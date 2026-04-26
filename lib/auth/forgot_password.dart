import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme_config.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
      );
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Email sent',
        message: 'Password reset instructions were sent to your email.',
        type: PopupType.success,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Request failed',
        message: e.message,
        type: PopupType.error,
      );
    } catch (_) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Request failed',
        message: 'Something went wrong. Please try again.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Forgot Password', style: AppTextStyles.header),
                const SizedBox(height: 8),
                const Text(
                  'Enter your email and we will send reset instructions.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 28),
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
                  prefixIcon: const Icon(Icons.email_outlined, color: Colors.black45),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required.';
                    }
                    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    if (!emailRegex.hasMatch(value.trim())) {
                      return 'Enter a valid email.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : CustomButton(
                          text: 'Send Reset Email',
                          onPressed: _sendResetLink,
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
