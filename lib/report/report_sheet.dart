import 'package:flutter/material.dart';

import '../theme_config.dart';

class ReportDraft {
  final String reason;
  final String details;

  const ReportDraft({required this.reason, required this.details});
}

class ReportSheet {
  static const List<String> _reasons = [
    'Violent or harmful content',
    'Harassment or hate speech',
    'Scam or misleading content',
    'Other safety concern',
  ];

  static Future<ReportDraft?> show(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    var selectedReason = _reasons.first;
    final detailsController = TextEditingController();

    return showModalBottomSheet<ReportDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: 12 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(30)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.darkText,
                          fontFamily: AppFonts.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.subtleText,
                          fontFamily: AppFonts.primary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final reason in _reasons)
                            ChoiceChip(
                              label: Text(reason),
                              selected: selectedReason == reason,
                              onSelected: (_) =>
                                  setModalState(() => selectedReason = reason),
                              selectedColor: AppColors.primaryGreen.withValues(
                                alpha: 0.14,
                              ),
                              labelStyle: TextStyle(
                                color: selectedReason == reason
                                    ? AppColors.primaryGreen
                                    : AppColors.darkText,
                                fontFamily: AppFonts.primary,
                                fontWeight: FontWeight.w700,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: detailsController,
                        minLines: 3,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          labelText: 'Details (optional)',
                          hintText: 'Tell us what should be reviewed.',
                          filled: true,
                          fillColor: AppColors.lightGrey,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                                side: const BorderSide(
                                  color: AppColors.primaryGreen,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.pop(
                                context,
                                ReportDraft(
                                  reason: selectedReason,
                                  details: detailsController.text,
                                ),
                              ),
                              icon: const Icon(Icons.flag_outlined, size: 18),
                              label: const Text('Report'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCF5F5F),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(detailsController.dispose);
  }
}
