import 'package:flutter/material.dart';

import '../cart/cart_service.dart';
import 'product_model.dart';
import '../theme_config.dart';
import '../widgets/custom_pop_up.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final PageController _imagePageController;
  int _currentImageIndex = 0;
  int _selectedSizeIndex = 3;
  int _selectedColorIndex = 0;

  late final List<_ColorVariant> _colorVariants = [
    _ColorVariant(
      name: 'Black',
      color: const Color(0xFF1C1C1C),
      imageUrl: widget.product.imageUrl,
    ),
    const _ColorVariant(
      name: 'White',
      color: Color(0xFFF5F5F5),
      imageUrl:
          'https://images.unsplash.com/photo-1564257577-2d5cb2c4b4f5?auto=format&fit=crop&w=900&q=80',
    ),
    const _ColorVariant(
      name: 'Brown',
      color: Color(0xFF8B5E4A),
      imageUrl:
          'https://images.unsplash.com/photo-1485230895905-ec40ba36b9bc?auto=format&fit=crop&w=900&q=80',
    ),
    const _ColorVariant(
      name: 'Blue Grey',
      color: Color(0xFF7797A7),
      imageUrl:
          'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?auto=format&fit=crop&w=900&q=80',
    ),
    const _ColorVariant(
      name: 'Indigo',
      color: Color(0xFF3D59C9),
      imageUrl:
          'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=900&q=80',
    ),
    const _ColorVariant(
      name: 'Deep Purple',
      color: Color(0xFF6F3FD1),
      imageUrl:
          'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?auto=format&fit=crop&w=900&q=80',
    ),
  ];

  final List<String> _sizes = const ['XS', 'S', 'M', 'L', 'XL'];

  late final List<_RecommendedProduct> _recommendedProducts = [
    const _RecommendedProduct(
      title: 'Moda Chic Luxury Top',
      price: 200,
      imageUrl:
          'https://images.unsplash.com/photo-1618244972963-dbad68f14f5d?auto=format&fit=crop&w=800&q=80',
    ),
    const _RecommendedProduct(
      title: 'Trend Craft Fleece Hoodie',
      price: 210,
      imageUrl:
          'https://images.unsplash.com/photo-1618354691373-d851c5c3a990?auto=format&fit=crop&w=800&q=80',
    ),
    const _RecommendedProduct(
      title: 'Street Style Crewneck',
      price: 190,
      imageUrl:
          'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=800&q=80',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController(viewportFraction: 1);
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  void _onColorSelected(int index) {
    setState(() {
      _selectedColorIndex = index;
      _currentImageIndex = index;
    });
    _imagePageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
  }

  void _showVariantBottomSheet({required bool isBuyNow}) {
    int sheetSelectedSize = _selectedSizeIndex;
    int sheetSelectedColor = _selectedColorIndex;
    int quantity = 1;
    const int stock = 256;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedVariant = _colorVariants[sheetSelectedColor];
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
                      'Choose Product Variant',
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
                            selectedVariant.imageUrl,
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
                                widget.product.name,
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
                                '\$${widget.product.price.toStringAsFixed(2)}',
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
                      children: List.generate(_sizes.length, (index) {
                        final isSelected = sheetSelectedSize == index;
                        return Padding(
                          padding: EdgeInsets.only(right: index == _sizes.length - 1 ? 0 : 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              setModalState(() {
                                sheetSelectedSize = index;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 52,
                              height: 52,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? AppColors.primaryGreen : Colors.white,
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                _sizes[index],
                                style: TextStyle(
                                  fontFamily: AppFonts.primary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? Colors.white : AppColors.darkText,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 14),
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
                      height: 64,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _colorVariants.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = _colorVariants[index];
                          final isSelected = index == sheetSelectedColor;
                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                sheetSelectedColor = index;
                              });
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: item.color,
                                    border: Border.all(
                                      color: isSelected ? AppColors.darkText : Colors.grey.shade300,
                                      width: isSelected ? 1.8 : 1,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check,
                                          size: 18,
                                          color: index == 1 ? AppColors.darkText : Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontFamily: AppFonts.primary,
                                    fontSize: 10,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(color: Colors.grey.shade200, height: 1),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              setState(() {
                                _selectedSizeIndex = sheetSelectedSize;
                                _selectedColorIndex = sheetSelectedColor;
                                _currentImageIndex = sheetSelectedColor;
                              });
                              _imagePageController.animateToPage(
                                sheetSelectedColor,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                              Navigator.pop(context);
                            },
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3ECE6),
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
                        const SizedBox(width: 14),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () async {
                              setState(() {
                                _selectedSizeIndex = sheetSelectedSize;
                                _selectedColorIndex = sheetSelectedColor;
                                _currentImageIndex = sheetSelectedColor;
                              });
                              _imagePageController.animateToPage(
                                sheetSelectedColor,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                              Navigator.pop(context);
                              if (isBuyNow) {
                                await showCustomPopup(
                                  context,
                                  title: 'Checkout',
                                  message:
                                      'Buy Now flow is ready for checkout integration.',
                                  type: PopupType.success,
                                );
                                return;
                              }

                              final selectedVariant =
                                  _colorVariants[sheetSelectedColor];
                              CartService.instance.addItem(
                                product: widget.product,
                                size: _sizes[sheetSelectedSize],
                                colorName: selectedVariant.name,
                                colorValue: selectedVariant.color.toARGB32(),
                                imageUrl: selectedVariant.imageUrl,
                                quantity: quantity,
                              );
                              await showCustomPopup(
                                context,
                                title: 'Added to cart',
                                message:
                                    '${widget.product.name} was added to your cart.',
                                type: PopupType.success,
                              );
                            },
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                isBuyNow ? 'Buy Now' : 'Add to Cart',
                                style: const TextStyle(
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
                    SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Product',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            color: AppColors.darkText,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: const [
          Icon(Icons.share_outlined, color: AppColors.darkText),
          SizedBox(width: 14),
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
                          PageView.builder(
                            controller: _imagePageController,
                            itemCount: _colorVariants.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentImageIndex = index;
                                _selectedColorIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return Image.network(
                                _colorVariants[index].imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  color: Colors.grey.shade300,
                                  alignment: Alignment.center,
                                  child:
                                      const Icon(Icons.image_not_supported, size: 40),
                                ),
                              );
                            },
                          ),
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
                              '${_currentImageIndex + 1}/${_colorVariants.length}',
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
                  const SizedBox(height: 16),
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.darkText,
                      fontFamily: AppFonts.primary,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        '\$${widget.product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppFonts.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildInfoPill(
                        '${(widget.product.rating * 570).round()} sold',
                        const Color(0xFFF1F1F1),
                      ),
                      const SizedBox(width: 8),
                      _buildInfoPill(
                        widget.product.rating.toStringAsFixed(1),
                        const Color(0xFFFFF4DD),
                        icon: Icons.star,
                        iconColor: Colors.orange,
                      ),
                    ],
                  ),
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
                      final isSelected = _selectedSizeIndex == index;
                      return Padding(
                        padding: EdgeInsets.only(right: index == _sizes.length - 1 ? 0 : 10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () {
                            setState(() {
                              _selectedSizeIndex = index;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? AppColors.primaryGreen : Colors.white,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryGreen
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              _sizes[index],
                              style: TextStyle(
                                fontFamily: AppFonts.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.darkText,
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
                      itemCount: _colorVariants.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = _colorVariants[index];
                        final isSelected = index == _selectedColorIndex;
                        return GestureDetector(
                          onTap: () => _onColorSelected(index),
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: item.color,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.darkText
                                        : Colors.transparent,
                                    width: 2,
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
                              const SizedBox(height: 4),
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontFamily: AppFonts.primary,
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
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
                    'Elevate your style with this premium piece from ${widget.product.brand}. '
                    'Designed for modern comfort with a clean silhouette and refined finishing.',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.grey.shade700,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'You May Also Like',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                          fontFamily: AppFonts.primary,
                        ),
                      ),
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.darkText,
                          fontFamily: AppFonts.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 180,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _recommendedProducts.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final item = _recommendedProducts[index];
                        return Container(
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
                                    item.imageUrl,
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
                                item.title,
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
                                '\$${item.price.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w700,
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
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(Icons.favorite_border, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => _showVariantBottomSheet(isBuyNow: true),
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
                      onTap: () => _showVariantBottomSheet(isBuyNow: false),
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

  Widget _buildInfoPill(
    String text,
    Color backgroundColor, {
    IconData? icon,
    Color iconColor = AppColors.darkText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: iconColor),
            const SizedBox(width: 3),
          ],
          Text(
            text,
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
}

class _ColorVariant {
  final String name;
  final Color color;
  final String imageUrl;

  const _ColorVariant({
    required this.name,
    required this.color,
    required this.imageUrl,
  });
}

class _RecommendedProduct {
  final String title;
  final double price;
  final String imageUrl;

  const _RecommendedProduct({
    required this.title,
    required this.price,
    required this.imageUrl,
  });
}
