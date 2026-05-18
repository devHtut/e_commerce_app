import 'package:flutter/material.dart';

import '../theme_config.dart';

class VendorFaqsScreen extends StatelessWidget {
  const VendorFaqsScreen({super.key});

  static const List<_VendorFaqItem> _faqs = [
    _VendorFaqItem(
      question: 'Why can I not delete a product?',
      answer:
          'A product cannot be deleted after it has already been ordered by a customer. Instead of deleting it, leave the product active until the stock reaches 0, or update the stock to 0 when the item is no longer available.',
    ),
    _VendorFaqItem(
      question: 'Where can I contact a customer?',
      answer:
          'You can contact a customer from the order detail screen. Open the related order and use the send message button to start a conversation with that customer.',
    ),
    _VendorFaqItem(
      question: 'What if the payment is a scam?',
      answer:
          'If you believe the payment is fake, suspicious, or a scam, cancel the order and avoid processing the delivery. You can also contact the Burma Brands Team if you need support reviewing the issue.',
    ),
    _VendorFaqItem(
      question: 'What if a customer contacts me and requests to cancel?',
      answer:
          'If a customer contacts you and asks to cancel an order, you can cancel the order from your side. If payment has already been made, please arrange the refund clearly and fairly with the customer.',
    ),
    _VendorFaqItem(
      question: 'Where can I view revenues by timestamp filter?',
      answer:
          'You can view revenue information in the dashboard. The dashboard includes week, month, and year filters so you can review your revenue by different time periods.',
    ),
    _VendorFaqItem(
      question: 'How many products can I upload?',
      answer:
          'For now, each brand can upload up to 50 products. This limit helps keep product management stable while Burma Brands continues improving the vendor experience.',
    ),
    _VendorFaqItem(
      question: 'How can I quit from being a vendor at Burma Brands?',
      answer:
          'If you want to stop being a vendor, stop uploading new products and let your remaining stock reach 0. You can also edit your product stock to 0 and contact the Burma Brands Team for further support.',
    ),
    _VendorFaqItem(
      question: 'How can I contact Burma Brands Team?',
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
              child: _VendorFaqTile(faq: faq),
            );
          },
        ),
      ),
    );
  }
}

class _VendorFaqTile extends StatelessWidget {
  const _VendorFaqTile({required this.faq});

  final _VendorFaqItem faq;

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

class _VendorFaqItem {
  const _VendorFaqItem({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}
