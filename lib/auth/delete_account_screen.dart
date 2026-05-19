import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cart/cart_service.dart';
import '../notification/notification_service.dart';
import '../notification/push_notification_service.dart';
import '../theme_config.dart';
import '../widgets/custom_pop_up.dart';
import 'account_deletion_service.dart';
import 'signin_screen.dart';

enum DeleteAccountRole { customer, vendor }

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key, required this.role});

  final DeleteAccountRole role;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final TextEditingController _confirmController = TextEditingController();
  bool _understands = false;
  bool _isDeleting = false;

  bool get _canDelete =>
      _understands &&
      _confirmController.text.trim().toUpperCase() == 'DELETE' &&
      !_isDeleting;

  bool get _isVendor => widget.role == DeleteAccountRole.vendor;

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (!_canDelete) return;

    setState(() => _isDeleting = true);
    try {
      await PushNotificationService.instance.unregisterCurrentDevice();
      final message = await AccountDeletionService.instance.deleteAccount();
      CartService.instance.clear();
      NotificationService.instance.clearUnreadCount();
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Account deleted',
        message: message,
        type: PopupType.success,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );
    } on AccountDeletionException catch (error) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: error.isBlocked ? 'Deletion blocked' : 'Unable to delete',
        message: error.message,
        type: PopupType.error,
      );
    } catch (_) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Unable to delete',
        message:
            'Unable to delete this account right now. Please contact Burma Brands Team.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isVendor ? 'Delete Brand Account' : 'Delete Account';
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.darkText),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    color: AppColors.errorRed,
                    size: 36,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontFamily: AppFonts.primary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isVendor
                        ? 'This will remove your vendor access, personal profile, payment setup, notifications, chats, and account data. Products will be stopped by setting stock to 0 where possible. Active orders must be completed, canceled, or refunded first.'
                        : 'This will remove your profile, saved addresses, cart, wishlist, notifications, chats, and account data. Active orders must be completed, canceled, or refunded first.',
                    style: const TextStyle(
                      color: AppColors.subtleText,
                      fontFamily: AppFonts.primary,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Some completed order records may be retained only when needed for receipts, safety, support, refunds, or legal records.',
                    style: TextStyle(
                      color: AppColors.subtleText,
                      fontFamily: AppFonts.primary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    value: _understands,
                    onChanged: _isDeleting
                        ? null
                        : (value) {
                            setState(() => _understands = value ?? false);
                          },
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primaryGreen,
                    title: const Text(
                      'I understand this action cannot be undone.',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Type DELETE to confirm',
                    style: TextStyle(
                      color: AppColors.darkText,
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _confirmController,
                    enabled: !_isDeleting,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.lightGrey,
                      hintText: 'DELETE',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _canDelete ? _deleteAccount : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.errorRed,
                        disabledBackgroundColor: Colors.redAccent.withOpacity(
                          0.35,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: _isDeleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: AppFonts.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
