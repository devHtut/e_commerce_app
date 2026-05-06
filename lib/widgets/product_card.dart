import 'package:flutter/material.dart';
import 'dart:async';

import '../product/product_model.dart';
import '../theme_config.dart';

class ProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback? onWishlistTap;
  final bool isWishlisted;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onWishlistTap,
    this.isWishlisted = false,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  Timer? _timer;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _startSliderIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id ||
        oldWidget.product.imageUrls != widget.product.imageUrls) {
      _imageIndex = 0;
      _startSliderIfNeeded();
    }
  }

  void _startSliderIfNeeded() {
    _timer?.cancel();
    final images = widget.product.galleryImages;
    if (images.length <= 1) return;
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      setState(() {
        _imageIndex = (_imageIndex + 1) % images.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.product.galleryImages;
    final imageUrl = images[_imageIndex.clamp(0, images.length - 1)];
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported, size: 28),
                    ),
                  ),
                  // Positioned(
                  //   top: 8,
                  //   left: 8,
                  //   child: Container(
                  //     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  //     decoration: BoxDecoration(
                  //       color: Colors.white.withValues(alpha: 0.9),
                  //       borderRadius: BorderRadius.circular(20),
                  //     ),
                  //     child: Row(
                  //       children: [
                  //         const Icon(Icons.star, color: Colors.amber, size: 16),
                  //         const SizedBox(width: 4),
                  //         Text(
                  //           widget.product.rating.toStringAsFixed(1),
                  //           style: const TextStyle(
                  //             fontFamily: AppFonts.primary,
                  //             fontWeight: FontWeight.w600,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black87,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: widget.onWishlistTap,
                        icon: Icon(
                          widget.isWishlisted ? Icons.favorite : Icons.favorite_border,
                          color: widget.isWishlisted ? Colors.red : Colors.white,
                        ),
                        tooltip:
                            widget.isWishlisted ? 'Remove from wishlist' : 'Add to wishlist',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
              fontFamily: AppFonts.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${widget.product.price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.bold,
              fontFamily: AppFonts.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.product.brand,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.subtleText,
              fontFamily: AppFonts.primary,
            ),
          ),
        ],
      ),
    );
  }
}
