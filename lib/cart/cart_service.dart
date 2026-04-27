import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cart_item.dart';
import '../product/product_model.dart';

class CartService {
  CartService._();

  static final CartService instance = CartService._();

  final ValueNotifier<List<CartItem>> itemsNotifier =
      ValueNotifier<List<CartItem>>(<CartItem>[]);

  Future<void> addItem({
    required ProductModel product,
    required String variantId,
    required String size,
    required String colorName,
    required int colorValue,
    required String imageUrl,
    int quantity = 1,
  }) async {
    final items = List<CartItem>.from(itemsNotifier.value);
    final existingIndex = items.indexWhere(
      (item) =>
          item.product.id == product.id &&
          item.size == size &&
          item.colorName == colorName &&
          item.variantId == variantId,
    );

    if (existingIndex != -1) {
      final existing = items[existingIndex];
      final nextQty = existing.quantity + quantity;
      items[existingIndex] =
          existing.copyWith(quantity: nextQty);
      await _upsertItem(
        variantId: variantId,
        quantity: nextQty,
        currentDbId: existing.dbId,
      );
    } else {
      final dbId = await _upsertItem(variantId: variantId, quantity: quantity);
      items.insert(
        0,
        CartItem(
          id: '${product.id}_${variantId}_${size}_$colorName',
          dbId: dbId,
          variantId: variantId,
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

  Future<void> removeItem(String id) async {
    final items = List<CartItem>.from(itemsNotifier.value);
    final index = items.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final current = items[index];
    await _deleteItem(current);
    items.removeAt(index);
    itemsNotifier.value = items;
  }

  Future<void> updateItemVariant({
    required String itemId,
    required String variantId,
    required String size,
    required String colorName,
    required int colorValue,
    required String imageUrl,
    required int quantity,
  }) async {
    final items = List<CartItem>.from(itemsNotifier.value);
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final current = items[index];
    final updatedId =
        '${current.product.id}_${variantId}_${size}_$colorName';
    final existingIndex = items.indexWhere(
      (item) => item.id == updatedId && item.id != itemId,
    );

    if (existingIndex != -1) {
      final existing = items[existingIndex];
      final mergedQty = existing.quantity + quantity;
      items[existingIndex] = existing.copyWith(
        quantity: mergedQty,
        isSelected: existing.isSelected || current.isSelected,
      );
      await _upsertItem(
        variantId: existing.variantId ?? variantId,
        quantity: mergedQty,
        currentDbId: existing.dbId,
      );
      await _deleteItem(current);
      items.removeAt(index);
    } else {
      final dbId = await _upsertItem(
        variantId: variantId,
        quantity: quantity,
        currentDbId: current.dbId,
      );
      items[index] = current.copyWith(
        id: updatedId,
        dbId: dbId,
        variantId: variantId,
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

  Future<String?> _upsertItem({
    required String variantId,
    required int quantity,
    String? currentDbId,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return currentDbId;
    final payload = {
      'user_id': user.id,
      'variant_id': variantId,
      'quantity': quantity,
    };
    final query = Supabase.instance.client.from('cart');
    if (currentDbId != null && currentDbId.isNotEmpty) {
      await query.update(payload).eq('id', currentDbId);
      return currentDbId;
    }
    final inserted = await query.insert(payload).select('id').single();
    return inserted['id']?.toString();
  }

  Future<void> _deleteItem(CartItem item) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final query = Supabase.instance.client.from('cart');
    if (item.dbId != null && item.dbId!.isNotEmpty) {
      await query.delete().eq('id', item.dbId!);
      return;
    }
    if (item.variantId != null && item.variantId!.isNotEmpty) {
      await query
          .delete()
          .eq('user_id', user.id)
          .eq('variant_id', item.variantId!);
    }
  }
}
