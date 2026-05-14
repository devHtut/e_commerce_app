import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/vendor_access.dart';
import '../notification/notification_service.dart';
import '../theme_config.dart';
import '../widgets/price_formatter.dart';
import '../widgets/search_box.dart';
import 'create_product_screen.dart';
import 'vendor_inventory_service.dart';
import 'vendor_product_detail_screen.dart';

class VendorProductsScreen extends StatefulWidget {
  const VendorProductsScreen({super.key});

  @override
  State<VendorProductsScreen> createState() => _VendorProductsScreenState();
}

class _VendorProductsScreenState extends State<VendorProductsScreen> {
  final List<_VendorVariantProduct> _variantProducts = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  bool _vendorAccessOk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVendorThenLoad());
  }

  Future<void> _ensureVendorThenLoad() async {
    final ok = await VendorAccess.ensureVendorOrRedirect(context);
    if (!mounted || !ok) return;
    setState(() => _vendorAccessOk = true);
    _loadVendorProducts();
  }

  List<_VendorVariantProduct> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _variantProducts;
    return _variantProducts
        .where(
          (p) =>
              p.name.toLowerCase().contains(query) ||
              p.variantLabel.toLowerCase().contains(query) ||
              p.sku.toLowerCase().contains(query) ||
              formatKyat(p.price).toLowerCase().contains(query) ||
              p.price.round().toString().contains(query),
        )
        .toList();
  }

  Future<void> _loadVendorProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => _error = 'Please sign in as vendor.');
        return;
      }

      final brand = await Supabase.instance.client
          .from('brands')
          .select('id')
          .eq('owner_id', user.id)
          .maybeSingle();
      if (brand == null) {
        setState(() => _error = 'No brand profile found.');
        return;
      }

      final productRows = await Supabase.instance.client
          .from('products')
          .select(
            'id, title, base_price, created_at, '
            'product_variants(id,size,color,stock_quantity,price_adjustment,promo_price,image_url,sku)',
          )
          .eq('brand_id', brand['id'])
          .order('created_at', ascending: false);

      final variantProducts = <_VendorVariantProduct>[];
      for (final row in (productRows as List<dynamic>)
          .cast<Map<String, dynamic>>()) {
        final basePrice = (row['base_price'] as num?)?.toDouble() ?? 0;
        final variants =
            (row['product_variants'] as List<dynamic>? ?? const <dynamic>[])
                .cast<Map<String, dynamic>>();
        for (final variant in variants) {
          final priceAdjustment =
              (variant['price_adjustment'] as num?)?.toDouble() ?? 0;
          final promoPrice = (variant['promo_price'] as num?)?.toDouble();
          final imageUrl = variant['image_url']?.toString() ?? '';
          variantProducts.add(
            _VendorVariantProduct(
              productId: row['id'].toString(),
              variantId: variant['id']?.toString() ?? '',
              name: row['title']?.toString() ?? 'Untitled',
              size: variant['size']?.toString() ?? 'Default',
              color: variant['color']?.toString() ?? 'Default',
              sku: variant['sku']?.toString() ?? '',
              price: promoPrice ?? (basePrice + priceAdjustment),
              stock: (variant['stock_quantity'] as num?)?.toInt() ?? 0,
              imageUrl: imageUrl.isEmpty
                  ? 'https://via.placeholder.com/600x600?text=No+Image'
                  : imageUrl,
            ),
          );
        }
      }
      variantProducts.sort((a, b) {
        if (a.isLowStock != b.isLowStock) return a.isLowStock ? -1 : 1;
        if (a.isLowStock && b.isLowStock) {
          final stockCompare = a.stock.compareTo(b.stock);
          if (stockCompare != 0) return stockCompare;
        }
        return a.name.compareTo(b.name);
      });

      final lowStockItems = variantProducts
          .where((item) => item.isLowStock)
          .map((item) => '${item.name} (${item.variantLabel})')
          .toList();
      VendorInventoryService.instance.lowStockCountNotifier.value =
          lowStockItems.length;
      await NotificationService.instance.notifyVendorLowStock(
        vendorId: user.id,
        lowStockCount: lowStockItems.length,
        itemNames: lowStockItems,
      );

      if (!mounted) return;
      setState(() {
        _variantProducts
          ..clear()
          ..addAll(variantProducts);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load products.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addProduct() async {
    final result = await Navigator.push<CreatedProductResult>(
      context,
      MaterialPageRoute(builder: (_) => const CreateProductScreen()),
    );
    if (result == null) return;
    await _loadVendorProducts();
  }

  @override
  Widget build(BuildContext context) {
    if (!_vendorAccessOk) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Product List',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                          fontFamily: AppFonts.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_variantProducts.length} variant item${_variantProducts.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.subtleText,
                          fontFamily: AppFonts.primary,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: _addProduct,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Create New Product',
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SearchBox(
                hintText: 'Search products...',
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(_error!, style: AppTextStyles.body),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: _loadVendorProducts,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : _filteredProducts.isEmpty
                            ? const Center(
                                child: Text(
                                  'No variant products found.',
                                  style: AppTextStyles.body,
                                ),
                              )
                            : ListView.separated(
                                itemCount: _filteredProducts.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final product = _filteredProducts[index];
                                  final isLowStock = product.isLowStock;
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: isLowStock
                                          ? const Color(0xFFFFF1F1)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: isLowStock
                                            ? AppColors.errorRed
                                                .withValues(alpha: 0.45)
                                            : Colors.transparent,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.04,
                                          ),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      onTap: () async {
                                        final changed =
                                            await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                VendorProductDetailScreen(
                                              productId: product.productId,
                                            ),
                                          ),
                                        );
                                        if (changed == true) {
                                          await _loadVendorProducts();
                                        }
                                      },
                                      contentPadding: const EdgeInsets.all(14),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.network(
                                          product.imageUrl,
                                          width: 70,
                                          height: 70,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            width: 70,
                                            height: 70,
                                            color: Colors.grey.shade300,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.image_not_supported,
                                            ),
                                          ),
                                        ),
                                      ),
                                      title: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: isLowStock
                                                  ? AppColors.errorRed
                                                  : AppColors.darkText,
                                              fontFamily: AppFonts.primary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            product.variantLabel,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.subtleText,
                                              fontFamily: AppFonts.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          '${formatKyat(product.price)} | ${product.stock} in stock',
                                          style: TextStyle(
                                            color: isLowStock
                                                ? AppColors.errorRed
                                                : AppColors.subtleText,
                                            fontFamily: AppFonts.primary,
                                            fontWeight: isLowStock
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.chevron_right,
                                        color: AppColors.darkText,
                                      ),
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VendorVariantProduct {
  final String productId;
  final String variantId;
  final String name;
  final String size;
  final String color;
  final String sku;
  final double price;
  final int stock;
  final String imageUrl;

  const _VendorVariantProduct({
    required this.productId,
    required this.variantId,
    required this.name,
    required this.size,
    required this.color,
    required this.sku,
    required this.price,
    required this.stock,
    required this.imageUrl,
  });

  bool get isLowStock => stock <= VendorInventoryService.lowStockThreshold;

  String get variantLabel {
    final parts = <String>[];
    if (color.trim().isNotEmpty && color.toLowerCase() != 'default') {
      parts.add(color);
    }
    if (size.trim().isNotEmpty && size.toLowerCase() != 'default') {
      parts.add('Size $size');
    }
    if (sku.trim().isNotEmpty) parts.add('SKU $sku');
    return parts.isEmpty ? 'Default variant' : parts.join(' | ');
  }
}

