import 'package:flutter/material.dart';

import '../theme_config.dart';

class ProgressPercentageOverlay extends StatelessWidget {
  final double progress;
  final String label;
  final String title;

  const ProgressPercentageOverlay({
    super.key,
    required this.progress,
    required this.label,
    this.title = 'Saving product',
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0, 1).toDouble();
    final percent = (clampedProgress * 100).round().clamp(0, 100);

    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.28),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.subtleText,
                        fontFamily: AppFonts.primary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: clampedProgress,
                        minHeight: 10,
                        backgroundColor: AppColors.lightGrey,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$percent%',
                        style: const TextStyle(
                          color: AppColors.darkText,
                          fontFamily: AppFonts.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
