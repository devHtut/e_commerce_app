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

  Future<bool> toggle(ProductModel product) async {
    final items = List<ProductModel>.from(itemsNotifier.value);
    final index = items.indexWhere((item) => item.id == product.id);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      clear();
      return false;
    }
    if (index == -1) {
      await Supabase.instance.client.from('wishlist').insert({
        'user_id': user.id,
        'product_id': product.id,
      });
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
