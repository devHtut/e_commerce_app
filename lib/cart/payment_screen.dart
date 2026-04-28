import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_user_service.dart';
import '../theme_config.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_pop_up.dart';
import '../home/home_screen.dart';
import 'cart_item.dart';
import 'cart_service.dart';

class PaymentScreen extends StatefulWidget {
  final List<CartItem> items;

  const PaymentScreen({super.key, required this.items});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  List<Map<String, dynamic>> _paymentMethods = [];
  String? _selectedPaymentMethodId;
  PlatformFile? _selectedScreenshot;
  Uint8List? _screenshotPreview;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    if (widget.items.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final brandId = widget.items.first.product.brandId;
    if (brandId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final payments = await AuthUserService.getVendorPayments(brandId);
      setState(() {
        _paymentMethods = payments;
        if (payments.isNotEmpty) {
          _selectedPaymentMethodId = payments.first['id'].toString();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickScreenshot() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final selected = result.files.first;
    setState(() {
      _selectedScreenshot = selected;
      _screenshotPreview = selected.bytes;
    });
  }

  Future<void> _makePayment() async {
    if (_selectedPaymentMethodId == null || _selectedScreenshot == null) {
      await showCustomPopup(
        context,
        title: 'Validation failed',
        message: 'Please select a payment method and upload a screenshot.',
        type: PopupType.error,
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // Upload screenshot to Supabase storage
      final filename =
          'payment_screenshots/${DateTime.now().millisecondsSinceEpoch}_${_selectedScreenshot!.name}';
      final screenshotData = _selectedScreenshot!.bytes;
      if (screenshotData == null) {
        await showCustomPopup(
          context,
          title: 'Upload failed',
          message: 'Unable to read the selected screenshot file.',
          type: PopupType.error,
        );
        return;
      }

      final ext = (_selectedScreenshot!.extension ?? '').toLowerCase();
      final String? contentType = switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'bmp' => 'image/bmp',
        _ => null,
      };

      await Supabase.instance.client.storage
          .from('media')
          .uploadBinary(
            filename,
            screenshotData,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );

      // Here you could save the order with payment info, but for now just show success
      // TODO: Integrate with order service to save order and payment details

      // Remove items from cart
      for (final item in widget.items) {
        await CartService.instance.removeItem(item.id);
      }

      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Payment successful',
        message:
            'You made payment for the order successfully! Please wait for the admin response.',
        type: PopupType.success,
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Payment failed',
        message: 'Unable to process payment. Please try again.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Payment',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            color: AppColors.darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Complete your payment',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a payment method and upload your payment screenshot.',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Payment Method',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFamily: AppFonts.primary,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentMethodId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      items: _paymentMethods.map((payment) {
                        return DropdownMenuItem(
                          value: payment['id'].toString(),
                          child: Text(
                            '${payment['payment_type']} - ${payment['account_name']} (${payment['account_number']})',
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedPaymentMethodId = value);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a payment method.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Payment Screenshot',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFamily: AppFonts.primary,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickScreenshot,
                      child: Container(
                        width: double.infinity,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: _screenshotPreview == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt_outlined,
                                    size: 40,
                                    color: AppColors.subtleText,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Tap to upload screenshot',
                                    style: TextStyle(
                                      color: AppColors.subtleText,
                                    ),
                                  ),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.memory(
                                  _screenshotPreview!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: _isProcessing
                          ? const Center(child: CircularProgressIndicator())
                          : CustomButton(
                              text: 'Make Payment',
                              onPressed: _makePayment,
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
