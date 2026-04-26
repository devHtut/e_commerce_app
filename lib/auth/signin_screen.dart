import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'forgot_password.dart';
import 'auth_user_service.dart';
import 'signup_screen.dart';
import '../theme_config.dart';
import '../home/home_screen.dart';
import '../home/vendor_dashboard.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';

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
    if (_emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      // Validation error ...
      return;
    }

    setState(() => _isLoading = true);
    try {
      final normalizedEmail = _emailController.text.trim();
      
      // 1. AuthUserService ကို အသုံးမပြုဘဲ တိုက်ရိုက် Login ဝင်ကြည့်ပါ
      final authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: normalizedEmail,
        password: _passwordController.text,
      );

      final user = authResponse.user;
      if (user != null) {
        // User ဝင်လို့ရသွားပြီဆိုမှ User Type စစ်ပါ
        String userType = await AuthUserService.resolveUserType(
          userId: user.id,
          email: user.email,
        );

        final isVendor = userType.toLowerCase() == 'vendor';
        if (!mounted) return;
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => isVendor ? const VendorDashboard() : const HomeScreen(),
          ),
        );
      }
    } on AuthException catch (e) {
      // 2. Error ကို သေချာဖတ်ပြီးမှ message ပြပါ
      String message = e.message;
      if (e.message.contains("Invalid login credentials")) {
        message = "Incorrect email or password.";
      } else if (e.message.contains("Email not confirmed")) {
        message = "Please verify your email via the OTP sent to you.";
      }
      
      await showCustomPopup(
        context,
        title: "Sign in failed",
        message: message,
        type: PopupType.error,
      );
    } catch (e) {
      await showCustomPopup(context, title: "Error", message: e.toString(), type: PopupType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Welcome Back! 👋", style: AppTextStyles.header),
              const SizedBox(height: 8),
              const Text(
                "Sign in to access your personalized fashion.",
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 32),
              
              CustomTextField(hintText: "Email", controller: _emailController),
              const SizedBox(height: 16),
              CustomTextField(
                hintText: "Password",
                controller: _passwordController,
                isPassword: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
                    onChanged: (v) => setState(() => _rememberMe = v!),
                  ),
                  const Text("Remember me", style: AppTextStyles.body),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Forgot Password?",
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
                    : CustomButton(text: "Sign in", onPressed: _signInWithEmail),
              ),

              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? ", style: AppTextStyles.body),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignupScreen()),
                      );
                    },
                    child: const Text(
                      "Sign up",
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppFonts.primary,
                      ),
                    ),
                  ),
                ],
              ),
              
              // Add "or" divider and Social login buttons here...
            ],
          ),
        ),
      ),
    );
  }
}