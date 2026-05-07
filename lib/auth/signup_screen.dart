import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../customer/home_screen.dart';
import '../theme_config.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';
import 'auth_user_service.dart';
import 'otp_screen.dart';
import 'signin_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _agreedToTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      await _showErrorPopup('Please agree to the Terms & Conditions.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final normalizedEmail = _emailController.text.trim().toLowerCase();
      final isEmailTaken = await AuthUserService.emailExistsInUsers(
        normalizedEmail,
      );

      if (isEmailTaken) {
        if (!mounted) return;
        await _showErrorPopup(
          'This email is already registered. Please sign in instead.',
        );
        return;
      }

      final response = await Supabase.instance.client.auth.signUp(
        email: normalizedEmail,
        password: _passwordController.text,
      );

      if (response.user != null) {
        if (response.user!.identities != null &&
            response.user!.identities!.isEmpty) {
          if (!mounted) return;
          await _showErrorPopup(
            'This email is already registered. Please sign in instead.',
          );
          return;
        }

        if (!mounted) return;
        await _showSuccessPopup(
          'A 6-digit verification code has been sent to your email.',
        );

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(
              email: normalizedEmail,
              password: _passwordController.text,
            ),
          ),
        );
      } else {
        await _showErrorPopup(
          'Please check your email to verify your account.',
        );
      }
    } on AuthException catch (e) {
      final message = _mapSignupErrorMessage(e.message);
      if (!mounted) return;
      await _showErrorPopup(message);
    } catch (_) {
      if (!mounted) return;
      await _showErrorPopup('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _mapSignupErrorMessage(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('already registered') ||
        lower.contains('user already exists')) {
      return 'This email is already registered. Please sign in instead.';
    } else if (lower.contains('weak password')) {
      return 'Password is too weak. Please use at least 6 characters.';
    }
    return message;
  }

  Future<void> _showErrorPopup(String message) {
    return showCustomPopup(
      context,
      title: 'Action failed',
      message: message,
      type: PopupType.error,
    );
  }

  Future<void> _showSuccessPopup(String message) {
    return showCustomPopup(
      context,
      title: 'Success',
      message: message,
      type: PopupType.success,
    );
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
      appBar: AppBar(
        leading: const BackButton(color: AppColors.darkText),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
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
                            'Join BB Today',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.header,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Explore trusted products from Burma Brands.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.body,
                          ),
                          const SizedBox(height: 32),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Email',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: AppFonts.primary,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _emailController,
                            hintText: 'example@gmail.com',
                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: Colors.black45,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email is required.';
                              }
                              final emailRegex = RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              );
                              if (!emailRegex.hasMatch(value.trim())) {
                                return 'Enter a valid email.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Password',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: AppFonts.primary,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _passwordController,
                            hintText: 'Enter your password',
                            isPassword: _obscurePassword,
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Colors.black45,
                            ),
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
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required.';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Confirm Password',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontFamily: AppFonts.primary,
                                color: AppColors.darkText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _confirmPasswordController,
                            hintText: 'Re-enter your password',
                            isPassword: _obscureConfirmPassword,
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: Colors.black45,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.black45,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please confirm your password.';
                              }
                              if (value != _passwordController.text) {
                                return 'Passwords do not match.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Checkbox(
                                value: _agreedToTerms,
                                activeColor: AppColors.primaryGreen,
                                onChanged: (value) {
                                  setState(() {
                                    _agreedToTerms = value ?? false;
                                  });
                                },
                              ),
                              Expanded(
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    const Text(
                                      'I agree to Trendify ',
                                      style: AppTextStyles.body,
                                    ),
                                    GestureDetector(
                                      onTap: () {},
                                      child: const Text(
                                        'Terms & Conditions.',
                                        style: TextStyle(
                                          color: AppColors.primaryGreen,
                                          decoration: TextDecoration.underline,
                                          fontFamily: AppFonts.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : CustomButton(
                                    text: 'Sign up',
                                    onPressed: _signUpWithEmail,
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
                                'Already have an account? ',
                                style: AppTextStyles.body,
                              ),
                              GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SignInScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  'Sign in',
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
              ),
            );
          },
        ),
      ),
    );
  }
}
