import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/vendor_access.dart';
import '../chat/chat_service.dart';
import '../customer/chat_screen.dart';
import '../product/product_detail_screen.dart';
import '../product/product_model.dart';
import '../product/product_sales_service.dart';
import '../theme_config.dart';
import '../widgets/custom_pop_up.dart';
import '../widgets/guest_auth_gate.dart';
import '../widgets/product_card.dart';
import '../wishlist/wishlist_service.dart';
import 'brand_analytics_service.dart';

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
  Map<String, ProductEngagementMetrics> _productMetrics = {};
  List<String> _categories = const ['Discover'];
  List<String> _audiences = const ['All'];
  int _selectedCategoryIndex = 0;
  int _selectedAudienceIndex = 0;
  _ShopSort? _sort = _ShopSort.latestArrival;
  bool _embeddedVendorAccessPending = false;

  @override
  void initState() {
    super.initState();
    if (Supabase.instance.client.auth.currentUser != null) {
      WishlistService.instance.loadWishlistItems();
    }
    if (widget.embedded) {
      _embeddedVendorAccessPending = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _startEmbeddedVendor(),
      );
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
          _audiences = const ['All'];
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
            'audience_id, categories(name), audiences(name), brands(brand_name,logo_url), product_variants(image_url,price_adjustment,promo_price)',
          )
          .eq('brand_id', brandRow['id'].toString())
          .order('created_at', ascending: false);

      final products = (productRows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ProductModel.fromSupabaseRow)
          .toList();
      final metrics = await ProductSalesService.instance.loadMetricsForProducts(
        products.map((product) => product.id).toList(),
      );
      final categories =
          products
              .map((product) => product.category.trim())
              .where((category) => category.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      final audiences =
          products
              .map((product) => product.audience.trim())
              .where((audience) => audience.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      if (!mounted) return;
      setState(() {
        _shop = _ShopInfo.fromRows(brandRow!, vendorRow);
        _products = products;
        _productMetrics = metrics;
        _categories = ['Discover', ...categories];
        _audiences = ['All', ...audiences];
        _selectedCategoryIndex = 0;
        _selectedAudienceIndex = 0;
      });
      if (!widget.embedded) {
        final shop = _ShopInfo.fromRows(brandRow, vendorRow);
        unawaited(
          BrandAnalyticsService.instance.recordBrandProfileVisit(
            brandId: shop.id,
            ownerId: shop.ownerId,
          ),
        );
      }
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
    final safeAudienceIndex = _selectedAudienceIndex.clamp(
      0,
      _audiences.length - 1,
    );
    final selectedAudience = _audiences[safeAudienceIndex];
    final filtered = _products.where((product) {
      final categoryMatch =
          selectedCategory == 'Discover' ||
          product.category == selectedCategory;
      final audienceMatch =
          selectedAudience == 'All' ||
          product.audience == selectedAudience;
      return categoryMatch && audienceMatch;
    }).toList();

    switch (_sort) {
      case _ShopSort.promotion:
        filtered.sort((a, b) {
          if (a.hasPromotion != b.hasPromotion) {
            return a.hasPromotion ? -1 : 1;
          }
          return b.promotionPercent.compareTo(a.promotionPercent);
        });
      case _ShopSort.priceHighToLow:
        filtered.sort((a, b) => b.price.compareTo(a.price));
      case _ShopSort.priceLowToHigh:
        filtered.sort((a, b) => a.price.compareTo(b.price));
      case _ShopSort.bestSelling:
        filtered.sort(
          (a, b) => (_productMetrics[b.id]?.soldCount ?? 0).compareTo(
            _productMetrics[a.id]?.soldCount ?? 0,
          ),
        );
      case _ShopSort.mostViewed:
        filtered.sort(
          (a, b) => (_productMetrics[b.id]?.viewCount ?? 0).compareTo(
            _productMetrics[a.id]?.viewCount ?? 0,
          ),
        );
      case _ShopSort.latestArrival:
      case null:
        break;
    }

    return filtered;
  }

  bool get _hasAudienceFilter => _selectedAudienceIndex > 0;

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
          child: _ShopBottomSheetPanel(
            title: 'Sort',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in _ShopSort.values)
                  _ShopSheetOptionTile(
                    label: option.label,
                    selected: option == _sort,
                    onTap: () => Navigator.pop(context, option),
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

  Future<void> _openFilterSheet() async {
    var selectedIndex = _selectedAudienceIndex;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: _ShopBottomSheetPanel(
                title: 'Filter',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Audience',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_audiences.length, (index) {
                        return _ShopFilterChip(
                          label: _audiences[index],
                          selected: selectedIndex == index,
                          onTap: () {
                            setModalState(() => selectedIndex = index);
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() => selectedIndex = 0);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                              side: const BorderSide(
                                color: AppColors.primaryGreen,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: const Text('Reset'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: const Text('Apply'),
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

    if (applied != true || !mounted) return;
    setState(() => _selectedAudienceIndex = selectedIndex);
  }

  Future<void> _openShopChat(_ShopInfo shop) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await GuestAuthGatePanel.show(context);
      return;
    }
    if (shop.ownerId.isEmpty) return;

    try {
      final option = ChatStartOption(
        userId: shop.ownerId,
        title: shop.name,
        subtitle: 'Vendor',
        imageUrl: shop.logoUrl,
      );
      final chat = await ChatService.instance.createOrGetDirectChat(option);
      if (!mounted || chat == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(initialChatId: chat.id)),
      );
    } catch (_) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Chat not started',
        message: 'Please try again in a moment.',
        type: PopupType.error,
      );
    }
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
        centerTitle: true,
        title: const Text(
          'Shop Profile',
          style: TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
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

    return Stack(
      children: [
        RefreshIndicator(
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
                    child: Text(
                      'No products found.',
                      style: AppTextStyles.body,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 104),
                  sliver: SliverGrid.builder(
                    itemCount: _visibleProducts.length,
                    gridDelegate: ProductCard.gridDelegate,
                    itemBuilder: (context, index) {
                      final product = _visibleProducts[index];
                      return ProductCard(
                        product: product,
                        isWishlisted: widget.embedded
                            ? false
                            : WishlistService.instance.isWishlisted(product.id),
                        onWishlistTap: widget.embedded
                            ? null
                            : () async {
                                if (Supabase.instance.client.auth.currentUser ==
                                    null) {
                                  await GuestAuthGatePanel.show(context);
                                  return;
                                }
                                try {
                                  await WishlistService.instance.toggle(
                                    product,
                                  );
                                } catch (e) {
                                  debugPrint('Unable to update wishlist: $e');
                                }
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
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 16,
          child: Center(
            child: _ShopBottomControls(
              sortLabel: _sort == _ShopSort.latestArrival
                  ? 'Sort'
                  : _sort!.shortLabel,
              filterActive: _hasAudienceFilter,
              onSort: _openSortSheet,
              onFilter: _openFilterSheet,
            ),
          ),
        ),
      ],
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
              if (!widget.embedded &&
                  shop.ownerId.isNotEmpty &&
                  shop.ownerId != Supabase.instance.client.auth.currentUser?.id)
                _ShopActionChip(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Send Message',
                  onTap: () => _openShopChat(shop),
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
      child: SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final selected = index == _selectedCategoryIndex;
            return _ShopPillButton(
              label: _categories[index],
              selected: selected,
              onTap: () => setState(() => _selectedCategoryIndex = index),
            );
          },
        ),
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

class _ShopPillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ShopPillButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primaryGreen : Colors.black12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _ShopBottomControls extends StatelessWidget {
  final String sortLabel;
  final bool filterActive;
  final VoidCallback onSort;
  final VoidCallback onFilter;

  const _ShopBottomControls({
    required this.sortLabel,
    required this.filterActive,
    required this.onSort,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: onSort,
              icon: const Icon(Icons.swap_vert_rounded),
              label: Text(sortLabel),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.darkText,
                textStyle: const TextStyle(
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(width: 1, height: 24, color: Colors.black12),
            TextButton.icon(
              onPressed: onFilter,
              icon: Icon(
                filterActive ? Icons.tune : Icons.tune_outlined,
                color: filterActive ? AppColors.primaryGreen : null,
              ),
              label: Text(filterActive ? 'Filter On' : 'Filter'),
              style: TextButton.styleFrom(
                foregroundColor: filterActive
                    ? AppColors.primaryGreen
                    : AppColors.darkText,
                textStyle: const TextStyle(
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopBottomSheetPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _ShopBottomSheetPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30), bottom: Radius.circular(30)),
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
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.darkText,
                fontFamily: AppFonts.primary,
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.62,
            ),
            child: SingleChildScrollView(child: child),
          ),
        ],
      ),
    );
  }
}

class _ShopFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ShopFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryGreen,
      backgroundColor: Colors.white,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.darkText,
        fontFamily: AppFonts.primary,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? AppColors.primaryGreen : Colors.black12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}

class _ShopSheetOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ShopSheetOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: AppColors.primaryGreen,
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.darkText,
          fontFamily: AppFonts.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ShopInfo {
  final String id;
  final String ownerId;
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
    required this.ownerId,
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
      ownerId: text(brand, 'owner_id'),
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
  bestSelling('Best Selling', 'Best'),
  mostViewed('Most Viewed', 'Viewed'),
  promotion('Promotion', 'Promo'),
  priceHighToLow('Price High to Low', 'High-Low'),
  priceLowToHigh('Price Low to High', 'Low-High'),
  latestArrival('Latest Arrival', 'Sort');

  final String label;
  final String shortLabel;
  const _ShopSort(this.label, this.shortLabel);
}
