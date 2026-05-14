const Map<String, String> _paymentTypeAssets = {
  'a+ wallet': 'assets/images/A+Wallet.png',
  'aya banking': 'assets/images/AYABanking.png',
  'aya pay': 'assets/images/AYAPay.png',
  'cb banking': 'assets/images/CBBanking.jpg',
  'cb pay': 'assets/images/CBPay.png',
  'kbz banking': 'assets/images/KBZBanking.png',
  'kbz pay': 'assets/images/KBZPay.png',
  'mab banking': 'assets/images/MABBanking.jpg',
  'ok\$': 'assets/images/OK\$.png',
  'one pay': 'assets/images/OnePay.png',
  'trusty pay': 'assets/images/TrustyPay.jpg',
  'uab banking': 'assets/images/UABBanking.jpg',
  'uab pay': 'assets/images/UABPay.png',
  'wave pay': 'assets/images/WavePay.png',
  'yoma banking': 'assets/images/YomaBanking.png',
};

String? paymentTypeAsset(String paymentType) {
  return _paymentTypeAssets[paymentType.trim().toLowerCase()];
}
