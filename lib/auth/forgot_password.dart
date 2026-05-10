import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme_config.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';
import 'auth_user_service.dart';
import 'signin_screen.dart';

enum _ForgotPasswordStep { email, otp, password }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ForgotPasswordStep _step = _ForgotPasswordStep.email;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String get _normalizedEmail => _emailController.text.trim().toLowerCase();

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp({bool validateForm = true}) async {
    if (validateForm && !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final emailExists = await AuthUserService.emailExistsInUsers(
        _normalizedEmail,
      );

      if (!emailExists) {
        if (!mounted) return;
        await showCustomPopup(
          context,
          title: 'Email not found',
          message: 'No account is registered with this email.',
          type: PopupType.error,
        );
        return;
      }

      await Supabase.instance.client.auth.resetPasswordForEmail(
        _normalizedEmail,
      );

      if (!mounted) return;
      setState(() {
        _step = _ForgotPasswordStep.otp;
        _otpController.clear();
      });
      await showCustomPopup(
        context,
        title: 'OTP sent',
        message: 'A 6-digit password reset code was sent to $_normalizedEmail.',
        type: PopupType.success,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'OTP request failed',
        message: e.message,
        type: PopupType.error,
      );
    } catch (_) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'OTP request failed',
        message: 'Something went wrong. Please try again.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        type: OtpType.recovery,
        email: _normalizedEmail,
        token: _otpController.text.trim(),
      );

      if (response.user == null) {
        throw const AuthException('Invalid OTP code.');
      }

      if (!mounted) return;
      setState(() {
        _step = _ForgotPasswordStep.password;
        _passwordController.clear();
        _confirmPasswordController.clear();
      });
      await showCustomPopup(
        context,
        title: 'OTP verified',
        message: 'Please create a new password for your account.',
        type: PopupType.success,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Verification failed',
        message: e.message,
        type: PopupType.error,
      );
    } catch (_) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Verification failed',
        message: 'Something went wrong. Please try again.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Password changed',
        message: 'Your password was changed successfully. Please sign in.',
        type: PopupType.success,
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Password change failed',
        message: e.message,
        type: PopupType.error,
      );
    } catch (_) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Password change failed',
        message: 'Something went wrong. Please try again.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goBackStep() {
    if (_step == _ForgotPasswordStep.email) {
      Navigator.of(context).maybePop();
      return;
    }

    setState(() {
      _formKey.currentState?.reset();
      if (_step == _ForgotPasswordStep.password) {
        _step = _ForgotPasswordStep.otp;
        _passwordController.clear();
        _confirmPasswordController.clear();
      } else {
        _step = _ForgotPasswordStep.email;
        _otpController.clear();
      }
    });
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required.';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email.';
    }
    return null;
  }

  String? _validateOtp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'OTP is required.';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return 'Enter exactly 6 digits.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'New password is required.';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm password is required.';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }
    return null;
  }

  String get _title {
    switch (_step) {
      case _ForgotPasswordStep.email:
        return 'Forgot Password';
      case _ForgotPasswordStep.otp:
        return 'Enter OTP Code';
      case _ForgotPasswordStep.password:
        return 'Create New Password';
    }
  }

  String get _subtitle {
    switch (_step) {
      case _ForgotPasswordStep.email:
        return 'Enter your reset email and we will send a 6-digit OTP.';
      case _ForgotPasswordStep.otp:
        return 'Please enter the 6-digit code sent to $_normalizedEmail.';
      case _ForgotPasswordStep.password:
        return 'Enter and confirm your new password.';
    }
  }

  String get _buttonText {
    switch (_step) {
      case _ForgotPasswordStep.email:
        return 'Send OTP';
      case _ForgotPasswordStep.otp:
        return 'Verify OTP';
      case _ForgotPasswordStep.password:
        return 'Change Password';
    }
  }

  Future<void> _submitCurrentStep() {
    switch (_step) {
      case _ForgotPasswordStep.email:
        return _sendOtp();
      case _ForgotPasswordStep.otp:
        return _verifyOtp();
      case _ForgotPasswordStep.password:
        return _changePassword();
    }
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: AppFonts.primary,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 8),
        CustomTextField(
          hintText: 'example@gmail.com',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.email_outlined, color: Colors.black45),
          validator: _validateEmail,
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OTP Code',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: AppFonts.primary,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 8),
        CustomTextField(
          hintText: 'Enter 6-digit code',
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          prefixIcon: const Icon(Icons.pin_outlined, color: Colors.black45),
          validator: _validateOtp,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : () => _sendOtp(validateForm: false),
            child: const Text(
              'Resend OTP',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontFamily: AppFonts.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'New Password',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: AppFonts.primary,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 8),
        CustomTextField(
          hintText: 'New password',
          controller: _passwordController,
          isPassword: _obscurePassword,
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.black45),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.black45,
            ),
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
          ),
          validator: _validatePassword,
        ),
        const SizedBox(height: 16),
        const Text(
          'Confirm New Password',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontFamily: AppFonts.primary,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 8),
        CustomTextField(
          hintText: 'Confirm new password',
          controller: _confirmPasswordController,
          isPassword: _obscureConfirmPassword,
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.black45),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons.visibility_off
                  : Icons.visibility,
              color: Colors.black45,
            ),
            onPressed: () {
              setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              );
            },
          ),
          validator: _validateConfirmPassword,
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _ForgotPasswordStep.email:
        return _buildEmailStep();
      case _ForgotPasswordStep.otp:
        return _buildOtpStep();
      case _ForgotPasswordStep.password:
        return _buildPasswordStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        leading: BackButton(
          color: AppColors.darkText,
          onPressed: _goBackStep,
        ),
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
                24,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_title, style: AppTextStyles.header),
                          const SizedBox(height: 8),
                          Text(_subtitle, style: AppTextStyles.body),
                          const SizedBox(height: 28),
                          _buildStepContent(),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: _isLoading
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : CustomButton(
                                    text: _buttonText,
                                    onPressed: _submitCurrentStep,
                                  ),
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
