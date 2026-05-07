import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/vendor_access.dart';
import '../theme_config.dart';
import 'custom_buttom.dart';
import 'custom_input.dart';
import 'custom_pop_up.dart';

class EditProductScreen extends StatefulWidget {
  final String productId;

  const EditProductScreen({super.key, required this.productId});

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  bool _vendorAccessOk = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _simplePriceController = TextEditingController();
  final _simplePromoController = TextEditingController();
  final _simpleStockController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;
  bool _hasVariants = true;
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

  final List<_ColorGroupDraft> _variantGroups = [];
  final List<_EditableImage> _simpleImages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _ensureVendorThenLoad(),
    );
  }

  Future<void> _ensureVendorThenLoad() async {
    final ok = await VendorAccess.ensureVendorOrRedirect(context);
    if (!mounted || !ok) return;
    setState(() => _vendorAccessOk = true);
    _load();
  }

  Future<bool> _confirmDiscardChanges() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Discard changes?',
            style: TextStyle(
              color: AppColors.darkText,
              fontFamily: AppFonts.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Your product changes are not saved yet. Are you sure you want to leave this screen?',
            style: TextStyle(
              color: AppColors.subtleText,
              fontFamily: AppFonts.primary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep Editing'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCF5F5F),
              ),
              child: const Text(
                'Discard',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
    return discard == true;
  }

  Future<void> _requestLeave() async {
    if (_saving) return;
    if (await _confirmDiscardChanges()) {
      _popAfterAllow();
    }
  }

  void _popAfterAllow([Object? result]) {
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pop(context, result);
    });
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

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final categoryRows = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .order('name');
      _categories
        ..clear()
        ..addAll(
          (categoryRows as List<dynamic>).cast<Map<String, dynamic>>().map(
            (e) => _CategoryOption(
              id: e['id'].toString(),
              name: e['name'].toString(),
            ),
          ),
        );

      final row = await Supabase.instance.client
          .from('products')
          .select(
            'id, title, description, category_id, base_price, product_variants('
            'size,color,stock_quantity,promo_price,price_adjustment,sku,image_url'
            ')',
          )
          .eq('id', widget.productId)
          .single();

      _nameController.text = row['title']?.toString() ?? '';
      _descriptionController.text = row['description']?.toString() ?? '';
      _selectedCategoryId = row['category_id']?.toString();
      final basePrice = (row['base_price'] as num?)?.toDouble() ?? 0;

      final variants =
          (row['product_variants'] as List<dynamic>? ?? const <dynamic>[])
              .cast<Map<String, dynamic>>();
      final realVariants = variants.where((v) {
        final c = (v['color']?.toString() ?? 'default').toLowerCase();
        final s = (v['size']?.toString() ?? 'default').toLowerCase();
        return c != 'default' || s != 'default';
      }).toList();

      _variantGroups.clear();
      _simpleImages.clear();

      if (realVariants.isEmpty) {
        _hasVariants = false;
        final first = variants.isEmpty ? null : variants.first;
        final price =
            basePrice +
            (((first?['price_adjustment'] as num?)?.toDouble() ?? 0));
        _simplePriceController.text = price.toStringAsFixed(0);
        _simplePromoController.text =
            ((first?['promo_price'] as num?)?.toString() ?? '');
        _simpleStockController.text =
            ((first?['stock_quantity'] as num?)?.toInt().toString() ?? '0');

        final simpleStorage = await _listStorageImages('default');
        _simpleImages.addAll(
          simpleStorage.map((u) => _EditableImage.fromUrl(u)),
        );
      } else {
        _hasVariants = true;
        final colorMap = <String, List<Map<String, dynamic>>>{};
        for (final v in realVariants) {
          final color = v['color']?.toString() ?? 'Black';
          colorMap.putIfAbsent(color, () => []).add(v);
        }
        for (final entry in colorMap.entries) {
          final group = _ColorGroupDraft(
            color: entry.key,
            images: [],
            variants: [],
          );
          final storageImages = await _listStorageImages(entry.key);
          group.images.addAll(
            storageImages.map((u) => _EditableImage.fromUrl(u)),
          );
          for (final v in entry.value) {
            final price =
                basePrice +
                (((v['price_adjustment'] as num?)?.toDouble() ?? 0));
            group.variants.add(
              _VariantDraft(
                size: v['size']?.toString() ?? _sizeOptions.first,
                stockController: TextEditingController(
                  text: ((v['stock_quantity'] as num?)?.toInt() ?? 0)
                      .toString(),
                ),
                priceController: TextEditingController(
                  text: price.toStringAsFixed(0),
                ),
                promoPriceController: TextEditingController(
                  text: ((v['promo_price'] as num?)?.toString() ?? ''),
                ),
                skuController: TextEditingController(
                  text: (v['sku']?.toString() ?? ''),
                ),
              ),
            );
          }
          _variantGroups.add(group);
        }
      }
    } catch (_) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Unable to load product',
        message: 'Please try again.',
        type: PopupType.error,
      );
      if (!mounted) return;
      _popAfterAllow();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<String>> _listStorageImages(String folder) async {
    try {
      final files = await Supabase.instance.client.storage
          .from('media')
          .list(path: 'product images/${widget.productId}/$folder');
      return files
          .where((f) => f.name.isNotEmpty)
          .map(
            (f) => Supabase.instance.client.storage
                .from('media')
                .getPublicUrl(
                  'product images/${widget.productId}/$folder/${f.name}',
                ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _pickImages(List<_EditableImage> target, int maxCount) async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    for (final f in result.files) {
      if (target.length >= maxCount) break;
      if (f.bytes == null) continue;
      target.add(
        _EditableImage.fromBytes(
          name: f.name,
          bytes: f.bytes!,
          extension: (f.extension ?? '').toLowerCase(),
        ),
      );
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final variants = _buildResolvedVariants();
      final prices = variants.map((v) => v.price).toList()..sort();
      final basePrice = prices.first;

      await Supabase.instance.client
          .from('products')
          .update({
            'title': _nameController.text.trim(),
            'description': _descriptionController.text.trim(),
            'category_id': _selectedCategoryId,
            'base_price': basePrice,
          })
          .eq('id', widget.productId);

      await _deleteAllStorageImages();
      await Supabase.instance.client
          .from('product_variants')
          .delete()
          .eq('product_id', widget.productId);

      final colorToUrls = await _uploadCurrentImages();

      await Supabase.instance.client
          .from('product_variants')
          .insert(
            variants.map((v) {
              final image = (colorToUrls[v.color] ?? const []).isEmpty
                  ? null
                  : colorToUrls[v.color]!.first;
              return {
                'product_id': widget.productId,
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
        title: 'Saved',
        message: 'Product updated successfully.',
        type: PopupType.success,
      );
      if (!mounted) return;
      _popAfterAllow(true);
    } on PostgrestException catch (e) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Unable to save',
        message: e.message,
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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

  Future<void> _deleteAllStorageImages() async {
    final root = await Supabase.instance.client.storage
        .from('media')
        .list(path: 'product images/${widget.productId}');
    for (final entry in root) {
      if (entry.id == null) continue;
      final folder = entry.name;
      final files = await Supabase.instance.client.storage
          .from('media')
          .list(path: 'product images/${widget.productId}/$folder');
      final paths = files
          .where((f) => f.name.isNotEmpty)
          .map((f) => 'product images/${widget.productId}/$folder/${f.name}')
          .toList();
      if (paths.isNotEmpty) {
        await Supabase.instance.client.storage.from('media').remove(paths);
      }
    }
  }

  Future<Map<String, List<String>>> _uploadCurrentImages() async {
    final map = <String, List<String>>{};
    if (_hasVariants) {
      for (final group in _variantGroups) {
        final urls = <String>[];
        for (var i = 0; i < group.images.length; i++) {
          final image = group.images[i];
          if (image.url != null) {
            urls.add(image.url!);
            continue;
          }
          final path =
              'product images/${widget.productId}/${group.color}/${i}_${DateTime.now().millisecondsSinceEpoch}_${image.name}';
          await Supabase.instance.client.storage
              .from('media')
              .uploadBinary(
                path,
                image.bytes!,
                fileOptions: FileOptions(
                  upsert: true,
                  contentType: _contentType(image.extension ?? ''),
                ),
              );
          urls.add(
            Supabase.instance.client.storage.from('media').getPublicUrl(path),
          );
        }
        map[group.color] = urls;
      }
      return map;
    }

    final urls = <String>[];
    for (var i = 0; i < _simpleImages.length; i++) {
      final image = _simpleImages[i];
      if (image.url != null) {
        urls.add(image.url!);
        continue;
      }
      final path =
          'product images/${widget.productId}/default/${i}_${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      await Supabase.instance.client.storage
          .from('media')
          .uploadBinary(
            path,
            image.bytes!,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentType(image.extension ?? ''),
            ),
          );
      urls.add(
        Supabase.instance.client.storage.from('media').getPublicUrl(path),
      );
    }
    map['Default'] = urls;
    return map;
  }

  String? _contentType(String ext) => switch (ext.toLowerCase()) {
    'png' => 'image/png',
    'jpg' || 'jpeg' => 'image/jpeg',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    _ => null,
  };

  String? _validatePrice(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Invalid price.';
    if (raw.replaceAll('.', '').length > 6) return 'Max 6 digits only.';
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
    if (raw.replaceAll('.', '').length > 6) return 'Max 6 digits only.';
    final promo = double.tryParse(raw);
    final price = double.tryParse(priceText.trim());
    if (promo == null || promo <= 0) return 'Invalid promo.';
    if (price != null && promo >= price)
      return 'Promo must be lower than price.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_vendorAccessOk) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestLeave();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightGrey,
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          leading: IconButton(
            onPressed: _requestLeave,
            icon: const Icon(Icons.arrow_back, color: AppColors.darkText),
          ),
          title: const Text('Edit Product'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  CustomTextField(
                    controller: _nameController,
                    labelText: 'Product name',
                    hintText: 'Product name',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  CustomTextField(
                    controller: _descriptionController,
                    labelText: 'Product description',
                    hintText: 'Product description',
                    maxLength: 500,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      labelStyle: TextStyle(
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _hasVariants,
                    title: const Text('Has variants'),
                    onChanged: (v) => setState(() => _hasVariants = v),
                  ),
                  const SizedBox(height: 8),
                  _hasVariants ? _buildVariantEditor() : _buildSimpleEditor(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: _saving
                        ? const Center(child: CircularProgressIndicator())
                        : CustomButton(text: 'Save', onPressed: _save),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleEditor() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _ImagePickerGrid(
            title: 'Product photos (max 6)',
            helper: '${_simpleImages.length}/6 selected',
            images: _simpleImages,
            onAdd: () => _pickImages(_simpleImages, 6),
            onRemove: (i) => setState(() => _simpleImages.removeAt(i)),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _simplePriceController,
                  labelText: 'Price',
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
                  labelText: 'Promo',
                  hintText: 'Promo',
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  validator: (v) =>
                      _validatePromo(v, _simplePriceController.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CustomTextField(
            controller: _simpleStockController,
            labelText: 'Stock quantity',
            hintText: 'Stock',
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

  Widget _buildVariantEditor() {
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
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: group.color,
                        decoration: const InputDecoration(
                          labelText: 'Color',
                          labelStyle: TextStyle(
                            color: AppColors.darkText,
                            fontFamily: AppFonts.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          filled: true,
                          fillColor: AppColors.lightGrey,
                        ),
                        items: _colorOptions
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => group.color = v ?? group.color),
                      ),
                    ),
                    if (_variantGroups.length > 1)
                      IconButton(
                        onPressed: () =>
                            setState(() => _variantGroups.removeAt(groupIndex)),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _ImagePickerGrid(
                  title: 'Photos (max 3)',
                  helper: '${group.images.length}/3 selected',
                  images: group.images,
                  onAdd: () => _pickImages(group.images, 3),
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
                                  labelText: 'Size',
                                  labelStyle: TextStyle(
                                    color: AppColors.darkText,
                                    fontFamily: AppFonts.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                items: _sizeOptions
                                    .map(
                                      (e) => DropdownMenuItem(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => v.size = value ?? v.size),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CustomTextField(
                                controller: v.stockController,
                                labelText: 'Stock',
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
                                labelText: 'Price',
                                hintText: 'Price',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                  LengthLimitingTextInputFormatter(7),
                                ],
                                validator: _validatePrice,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: CustomTextField(
                                controller: v.promoPriceController,
                                labelText: 'Promo',
                                hintText: 'Promo (optional)',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                  LengthLimitingTextInputFormatter(7),
                                ],
                                validator: (val) =>
                                    _validatePromo(val, v.priceController.text),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: v.skuController,
                          labelText: 'SKU',
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
                                      promoPriceController:
                                          TextEditingController(),
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
                                  final removed = group.variants.removeAt(
                                    variantIndex,
                                  );
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

class _CategoryOption {
  final String id;
  final String name;
  const _CategoryOption({required this.id, required this.name});
}

class _ColorGroupDraft {
  String color;
  final List<_EditableImage> images;
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

class _EditableImage {
  final String? name;
  final String? extension;
  final Uint8List? bytes;
  final String? url;
  const _EditableImage({this.name, this.extension, this.bytes, this.url});

  factory _EditableImage.fromUrl(String url) => _EditableImage(url: url);
  factory _EditableImage.fromBytes({
    required String name,
    required Uint8List bytes,
    required String extension,
  }) => _EditableImage(name: name, bytes: bytes, extension: extension);
}

class _ImagePickerGrid extends StatelessWidget {
  final String title;
  final String helper;
  final List<_EditableImage> images;
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
        Text(title),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...List.generate(images.length, (index) {
              final image = images[index];
              Widget child;
              if (image.bytes != null) {
                child = Image.memory(
                  image.bytes!,
                  width: 78,
                  height: 78,
                  fit: BoxFit.cover,
                );
              } else {
                child = Image.network(
                  image.url!,
                  width: 78,
                  height: 78,
                  fit: BoxFit.cover,
                );
              }
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: child,
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
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 14,
                        ),
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
                ),
                child: const Icon(Icons.add_photo_alternate_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(helper),
      ],
    );
  }
}
