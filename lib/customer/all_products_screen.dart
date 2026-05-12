import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../product/product_detail_screen.dart';
import '../product/product_model.dart';
import '../theme_config.dart';
import '../widgets/guest_auth_gate.dart';
import '../widgets/product_card.dart';
import '../widgets/search_box.dart';
import '../wishlist/wishlist_service.dart';

class AllProductsScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialCategory;

  const AllProductsScreen({super.key, this.initialQuery, this.initialCategory});

  @override
  State<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends State<AllProductsScreen> {
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedCategory = 'Discover';
  String? _selectedAudience;
  String? _selectedBrand;
  _ProductSort _sort = _ProductSort.latestArrival;

  List<ProductModel> _products = [];
  List<String> _categories = const ['Discover'];
  List<String> _audiences = const [];
  List<String> _brands = const [];

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialQuery?.trim() ?? '';
    _searchController.text = _searchQuery;
    if (widget.initialCategory?.trim().isNotEmpty ?? false) {
      _selectedCategory = widget.initialCategory!.trim();
    }
    if (Supabase.instance.client.auth.currentUser != null) {
      WishlistService.instance.loadWishlistItems();
    }
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rows = await Supabase.instance.client
          .from('products')
          .select(
            'id, brand_id, category_id, audience_id, title, description, base_price, '
            'categories(name), audiences(name), brands(brand_name,logo_url), '
            'product_variants(image_url)',
          )
          .order('created_at', ascending: false);

      final products = (rows as List<dynamic>)
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
      final audiences =
          products
              .map((product) => product.audience.trim())
              .where((audience) => audience.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      final brands =
          products
              .map((product) => product.brand.trim())
              .where((brand) => brand.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      if (!mounted) return;
      setState(() {
        _products = products;
        _categories = ['Discover', ...categories];
        _audiences = audiences;
        _brands = brands;
        if (!_categories.contains(_selectedCategory)) {
          _selectedCategory = 'Discover';
        }
        if (_selectedAudience != null &&
            !_audiences.contains(_selectedAudience)) {
          _selectedAudience = null;
        }
        if (_selectedBrand != null && !_brands.contains(_selectedBrand)) {
          _selectedBrand = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load products right now.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ProductModel> get _visibleProducts {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _products.where((product) {
      final categoryMatch =
          _selectedCategory == 'Discover' ||
          product.category == _selectedCategory;
      final audienceMatch =
          _selectedAudience == null || product.audience == _selectedAudience;
      final brandMatch =
          _selectedBrand == null || product.brand == _selectedBrand;
      final searchMatch =
          query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.brand.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          product.audience.toLowerCase().contains(query) ||
          product.description.toLowerCase().contains(query);
      return categoryMatch && audienceMatch && brandMatch && searchMatch;
    }).toList();

    switch (_sort) {
      case _ProductSort.priceHighToLow:
        filtered.sort((a, b) => b.price.compareTo(a.price));
      case _ProductSort.priceLowToHigh:
        filtered.sort((a, b) => a.price.compareTo(b.price));
      case _ProductSort.latestArrival:
        break;
    }
    return filtered;
  }

  bool get _hasFilter => _selectedAudience != null || _selectedBrand != null;

  void _openProduct(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
    );
  }

  Future<void> _toggleWishlist(ProductModel product) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await GuestAuthGatePanel.show(context);
      return;
    }
    try {
      await WishlistService.instance.toggle(product);
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update wishlist.')),
      );
    }
  }

  Future<void> _openSortSheet() async {
    final selected = await showModalBottomSheet<_ProductSort>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: _BottomSheetPanel(
            title: 'Sort',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in _ProductSort.values)
                  _SheetOptionTile(
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
    var audience = _selectedAudience;
    var brand = _selectedBrand;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: _BottomSheetPanel(
                title: 'Filter',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FilterSection(
                      title: 'Audience',
                      values: _audiences,
                      selected: audience,
                      onChanged: (value) {
                        setModalState(() => audience = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    _FilterSection(
                      title: 'Brand',
                      values: _brands,
                      selected: brand,
                      onChanged: (value) {
                        setModalState(() => brand = value);
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setModalState(() {
                                audience = null;
                                brand = null;
                              });
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
    setState(() {
      _selectedAudience = audience;
      _selectedBrand = brand;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.darkText,
                    tooltip: 'Back',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SearchBox(
                      controller: _searchController,
                      hintText: 'Search products',
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                      onSubmitted: (value) {
                        setState(() => _searchQuery = value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  return _PillButton(
                    label: category,
                    selected: category == _selectedCategory,
                    onTap: () => setState(() => _selectedCategory = category),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _BottomControls(
        sortLabel: _sort.shortLabel,
        filterActive: _hasFilter,
        onSort: _openSortSheet,
        onFilter: _openFilterSheet,
      ),
    );
  }

  Widget _buildContent() {
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
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _loadProducts, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final products = _visibleProducts;
    if (products.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No products found.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 92),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
        childAspectRatio: 0.56,
      ),
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          isWishlisted: WishlistService.instance.isWishlisted(product.id),
          onTap: () => _openProduct(product),
          onWishlistTap: () => _toggleWishlist(product),
        );
      },
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PillButton({
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

class _BottomControls extends StatelessWidget {
  final String sortLabel;
  final bool filterActive;
  final VoidCallback onSort;
  final VoidCallback onFilter;

  const _BottomControls({
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

class _BottomSheetPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _BottomSheetPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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

class _SheetOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SheetOptionTile({
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

class _FilterSection extends StatelessWidget {
  final String title;
  final List<String> values;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _FilterSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
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
          children: [
            _FilterChipButton(
              label: 'All',
              selected: selected == null,
              onTap: () => onChanged(null),
            ),
            for (final value in values)
              _FilterChipButton(
                label: value,
                selected: selected == value,
                onTap: () => onChanged(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
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

enum _ProductSort {
  latestArrival('Latest Arrival', 'Sort'),
  priceHighToLow('Price High to Low', 'High-Low'),
  priceLowToHigh('Price Low to High', 'Low-High');

  final String label;
  final String shortLabel;
  const _ProductSort(this.label, this.shortLabel);
}
