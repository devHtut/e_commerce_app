import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:flutter/foundation.dart';

class PwaInstallService {
  PwaInstallService._();

  static final PwaInstallService instance = PwaInstallService._();
  static const String _dismissedKey = 'burma_brands_pwa_install_dismissed';
  static const String _installedKey = 'burma_brands_pwa_installed';

  final ValueNotifier<int> engagementNotifier = ValueNotifier<int>(0);

  html.Event? _installPromptEvent;
  bool _initialized = false;
  bool _hasInteraction = false;
  int _pageVisits = 0;

  bool get isIosSafari {
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    final isIos = userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('ipod');
    final isSafari = userAgent.contains('safari') &&
        !userAgent.contains('crios') &&
        !userAgent.contains('fxios');
    return isIos && isSafari;
  }

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    html.window.addEventListener('beforeinstallprompt', (event) {
      event.preventDefault();
      _installPromptEvent = event;
      _notifyEngagementChanged();
    });

    html.window.addEventListener('appinstalled', (_) {
      html.window.localStorage[_installedKey] = 'true';
      html.window.localStorage.remove(_dismissedKey);
      _installPromptEvent = null;
      _notifyEngagementChanged();
    });
  }

  void recordInteraction() {
    if (_hasInteraction) return;
    _hasInteraction = true;
    _notifyEngagementChanged();
  }

  void recordPageVisit() {
    _pageVisits += 1;
    _notifyEngagementChanged();
  }

  bool shouldShowPrompt() {
    if (!_isMobileViewport()) return false;
    if (_isStandalone()) return false;
    if (html.window.localStorage[_dismissedKey] == 'true') return false;
    if (html.window.localStorage[_installedKey] == 'true') return false;
    if (!_hasInteraction && _pageVisits < 2) return false;

    return isIosSafari || _installPromptEvent != null;
  }

  Future<bool> promptInstall() async {
    final event = _installPromptEvent;
    if (event == null) return false;

    js_util.callMethod<void>(event, 'prompt', const <Object?>[]);
    final choicePromise = js_util.getProperty<Object>(event, 'userChoice');
    final choice = await js_util.promiseToFuture<Object?>(
      choicePromise,
    );
    _installPromptEvent = null;

    final outcome = choice == null
        ? null
        : js_util.getProperty<Object?>(choice, 'outcome')?.toString();
    final accepted = outcome == 'accepted';
    if (accepted) {
      html.window.localStorage[_installedKey] = 'true';
    } else {
      markDismissed();
    }
    _notifyEngagementChanged();
    return accepted;
  }

  void markDismissed() {
    html.window.localStorage[_dismissedKey] = 'true';
    _notifyEngagementChanged();
  }

  bool _isStandalone() {
    final displayModeStandalone = html.window
        .matchMedia('(display-mode: standalone)')
        .matches;
    final navigatorStandalone =
        js_util.getProperty<Object?>(html.window.navigator, 'standalone') ==
            true;
    return displayModeStandalone || navigatorStandalone;
  }

  bool _isMobileViewport() {
    final width = html.window.innerWidth ?? 0;
    final userAgent = html.window.navigator.userAgent.toLowerCase();
    final mobileUserAgent = userAgent.contains('android') ||
        userAgent.contains('iphone') ||
        userAgent.contains('ipad') ||
        userAgent.contains('ipod');
    return mobileUserAgent || width <= 600;
  }

  void _notifyEngagementChanged() {
    scheduleMicrotask(() {
      engagementNotifier.value += 1;
    });
  }
}
