const Map<String, String> _paymentTypeAssets = {
  'a+wallet': 'assets/images/A+Wallet.png',
  'apluswallet': 'assets/images/A+Wallet.png',
  'ayabanking': 'assets/images/AYABanking.png',
  'ayapay': 'assets/images/AYAPay.png',
  'cbbanking': 'assets/images/CBBanking.jpg',
  'cbpay': 'assets/images/CBPay.png',
  'kbzbanking': 'assets/images/KBZBanking.png',
  'kbzpay': 'assets/images/KBZPay.png',
  'mabbanking': 'assets/images/MABBanking.jpg',
  'ok': 'assets/images/OK\$.png',
  'ok\$': 'assets/images/OK\$.png',
  'onepay': 'assets/images/OnePay.png',
  'trustypay': 'assets/images/TrustyPay.jpg',
  'uabbanking': 'assets/images/UABBanking.jpg',
  'uabpay': 'assets/images/UABPay.png',
  'wavepay': 'assets/images/WavePay.png',
  'yomabanking': 'assets/images/YomaBanking.png',
};

String? paymentTypeAsset(String paymentType) {
  return _paymentTypeAssets[_paymentTypeKey(paymentType)];
}

String _paymentTypeKey(String paymentType) {
  return paymentType.trim().toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9+$]'),
    '',
  );
}
