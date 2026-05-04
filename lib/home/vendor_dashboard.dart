import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_user_service.dart';
import '../auth/signin_screen.dart';
import '../auth/vendor_access.dart';
import '../notification/notification_screen.dart';
import '../notification/notification_service.dart';
import '../order/order_detail_screen.dart';
import '../order/order_service.dart';
import '../theme_config.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/custom_pop_up.dart';
import '../widgets/order_readable_id_search.dart';
import 'shop_profile_screen.dart';
import 'vendor_products_screen.dart';

class VendorDashboard extends StatefulWidget {
  const VendorDashboard({super.key});

  @override
  State<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends State<VendorDashboard> {
  int _currentIndex = 0;
  int _orderTabIndex = 0;
  late Future<List<OrderModel>> _vendorOrdersFuture;
  final TextEditingController _vendorOrderSearchController =
      TextEditingController();
  String _vendorOrderSearchNeedle = '';
  String _vendorBrandOrderPrefix = '';
  bool _vendorAccessGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVendorAccess());
  }

  Future<void> _ensureVendorAccess() async {
    final ok = await VendorAccess.ensureVendorOrRedirect(context);
    if (!mounted || !ok) return;
    _vendorOrdersFuture = OrderService.instance.loadVendorOrders();
    _loadVendorBrandOrderPrefix();
    NotificationService.instance.refreshUnreadCount(
      audience: AppNotificationAudience.vendor,
    );
    setState(() => _vendorAccessGranted = true);
  }

  Future<void> _loadVendorBrandOrderPrefix() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final brand = await AuthUserService.getVendorBrand(user.id);
    if (!mounted) return;
    setState(() {
      _vendorBrandOrderPrefix = brand?['prefix']?.toString() ?? '';
    });
  }

  @override
  void dispose() {
    _vendorOrderSearchController.dispose();
    super.dispose();
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

  static const List<String> _titles = [
    'Vendor Dashboard',
    'Products',
    'Shop Profile',
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

  Future<void> _refreshVendorOrders() async {
    await _loadVendorBrandOrderPrefix();
    final future = OrderService.instance.loadVendorOrders();
    setState(() {
      _vendorOrdersFuture = future;
    });
    await future;
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const NotificationScreen(audience: AppNotificationAudience.vendor),
      ),
    );
    await NotificationService.instance.refreshUnreadCount(
      audience: AppNotificationAudience.vendor,
    );
  }

  Widget _notificationButton() {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.instance.unreadCountNotifier,
      builder: (context, unreadCount, _) {
        return IconButton(
          onPressed: _openNotifications,
          tooltip: 'Notifications',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.darkText,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -3,
                  child: Container(
                    width: 16,
                    height: 16,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.errorRed,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatOrderDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) {
      return 'Today, ${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    if (d == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Color _orderStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.amber.shade900;
      case OrderStatus.confirmed:
        return Colors.teal.shade700;
      case OrderStatus.inDelivery:
        return Colors.blue.shade700;
      case OrderStatus.completed:
        return AppColors.primaryGreen;
      case OrderStatus.canceled:
        return AppColors.errorRed;
      case OrderStatus.refund:
        return Colors.deepOrange.shade800;
    }
  }

  Color _orderStatusBackgroundColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.amber.shade50;
      case OrderStatus.confirmed:
        return Colors.teal.shade50;
      case OrderStatus.inDelivery:
        return Colors.blue.shade50;
      case OrderStatus.completed:
        return AppColors.primaryGreen.withValues(alpha: 0.12);
      case OrderStatus.canceled:
        return AppColors.errorRed.withValues(alpha: 0.12);
      case OrderStatus.refund:
        return Colors.deepOrange.shade50;
    }
  }

  String _orderStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'PENDING';
      case OrderStatus.confirmed:
        return 'CONFIRMED';
      case OrderStatus.inDelivery:
        return 'IN-DELIVERY';
      case OrderStatus.completed:
        return 'COMPLETED';
      case OrderStatus.canceled:
        return 'CANCELED';
      case OrderStatus.refund:
        return 'REFUND';
    }
  }

  Widget _buildOrdersPage() {
    return FutureBuilder<List<OrderModel>>(
      future: _vendorOrdersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Unable to load orders.', style: AppTextStyles.body),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    _refreshVendorOrders();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final orders = snapshot.data ?? <OrderModel>[];
        final pending = orders
            .where((o) => o.status == OrderStatus.pending)
            .toList();
        final confirmed = orders
            .where((o) => o.status == OrderStatus.confirmed)
            .toList();
        final inDelivery = orders
            .where((o) => o.status == OrderStatus.inDelivery)
            .toList();
        final completed = orders
            .where((o) => o.status == OrderStatus.completed)
            .toList();
        final canceled = orders
            .where((o) => o.status == OrderStatus.canceled)
            .toList();
        final refunds = orders
            .where((o) => o.status == OrderStatus.refund)
            .toList();
        final tabs = <(String, int)>[
          ('Pending', pending.length),
          ('Confirmed', confirmed.length),
          ('In Delivery', inDelivery.length),
          ('Completed', completed.length),
          ('Canceled', canceled.length),
          if (refunds.isNotEmpty) ('Refund', refunds.length),
        ];
        final displayedIndex = _orderTabIndex < tabs.length
            ? _orderTabIndex
            : tabs.length - 1;
        final showing = switch (displayedIndex) {
          0 => pending,
          1 => confirmed,
          2 => inDelivery,
          3 => completed,
          4 => canceled,
          _ => refunds,
        };
        final filtered = showing
            .where(
              (o) => orderReadableIdMatchesSearch(
                o.readableId,
                _vendorOrderSearchNeedle,
              ),
            )
            .toList();

        return Column(
          children: [
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: tabs.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tab = tabs[index];
                  final selected = displayedIndex == index;
                  return ChoiceChip(
                    label: Text('${tab.$1} (${tab.$2})'),
                    selected: selected,
                    onSelected: (_) => setState(() => _orderTabIndex = index),
                    showCheckmark: false,
                    selectedColor: AppColors.primaryGreen,
                    labelStyle: TextStyle(
                      fontFamily: AppFonts.primary,
                      color: selected ? Colors.white : AppColors.darkText,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: VendorOrderReadableIdSearchField(
                controller: _vendorOrderSearchController,
                brandOrderPrefix: _vendorBrandOrderPrefix,
                onNeedleChanged: (needle) {
                  setState(() => _vendorOrderSearchNeedle = needle);
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshVendorOrders,
                child: showing.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 240),
                          Center(
                            child: Text(
                              'No orders yet.',
                              style: AppTextStyles.body,
                            ),
                          ),
                        ],
                      )
                    : filtered.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 240),
                              Center(
                                child: Text(
                                  'အော်ဒါ ID လေး မှားနေသလားလို့ပါ။ 🧐 ရှာလို့မတွေ့ဖြစ်နေလို့ တစ်ခေါက်လောက် ပြန်စစ်ပြီး ရိုက်ထည့်ပေးပါဦးနော်။ ကျေးဇူးတင်ပါတယ်ဗျ! 🙌',
                                  style: AppTextStyles.body,
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = filtered[index];
                          final leadItem = order.items.first;
                          final extraCount = order.items.length - 1;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16,
                                      color: AppColors.primaryGreen,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            order.readableId,
                                            style: const TextStyle(
                                              fontFamily: AppFonts.primary,
                                              color: AppColors.darkText,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatOrderDate(order.createdAt),
                                            style: TextStyle(
                                              fontFamily: AppFonts.primary,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  _orderStatusBackgroundColor(
                                                    order.status,
                                                  ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              _orderStatusLabel(order.status),
                                              style: TextStyle(
                                                fontFamily: AppFonts.primary,
                                                color: _orderStatusColor(
                                                  order.status,
                                                ),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        leadItem.imageUrl,
                                        width: 96,
                                        height: 110,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            leadItem.product.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: AppFonts.primary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                          if (extraCount > 0)
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                top: 2,
                                              ),
                                              child: Text(
                                                '+$extraCount other products',
                                                style: TextStyle(
                                                  fontFamily: AppFonts.primary,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Total Shopping',
                                            style: TextStyle(
                                              fontFamily: AppFonts.primary,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          Text(
                                            '\$${order.total.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              color: AppColors.primaryGreen,
                                              fontFamily: AppFonts.primary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 30,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          OutlinedButton(
                                            onPressed: () async {
                                              await Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      OrderDetailScreen(
                                                        order: order,
                                                        isVendorView: true,
                                                      ),
                                                ),
                                              );
                                              if (!mounted) return;
                                              _refreshVendorOrders();
                                            },
                                            style: OutlinedButton.styleFrom(
                                              side: const BorderSide(
                                                color: AppColors.primaryGreen,
                                              ),
                                            ),
                                            child: const Text(
                                              'View Order',
                                              style: TextStyle(
                                                color: AppColors.primaryGreen,
                                                fontFamily: AppFonts.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_vendorAccessGranted) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = <Widget>[
      _buildOverviewPage(),
      const VendorProductsScreen(),
      ShopProfileScreen(
        ownerId: Supabase.instance.client.auth.currentUser?.id,
        embedded: true,
      ),
      _buildOrdersPage(),
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
          _notificationButton(),
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
            icon: const Icon(Icons.storefront_outlined),
            activeIcon: const Icon(Icons.storefront),
            label: 'Shop',
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
