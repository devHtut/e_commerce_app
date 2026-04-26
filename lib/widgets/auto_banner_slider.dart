import 'dart:async';
import 'package:flutter/material.dart';

import '../theme_config.dart';

class BannerItem {
  final String title;
  final String subtitle;
  final String description;
  final String imageUrl;
  final Color backgroundColor;

  const BannerItem({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imageUrl,
    this.backgroundColor = AppColors.primaryGreen,
  });
}

class AutoBannerSlider extends StatefulWidget {
  final List<BannerItem> banners;

  const AutoBannerSlider({super.key, required this.banners});

  @override
  State<AutoBannerSlider> createState() => _AutoBannerSliderState();
}

class _AutoBannerSliderState extends State<AutoBannerSlider> {
  final _controller = PageController();
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startAutoSlide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startAutoSlide() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || widget.banners.isEmpty) return;
      _currentIndex = (_currentIndex + 1) % widget.banners.length;
      _controller.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemCount: widget.banners.length,
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: banner.backgroundColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          banner.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: banner.backgroundColor),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              banner.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.bold,
                                fontFamily: AppFonts.primary,
                              ),
                            ),
                            Text(
                              banner.subtitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                fontFamily: AppFonts.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              banner.description,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: AppFonts.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.banners.length, (index) {
            final isActive = _currentIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: isActive ? 18 : 6,
              decoration: BoxDecoration(
                color: isActive ? AppColors.primaryGreen : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
      ],
    );
  }
}
