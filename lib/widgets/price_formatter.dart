String formatKyat(num amount) {
  final rounded = amount.round();
  final sign = rounded < 0 ? '-' : '';
  final digits = rounded.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;
    buffer.write(digits[i]);
    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(',');
    }
  }

  return '$sign${buffer} Ks';
}

String formatDiscountKyat(num amount) {
  if (amount.round() == 0) return formatKyat(0);
  return '-${formatKyat(amount)}';
}
