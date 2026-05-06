import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_user_service.dart';
import '../auth/signin_screen.dart';
import '../auth/vendor_access.dart';
import '../theme_config.dart';
import '../widgets/custom_pop_up.dart';
import 'vendor_business_info_screen.dart';
import 'vendor_info_screen.dart';
import 'vendor_social_links_screen.dart';

class BrandAccountSettingsScreen extends StatefulWidget {
  const BrandAccountSettingsScreen({super.key});

  @override
  State<BrandAccountSettingsScreen> createState() =>
      _BrandAccountSettingsScreenState();
}

class _BrandAccountSettingsScreenState
    extends State<BrandAccountSettingsScreen> {
  bool _isLoading = true;
  bool _vendorAccessOk = false;
  Map<String, dynamic>? _brand;
  String _userEmail = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final ok = await VendorAccess.ensureVendorOrRedirect(context);
    if (!mounted || !ok) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final brand = await AuthUserService.getVendorBrand(user.id);
    if (!mounted) return;

    setState(() {
      _vendorAccessOk = true;
      _brand = brand;
      _userEmail = user.email ?? '';
      _isLoading = false;
    });
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    await showCustomPopup(
      context,
      title: 'Logged out',
      message: 'You have been signed out successfully.',
      type: PopupType.success,
    );
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const SignInScreen()),
          (route) => false,
    );
  }

  Future<void> _showLogoutConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_vendorAccessOk || _isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final brandName = _brand?['brand_name']?.toString().trim() ?? 'Brand Name';
    final brandDescription = _brand?['description']?.toString().trim() ?? '';
    final logoUrl = _brand?['logo_url']?.toString().trim();
    final displayEmail = _userEmail.isNotEmpty ? _userEmail : 'No email';
    final initials = brandName.isNotEmpty
        ? brandName[0].toUpperCase()
        : (displayEmail.isNotEmpty ? displayEmail[0].toUpperCase() : 'B');

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: logoUrl != null && logoUrl.isNotEmpty
                          ? Image.network(
                        logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade100,
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                              fontFamily: AppFonts.primary,
                            ),
                          ),
                        ),
                      )
                          : Container(
                        color: Colors.grey.shade100,
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                            fontFamily: AppFonts.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          brandName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                            fontFamily: AppFonts.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          displayEmail,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontFamily: AppFonts.primary,
                          ),
                        ),
                        if (brandDescription.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            brandDescription,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.subtleText,
                              fontFamily: AppFonts.primary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.store_outlined,
                      color: AppColors.primaryGreen,
                    ),
                    title: const Text(
                      'Manage Brand Profile',
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VendorInfoScreen(),
                        ),
                      ).then((_) => _loadData());
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.business_outlined,
                      color: AppColors.primaryGreen,
                    ),
                    title: const Text(
                      'Manage Business Info',
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VendorBusinessInfoScreen(
                            continueToSocialLinks: false,
                          ),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(
                      Icons.link_outlined,
                      color: AppColors.primaryGreen,
                    ),
                    title: const Text(
                      'Manage Social Media Links',
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const VendorSocialLinksScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.redAccent,
                    ),
                    onTap: _showLogoutConfirmation,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
