import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../notification/notification_service.dart';
import '../product/product_model.dart';
import 'cart_item.dart';

class CartService {
  CartService._();

  static final CartService instance = CartService._();

  final ValueNotifier<List<CartItem>> itemsNotifier =
      ValueNotifier<List<CartItem>>(<CartItem>[]);

  final Set<String> _expiryWarningSentItemIds = {};

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
      items[existingIndex] = existing.copyWith(quantity: nextQty);
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
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }

    itemsNotifier.value = items;
  }

  void toggleSelection(String id) {
    final items = itemsNotifier.value
        .map(
          (item) => item.id == id
              ? item.copyWith(isSelected: !item.isSelected)
              : item,
        )
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

  Future<void> loadCartItems() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final rows = await Supabase.instance.client
          .from('cart')
          .select(
            'id,variant_id,quantity,created_at,product_variants(id,size,color,stock_quantity,price_adjustment,promo_price,image_url,sku,products(id,title,description,base_price,category_id,brand_id,categories(name),brands(brand_name,logo_url)))',
          )
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final items = (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_buildCartItemFromRow)
          .whereType<CartItem>()
          .toList();

      await _processExpiryAndNotifications(items);
      itemsNotifier.value = items.where((item) => !item.isExpired).toList();
    } catch (e) {
      debugPrint('Unable to load cart items: $e');
    }
  }

  CartItem? _buildCartItemFromRow(Map<String, dynamic> row) {
    final cartId = row['id']?.toString() ?? '';
    final variantId = row['variant_id']?.toString() ?? '';
    final quantity = (row['quantity'] as num?)?.toInt() ?? 1;
    final createdAtText = row['created_at']?.toString();
    final createdAt = createdAtText != null
        ? DateTime.tryParse(createdAtText)?.toUtc() ?? DateTime.now().toUtc()
        : DateTime.now().toUtc();

    dynamic rawVariant = row['product_variants'];
    Map<String, dynamic>? variantRow;
    if (rawVariant is Map<String, dynamic>) {
      variantRow = rawVariant;
    } else if (rawVariant is List<dynamic> && rawVariant.isNotEmpty) {
      variantRow = rawVariant.first as Map<String, dynamic>;
    }

    final productRow = variantRow != null
        ? _extractRow(variantRow['products'])
        : null;
    if (productRow == null) return null;

    final product = ProductModel.fromSupabaseRow(productRow);
    final size = variantRow?['size']?.toString() ?? 'Default';
    final colorName = variantRow?['color']?.toString() ?? 'Default';
    final colorValue =
        int.tryParse(variantRow?['color_value']?.toString() ?? '') ??
        0xFF000000;
    final imageUrl = variantRow?['image_url']?.toString().isNotEmpty == true
        ? variantRow!['image_url']!.toString()
        : product.imageUrl;

    return CartItem(
      id: '${product.id}_${variantId}_${size}_$colorName',
      dbId: cartId,
      variantId: variantId,
      product: product,
      size: size,
      colorName: colorName,
      colorValue: colorValue,
      imageUrl: imageUrl,
      quantity: quantity,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic>? _extractRow(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw;
    }
    if (raw is List<dynamic> &&
        raw.isNotEmpty &&
        raw.first is Map<String, dynamic>) {
      return raw.first as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> _processExpiryAndNotifications(List<CartItem> items) async {
    final expiredItems = items.where((item) => item.isExpired).toList();
    final activeItems = items.where((item) => !item.isExpired).toList();

    for (final expiredItem in expiredItems) {
      await _deleteItem(expiredItem);
      await NotificationService.instance.notifyCartItemRemovedFromCart(
        productName: expiredItem.product.name,
        variantInfo: _buildVariantInfo(expiredItem),
      );
    }

    for (final item in activeItems) {
      if (item.isExpiringSoon) {
        final key = item.dbId?.isNotEmpty == true ? item.dbId! : item.id;
        if (!_expiryWarningSentItemIds.contains(key)) {
          await NotificationService.instance.notifyCartExpiryWarning(
            productName: item.product.name,
            variantInfo: _buildVariantInfo(item),
            daysLeft: item.daysRemaining,
          );
          _expiryWarningSentItemIds.add(key);
        }
      }
    }

    if (expiredItems.isNotEmpty) {
      items.removeWhere((item) => item.isExpired);
    }
  }

  String _buildVariantInfo(CartItem item) {
    return '(Size: ${item.size}, Color: ${item.colorName})';
  }

  Future<void> updateItemVariant({
    required String itemId,
    required String variantId,
    required String size,
    required String colorName,
    required int colorValue,
    required String imageUrl,
    required double selectedPrice,
    required int quantity,
  }) async {
    final items = List<CartItem>.from(itemsNotifier.value);
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) return;

    final current = items[index];
    final updatedId = '${current.product.id}_${variantId}_${size}_$colorName';
    final existingIndex = items.indexWhere(
      (item) => item.id == updatedId && item.id != itemId,
    );

    if (existingIndex != -1) {
      final existing = items[existingIndex];
      final mergedQty = existing.quantity + quantity;
      items[existingIndex] = existing.copyWith(
        quantity: mergedQty,
        product: existing.product.copyWith(price: selectedPrice),
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
        product: current.product.copyWith(price: selectedPrice),
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
