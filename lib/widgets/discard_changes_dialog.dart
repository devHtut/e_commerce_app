import 'package:flutter/material.dart';

import '../theme_config.dart';

Future<bool> showDiscardChangesDialog(
  BuildContext context, {
  String title = 'Discard changes?',
  String message =
      'Your changes are not saved yet. Are you sure you want to leave this screen?',
}) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: AppColors.subtleText,
            fontFamily: AppFonts.primary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep Editing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCF5F5F),
            ),
            child: const Text('Discard', style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
  return discard == true;
}
