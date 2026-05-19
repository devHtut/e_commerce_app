import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage _) async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Firebase may not be configured yet in local/dev builds.
  }
}

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();
  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        'burma_brands_push',
        'Burma Brands notifications',
        description: 'Order, account, and chat updates from Burma Brands.',
        importance: Importance.high,
      );

  bool _initialized = false;
  bool _firebaseAvailable = false;
  bool _tokenRefreshListening = false;
  bool _foregroundMessageListening = false;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
      await _initializeLocalNotifications();
      _listenForTokenRefresh();
      _listenForForegroundMessages();
      _firebaseAvailable = true;
    } catch (error) {
      _firebaseAvailable = false;
      debugPrint('Push notifications are not configured yet: $error');
    }
  }

  Future<void> registerCurrentDevice() async {
    await initialize();
    if (!_firebaseAvailable) return;

    final user = _client.auth.currentUser;
    if (user == null) return;

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    try {
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _saveToken(user.id, token);
    } catch (error) {
      debugPrint('Unable to register push token: $error');
    }
  }

  Future<void> unregisterCurrentDevice() async {
    await initialize();
    if (!_firebaseAvailable) return;

    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _client
          .from('user_push_tokens')
          .delete()
          .eq('user_id', user.id)
          .eq('token', token);
    } catch (error) {
      debugPrint('Unable to unregister push token: $error');
    }
  }

  void _listenForTokenRefresh() {
    if (_tokenRefreshListening) return;
    _tokenRefreshListening = true;

    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final user = _client.auth.currentUser;
      if (user == null || token.isEmpty) return;

      try {
        await _saveToken(user.id, token);
      } catch (error) {
        debugPrint('Unable to refresh push token: $error');
      }
    });
  }

  void _listenForForegroundMessages() {
    if (_foregroundMessageListening) return;
    _foregroundMessageListening = true;

    FirebaseMessaging.onMessage.listen((message) {
      _showForegroundNotification(message);
    });
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings: settings);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    await _localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> _saveToken(String userId, String token) async {
    await _client.from('user_push_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': _platformName(),
      'is_active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,token');
  }

  String _platformName() {
    if (kIsWeb) return 'web';

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}
