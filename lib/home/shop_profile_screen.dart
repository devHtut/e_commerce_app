import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/vendor_access.dart';
import '../product/product_detail_screen.dart';
import '../product/product_model.dart';
import '../theme_config.dart';
import '../widgets/guest_auth_gate.dart';
import '../widgets/product_card.dart';
import '../wishlist/wishlist_service.dart';

class ShopProfileScreen extends StatefulWidget {
  final String? brandId;
  final String? ownerId;
  final bool embedded;

  const ShopProfileScreen({
    super.key,
    this.brandId,
    this.ownerId,
    this.embedded = false,
  });

  @override
  State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen> {
  bool _loading = true;
  String? _error;
  _ShopInfo? _shop;
  List<ProductModel> _products = [];
  List<String> _categories = const ['Discover'];
  int _selectedCategoryIndex = 0;
  _ShopSort _sort = _ShopSort.mostSuitable;
  bool _embeddedVendorAccessPending = false;

  @override
  void initState() {
    super.initState();
    if (widget.embedded) {
      _embeddedVendorAccessPending = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _startEmbeddedVendor());
    } else {
      _loadShop();
    }
  }

  Future<void> _startEmbeddedVendor() async {
    final ok = await VendorAccess.ensureVendorOrRedirect(context);
    if (!mounted || !ok) return;
    setState(() => _embeddedVendorAccessPending = false);
    _loadShop();
  }

  Future<void> _loadShop() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      Map<String, dynamic>? brandRow;

      if (widget.brandId != null && widget.brandId!.isNotEmpty) {
        brandRow = await client
            .from('brands')
            .select('*')
            .eq('id', widget.brandId!)
            .maybeSingle();
      } else {
        final ownerId = widget.ownerId ?? client.auth.currentUser?.id;
        if (ownerId != null && ownerId.isNotEmpty) {
          brandRow = await client
              .from('brands')
              .select('*')
              .eq('owner_id', ownerId)
              .maybeSingle();
        }
      }

      if (brandRow == null) {
        if (!mounted) return;
        setState(() {
          _shop = null;
          _products = [];
          _categories = const ['Discover'];
          _error = 'Shop profile not found.';
        });
        return;
      }

      final ownerId = brandRow['owner_id']?.toString();
      Map<String, dynamic>? vendorRow;
      if (ownerId != null && ownerId.isNotEmpty) {
        vendorRow = await client
            .from('vendors')
            .select('*')
            .eq('user_id', ownerId)
            .maybeSingle();
      }

      final productRows = await client
          .from('products')
          .select(
            'id, brand_id, category_id, title, description, base_price, created_at, '
            'categories(name), brands(brand_name,logo_url), product_variants(image_url)',
          )
          .eq('brand_id', brandRow['id'].toString())
          .order('created_at', ascending: false);

      final products = (productRows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ProductModel.fromSupabaseRow)
          .toList();
      final categories =
          products
              .map((product) => product.category.trim())
              .where((category) => category.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      if (!mounted) return;
      setState(() {
        _shop = _ShopInfo.fromRows(brandRow!, vendorRow);
        _products = products;
        _categories = ['Discover', ...categories];
        if (_selectedCategoryIndex >= _categories.length) {
          _selectedCategoryIndex = 0;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load shop profile.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ProductModel> get _visibleProducts {
    final safeIndex = _selectedCategoryIndex.clamp(0, _categories.length - 1);
    final selectedCategory = _categories[safeIndex];
    final filtered = _products.where((product) {
      return selectedCategory == 'Discover' ||
          product.category == selectedCategory;
    }).toList();

    switch (_sort) {
      case _ShopSort.priceHighToLow:
        filtered.sort((a, b) => b.price.compareTo(a.price));
      case _ShopSort.priceLowToHigh:
        filtered.sort((a, b) => a.price.compareTo(b.price));
      case _ShopSort.topRated:
      case _ShopSort.popularity:
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
      case _ShopSort.latestArrival:
      case _ShopSort.discount:
      case _ShopSort.mostSuitable:
        break;
    }

    return filtered;
  }

  Future<void> _launch(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Uri _externalUri(String value) {
    final trimmed = value.trim();
    final uri = Uri.parse(trimmed);
    if (uri.hasScheme) return uri;
    return Uri.parse('https://$trimmed');
  }

  Future<void> _openSortSheet() async {
    final selected = await showModalBottomSheet<_ShopSort>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Sort',
                  style: TextStyle(
                    color: AppColors.darkText,
                    fontFamily: AppFonts.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 8),
                for (final option in _ShopSort.values)
                  InkWell(
                    onTap: () => Navigator.pop(context, option),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          _SortRadioDot(selected: option == _sort),
                          const SizedBox(width: 16),
                          Text(
                            option.label,
                            style: const TextStyle(
                              color: AppColors.darkText,
                              fontFamily: AppFonts.primary,
                              fontWeight: FontWeight.w500,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null || !mounted) return;
    setState(() => _sort = selected);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded && _embeddedVendorAccessPending) {
      return const Center(child: CircularProgressIndicator());
    }

    final body = _buildBody();

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.darkText),
        centerTitle: true,
        title: const Text(
          'Shop Profile',
          style: TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                style: AppTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _loadShop, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final shop = _shop;
    if (shop == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _loadShop,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _buildShopHeader(shop),
            ),
          ),
          SliverToBoxAdapter(child: _buildControls()),
          if (_visibleProducts.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('No products found.', style: AppTextStyles.body),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
              sliver: SliverGrid.builder(
                itemCount: _visibleProducts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.58,
                ),
                itemBuilder: (context, index) {
                  final product = _visibleProducts[index];
                  return ProductCard(
                    product: product,
                    isWishlisted: WishlistService.instance.isWishlisted(
                      product.id,
                    ),
                    onWishlistTap: () async {
                      if (Supabase.instance.client.auth.currentUser == null) {
                        await GuestAuthGatePanel.show(context);
                        return;
                      }
                      await WishlistService.instance.toggle(product);
                      if (mounted) setState(() {});
                    },
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(
                            product: product,
                            hideShoppingActions: widget.embedded,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShopHeader(_ShopInfo shop) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                child: shop.logoUrl.isEmpty
                    ? Container(
                        width: 72,
                        height: 72,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.storefront_outlined, size: 34),
                      )
                    : Image.network(
                        shop.logoUrl,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shop.name,
                      style: const TextStyle(
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    if (shop.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        shop.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.subtleText,
                          fontFamily: AppFonts.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (shop.phone.isNotEmpty)
                _ShopActionChip(
                  icon: Icons.call_outlined,
                  label: shop.phone,
                  onTap: () => _launch(Uri(scheme: 'tel', path: shop.phone)),
                ),
              if (shop.address.isNotEmpty || shop.addressUrl.isNotEmpty)
                _ShopActionChip(
                  icon: Icons.location_on_outlined,
                  label: shop.address.isEmpty ? 'Address' : shop.address,
                  onTap: shop.addressUrl.isEmpty
                      ? null
                      : () => _launch(_externalUri(shop.addressUrl)),
                ),
              if (shop.facebookUrl.isNotEmpty)
                _ShopActionChip(
                  icon: Icons.facebook,
                  label: 'Facebook',
                  onTap: () => _launch(_externalUri(shop.facebookUrl)),
                ),
              if (shop.instagramUrl.isNotEmpty)
                _ShopActionChip(
                  icon: Icons.camera_alt_outlined,
                  label: 'Instagram',
                  onTap: () => _launch(_externalUri(shop.instagramUrl)),
                ),
              if (shop.tiktokUrl.isNotEmpty)
                _ShopActionChip(
                  icon: Icons.music_note_outlined,
                  label: 'TikTok',
                  onTap: () => _launch(_externalUri(shop.tiktokUrl)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final selected = index == _selectedCategoryIndex;
                  return ChoiceChip(
                    label: Text(
                      _categories[index],
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        color: selected ? Colors.white : AppColors.darkText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedCategoryIndex = index);
                    },
                    selectedColor: AppColors.primaryGreen,
                    backgroundColor: Colors.transparent,
                    side: BorderSide(
                      color: selected ? AppColors.primaryGreen : Colors.black26,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: _openSortSheet,
            icon: const Icon(Icons.tune),
            tooltip: 'Sort',
            style: IconButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
              backgroundColor: Colors.white,
              fixedSize: const Size(44, 44),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ShopActionChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.lightGrey,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primaryGreen),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortRadioDot extends StatelessWidget {
  final bool selected;

  const _SortRadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryGreen, width: 2.5),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGreen,
                ),
              ),
            )
          : null,
    );
  }
}

class _ShopInfo {
  final String id;
  final String name;
  final String logoUrl;
  final String description;
  final String phone;
  final String address;
  final String addressUrl;
  final String facebookUrl;
  final String instagramUrl;
  final String tiktokUrl;

  const _ShopInfo({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.description,
    required this.phone,
    required this.address,
    required this.addressUrl,
    required this.facebookUrl,
    required this.instagramUrl,
    required this.tiktokUrl,
  });

  factory _ShopInfo.fromRows(
    Map<String, dynamic> brand,
    Map<String, dynamic>? vendor,
  ) {
    String text(Map<String, dynamic>? row, String key) {
      return row?[key]?.toString().trim() ?? '';
    }

    return _ShopInfo(
      id: text(brand, 'id'),
      name: text(brand, 'brand_name').isEmpty
          ? 'Shop'
          : text(brand, 'brand_name'),
      logoUrl: text(brand, 'logo_url'),
      description: text(brand, 'description'),
      phone: text(vendor, 'phone'),
      address: text(vendor, 'address'),
      addressUrl: text(vendor, 'address_url'),
      facebookUrl: text(vendor, 'facebook_url'),
      instagramUrl: text(vendor, 'instagram_url'),
      tiktokUrl: text(vendor, 'tiktok_url'),
    );
  }
}

enum _ShopSort {
  mostSuitable('Most Suitable'),
  popularity('Popularity'),
  topRated('Top Rated'),
  priceHighToLow('Price High to Low'),
  priceLowToHigh('Price Low to High'),
  latestArrival('Latest Arrival'),
  discount('Discount');

  final String label;
  const _ShopSort(this.label);
}
