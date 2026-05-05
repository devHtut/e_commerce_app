import 'package:flutter/material.dart';

import '../theme_config.dart';
import '../widgets/custom_pop_up.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const List<String> _items = [
    'FAQ',
    'Contact Support',
    'Privacy Policy',
    'Terms of Service',
    'Partner',
    'Job Vacancy',
    'Accessibility',
    'Feedback',
    'About us',
    'Rate us',
    'Visit Our Website',
    'Follow us on Social Media',
  ];

  void _showPlaceholder(BuildContext context, String title) {
    showCustomPopup(
      context,
      title: title,
      message: 'This section is under development.',
      type: PopupType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.darkText),
        title: const Text(
          'Help & Support',
          style: TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 16),
          itemBuilder: (context, index) {
            final item = _items[index];
            return Container(
              color: Colors.white,
              child: ListTile(
                title: Text(
                  item,
                  style: const TextStyle(
                    fontFamily: AppFonts.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showPlaceholder(context, item),
              ),
            );
          },
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: _items.length,
        ),
      ),
    );
  }
}
