import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_user_service.dart';
import '../order/order_service.dart';
import '../theme_config.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_pop_up.dart';
import '../widgets/discard_changes_dialog.dart';
import '../widgets/price_formatter.dart';
import '../customer/home_screen.dart';
import 'cart_item.dart';
import 'cart_service.dart';

class PaymentScreen extends StatefulWidget {
  final List<CartItem> items;
  final String shippingAddressId;

  const PaymentScreen({
    super.key,
    required this.items,
    required this.shippingAddressId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  List<Map<String, dynamic>> _paymentMethods = [];
  String? _selectedPaymentMethodId;
  final TextEditingController _transactionController = TextEditingController();
  PlatformFile? _selectedScreenshot;
  Uint8List? _screenshotPreview;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  @override
  void dispose() {
    _transactionController.dispose();
    super.dispose();
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
      final payments = await AuthUserService.getVendorPaymentsByBrand(brandId);
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

  bool get _hasDraftInput {
    return _transactionController.text.trim().isNotEmpty ||
        _selectedScreenshot != null;
  }

  Future<void> _requestLeave() async {
    if (_isProcessing) return;
    if (!_hasDraftInput ||
        await showDiscardChangesDialog(
          context,
          title: 'Discard payment?',
          message:
              'Your payment information is not submitted yet. Are you sure you want to leave this screen?',
        )) {
      _popAfterAllow();
    }
  }

  void _popAfterAllow() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pop(context);
    });
  }

  Widget _buildOrderSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Order Details',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    color: AppColors.darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ...widget.items.map((item) => _OrderItemTile(item: item)),
        ],
      ),
    );
  }

  Widget _buildReviewSummary(double subtotal) {
    const promo = 0.00;
    final totalPayment = subtotal - promo;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: AppColors.primaryGreen,
                size: 20,
              ),
              SizedBox(width: 10),
              Text(
                'Review Summary',
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  color: AppColors.darkText,
                  fontWeight: FontWeight.w600,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Subtotal (${widget.items.length} items)',
            value: formatKyat(subtotal),
          ),
          const SizedBox(height: 8),
          _SummaryRow(label: 'Promo', value: formatDiscountKyat(promo)),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Total Payment',
            value: formatKyat(totalPayment),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Future<void> _makePayment() async {
    final transactionId = _transactionController.text.trim();
    if (_selectedPaymentMethodId == null || _selectedScreenshot == null) {
      await showCustomPopup(
        context,
        title: 'Validation failed',
        message:
            'Choose one of the Payment Method and upload a screenshot after make payment!',
        type: PopupType.error,
      );
      return;
    }
    if (transactionId.length != 6) {
      await showCustomPopup(
        context,
        title: 'Validation failed',
        message: 'Please enter the last 6 digits of the transaction id.',
        type: PopupType.error,
      );
      return;
    }

    setState(() => _isProcessing = true);

    String? orderId;
    var stockReserved = false;

    try {
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

      final filename =
          'payments/${DateTime.now().millisecondsSinceEpoch}_${_selectedScreenshot!.name}';
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
          .from('payments')
          .uploadBinary(
            filename,
            screenshotData,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );
      final screenshotUrl = Supabase.instance.client.storage
          .from('payments')
          .getPublicUrl(filename);

      final customer = Supabase.instance.client.auth.currentUser;
      if (customer == null) {
        throw Exception('Customer not authenticated');
      }

      final brandId = widget.items.first.product.brandId;
      final orderPayload = <String, dynamic>{
        'customer_id': customer.id,
        'status': 'pending',
        'total_price': widget.items.fold<double>(
          0,
          (sum, item) => sum + item.product.price * item.quantity,
        ),
        'shipping_address_id': widget.shippingAddressId,
        if (brandId != null && brandId.isNotEmpty) 'brand_id': brandId,
      };

      final orderRow = await Supabase.instance.client
          .from('orders')
          .insert(orderPayload)
          .select('id')
          .single();
      orderId = orderRow['id']?.toString();
      if (orderId == null || orderId.isEmpty) {
        throw Exception('Unable to create order');
      }

      final itemsToInsert = widget.items
          .map(
            (item) => {
              'order_id': orderId,
              'product_variant_id': item.variantId,
              'brand_id': item.product.brandId,
              'quantity': item.quantity,
              'price_at_purchase': item.product.price,
            },
          )
          .toList();
      await Supabase.instance.client.from('order_items').insert(itemsToInsert);
      await OrderService.instance.reserveStockForOrder(orderId);
      stockReserved = true;

      final selectedPayment = _paymentMethods.firstWhere(
        (payment) => payment['id'].toString() == _selectedPaymentMethodId,
        orElse: () => {},
      );
      if (selectedPayment.isEmpty) {
        throw Exception('Selected payment method not found');
      }
      final paymentPayload = {
        'order_id': orderId,
        'payment_method':
            '${selectedPayment['payment_type']} - ${selectedPayment['account_name']}',
        'status': 'pending',
        'transaction_id': transactionId,
        'amount': widget.items.fold<double>(
          0,
          (sum, item) => sum + item.product.price * item.quantity,
        ),
        'screenshot_url': screenshotUrl,
      };
      final paymentRow = await Supabase.instance.client
          .from('payments')
          .insert(paymentPayload)
          .select('id')
          .single();

      OrderService.instance.placeOrder(
        widget.items,
        orderId: orderId,
        status: OrderStatus.pending,
        payment: OrderPaymentDetails(
          id: paymentRow['id']?.toString() ?? '',
          paymentMethod: paymentPayload['payment_method']?.toString() ?? '',
          status: paymentPayload['status']?.toString() ?? '',
          transactionId: transactionId,
          amount: (paymentPayload['amount'] as num?)?.toDouble() ?? 0.0,
          screenshotUrl: screenshotUrl,
        ),
      );

      for (final item in widget.items) {
        await CartService.instance.removeItem(item.id);
      }

      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Payment successful',
        message:
            'You made payment for the order successfully! Please wait the admin response.',
        type: PopupType.success,
      );

      if (!mounted) return;
      _allowPop = true;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (stockReserved && orderId != null && orderId.isNotEmpty) {
        try {
          await OrderService.instance.restoreStockForOrder(orderId);
        } catch (restoreError) {
          debugPrint(
            'Unable to restore stock after payment failure: $restoreError',
          );
        }
      }
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Payment failed',
        message: e.toString().toLowerCase().contains('stock')
            ? 'Not enough stock is available for this order.'
            : 'Unable to process payment. Please try again.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightGrey,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: _requestLeave,
            icon: const Icon(Icons.arrow_back, color: AppColors.darkText),
          ),
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
                        'Choose one of the Payment Method and upload a screenshot after make payment!',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 24),
                      _buildOrderSection(),
                      const SizedBox(height: 16),
                      _buildReviewSummary(
                        widget.items.fold<double>(
                          0,
                          (sum, item) =>
                              sum + item.product.price * item.quantity,
                        ),
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
                      if (_paymentMethods.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Text(
                            'No payment methods available for this brand.',
                            style: TextStyle(color: AppColors.subtleText),
                          ),
                        )
                      else
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
                        'Please check the Account Number and Name before transfer',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: AppColors.errorRed,
                          fontFamily: AppFonts.primary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Transaction ID (last 6 digits)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: AppFonts.primary,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _transactionController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          hintText: 'Enter last 6 transaction digits',
                          counterText: '',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide(
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
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
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final CartItem item;

  const _OrderItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item.imageUrl,
              width: 72,
              height: 86,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 72,
                height: 86,
                color: Colors.grey.shade300,
                alignment: Alignment.center,
                child: const Icon(Icons.image_not_supported, size: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.primary,
                    fontSize: 16,
                    color: AppColors.darkText,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Size: ${item.size}',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Color: ${item.colorName} ',
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Qty: ${item.quantity}',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatKyat(item.subtotal),
                  style: const TextStyle(
                    fontFamily: AppFonts.primary,
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.primary,
                color: AppColors.darkText,
                fontSize: isTotal ? 16 : 15,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.primary,
              color: AppColors.darkText,
              fontSize: isTotal ? 16 : 15,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
