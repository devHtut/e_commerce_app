import 'package:flutter/foundation.dart';

import 'cart_item.dart';
import '../product/product_model.dart';

class CartService {
  CartService._();

  static final CartService instance = CartService._();

  final ValueNotifier<List<CartItem>> itemsNotifier =
      ValueNotifier<List<CartItem>>(<CartItem>[]);

  void addItem({
    required ProductModel product,
    required String size,
    required String colorName,
    required int colorValue,
    required String imageUrl,
    int quantity = 1,
  }) {
    final items = List<CartItem>.from(itemsNotifier.value);
    final existingIndex = items.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.size == size &&
          item.colorName == colorName,
    );

    if (existingIndex != -1) {
      final existing = items[existingIndex];
      items[existingIndex] =
          existing.copyWith(quantity: existing.quantity + quantity);
    } else {
      items.insert(
        0,
        CartItem(
          id: '${product.id}_${size}_$colorName',
          product: product,
          size: size,
          colorName: colorName,
          colorValue: colorValue,
          imageUrl: imageUrl,
          quantity: quantity,
        ),
      );
    }

    itemsNotifier.value = items;
  }

  void toggleSelection(String id) {
    final items = itemsNotifier.value
        .map((item) => item.id == id
            ? item.copyWith(isSelected: !item.isSelected)
            : item)
        .toList();
    itemsNotifier.value = items;
  }

  void removeItem(String id) {
    final items = List<CartItem>.from(itemsNotifier.value)
      ..removeWhere((item) => item.id == id);
    itemsNotifier.value = items;
  }

  void updateItemVariant({
    required String itemId,
    required String size,
    required String colorName,
    required int colorValue,
    required String imageUrl,
    required int quantity,
  }) {
    final items = List<CartItem>.from(itemsNotifier.value);
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final current = items[index];
    final updatedId = '${current.product.id}_${size}_$colorName';
    final existingIndex = items.indexWhere(
      (item) => item.id == updatedId && item.id != itemId,
    );

    if (existingIndex != -1) {
      final existing = items[existingIndex];
      items[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
        isSelected: existing.isSelected || current.isSelected,
      );
      items.removeAt(index);
    } else {
      items[index] = current.copyWith(
        id: updatedId,
        size: size,
        colorName: colorName,
        colorValue: colorValue,
        imageUrl: imageUrl,
        quantity: quantity,
      );
    }

    itemsNotifier.value = items;
  }

  double totalSelectedPrice(List<CartItem> items) {
    return items
        .where((item) => item.isSelected)
        .fold<double>(0, (sum, item) => sum + item.subtotal);
  }

  int selectedCount(List<CartItem> items) {
    return items.where((item) => item.isSelected).length;
  }
}
