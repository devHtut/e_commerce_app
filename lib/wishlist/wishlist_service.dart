import 'package:flutter/foundation.dart';

import '../product/product_model.dart';

class WishlistService {
  WishlistService._();

  static final WishlistService instance = WishlistService._();

  final ValueNotifier<List<ProductModel>> itemsNotifier =
      ValueNotifier<List<ProductModel>>(<ProductModel>[]);

  bool isWishlisted(String productId) {
    return itemsNotifier.value.any((item) => item.id == productId);
  }

  bool toggle(ProductModel product) {
    final items = List<ProductModel>.from(itemsNotifier.value);
    final index = items.indexWhere((item) => item.id == product.id);
    if (index == -1) {
      items.insert(0, product);
      itemsNotifier.value = items;
      return true;
    }
    items.removeAt(index);
    itemsNotifier.value = items;
    return false;
  }

  void remove(String productId) {
    final items = List<ProductModel>.from(itemsNotifier.value)
      ..removeWhere((item) => item.id == productId);
    itemsNotifier.value = items;
  }
}
