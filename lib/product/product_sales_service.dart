import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductSalesService {
  ProductSalesService._();

  static final ProductSalesService instance = ProductSalesService._();

  final Map<String, ProductEngagementMetrics> _metricsCache = {};
  final Map<String, Future<ProductEngagementMetrics>> _metricsFutures = {};

  Future<int> loadSoldCount(String productId) {
    return loadMetrics(productId).then((metrics) => metrics.soldCount);
  }

  Future<int> loadViewCount(String productId) {
    return loadMetrics(productId).then((metrics) => metrics.viewCount);
  }

  Future<ProductEngagementMetrics> loadMetrics(String productId) {
    if (productId.isEmpty) {
      return Future.value(ProductEngagementMetrics.empty);
    }
    final cached = _metricsCache[productId];
    if (cached != null) return Future.value(cached);
    return _metricsFutures.putIfAbsent(productId, () async {
      final metrics = await loadMetricsForProducts([productId]);
      return metrics[productId] ?? ProductEngagementMetrics.empty;
    });
  }

  Future<Map<String, ProductEngagementMetrics>> loadMetricsForProducts(
    List<String> productIds,
  ) async {
    final ids = productIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const {};

    final result = <String, ProductEngagementMetrics>{
      for (final id in ids)
        id: _metricsCache[id] ?? ProductEngagementMetrics.empty,
    };
    final missing = ids.where((id) => !_metricsCache.containsKey(id)).toList();
    if (missing.isEmpty) return result;

    final soldCounts = <String, int>{};
    final viewCounts = <String, int>{};

    try {
      final orderRows = await Supabase.instance.client
          .from('order_items')
          .select(
            'quantity, orders!inner(status), '
            'product_variants!inner(product_id)',
          )
          .filter('product_variants.product_id', 'in', missing);

      for (final row in orderRows as List<dynamic>) {
        final item = row as Map<String, dynamic>;
        final order = item['orders'] as Map<String, dynamic>?;
        if (!_isSoldStatus(order?['status']?.toString() ?? '')) continue;
        final variant = item['product_variants'] as Map<String, dynamic>?;
        final productId = variant?['product_id']?.toString();
        if (productId == null || productId.isEmpty) continue;
        soldCounts[productId] =
            (soldCounts[productId] ?? 0) +
            ((item['quantity'] as num?)?.toInt() ?? 0);
      }

      final viewRows = await Supabase.instance.client
          .from('product_views')
          .select('product_id')
          .filter('product_id', 'in', missing);

      for (final row in viewRows as List<dynamic>) {
        final productId = (row as Map<String, dynamic>)['product_id']
            ?.toString();
        if (productId == null || productId.isEmpty) continue;
        viewCounts[productId] = (viewCounts[productId] ?? 0) + 1;
      }

      for (final id in missing) {
        final metrics = ProductEngagementMetrics(
          soldCount: soldCounts[id] ?? 0,
          viewCount: viewCounts[id] ?? 0,
        );
        _metricsCache[id] = metrics;
        result[id] = metrics;
      }
    } catch (e) {
      debugPrint('Unable to load product metrics: $e');
    }

    return result;
  }

  bool _isSoldStatus(String status) {
    final value = status.trim().toLowerCase();
    return value == 'confirmed' ||
        value == 'confirm' ||
        value == 'in-delivery' ||
        value == 'in_delivery' ||
        value == 'in delivery' ||
        value == 'completed' ||
        value == 'delivered' ||
        value == 'arrived';
  }
}

class ProductEngagementMetrics {
  final int soldCount;
  final int viewCount;

  const ProductEngagementMetrics({
    required this.soldCount,
    required this.viewCount,
  });

  static const empty = ProductEngagementMetrics(soldCount: 0, viewCount: 0);
}
