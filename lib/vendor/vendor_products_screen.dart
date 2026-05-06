import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/vendor_access.dart';
import '../theme_config.dart';
import '../widgets/search_box.dart';
import 'create_product_screen.dart';
import 'vendor_product_detail_screen.dart';

class VendorProductsScreen extends StatefulWidget {
  const VendorProductsScreen({super.key});

  @override
  State<VendorProductsScreen> createState() => _VendorProductsScreenState();
}

class _VendorProductsScreenState extends State<VendorProductsScreen> {
  final List<_VendorProduct> _products = [];
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

  List<_VendorProduct> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _products;
    return _products
        .where(
          (p) =>
              p.name.toLowerCase().contains(query) ||
              p.price.toStringAsFixed(0).contains(query),
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
            'id, title, base_price, '
            'product_variants(stock_quantity,image_url)',
          )
          .eq('brand_id', brand['id'])
          .order('created_at', ascending: false);

      final products = (productRows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) {
            final variants =
                (row['product_variants'] as List<dynamic>? ?? const <dynamic>[])
                    .cast<Map<String, dynamic>>();
            final stock = variants.fold<int>(
              0,
              (sum, v) => sum + ((v['stock_quantity'] as num?)?.toInt() ?? 0),
            );
            final image = variants
                .map((v) => v['image_url']?.toString() ?? '')
                .firstWhere(
                  (url) => url.isNotEmpty,
                  orElse: () => 'https://via.placeholder.com/600x600?text=No+Image',
                );
            return _VendorProduct(
              id: row['id'].toString(),
              name: row['title']?.toString() ?? 'Untitled',
              price: (row['base_price'] as num?)?.toDouble() ?? 0,
              stock: stock,
              imageUrl: image,
            );
          })
          .toList();

      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(products);
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
                  IconButton(
                    onPressed: _addProduct,
                    icon: const Icon(Icons.add, color: AppColors.primaryGreen),
                    tooltip: 'Add product',
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
                                  'No products found.',
                                  style: AppTextStyles.body,
                                ),
                              )
                            : ListView.separated(
                                itemCount: _filteredProducts.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final product = _filteredProducts[index];
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      onTap: () async {
                                        final changed = await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => VendorProductDetailScreen(
                                              productId: product.id,
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
                                          errorBuilder: (_, __, ___) => Container(
                                            width: 70,
                                            height: 70,
                                            color: Colors.grey.shade300,
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.image_not_supported),
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        product.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.darkText,
                                          fontFamily: AppFonts.primary,
                                        ),
                                      ),
                                      subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          '\$${product.price.toStringAsFixed(0)} • ${product.stock} in stocks',
                                          style: const TextStyle(
                                            color: AppColors.subtleText,
                                            fontFamily: AppFonts.primary,
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

class _VendorProduct {
  final String id;
  final String name;
  final double price;
  final int stock;
  final String imageUrl;

  const _VendorProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    required this.imageUrl,
  });
}

