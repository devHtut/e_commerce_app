import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/signin_screen.dart';
import '../theme_config.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/custom_pop_up.dart';
import 'vendor_products_screen.dart';

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  int _currentIndex = 0;

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

  static const List<String> _titles = [
    'Vendor Dashboard',
    'Products',
    'Orders',
    'Chat',
    'Account',
  ];

  Widget _buildOverviewCard({
    required IconData icon,
    required String title,
    required String value,
    required String change,
    required Color changeColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primaryGreen, size: 28),
            const SizedBox(height: 16),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontFamily: AppFonts.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.subtleText,
                fontFamily: AppFonts.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              change,
              style: TextStyle(
                fontSize: 12,
                color: changeColor,
                fontFamily: AppFonts.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              fontFamily: AppFonts.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track the latest store performance and sales metrics.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildOverviewCard(
                icon: Icons.people_alt_outlined,
                title: 'Total Visitors',
                value: '855',
                change: '+4.8%',
                changeColor: Colors.green,
              ),
              const SizedBox(width: 12),
              _buildOverviewCard(
                icon: Icons.shopping_bag_outlined,
                title: 'Total Orders',
                value: '658',
                change: '+2.5%',
                changeColor: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildOverviewCard(
                icon: Icons.remove_red_eye_outlined,
                title: 'Total Views',
                value: '788',
                change: '-1.8%',
                changeColor: Colors.red,
              ),
              const SizedBox(width: 12),
              _buildOverviewCard(
                icon: Icons.chat_bubble_outline,
                title: 'Conversion',
                value: '82%',
                change: '+2.0%',
                changeColor: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Weekly Sales',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Weekly',
                        style: TextStyle(
                          color: AppColors.darkText,
                          fontFamily: AppFonts.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 190,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildChartBar(label: 'Sun', value: 0.5),
                      _buildChartBar(label: 'Mon', value: 0.6),
                      _buildChartBar(label: 'Tue', value: 0.4),
                      _buildChartBar(label: 'Wed', value: 0.7),
                      _buildChartBar(label: 'Thu', value: 0.8),
                      _buildChartBar(label: 'Fri', value: 0.9),
                      _buildChartBar(label: 'Sat', value: 0.65),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sales in USD',
                  style: TextStyle(
                    color: AppColors.subtleText,
                    fontFamily: AppFonts.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar({required String label, required double value}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: 140 * value,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.subtleText,
            fontFamily: AppFonts.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppColors.primaryGreen.withOpacity(0.8)),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              color: AppColors.darkText,
              fontFamily: AppFonts.primary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildOverviewPage(),
      const VendorProductsScreen(),
      _buildPlaceholder(
        'Your orders will appear here once you receive them.',
        Icons.receipt_long_outlined,
      ),
      _buildPlaceholder(
        'Vendor chat is coming soon.',
        Icons.chat_bubble_outline,
      ),
      _buildPlaceholder(
        'Manage your account details here.',
        Icons.person_outline,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _titles[_currentIndex],
          style: const TextStyle(
            fontFamily: AppFonts.primary,
            color: AppColors.darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: AppColors.darkText),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: AppBottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.inventory_2_outlined),
            activeIcon: const Icon(Icons.inventory_2),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long_outlined),
            activeIcon: const Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            activeIcon: const Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}
