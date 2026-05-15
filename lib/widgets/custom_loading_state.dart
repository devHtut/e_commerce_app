import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String animationAsset;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.animationAsset = 'assets/animations/sandy_loading.json',
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
                  child: Lottie.asset(animationAsset, width: 140, height: 140),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
