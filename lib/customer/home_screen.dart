import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../cart/cart_item.dart';
import '../cart/checkout_screen.dart';
import '../cart/cart_service.dart';
import '../chat/chat_service.dart';
import '../contact_about_screen.dart';
import '../order/order_service.dart';
import '../order/order_detail_screen.dart';
import '../address/delivery_address_screen.dart';
import '../auth/auth_user_service.dart';
import '../auth/profile_info_screen.dart';
import '../notification/notification_screen.dart';
import '../notification/notification_service.dart';
import '../product/product_detail_screen.dart';
import '../product/product_model.dart';
import '../product/product_sales_service.dart';
import '../wishlist/wishlist_service.dart';
import '../widgets/auto_banner_slider.dart';
import '../widgets/custom_pop_up.dart';
import '../widgets/price_formatter.dart';
import '../widgets/product_card.dart';
import '../widgets/guest_auth_gate.dart';
import '../widgets/order_readable_id_search.dart';
import '../widgets/search_box.dart';
import '../theme_config.dart';
import '../widgets/custom_loading_state.dart';
import 'all_products_screen.dart';
import 'chat_screen.dart';
import 'help_support_screen.dart';
import '../vendor/shop_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({super.key, this.initialIndex = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _orderTabIndex = 0;
  String _searchQuery = '';
  bool _isLoadingProducts = true;
  bool _isAccountLoading = false;
  Map<String, dynamic>? _userProfile;
  String _userEmail = '';
  String? _userAvatarUrl;
  String? _productsError;
  List<ProductModel> _products = [];
  Map<String, ProductEngagementMetrics> _productMetrics = {};
  bool _isLoadingBrands = true;
  String? _brandsError;
  List<_BrandInfo> _brands = [];
  final List<String> _recentSearches = [];
  DateTime? _lastBackPressedAt;
  bool get _isLoggedIn => Supabase.instance.client.auth.currentUser != null;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _customerOrderSearchController =
      TextEditingController();
  String _customerOrderSearchNeedle = '';
  final Map<OrderStatus, int> _viewedCustomerOrderCounts = {};

  bool _isAttentionOrderStatus(OrderStatus status) {
    return status == OrderStatus.pending ||
        status == OrderStatus.confirmed ||
        status == OrderStatus.inDelivery ||
        status == OrderStatus.refund;
  }

  int _unviewedOrderCount(OrderStatus status, int currentCount) {
    if (!_isAttentionOrderStatus(status)) return 0;
    final viewedCount = _viewedCustomerOrderCounts[status] ?? 0;
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

  void _markCustomerOrderStatusViewed(OrderStatus status, int count) {
    if (!_isAttentionOrderStatus(status)) return;
    if ((_viewedCustomerOrderCounts[status] ?? 0) >= count) return;
    _viewedCustomerOrderCounts[status] = count;
  }

  Widget _orderTabLabel({required String label}) {
    return Text(label);
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _loadProducts();
    _loadBrands();
    if (_isLoggedIn) {
      _loadAccountInfo();
      OrderService.instance.loadOrders();
      NotificationService.instance.refreshUnreadCount(
        audience: AppNotificationAudience.customer,
      );
      ChatService.instance.startUnreadCountSubscription();
      ChatService.instance.refreshUnreadCount();
      CartService.instance.loadCartItems();
      WishlistService.instance.loadWishlistItems();
    } else {
      WishlistService.instance.clear();
      CartService.instance.clear();
      NotificationService.instance.clearUnreadCount();
      ChatService.instance.stopUnreadCountSubscription();
      ChatService.instance.unreadCountNotifier.value = 0;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _customerOrderSearchController.dispose();
    ChatService.instance.stopUnreadCountSubscription();
    super.dispose();
  }

  final List<BannerItem> _banners = const [
    BannerItem(
      title: '30% OFF',
      subtitle: "Special!",
      description: '',
      // description: 'Get discount for every order, only valid for today',
      imageUrl:
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=1200&q=80',
    ),
    BannerItem(
      title: '20% OFF',
      subtitle: 'Weekend Deal',
      description: '',
      // description: 'Fresh styles dropped. Shop now and save.',
      imageUrl:
          'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=1200&q=80',
    ),
    BannerItem(
      title: 'NEW',
      subtitle: 'Summer Picks',
      description: '',
      // description: 'Lightweight essentials for sunny days.',
      imageUrl:
          'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=crop&w=1200&q=80',
    ),
  ];

  Future<void> _loadProducts() async {
    setState(() {
      _isLoadingProducts = true;
      _productsError = null;
    });
    try {
      final rows = await Supabase.instance.client
          .from('products')
          .select(
            'id, title, description, base_price, '
            'brand_id, category_id, audience_id, categories(name), audiences(name), brands(brand_name), '
            'product_variants(image_url,price_adjustment,promo_price)',
          )
          .order('created_at', ascending: false);

      final products = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ProductModel.fromSupabaseRow)
          .toList();
      final metrics = await ProductSalesService.instance.loadMetricsForProducts(
        products.map((product) => product.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _productMetrics = metrics;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _productsError = 'Unable to load products right now.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  List<ProductModel> get _newArrivalProducts => _products.take(4).toList();
  List<ProductModel> get _promotionProducts =>
      _products.where((product) => product.hasPromotion).take(10).toList();
  List<ProductModel> get _hotDealProducts =>
      _products.reversed.take(4).toList();
  List<ProductModel> get _bestSellingProducts {
    final products = List<ProductModel>.from(_products)
      ..sort(
        (a, b) => (_productMetrics[b.id]?.soldCount ?? 0).compareTo(
          _productMetrics[a.id]?.soldCount ?? 0,
        ),
      );
    return products
        .where((product) => (_productMetrics[product.id]?.soldCount ?? 0) >= 5)
        .take(10)
        .toList();
  }

  List<ProductModel> get _mostViewedProducts {
    final products = List<ProductModel>.from(_products)
      ..sort(
        (a, b) => (_productMetrics[b.id]?.viewCount ?? 0).compareTo(
          _productMetrics[a.id]?.viewCount ?? 0,
        ),
      );
    return products
        .where((product) => (_productMetrics[product.id]?.viewCount ?? 0) >= 5)
        .take(10)
        .toList();
  }

  List<ProductModel> get _searchResults {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _products;
    return _products
        .where((product) => _matchesProductSearch(product, query))
        .toList();
  }

  bool get _isSearchMode =>
      _searchFocusNode.hasFocus || _searchQuery.trim().isNotEmpty;

  bool _matchesProductSearch(ProductModel product, String query) {
    return product.name.toLowerCase().contains(query) ||
        product.brand.toLowerCase().contains(query) ||
        product.category.toLowerCase().contains(query) ||
        product.audience.toLowerCase().contains(query) ||
        product.description.toLowerCase().contains(query);
  }

  void _updateSearchQuery(String value) {
    setState(() => _searchQuery = value);
  }

  void _submitSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    setState(() {
      _searchQuery = query;
      _recentSearches.removeWhere(
        (recent) => recent.toLowerCase() == query.toLowerCase(),
      );
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 6) {
        _recentSearches.removeRange(6, _recentSearches.length);
      }
    });
  }

  void _selectRecentSearch(String query) {
    _searchController.text = query;
    _searchController.selection = TextSelection.collapsed(offset: query.length);
    _searchFocusNode.requestFocus();
    setState(() => _searchQuery = query);
  }

  void _removeRecentSearch(String query) {
    setState(() => _recentSearches.remove(query));
  }

  void _clearRecentSearches() {
    setState(_recentSearches.clear);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
    _searchFocusNode.unfocus();
  }

  Future<void> _loadAccountInfo() async {
    if (!_isLoggedIn) return;
    setState(() => _isAccountLoading = true);

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      setState(() => _isAccountLoading = false);
      return;
    }

    final profile = await AuthUserService.getUserProfile(currentUser.id);
    if (!mounted) return;

    setState(() {
      _userProfile = profile;
      _userEmail = currentUser.email ?? '';
      _userAvatarUrl = profile?['avatar_url']?.toString();
      _isAccountLoading = false;
    });
  }

  Future<void> _openChooseDeliveryAddress() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await AuthUserService.getUserProfile(user.id);
    final fullName = profile?['full_name']?.toString() ?? 'You';

    try {
      final rows = await Supabase.instance.client
          .from('user_addresses')
          .select(
            'id,label,phone_number,address_line,region,district,township,city,is_default',
          )
          .eq('user_id', user.id)
          .order('is_default', ascending: false);

      final addresses = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) {
            final street = row['address_line']?.toString() ?? '';
            final city = row['city']?.toString() ?? '';
            final township = row['township']?.toString() ?? city;
            return DeliveryAddress(
              id:
                  row['id']?.toString() ??
                  'addr_${DateTime.now().microsecondsSinceEpoch}',
              label: row['label']?.toString() ?? 'Home',
              recipientName: fullName,
              phone: row['phone_number']?.toString() ?? '',
              streetAddress: street,
              region: row['region']?.toString() ?? '',
              district: row['district']?.toString() ?? '',
              township: township,
              isPrimary: (row['is_default'] as bool?) ?? false,
            );
          })
          .toList();

      final selectedId = addresses.isNotEmpty ? addresses.first.id : '';
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryAddressScreen(
            initialAddresses: addresses,
            selectedAddressId: selectedId,
          ),
        ),
      );
    } catch (_) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DeliveryAddressScreen(
            initialAddresses: [],
            selectedAddressId: '',
          ),
        ),
      );
    }
  }

  Future<void> _openProfileEdit() async {
    if (!_isLoggedIn) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileInfoScreen(
          initialFullName: _userProfile?['full_name']?.toString(),
          initialUsername: _userProfile?['username']?.toString(),
          initialAvatarUrl: _userAvatarUrl,
          returnToHomeAfterSave: false,
        ),
      ),
    );
    if (!mounted) return;
    await _loadAccountInfo();
  }

  void _openHelpSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
    );
  }

  void _openContactAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ContactAboutScreen()),
    );
  }

  void _openAllProducts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllProductsScreen(
          initialQuery: _searchQuery.trim().isEmpty ? null : _searchQuery,
        ),
      ),
    );
  }

  Future<void> _openNotifications() async {
    if (!_isLoggedIn) {
      await showCustomPopup(
        context,
        title: 'Sign in required',
        message: 'Please sign in to view notifications.',
        type: PopupType.error,
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationScreen(
          audience: AppNotificationAudience.customer,
        ),
      ),
    );
    await NotificationService.instance.refreshUnreadCount(
      audience: AppNotificationAudience.customer,
    );
  }

  Future<void> _openChat() async {
    if (!_isLoggedIn) {
      await GuestAuthGatePanel.show(context);
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
    await ChatService.instance.refreshUnreadCount();
  }

  void _showLogoutConfirmation() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Logout',
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    color: AppColors.primaryGreen,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Are you sure you want to log out?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppFonts.primary,
                    color: AppColors.darkText,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.lightGrey),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.primaryGreen,
                            fontFamily: AppFonts.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _logout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text(
                          'Yes, Logout',
                          style: TextStyle(
                            color: Colors.white,
                            fontFamily: AppFonts.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHorizontalProductSection({
    required String title,
    required List<ProductModel> products,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                  fontFamily: AppFonts.primary,
                ),
              ),
            ),
            TextButton(
              onPressed: _openAllProducts,
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 290,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final product = products[index];
              return SizedBox(
                width: 180,
                child: ProductCard(
                  product: product,
                  isWishlisted: WishlistService.instance.isWishlisted(
                    product.id,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: product),
                      ),
                    );
                  },
                  onWishlistTap: () => _toggleWishlist(product),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHomeSearchBox() {
    return SearchBox(
      controller: _searchController,
      focusNode: _searchFocusNode,
      hintText: 'Search anything you want ...',
      onChanged: _updateSearchQuery,
      onSubmitted: _submitSearch,
      suffixIcon: _searchQuery.trim().isNotEmpty
          ? IconButton(
              onPressed: _clearSearch,
              tooltip: 'Clear search',
              icon: const Icon(Icons.close, color: AppColors.darkText),
            )
          : null,
    );
  }

  Widget _buildSearchModeContent() {
    final query = _searchQuery.trim();
    final results = _searchResults;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_recentSearches.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Searches',
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: _clearRecentSearches,
                tooltip: 'Clear recent searches',
                icon: const Icon(Icons.close, color: AppColors.darkText),
              ),
            ],
          ),
          const Divider(height: 1),
          ..._recentSearches.map(_buildRecentSearchRow),
          const SizedBox(height: 18),
        ],
        if (query.isEmpty) ...[
          if (_hotDealProducts.isNotEmpty)
            _buildHorizontalProductSection(
              title: 'Hot Deals This Week',
              products: _hotDealProducts,
            ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Results for "$query"',
                  style: const TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${results.length} found',
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (results.isEmpty)
            const _HomeEmptyState(
              icon: Icons.search_off_rounded,
              title: 'No products found',
              message:
                  'Try searching by product name, brand, category, or audience.',
            )
          else
            _buildProductGrid(results),
        ],
      ],
    );
  }

  Widget _buildRecentSearchRow(String query) {
    return InkWell(
      onTap: () => _selectRecentSearch(query),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                query,
                style: const TextStyle(
                  color: AppColors.subtleText,
                  fontFamily: AppFonts.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: () => _removeRecentSearch(query),
              tooltip: 'Remove search',
              icon: const Icon(Icons.close, color: AppColors.darkText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid(List<ProductModel> products) {
    return GridView.builder(
      itemCount: products.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: ProductCard.gridDelegate,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          isWishlisted: WishlistService.instance.isWishlisted(product.id),
          onTap: () {
            _submitSearch(_searchQuery);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(product: product),
              ),
            );
          },
          onWishlistTap: () => _toggleWishlist(product),
        );
      },
    );
  }

  Future<void> _loadBrands() async {
    setState(() {
      _brandsError = null;
      _isLoadingBrands = true;
    });
    try {
      final rows = await Supabase.instance.client
          .from('brands')
          .select('id, brand_name, logo_url')
          .order('created_at', ascending: false)
          .limit(10);
      final brands = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .where((row) => row['id'] != null)
          .map(
            (row) => _BrandInfo(
              id: row['id'].toString(),
              name: row['brand_name']?.toString() ?? 'Brand',
              logoUrl: row['logo_url']?.toString() ?? '',
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _brands = brands;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _brandsError = 'Unable to load brands right now.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoadingBrands = false;
      });
    }
  }

  Widget _buildBrandsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Brands',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
          ),
        ),
        const SizedBox(height: 10),
        if (_isLoadingBrands)
          const SizedBox(height: 100, child: const CustomLoadingCenter())
        else if (_brandsError != null)
          Text(
            _brandsError!,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.darkText,
              fontFamily: AppFonts.primary,
            ),
          )
        else
          SizedBox(
            height: 168,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: 10,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
                childAspectRatio: 0.86,
              ),
              itemBuilder: (context, index) {
                if (index < _brands.length) {
                  return _buildBrandTile(_brands[index]);
                }
                return const _BrandComingSoonTile();
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBrandTile(_BrandInfo brand) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShopProfileScreen(brandId: brand.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: brand.logoUrl.isNotEmpty
                ? Image.network(
                    brand.logoUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 52,
                      height: 52,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.storefront_outlined,
                        size: 28,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  )
                : Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.storefront_outlined,
                      size: 28,
                      color: AppColors.primaryGreen,
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Text(
            brand.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
              fontFamily: AppFonts.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    WishlistService.instance.clear();
    CartService.instance.clear();
    NotificationService.instance.clearUnreadCount();
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
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _toggleWishlist(ProductModel product) async {
    if (!_isLoggedIn) {
      setState(() => _currentIndex = 1);
      return;
    }
    try {
      final added = await WishlistService.instance.toggle(product);
      if (!mounted) return;
      setState(() {});
      if (added) {
        await showCustomPopup(
          context,
          title: 'Saved',
          message: '${product.name} added to wishlist.',
          type: PopupType.success,
        );
      } else {
        _showRemovedFromWishlistToast();
      }
    } catch (e) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Wishlist failed',
        message: 'Unable to update wishlist. Please try again.',
        type: PopupType.error,
      );
    }
  }

  void _showRemovedFromWishlistToast() {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 88),
          duration: const Duration(seconds: 2),
          content: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: const [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryGreen,
                  child: Icon(Icons.check, color: Colors.white, size: 18),
                ),
                SizedBox(width: 12),
                Text(
                  'Removed from Wishlist!',
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  static const List<String> _titles = [
    'Customer Home',
    'Wishlist',
    'Cart',
    'My Orders',
    'Account',
  ];

  String _appBarTitle() {
    if (_currentIndex == 2) {
      final count = _isLoggedIn
          ? CartService.instance.itemsNotifier.value.length
          : 0;
      return 'Cart ($count)';
    }
    if (_currentIndex == 1) {
      final count = _isLoggedIn
          ? WishlistService.instance.itemsNotifier.value.length
          : 0;
      return 'Wishlist ($count)';
    }
    if (_currentIndex == 3) {
      return 'My Orders';
    }
    if (_currentIndex == 0) {
      return 'Trendify';
    }
    return _titles[_currentIndex];
  }

  Future<void> _handleTabTap(int index) async {
    setState(() {
      _currentIndex = index;
    });
    if (index == 2 && _isLoggedIn) {
      await CartService.instance.loadCartItems();
    }
    if (index == 1 && _isLoggedIn) {
      await WishlistService.instance.loadWishlistItems();
    }
    if (index == 3 && _isLoggedIn) {
      await OrderService.instance.loadOrders();
    }
    if (index == 4 && _isLoggedIn) {
      await _loadAccountInfo();
    }
  }

  Future<void> _showEditProductVariantSheet(CartItem item) async {
    final variants = await _loadProductVariants(item.product.id);
    if (!mounted || variants.isEmpty) return;
    int selectedVariant = variants.indexWhere(
      (variant) =>
          variant.id == item.variantId ||
          (variant.size == item.size && variant.color == item.colorName),
    );
    if (selectedVariant == -1) selectedVariant = 0;
    int quantity = item.quantity.clamp(1, variants[selectedVariant].stock);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final current = variants[selectedVariant];
            final hasSelectableVariants = variants.any(
              (variant) =>
                  !_isDefaultVariantValue(variant.size) ||
                  !_isDefaultVariantValue(variant.color),
            );
            final sizes = variants.map((v) => v.size).toSet().toList();
            final colors = variants
                .where((v) => v.size == current.size)
                .map((v) => v.color)
                .toSet()
                .toList();
            return SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.only(top: 24),
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Edit Product Variant',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            item.imageUrl,
                            width: 98,
                            height: 118,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 98,
                              height: 118,
                              color: Colors.grey.shade300,
                              alignment: Alignment.center,
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkText,
                                  fontFamily: AppFonts.primary,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Stock  :  ${current.stock}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontFamily: AppFonts.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                formatKyat(current.price),
                                style: const TextStyle(
                                  fontSize: 22,
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: AppFonts.primary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                height: 42,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: quantity > 1
                                          ? () {
                                              setModalState(() {
                                                quantity--;
                                              });
                                            }
                                          : null,
                                      icon: const Icon(Icons.remove, size: 20),
                                    ),
                                    SizedBox(
                                      width: 26,
                                      child: Text(
                                        '$quantity',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w600,
                                          fontFamily: AppFonts.primary,
                                          color: AppColors.darkText,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: quantity < current.stock
                                          ? () {
                                              setModalState(() {
                                                quantity++;
                                              });
                                            }
                                          : null,
                                      icon: const Icon(Icons.add, size: 20),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (hasSelectableVariants) ...[
                      const SizedBox(height: 14),
                      Divider(color: Colors.grey.shade200, height: 1),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Size',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                            fontFamily: AppFonts.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(sizes.length, (index) {
                          final size = sizes[index];
                          final isSelected = current.size == size;
                          return Padding(
                            padding: EdgeInsets.only(
                              right: index == sizes.length - 1 ? 0 : 10,
                            ),
                            child: InkWell(
                              onTap: () {
                                final sameSize = variants
                                    .where((variant) => variant.size == size)
                                    .toList();
                                final matchedColor = sameSize.indexWhere(
                                  (variant) => variant.color == current.color,
                                );
                                setModalState(() {
                                  selectedVariant = variants.indexOf(
                                    sameSize[matchedColor == -1
                                        ? 0
                                        : matchedColor],
                                  );
                                  quantity = quantity.clamp(
                                    1,
                                    variants[selectedVariant].stock,
                                  );
                                });
                              },
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryGreen
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryGreen
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  size,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.darkText,
                                    fontFamily: AppFonts.primary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Divider(color: Colors.grey.shade200, height: 1),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Color',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.darkText,
                            fontFamily: AppFonts.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 78,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: colors.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final colorName = colors[index];
                            final isSelected = current.color == colorName;
                            final swatchColor = _cartVariantColor(
                              variants,
                              colorName,
                            );
                            return InkWell(
                              onTap: () {
                                final match = variants.firstWhere(
                                  (variant) =>
                                      variant.size == current.size &&
                                      variant.color == colorName,
                                );
                                setModalState(() {
                                  selectedVariant = variants.indexOf(match);
                                  quantity = quantity.clamp(
                                    1,
                                    variants[selectedVariant].stock,
                                  );
                                });
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Column(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: swatchColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.darkText
                                            : Colors.grey.shade300,
                                        width: isSelected ? 2 : 1,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Icon(
                                            Icons.check,
                                            size: 18,
                                            color:
                                                swatchColor.computeLuminance() >
                                                    0.8
                                                ? AppColors.darkText
                                                : Colors.white,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    colorName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                      fontFamily: AppFonts.primary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE3ECE6),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontFamily: AppFonts.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () async {
                                final selected = variants[selectedVariant];
                                await CartService.instance.updateItemVariant(
                                  itemId: item.id,
                                  variantId: selected.id,
                                  size: selected.size,
                                  colorName: selected.color,
                                  colorValue: _cartVariantColor(
                                    variants,
                                    selected.color,
                                  ).toARGB32(),
                                  imageUrl: selected.imageUrl.isEmpty
                                      ? item.imageUrl
                                      : selected.imageUrl,
                                  selectedPrice: selected.price,
                                  quantity: quantity,
                                );
                                if (!context.mounted) return;
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: const Text(
                                'Confirm',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: AppFonts.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<_CartVariantOption>> _loadProductVariants(
    String productId,
  ) async {
    final rows = await Supabase.instance.client
        .from('product_variants')
        .select(
          'id,size,color,color_value,stock_quantity,price_adjustment,promo_price,image_url,products(base_price)',
        )
        .eq('product_id', productId);
    return (rows as List<dynamic>).cast<Map<String, dynamic>>().map((row) {
      final product = row['products'] as Map<String, dynamic>?;
      final base = (product?['base_price'] as num?)?.toDouble() ?? 0;
      final adjustment = (row['price_adjustment'] as num?)?.toDouble() ?? 0;
      final promo = (row['promo_price'] as num?)?.toDouble();
      return _CartVariantOption(
        id: row['id'].toString(),
        size: row['size']?.toString() ?? 'Default',
        color: row['color']?.toString() ?? 'Default',
        colorValue: _nullableColorValue(row['color_value']),
        stock: (row['stock_quantity'] as num?)?.toInt() ?? 0,
        imageUrl: row['image_url']?.toString() ?? '',
        price: promo ?? (base + adjustment),
      );
    }).toList();
  }

  Future<void> _confirmAndRemoveCartItem(CartItem item) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Remove from cart?',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          content: Text(
            'Do you want to remove ${item.product.name} from your cart?',
            style: const TextStyle(
              fontFamily: AppFonts.primary,
              color: AppColors.darkText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'No',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontFamily: AppFonts.primary,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Yes',
                style: TextStyle(
                  color: AppColors.primaryGreen,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true || !mounted) return;

    await CartService.instance.removeItem(item.id);
    _showRemovedFromCartToast();
  }

  void _showRemovedFromCartToast() {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 88),
          duration: const Duration(seconds: 2),
          content: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: const [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryGreen,
                  child: Icon(Icons.check, color: Colors.white, size: 18),
                ),
                SizedBox(width: 12),
                Text(
                  'Removed from Cart!',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontFamily: AppFonts.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  void _goToCheckout(List<CartItem> items) {
    final checkoutItems = items.where((item) => item.isSelected).toList();
    if (checkoutItems.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(items: checkoutItems)),
    );
  }

  Widget _buildCartPage() {
    if (!_isLoggedIn) {
      return const GuestAuthGatePanel();
    }
    return ValueListenableBuilder<List<CartItem>>(
      valueListenable: CartService.instance.itemsNotifier,
      builder: (context, items, _) {
        if (items.isEmpty) {
          return const Center(
            child: Text('Your cart is empty.', style: AppTextStyles.body),
          );
        }

        final selectedCount = CartService.instance.selectedCount(items);
        final selectedTotal = CartService.instance.totalSelectedPrice(items);

        return Stack(
          children: [
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final hasSize = !_isDefaultVariantValue(item.size);
                final hasColor = !_isDefaultVariantValue(item.colorName);
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              item.imageUrl,
                              width: 110,
                              height: 138,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 110,
                                height: 138,
                                color: Colors.grey.shade300,
                                alignment: Alignment.center,
                                child: const Icon(Icons.image_not_supported),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            top: 8,
                            child: InkWell(
                              onTap: () =>
                                  CartService.instance.toggleSelection(item.id),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: item.isSelected
                                      ? AppColors.primaryGreen
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: item.isSelected
                                        ? AppColors.primaryGreen
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: item.isSelected
                                    ? const Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkText,
                                fontFamily: AppFonts.primary,
                                height: 1.25,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (hasSize) ...[
                              Text(
                                'Size: ${item.size}',
                                style: TextStyle(
                                  fontFamily: AppFonts.primary,
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 4),
                            ],
                            if (hasColor) ...[
                              Row(
                                children: [
                                  Text(
                                    'Color: ${item.colorName} ',
                                    style: TextStyle(
                                      fontFamily: AppFonts.primary,
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Color(item.colorValue),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              'Qty: ${item.quantity}',
                              style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (item.isExpiringSoon) ...[
                              const SizedBox(height: 6),
                              Text(
                                item.expiryLabel,
                                style: const TextStyle(
                                  fontFamily: AppFonts.primary,
                                  fontSize: 13,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              formatKyat(item.subtotal),
                              style: const TextStyle(
                                fontSize: 25,
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w700,
                                fontFamily: AppFonts.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildCartItemActions(item),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: selectedCount > 0
                        ? () => _goToCheckout(items)
                        : null,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Checkout ($selectedCount) - ${formatKyat(selectedTotal)}',
                        style: AppTextStyles.button.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildWishlistPage() {
    if (!_isLoggedIn) {
      return const GuestAuthGatePanel();
    }
    return ValueListenableBuilder<List<ProductModel>>(
      valueListenable: WishlistService.instance.itemsNotifier,
      builder: (context, wishlistItems, _) {
        if (wishlistItems.isEmpty) {
          return const Center(
            child: Text('Your wishlist is empty.', style: AppTextStyles.body),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: wishlistItems.length,
          gridDelegate: ProductCard.gridDelegate,
          itemBuilder: (context, index) {
            final product = wishlistItems[index];
            return ProductCard(
              product: product,
              isWishlisted: true,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailScreen(product: product),
                  ),
                );
              },
              onWishlistTap: () => _toggleWishlist(product),
            );
          },
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

  Future<void> _showCancelOrderDialog(OrderModel order) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Cancel Order',
          style: TextStyle(
            // color: Color(0xFFCF6E6E),
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          'Are you sure you want to cancel the order?\n\nIt\'s okay to change your mind! Your payment will be safely refunded. Terms & Conditions apply.',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            color: AppColors.darkText,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, Don\'t Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: const Text(
              'Yes, Cancel Order',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (shouldCancel != true || !mounted) return;
    await OrderService.instance.cancelOrder(order.id);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primaryGreen,
              child: Icon(Icons.check, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text(
              'Order Canceled Successfully!',
              style: TextStyle(
                fontFamily: AppFonts.primary,
                color: AppColors.darkText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyOrdersPage() {
    if (!_isLoggedIn) {
      return const GuestAuthGatePanel();
    }
    return ValueListenableBuilder<List<OrderModel>>(
      valueListenable: OrderService.instance.ordersNotifier,
      builder: (context, orders, _) {
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
              _markCustomerOrderStatusViewed(displayedTab.$3, displayedTab.$2);
            });
          });
        }
        final filtered = showing
            .where(
              (o) => orderReadableIdMatchesSearch(
                o.readableId,
                _customerOrderSearchNeedle,
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
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final tab = tabs[index];
                  final selected = displayedIndex == index;
                  final hasUnviewed = _unviewedOrderCount(tab.$3, tab.$2) > 0;
                  return ChoiceChip(
                    label: _orderTabLabel(label: tab.$1),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _orderTabIndex = index;
                      _markCustomerOrderStatusViewed(tab.$3, tab.$2);
                    }),
                    showCheckmark: false,
                    selectedColor: AppColors.primaryGreen,
                    side: BorderSide(
                      color: hasUnviewed && !selected
                          ? AppColors.errorRed
                          : Colors.grey.shade300,
                      width: hasUnviewed && !selected ? 1.4 : 1,
                    ),
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
              child: CustomerOrderReadableIdSearchField(
                controller: _customerOrderSearchController,
                onNeedleChanged: (needle) {
                  setState(() => _customerOrderSearchNeedle = needle);
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: showing.isEmpty
                  ? const Center(
                      child: Text('No orders yet.', style: AppTextStyles.body),
                    )
                  : filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No orders match this order ID.',
                        style: AppTextStyles.body,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
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
                                            color: _orderStatusBackgroundColor(
                                              order.status,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
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
                                  if (order.status == OrderStatus.pending)
                                    PopupMenuButton<String>(
                                      color: Colors.white,
                                      elevation: 8,
                                      offset: const Offset(0, 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      onSelected: (_) =>
                                          _showCancelOrderDialog(order),
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'cancel',
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.cancel_outlined,
                                                color: Color(0xFFCF5F5F),
                                                size: 20,
                                              ),
                                              SizedBox(width: 10),
                                              Text(
                                                'Cancel Order',
                                                style: TextStyle(
                                                  color: Color(0xFFCF5F5F),
                                                  fontFamily: AppFonts.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
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
                                            fontSize: 25,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        OutlinedButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    OrderDetailScreen(
                                                      order: order,
                                                      onOrderUpdated: (_) {
                                                        OrderService.instance
                                                            .loadOrders();
                                                      },
                                                    ),
                                              ),
                                            );
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
          ],
        );
      },
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
        if (_isLoadingProducts) {
          return const CustomLoadingCenter();
        }
        if (_productsError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_productsError!, style: AppTextStyles.body),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loadProducts,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isSearchMode)
                _buildSearchModeContent()
              else ...[
                AutoBannerSlider(banners: _banners),
                const SizedBox(height: 12),
                _buildBrandsSection(),
                const SizedBox(height: 12),
                if (_promotionProducts.isNotEmpty) ...[
                  _buildHorizontalProductSection(
                    title: 'Promotion',
                    products: _promotionProducts,
                  ),
                  const SizedBox(height: 14),
                ],
                _buildHorizontalProductSection(
                  title: 'New Arrival',
                  products: _newArrivalProducts,
                ),
                const SizedBox(height: 14),
                if (_bestSellingProducts.isNotEmpty) ...[
                  _buildHorizontalProductSection(
                    title: 'Best Selling',
                    products: _bestSellingProducts,
                  ),
                  const SizedBox(height: 14),
                ],
                if (_mostViewedProducts.isNotEmpty) ...[
                  _buildHorizontalProductSection(
                    title: 'Most Viewed',
                    products: _mostViewedProducts,
                  ),
                  const SizedBox(height: 14),
                ],
                _buildHorizontalProductSection(
                  title: 'Hot Deals for this week',
                  products: _hotDealProducts,
                ),
              ],
            ],
          ),
        );
      case 1:
        return _buildWishlistPage();
      case 2:
        return _buildCartPage();
      case 3:
        return _buildMyOrdersPage();
      case 4:
        if (!_isLoggedIn) {
          return const GuestAuthGatePanel();
        }

        if (_isAccountLoading) {
          return const CustomLoadingCenter();
        }

        final displayName =
            (_userProfile?['full_name']?.toString().trim().isNotEmpty ?? false)
            ? _userProfile!['full_name'].toString().trim()
            : 'Your Name';
        final displayEmail = _userEmail.isNotEmpty ? _userEmail : 'No email';
        final initials = displayName.isNotEmpty
            ? displayName[0].toUpperCase()
            : (displayEmail.isNotEmpty ? displayEmail[0].toUpperCase() : 'U');

        return SafeArea(
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
                        child:
                            _userAvatarUrl != null && _userAvatarUrl!.isNotEmpty
                            ? Image.network(
                                _userAvatarUrl!,
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
                            displayName,
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
                        Icons.location_on_outlined,
                        color: AppColors.primaryGreen,
                      ),
                      title: const Text(
                        'Manage Addresses',
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openChooseDeliveryAddress,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(
                        Icons.person_outline,
                        color: AppColors.primaryGreen,
                      ),
                      title: const Text(
                        'My Profile',
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openProfileEdit,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(
                        Icons.help_outline,
                        color: AppColors.primaryGreen,
                      ),
                      title: const Text(
                        'FAQs',
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openHelpSupport,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(
                        Icons.info_outline,
                        color: AppColors.primaryGreen,
                      ),
                      title: const Text(
                        'Contact & About',
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openContactAbout,
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(
                        Icons.logout,
                        color: Colors.redAccent,
                      ),
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
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _notificationButton() {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.instance.unreadCountNotifier,
      builder: (context, unreadCount, _) {
        final visibleUnreadCount = _isLoggedIn ? unreadCount : 0;
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
              if (visibleUnreadCount > 0)
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
                      visibleUnreadCount > 9 ? '9+' : '$visibleUnreadCount',
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

  Widget _buildCartItemActions(CartItem item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E8E1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _cartActionIconButton(
            icon: Icons.edit_outlined,
            iconColor: AppColors.primaryGreen,
            splashColor: AppColors.primaryGreen.withValues(alpha: 0.10),
            tooltip: 'Edit',
            onTap: () => _showEditProductVariantSheet(item),
          ),
          Container(width: 26, height: 1, color: const Color(0xFFE5E8E1)),
          _cartActionIconButton(
            icon: Icons.delete_outline,
            iconColor: const Color(0xFFC76F6F),
            splashColor: const Color(0xFFC76F6F).withValues(alpha: 0.10),
            tooltip: 'Remove',
            onTap: () => _confirmAndRemoveCartItem(item),
          ),
        ],
      ),
    );
  }

  Widget _cartActionIconButton({
    required IconData icon,
    required Color iconColor,
    required Color splashColor,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          splashColor: splashColor,
          highlightColor: splashColor,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: iconColor, size: 21),
          ),
        ),
      ),
    );
  }

  Widget _bottomNavIconWithBadge({required IconData icon, required int count}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        if (count > 0)
          Positioned(
            right: -6,
            top: -4,
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

  void _handleBackPressed() {
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return;
    }

    final now = DateTime.now();
    final shouldExit =
        _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) < const Duration(seconds: 2);

    if (shouldExit) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressedAt = now;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackPressed();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightGrey,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: _chatButton(),
          leadingWidth: 56,
          title: _currentIndex == 2
              ? ValueListenableBuilder<List<CartItem>>(
                  valueListenable: CartService.instance.itemsNotifier,
                  builder: (context, items, _) {
                    return Text(
                      'Cart (${items.length})',
                      style: AppTextStyles.appBarTitle,
                    );
                  },
                )
              : _currentIndex == 0
              ? Image.asset(
                  'assets/logo.png',
                  height: 50,
                  fit: BoxFit.contain,
                  semanticLabel: 'BurmaBrands',
                )
              : Text(_appBarTitle(), style: AppTextStyles.appBarTitle),
          centerTitle: true,
          actions: [_notificationButton()],
          bottom: _currentIndex == 0
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(68),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: _buildHomeSearchBox(),
                  ),
                )
              : null,
        ),
        body: _buildCurrentPage(),
        bottomNavigationBar: ValueListenableBuilder<List<OrderModel>>(
          valueListenable: OrderService.instance.ordersNotifier,
          builder: (context, orders, _) {
            return ValueListenableBuilder<List<CartItem>>(
              valueListenable: CartService.instance.itemsNotifier,
              builder: (context, cartItems, _) {
                return ValueListenableBuilder<List<ProductModel>>(
                  valueListenable: WishlistService.instance.itemsNotifier,
                  builder: (context, wishlistItems, _) {
                    final cartCount = cartItems.length;
                    final visibleCartCount = _isLoggedIn ? cartCount : 0;
                    final wishlistCount = wishlistItems.length;
                    final visibleWishlistCount = _isLoggedIn
                        ? wishlistCount
                        : 0;
                    final visibleOrderCount = _isLoggedIn
                        ? _attentionOrderCount(orders)
                        : 0;
                    final bottomInset = MediaQuery.paddingOf(context).bottom;
                    final navBackground =
                        Theme.of(
                          context,
                        ).bottomNavigationBarTheme.backgroundColor ??
                        Theme.of(context).canvasColor;

                    return Material(
                      color: navBackground,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: bottomInset + 12),
                        child: MediaQuery.removePadding(
                          context: context,
                          removeBottom: true,
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              splashFactory: NoSplash.splashFactory,
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                            ),
                            child: BottomNavigationBar(
                              currentIndex: _currentIndex,
                              elevation: 0,
                              selectedItemColor: AppColors.primaryGreen,
                              unselectedItemColor: Colors.grey,
                              type: BottomNavigationBarType.fixed,
                              onTap: _handleTabTap,
                              items: [
                                const BottomNavigationBarItem(
                                  icon: Icon(Icons.home_outlined),
                                  activeIcon: Icon(Icons.home),
                                  label: 'Home',
                                ),
                                BottomNavigationBarItem(
                                  icon: _bottomNavIconWithBadge(
                                    icon: Icons.favorite_border,
                                    count: visibleWishlistCount,
                                  ),
                                  activeIcon: _bottomNavIconWithBadge(
                                    icon: Icons.favorite,
                                    count: visibleWishlistCount,
                                  ),
                                  label: 'Wishlist',
                                ),
                                BottomNavigationBarItem(
                                  icon: _bottomNavIconWithBadge(
                                    icon: Icons.shopping_cart_outlined,
                                    count: visibleCartCount,
                                  ),
                                  activeIcon: _bottomNavIconWithBadge(
                                    icon: Icons.shopping_cart,
                                    count: visibleCartCount,
                                  ),
                                  label: 'Cart',
                                ),
                                BottomNavigationBarItem(
                                  icon: _bottomNavIconWithBadge(
                                    icon: Icons.receipt_long_outlined,
                                    count: visibleOrderCount,
                                  ),
                                  activeIcon: _bottomNavIconWithBadge(
                                    icon: Icons.receipt_long,
                                    count: visibleOrderCount,
                                  ),
                                  label: 'My Orders',
                                ),
                                const BottomNavigationBarItem(
                                  icon: Icon(Icons.account_circle_outlined),
                                  activeIcon: Icon(Icons.account_circle),
                                  label: 'Account',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CartVariantOption {
  final String id;
  final String size;
  final String color;
  final int? colorValue;
  final int stock;
  final String imageUrl;
  final double price;

  const _CartVariantOption({
    required this.id,
    required this.size,
    required this.color,
    required this.colorValue,
    required this.stock,
    required this.imageUrl,
    required this.price,
  });
}

class _BrandInfo {
  final String id;
  final String name;
  final String logoUrl;

  const _BrandInfo({
    required this.id,
    required this.name,
    required this.logoUrl,
  });
}

Color _cartVariantColor(List<_CartVariantOption> variants, String colorName) {
  for (final variant in variants) {
    if (variant.color == colorName && variant.colorValue != null) {
      return Color(variant.colorValue!);
    }
  }
  return _colorFromName(colorName);
}

int? _nullableColorValue(dynamic value) {
  if (value == null) return null;
  final parsed = value is num ? value.toInt() : int.tryParse(value.toString());
  if (parsed == null) return null;
  return parsed < 0 ? parsed + 0x100000000 : parsed;
}

class _BrandComingSoonTile extends StatelessWidget {
  const _BrandComingSoonTile();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.storefront_outlined,
            size: 24,
            color: AppColors.subtleText,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Coming soon',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.subtleText,
            fontFamily: AppFonts.primary,
          ),
        ),
      ],
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _HomeEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: AppColors.primaryGreen),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.darkText,
              fontFamily: AppFonts.primary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.subtleText,
              fontFamily: AppFonts.primary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

bool _isDefaultVariantValue(String value) {
  return value.trim().toLowerCase() == 'default';
}

Color _colorFromName(String colorName) {
  switch (colorName.trim().toLowerCase()) {
    case 'black':
      return const Color(0xFF1C1C1C);
    case 'white':
      return const Color(0xFFF5F5F5);
    case 'red':
      return const Color(0xFFD84343);
    case 'blue':
      return const Color(0xFF3D59C9);
    case 'green':
      return const Color(0xFF2E7D32);
    case 'brown':
      return const Color(0xFF8B5E4A);
    case 'grey':
    case 'gray':
      return const Color(0xFF7A7A7A);
    case 'purple':
      return const Color(0xFF6F3FD1);
    case 'yellow':
      return const Color(0xFFF9A825);
    case 'orange':
      return const Color(0xFFF57C00);
    default:
      return const Color(0xFF4A4A4A);
  }
}
