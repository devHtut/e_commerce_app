import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../theme_config.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        disabledBackgroundColor: AppColors.primaryGreen,
        textStyle: AppTextStyles.button,
      ),
      child: isLoading
          ? Lottie.asset(
              'assets/animations/loading_dots.json',
              width: 72,
              height: 36,
              fit: BoxFit.contain,
            )
          : Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}
