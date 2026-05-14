import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_user_service.dart';
import '../auth/vendor_access.dart';
import '../chat/chat_service.dart';
import '../customer/chat_screen.dart';
import '../notification/notification_screen.dart';
import '../notification/notification_service.dart';
import '../order/order_detail_screen.dart';
import '../order/order_service.dart';
import '../theme_config.dart';
import '../widgets/app_bottom_navigation_bar.dart';
import '../widgets/order_readable_id_search.dart';
import '../widgets/price_formatter.dart';
import 'brand_account_settings_screen.dart';
import 'brand_analytics_service.dart';
import 'shop_profile_screen.dart';
import 'vendor_inventory_service.dart';
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
  int _activeVendorOrderCount = 0;
  final Map<OrderStatus, int> _viewedVendorOrderCounts = {};
  BrandAnalyticsRange _analyticsRange = BrandAnalyticsRange.week;
  late Future<BrandAnalyticsSnapshot> _brandAnalyticsFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVendorAccess());
  }

  Future<void> _ensureVendorAccess() async {
    final ok = await VendorAccess.ensureVendorOrRedirect(context);
    if (!mounted || !ok) return;
    _vendorOrdersFuture = _loadVendorOrdersAndCount();
    _brandAnalyticsFuture = BrandAnalyticsService.instance.loadSnapshot(
      _analyticsRange,
    );
    _loadVendorBrandOrderPrefix();
    NotificationService.instance.refreshUnreadCount(
      audience: AppNotificationAudience.vendor,
    );
    VendorInventoryService.instance.refreshLowStockCount();
    ChatService.instance.startUnreadCountSubscription();
    ChatService.instance.refreshUnreadCount();
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
    ChatService.instance.stopUnreadCountSubscription();
    super.dispose();
  }

  bool _isAttentionOrderStatus(OrderStatus status) {
    return status == OrderStatus.pending ||
        status == OrderStatus.confirmed ||
        status == OrderStatus.inDelivery ||
        status == OrderStatus.refund;
  }

  int _unviewedOrderCount(OrderStatus status, int currentCount) {
    if (!_isAttentionOrderStatus(status)) return 0;
    final viewedCount = _viewedVendorOrderCounts[status] ?? 0;
    final count = currentCount - viewedCount;
    return count <= 0 ? 0 : count;
  }

  int _attentionOrderCount(List<OrderModel> orders) {
    final counts = <OrderStatus, int>{};
    for (final order in orders) {
      if (!_isAttentionOrderStatus(order.status)) continue;
      counts[order.status] = (counts[order.status] ?? 0) + 1;
    }
    return counts.entries.fold<int>(
      0,
      (sum, entry) => sum + _unviewedOrderCount(entry.key, entry.value),
    );
  }

  void _markVendorOrderStatusViewed(OrderStatus status, int count) {
    if (!_isAttentionOrderStatus(status)) return;
    if ((_viewedVendorOrderCounts[status] ?? 0) >= count) return;
    _viewedVendorOrderCounts[status] = count;
  }

  Future<List<OrderModel>> _loadVendorOrdersAndCount() async {
    final orders = await OrderService.instance.loadVendorOrders();
    if (mounted) {
      setState(() => _activeVendorOrderCount = _attentionOrderCount(orders));
    } else {
      _activeVendorOrderCount = _attentionOrderCount(orders);
    }
    return orders;
  }

  static const List<String> _titles = [
    'Dashboard',
    'Products',
    'Shop Profile',
    'Orders',
    'Account',
  ];

  Widget _buildOverviewCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
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
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.subtleText,
                fontFamily: AppFonts.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewPage() {
    return FutureBuilder<BrandAnalyticsSnapshot>(
      future: _brandAnalyticsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Unable to load analytics.',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _refreshBrandAnalytics,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final analytics =
            snapshot.data ?? BrandAnalyticsSnapshot.empty(_analyticsRange);
        return RefreshIndicator(
          onRefresh: () async {
            await _refreshBrandAnalytics();
            await _vendorOrdersFuture;
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOverviewHeader(),
                const SizedBox(height: 16),
                _buildRangeSelector(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildOverviewCard(
                      icon: Icons.payments_outlined,
                      title: 'Revenue',
                      value: formatKyat(analytics.totalRevenue),
                      subtitle: '${analytics.salesOrderCount} sales orders',
                    ),
                    const SizedBox(width: 12),
                    _buildOverviewCard(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Orders',
                      value: '${analytics.totalOrders}',
                      subtitle: '${analytics.pendingOrderCount} pending',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildOverviewCard(
                      icon: Icons.inventory_2_outlined,
                      title: 'Products Sold',
                      value: '${analytics.productsSold}',
                      subtitle: '${analytics.lowStockItems.length} low stock',
                    ),
                    const SizedBox(width: 12),
                    _buildOverviewCard(
                      icon: Icons.remove_red_eye_outlined,
                      title: 'Product Views',
                      value: '${analytics.productViews}',
                      subtitle:
                          '${analytics.conversionRate.toStringAsFixed(1)}% conversion',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildOverviewCard(
                      icon: Icons.storefront_outlined,
                      title: 'Profile Visits',
                      value: '${analytics.brandProfileVisits}',
                      subtitle: '${analytics.uniqueProfileVisits} unique',
                    ),
                    const SizedBox(width: 12),
                    _buildOverviewCard(
                      icon: Icons.cancel_outlined,
                      title: 'Canceled',
                      value: '${analytics.canceledOrderCount}',
                      subtitle: 'Excluded from revenue',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildRevenuePanel(analytics),
                const SizedBox(height: 16),
                _buildBestSellingPanel(analytics.bestSellingProducts),
                const SizedBox(height: 16),
                _buildPopularProductsPanel(analytics.popularProducts),
                const SizedBox(height: 16),
                _buildLowStockPanel(analytics.lowStockItems),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Track your sales, visitors, product demand, and stock health.',
          style: AppTextStyles.body,
        ),
      ],
    );
  }

  Widget _buildRangeSelector() {
    return Row(
      children: BrandAnalyticsRange.values.map((range) {
        final selected = _analyticsRange == range;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(range.label),
            selected: selected,
            onSelected: (_) => _changeAnalyticsRange(range),
            selectedColor: AppColors.primaryGreen,
            showCheckmark: false,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.darkText,
              fontFamily: AppFonts.primary,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: selected ? AppColors.primaryGreen : Colors.black12,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRevenuePanel(BrandAnalyticsSnapshot analytics) {
    final maxValue = analytics.revenueSeries.fold<double>(
      0,
      (max, point) => point.value > max ? point.value : max,
    );
    return _analyticsPanel(
      title: '${analytics.range.label} Revenue',
      trailing: formatKyat(analytics.totalRevenue),
      child: SizedBox(
        height: 190,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: analytics.revenueSeries.map((point) {
            final value = maxValue == 0 ? 0.06 : (point.value / maxValue);
            return _buildChartBar(label: point.label, value: value);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBestSellingPanel(List<BrandProductSalesItem> products) {
    return _analyticsPanel(
      title: 'Best Selling',
      child: products.isEmpty
          ? _emptyAnalyticsText('No sales in this period yet.')
          : Column(
              children: products
                  .map(
                    (item) => _analyticsRow(
                      title: item.productTitle,
                      subtitle:
                          '${item.variantLabel} • ${item.orderCount} orders',
                      value: '${item.quantitySold} sold',
                      footnote: formatKyat(item.grossRevenue),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildPopularProductsPanel(List<BrandProductViewItem> products) {
    return _analyticsPanel(
      title: 'Most Popular',
      child: products.isEmpty
          ? _emptyAnalyticsText('No product views in this period yet.')
          : Column(
              children: products
                  .map(
                    (item) => _analyticsRow(
                      title: item.productTitle,
                      subtitle: '${item.uniqueViews} unique viewers',
                      value: '${item.totalViews} views',
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildLowStockPanel(List<BrandLowStockItem> items) {
    return _analyticsPanel(
      title: 'Low Stock',
      child: items.isEmpty
          ? _emptyAnalyticsText('No low stock products right now.')
          : Column(
              children: items
                  .map(
                    (item) => _analyticsRow(
                      title: item.productTitle,
                      subtitle: item.variantLabel,
                      value: '${item.stockQuantity} left',
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _analyticsPanel({
    required String title,
    required Widget child,
    String? trailing,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                  ),
                ),
              ),
              if (trailing != null)
                Text(
                  trailing,
                  style: const TextStyle(
                    color: AppColors.primaryGreen,
                    fontFamily: AppFonts.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _analyticsRow({
    required String title,
    required String subtitle,
    required String value,
    String? footnote,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.subtleText,
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (footnote != null) ...[
                const SizedBox(height: 3),
                Text(
                  footnote,
                  style: const TextStyle(
                    color: AppColors.subtleText,
                    fontFamily: AppFonts.primary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyAnalyticsText(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(message, style: AppTextStyles.body),
    );
  }

  Widget _buildChartBar({required String label, required double value}) {
    final height = 140 * value.clamp(0.06, 1.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: height,
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

  Future<void> _refreshVendorOrders() async {
    await _loadVendorBrandOrderPrefix();
    final future = _loadVendorOrdersAndCount();
    final analyticsFuture = BrandAnalyticsService.instance.loadSnapshot(
      _analyticsRange,
    );
    setState(() {
      _vendorOrdersFuture = future;
      _brandAnalyticsFuture = analyticsFuture;
    });
    await Future.wait([future, analyticsFuture]);
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

  Future<void> _openChat() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
    await ChatService.instance.refreshUnreadCount();
  }

  Widget _chatButton() {
    return ValueListenableBuilder<int>(
      valueListenable: ChatService.instance.unreadCountNotifier,
      builder: (context, unreadCount, _) {
        return IconButton(
          onPressed: _openChat,
          tooltip: 'Chat',
          icon: _appBarIconWithBadge(
            icon: Icons.chat_bubble_outline,
            count: unreadCount,
          ),
        );
      },
    );
  }

  Widget _appBarIconWithBadge({required IconData icon, required int count}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: AppColors.darkText),
        if (count > 0)
          Positioned(
            right: -6,
            top: -5,
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.errorRed,
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _changeAnalyticsRange(BrandAnalyticsRange range) {
    if (_analyticsRange == range) return;
    setState(() {
      _analyticsRange = range;
      _brandAnalyticsFuture = BrandAnalyticsService.instance.loadSnapshot(
        _analyticsRange,
      );
    });
  }

  Future<void> _refreshBrandAnalytics() async {
    final future = BrandAnalyticsService.instance.loadSnapshot(_analyticsRange);
    setState(() {
      _brandAnalyticsFuture = future;
    });
    await future;
  }

  Widget _bottomNavIconWithBadge({required IconData icon, required int count}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -10,
            top: -7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.errorRed,
                shape: BoxShape.circle,
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _orderTabLabel({
    required String label,
    required int count,
    required bool selected,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: const EdgeInsets.symmetric(horizontal: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Colors.white : AppColors.errorRed,
              shape: BoxShape.circle,
            ),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: TextStyle(
                color: selected ? AppColors.errorRed : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
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
        final tabs = <(String, int, OrderStatus)>[
          ('Pending', pending.length, OrderStatus.pending),
          ('Confirmed', confirmed.length, OrderStatus.confirmed),
          ('In Delivery', inDelivery.length, OrderStatus.inDelivery),
          ('Completed', completed.length, OrderStatus.completed),
          ('Canceled', canceled.length, OrderStatus.canceled),
          if (refunds.isNotEmpty)
            ('Refund', refunds.length, OrderStatus.refund),
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
        final displayedTab = tabs[displayedIndex];
        final displayedBadgeCount = _unviewedOrderCount(
          displayedTab.$3,
          displayedTab.$2,
        );
        if (displayedBadgeCount > 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _markVendorOrderStatusViewed(displayedTab.$3, displayedTab.$2);
              _activeVendorOrderCount = _attentionOrderCount(orders);
            });
          });
        }
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
                    label: _orderTabLabel(
                      label: tab.$1,
                      count: _unviewedOrderCount(tab.$3, tab.$2),
                      selected: selected,
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _orderTabIndex = index;
                      _markVendorOrderStatusViewed(tab.$3, tab.$2);
                      _activeVendorOrderCount = _attentionOrderCount(orders);
                    }),
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
                              'No orders match this order ID.',
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
                                            formatKyat(order.total),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = <Widget>[
      _buildOverviewPage(),
      const VendorProductsScreen(),
      ShopProfileScreen(
        ownerId: Supabase.instance.client.auth.currentUser?.id,
        embedded: true,
      ),
      _buildOrdersPage(),
      const BrandAccountSettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: _chatButton(),
        leadingWidth: 56,
        title: Text(_titles[_currentIndex], style: AppTextStyles.appBarTitle),
        actions: [_notificationButton()],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: VendorInventoryService.instance.lowStockCountNotifier,
        builder: (context, lowStockCount, _) {
          return AppBottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.dashboard_outlined),
                activeIcon: const Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: _bottomNavIconWithBadge(
                  icon: Icons.inventory_2_outlined,
                  count: lowStockCount,
                ),
                activeIcon: _bottomNavIconWithBadge(
                  icon: Icons.inventory_2,
                  count: lowStockCount,
                ),
                label: 'Products',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.storefront_outlined),
                activeIcon: const Icon(Icons.storefront),
                label: 'Shop',
              ),
              BottomNavigationBarItem(
                icon: _bottomNavIconWithBadge(
                  icon: Icons.receipt_long_outlined,
                  count: _activeVendorOrderCount,
                ),
                activeIcon: _bottomNavIconWithBadge(
                  icon: Icons.receipt_long,
                  count: _activeVendorOrderCount,
                ),
                label: 'Orders',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                activeIcon: const Icon(Icons.person),
                label: 'Account',
              ),
            ],
          );
        },
      ),
    );
  }
}
