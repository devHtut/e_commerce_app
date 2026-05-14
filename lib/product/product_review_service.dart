import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProductReviewService {
  ProductReviewService._();

  static final ProductReviewService instance = ProductReviewService._();

  final Map<String, ProductReviewSummary> _summaryCache = {};
  final Map<String, Future<ProductReviewSummary>> _summaryFutures = {};

  SupabaseClient get _client => Supabase.instance.client;

  Future<ProductReviewSummary> loadSummary(String productId) {
    if (productId.isEmpty) return Future.value(ProductReviewSummary.empty);
    final cached = _summaryCache[productId];
    if (cached != null) return Future.value(cached);
    return _summaryFutures.putIfAbsent(productId, () async {
      final summaries = await loadSummariesForProducts([productId]);
      return summaries[productId] ?? ProductReviewSummary.empty;
    });
  }

  Future<Map<String, ProductReviewSummary>> loadSummariesForProducts(
    List<String> productIds,
  ) async {
    final ids = productIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (ids.isEmpty) return const {};

    final result = <String, ProductReviewSummary>{
      for (final id in ids) id: _summaryCache[id] ?? ProductReviewSummary.empty,
    };
    final missing = ids.where((id) => !_summaryCache.containsKey(id)).toList();
    if (missing.isEmpty) return result;

    try {
      final rows = await _client
          .from('product_review_summary')
          .select('product_id,review_count,average_rating')
          .filter('product_id', 'in', missing);

      for (final row in rows as List<dynamic>) {
        final data = row as Map<String, dynamic>;
        final productId = data['product_id']?.toString();
        if (productId == null || productId.isEmpty) continue;
        final summary = ProductReviewSummary(
          reviewCount: (data['review_count'] as num?)?.toInt() ?? 0,
          averageRating: (data['average_rating'] as num?)?.toDouble() ?? 0.0,
        );
        _summaryCache[productId] = summary;
        result[productId] = summary;
      }

      for (final id in missing) {
        _summaryCache.putIfAbsent(id, () => ProductReviewSummary.empty);
      }
    } catch (e) {
      debugPrint('Unable to load product review summaries: $e');
    }

    return result;
  }

  Future<List<ProductReview>> loadProductReviews(String productId) async {
    if (productId.isEmpty) return const [];
    try {
      final rows = await _client
          .from('product_reviews')
          .select('id,rating,review_text,created_at,customer_id')
          .eq('product_id', productId)
          .order('created_at', ascending: false)
          .limit(20);

      return (rows as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ProductReview.fromRow)
          .toList();
    } catch (e) {
      debugPrint('Unable to load product reviews: $e');
      return const [];
    }
  }

  Future<ProductReview?> loadOrderProductReview({
    required String orderId,
    required String productId,
    String? productVariantId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null || orderId.isEmpty || productId.isEmpty) return null;

    try {
      var query = _client
          .from('product_reviews')
          .select('id,rating,review_text,created_at,customer_id')
          .eq('order_id', orderId)
          .eq('product_id', productId)
          .eq('customer_id', user.id);
      if (productVariantId != null && productVariantId.isNotEmpty) {
        query = query.eq('product_variant_id', productVariantId);
      }
      final row = await query.maybeSingle();
      if (row == null) return null;
      return ProductReview.fromRow(row);
    } catch (e) {
      debugPrint('Unable to load order product review: $e');
      return null;
    }
  }

  Future<void> submitReview({
    String? reviewId,
    required String orderId,
    String? orderItemId,
    required String productId,
    String? productVariantId,
    required String brandId,
    required int rating,
    String? reviewText,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Customer not authenticated');
    final text = reviewText?.trim();
    final payload = <String, dynamic>{
      'product_id': productId,
      if (productVariantId != null && productVariantId.isNotEmpty)
        'product_variant_id': productVariantId,
      'brand_id': brandId,
      'order_id': orderId,
      if (orderItemId != null && orderItemId.isNotEmpty)
        'order_item_id': orderItemId,
      'customer_id': user.id,
      'rating': rating,
      'review_text': text == null || text.isEmpty ? null : text,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (reviewId != null && reviewId.isNotEmpty) {
      await _client.from('product_reviews').update(payload).eq('id', reviewId);
    } else {
      await _client.from('product_reviews').insert(payload);
    }

    _summaryCache.remove(productId);
    _summaryFutures.remove(productId);
  }
}

class ProductReviewSummary {
  final int reviewCount;
  final double averageRating;

  const ProductReviewSummary({
    required this.reviewCount,
    required this.averageRating,
  });

  static const empty = ProductReviewSummary(reviewCount: 0, averageRating: 0);
}

class ProductReview {
  final String id;
  final int rating;
  final String reviewText;
  final DateTime createdAt;
  final String customerName;

  const ProductReview({
    required this.id,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
    required this.customerName,
  });

  factory ProductReview.fromRow(Map<String, dynamic> row) {
    final dateText = row['created_at']?.toString();
    return ProductReview(
      id: row['id']?.toString() ?? '',
      rating: (row['rating'] as num?)?.toInt() ?? 0,
      reviewText: row['review_text']?.toString() ?? '',
      createdAt: dateText == null
          ? DateTime.now()
          : DateTime.tryParse(dateText)?.toLocal() ?? DateTime.now(),
      customerName: 'Verified Customer',
    );
  }
}
