import 'package:flutter/foundation.dart';

class PwaInstallService {
  PwaInstallService._();

  static final PwaInstallService instance = PwaInstallService._();

  final ValueNotifier<int> engagementNotifier = ValueNotifier<int>(0);

  bool get isIosSafari => false;

  void initialize() {}

  void recordInteraction() {}

  void recordPageVisit() {}

  bool shouldShowPrompt() => false;

  Future<bool> promptInstall() async => false;

  void markDismissed() {}
}
