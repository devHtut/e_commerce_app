import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import 'auth_user_service.dart';
import 'signin_screen.dart';
import '../theme_config.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  final String password;
  const OtpScreen({super.key, required this.email, required this.password});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _otpController = TextEditingController();
  int _secondsRemaining = 60;
  Timer? _timer;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.signup,
        token: _otpController.text.trim(),
        email: widget.email.trim(),
      );

      if (response.user != null) {
        await AuthUserService.createUserProfile(
          response.user!.id,
          widget.email,
        );

        if (!mounted) return;
        await showCustomPopup(
          context,
          title: "Verification successful",
          message: "Please sign in with the same email and password",
          type: PopupType.success,
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SignInScreen()),
        );
      }
    } on AuthException catch (e) {
      debugPrint("Supabase Auth Error: ${e.message}");
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: "Verification failed",
        message: e.message,
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    super.dispose();
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Enter OTP Code 🔐",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Please check your email. Verification code sent to ${widget.email}",
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 40),

                // Using your CustomTextField for consistent web/mobile design
                CustomTextField(
                  controller: _otpController,
                  hintText: "Enter 6-digit code",
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "OTP is required.";
                    }
                    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
                      return "Enter exactly 6 digits.";
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Using your CustomButton
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : CustomButton(
                          text: "Verify",
                          onPressed:
                              _verifyOtp, // This now works safely with _isLoading
                        ),
                ),

                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: _secondsRemaining == 0
                        ? () async {
                            // Resend OTP Logic အလုပ်လုပ်အောင် ထည့်သွင်းထားပါတယ်
                            setState(() => _secondsRemaining = 60);
                            _startTimer();
                            try {
                              await Supabase.instance.client.auth.resend(
                                type: OtpType.signup,
                                email: widget.email,
                              );
                              if (!mounted) return;
                              await showCustomPopup(
                                context,
                                title: "OTP Resent",
                                message:
                                    "A new verification code has been sent.",
                                type: PopupType.success,
                              );
                            } catch (e) {
                              if (!mounted) return;
                              await showCustomPopup(
                                context,
                                title: "Failed to resend",
                                message:
                                    "Could not resend OTP. Please try again later.",
                                type: PopupType.error,
                              );
                            }
                          }
                        : null,
                    child: Text(
                      _secondsRemaining > 0
                          ? "You can resend in $_secondsRemaining seconds"
                          : "Resend code",
                      style: TextStyle(
                        color: _secondsRemaining == 0
                            ? AppColors.primaryGreen
                            : Colors.grey,
                        fontFamily: AppFonts.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
