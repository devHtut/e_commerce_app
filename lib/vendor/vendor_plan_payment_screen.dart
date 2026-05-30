import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme_config.dart';
import '../widgets/copy_pill_button.dart';
import '../widgets/custom_loading_state.dart';
import '../widgets/custom_pop_up.dart';
import '../widgets/price_formatter.dart';
import '../widgets/progress_percentage_overlay.dart';
import 'vendor_plan_service.dart';

class VendorPlanPaymentScreen extends StatefulWidget {
  final VendorPlan plan;

  const VendorPlanPaymentScreen({super.key, required this.plan});

  @override
  State<VendorPlanPaymentScreen> createState() =>
      _VendorPlanPaymentScreenState();
}

class _VendorPlanPaymentScreenState extends State<VendorPlanPaymentScreen> {
  List<Map<String, dynamic>> _paymentMethods = const <Map<String, dynamic>>[];
  String? _selectedPaymentMethodId;
  PlatformFile? _selectedScreenshot;
  Uint8List? _screenshotPreview;
  bool _loading = true;
  bool _submitting = false;
  double _progress = 0;
  String _progressLabel = 'Preparing payment...';

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    try {
      final rows = await Supabase.instance.client
          .from('admin_payment_methods')
          .select(
            'id,name,account_name,account_number,qr_image_url,instructions',
          )
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      if (!mounted) return;
      setState(() {
        _paymentMethods = (rows as List<dynamic>).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickScreenshot() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _selectedScreenshot = result.files.first;
      _screenshotPreview = result.files.first.bytes;
    });
  }

  Map<String, dynamic>? get _selectedPaymentMethod {
    for (final payment in _paymentMethods) {
      if (payment['id'].toString() == _selectedPaymentMethodId) return payment;
    }
    return null;
  }

  Future<void> _submitPayment() async {
    final amount = widget.plan.priceMmk;
    if (amount == null || amount <= 0) return;
    if (_selectedPaymentMethodId == null || _selectedScreenshot == null) {
      await showCustomPopup(
        context,
        title: 'Payment required',
        message: 'Select a payment method and upload your payment screenshot.',
        type: PopupType.error,
      );
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() {
      _submitting = true;
      _progress = 0.12;
      _progressLabel = 'Checking screenshot...';
    });

    try {
      final access = await VendorPlanService.instance
          .loadAccessForCurrentVendor();
      final bytes = _selectedScreenshot!.bytes;
      if (bytes == null) throw Exception('Unable to read screenshot');
      final filename =
          'plan-payments/${DateTime.now().millisecondsSinceEpoch}_${_selectedScreenshot!.name}';
      final ext = (_selectedScreenshot!.extension ?? '').toLowerCase();
      final contentType = switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        _ => null,
      };

      _updateProgress(0.42, 'Uploading screenshot...');
      await Supabase.instance.client.storage
          .from('payments')
          .uploadBinary(
            filename,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );
      final screenshotUrl = Supabase.instance.client.storage
          .from('payments')
          .getPublicUrl(filename);

      _updateProgress(0.78, 'Submitting plan order...');
      await Supabase.instance.client.from('vendor_plan_orders').insert({
        'vendor_id': access.vendorId,
        'plan_code': widget.plan.code,
        'amount_mmk': amount,
        'status': 'submitted',
        'payment_method_id': _selectedPaymentMethodId,
        'payment_screenshot_url': screenshotUrl,
      });

      _updateProgress(1, 'Payment submitted.');
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Payment submitted',
        message: 'Your plan purchase is waiting for admin approval.',
        type: PopupType.success,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Payment failed',
        message: 'Unable to submit plan payment. Please try again.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _progress = 0;
          _progressLabel = 'Preparing payment...';
        });
      }
    }
  }

  void _updateProgress(double progress, String label) {
    if (!mounted) return;
    setState(() {
      _progress = progress.clamp(0, 1).toDouble();
      _progressLabel = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.plan.priceMmk ?? 0;
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.lightGrey,
          appBar: AppBar(
            title: const Text('Plan Payment', style: AppTextStyles.appBarTitle),
          ),
          body: SafeArea(
            child: _loading
                ? const CustomLoadingCenter()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _section(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.plan.name,
                                style: const TextStyle(
                                  color: AppColors.darkText,
                                  fontFamily: AppFonts.primary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                formatKyat(amount.toDouble()),
                                style: const TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontFamily: AppFonts.primary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${VendorPlanService.paidPlanDays} days access after admin approval',
                                style: AppTextStyles.body,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Payment Method', style: _labelStyle),
                        const SizedBox(height: 8),
                        if (_paymentMethods.isEmpty)
                          _section(
                            child: const Text(
                              'No admin payment methods are available yet.',
                              style: AppTextStyles.body,
                            ),
                          )
                        else
                          ..._paymentMethods.map(_paymentTile),
                        if (_selectedPaymentMethod != null) ...[
                          const SizedBox(height: 10),
                          _paymentDetails(_selectedPaymentMethod!),
                        ],
                        const SizedBox(height: 16),
                        const Text('Payment Screenshot', style: _labelStyle),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _submitting ? null : _pickScreenshot,
                          child: Container(
                            width: double.infinity,
                            height: 132,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _screenshotPreview == null
                                ? const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        CupertinoIcons.camera,
                                        color: AppColors.subtleText,
                                        size: 34,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Tap to upload screenshot',
                                        style: TextStyle(
                                          color: AppColors.subtleText,
                                          fontFamily: AppFonts.primary,
                                        ),
                                      ),
                                    ],
                                  )
                                : ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.memory(
                                      _screenshotPreview!,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _submitting || _paymentMethods.isEmpty
                                ? null
                                : _submitPayment,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              'Submit Payment',
                              style: AppTextStyles.button,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        if (_submitting)
          ProgressPercentageOverlay(
            title: 'Submitting payment',
            progress: _progress,
            label: _progressLabel,
          ),
      ],
    );
  }

  Widget _section({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }

  Widget _paymentTile(Map<String, dynamic> payment) {
    final id = payment['id'].toString();
    final selected = id == _selectedPaymentMethodId;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _submitting
              ? null
              : () => setState(() => _selectedPaymentMethodId = id),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primaryGreen : Colors.grey.shade300,
                width: selected ? 1.8 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? CupertinoIcons.check_mark_circled_solid
                      : CupertinoIcons.creditcard,
                  color: selected
                      ? AppColors.primaryGreen
                      : AppColors.subtleText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    payment['name']?.toString() ?? 'Payment',
                    style: const TextStyle(
                      color: AppColors.darkText,
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _paymentDetails(Map<String, dynamic> payment) {
    final qrUrl = payment['qr_image_url']?.toString() ?? '';
    final accountName = payment['account_name']?.toString() ?? '-';
    final accountNumber = payment['account_number']?.toString() ?? '-';
    final instructions = payment['instructions']?.toString() ?? '';
    return _section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (qrUrl.isNotEmpty) ...[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  qrUrl,
                  width: 180,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          _detailRow('Account Name', accountName),
          const SizedBox(height: 10),
          _detailRow('Account Number', accountNumber, copyable: true),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(instructions, style: AppTextStyles.body),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool copyable = false}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: AppColors.subtleText)),
              const SizedBox(height: 3),
              SelectableText(
                value,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontFamily: AppFonts.primary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (copyable && value.isNotEmpty && value != '-')
          CopyPillButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              await Clipboard.setData(ClipboardData(text: value));
              messenger.showSnackBar(
                const SnackBar(content: Text('Account number copied')),
              );
            },
          ),
      ],
    );
  }
}

const _labelStyle = TextStyle(
  color: AppColors.darkText,
  fontFamily: AppFonts.primary,
  fontWeight: FontWeight.w700,
);
