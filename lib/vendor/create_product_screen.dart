import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_user_service.dart';
import '../auth/vendor_access.dart';
import '../theme_config.dart';
import '../widgets/custom_buttom.dart';
import '../widgets/custom_input.dart';
import '../widgets/custom_pop_up.dart';

class CreateProductScreen extends StatefulWidget {
  const CreateProductScreen({super.key});

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _simplePriceController = TextEditingController();
  final _simplePromoController = TextEditingController();
  final _simpleStockController = TextEditingController();

  bool _isSaving = false;
  bool _hasVariants = true;
  bool _isLoadingCategories = true;
  bool _vendorAccessOk = false;
  String? _selectedCategoryId;
  final List<_CategoryOption> _categories = [];

  static const _sizeOptions = ['XS', 'S', 'M', 'L', 'XL'];
  static const _colorOptions = [
    'Black',
    'White',
    'Blue',
    'Red',
    'Green',
    'Brown',
    'Grey',
    'Purple',
    'Orange',
    'Yellow',
  ];

  final List<_ColorGroupDraft> _variantGroups = [
    _ColorGroupDraft(
      color: _colorOptions.first,
      images: [],
      variants: [
        _VariantDraft(
          size: _sizeOptions[2],
          stockController: TextEditingController(),
          priceController: TextEditingController(),
          promoPriceController: TextEditingController(),
          skuController: TextEditingController(),
        ),
      ],
    ),
  ];

  final List<_PickedImage> _simpleImages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureVendorThenLoadCategories());
  }

  Future<void> _ensureVendorThenLoadCategories() async {
    final ok = await VendorAccess.ensureVendorOrRedirect(context);
    if (!mounted || !ok) return;
    setState(() => _vendorAccessOk = true);
    await _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _simplePriceController.dispose();
    _simplePromoController.dispose();
    _simpleStockController.dispose();

    for (final group in _variantGroups) {
      for (final variant in group.variants) {
        variant.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final rows = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .order('name');
      _categories
        ..clear()
        ..addAll(
          (rows as List<dynamic>)
              .cast<Map<String, dynamic>>()
              .map((e) => _CategoryOption(id: e['id'].toString(), name: e['name'].toString())),
        );
      if (_categories.isNotEmpty) {
        _selectedCategoryId = _categories.first.id;
      }
    } finally {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _pickImages({
    required List<_PickedImage> target,
    required int maxCount,
  }) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    for (final file in result.files) {
      if (target.length >= maxCount) break;
      if (file.bytes == null) continue;
      target.add(
        _PickedImage(
          name: file.name,
          bytes: file.bytes!,
          extension: (file.extension ?? '').toLowerCase(),
        ),
      );
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      await showCustomPopup(
        context,
        title: 'Category required',
        message: 'Please choose a category.',
        type: PopupType.error,
      );
      return;
    }

    if (_hasVariants) {
      for (final group in _variantGroups) {
        if (group.images.length > 3) {
          await showCustomPopup(
            context,
            title: 'Too many photos',
            message: 'Each variant color can have maximum 3 photos.',
            type: PopupType.error,
          );
          return;
        }
      }
    } else {
      if (_simpleImages.length > 6) {
        await showCustomPopup(
          context,
          title: 'Too many photos',
          message: 'A product without variants can have maximum 6 photos.',
          type: PopupType.error,
        );
        return;
      }
    }

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      await showCustomPopup(
        context,
        title: 'Sign in required',
        message: 'Please sign in again.',
        type: PopupType.error,
      );
      return;
    }

    final brand = await AuthUserService.getVendorBrand(currentUser.id);
    if (brand == null) {
      await showCustomPopup(
        context,
        title: 'Brand profile missing',
        message: 'Please complete vendor info first.',
        type: PopupType.error,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final productName = _nameController.text.trim();
      final description = _descriptionController.text.trim();

      final variants = _buildResolvedVariants();
      final prices = variants.map((v) => v.price).toList()..sort();
      final basePrice = prices.first;
      final totalStock = variants.fold<int>(0, (sum, v) => sum + v.stock);

      final productRow = await Supabase.instance.client
          .from('products')
          .insert({
            'brand_id': brand['id'],
            'category_id': _selectedCategoryId,
            'title': productName,
            'description': description,
            'base_price': basePrice,
          })
          .select('id')
          .single();
      final productId = productRow['id'].toString();

      final colorImages = await _uploadImagesByColor(productId);

      await Supabase.instance.client.from('product_variants').insert(
            variants.map((v) {
              final image = (colorImages[v.color] ?? const []).isEmpty
                  ? null
                  : colorImages[v.color]!.first;
              return {
                'product_id': productId,
                'size': v.size,
                'color': v.color,
                'stock_quantity': v.stock,
                'price_adjustment': v.price - basePrice,
                'promo_price': v.promoPrice,
                'sku': v.sku?.isEmpty == true ? null : v.sku,
                'image_url': image,
              };
            }).toList(),
          );

      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Product created',
        message: 'Saved successfully.',
        type: PopupType.success,
      );
      if (!mounted) return;
      Navigator.pop(
        context,
        CreatedProductResult(
          id: productId,
          name: productName,
          price: basePrice,
          totalStock: totalStock,
        ),
      );
    } on PostgrestException catch (e) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Unable to create product',
        message: e.message,
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<_ResolvedVariant> _buildResolvedVariants() {
    if (!_hasVariants) {
      return [
        _ResolvedVariant(
          color: 'Default',
          size: 'Default',
          stock: int.parse(_simpleStockController.text.trim()),
          price: double.parse(_simplePriceController.text.trim()),
          promoPrice: _simplePromoController.text.trim().isEmpty
              ? null
              : double.parse(_simplePromoController.text.trim()),
          sku: null,
        ),
      ];
    }

    final variants = <_ResolvedVariant>[];
    for (final group in _variantGroups) {
      for (final variant in group.variants) {
        variants.add(
          _ResolvedVariant(
            color: group.color,
            size: variant.size,
            stock: int.parse(variant.stockController.text.trim()),
            price: double.parse(variant.priceController.text.trim()),
            promoPrice: variant.promoPriceController.text.trim().isEmpty
                ? null
                : double.parse(variant.promoPriceController.text.trim()),
            sku: variant.skuController.text.trim(),
          ),
        );
      }
    }
    return variants;
  }

  Future<Map<String, List<String>>> _uploadImagesByColor(String productId) async {
    final result = <String, List<String>>{};
    if (_hasVariants) {
      for (final group in _variantGroups) {
        final urls = <String>[];
        for (var i = 0; i < group.images.length; i++) {
          final image = group.images[i];
          final path =
              'product images/$productId/${group.color}/${i}_${DateTime.now().millisecondsSinceEpoch}_${image.name}';
          await Supabase.instance.client.storage.from('media').uploadBinary(
                path,
                image.bytes,
                fileOptions: FileOptions(
                  upsert: true,
                  contentType: _contentType(image.extension),
                ),
              );
          urls.add(Supabase.instance.client.storage.from('media').getPublicUrl(path));
        }
        result[group.color] = urls;
      }
      return result;
    }

    final urls = <String>[];
    for (var i = 0; i < _simpleImages.length; i++) {
      final image = _simpleImages[i];
      final path =
          'product images/$productId/default/${i}_${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      await Supabase.instance.client.storage.from('media').uploadBinary(
            path,
            image.bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentType(image.extension),
            ),
          );
      urls.add(Supabase.instance.client.storage.from('media').getPublicUrl(path));
    }
    result['Default'] = urls;
    return result;
  }

  String? _contentType(String ext) => switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => null,
      };

  String? _validatePrice(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Invalid price.';
    final digitsOnly = raw.replaceAll('.', '');
    if (digitsOnly.length > 6) return 'Max 6 digits only.';
    final parsed = double.tryParse(raw);
    if (parsed == null || parsed <= 0) return 'Invalid price.';
    return null;
  }

  String? _validateStock(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Invalid stock.';
    if (raw.length > 4) return 'Max 4 digits only.';
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0) return 'Invalid stock.';
    return null;
  }

  String? _validatePromo(String? value, String priceText) {
    if (value == null || value.trim().isEmpty) return null;
    final raw = value.trim();
    final digitsOnly = raw.replaceAll('.', '');
    if (digitsOnly.length > 6) return 'Max 6 digits only.';
    final promo = double.tryParse(raw);
    final price = double.tryParse(priceText.trim());
    if (promo == null || promo <= 0) return 'Invalid promo.';
    if (price != null && promo >= price) return 'Promo must be lower than price.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_vendorAccessOk) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Create Product',
          style: TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomTextField(
                  controller: _nameController,
                  hintText: 'Product name',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Product name is required.'
                      : null,
                ),
                const SizedBox(height: 10),
                CustomTextField(
                  controller: _descriptionController,
                  hintText: 'Product description',
                  maxLength: 500,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Description is required.'
                      : null,
                ),
                const SizedBox(height: 10),
                if (_isLoadingCategories)
                  const LinearProgressIndicator()
                else
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Choose category',
                    ),
                    items: _categories
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.id,
                            child: Text(e.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _selectedCategoryId = value),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'Category is required.'
                        : null,
                  ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _hasVariants,
                  activeThumbColor: AppColors.primaryGreen,
                  title: const Text('Has variants (color + size)'),
                  onChanged: (value) => setState(() => _hasVariants = value),
                ),
                const SizedBox(height: 6),
                if (_hasVariants) _buildVariantsSection() else _buildSimpleSection(),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: _isSaving
                      ? const Center(child: CircularProgressIndicator())
                      : CustomButton(text: 'Create product', onPressed: _save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _ImagePickerGrid(
            title: 'Product photos (max 6)',
            helper: '${_simpleImages.length}/6 selected',
            images: _simpleImages,
            onAdd: () => _pickImages(target: _simpleImages, maxCount: 6),
            onRemove: (i) => setState(() => _simpleImages.removeAt(i)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _simplePriceController,
                  hintText: 'Price',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  validator: _validatePrice,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomTextField(
                  controller: _simplePromoController,
                  hintText: 'Promo (optional)',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  validator: (v) => _validatePromo(v, _simplePriceController.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CustomTextField(
            controller: _simpleStockController,
            hintText: 'Stock quantity',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            validator: _validateStock,
          ),
        ],
      ),
    );
  }

  Widget _buildVariantsSection() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _variantGroups.add(
                  _ColorGroupDraft(
                    color: _colorOptions.first,
                    images: [],
                    variants: [
                      _VariantDraft(
                        size: _sizeOptions.first,
                        stockController: TextEditingController(),
                        priceController: TextEditingController(),
                        promoPriceController: TextEditingController(),
                        skuController: TextEditingController(),
                      ),
                    ],
                  ),
                );
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add color group'),
          ),
        ),
        ...List.generate(_variantGroups.length, (groupIndex) {
          final group = _variantGroups[groupIndex];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: group.color,
                        decoration: const InputDecoration(
                          filled: true,
                          fillColor: AppColors.lightGrey,
                        ),
                        items: _colorOptions
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => group.color = value ?? group.color),
                      ),
                    ),
                    if (_variantGroups.length > 1)
                      IconButton(
                        onPressed: () => setState(() => _variantGroups.removeAt(groupIndex)),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _ImagePickerGrid(
                  title: 'Photos (max 3 for this color)',
                  helper: '${group.images.length}/3 selected',
                  images: group.images,
                  onAdd: () => _pickImages(target: group.images, maxCount: 3),
                  onRemove: (i) => setState(() => group.images.removeAt(i)),
                ),
                const SizedBox(height: 8),
                ...List.generate(group.variants.length, (variantIndex) {
                  final v = group.variants[variantIndex];
                  return Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: v.size,
                                decoration: const InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: _sizeOptions
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => v.size = value ?? v.size),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CustomTextField(
                                controller: v.stockController,
                                hintText: 'Stock',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                validator: _validateStock,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: v.priceController,
                                hintText: 'Price',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                  LengthLimitingTextInputFormatter(7),
                                ],
                                validator: _validatePrice,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CustomTextField(
                                controller: v.promoPriceController,
                                hintText: 'Promo (optional)',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                  LengthLimitingTextInputFormatter(7),
                                ],
                                validator: (val) => _validatePromo(val, v.priceController.text),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: v.skuController,
                          hintText: 'SKU (optional)',
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  group.variants.add(
                                    _VariantDraft(
                                      size: _sizeOptions.first,
                                      stockController: TextEditingController(),
                                      priceController: TextEditingController(),
                                      promoPriceController: TextEditingController(),
                                      skuController: TextEditingController(),
                                    ),
                                  );
                                });
                              },
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Add size'),
                            ),
                            if (group.variants.length > 1)
                              TextButton(
                                onPressed: () => setState(() {
                                  final removed = group.variants.removeAt(variantIndex);
                                  removed.dispose();
                                }),
                                child: const Text('Remove'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class CreatedProductResult {
  final String id;
  final String name;
  final double price;
  final int totalStock;

  const CreatedProductResult({
    required this.id,
    required this.name,
    required this.price,
    required this.totalStock,
  });
}

class _CategoryOption {
  final String id;
  final String name;

  const _CategoryOption({required this.id, required this.name});
}

class _ColorGroupDraft {
  String color;
  final List<_PickedImage> images;
  final List<_VariantDraft> variants;

  _ColorGroupDraft({
    required this.color,
    required this.images,
    required this.variants,
  });
}

class _VariantDraft {
  String size;
  final TextEditingController stockController;
  final TextEditingController priceController;
  final TextEditingController promoPriceController;
  final TextEditingController skuController;

  _VariantDraft({
    required this.size,
    required this.stockController,
    required this.priceController,
    required this.promoPriceController,
    required this.skuController,
  });

  void dispose() {
    stockController.dispose();
    priceController.dispose();
    promoPriceController.dispose();
    skuController.dispose();
  }
}

class _PickedImage {
  final String name;
  final Uint8List bytes;
  final String extension;

  const _PickedImage({
    required this.name,
    required this.bytes,
    required this.extension,
  });
}

class _ResolvedVariant {
  final String color;
  final String size;
  final int stock;
  final double price;
  final double? promoPrice;
  final String? sku;

  const _ResolvedVariant({
    required this.color,
    required this.size,
    required this.stock,
    required this.price,
    required this.promoPrice,
    required this.sku,
  });
}

class _ImagePickerGrid extends StatelessWidget {
  final String title;
  final String helper;
  final List<_PickedImage> images;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const _ImagePickerGrid({
    required this.title,
    required this.helper,
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...List.generate(images.length, (index) {
              final image = images[index];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      image.bytes,
                      width: 78,
                      height: 78,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: () => onRemove(index),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              );
            }),
            InkWell(
              onTap: onAdd,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          helper,
          style: const TextStyle(
            fontFamily: AppFonts.primary,
            color: AppColors.subtleText,
          ),
        ),
      ],
    );
  }
}

