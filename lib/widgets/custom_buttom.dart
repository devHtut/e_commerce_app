import 'package:flutter/material.dart';
class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const CustomButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4A6741)), // Your button color
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}