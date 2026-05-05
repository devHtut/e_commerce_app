import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_user_service.dart';
import '../theme_config.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';
import 'vendor_business_info_screen.dart';
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
  PlatformFile? _selectedLogo;
  Uint8List? _logoPreviewBytes;
  bool _isSaving = false;

  @override
  void dispose() {
    _brandNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final selected = result.files.first;
    setState(() {
      _selectedLogo = selected;
      _logoPreviewBytes = selected.bytes;
    });
  }

  Future<void> _saveVendorInfo() async {
    if (!_formKey.currentState!.validate()) return;

    final brandName = _brandNameController.text.trim();
    final description = _descriptionController.text.trim();
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      await _showErrorPopup('Unable to detect user. Please sign in again.');
      return;
    }

    if (_selectedLogo == null) {
      await _showErrorPopup('Please select a brand logo image.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final filename =
          '${DateTime.now().millisecondsSinceEpoch}_${_selectedLogo!.name}';
      final uploadPath = 'brand logos/${currentUser.id}/$filename';
      final logoData = _selectedLogo!.bytes;
      if (logoData == null) {
        await _showErrorPopup('Unable to read the selected logo file.');
        return;
      }

      final ext = (_selectedLogo!.extension ?? '').toLowerCase();
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
            uploadPath,
            logoData,
            fileOptions: FileOptions(upsert: true, contentType: contentType),
          );
      final logoUrl = Supabase.instance.client.storage
          .from('media')
          .getPublicUrl(uploadPath);

      await AuthUserService.upsertVendorBrandProfile(
        currentUser.id,
        brandName,
        description,
        logoUrl,
      );

      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Vendor information saved',
        message:
            'Your brand profile is ready. Please complete business details.',
        type: PopupType.success,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VendorBusinessInfoScreen()),
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
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickLogo,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 124,
                              height: 124,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 14,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _logoPreviewBytes == null
                                    ? Container(
                                        color: Colors.grey.shade100,
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.storefront_outlined,
                                          size: 40,
                                          color: AppColors.subtleText,
                                        ),
                                      )
                                    : Image.memory(
                                        _logoPreviewBytes!,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryGreen,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _selectedLogo == null
                            ? 'Tap to upload logo'
                            : 'Tap to change logo',
                        style: const TextStyle(
                          fontFamily: AppFonts.primary,
                          color: AppColors.subtleText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
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
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : CustomButton(text: 'Next', onPressed: _saveVendorInfo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
