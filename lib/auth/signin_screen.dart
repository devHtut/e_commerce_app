import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../customer/home_screen.dart';
import '../notification/notification_service.dart';
import '../theme_config.dart';
import '../vendor/vendor_business_info_screen.dart';
import '../vendor/vendor_dashboard.dart';
import '../vendor/vendor_info_screen.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';
import 'auth_user_service.dart';
import 'forgot_password.dart';
import 'profile_info_screen.dart';
import 'signup_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      await showCustomPopup(
        context,
        title: 'Validation failed',
        message: 'Email and password are required.',
        type: PopupType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final normalizedEmail = _emailController.text.trim().toLowerCase();
      final emailExists = await AuthUserService.emailExistsInUsers(
        normalizedEmail,
      );

      if (!emailExists) {
        if (!mounted) return;
        await showCustomPopup(
          context,
          title: 'Sign in failed',
          message: 'Email not registered. Please sign up first.',
          type: PopupType.error,
        );
        return;
      }

      final authResponse = await Supabase.instance.client.auth
          .signInWithPassword(
            email: normalizedEmail,
            password: _passwordController.text,
          );

      final user = authResponse.user;
      if (user == null) return;

      final userType = await AuthUserService.resolveUserType(
        userId: user.id,
        email: user.email,
      );

      final isVendor = userType.toLowerCase() == 'vendor';
      final vendorHasInfo = isVendor
          ? await AuthUserService.vendorHasBrandInfo(user.id)
          : false;
      final vendorHasBusinessInfo = isVendor
          ? await AuthUserService.vendorHasBusinessInfo(user.id)
          : false;
      final isCustomer = !isVendor;
      final customerNeedsProfile = isCustomer
          ? !(await AuthUserService.userHasProfile(user.id))
          : false;
      final destination = isVendor
          ? (!vendorHasInfo
                ? const VendorInfoScreen()
                : (vendorHasBusinessInfo
                      ? const VendorDashboard()
                      : const VendorBusinessInfoScreen()))
          : (customerNeedsProfile
                ? const ProfileInfoScreen()
                : const HomeScreen());

      await NotificationService.instance.createWelcomeNotification(
        isVendor: isVendor,
        userId: user.id,
      );

      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Sign in success',
        message: isVendor
            ? (!vendorHasInfo
                  ? 'Welcome! Please complete your vendor brand profile.'
                  : (vendorHasBusinessInfo
                        ? 'Welcome to Vendor Dashboard!'
                        : 'Brand saved! Please complete your business details.'))
            : (customerNeedsProfile
                  ? 'Welcome! Please complete your profile.'
                  : 'Welcome back!'),
        type: PopupType.success,
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => destination),
        (route) => false,
      );
    } on AuthException catch (e) {
      final message =
          e.message.toLowerCase().contains('invalid login credentials')
          ? 'Incorrect password. Please try again.'
          : e.message;

      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Sign in failed',
        message: message,
        type: PopupType.error,
      );
    } catch (_) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Error',
        message: 'An unexpected error occurred.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _continueAsGuest() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.asset(
                          '../assets/icon_logo.png',
                          height: 96,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Welcome!',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.header,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sign in to access your personalized shopping experience.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: 32),
                        CustomTextField(
                          hintText: 'Email',
                          controller: _emailController,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          hintText: 'Password',
                          controller: _passwordController,
                          isPassword: _obscurePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.black45,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: AppColors.primaryGreen,
                              onChanged: (v) {
                                setState(() => _rememberMe = v ?? false);
                              },
                            ),
                            const Text(
                              'Remember me',
                              style: AppTextStyles.body,
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontFamily: AppFonts.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : CustomButton(
                                  text: 'Sign in',
                                  onPressed: _signInWithEmail,
                                ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _continueAsGuest,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(
                                color: AppColors.primaryGreen,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text('Continue as Guest'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Don't have an account? ",
                              style: AppTextStyles.body,
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignupScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'Sign up',
                                style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: AppFonts.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
