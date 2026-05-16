import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

const String kPageLoadingAnimation = 'assets/animations/sandy_loading.json';
const String kButtonLoadingAnimation = 'assets/animations/loading_dots.json';

class CustomLoadingIndicator extends StatelessWidget {
  final double size;
  final String animationAsset;

  const CustomLoadingIndicator({
    super.key,
    this.size = 120,
    this.animationAsset = kPageLoadingAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      animationAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

class CustomLoadingCenter extends StatelessWidget {
  final double size;
  final String animationAsset;

  const CustomLoadingCenter({
    super.key,
    this.size = 120,
    this.animationAsset = kPageLoadingAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CustomLoadingIndicator(size: size, animationAsset: animationAsset),
    );
  }
}

class ButtonLoadingDots extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const ButtonLoadingDots({
    super.key,
    this.width = 70,
    this.height = 34,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final renderWidth = width * 5;
    final renderHeight = renderWidth * 9 / 16;

    return ClipRect(
      child: SizedBox(
        width: width,
        height: height,
        child: OverflowBox(
          maxWidth: renderWidth,
          maxHeight: renderHeight,
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            child: Lottie.asset(
              kButtonLoadingAnimation,
              width: renderWidth,
              height: renderHeight,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class InlineButtonLoadingDots extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const InlineButtonLoadingDots({
    super.key,
    this.width = 42,
    this.height = 24,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ButtonLoadingDots(
      width: width,
      height: height,
      color: color,
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String animationAsset;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.animationAsset = kPageLoadingAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,

        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.15),
                  alignment: Alignment.center,
                  child: CustomLoadingIndicator(
                    animationAsset: animationAsset,
                    size: 140,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
