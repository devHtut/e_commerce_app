import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme_config.dart';
import 'pwa_install_service.dart';

class PwaInstallPromptGate extends StatefulWidget {
  const PwaInstallPromptGate({super.key, required this.child});

  final Widget child;

  @override
  State<PwaInstallPromptGate> createState() => _PwaInstallPromptGateState();
}

class _PwaInstallPromptGateState extends State<PwaInstallPromptGate> {
  final PwaInstallService _service = PwaInstallService.instance;
  bool _promptOpen = false;

  @override
  void initState() {
    super.initState();
    _service.initialize();
    _service.engagementNotifier.addListener(_maybeShowPrompt);
  }

  @override
  void dispose() {
    _service.engagementNotifier.removeListener(_maybeShowPrompt);
    super.dispose();
  }

  void _recordInteraction() {
    _service.recordInteraction();
    _maybeShowPrompt();
  }

  void _maybeShowPrompt() {
    if (!mounted || _promptOpen || !_service.shouldShowPrompt()) return;
    _promptOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_service.shouldShowPrompt()) {
        _promptOpen = false;
        return;
      }
      await _showInstallSheet();
      if (mounted) _promptOpen = false;
    });
  }

  Future<void> _showInstallSheet() {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        CupertinoIcons.square_arrow_down,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Install Burma Brands',
                        style: TextStyle(
                          color: AppColors.darkText,
                          fontFamily: AppFonts.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Install this app for a better mobile experience.',
                  style: TextStyle(
                    color: AppColors.subtleText,
                    fontFamily: AppFonts.primary,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
                if (_service.isIosSafari) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'On iPhone Safari: tap Share, then Add to Home Screen.',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _service.markDismissed();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.darkText,
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: AppColors.lightGrey),
                        ),
                        child: const Text('Later'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_service.isIosSafari) {
                            _service.markDismissed();
                          } else {
                            await _service.promptInstall();
                          }
                          if (context.mounted) Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: const Text('Install'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _recordInteraction(),
      child: widget.child,
    );
  }
}

class PwaInstallNavigationObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    PwaInstallService.instance.recordPageVisit();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    PwaInstallService.instance.recordPageVisit();
  }
}
