import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme_config.dart';

class ContactAboutScreen extends StatelessWidget {
  const ContactAboutScreen({super.key});

  static const String legalDocumentsBaseUrl =
      'https://burmabrands.github.io/burmabrands';

  static const List<_AboutSection> _sections = [
    _AboutSection(
      icon: CupertinoIcons.info_circle,
      title: 'About Us',
      body:
          'Burma Brands is a local shopping platform created to bring Myanmar brands and customers closer together. We help verified brands present their products clearly, manage customer conversations, and receive orders in one trusted place.',
    ),
    _AboutSection(
      icon: CupertinoIcons.flag,
      title: 'Mission',
      body:
          'Our mission is to support local businesses by making online selling simpler, safer, and more accessible while helping customers discover quality products from brands they can trust.',
    ),
    _AboutSection(
      icon: CupertinoIcons.eye,
      title: 'Vision',
      body:
          'We aim to become a reliable digital marketplace for Myanmar brands, where every customer can shop with confidence and every brand can grow with better tools and stronger visibility.',
    ),
    _AboutSection(
      icon: CupertinoIcons.bag,
      title: 'What We Offer',
      body:
          'Burma Brands offers product browsing, brand profiles, direct brand contact, carts and orders, product ratings, wishlist features, delivery address management, and reporting tools for safer shopping.',
    ),
    _AboutSection(
      icon: CupertinoIcons.checkmark_shield,
      title: 'Why Choose Us',
      body:
          'Brands on the platform are verified by the Burma Brands Team, and customers can view shop information, contact brands directly, and report inappropriate content when needed.',
    ),
    _AboutSection(
      icon: CupertinoIcons.heart,
      title: 'Our Values',
      body:
          'We value trust, local growth, clear communication, customer safety, and fair opportunities for Myanmar businesses. Every feature is designed to make shopping and selling feel more dependable.',
    ),
    _AboutSection(
      icon: CupertinoIcons.question_circle,
      title: 'Contact Us',
      body:
          'For help, questions, reports, or partnership inquiries, please contact the Burma Brands Team.',
      showContactActions: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.darkText),
        title: const Text(
          'Contact & About',
          style: TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _Header(),
            const SizedBox(height: 16),
            ..._sections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SectionCard(section: section),
              ),
            ),
            const _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Image.asset(
                  'assets/icon_button.png',
                  width: 200,
                  height: 100,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Burma Brands',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Connecting customers with trusted local brands across Myanmar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.subtleText,
                    fontFamily: AppFonts.primary,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final _AboutSection section;

  Future<void> _openUri(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open contact option.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              section.icon,
              color: AppColors.primaryGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  section.body,
                  style: const TextStyle(
                    color: AppColors.subtleText,
                    fontFamily: AppFonts.primary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                if (section.showContactActions) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openUri(
                          context,
                          Uri.parse('mailto:burmabrands@gmail.com'),
                        ),
                        icon: const Icon(CupertinoIcons.mail, size: 18),
                        label: const Text('burmabrands@gmail.com'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(
                            color: AppColors.primaryGreen,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: AppFonts.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _openUri(
                          context,
                          Uri.parse('tel:+959772364896'),
                        ),
                        icon: const Icon(CupertinoIcons.phone, size: 18),
                        label: const Text('+959772364896'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: const BorderSide(
                            color: AppColors.primaryGreen,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: const TextStyle(
                            fontFamily: AppFonts.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  Future<void> _openDocument(BuildContext context, String path) async {
    final uri = Uri.parse('${ContactAboutScreen.legalDocumentsBaseUrl}/$path');
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open document link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          const Text(
            'Copyright (c) 2026 Burma Brands. All rights reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.subtleText,
              fontFamily: AppFonts.primary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              TextButton(
                onPressed: () =>
                    _openDocument(context, 'privacy-policy.html'),
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontFamily: AppFonts.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    _openDocument(context, 'terms-and-conditions.html'),
                child: const Text(
                  'Terms & Conditions',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontFamily: AppFonts.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AboutSection {
  const _AboutSection({
    required this.icon,
    required this.title,
    required this.body,
    this.showContactActions = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool showContactActions;
}
