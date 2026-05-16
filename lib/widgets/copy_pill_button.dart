import 'package:flutter/material.dart';

import '../theme_config.dart';

class CopyPillButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const CopyPillButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.darkText,
        backgroundColor: AppColors.lightGrey,
        disabledForegroundColor: AppColors.subtleText,
        disabledBackgroundColor: AppColors.lightGrey,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(0, 34),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: const StadiumBorder(),
      ),
      child: const Text(
        'Copy',
        style: TextStyle(
          fontFamily: AppFonts.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
    );
  }
}
