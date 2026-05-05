import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryGreen = Color(0xFF4A6741);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkText = Colors.black87;
  static const Color subtleText = Colors.black54;
  static const Color errorRed = Colors.redAccent;
}

class AppFonts {
  static const String primary = 'SF Pro Display';
}

class AppTextStyles {
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
    fontFamily: AppFonts.primary,
  );

  static const TextStyle header = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.black87,
    fontFamily: AppFonts.primary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    color: Colors.black54,
    fontFamily: AppFonts.primary,
  );
}
