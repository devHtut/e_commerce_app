import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cart/cart_item.dart';
import '../product/product_model.dart';

enum OrderStatus { pending, completed, canceled, refund }

class OrderModel {
  final String id;
  final List<CartItem> items;
  final DateTime createdAt;
  final OrderStatus status;
  final String shippingAddressLabel;
  final String shippingAddressRecipient;
  final String shippingAddressPhone;
  final String shippingAddressStreet;

  const OrderModel({
    required this.id,
    required this.items,
    required this.createdAt,
    required this.status,
    required this.shippingAddressLabel,
    required this.shippingAddressRecipient,
    required this.shippingAddressPhone,
    required this.shippingAddressStreet,
  });

  double get total => items.fold<double>(0, (sum, item) => sum + item.subtotal);

  OrderModel copyWith({
    List<CartItem>? items,
    DateTime? createdAt,
    OrderStatus? status,
    String? shippingAddressLabel,
    String? shippingAddressRecipient,
    String? shippingAddressPhone,
    String? shippingAddressStreet,
  }) {
    return OrderModel(
      id: id,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      shippingAddressLabel: shippingAddressLabel ?? this.shippingAddressLabel,
      shippingAddressRecipient:
          shippingAddressRecipient ?? this.shippingAddressRecipient,
      shippingAddressPhone: shippingAddressPhone ?? this.shippingAddressPhone,
      shippingAddressStreet:
          shippingAddressStreet ?? this.shippingAddressStreet,
    );
  }
}

class OrderService {
  OrderService._();

  static final OrderService instance = OrderService._();

  final ValueNotifier<List<OrderModel>> ordersNotifier =
      ValueNotifier<List<OrderModel>>(<OrderModel>[]);

  Future<void> loadOrders() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final orderRows = await Supabase.instance.client
          .from('orders')
          .select('''
            id,
            status,
            created_at,
            shipping_address_id,
            order_items (
              quantity,
              price_at_purchase,
              product_variants (
                id,
                size,
                color,
                image_url,
                products (
                  id,
                  title,
                  description,
                  base_price,
                  categories(name),
                  brands(brand_name, id)
                )
              )
            )
          ''')
          .eq('customer_id', user.id)
          .order('created_at', ascending: false);

      final shippingAddressIds = orderRows
          .map((row) => row['shipping_address_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final addressMap = <String, Map<String, dynamic>>{};
      if (shippingAddressIds.isNotEmpty) {
        final addressRows = await Supabase.instance.client
            .from('user_addresses')
            .select('id,label,phone_number,address_line,city')
            .filter('id', 'in', shippingAddressIds);

        for (final addressRow in addressRows as List<dynamic>) {
          final id = addressRow['id']?.toString();
          if (id == null) continue;
          addressMap[id] = addressRow as Map<String, dynamic>;
        }
      }

      final orders = <OrderModel>[];
      for (final orderRow in orderRows) {
        final orderId = orderRow['id']?.toString() ?? '';
        final statusString = orderRow['status']?.toString() ?? 'pending';
        final createdAtString = orderRow['created_at']?.toString();
        final createdAt = createdAtString != null
            ? DateTime.parse(createdAtString)
            : DateTime.now();
        final shippingAddressId = orderRow['shipping_address_id']?.toString();

        final status = () {
          if (statusString == 'completed') return OrderStatus.completed;
          if (statusString == 'canceled') return OrderStatus.canceled;
          if (statusString == 'refund' || statusString == 'refunded') {
            return OrderStatus.refund;
          }
          return OrderStatus.pending;
        }();

        final items = <CartItem>[];
        final orderItems = orderRow['order_items'] as List<dynamic>? ?? [];

        for (final itemRow in orderItems) {
          final quantity = itemRow['quantity'] as int? ?? 1;
          final priceAtPurchase =
              (itemRow['price_at_purchase'] as num?)?.toDouble() ?? 0.0;

          final variantRow =
              itemRow['product_variants'] as Map<String, dynamic>?;
          if (variantRow == null) continue;

          final productRow = variantRow['products'] as Map<String, dynamic>?;
          if (productRow == null) continue;

          final categoryRow = productRow['categories'] as Map<String, dynamic>?;
          final brandRow = productRow['brands'] as Map<String, dynamic>?;

          final product = ProductModel(
            id: productRow['id']?.toString() ?? '',
            name: productRow['title']?.toString() ?? '',
            description: productRow['description']?.toString() ?? '',
            price: priceAtPurchase,
            category: categoryRow?['name']?.toString() ?? '',
            brand: brandRow?['brand_name']?.toString() ?? '',
            brandId: brandRow?['id']?.toString() ?? '',
            rating: 0.0, // Default rating since it's not stored in order data
            imageUrl: variantRow['image_url']?.toString() ?? '',
          );

          final cartItem = CartItem(
            id: 'item_${DateTime.now().microsecondsSinceEpoch}_${items.length}',
            variantId: variantRow['id']?.toString(),
            product: product,
            size: variantRow['size']?.toString() ?? '',
            colorName: variantRow['color']?.toString() ?? '',
            colorValue: 0,
            imageUrl: variantRow['image_url']?.toString() ?? '',
            quantity: quantity,
          );

          items.add(cartItem);
        }

        final shippingData = shippingAddressId != null
            ? addressMap[shippingAddressId]
            : null;
        final street = shippingData != null
            ? shippingData['address_line']?.toString() ?? ''
            : '';
        final city = shippingData != null
            ? shippingData['city']?.toString() ?? ''
            : '';

        if (items.isNotEmpty) {
          orders.add(
            OrderModel(
              id: orderId,
              items: items,
              createdAt: createdAt,
              status: status,
              shippingAddressLabel: shippingData?['label']?.toString() ?? '',
              shippingAddressRecipient:
                  shippingData?['label']?.toString() ?? '',
              shippingAddressPhone:
                  shippingData?['phone_number']?.toString() ?? '',
              shippingAddressStreet:
                  '$street${city.isNotEmpty ? ', $city' : ''}',
            ),
          );
        }
      }

      ordersNotifier.value = orders;
    } catch (e) {
      // Handle error silently or log it
      debugPrint('Error loading orders: $e');
    }
  }

  void placeOrder(
    List<CartItem> items, {
    String? orderId,
    OrderStatus status = OrderStatus.pending,
    String shippingAddressLabel = '',
    String shippingAddressRecipient = '',
    String shippingAddressPhone = '',
    String shippingAddressStreet = '',
  }) {
    if (items.isEmpty) return;
    final orders = List<OrderModel>.from(ordersNotifier.value);
    orders.insert(
      0,
      OrderModel(
        id: orderId ?? 'ord_${DateTime.now().microsecondsSinceEpoch}',
        items: List<CartItem>.from(items),
        createdAt: DateTime.now(),
        status: status,
        shippingAddressLabel: shippingAddressLabel,
        shippingAddressRecipient: shippingAddressRecipient,
        shippingAddressPhone: shippingAddressPhone,
        shippingAddressStreet: shippingAddressStreet,
      ),
    );
    ordersNotifier.value = orders;
  }

  void cancelOrder(String orderId) {
    final orders = ordersNotifier.value
        .map(
          (order) => order.id == orderId
              ? order.copyWith(status: OrderStatus.canceled)
              : order,
        )
        .toList();
    ordersNotifier.value = orders;
  }
}
