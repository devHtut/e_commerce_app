import 'package:flutter/material.dart';

import 'theme_config.dart';

class ContactAboutScreen extends StatelessWidget {
  const ContactAboutScreen({super.key});

  static const List<_AboutSection> _sections = [
    _AboutSection(
      icon: Icons.info_outline,
      title: 'About Us',
      body:
          'Burma Brands is a local shopping platform created to bring Myanmar brands and customers closer together. We help verified brands present their products clearly, manage customer conversations, and receive orders in one trusted place.',
    ),
    _AboutSection(
      icon: Icons.flag_outlined,
      title: 'Mission',
      body:
          'Our mission is to support local businesses by making online selling simpler, safer, and more accessible while helping customers discover quality products from brands they can trust.',
    ),
    _AboutSection(
      icon: Icons.visibility_outlined,
      title: 'Vision',
      body:
          'We aim to become a reliable digital marketplace for Myanmar brands, where every customer can shop with confidence and every brand can grow with better tools and stronger visibility.',
    ),
    _AboutSection(
      icon: Icons.shopping_bag_outlined,
      title: 'What We Offer',
      body:
          'Burma Brands offers product browsing, brand profiles, direct brand contact, carts and orders, product ratings, wishlist features, delivery address management, and reporting tools for safer shopping.',
    ),
    _AboutSection(
      icon: Icons.verified_user_outlined,
      title: 'Why Choose Us',
      body:
          'Brands on the platform are verified by the Burma Brands Team, and customers can view shop information, contact brands directly, and report inappropriate content when needed.',
    ),
    _AboutSection(
      icon: Icons.favorite_border,
      title: 'Our Values',
      body:
          'We value trust, local growth, clear communication, customer safety, and fair opportunities for Myanmar businesses. Every feature is designed to make shopping and selling feel more dependable.',
    ),
    _AboutSection(
      icon: Icons.contact_support_outlined,
      title: 'Contact Us',
      body:
          'For help, questions, reports, or partnership inquiries, please contact the Burma Brands Team through the official support channels shared by the app team. We will do our best to respond as soon as possible.',
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
          Container(
            width: 72,
            height: 72,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Image.asset(
              'assets/icon_button.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Burma Brands',
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Connecting customers with trusted local brands across Myanmar.',
                  style: TextStyle(
                    color: AppColors.subtleText,
                    fontFamily: AppFonts.primary,
                    fontSize: 14,
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
              ],
            ),
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
  });

  final IconData icon;
  final String title;
  final String body;
}
