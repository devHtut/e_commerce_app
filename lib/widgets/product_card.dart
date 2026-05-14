import 'package:flutter/material.dart';
import 'dart:async';

import '../product/product_model.dart';
import '../product/product_review_service.dart';
import '../product/product_sales_service.dart';
import '../theme_config.dart';
import 'price_formatter.dart';

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
  late Future<ProductEngagementMetrics> _metricsFuture;
  late Future<ProductReviewSummary> _reviewSummaryFuture;

  @override
  void initState() {
    super.initState();
    _metricsFuture = ProductSalesService.instance.loadMetrics(
      widget.product.id,
    );
    _reviewSummaryFuture = ProductReviewService.instance.loadSummary(
      widget.product.id,
    );
    _startSliderIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id ||
        oldWidget.product.imageUrls != widget.product.imageUrls) {
      _imageIndex = 0;
      _metricsFuture = ProductSalesService.instance.loadMetrics(
        widget.product.id,
      );
      _reviewSummaryFuture = ProductReviewService.instance.loadSummary(
        widget.product.id,
      );
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
    final hasPromotion = widget.product.hasPromotion;
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
                  Positioned(
                    top: 8,
                    left: 8,
                    child: FutureBuilder<ProductEngagementMetrics>(
                      future: _metricsFuture,
                      builder: (context, snapshot) {
                        final metrics =
                            snapshot.data ?? ProductEngagementMetrics.empty;
                        return _ProductCardBadges(
                          promotionPercent: hasPromotion
                              ? widget.product.promotionPercent
                              : null,
                          soldCount: metrics.soldCount,
                          viewCount: metrics.viewCount,
                        );
                      },
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
                  if (widget.onWishlistTap != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black87,
                        shape: const CircleBorder(),
                        child: IconButton(
                          onPressed: widget.onWishlistTap,
                          icon: Icon(
                            widget.isWishlisted
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: widget.isWishlisted
                                ? Colors.red
                                : Colors.white,
                          ),
                          tooltip: widget.isWishlisted
                              ? 'Remove from wishlist'
                              : 'Add to wishlist',
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
          hasPromotion
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatKyat(widget.product.promoPrice!),
                      style: const TextStyle(
                        fontSize: 18,
                        color: AppColors.errorRed,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppFonts.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatKyat(widget.product.promoRegularPrice!),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.subtleText,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppFonts.primary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                )
              : Text(
                  formatKyat(widget.product.price),
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
          FutureBuilder<ProductReviewSummary>(
            future: _reviewSummaryFuture,
            builder: (context, snapshot) {
              final summary = snapshot.data ?? ProductReviewSummary.empty;
              if (summary.reviewCount < 3) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Color(0xFFFFB300)),
                    const SizedBox(width: 3),
                    Text(
                      '${summary.averageRating.toStringAsFixed(1)} (${summary.reviewCount})',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          FutureBuilder<ProductEngagementMetrics>(
            future: _metricsFuture,
            builder: (context, snapshot) {
              final soldCount = snapshot.data?.soldCount ?? 0;
              if (soldCount < 5) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '$soldCount sold',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryGreen,
                    fontFamily: AppFonts.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProductCardBadges extends StatelessWidget {
  final int? promotionPercent;
  final int soldCount;
  final int viewCount;

  const _ProductCardBadges({
    required this.promotionPercent,
    required this.soldCount,
    required this.viewCount,
  });

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (promotionPercent != null)
        _BadgePill(label: '-$promotionPercent%', color: AppColors.errorRed),
      if (soldCount >= 5)
        const _BadgePill(label: 'Best Seller', color: Color(0xFFE65100)),
      if (viewCount >= 5)
        const _BadgePill(label: 'Most Viewed', color: Color(0xFF006D77)),
    ];
    if (badges.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < badges.length; i++) ...[
          if (i > 0) const SizedBox(height: 5),
          badges[i],
        ],
      ],
    );
  }
}

class _BadgePill extends StatelessWidget {
  final String label;
  final Color color;

  const _BadgePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          fontFamily: AppFonts.primary,
        ),
      ),
    );
  }
}
