import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../product/product_model.dart';

class WishlistService {
  WishlistService._();

  static final WishlistService instance = WishlistService._();

  final ValueNotifier<List<ProductModel>> itemsNotifier =
      ValueNotifier<List<ProductModel>>(<ProductModel>[]);

  void clear() {
    itemsNotifier.value = <ProductModel>[];
  }

  bool isWishlisted(String productId) {
    if (Supabase.instance.client.auth.currentUser == null) return false;
    return itemsNotifier.value.any((item) => item.id == productId);
  }

  Future<void> loadWishlistItems() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      clear();
      return;
    }

    try {
      final wishlistRows = await Supabase.instance.client
          .from('wishlist')
          .select('product_id')
          .eq('user_id', user.id);
      final productIds = (wishlistRows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((row) => row['product_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toList();

      if (productIds.isEmpty) {
        clear();
        return;
      }

      final productRows = await Supabase.instance.client
          .from('products')
          .select(
            'id, brand_id, category_id, title, description, base_price, created_at, '
            'categories(name), brands(brand_name,logo_url), product_variants(image_url)',
          )
          .filter('id', 'in', productIds);
      final productsById = {
        for (final row
            in (productRows as List<dynamic>).cast<Map<String, dynamic>>())
          row['id'].toString(): ProductModel.fromSupabaseRow(row),
      };

      itemsNotifier.value = productIds
          .map((id) => productsById[id])
          .whereType<ProductModel>()
          .toList();
    } catch (e) {
      debugPrint('Unable to load wishlist items: $e');
    }
  }

  Future<bool> toggle(ProductModel product) async {
    final items = List<ProductModel>.from(itemsNotifier.value);
    final index = items.indexWhere((item) => item.id == product.id);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      clear();
      return false;
    }
    if (index == -1) {
      final existing = await Supabase.instance.client
          .from('wishlist')
          .select('id')
          .eq('user_id', user.id)
          .eq('product_id', product.id)
          .maybeSingle();
      if (existing == null) {
        await Supabase.instance.client.from('wishlist').insert({
          'user_id': user.id,
          'product_id': product.id,
        });
      }
      items.insert(0, product);
      itemsNotifier.value = items;
      return true;
    }
    await Supabase.instance.client
        .from('wishlist')
        .delete()
        .eq('user_id', user.id)
        .eq('product_id', product.id);
    items.removeAt(index);
    itemsNotifier.value = items;
    return false;
  }

  Future<void> remove(String productId) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      clear();
      return;
    }
    await Supabase.instance.client
        .from('wishlist')
        .delete()
        .eq('user_id', user.id)
        .eq('product_id', productId);
    final items = List<ProductModel>.from(itemsNotifier.value)
      ..removeWhere((item) => item.id == productId);
    itemsNotifier.value = items;
  }
}
