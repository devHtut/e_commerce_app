import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../cart/cart_item.dart';
import '../cart/checkout_screen.dart';
import '../cart/cart_service.dart';
import '../order/order_service.dart';
import '../order/order_detail_screen.dart';
import '../auth/signin_screen.dart';
import '../auth/signup_screen.dart';
import '../product/product_detail_screen.dart';
import '../product/product_model.dart';
import '../wishlist/wishlist_service.dart';
import '../widgets/auto_banner_slider.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_pop_up.dart';
import '../widgets/product_card.dart';
import '../widgets/search_box.dart';
import '../theme_config.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _selectedCategoryIndex = 0;
  int _orderTabIndex = 0;
  String _searchQuery = '';
  bool _isLoadingProducts = true;
  String? _productsError;
  List<ProductModel> _products = [];
  List<String> _categories = const ['Discover'];
  bool get _isLoggedIn => Supabase.instance.client.auth.currentUser != null;
  static const List<String> _cartSizes = ['XS', 'S', 'M', 'L', 'XL'];
  static const List<_CartColorVariant> _cartColorVariants = [
    _CartColorVariant(name: 'Black', color: Color(0xFF1C1C1C)),
    _CartColorVariant(name: 'White', color: Color(0xFFF5F5F5)),
    _CartColorVariant(name: 'Brown', color: Color(0xFF8B5E4A)),
    _CartColorVariant(name: 'Blue Grey', color: Color(0xFF7797A7)),
    _CartColorVariant(name: 'Indigo', color: Color(0xFF3D59C9)),
    _CartColorVariant(name: 'Deep Purple', color: Color(0xFF6F3FD1)),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadProducts();
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
            'categories(name), brands(brand_name), '
            'product_variants(image_url)',
          )
          .order('created_at', ascending: false);

      final products = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ProductModel.fromSupabaseRow)
          .toList();
      final categoryNames = products
          .map((p) => p.category.trim())
          .where((c) => c.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (!mounted) return;
      setState(() {
        _products = products;
        _categories = ['Discover', ...categoryNames];
        if (_selectedCategoryIndex >= _categories.length) {
          _selectedCategoryIndex = 0;
        }
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

  List<ProductModel> get _filteredProducts {
    final safeIndex = _selectedCategoryIndex.clamp(0, _categories.length - 1);
    final selectedCategory = _categories[safeIndex];
    return _products.where((product) {
      final categoryMatch =
          selectedCategory == 'Discover' || product.category == selectedCategory;
      final query = _searchQuery.trim().toLowerCase();
      final searchMatch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.brand.toLowerCase().contains(query);
      return categoryMatch && searchMatch;
    }).toList();
  }

  List<ProductModel> get _newArrivalProducts => _products.take(4).toList();
  List<ProductModel> get _hotDealProducts => _products.reversed.take(4).toList();

  Widget _buildHorizontalProductSection({
    required String title,
    required List<ProductModel> products,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
          ),
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
                  isWishlisted: WishlistService.instance.isWishlisted(product.id),
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
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _toggleWishlist(ProductModel product) async {
    if (!_isLoggedIn) {
      await showCustomPopup(
        context,
        title: 'Sign in required',
        message: 'Please sign in to save products to wishlist.',
        type: PopupType.error,
      );
      return;
    }
    final added = WishlistService.instance.toggle(product);
    if (!mounted) return;
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
    if (mounted) setState(() {});
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
      final count = CartService.instance.itemsNotifier.value.length;
      return 'Cart ($count)';
    }
    if (_currentIndex == 1) {
      final count = WishlistService.instance.itemsNotifier.value.length;
      return 'Wishlist ($count)';
    }
    if (_currentIndex == 3) {
      return 'My Order';
    }
    if (_currentIndex == 0) {
      return 'Trendify';
    }
    return _titles[_currentIndex];
  }

  Future<void> _handleTabTap(int index) async {
    // Guests can browse Home freely; protected tabs require auth.
    if (!_isLoggedIn && [1, 2, 3].contains(index)) {
      await showCustomPopup(
        context,
        title: 'Sign in required',
        message: 'Please sign in to use wishlist, cart, and orders.',
        type: PopupType.error,
      );
      if (!mounted) return;
      setState(() {
        _currentIndex = 4;
      });
      return;
    }
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _showEditProductVariantSheet(CartItem item) async {
    int selectedSize = _cartSizes.indexOf(item.size);
    int selectedColor = _cartColorVariants.indexWhere(
      (variant) => variant.name == item.colorName,
    );
    int quantity = item.quantity;
    selectedSize = selectedSize == -1 ? 3 : selectedSize;
    selectedColor = selectedColor == -1 ? 0 : selectedColor;
    const int stock = 195;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colorVariant = _cartColorVariants[selectedColor];
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
                                'Stock  :  $stock',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontFamily: AppFonts.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '\$${item.product.price.toStringAsFixed(2)}',
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
                                padding: const EdgeInsets.symmetric(horizontal: 4),
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
                                      onPressed: quantity < stock
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
                      children: List.generate(_cartSizes.length, (index) {
                        final isSelected = selectedSize == index;
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index == _cartSizes.length - 1 ? 0 : 10,
                          ),
                          child: InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedSize = index;
                              });
                            },
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color:
                                    isSelected ? AppColors.primaryGreen : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryGreen
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                _cartSizes[index],
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
                        itemCount: _cartColorVariants.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final variant = _cartColorVariants[index];
                          final isSelected = selectedColor == index;
                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                selectedColor = index;
                              });
                            },
                            borderRadius: BorderRadius.circular(18),
                            child: Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: variant.color,
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
                                          color: index == 1
                                              ? AppColors.darkText
                                              : Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  variant.name,
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
                                  fontSize: 22,
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
                              onPressed: () {
                                CartService.instance.updateItemVariant(
                                  itemId: item.id,
                                  size: _cartSizes[selectedSize],
                                  colorName: colorVariant.name,
                                  colorValue: colorVariant.color.value,
                                  imageUrl: item.imageUrl,
                                  quantity: quantity,
                                );
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
                                  fontSize: 22,
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

    CartService.instance.removeItem(item.id);
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
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: const [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.check, color: Colors.white, size: 18),
                ),
                SizedBox(width: 12),
                Text(
                  'Removed from Cart!',
                  style: TextStyle(
                    color: Colors.white,
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
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(items: checkoutItems),
      ),
    );
  }

  Widget _buildCartPage() {
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
                            Text(
                              'Size: ${item.size}',
                              style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
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
                            Text(
                              'Qty: ${item.quantity}',
                              style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '\$${item.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 34,
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w700,
                                fontFamily: AppFonts.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit_outlined,
                              color: AppColors.darkText,
                            ),
                            onPressed: () => _showEditProductVariantSheet(item),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFDC9696),
                            ),
                            onPressed: () => _confirmAndRemoveCartItem(item),
                            tooltip: 'Remove',
                          ),
                        ],
                      ),
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
                    onTap: selectedCount > 0 ? () => _goToCheckout(items) : null,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Checkout ($selectedCount) - \$${selectedTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: AppFonts.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
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
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.58,
          ),
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
    if (d == today) return 'Today, ${months[date.month - 1]} ${date.day}, ${date.year}';
    if (d == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${months[date.month - 1]} ${date.day}, ${date.year}';
    }
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _showCancelOrderDialog(OrderModel order) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          'Cancel Order',
          style: TextStyle(
            color: Color(0xFFCF6E6E),
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
            child: const Text('Yes, Cancel Order'),
          ),
        ],
      ),
    );
    if (shouldCancel != true || !mounted) return;
    OrderService.instance.cancelOrder(order.id);
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
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyOrdersPage() {
    return ValueListenableBuilder<List<OrderModel>>(
      valueListenable: OrderService.instance.ordersNotifier,
      builder: (context, orders, _) {
        final active = orders.where((o) => o.status == OrderStatus.active).toList();
        final completed =
            orders.where((o) => o.status == OrderStatus.completed).toList();
        final canceled = orders.where((o) => o.status == OrderStatus.canceled).toList();
        final tabs = <(String, int)>[
          ('Active', active.length),
          ('Completed', completed.length),
          ('Canceled', canceled.length),
        ];
        final showing = switch (_orderTabIndex) {
          0 => active,
          1 => completed,
          _ => canceled,
        };
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
                  final selected = _orderTabIndex == index;
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
            Expanded(
              child: showing.isEmpty
                  ? const Center(
                      child: Text('No orders yet.', style: AppTextStyles.body),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: showing.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final order = showing[index];
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
                                    child: Text(
                                      _formatOrderDate(order.createdAt),
                                      style: TextStyle(
                                        fontFamily: AppFonts.primary,
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  if (order.status == OrderStatus.active)
                                    PopupMenuButton<String>(
                                      onSelected: (_) => _showCancelOrderDialog(order),
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'cancel',
                                          child: Text('Cancel Order'),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                            padding: const EdgeInsets.only(top: 2),
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
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    OrderDetailScreen(order: order),
                                              ),
                                            );
                                          },
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                                color: AppColors.primaryGreen),
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
          return const Center(child: CircularProgressIndicator());
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
            children: [
              SearchBox(
                hintText: 'Search Trends...',
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
              const SizedBox(height: 12),
              AutoBannerSlider(banners: _banners),
              const SizedBox(height: 12),
              _buildHorizontalProductSection(
                title: 'New Arrival',
                products: _newArrivalProducts,
              ),
              const SizedBox(height: 14),
              _buildHorizontalProductSection(
                title: 'Hot Deals for this week',
                products: _hotDealProducts,
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final isSelected = index == _selectedCategoryIndex;
                    return ChoiceChip(
                      label: Text(
                        _categories[index],
                        style: TextStyle(
                          fontFamily: AppFonts.primary,
                          color: isSelected ? Colors.white : AppColors.darkText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategoryIndex = index;
                        });
                      },
                      selectedColor: AppColors.primaryGreen,
                      backgroundColor: Colors.transparent,
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryGreen : Colors.black26,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                itemCount: _filteredProducts.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.58,
                ),
                itemBuilder: (context, index) {
                  final product = _filteredProducts[index];
                  return ProductCard(
                    product: product,
                    isWishlisted: WishlistService.instance.isWishlisted(product.id),
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
              ),
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
        if (_isLoggedIn) {
          return const Center(
            child: Text(
              'You are signed in. Manage account from here.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Create your account to save wishlist, cart, and orders.',
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: CustomButton(
                  text: 'Sign up',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignInScreen()),
                  );
                },
                child: const Text(
                  'Already have an account? Sign in',
                  style: TextStyle(
                    color: AppColors.primaryGreen,
                    fontFamily: AppFonts.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        leading: _currentIndex == 0
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryGreen,
                  ),
                  child: const Icon(Icons.eco, size: 18, color: Colors.white),
                ),
              )
            : null,
        leadingWidth: _currentIndex == 0 ? 52 : null,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: _currentIndex == 2
            ? ValueListenableBuilder<List<CartItem>>(
                valueListenable: CartService.instance.itemsNotifier,
                builder: (context, items, _) {
                  return Text(
                    'Cart (${items.length})',
                    style: TextStyle(
                      fontFamily: AppFonts.primary,
                      color: AppColors.darkText,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              )
            : Text(
                _appBarTitle(),
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  color: AppColors.darkText,
                  fontWeight: FontWeight.bold,
                ),
              ),
        centerTitle: _currentIndex == 0,
        actions: _isLoggedIn
            ? [
                if (_currentIndex == 0)
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.darkText,
                    ),
                    tooltip: 'Notifications',
                  ),
                IconButton(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout, color: AppColors.darkText),
                  tooltip: 'Logout',
                ),
              ]
            : _currentIndex == 0
                ? [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.notifications_none_rounded,
                        color: AppColors.darkText,
                      ),
                      tooltip: 'Notifications',
                    ),
                  ]
                : null,
      ),
      body: _buildCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _handleTabTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Wishlist',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart_outlined),
            activeIcon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'My Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class _CartColorVariant {
  final String name;
  final Color color;

  const _CartColorVariant({
    required this.name,
    required this.color,
  });
}
