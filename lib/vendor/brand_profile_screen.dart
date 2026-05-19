import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/delete_account_screen.dart';
import '../auth/auth_user_service.dart';
import '../auth/vendor_access.dart';
import '../theme_config.dart';
import '../widgets/custom_loading_state.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';
import '../widgets/discard_changes_dialog.dart';
import '../utils/image_upload_optimizer.dart';

class BrandProfileScreen extends StatefulWidget {
  const BrandProfileScreen({super.key});

  @override
  State<BrandProfileScreen> createState() => _BrandProfileScreenState();
}

class _BrandProfileScreenState extends State<BrandProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _brandNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _prefixController = TextEditingController();

  PlatformFile? _selectedLogo;
  Uint8List? _logoPreviewBytes;
  String? _existingLogoUrl;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _allowPop = false;
  bool _vendorAccessOk = false;
  String _initialBrandName = '';
  String _initialDescription = '';
  String _initialPrefix = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBrandProfile());
  }

  @override
  void dispose() {
    _brandNameController.dispose();
    _prefixController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadBrandProfile() async {
    final ok = await VendorAccess.ensureVendorOrRedirect(context);
    if (!mounted || !ok) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      await _showErrorPopup('Unable to detect user. Please sign in again.');
      return;
    }

    final brand = await AuthUserService.getVendorBrand(currentUser.id);
    if (!mounted) return;

    _brandNameController.text = brand?['brand_name']?.toString() ?? '';
    _descriptionController.text = brand?['description']?.toString() ?? '';
    _prefixController.text = brand?['prefix']?.toString().toUpperCase() ?? '';
    _existingLogoUrl = brand?['logo_url']?.toString();
    _initialBrandName = _brandNameController.text;
    _initialDescription = _descriptionController.text;
    _initialPrefix = _prefixController.text;

    setState(() {
      _vendorAccessOk = true;
      _isLoading = false;
    });
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

  bool get _hasDraftInput {
    return _brandNameController.text.trim() != _initialBrandName.trim() ||
        _descriptionController.text.trim() != _initialDescription.trim() ||
        _prefixController.text.trim().toUpperCase() !=
            _initialPrefix.trim().toUpperCase() ||
        _selectedLogo != null;
  }

  Future<void> _requestLeave() async {
    if (_isSaving) return;
    if (!_hasDraftInput ||
        await showDiscardChangesDialog(
          context,
          title: 'Discard brand changes?',
        )) {
      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
      });
    }
  }

  Future<void> _saveBrandProfile() async {
    final inputIssues = _collectInputIssues();
    if (inputIssues.isNotEmpty) {
      await _showInputIssues(inputIssues);
      _formKey.currentState!.validate();
      return;
    }
    if (!_formKey.currentState!.validate()) {
      await _showInputIssues(['Please check the highlighted fields.']);
      return;
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      await _showErrorPopup('Unable to detect user. Please sign in again.');
      return;
    }

    final existingLogo = _existingLogoUrl?.trim() ?? '';
    if (_selectedLogo == null && existingLogo.isEmpty) {
      await _showErrorPopup('Please select a brand logo image.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      var logoUrl = existingLogo;
      if (_selectedLogo != null) {
        final logoData = _selectedLogo!.bytes;
        if (logoData == null) {
          await _showErrorPopup('Unable to read the selected logo file.');
          return;
        }
        final optimizedLogo = await optimizeImageForUpload(
          bytes: logoData,
          originalName: _selectedLogo!.name,
          maxDimension: 900,
          jpegQuality: 82,
        );

        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_${optimizedLogo.name}';
        final uploadPath = 'brand logos/${currentUser.id}/$filename';

        await Supabase.instance.client.storage
            .from('media')
            .uploadBinary(
              uploadPath,
              optimizedLogo.bytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: optimizedLogo.contentType,
              ),
            );
        logoUrl = Supabase.instance.client.storage
            .from('media')
            .getPublicUrl(uploadPath);
      }

      await AuthUserService.upsertVendorBrandProfile(
        currentUser.id,
        _brandNameController.text.trim(),
        _descriptionController.text.trim(),
        logoUrl,
        _prefixController.text.trim().toUpperCase(),
      );

      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Brand profile updated',
        message: 'Your brand profile has been saved successfully.',
        type: PopupType.success,
      );

      if (!mounted) return;
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context, true);
      });
    } on AuthException catch (e) {
      await _showErrorPopup(e.message);
    } catch (_) {
      await _showErrorPopup('Unable to save brand profile. Please try again.');
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

  Future<void> _showInputIssues(List<String> issues) {
    return showCustomPopup(
      context,
      title: 'Missing brand details',
      message: issues.map((issue) => '- $issue').join('\n'),
      type: PopupType.error,
    );
  }

  List<String> _collectInputIssues() {
    final issues = <String>[];
    final brandName = _brandNameController.text.trim();
    final prefix = _prefixController.text.trim().toUpperCase();
    final description = _descriptionController.text.trim();
    final hasLogo =
        _selectedLogo != null || (_existingLogoUrl?.trim().isNotEmpty ?? false);
    if (brandName.isEmpty) {
      issues.add('Brand name is required.');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(prefix)) {
      issues.add('Order ID prefix must be 3 capital letters A-Z.');
    }
    if (description.isEmpty) {
      issues.add('Brand description is required.');
    }
    if (!hasLogo) {
      issues.add('Brand logo image is required.');
    }
    return issues;
  }

  Widget _buildLogoPreview() {
    if (_logoPreviewBytes != null) {
      return Image.memory(_logoPreviewBytes!, fit: BoxFit.cover);
    }

    final logoUrl = _existingLogoUrl?.trim();
    if (logoUrl != null && logoUrl.isNotEmpty) {
      return Image.network(
        logoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildLogoPlaceholder(),
      );
    }

    return _buildLogoPlaceholder();
  }

  Widget _buildLogoPlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      alignment: Alignment.center,
      child: const Icon(
        CupertinoIcons.bag,
        size: 40,
        color: AppColors.subtleText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_vendorAccessOk || _isLoading) {
      return const Scaffold(body: CustomLoadingCenter());
    }

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightGrey,
        appBar: AppBar(
          leading: IconButton(
            onPressed: _requestLeave,
            icon: const Icon(CupertinoIcons.back, color: AppColors.darkText),
          ),
          title: const Text(
            'Manage Brand Profile',
            style: AppTextStyles.appBarTitle,
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
                    'Update your brand name, logo and description so customers can recognize your store.',
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
                                child: ClipOval(child: _buildLogoPreview()),
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
                                  CupertinoIcons.camera,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _existingLogoUrl == null && _selectedLogo == null
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
                    'Order ID prefix',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: AppFonts.primary,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _prefixController,
                    hintText: 'e.g. PDT (shown as PDT- on orders)',
                    maxLength: 3,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Z]')),
                      LengthLimitingTextInputFormatter(3),
                    ],
                    validator: (value) {
                      final prefix = value?.trim() ?? '';
                      if (!RegExp(r'^[A-Z]{3}$').hasMatch(prefix)) {
                        return 'Prefix must be 3 capital letters A-Z.';
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
                    child: CustomButton(
                      isLoading: _isSaving,
                      text: 'Save Changes',
                      onPressed: _saveBrandProfile,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _isSaving
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DeleteAccountScreen(
                                    role: DeleteAccountRole.vendor,
                                  ),
                                ),
                              );
                            },
                      icon: const Icon(CupertinoIcons.delete),
                      label: const Text('Delete Brand Account'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
