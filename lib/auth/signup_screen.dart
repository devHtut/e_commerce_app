import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_user_service.dart';
import '../theme_config.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';
import 'otp_screen.dart';
import 'signin_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  // 1. FORM STATE
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
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

  // 2. SUPABASE AUTH FUNCTION (OTP Flow)
  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      await _showErrorPopup("Please agree to the Terms & Conditions.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final normalizedEmail = _emailController.text.trim().toLowerCase();

      // NEW: 1. Check if email already exists in 'users' table
      final isEmailTaken = await AuthUserService.emailExistsInUsers(
        normalizedEmail,
      );
      if (isEmailTaken) {
        if (!mounted) return;
        await _showErrorPopup(
          'This email is already registered. Please sign in instead.',
        );
        return; // Stop the sign up process
      }

      // 2. Attempt Sign Up with Supabase
      final response = await Supabase.instance.client.auth.signUp(
        email: normalizedEmail,
        password: _passwordController.text,
      );

      // 3. Only proceed if user creation was successful
      if (response.user != null) {
        // NEW: Check if identities array is empty
        // (Supabase returns empty identities for existing users to prevent enumeration)
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
          "A 6-digit verification code has been sent to your email.",
        );

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
        // This happens if email confirmation is enabled and user is created but unverified
        await _showErrorPopup(
          "Please check your email to verify your account.",
        );
      }
    } on AuthException catch (e) {
      final message = _mapSignupErrorMessage(e.message);
      if (!mounted) return;
      await _showErrorPopup(message);
    } catch (e) {
      if (!mounted) return;
      await _showErrorPopup("An unexpected error occurred. Please try again.");
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
      title: "Action failed",
      message: message,
      type: PopupType.error,
    );
  }

  Future<void> _showSuccessPopup(String message) {
    return showCustomPopup(
      context,
      title: "Success",
      message: message,
      type: PopupType.success,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 5. HEADER (Image 2)
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Text("Join Trendify Today", style: AppTextStyles.header),
                    SizedBox(width: 8),
                    Icon(Icons.person, size: 36, color: Color(0xFF6C89A2)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  "Embark on a fashion journey tailored for you.",
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 32),

                // 6. INPUT FIELDS (Image 2 - using Reusable Widgets)
                // Email Field
                const Text(
                  "Email",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: AppFonts.primary,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _emailController,
                  hintText: "example@gmail.com",
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Colors.black45,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Email is required.";
                    }
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return "Enter a valid email.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Password Field
                const Text(
                  "Password",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: AppFonts.primary,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _passwordController,
                  hintText: "Enter your password",
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
                      return "Password is required.";
                    }
                    if (value.length < 6) {
                      return "Password must be at least 6 characters.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                const Text(
                  "Confirm Password",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: AppFonts.primary,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _confirmPasswordController,
                  hintText: "Re-enter your password",
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
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Please confirm your password.";
                    }
                    if (value != _passwordController.text) {
                      return "Passwords do not match.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 7. AGREEMENT & LINK (Image 2)
                Row(
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      activeColor: AppColors.primaryGreen,
                      onChanged: (value) {
                        setState(() {
                          _agreedToTerms = value!;
                        });
                      },
                    ),
                    const Text(
                      "I agree to Trendify ",
                      style: AppTextStyles.body,
                    ),
                    GestureDetector(
                      onTap: () {
                        // Implement navigation to T&C
                      },
                      child: const Text(
                        "Terms & Conditions.",
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          decoration: TextDecoration.underline,
                          fontFamily: AppFonts.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Already have an account? ",
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
                        "Sign in",
                        style: TextStyle(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppFonts.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: double.infinity,
                    height: 56, // Large button as requested
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : CustomButton(
                            text: "Sign up",
                            onPressed: _signUpWithEmail,
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
