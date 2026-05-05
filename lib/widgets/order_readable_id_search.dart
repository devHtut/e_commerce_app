import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme_config.dart';

/// Compact [readableId] and [needle] to A–Z / 0–9 only for substring matching.
bool orderReadableIdMatchesSearch(String readableId, String needle) {
  final n = needle.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (n.isEmpty) return true;
  final h = readableId.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  return h.contains(n);
}

String vendorOrderSearchDisplayPrefix(String? orderPrefix) {
  final t = (orderPrefix ?? 'ORD').trim().toUpperCase();
  if (t.isEmpty) return 'ORD-';
  final core = t.replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final base = core.isEmpty ? 'ORD' : core;
  return '$base-';
}

/// Digits only; displays as `######-###` after the decoration prefix.
class VendorOrderDigitSegmentFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited =
        digits.length > 9 ? digits.substring(0, 9) : digits;
    final String display;
    if (limited.length <= 6) {
      display = limited;
    } else {
      display =
          '${limited.substring(0, 6)}-${limited.substring(6)}';
    }
    return TextEditingValue(
      text: display,
      selection: TextSelection.collapsed(offset: display.length),
    );
  }
}

String customerOrderSearchNeedleFromText(String fieldText) {
  return fieldText.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

/// Up to 3 letters, then up to 6 + 3 digits with fixed `-` separators.
class CustomerOrderReadableIdInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final letters = <String>[];
    final nums = <String>[];
    for (final ch in newValue.text.toUpperCase().split('')) {
      if (RegExp(r'[A-Z]').hasMatch(ch) && letters.length < 3) {
        letters.add(ch);
      } else if (RegExp(r'[0-9]').hasMatch(ch) && nums.length < 9) {
        nums.add(ch);
      }
    }
    final l = letters.join();
    if (l.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final n = nums.join();
    final n1 = n.length <= 6 ? n : n.substring(0, 6);
    final n2 = n.length > 6 ? n.substring(6) : '';
    var text = l;
    if (n.isNotEmpty) {
      text += '-$n1';
      if (n2.isNotEmpty) {
        text += '-$n2';
      }
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

String vendorOrderSearchNeedleFromParts(String? orderPrefix, String digitField) {
  final prefixCore = vendorOrderSearchDisplayPrefix(orderPrefix)
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '');
  final digits = digitField.replaceAll(RegExp(r'[^0-9]'), '');
  if (prefixCore.isEmpty && digits.isEmpty) return '';
  return '$prefixCore$digits';
}

class CustomerOrderReadableIdSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onNeedleChanged;

  const CustomerOrderReadableIdSearchField({
    super.key,
    required this.controller,
    required this.onNeedleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      keyboardType: TextInputType.text,
      inputFormatters: [CustomerOrderReadableIdInputFormatter()],
      onChanged: (_) =>
          onNeedleChanged(customerOrderSearchNeedleFromText(controller.text)),
      decoration: InputDecoration(
        hintText: 'ABC-000000-000',
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontFamily: AppFonts.primary,
        ),
        filled: true,
        fillColor: Colors.grey.shade200,
        prefixIcon: const Icon(Icons.search, color: Colors.black38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      style: const TextStyle(
        fontFamily: AppFonts.primary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

class VendorOrderReadableIdSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String brandOrderPrefix;
  final ValueChanged<String> onNeedleChanged;

  const VendorOrderReadableIdSearchField({
    super.key,
    required this.controller,
    required this.brandOrderPrefix,
    required this.onNeedleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final fadedPrefix = vendorOrderSearchDisplayPrefix(brandOrderPrefix);
    return Material(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.black38, size: 22),
            const SizedBox(width: 6),
            Text(
              fadedPrefix,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontFamily: AppFonts.primary,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [VendorOrderDigitSegmentFormatter()],
                onChanged: (_) => onNeedleChanged(
                  vendorOrderSearchNeedleFromParts(
                    brandOrderPrefix,
                    controller.text,
                  ),
                ),
                decoration: InputDecoration(
                  hintText: '000000-000',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontFamily: AppFonts.primary,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                style: const TextStyle(
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
