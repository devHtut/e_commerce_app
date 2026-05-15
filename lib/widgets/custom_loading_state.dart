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

  const ButtonLoadingDots({
    super.key,
    this.width = 72,
    this.height = 36,
  });

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      kButtonLoadingAnimation,
      width: width,
      height: height,
      fit: BoxFit.contain,
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
