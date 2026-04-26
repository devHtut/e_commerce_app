import 'package:flutter/foundation.dart';

import '../cart/cart_item.dart';

enum OrderStatus { active, completed, canceled }

class OrderModel {
  final String id;
  final List<CartItem> items;
  final DateTime createdAt;
  final OrderStatus status;

  const OrderModel({
    required this.id,
    required this.items,
    required this.createdAt,
    required this.status,
  });

  double get total => items.fold<double>(0, (sum, item) => sum + item.subtotal);

  OrderModel copyWith({
    List<CartItem>? items,
    DateTime? createdAt,
    OrderStatus? status,
  }) {
    return OrderModel(
      id: id,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}

class OrderService {
  OrderService._();

  static final OrderService instance = OrderService._();

  final ValueNotifier<List<OrderModel>> ordersNotifier =
      ValueNotifier<List<OrderModel>>(<OrderModel>[]);

  void placeOrder(List<CartItem> items) {
    if (items.isEmpty) return;
    final orders = List<OrderModel>.from(ordersNotifier.value);
    orders.insert(
      0,
      OrderModel(
        id: 'ord_${DateTime.now().microsecondsSinceEpoch}',
        items: List<CartItem>.from(items),
        createdAt: DateTime.now(),
        status: OrderStatus.active,
      ),
    );
    ordersNotifier.value = orders;
  }

  void cancelOrder(String orderId) {
    final orders = ordersNotifier.value
        .map((order) => order.id == orderId
            ? order.copyWith(status: OrderStatus.canceled)
            : order)
        .toList();
    ordersNotifier.value = orders;
  }
}
