import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_user_service.dart';
import 'home/home_screen.dart';
import 'home/vendor_dashboard.dart';
import 'theme_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://syceqprtekughgmbrzel.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN5Y2VxcHJ0ZWt1Z2hnbWJyemVsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzcxMjM2OTIsImV4cCI6MjA5MjY5OTY5Mn0.GnyFmjN42D7UTLfJzQ1n_dzBgrXdlGHFxQ-4fCQHIZ0',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
      return const VendorDashboard();
    }
    return const HomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      ),
      home: FutureBuilder<Widget>(
        future: _resolveStartScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
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