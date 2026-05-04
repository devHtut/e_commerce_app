import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_user_service.dart';
import '../auth/vendor_access.dart';
import '../theme_config.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';
import 'vendor_dashboard.dart';

class _VendorPaymentEntry {
  String? paymentType;
  final TextEditingController accountNameController;
  final TextEditingController accountNumberController;

  _VendorPaymentEntry({
    this.paymentType,
    String accountName = '',
    String accountNumber = '',
  }) : accountNameController = TextEditingController(text: accountName),
       accountNumberController = TextEditingController(text: accountNumber);

  void dispose() {
    accountNameController.dispose();
    accountNumberController.dispose();
  }
}

class VendorBusinessInfoScreen extends StatefulWidget {
  const VendorBusinessInfoScreen({super.key});

  @override
  State<VendorBusinessInfoScreen> createState() =>
      _VendorBusinessInfoScreenState();
}

class _VendorBusinessInfoScreenState extends State<VendorBusinessInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _vendorAccessOk = false;
  Map<String, dynamic>? _brand;
  List<String> _paymentTypes = [];
  final List<_VendorPaymentEntry> _paymentEntries = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVendorThenLoad());
  }

  Future<void> _ensureVendorThenLoad() async {
    final ok = await VendorAccess.ensureVendorOrRedirect(context);
    if (!mounted || !ok) return;
    setState(() => _vendorAccessOk = true);
    _loadData();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    for (final entry in _paymentEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Unable to load vendor info',
        message: 'Please sign in again.',
        type: PopupType.error,
      );
      return;
    }

    try {
      final brand = await AuthUserService.getVendorBrand(currentUser.id);
      final paymentRows = await AuthUserService.getPaymentTypes();
      final vendor = await AuthUserService.getVendorByUser(currentUser.id);

      if (brand == null) {
        if (!mounted) return;
        await showCustomPopup(
          context,
          title: 'Vendor brand missing',
          message: 'Please complete your brand details first.',
          type: PopupType.error,
        );
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      final vendorPayments = vendor != null && vendor['id'] != null
          ? await AuthUserService.getVendorPayments(vendor['id'].toString())
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        _brand = brand;
        _paymentTypes = paymentRows
            .map((row) => row['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        _paymentEntries.clear();
        if (vendorPayments.isNotEmpty) {
          _paymentEntries.addAll(
            vendorPayments.map((payment) {
              return _VendorPaymentEntry(
                paymentType: payment['payment_type']?.toString(),
                accountName: payment['account_name']?.toString() ?? '',
                accountNumber: payment['account_number']?.toString() ?? '',
              );
            }),
          );
        } else {
          _paymentEntries.add(_VendorPaymentEntry());
        }
        _phoneController.text = vendor?['phone']?.toString() ?? '';
        _addressController.text = vendor?['address']?.toString() ?? '';
        _facebookController.text = vendor?['facebook_url']?.toString() ?? '';
        _instagramController.text = vendor?['instagram_url']?.toString() ?? '';
        _tiktokController.text = vendor?['tiktok_url']?.toString() ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Unable to load data',
        message: 'Please try again later.',
        type: PopupType.error,
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _paymentIconWidget(String type) {
    switch (type) {
      case 'KBZ Pay':
        return Image.asset('../assets/images/KBZPay.png', fit: BoxFit.contain);
      case 'Wave Pay':
        return Image.asset('../assets/images/WavePay.png', fit: BoxFit.contain);
      case 'AYA Pay':
        return Image.asset('../assets/images/AYAPay.png', fit: BoxFit.contain);
      case 'CB Pay':
        return Image.asset('../assets/images/CBPay.png', fit: BoxFit.contain);
      default:
        return const Icon(
          Icons.payment,
          color: AppColors.primaryGreen,
          size: 24,
        );
    }
  }

  Widget _buildPaymentEntry(int index, _VendorPaymentEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Payment method ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: AppFonts.primary,
                    color: AppColors.darkText,
                  ),
                ),
              ),
              if (_paymentEntries.length > 1)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _paymentEntries.removeAt(index).dispose();
                    });
                  },
                  icon: const Icon(Icons.close, color: AppColors.errorRed),
                ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: entry.paymentType,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            items: _paymentTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: _paymentIconWidget(type),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(type),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                entry.paymentType = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Select a payment type.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: entry.accountNameController,
            hintText: 'Enter payment account name',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Account name is required.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          CustomTextField(
            controller: entry.accountNumberController,
            hintText: 'Enter account number',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Account number is required.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveVendorBusinessInfo() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    final payments = _paymentEntries.map((entry) {
      return {
        'payment_type': entry.paymentType?.trim() ?? '',
        'account_name': entry.accountNameController.text.trim(),
        'account_number': entry.accountNumberController.text.trim(),
      };
    }).toList();

    if (payments.any(
      (payment) =>
          payment['payment_type']!.isEmpty ||
          payment['account_name']!.isEmpty ||
          payment['account_number']!.isEmpty,
    )) {
      await showCustomPopup(
        context,
        title: 'Validation failed',
        message: 'Please complete all payment method entries.',
        type: PopupType.error,
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final vendor = await AuthUserService.upsertVendorDetails(
        currentUser.id,
        _phoneController.text.trim(),
        _addressController.text.trim(),
        _facebookController.text.trim(),
        _instagramController.text.trim(),
        _tiktokController.text.trim().isEmpty
            ? null
            : _tiktokController.text.trim(),
      );

      final vendorId = vendor?['id']?.toString();
      if (vendorId != null) {
        await AuthUserService.replaceVendorPayments(vendorId, payments);
      }

      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Vendor setup complete',
        message: 'Your business and payment details are saved.',
        type: PopupType.success,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VendorDashboard()),
      );
    } catch (e) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Save failed',
        message: 'Unable to save vendor details. Please try again.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_vendorAccessOk) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Business Details',
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Complete your vendor setup',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                          fontFamily: AppFonts.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We already saved your brand identity. Now add your business location and payment details.',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 24),
                      if (_brand != null) _buildBrandHeader(),
                      const SizedBox(height: 24),
                      const Text(
                        'Phone Number',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: AppFonts.primary,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _phoneController,
                        hintText: 'Enter phone number',
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Phone number is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Address',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: AppFonts.primary,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _addressController,
                        hintText: 'Enter business address',
                        maxLength: 200,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Address is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Facebook URL',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: AppFonts.primary,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _facebookController,
                        hintText: 'https://facebook.com/yourpage',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Instagram URL',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: AppFonts.primary,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _instagramController,
                        hintText: 'https://instagram.com/yourpage',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'TikTok URL',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: AppFonts.primary,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _tiktokController,
                        hintText: 'https://tiktok.com/@yourpage',
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Payment Methods',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: AppFonts.primary,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._paymentEntries
                          .asMap()
                          .entries
                          .map(
                            (entry) =>
                                _buildPaymentEntry(entry.key, entry.value),
                          )
                          .toList(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _paymentEntries.add(_VendorPaymentEntry());
                                });
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add payment method'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: _isSaving
                            ? const Center(child: CircularProgressIndicator())
                            : CustomButton(
                                text: 'Finish',
                                onPressed: _saveVendorBusinessInfo,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildBrandHeader() {
    final logoUrl = _brand?['logo_url']?.toString();
    final brandName = _brand?['brand_name']?.toString() ?? 'Your Brand';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          const BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.04),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: logoUrl == null || logoUrl.isEmpty
                ? const Icon(
                    Icons.storefront_outlined,
                    size: 36,
                    color: AppColors.subtleText,
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      logoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.storefront_outlined,
                        size: 36,
                        color: AppColors.subtleText,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Brand',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    color: AppColors.subtleText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  brandName,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
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
