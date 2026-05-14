import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BrandAnalyticsService {
  BrandAnalyticsService._();

  static final BrandAnalyticsService instance = BrandAnalyticsService._();
  static const int lowStockThreshold = 10;
  static const Duration _eventThrottle = Duration(minutes: 30);
  static final String _sessionId =
      'session_${DateTime.now().millisecondsSinceEpoch}';

  final Map<String, DateTime> _recentEvents = {};

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> recordProductView({
    required String productId,
    required String brandId,
    String? variantId,
  }) async {
    if (productId.isEmpty || brandId.isEmpty) return;
    final currentUserId = _client.auth.currentUser?.id;
    await _recordThrottled(
      key: 'product:$productId',
      insert: () {
        final payload = <String, dynamic>{
          'brand_id': brandId,
          'product_id': productId,
          'session_id': _sessionId,
        };
        if (variantId != null && variantId.isNotEmpty) {
          payload['variant_id'] = variantId;
        }
        if (currentUserId != null) {
          payload['viewer_id'] = currentUserId;
        }
        return _client.from('product_views').insert(payload);
      },
    );
  }

  Future<void> recordBrandProfileVisit({
    required String brandId,
    String? ownerId,
  }) async {
    if (brandId.isEmpty) return;
    final currentUserId = _client.auth.currentUser?.id;
    if (ownerId != null && ownerId.isNotEmpty && ownerId == currentUserId) {
      return;
    }
    await _recordThrottled(
      key: 'brand:$brandId',
      insert: () {
        final payload = <String, dynamic>{
          'brand_id': brandId,
          'session_id': _sessionId,
        };
        if (currentUserId != null) {
          payload['visitor_id'] = currentUserId;
        }
        return _client.from('brand_profile_visits').insert(payload);
      },
    );
  }

  Future<void> _recordThrottled({
    required String key,
    required Future<void> Function() insert,
  }) async {
    final now = DateTime.now();
    final lastRecorded = _recentEvents[key];
    if (lastRecorded != null && now.difference(lastRecorded) < _eventThrottle) {
      return;
    }
    _recentEvents[key] = now;

    try {
      await insert();
    } catch (e) {
      debugPrint('Unable to record analytics event: $e');
    }
  }

  Future<BrandAnalyticsSnapshot> loadSnapshot(BrandAnalyticsRange range) async {
    final user = _client.auth.currentUser;
    if (user == null) return BrandAnalyticsSnapshot.empty(range);

    final brand = await _client
        .from('brands')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();
    final brandId = brand?['id']?.toString();
    if (brandId == null || brandId.isEmpty) {
      return BrandAnalyticsSnapshot.empty(range);
    }

    final start = range.startDate(DateTime.now());
    final startIso = start.toUtc().toIso8601String();

    final ordersFuture = _client
        .from('orders')
        .select(
          'id,readable_id,status,total_price,created_at,'
          'order_items(quantity,price_at_purchase,brand_id,'
          'product_variants(id,size,color,stock_quantity,'
          'products(id,title)))',
        )
        .eq('brand_id', brandId)
        .gte('created_at', startIso)
        .order('created_at', ascending: false);

    final productViewsFuture = _client
        .from('product_views')
        .select('product_id,viewer_id,session_id,viewed_at,products(title)')
        .eq('brand_id', brandId)
        .gte('viewed_at', startIso);

    final profileVisitsFuture = _client
        .from('brand_profile_visits')
        .select('visitor_id,session_id,visited_at')
        .eq('brand_id', brandId)
        .gte('visited_at', startIso);

    final lowStockFuture = _client
        .from('product_variants')
        .select(
          'id,size,color,stock_quantity,products!inner(id,title,brand_id)',
        )
        .eq('products.brand_id', brandId)
        .lte('stock_quantity', lowStockThreshold)
        .order('stock_quantity', ascending: true)
        .limit(8);

    final results = await Future.wait<dynamic>([
      ordersFuture,
      productViewsFuture,
      profileVisitsFuture,
      lowStockFuture,
    ]);

    return _buildSnapshot(
      range: range,
      orders: (results[0] as List<dynamic>).cast<Map<String, dynamic>>(),
      productViews: (results[1] as List<dynamic>).cast<Map<String, dynamic>>(),
      profileVisits: (results[2] as List<dynamic>).cast<Map<String, dynamic>>(),
      lowStockRows: (results[3] as List<dynamic>).cast<Map<String, dynamic>>(),
    );
  }

  BrandAnalyticsSnapshot _buildSnapshot({
    required BrandAnalyticsRange range,
    required List<Map<String, dynamic>> orders,
    required List<Map<String, dynamic>> productViews,
    required List<Map<String, dynamic>> profileVisits,
    required List<Map<String, dynamic>> lowStockRows,
  }) {
    final bestSelling = <String, _MutableProductSales>{};
    final revenueByDate = <DateTime, double>{};
    var totalRevenue = 0.0;
    var productsSold = 0;
    var salesOrderCount = 0;
    var pendingOrderCount = 0;
    var canceledOrderCount = 0;

    for (final order in orders) {
      final status = order['status']?.toString() ?? '';
      if (_isPendingStatus(status)) pendingOrderCount++;
      if (_isCanceledStatus(status)) canceledOrderCount++;
      if (!_isRevenueStatus(status)) continue;

      salesOrderCount++;
      final createdAt = _parseDate(order['created_at']);
      final day = createdAt == null
          ? null
          : DateTime(createdAt.year, createdAt.month, createdAt.day);
      var orderRevenue = 0.0;

      final items = (order['order_items'] as List<dynamic>? ?? const []);
      for (final itemRaw in items) {
        final item = itemRaw as Map<String, dynamic>;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        final price = (item['price_at_purchase'] as num?)?.toDouble() ?? 0;
        final revenue = quantity * price;
        orderRevenue += revenue;
        productsSold += quantity;

        final variant = item['product_variants'] as Map<String, dynamic>?;
        final product = variant?['products'] as Map<String, dynamic>?;
        final productId = product?['id']?.toString() ?? 'unknown';
        final variantId = variant?['id']?.toString() ?? '';
        final key = '$productId:$variantId';
        final entry = bestSelling.putIfAbsent(
          key,
          () => _MutableProductSales(
            productId: productId,
            variantId: variantId,
            productTitle: product?['title']?.toString() ?? 'Product',
            variantLabel: _variantLabel(variant),
          ),
        );
        entry.quantitySold += quantity;
        entry.grossRevenue += revenue;
        entry.orderIds.add(order['id']?.toString() ?? '');
      }

      totalRevenue += orderRevenue;
      if (day != null) {
        revenueByDate[day] = (revenueByDate[day] ?? 0) + orderRevenue;
      }
    }

    final popular = <String, _MutableProductViews>{};
    for (final row in productViews) {
      final productId = row['product_id']?.toString() ?? '';
      if (productId.isEmpty) continue;
      final product = row['products'] as Map<String, dynamic>?;
      final entry = popular.putIfAbsent(
        productId,
        () => _MutableProductViews(
          productId: productId,
          productTitle: product?['title']?.toString() ?? 'Product',
        ),
      );
      entry.totalViews++;
      final viewerId = row['viewer_id']?.toString();
      final sessionId = row['session_id']?.toString();
      if (viewerId != null && viewerId.isNotEmpty) {
        entry.viewerIds.add(viewerId);
      }
      if (sessionId != null && sessionId.isNotEmpty) {
        entry.sessionIds.add(sessionId);
      }
    }

    final uniqueProfileUsers = <String>{};
    final uniqueProfileSessions = <String>{};
    for (final row in profileVisits) {
      final visitorId = row['visitor_id']?.toString();
      final sessionId = row['session_id']?.toString();
      if (visitorId != null && visitorId.isNotEmpty) {
        uniqueProfileUsers.add(visitorId);
      }
      if (sessionId != null && sessionId.isNotEmpty) {
        uniqueProfileSessions.add(sessionId);
      }
    }

    final totalProductViews = productViews.length;
    final conversionRate = totalProductViews == 0
        ? 0.0
        : (salesOrderCount / totalProductViews) * 100;

    final revenueSeries = _buildRevenueSeries(range, revenueByDate);
    final topSales = bestSelling.values.map((item) => item.toItem()).toList()
      ..sort((a, b) => b.quantitySold.compareTo(a.quantitySold));
    final topViews = popular.values.map((item) => item.toItem()).toList()
      ..sort((a, b) => b.totalViews.compareTo(a.totalViews));
    final lowStock = lowStockRows.map(_lowStockFromRow).toList();

    return BrandAnalyticsSnapshot(
      range: range,
      totalRevenue: totalRevenue,
      totalOrders: orders.length,
      salesOrderCount: salesOrderCount,
      pendingOrderCount: pendingOrderCount,
      canceledOrderCount: canceledOrderCount,
      productsSold: productsSold,
      productViews: totalProductViews,
      brandProfileVisits: profileVisits.length,
      uniqueProfileVisits: uniqueProfileUsers.isNotEmpty
          ? uniqueProfileUsers.length
          : uniqueProfileSessions.length,
      conversionRate: conversionRate,
      revenueSeries: revenueSeries,
      bestSellingProducts: topSales.take(5).toList(),
      popularProducts: topViews.take(5).toList(),
      lowStockItems: lowStock,
    );
  }

  List<BrandRevenuePoint> _buildRevenueSeries(
    BrandAnalyticsRange range,
    Map<DateTime, double> revenueByDate,
  ) {
    final now = DateTime.now();
    if (range == BrandAnalyticsRange.week) {
      final start = range.startDate(now);
      return List.generate(7, (index) {
        final day = DateTime(start.year, start.month, start.day + index);
        return BrandRevenuePoint(
          label: _weekdayLabel(day),
          value: revenueByDate[day] ?? 0,
        );
      });
    }

    final buckets = range == BrandAnalyticsRange.month ? 4 : 12;
    final labels = range == BrandAnalyticsRange.month
        ? const ['W1', 'W2', 'W3', 'W4']
        : const [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
    final values = List<double>.filled(buckets, 0);
    revenueByDate.forEach((date, value) {
      final index = range == BrandAnalyticsRange.month
          ? ((date.day - 1) ~/ 7).clamp(0, 3)
          : date.month - 1;
      values[index] += value;
    });
    return List.generate(
      buckets,
      (index) => BrandRevenuePoint(label: labels[index], value: values[index]),
    );
  }

  BrandLowStockItem _lowStockFromRow(Map<String, dynamic> row) {
    final product = row['products'] as Map<String, dynamic>?;
    return BrandLowStockItem(
      productTitle: product?['title']?.toString() ?? 'Product',
      variantLabel: _variantLabel(row),
      stockQuantity: (row['stock_quantity'] as num?)?.toInt() ?? 0,
    );
  }

  static bool _isRevenueStatus(String status) {
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

  static bool _isPendingStatus(String status) {
    return status.trim().toLowerCase() == 'pending';
  }

  static bool _isCanceledStatus(String status) {
    final value = status.trim().toLowerCase();
    return value == 'cancel' || value == 'canceled' || value == 'cancelled';
  }

  static DateTime? _parseDate(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return DateTime.tryParse(text)?.toLocal();
  }

  static String _weekdayLabel(DateTime date) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[date.weekday - 1];
  }

  static String _variantLabel(Map<String, dynamic>? row) {
    final size = row?['size']?.toString().trim() ?? '';
    final color = row?['color']?.toString().trim() ?? '';
    final parts = [
      if (size.isNotEmpty && size.toLowerCase() != 'default') size,
      if (color.isNotEmpty && color.toLowerCase() != 'default') color,
    ];
    return parts.isEmpty ? 'Default' : parts.join(' / ');
  }
}

enum BrandAnalyticsRange {
  week('Week'),
  month('Month'),
  year('Year');

  final String label;
  const BrandAnalyticsRange(this.label);

  DateTime startDate(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (this) {
      BrandAnalyticsRange.week => today.subtract(
        Duration(days: today.weekday - 1),
      ),
      BrandAnalyticsRange.month => DateTime(today.year, today.month),
      BrandAnalyticsRange.year => DateTime(today.year),
    };
  }
}

class BrandAnalyticsSnapshot {
  final BrandAnalyticsRange range;
  final double totalRevenue;
  final int totalOrders;
  final int salesOrderCount;
  final int pendingOrderCount;
  final int canceledOrderCount;
  final int productsSold;
  final int productViews;
  final int brandProfileVisits;
  final int uniqueProfileVisits;
  final double conversionRate;
  final List<BrandRevenuePoint> revenueSeries;
  final List<BrandProductSalesItem> bestSellingProducts;
  final List<BrandProductViewItem> popularProducts;
  final List<BrandLowStockItem> lowStockItems;

  const BrandAnalyticsSnapshot({
    required this.range,
    required this.totalRevenue,
    required this.totalOrders,
    required this.salesOrderCount,
    required this.pendingOrderCount,
    required this.canceledOrderCount,
    required this.productsSold,
    required this.productViews,
    required this.brandProfileVisits,
    required this.uniqueProfileVisits,
    required this.conversionRate,
    required this.revenueSeries,
    required this.bestSellingProducts,
    required this.popularProducts,
    required this.lowStockItems,
  });

  factory BrandAnalyticsSnapshot.empty(BrandAnalyticsRange range) {
    return BrandAnalyticsSnapshot(
      range: range,
      totalRevenue: 0,
      totalOrders: 0,
      salesOrderCount: 0,
      pendingOrderCount: 0,
      canceledOrderCount: 0,
      productsSold: 0,
      productViews: 0,
      brandProfileVisits: 0,
      uniqueProfileVisits: 0,
      conversionRate: 0,
      revenueSeries: const [],
      bestSellingProducts: const [],
      popularProducts: const [],
      lowStockItems: const [],
    );
  }
}

class BrandRevenuePoint {
  final String label;
  final double value;

  const BrandRevenuePoint({required this.label, required this.value});
}

class BrandProductSalesItem {
  final String productTitle;
  final String variantLabel;
  final int quantitySold;
  final int orderCount;
  final double grossRevenue;

  const BrandProductSalesItem({
    required this.productTitle,
    required this.variantLabel,
    required this.quantitySold,
    required this.orderCount,
    required this.grossRevenue,
  });
}

class BrandProductViewItem {
  final String productTitle;
  final int totalViews;
  final int uniqueViews;

  const BrandProductViewItem({
    required this.productTitle,
    required this.totalViews,
    required this.uniqueViews,
  });
}

class BrandLowStockItem {
  final String productTitle;
  final String variantLabel;
  final int stockQuantity;

  const BrandLowStockItem({
    required this.productTitle,
    required this.variantLabel,
    required this.stockQuantity,
  });
}

class _MutableProductSales {
  final String productId;
  final String variantId;
  final String productTitle;
  final String variantLabel;
  final Set<String> orderIds = {};
  int quantitySold = 0;
  double grossRevenue = 0;

  _MutableProductSales({
    required this.productId,
    required this.variantId,
    required this.productTitle,
    required this.variantLabel,
  });

  BrandProductSalesItem toItem() {
    return BrandProductSalesItem(
      productTitle: productTitle,
      variantLabel: variantLabel,
      quantitySold: quantitySold,
      orderCount: orderIds.length,
      grossRevenue: grossRevenue,
    );
  }
}

class _MutableProductViews {
  final String productId;
  final String productTitle;
  final Set<String> viewerIds = {};
  final Set<String> sessionIds = {};
  int totalViews = 0;

  _MutableProductViews({required this.productId, required this.productTitle});

  BrandProductViewItem toItem() {
    return BrandProductViewItem(
      productTitle: productTitle,
      totalViews: totalViews,
      uniqueViews: viewerIds.isNotEmpty ? viewerIds.length : sessionIds.length,
    );
  }
}
