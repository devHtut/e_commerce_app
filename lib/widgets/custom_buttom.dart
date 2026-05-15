import 'package:flutter/material.dart';

import '../theme_config.dart';
import 'custom_loading_state.dart';

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
          ? const ButtonLoadingDots()
          : Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}
