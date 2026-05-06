import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/vendor_access.dart';
import '../theme_config.dart';
import '../widgets/custom_pop_up.dart';
import '../widgets/edit_product_screen.dart';

class VendorProductDetailScreen extends StatefulWidget {
  final String productId;

  const VendorProductDetailScreen({super.key, required this.productId});

  @override
  State<VendorProductDetailScreen> createState() =>
      _VendorProductDetailScreenState();
}

class _VendorProductDetailScreenState extends State<VendorProductDetailScreen> {
  bool _vendorAccessOk = false;
  bool _loading = true;
  String? _error;
  String _name = '';
  String _description = '';
  double _price = 0;
  List<_VariantView> _variants = [];
  Map<String, List<String>> _imagesByColor = {};
  String _selectedColor = 'Default';
  String _selectedSize = 'Default';
  int _selectedImage = 0;
  final PageController _imageController = PageController();

  bool get _hasRealVariants => _variants.any(
        (v) =>
            v.color.toLowerCase() != 'default' || v.size.toLowerCase() != 'default',
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVendorThenLoad());
  }

  Future<void> _ensureVendorThenLoad() async {
    final ok = await VendorAccess.ensureVendorOrRedirect(context);
    if (!mounted || !ok) return;
    setState(() => _vendorAccessOk = true);
    _load();
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  List<String> get _colors => _imagesByColor.keys.toList();
  List<String> get _sizes => _variants
      .where((v) => v.color == _selectedColor)
      .map((v) => v.size)
      .toSet()
      .toList();
  List<String> get _images => _imagesByColor[_selectedColor] ?? const [];

  _VariantView? get _currentVariant {
    try {
      return _variants.firstWhere(
        (v) => v.color == _selectedColor && v.size == _selectedSize,
      );
    } catch (_) {
      return _variants.isEmpty ? null : _variants.first;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await Supabase.instance.client
          .from('products')
          .select(
            'id,title,description,base_price,product_variants('
            'size,color,stock_quantity,promo_price,price_adjustment,sku,image_url'
            ')',
          )
          .eq('id', widget.productId)
          .single();

      final basePrice = (row['base_price'] as num?)?.toDouble() ?? 0;
      final variants = (row['product_variants'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>()
          .map((v) => _VariantView(
                color: v['color']?.toString() ?? 'Default',
                size: v['size']?.toString() ?? 'Default',
                stock: (v['stock_quantity'] as num?)?.toInt() ?? 0,
                sku: v['sku']?.toString(),
                price:
                    basePrice + ((v['price_adjustment'] as num?)?.toDouble() ?? 0),
                promoPrice: (v['promo_price'] as num?)?.toDouble(),
                imageUrl: v['image_url']?.toString(),
              ))
          .toList();

      final byColor = <String, List<String>>{};
      final colors = variants.map((v) => v.color).toSet().toList();
      if (colors.isEmpty) colors.add('Default');
      for (final color in colors) {
        final folder = color.toLowerCase() == 'default' ? 'default' : color;
        final files = await Supabase.instance.client.storage
            .from('media')
            .list(path: 'product images/${widget.productId}/$folder');
        final urls = files
            .where((f) => f.name.isNotEmpty)
            .map((f) => Supabase.instance.client.storage
                .from('media')
                .getPublicUrl('product images/${widget.productId}/$folder/${f.name}'))
            .toList();
        if (urls.isNotEmpty) {
          byColor[color] = urls;
        } else {
          final fallback = variants
              .where((v) => v.color == color)
              .map((v) => v.imageUrl ?? '')
              .where((u) => u.isNotEmpty)
              .toSet()
              .toList();
          if (fallback.isNotEmpty) byColor[color] = fallback;
        }
      }

      if (!mounted) return;
      final firstColor = byColor.keys.isEmpty ? 'Default' : byColor.keys.first;
      final firstSizes =
          variants.where((v) => v.color == firstColor).map((v) => v.size).toSet().toList();
      setState(() {
        _name = row['title']?.toString() ?? '';
        _description = row['description']?.toString() ?? '';
        _price = basePrice;
        _variants = variants;
        _imagesByColor = byColor;
        _selectedColor = firstColor;
        _selectedSize = firstSizes.isEmpty ? 'Default' : firstSizes.first;
        _selectedImage = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load product.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete product?'),
        content: const Text(
          'This will remove product, variants and all associated images.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await _deleteProduct();
  }

  Future<void> _deleteProduct() async {
    try {
      final root = await Supabase.instance.client.storage
          .from('media')
          .list(path: 'product images/${widget.productId}');
      for (final folder in root) {
        final files = await Supabase.instance.client.storage
            .from('media')
            .list(path: 'product images/${widget.productId}/${folder.name}');
        final paths = files
            .where((f) => f.name.isNotEmpty)
            .map(
              (f) => 'product images/${widget.productId}/${folder.name}/${f.name}',
            )
            .toList();
        if (paths.isNotEmpty) {
          await Supabase.instance.client.storage.from('media').remove(paths);
        }
      }
      await Supabase.instance.client
          .from('product_variants')
          .delete()
          .eq('product_id', widget.productId);
      await Supabase.instance.client
          .from('products')
          .delete()
          .eq('id', widget.productId);
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Deleted',
        message: 'Product deleted successfully.',
        type: PopupType.success,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Delete failed',
        message: 'Please try again.',
        type: PopupType.error,
      );
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProductScreen(productId: widget.productId),
      ),
    );
    if (changed == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_vendorAccessOk) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }

    final current = _currentVariant;
    final price = (current?.promoPrice ?? current?.price) ?? _price;
    if (_selectedImage >= _images.length && _images.isNotEmpty) _selectedImage = 0;

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: const Text('Product'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: _images.isEmpty
                          ? Container(color: Colors.grey.shade300)
                          : PageView.builder(
                              controller: _imageController,
                              itemCount: _images.length,
                              onPageChanged: (i) =>
                                  setState(() => _selectedImage = i),
                              itemBuilder: (_, i) => Image.network(
                                _images[i],
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                  ),
                  if (_images.length > 1) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 76,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => _imageController.animateToPage(
                            i,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              _images[i],
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    _name,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_hasRealVariants) ...[
                    const SizedBox(height: 20),
                    const Text('Size', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(_sizes.length, (index) {
                        final size = _sizes[index];
                        final selected = _selectedSize == size;
                        return Padding(
                          padding: EdgeInsets.only(right: index == _sizes.length - 1 ? 0 : 10),
                          child: InkWell(
                            onTap: () => setState(() => _selectedSize = size),
                            child: Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected ? AppColors.primaryGreen : Colors.white,
                              ),
                              child: Text(
                                size,
                                style: TextStyle(
                                  color: selected ? Colors.white : AppColors.darkText,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),
                    const Text('Color', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 60,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _colors.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final c = _colors[i];
                          final selected = _selectedColor == c;
                          return GestureDetector(
                            onTap: () {
                              final sizes = _variants
                                  .where((v) => v.color == c)
                                  .map((v) => v.size)
                                  .toSet()
                                  .toList();
                              setState(() {
                                _selectedColor = c;
                                _selectedSize = sizes.isEmpty ? 'Default' : sizes.first;
                                _selectedImage = 0;
                              });
                              _imageController.jumpToPage(0);
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _colorFromName(c),
                                    border: Border.all(
                                      color: selected
                                          ? AppColors.darkText
                                          : Colors.grey.shade300,
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  child: selected
                                      ? const Icon(
                                          Icons.check,
                                          size: 18,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Stock: ${current?.stock ?? 0}${(current?.sku ?? '').isNotEmpty ? ' | SKU: ${current!.sku}' : ''}',
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Product Information',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(_description),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _confirmDelete,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE2E2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _edit,
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantView {
  final String color;
  final String size;
  final int stock;
  final String? sku;
  final double price;
  final double? promoPrice;
  final String? imageUrl;

  const _VariantView({
    required this.color,
    required this.size,
    required this.stock,
    required this.sku,
    required this.price,
    required this.promoPrice,
    required this.imageUrl,
  });
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

