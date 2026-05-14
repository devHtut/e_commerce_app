import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VendorInventoryService {
  VendorInventoryService._();

  static final VendorInventoryService instance = VendorInventoryService._();
  static const int lowStockThreshold = 10;

  final ValueNotifier<int> lowStockCountNotifier = ValueNotifier<int>(0);

  SupabaseClient get _client => Supabase.instance.client;

  Future<int> refreshLowStockCount() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      lowStockCountNotifier.value = 0;
      return 0;
    }

    final brand = await _client
        .from('brands')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();
    final brandId = brand?['id']?.toString();
    if (brandId == null || brandId.isEmpty) {
      lowStockCountNotifier.value = 0;
      return 0;
    }

    final rows = await _client
        .from('product_variants')
        .select('id, products!inner(brand_id)')
        .eq('products.brand_id', brandId)
        .lte('stock_quantity', lowStockThreshold);

    final count = (rows as List<dynamic>).length;
    lowStockCountNotifier.value = count;
    return count;
  }
}
