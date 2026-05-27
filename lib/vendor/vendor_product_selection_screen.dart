import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../theme_config.dart';
import '../widgets/custom_loading_state.dart';
import '../widgets/custom_pop_up.dart';
import 'vendor_plan_service.dart';

class VendorProductSelectionScreen extends StatefulWidget {
  final int productLimit;

  const VendorProductSelectionScreen({super.key, required this.productLimit});

  @override
  State<VendorProductSelectionScreen> createState() =>
      _VendorProductSelectionScreenState();
}

class _VendorProductSelectionScreenState
    extends State<VendorProductSelectionScreen> {
  bool _loading = true;
  bool _saving = false;
  List<VendorSelectableProduct> _products = const <VendorSelectableProduct>[];
  final Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await VendorPlanService.instance
        .loadInStockProductsForSelection();
    if (!mounted) return;
    setState(() {
      _products = products;
      _selected
        ..clear()
        ..addAll(
          products
              .where((product) => !product.planLocked)
              .take(widget.productLimit)
              .map((product) => product.id),
        );
      if (_selected.isEmpty) {
        _selected.addAll(
          products.take(widget.productLimit).map((product) => product.id),
        );
      }
      _loading = false;
    });
  }

  void _toggle(String productId) {
    setState(() {
      if (_selected.contains(productId)) {
        _selected.remove(productId);
      } else if (_selected.length < widget.productLimit) {
        _selected.add(productId);
      }
    });
  }

  Future<void> _saveSelection() async {
    if (_selected.length != widget.productLimit) {
      await showCustomPopup(
        context,
        title: 'Choose ${widget.productLimit} products',
        message:
            'Please choose exactly ${widget.productLimit} in-stock products to keep editable.',
        type: PopupType.error,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await VendorPlanService.instance.applyManualProductSelection(_selected);
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Products updated',
        message:
            'Your selected products stay editable. The remaining products are locked until you upgrade.',
        type: PopupType.success,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      await showCustomPopup(
        context,
        title: 'Unable to save',
        message: 'Please try again.',
        type: PopupType.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        title: const Text('Choose Products', style: AppTextStyles.appBarTitle),
      ),
      body: SafeArea(
        child: _loading
            ? const CustomLoadingCenter()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_selected.length} / ${widget.productLimit} selected',
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontFamily: AppFonts.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your trial has ended. Choose the products you want to keep editable on the Free plan.',
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: _products.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final product = _products[index];
                        final selected = _selected.contains(product.id);
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _saving ? null : () => _toggle(product.id),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: product.imageUrl.isEmpty
                                        ? Container(
                                            width: 62,
                                            height: 62,
                                            color: Colors.grey.shade200,
                                            child: const Icon(
                                              CupertinoIcons.photo,
                                              color: AppColors.subtleText,
                                            ),
                                          )
                                        : Image.network(
                                            product.imageUrl,
                                            width: 62,
                                            height: 62,
                                            fit: BoxFit.cover,
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.darkText,
                                            fontFamily: AppFonts.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${product.stock} in stock',
                                          style: const TextStyle(
                                            color: AppColors.subtleText,
                                            fontFamily: AppFonts.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    selected
                                        ? CupertinoIcons
                                              .check_mark_circled_solid
                                        : CupertinoIcons.circle,
                                    color: selected
                                        ? AppColors.primaryGreen
                                        : Colors.grey,
                                    size: 28,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveSelection,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          _saving ? 'Saving...' : 'Keep Selected Products',
                          style: AppTextStyles.button,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
