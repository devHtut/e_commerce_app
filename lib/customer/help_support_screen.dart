import 'package:flutter/material.dart';

import '../theme_config.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const List<_FaqItem> _faqs = [
    _FaqItem(
      question: 'Can I cancel the order?',
      answer:
          'Yes. You can cancel your order while it is still pending. If the order has already been confirmed and you still need to cancel it, please contact the brand directly so they can help you with the cancellation and refund process.',
    ),
    _FaqItem(
      question: 'How do I contact a brand?',
      answer:
          'You can contact a brand by sending them a message from the app or by using the phone number shown on their brand information or shop profile, when available.',
    ),
    _FaqItem(
      question: 'How can I give ratings to the product?',
      answer:
          'You can rate a product after the order has arrived to you. Once you receive the item, open your order or the product detail page and share your rating based on your experience.',
    ),
    _FaqItem(
      question: 'Where can I see brand info?',
      answer:
          'You can see brand information in the shop profile. The shop profile includes details that help you understand more about the brand before you order.',
    ),
    _FaqItem(
      question: 'Why are the product images not displaying?',
      answer:
          'Product images may not display correctly when the network connection is slow or unstable. Please check your internet connection and try refreshing the screen.',
    ),
    _FaqItem(
      question: 'How can I report violent contents?',
      answer:
          'You can report violent or inappropriate content by using the report buttons available in the chat screen and on the product detail screen. Our team will review reports to help keep Burma Brands safe.',
    ),
    _FaqItem(
      question: 'Why can we not add products from multiple brands to cart?',
      answer:
          'Products from multiple brands cannot be added to the same cart because payment is currently managed directly by each brand, not by the app yet. Please place separate orders for different brands.',
    ),
    _FaqItem(
      question: 'What if the brand does not contact me after confirming my order?',
      answer:
          'That should not happen because brands on Burma Brands are verified by the Burma Brands Team. If you still have trouble reaching a brand after your order is confirmed, please contact our team for help.',
    ),
    _FaqItem(
      question: 'How can we contact Burma Brands Team?',
      answer:
          'You can contact the Burma Brands Team through the contact information listed in the Contact & About screen.',
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
          'FAQs',
          style: TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: _faqs.length,
          itemBuilder: (context, index) {
            final faq = _faqs[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FaqTile(faq: faq),
            );
          },
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.faq});

  final _FaqItem faq;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: Colors.white,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            iconColor: AppColors.primaryGreen,
            collapsedIconColor: AppColors.subtleText,
            title: Text(
              faq.question,
              style: const TextStyle(
                color: AppColors.darkText,
                fontFamily: AppFonts.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  faq.answer,
                  style: const TextStyle(
                    color: AppColors.subtleText,
                    fontFamily: AppFonts.primary,
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}
