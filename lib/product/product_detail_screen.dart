import 'package:flutter/material.dart';

import 'product_model.dart';
import '../theme_config.dart';

class ProductDetailScreen extends StatelessWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Product Detail',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            color: AppColors.darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey.shade300,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported, size: 40),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(product.name, style: AppTextStyles.header.copyWith(fontSize: 28)),
            const SizedBox(height: 8),
            Text(
              '\$${product.price.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 28,
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.bold,
                fontFamily: AppFonts.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Brand: ${product.brand}',
              style: AppTextStyles.body.copyWith(color: AppColors.darkText),
            ),
            const SizedBox(height: 6),
            Text(
              'Rating: ${product.rating.toStringAsFixed(1)}',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 20),
            const Text(
              'Product description can be shown here.',
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}
