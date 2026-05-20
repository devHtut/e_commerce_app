import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_user_service.dart';
import 'customer/home_screen.dart';
import 'notification/push_notification_service.dart';
import 'pwa/pwa_install_prompt.dart';
import 'vendor/vendor_business_info_screen.dart';
import 'vendor/vendor_dashboard.dart';
import 'vendor/vendor_info_screen.dart';
import 'theme_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://ckfvzrqylzpvhrvhtenz.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNrZnZ6cnF5bHpwdmhydmh0ZW56Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgzMDU4NjQsImV4cCI6MjA5Mzg4MTg2NH0.NAgFZrAFOswIoPXP7ksWrqeAyI9Yc_aO8pGR2pG29I0',
  );

  await PushNotificationService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const double _webMaxAppWidth = 390;

  Future<Widget> _resolveStartScreen() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      return const HomeScreen();
    }

    final userType = await AuthUserService.resolveUserType(
      userId: user.id,
      email: user.email,
    );

    if (userType.toLowerCase() == 'vendor') {
      final hasVendorInfo = await AuthUserService.vendorHasBrandInfo(user.id);
      if (!hasVendorInfo) {
        return const VendorInfoScreen();
      }
      final hasVendorBusinessInfo = await AuthUserService.vendorHasBusinessInfo(
        user.id,
      );
      return hasVendorBusinessInfo
          ? const VendorDashboard()
          : const VendorBusinessInfoScreen();
    }
    return const HomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        if (!kIsWeb || child == null) {
          return child ?? const SizedBox.shrink();
        }

        return PwaInstallPromptGate(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth <= _webMaxAppWidth) {
                return child;
              }

              final mediaQuery = MediaQuery.of(context);
              return ColoredBox(
                color: AppColors.lightGrey,
                child: Center(
                  child: SizedBox(
                    width: _webMaxAppWidth,
                    height: constraints.maxHeight,
                    child: MediaQuery(
                      data: mediaQuery.copyWith(
                        size: Size(_webMaxAppWidth, mediaQuery.size.height),
                      ),
                      child: child,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      navigatorObservers: [PwaInstallNavigationObserver()],
      theme: ThemeData(
        primaryColor: AppColors.primaryGreen,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryGreen,
          primary: AppColors.primaryGreen,
        ),
        textTheme: TextTheme(
          headlineLarge: AppTextStyles.header,
          bodyMedium: AppTextStyles.body,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: AppTextStyles.appBarTitle,
          iconTheme: IconThemeData(color: AppColors.darkText),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(textStyle: AppTextStyles.button),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(textStyle: AppTextStyles.button),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(textStyle: AppTextStyles.button),
        ),
      ),
      home: FutureBuilder<Widget>(
        future: _resolveStartScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
              return const Scaffold(backgroundColor: Colors.white);
            }
            return const _AppSplashScreen();
          }
          if (snapshot.hasError) {
            return const HomeScreen();
          }
          return snapshot.data ?? const HomeScreen();
        },
      ),
    );
  }
}

class _AppSplashScreen extends StatelessWidget {
  const _AppSplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image(
          image: AssetImage('assets/icon_logo.png'),
          width: 220,
          height: 220,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
