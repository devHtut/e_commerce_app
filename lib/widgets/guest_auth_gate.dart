import 'package:flutter/material.dart';

import '../auth/signin_screen.dart';
import '../auth/signup_screen.dart';
import '../theme_config.dart';
import 'custom_buttom.dart';

/// Same sign-up / sign-in prompt shown to guests on Wishlist, Cart, and My Orders.
class GuestAuthGatePanel extends StatelessWidget {
  const GuestAuthGatePanel({super.key});

  /// Presents the gate in a modal sheet (e.g. from product detail or shop profile).
  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: const SingleChildScrollView(
              child: GuestAuthGatePanel(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          const Text(
            'Create your account to save wishlist, cart, and orders.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: CustomButton(
              text: 'Sign up',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignInScreen()),
              );
            },
            child: const Text(
              'Already have an account? Sign in',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontFamily: AppFonts.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
