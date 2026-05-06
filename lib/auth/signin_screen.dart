import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../vendor/vendor_business_info_screen.dart';
import 'forgot_password.dart';
import 'auth_user_service.dart';
import 'signup_screen.dart';
import '../theme_config.dart';
import '../notification/notification_service.dart';
import '../customer/home_screen.dart';
import '../vendor/vendor_dashboard.dart';
import '../vendor/vendor_info_screen.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';
import 'profile_info_screen.dart';

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
        title: "Validation failed",
        message: "Email and password are required.",
        type: PopupType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final normalizedEmail = _emailController.text.trim().toLowerCase();

      // ၁။ Email အရင်စစ်ဆေးခြင်း
      final emailExists = await AuthUserService.emailExistsInUsers(
        normalizedEmail,
      );
      if (!emailExists) {
        if (!mounted) return;
        await showCustomPopup(
          context,
          title: "Sign in failed",
          message: "Email not registered. Please sign up first.",
          type: PopupType.error,
        );
        return; // အကောင့်မရှိရင် ဒီမှာတင် ရပ်လိုက်ပါ
      }

      // ၂။ Email ရှိမှ Password နဲ့ ဝင်ခြင်း
      final authResponse = await Supabase.instance.client.auth
          .signInWithPassword(
            email: normalizedEmail,
            password: _passwordController.text,
          );

      final user = authResponse.user;

      if (user != null) {
        // ၃။ Profile Check & User Type Resolve
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
          title: "Sign in success",
          message: isVendor
              ? (!vendorHasInfo
                    ? "Welcome! Please complete your vendor brand profile."
                    : (vendorHasBusinessInfo
                          ? "Welcome to Vendor Dashboard!"
                          : "Brand saved! Please complete your business details."))
              : (customerNeedsProfile
                    ? "Welcome! Please complete your profile."
                    : "Welcome back!"),
          type: PopupType.success,
        );

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => destination),
          (route) => false,
        );
      }
    } on AuthException catch (e) {
      // ၄။ Password မှားယွင်းခြင်းကို တိကျစွာ ဖမ်းခြင်း
      final message =
          e.message.toLowerCase().contains('invalid login credentials')
          ? 'Incorrect password. Please try again.'
          : e.message;

      if (!mounted) return;
      await showCustomPopup(
        context,
        title: "Sign in failed",
        message: message,
        type: PopupType.error,
      );
    } catch (e) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: "Error",
        message: "An unexpected error occurred.",
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
                    : CustomButton(
                        text: "Sign in",
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
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Continue as Guest',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
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
            ],
          ),
        ),
      ),
    );
  }
}
