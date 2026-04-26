import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../cart/cart_item.dart';
import '../cart/cart_service.dart';
import '../auth/signin_screen.dart';
import '../auth/signup_screen.dart';
import '../product/product_detail_screen.dart';
import '../product/product_model.dart';
import '../widgets/auto_banner_slider.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_pop_up.dart';
import '../widgets/product_card.dart';
import '../widgets/search_box.dart';
import '../theme_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _selectedCategoryIndex = 0;
  String _searchQuery = '';
  bool get _isLoggedIn => Supabase.instance.client.auth.currentUser != null;
  static const List<String> _categories = [
    'Discover',
    'Women',
    'Men',
    'Shoes',
    'Accessories',
  ];

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

  final List<ProductModel> _products = const [
    ProductModel(
      id: 'p1',
      name: 'Urban Blend Long Sleeve',
      category: 'Women',
      brand: 'Trendify Studio',
      price: 185,
      rating: 4.8,
      imageUrl:
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=900&q=80',
    ),
    ProductModel(
      id: 'p2',
      name: 'Classic Denim Jacket',
      category: 'Men',
      brand: 'BlueMark',
      price: 219,
      rating: 4.6,
      imageUrl:
          'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?auto=format&fit=crop&w=900&q=80',
    ),
    ProductModel(
      id: 'p3',
      name: 'Minimal Linen Shirt',
      category: 'Women',
      brand: 'North Thread',
      price: 149,
      rating: 4.7,
      imageUrl:
          'https://images.unsplash.com/photo-1483985988355-763728e1935b?auto=format&fit=crop&w=900&q=80',
    ),
    ProductModel(
      id: 'p4',
      name: 'Signature Straight Jeans',
      category: 'Men',
      brand: 'Rawline',
      price: 199,
      rating: 4.5,
      imageUrl:
          'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?auto=format&fit=crop&w=900&q=80',
    ),
  ];

  List<ProductModel> get _filteredProducts {
    final selectedCategory = _categories[_selectedCategoryIndex];
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
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(product: product),
                      ),
                    );
                  },
                  onWishlistTap: () async {
                    if (!_isLoggedIn) {
                      await showCustomPopup(
                        context,
                        title: 'Sign in required',
                        message: 'Please sign in to save products to wishlist.',
                        type: PopupType.error,
                      );
                      return;
                    }
                    await showCustomPopup(
                      context,
                      title: 'Saved',
                      message: '${product.name} added to wishlist.',
                      type: PopupType.success,
                    );
                  },
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
                            onPressed: () {},
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFFDC9696),
                            ),
                            onPressed: () {
                              CartService.instance.removeItem(item.id);
                            },
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
          ],
        );
      },
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 0:
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(product: product),
                        ),
                      );
                    },
                    onWishlistTap: () async {
                      if (!_isLoggedIn) {
                        await showCustomPopup(
                          context,
                          title: 'Sign in required',
                          message: 'Please sign in to save products to wishlist.',
                          type: PopupType.error,
                        );
                        return;
                      }
                      await showCustomPopup(
                        context,
                        title: 'Saved',
                        message: '${product.name} added to wishlist.',
                        type: PopupType.success,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      case 1:
        return const Center(child: Text('Your wishlist will appear here.', style: AppTextStyles.body));
      case 2:
        return _buildCartPage();
      case 3:
        return const Center(child: Text('Your orders will appear here.', style: AppTextStyles.body));
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
