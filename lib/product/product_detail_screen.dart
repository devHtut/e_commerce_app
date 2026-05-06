import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cart/cart_item.dart';
import '../cart/cart_service.dart';
import '../cart/checkout_screen.dart';
import '../vendor/shop_profile_screen.dart';
import '../theme_config.dart';
import '../widgets/custom_pop_up.dart';
import '../widgets/guest_auth_gate.dart';
import 'product_model.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  /// When true (e.g. vendor viewing their shop), hide Buy Now / Add to cart.
  final bool hideShoppingActions;

  const ProductDetailScreen({
    super.key,
    required this.product,
    this.hideShoppingActions = false,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _loading = true;
  String? _error;
  late ProductModel _product;
  final PageController _imageController = PageController();
  List<_VariantOption> _variants = [];
  Map<String, List<String>> _imagesByColor = {};
  String _selectedColor = 'Default';
  String _selectedSize = 'Default';
  int _selectedImage = 0;
  List<ProductModel> _youMayLike = [];
  List<ProductModel> _moreFromShop = [];

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _load();
  }

  @override
  void dispose() {
    _imageController.dispose();
    super.dispose();
  }

  bool get _hasRealVariants => _variants.any(
    (v) =>
        v.color.toLowerCase() != 'default' || v.size.toLowerCase() != 'default',
  );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await Supabase.instance.client
          .from('products')
          .select(
            'id, brand_id, category_id, title, description, base_price, '
            'categories(name), brands(brand_name,logo_url), '
            'product_variants(id,size,color,stock_quantity,price_adjustment,promo_price,image_url,sku)',
          )
          .eq('id', widget.product.id)
          .single();

      final product = ProductModel.fromSupabaseRow(row);
      final variantRows = (row['product_variants'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final variants = variantRows.map((v) {
        final adj = (v['price_adjustment'] as num?)?.toDouble() ?? 0;
        return _VariantOption(
          id: v['id']?.toString() ?? '',
          color: v['color']?.toString() ?? 'Default',
          size: v['size']?.toString() ?? 'Default',
          stock: (v['stock_quantity'] as num?)?.toInt() ?? 0,
          sku: v['sku']?.toString(),
          price: product.price + adj,
          promoPrice: (v['promo_price'] as num?)?.toDouble(),
          imageUrl: v['image_url']?.toString(),
        );
      }).toList();

      final colors = variants.map((v) => v.color).toSet().toList();
      if (colors.isEmpty) colors.add('Default');

      final byColor = <String, List<String>>{};
      for (final color in colors) {
        final folder = color.toLowerCase() == 'default' ? 'default' : color;
        final files = await Supabase.instance.client.storage
            .from('media')
            .list(path: 'product images/${product.id}/$folder');
        final urls = files
            .where((f) => f.name.isNotEmpty)
            .map(
              (f) => Supabase.instance.client.storage
                  .from('media')
                  .getPublicUrl(
                    'product images/${product.id}/$folder/${f.name}',
                  ),
            )
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

      if (byColor.isEmpty) {
        byColor['Default'] = product.galleryImages;
      }

      final selectedColor = byColor.keys.first;
      final sizes = variants
          .where((v) => v.color == selectedColor)
          .map((v) => v.size)
          .toSet()
          .toList();

      final related = await _loadRelatedProducts(row);

      if (!mounted) return;
      setState(() {
        _product = product;
        _variants = variants;
        _imagesByColor = byColor;
        _selectedColor = selectedColor;
        _selectedSize = sizes.isEmpty ? 'Default' : sizes.first;
        _selectedImage = 0;
        _youMayLike = related.$1;
        _moreFromShop = related.$2;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load product details.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<(List<ProductModel>, List<ProductModel>)> _loadRelatedProducts(
    Map<String, dynamic> row,
  ) async {
    final categoryId = row['category_id']?.toString();
    final brandId = row['brand_id']?.toString();
    final currentId = row['id'].toString();

    List<ProductModel> byCategory = [];
    List<ProductModel> byBrand = [];

    if (categoryId != null && categoryId.isNotEmpty) {
      final rows = await Supabase.instance.client
          .from('products')
          .select(
            'id, brand_id, category_id, title, description, base_price, '
            'categories(name), brands(brand_name,logo_url), product_variants(image_url)',
          )
          .eq('category_id', categoryId)
          .neq('id', currentId)
          .limit(10);
      byCategory = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ProductModel.fromSupabaseRow)
          .toList();
    }

    if (brandId != null && brandId.isNotEmpty) {
      final rows = await Supabase.instance.client
          .from('products')
          .select(
            'id, brand_id, category_id, title, description, base_price, '
            'categories(name), brands(brand_name,logo_url), product_variants(image_url)',
          )
          .eq('brand_id', brandId)
          .neq('id', currentId)
          .limit(10);
      byBrand = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ProductModel.fromSupabaseRow)
          .toList();
    }

    return (byCategory, byBrand);
  }

  List<String> get _colors => _imagesByColor.keys.toList();
  List<String> get _images => _imagesByColor[_selectedColor] ?? const [];
  List<String> get _sizes => _variants
      .where((v) => v.color == _selectedColor)
      .map((v) => v.size)
      .toSet()
      .toList();

  _VariantOption? get _selectedVariant {
    try {
      return _variants.firstWhere(
        (v) => v.color == _selectedColor && v.size == _selectedSize,
      );
    } catch (_) {
      return _variants.isEmpty ? null : _variants.first;
    }
  }

  Future<CartItem?> _addToCart({
    required bool buyNow,
    required _VariantOption variant,
    required int quantity,
  }) async {
    final variantImages = _imagesByColor[variant.color] ?? _images;
    final imageUrl = variantImages.isEmpty
        ? _product.imageUrl
        : variantImages.first;
    final price = variant.promoPrice ?? variant.price;
    final cartProduct = ProductModel(
      id: _product.id,
      name: _product.name,
      category: _product.category,
      categoryId: _product.categoryId,
      brand: _product.brand,
      brandId: _product.brandId,
      brandLogoUrl: _product.brandLogoUrl,
      description: _product.description,
      price: price,
      // rating: _product.rating,
      imageUrl: imageUrl,
      imageUrls: _images,
    );

    final item = CartItem(
      id: buyNow
          ? 'buy_now_${_product.id}_${DateTime.now().microsecondsSinceEpoch}'
          : '${_product.id}_${variant.id}_${variant.size}_${variant.color}',
      variantId: variant.id,
      product: cartProduct,
      size: variant.size,
      colorName: variant.color,
      colorValue: _colorFromName(variant.color).toARGB32(),
      imageUrl: imageUrl,
      quantity: quantity,
      createdAt: DateTime.now().toUtc(),
    );
    if (buyNow) {
      return item;
    }

    // Check if cart has items from a different brand
    final currentCartItems = CartService.instance.itemsNotifier.value;
    if (currentCartItems.isNotEmpty) {
      final cartBrandId = currentCartItems.first.product.brandId;
      if (cartBrandId != null &&
          cartProduct.brandId != null &&
          cartBrandId != cartProduct.brandId) {
        if (!mounted) return null;
        await showCustomPopup(
          context,
          title: 'Cannot add to cart',
          message:
              'You can\'t add to cart because of different brand. Please checkout first for the first item.',
          type: PopupType.error,
        );
        return null;
      }
    }

    await CartService.instance.addItem(
      product: cartProduct,
      variantId: variant.id,
      size: variant.size,
      colorName: variant.color,
      colorValue: _colorFromName(variant.color).toARGB32(),
      imageUrl: imageUrl,
      quantity: quantity,
    );
    if (!mounted) return null;
    await showCustomPopup(
      context,
      title: 'Added to cart',
      message: '${_product.name} was added to your cart.',
      type: PopupType.success,
    );
    return item;
  }

  Future<void> _showConfirmStage({required bool buyNow}) async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await GuestAuthGatePanel.show(context);
      return;
    }
    if (_variants.isEmpty) return;
    int selectedSizeIndex = _sizes.indexOf(_selectedSize);
    if (selectedSizeIndex == -1) selectedSizeIndex = 0;
    int selectedColorIndex = _colors.indexOf(_selectedColor);
    if (selectedColorIndex == -1) selectedColorIndex = 0;
    int quantity = 1;

    final cartItem = await showModalBottomSheet<CartItem?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final color = _colors[selectedColorIndex];
            final sizesForColor = _variants
                .where((v) => v.color == color)
                .map((v) => v.size)
                .toSet()
                .toList();
            if (!sizesForColor.contains(_sizes[selectedSizeIndex])) {
              selectedSizeIndex = 0;
            }
            final size = sizesForColor[selectedSizeIndex];
            final selectedVariant = _variants.firstWhere(
              (v) => v.color == color && v.size == size,
            );
            quantity = quantity.clamp(1, selectedVariant.stock);
            final displayPrice =
                selectedVariant.promoPrice ?? selectedVariant.price;
            final previewImage = (_imagesByColor[color] ?? _images).isEmpty
                ? _product.imageUrl
                : (_imagesByColor[color] ?? _images).first;

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
                      'Confirm Product Variant',
                      style: TextStyle(
                        fontSize: 30,
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
                            previewImage,
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
                                _product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.darkText,
                                  fontFamily: AppFonts.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('Stock  :  ${selectedVariant.stock}'),
                              const SizedBox(height: 8),
                              Text(
                                '\$${displayPrice.toStringAsFixed(2)}',
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
                                          ? () =>
                                                setModalState(() => quantity--)
                                          : null,
                                      icon: const Icon(Icons.remove, size: 20),
                                    ),
                                    SizedBox(
                                      width: 26,
                                      child: Text(
                                        '$quantity',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed:
                                          quantity < selectedVariant.stock
                                          ? () =>
                                                setModalState(() => quantity++)
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
                    if (_hasRealVariants) ...[
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
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(sizesForColor.length, (index) {
                          final isSelected = selectedSizeIndex == index;
                          return InkWell(
                            onTap: () =>
                                setModalState(() => selectedSizeIndex = index),
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
                                sizesForColor[index],
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.darkText,
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
                          itemCount: _colors.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, index) {
                            final colorName = _colors[index];
                            final selected = selectedColorIndex == index;
                            return InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedColorIndex = index;
                                  selectedSizeIndex = 0;
                                });
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Column(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _colorFromName(colorName),
                                      shape: BoxShape.circle,
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
                                style: TextStyle(color: AppColors.primaryGreen),
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
                                final addedItem = await _addToCart(
                                  buyNow: buyNow,
                                  variant: selectedVariant,
                                  quantity: quantity,
                                );
                                if (!context.mounted) return;
                                Navigator.pop(context, addedItem);
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
                                style: TextStyle(color: Colors.white),
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

    if (buyNow && cartItem != null && mounted) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => CheckoutScreen(items: [cartItem])),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.lightGrey,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.lightGrey,
        body: Center(child: Text(_error!)),
      );
    }

    final variant = _selectedVariant;
    final price = (variant?.promoPrice ?? variant?.price) ?? _product.price;
    if (_selectedImage >= _images.length && _images.isNotEmpty) {
      _selectedImage = 0;
    }

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Product'),
        actions: const [
          Icon(Icons.share_outlined, color: AppColors.darkText),
          SizedBox(width: 12),
          Icon(Icons.more_vert, color: AppColors.darkText),
          SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          _images.isEmpty
                              ? Container(color: Colors.grey.shade300)
                              : PageView.builder(
                                  controller: _imageController,
                                  itemCount: _images.length,
                                  onPageChanged: (index) =>
                                      setState(() => _selectedImage = index),
                                  itemBuilder: (_, index) => Image.network(
                                    _images[index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                          if (_images.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_selectedImage + 1}/${_images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: AppFonts.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
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
                        itemBuilder: (_, index) {
                          final selected = index == _selectedImage;
                          return GestureDetector(
                            onTap: () {
                              _imageController.animateToPage(
                                index,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                              );
                            },
                            child: Container(
                              width: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primaryGreen
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _images[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    _product.name,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                      fontFamily: AppFonts.primary,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_product.brand, style: AppTextStyles.body),
                  const SizedBox(height: 8),
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 28,
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                      fontFamily: AppFonts.primary,
                    ),
                  ),
                  if (_hasRealVariants) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Size',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(_sizes.length, (index) {
                        final size = _sizes[index];
                        final isSelected = _selectedSize == size;
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index == _sizes.length - 1 ? 0 : 10,
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => setState(() => _selectedSize = size),
                            child: Container(
                              width: 42,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? AppColors.primaryGreen
                                    : Colors.white,
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryGreen
                                      : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                size,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.darkText,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Color',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 60,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _colors.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, index) {
                          final name = _colors[index];
                          final selected = _selectedColor == name;
                          return GestureDetector(
                            onTap: () {
                              final nextSizes = _variants
                                  .where((v) => v.color == name)
                                  .map((v) => v.size)
                                  .toSet()
                                  .toList();
                              setState(() {
                                _selectedColor = name;
                                _selectedSize = nextSizes.isEmpty
                                    ? 'Default'
                                    : nextSizes.first;
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
                                    color: _colorFromName(name),
                                    shape: BoxShape.circle,
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
                                const SizedBox(height: 4),
                                // Text(
                                //   name,
                                //   style: TextStyle(
                                //     fontSize: 10,
                                //     color: Colors.grey.shade600,
                                //   ),
                                // ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Stock: ${variant?.stock ?? 0}'
                    '${(variant?.sku ?? '').isNotEmpty ? ' | SKU: ${variant!.sku}' : ''}',
                    style: const TextStyle(
                      fontFamily: AppFonts.primary,
                      color: AppColors.subtleText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Product Information',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.darkText,
                      fontFamily: AppFonts.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _product.description.isEmpty
                        ? 'No description available.'
                        : _product.description,
                    style: AppTextStyles.body.copyWith(
                      color: Colors.grey.shade700,
                      height: 1.45,
                    ),
                  ),
                  if (!widget.hideShoppingActions) ...[
                    const SizedBox(height: 16),
                    _buildBrandSection(),
                    const SizedBox(height: 20),
                    _buildHorizontalSection('You may like', _youMayLike),
                    const SizedBox(height: 20),
                    _buildHorizontalSection(
                      'More from this shop',
                      _moreFromShop,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!widget.hideShoppingActions)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _showConfirmStage(buyNow: true),
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDDECE1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Buy Now',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                              fontFamily: AppFonts.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () => _showConfirmStage(buyNow: false),
                        child: Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Add to Cart',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFamily: AppFonts.primary,
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

  Widget _buildBrandSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ClipOval(
            child:
                _product.brandLogoUrl == null || _product.brandLogoUrl!.isEmpty
                ? Container(
                    width: 46,
                    height: 46,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Icon(Icons.storefront_outlined),
                  )
                : Image.network(
                    _product.brandLogoUrl!,
                    width: 46,
                    height: 46,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _product.brand,
              style: const TextStyle(
                fontFamily: AppFonts.primary,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: _product.brandId == null || _product.brandId!.isEmpty
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ShopProfileScreen(brandId: _product.brandId),
                      ),
                    );
                  },
            child: const Text('View shop'),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalSection(String title, List<ProductModel> products) {
    if (products.isEmpty) return const SizedBox.shrink();
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
          height: 215,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              final p = products[index];
              return InkWell(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(
                        product: p,
                        hideShoppingActions: widget.hideShoppingActions,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 140,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            p.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppFonts.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${p.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppFonts.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _VariantOption {
  final String id;
  final String color;
  final String size;
  final int stock;
  final String? sku;
  final double price;
  final double? promoPrice;
  final String? imageUrl;

  const _VariantOption({
    required this.id,
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
