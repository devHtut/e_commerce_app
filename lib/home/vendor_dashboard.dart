import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/signin_screen.dart';
import '../theme_config.dart';
import '../widgets/custom_pop_up.dart';

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
    'Sales',
    'Profile',
  ];

  static const List<Widget> _pages = [
    Center(
      child: Text(
        'Welcome, Vendor!',
        style: AppTextStyles.header,
        textAlign: TextAlign.center,
      ),
    ),
    Center(
      child: Text(
        'Manage your products here.',
        style: AppTextStyles.body,
      ),
    ),
    Center(
      child: Text(
        'Track your sales and earnings here.',
        style: AppTextStyles.body,
      ),
    ),
    Center(
      child: Text(
        'Manage vendor profile here.',
        style: AppTextStyles.body,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
