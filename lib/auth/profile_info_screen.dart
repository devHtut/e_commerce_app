import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_user_service.dart';
import '../customer/home_screen.dart';
import '../theme_config.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';

class ProfileInfoScreen extends StatefulWidget {
  const ProfileInfoScreen({
    super.key,
    this.initialFullName,
    this.initialAvatarUrl,
    this.returnToHomeAfterSave = true,
  });

  final String? initialFullName;
  final String? initialAvatarUrl;
  final bool returnToHomeAfterSave;

  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  PlatformFile? _selectedAvatar;
  Uint8List? _avatarPreviewBytes;
  String? _avatarUrl;
  bool _isSaving = false;
  late final String _randomLetter;

  @override
  void initState() {
    super.initState();
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    _randomLetter = letters[Random().nextInt(letters.length)];
    _fullNameController.text = widget.initialFullName ?? '';
    _avatarUrl = widget.initialAvatarUrl;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final selected = result.files.first;
    setState(() {
      _selectedAvatar = selected;
      _avatarPreviewBytes = selected.bytes;
    });
  }

  String get _displayLetter {
    final text = _fullNameController.text.trim();
    if (text.isEmpty) return _randomLetter;
    return text[0].toUpperCase();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      await showCustomPopup(
        context,
        title: 'Unable to save profile',
        message: 'Please sign in again.',
        type: PopupType.error,
      );
      return;
    }

    setState(() => _isSaving = true);

    String? avatarUrl = _avatarUrl;
    try {
      if (_selectedAvatar != null) {
        final filename =
            '${DateTime.now().millisecondsSinceEpoch}_${_selectedAvatar!.name}';
        final uploadPath = 'profile avatars/${currentUser.id}/$filename';
        final avatarData = _selectedAvatar!.bytes;
        if (avatarData == null) {
          throw Exception('Unable to read avatar image.');
        }

        final ext = (_selectedAvatar!.extension ?? '').toLowerCase();
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
              avatarData,
              fileOptions: FileOptions(upsert: true, contentType: contentType),
            );
        avatarUrl = Supabase.instance.client.storage
            .from('media')
            .getPublicUrl(uploadPath);
      }

      await AuthUserService.upsertUserProfile(
        currentUser.id,
        _fullNameController.text.trim(),
        avatarUrl,
      );

      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Profile saved',
        message: 'Your profile is ready. Enjoy shopping with us!',
        type: PopupType.success,
      );

      if (!mounted) return;
      if (widget.returnToHomeAfterSave) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Save failed',
        message: 'Unable to save profile. Please try again.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: Text(
          widget.initialFullName == null ? 'Complete Profile' : 'Edit Profile',
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
                  'Tell us about yourself',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add your full name and optional avatar so your delivery and account look great.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickAvatar,
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
                                child: _avatarPreviewBytes != null
                                    ? Image.memory(
                                        _avatarPreviewBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : (_avatarUrl != null &&
                                          _avatarUrl!.isNotEmpty)
                                    ? Image.network(
                                        _avatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) {
                                          return Container(
                                            color: Colors.grey.shade100,
                                            alignment: Alignment.center,
                                            child: Text(
                                              _displayLetter,
                                              style: const TextStyle(
                                                fontSize: 42,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryGreen,
                                                fontFamily: AppFonts.primary,
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.grey.shade100,
                                        alignment: Alignment.center,
                                        child: Text(
                                          _displayLetter,
                                          style: const TextStyle(
                                            fontSize: 42,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryGreen,
                                            fontFamily: AppFonts.primary,
                                          ),
                                        ),
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
                        _selectedAvatar == null
                            ? 'Tap to upload avatar (optional)'
                            : 'Tap to change avatar',
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
                  'Full Name',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: AppFonts.primary,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                CustomTextField(
                  controller: _fullNameController,
                  hintText: 'Your full name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : CustomButton(
                          text: widget.initialFullName == null
                              ? 'Save Profile'
                              : 'Update Profile',
                          onPressed: _saveProfile,
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
