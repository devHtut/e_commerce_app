import 'package:flutter/material.dart';

import '../theme_config.dart';

class SearchBox extends StatelessWidget {
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  const SearchBox({
    super.key,
    this.hintText = 'Search trends...',
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      onTap: onTap,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Colors.black38,
          fontFamily: AppFonts.primary,
        ),
        filled: true,
        fillColor: Colors.grey.shade200,
        prefixIcon: const Icon(Icons.search, color: Colors.black38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
