import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_user_service.dart';
import 'delete_account_screen.dart';
import '../customer/home_screen.dart';
import '../theme_config.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';
import '../widgets/discard_changes_dialog.dart';

class ProfileInfoScreen extends StatefulWidget {
  const ProfileInfoScreen({
    super.key,
    this.initialFullName,
    this.initialUsername,
    this.initialAvatarUrl,
    this.returnToHomeAfterSave = true,
  });

  final String? initialFullName;
  final String? initialUsername;
  final String? initialAvatarUrl;
  final bool returnToHomeAfterSave;

  @override
  State<ProfileInfoScreen> createState() => _ProfileInfoScreenState();
}

class _ProfileInfoScreenState extends State<ProfileInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  PlatformFile? _selectedAvatar;
  Uint8List? _avatarPreviewBytes;
  String? _avatarUrl;
  bool _isSaving = false;
  bool _allowPop = false;
  late final String _randomLetter;

  @override
  void initState() {
    super.initState();
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    _randomLetter = letters[Random().nextInt(letters.length)];
    _fullNameController.text = widget.initialFullName ?? '';
    _usernameController.text = widget.initialUsername ?? '';
    _avatarUrl = widget.initialAvatarUrl;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
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

  bool get _hasDraftInput {
    return _fullNameController.text.trim() !=
            (widget.initialFullName ?? '').trim() ||
        _usernameController.text.trim() !=
            (widget.initialUsername ?? '').trim() ||
        _selectedAvatar != null;
  }

  Future<void> _requestLeave() async {
    if (_isSaving) return;
    if (!_hasDraftInput ||
        await showDiscardChangesDialog(
          context,
          title: 'Discard profile changes?',
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

  Future<void> _saveProfile() async {
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
      final username = _usernameController.text.trim().toLowerCase();
      final usernameAvailable = await AuthUserService.usernameAvailable(
        username,
        currentUserId: currentUser.id,
      );
      if (!usernameAvailable) {
        if (!mounted) return;
        await showCustomPopup(
          context,
          title: 'Username unavailable',
          message: 'Please choose a different username.',
          type: PopupType.error,
        );
        return;
      }

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
        '',
        username,
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
        _allowPop = true;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      } else {
        _popAfterAllow();
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

  Future<void> _showInputIssues(List<String> issues) {
    return showCustomPopup(
      context,
      title: 'Missing profile details',
      message: issues.map((issue) => '- $issue').join('\n'),
      type: PopupType.error,
    );
  }

  List<String> _collectInputIssues() {
    final issues = <String>[];
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    if (fullName.isEmpty) {
      issues.add('Full name is required.');
    }
    if (username.isEmpty) {
      issues.add('Username is required.');
    } else if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(username)) {
      issues.add('Username must use 3-24 letters, numbers, or underscores.');
    }
    return issues;
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
          leading: IconButton(
            onPressed: _requestLeave,
            icon: const Icon(CupertinoIcons.back, color: AppColors.darkText),
          ),
          title: Text(
            widget.initialFullName == null
                ? 'Complete Profile'
                : 'Edit Profile',
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
                    'Add your name, username, and optional avatar so your delivery and account look great.',
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
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
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
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey.shade100,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    _displayLetter,
                                                    style: const TextStyle(
                                                      fontSize: 42,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors
                                                          .primaryGreen,
                                                      fontFamily:
                                                          AppFonts.primary,
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
                    'How can we call you?',
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
                        return 'Name is required.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Choose a username',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: AppFonts.primary,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _usernameController,
                    hintText: 'username',
                    maxLength: 24,
                    prefixIcon: const Icon(CupertinoIcons.at),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_]')),
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        return newValue.copyWith(
                          text: newValue.text.toLowerCase(),
                          selection: newValue.selection,
                        );
                      }),
                    ],
                    validator: (value) {
                      final username = value?.trim() ?? '';
                      if (username.isEmpty) {
                        return 'Username is required.';
                      }
                      if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(username)) {
                        return 'Use 3-24 letters, numbers, or underscores.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: CustomButton(
                      isLoading: _isSaving,
                      text: widget.initialFullName == null
                          ? 'Save Profile'
                          : 'Update Profile',
                      onPressed: _saveProfile,
                    ),
                  ),
                  if (widget.initialFullName != null) ...[
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
                                    builder: (_) =>
                                        const DeleteAccountScreen(
                                          role: DeleteAccountRole.customer,
                                        ),
                                  ),
                                );
                              },
                        icon: const Icon(CupertinoIcons.delete),
                        label: const Text('Delete Account'),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
