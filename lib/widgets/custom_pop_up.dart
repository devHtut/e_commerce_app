import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme_config.dart';

enum PopupType { success, error }

Future<void> showCustomPopup(
  BuildContext context, {
  required String title,
  required String message,
  required PopupType type,
}) {
  final bool isSuccess = type == PopupType.success;

  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isSuccess ? CupertinoIcons.check_mark_circled : CupertinoIcons.exclamationmark_circle,
              color: isSuccess ? AppColors.primaryGreen : Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontFamily: AppFonts.primary,
              ),
            ),
          ),
        ],
      );
    },
  );
}
