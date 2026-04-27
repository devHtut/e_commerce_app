import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_user_service.dart';
import '../theme_config.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';
import 'vendor_dashboard.dart';

class VendorInfoScreen extends StatefulWidget {
  const VendorInfoScreen({super.key});

  @override
  State<VendorInfoScreen> createState() => _VendorInfoScreenState();
}

class _VendorInfoScreenState extends State<VendorInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _brandNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _logoUrlController = TextEditingController();
  PlatformFile? _selectedLogo;
  Uint8List? _logoPreviewBytes;
  bool _isSaving = false;

  @override
  void dispose() {
    _brandNameController.dispose();
    _descriptionController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final selected = result.files.first;
    setState(() {
      _selectedLogo = selected;
      _logoPreviewBytes = selected.bytes;
      _logoUrlController.text = '';
    });
  }

  Future<void> _saveVendorInfo() async {
    if (!_formKey.currentState!.validate()) return;

    final brandName = _brandNameController.text.trim();
    final description = _descriptionController.text.trim();
    final manualLogoUrl = _logoUrlController.text.trim();
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      await _showErrorPopup('Unable to detect user. Please sign in again.');
      return;
    }

    if (_selectedLogo == null && manualLogoUrl.isEmpty) {
      await _showErrorPopup('Please select a logo image or enter a logo URL.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      String logoUrl = manualLogoUrl;
      if (_selectedLogo != null) {
        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_${_selectedLogo!.name}';
        final uploadPath = '${currentUser.id}/$filename';
        final logoData = _selectedLogo!.bytes;
        if (logoData == null) {
          await _showErrorPopup('Unable to read the selected logo file.');
          return;
        }
        await Supabase.instance.client.storage
            .from('brand_logos')
            .uploadBinary(uploadPath, logoData);
        logoUrl = Supabase.instance.client.storage
            .from('brand_logos')
            .getPublicUrl(uploadPath);
      }

      await AuthUserService.createVendorBrandProfile(
        currentUser.id,
        brandName,
        description,
        logoUrl,
      );

      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Vendor information saved',
        message: 'Your brand profile is ready. Welcome aboard!',
        type: PopupType.success,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VendorDashboard()),
      );
    } on AuthException catch (e) {
      await _showErrorPopup(e.message);
    } catch (e) {
      await _showErrorPopup('Unable to save vendor info. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _showErrorPopup(String message) {
    return showCustomPopup(
      context,
      title: 'Something went wrong',
      message: message,
      type: PopupType.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Complete Vendor Info',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            color: AppColors.darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Brand Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add your brand name, logo and description so customers can recognize your store.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 24),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _pickLogo,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 18,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.upload_file,
                            color: AppColors.primaryGreen,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedLogo?.name ?? 'Upload brand logo',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontFamily: AppFonts.primary,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Colors.black38,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_logoPreviewBytes != null) ...[
                  const SizedBox(height: 14),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.memory(
                        _logoPreviewBytes!,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Text(
                  'Brand Name',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: AppFonts.primary,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _brandNameController,
                  hintText: 'Enter brand name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Brand name is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Brand Description',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: AppFonts.primary,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _descriptionController,
                  hintText: 'Tell us about your brand',
                  maxLength: 200,
                  keyboardType: TextInputType.multiline,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Description is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'Logo URL (optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: AppFonts.primary,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _logoUrlController,
                  hintText: 'Enter logo URL if you do not want to upload',
                  keyboardType: TextInputType.url,
                  validator: (value) {
                    if ((_selectedLogo == null || _logoPreviewBytes == null) &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Please upload a logo or provide a logo URL.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : CustomButton(
                          text: 'Save and Continue',
                          onPressed: _saveVendorInfo,
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
