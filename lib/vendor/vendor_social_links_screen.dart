import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_user_service.dart';
import '../auth/vendor_access.dart';
import '../theme_config.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';
import 'vendor_dashboard.dart';

class VendorSocialLinksScreen extends StatefulWidget {
  const VendorSocialLinksScreen({super.key, this.isOnboarding = false});

  final bool isOnboarding;

  @override
  State<VendorSocialLinksScreen> createState() =>
      _VendorSocialLinksScreenState();
}

class _VendorSocialLinksScreenState extends State<VendorSocialLinksScreen> {
  final _formKey = GlobalKey<FormState>();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _vendorAccessOk = false;
  Map<String, dynamic>? _brand;

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
    _facebookController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Unable to load social links',
        message: 'Please sign in again.',
        type: PopupType.error,
      );
      return;
    }

    try {
      final brand = await AuthUserService.getVendorBrand(currentUser.id);
      final vendor = await AuthUserService.getVendorByUser(currentUser.id);

      if (!mounted) return;
      setState(() {
        _brand = brand;
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSocialLinks() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isSaving = true);

    try {
      await AuthUserService.updateVendorSocialLinks(
        userId: currentUser.id,
        facebookUrl: _facebookController.text.trim(),
        instagramUrl: _instagramController.text.trim(),
        tiktokUrl: _tiktokController.text.trim().isEmpty
            ? null
            : _tiktokController.text.trim(),
      );

      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Social links saved',
        message: 'Your social media links are saved.',
        type: PopupType.success,
      );

      if (!mounted) return;
      _finish();
    } catch (e) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Save failed',
        message: 'Unable to save social links. Please try again.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _skipSocialLinks() {
    _finish();
  }

  void _finish() {
    if (widget.isOnboarding) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const VendorDashboard()),
        (route) => false,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_vendorAccessOk) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: const Text(
          'Social Media Links',
          style: AppTextStyles.appBarTitle,
        ),
        automaticallyImplyLeading: !widget.isOnboarding,
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
                        'Add social media links',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                          fontFamily: AppFonts.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Help customers find your brand on social platforms. '
                        'You can skip this now and update it later in account settings.',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 24),
                      if (_brand != null) _buildBrandHeader(),
                      const SizedBox(height: 24),
                      _buildFieldLabel('Facebook URL'),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _facebookController,
                        hintText: 'https://facebook.com/yourpage',
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                      _buildFieldLabel('Instagram URL'),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _instagramController,
                        hintText: 'https://instagram.com/yourpage',
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                      _buildFieldLabel('TikTok URL'),
                      const SizedBox(height: 8),
                      CustomTextField(
                        controller: _tiktokController,
                        hintText: 'https://tiktok.com/@yourpage',
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: _isSaving
                            ? const Center(child: CircularProgressIndicator())
                            : CustomButton(
                                text: widget.isOnboarding
                                    ? 'Save & Finish'
                                    : 'Save Links',
                                onPressed: _saveSocialLinks,
                              ),
                      ),
                      if (widget.isOnboarding) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : _skipSocialLinks,
                            child: const Text('Skip for now'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontFamily: AppFonts.primary,
        color: AppColors.darkText,
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
        boxShadow: const [
          BoxShadow(
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
