import 'package:flutter/material.dart';

import '../theme_config.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const CustomButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        textStyle: AppTextStyles.button,
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}
