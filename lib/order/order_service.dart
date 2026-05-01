import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cart/cart_item.dart';
import '../notification/notification_service.dart';
import '../product/product_model.dart';

enum OrderStatus { pending, confirmed, inDelivery, completed, canceled, refund }

class OrderStatusHistoryEntry {
  final OrderStatus status;
  final DateTime changedAt;

  const OrderStatusHistoryEntry({
    required this.status,
    required this.changedAt,
  });
}

class OrderPaymentDetails {
  final String id;
  final String paymentMethod;
  final String status;
  final String transactionId;
  final double amount;
  final String screenshotUrl;

  const OrderPaymentDetails({
    required this.id,
    required this.paymentMethod,
    required this.status,
    required this.transactionId,
    required this.amount,
    required this.screenshotUrl,
  });
}

class OrderModel {
  final String id;
  final List<CartItem> items;
  final DateTime createdAt;
  final OrderStatus status;
  final String shippingAddressLabel;
  final String shippingAddressRecipient;
  final String shippingAddressPhone;
  final String shippingAddressStreet;
  final OrderPaymentDetails? payment;
  final List<OrderStatusHistoryEntry> statusHistory;

  const OrderModel({
    required this.id,
    required this.items,
    required this.createdAt,
    required this.status,
    required this.shippingAddressLabel,
    required this.shippingAddressRecipient,
    required this.shippingAddressPhone,
    required this.shippingAddressStreet,
    this.payment,
    this.statusHistory = const [],
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
    OrderPaymentDetails? payment,
    List<OrderStatusHistoryEntry>? statusHistory,
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
      payment: payment ?? this.payment,
      statusHistory: statusHistory ?? this.statusHistory,
    );
  }
}

class OrderService {
  OrderService._();

  static final OrderService instance = OrderService._();

  final ValueNotifier<List<OrderModel>> ordersNotifier =
      ValueNotifier<List<OrderModel>>(<OrderModel>[]);

  static const String _orderSelect = '''
            id,
            customer_id,
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
          ''';

  Future<void> loadOrders() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final orderRows = await Supabase.instance.client
          .from('orders')
          .select(_orderSelect)
          .eq('customer_id', user.id)
          .order('created_at', ascending: false);

      final orders = await _buildOrders(orderRows, includePaymentDetails: true);
      ordersNotifier.value = await _completeOverdueInDeliveryOrders(orders);
    } catch (e) {
      // Handle error silently or log it
      debugPrint('Error loading orders: $e');
    }
  }

  Future<List<OrderModel>> loadVendorOrders() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return <OrderModel>[];

    try {
      final brandRows = await Supabase.instance.client
          .from('brands')
          .select('id')
          .eq('owner_id', user.id);
      final brandIds = (brandRows as List<dynamic>)
          .map((row) => (row as Map<String, dynamic>)['id']?.toString())
          .whereType<String>()
          .toSet();

      if (brandIds.isEmpty) return <OrderModel>[];

      final orderRows = await Supabase.instance.client
          .from('orders')
          .select(_orderSelect)
          .order('created_at', ascending: false);

      final orders = await _buildOrders(
        orderRows,
        allowedBrandIds: brandIds,
        includePaymentDetails: true,
      );
      return _completeOverdueInDeliveryOrders(orders);
    } catch (e) {
      debugPrint('Error loading vendor orders: $e');
      return <OrderModel>[];
    }
  }

  Future<List<OrderModel>> _buildOrders(
    List<dynamic> orderRows, {
    Set<String>? allowedBrandIds,
    bool includePaymentDetails = false,
  }) async {
    final shippingAddressIds = orderRows
        .map((row) => row['shipping_address_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    final customerIds = orderRows
        .map((row) => row['customer_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();
    final orderIds = orderRows
        .map((row) => row['id']?.toString())
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

    final profileMap = <String, Map<String, dynamic>>{};
    if (customerIds.isNotEmpty) {
      final profileRows = await Supabase.instance.client
          .from('profiles')
          .select('id,full_name')
          .filter('id', 'in', customerIds);

      for (final profileRow in profileRows as List<dynamic>) {
        final id = profileRow['id']?.toString();
        if (id == null) continue;
        profileMap[id] = profileRow as Map<String, dynamic>;
      }
    }

    final paymentMap = <String, OrderPaymentDetails>{};
    if (includePaymentDetails && orderIds.isNotEmpty) {
      final paymentRows = await Supabase.instance.client
          .from('payments')
          .select(
            'id,order_id,payment_method,status,transaction_id,amount,screenshot_url',
          )
          .filter('order_id', 'in', orderIds);

      for (final paymentRow in paymentRows as List<dynamic>) {
        final orderId = paymentRow['order_id']?.toString();
        if (orderId == null || paymentMap.containsKey(orderId)) continue;
        paymentMap[orderId] = OrderPaymentDetails(
          id: paymentRow['id']?.toString() ?? '',
          paymentMethod: paymentRow['payment_method']?.toString() ?? '',
          status: paymentRow['status']?.toString() ?? '',
          transactionId: paymentRow['transaction_id']?.toString() ?? '',
          amount: (paymentRow['amount'] as num?)?.toDouble() ?? 0.0,
          screenshotUrl: paymentRow['screenshot_url']?.toString() ?? '',
        );
      }
    }

    final historyMap = await _loadStatusHistory(orderIds);

    final orders = <OrderModel>[];
    for (final orderRow in orderRows) {
      final orderId = orderRow['id']?.toString() ?? '';
      final customerId = orderRow['customer_id']?.toString();
      final statusString = orderRow['status']?.toString() ?? 'pending';
      final createdAtString = orderRow['created_at']?.toString();
      final createdAt = createdAtString != null
          ? DateTime.parse(createdAtString)
          : DateTime.now();
      final shippingAddressId = orderRow['shipping_address_id']?.toString();

      final status = _statusFromDatabaseValue(statusString);

      final items = <CartItem>[];
      final orderItems = orderRow['order_items'] as List<dynamic>? ?? [];

      for (final itemRow in orderItems) {
        final quantity = itemRow['quantity'] as int? ?? 1;
        final priceAtPurchase =
            (itemRow['price_at_purchase'] as num?)?.toDouble() ?? 0.0;

        final variantRow = itemRow['product_variants'] as Map<String, dynamic>?;
        if (variantRow == null) continue;

        final productRow = variantRow['products'] as Map<String, dynamic>?;
        if (productRow == null) continue;

        final categoryRow = productRow['categories'] as Map<String, dynamic>?;
        final brandRow = productRow['brands'] as Map<String, dynamic>?;
        final brandId = brandRow?['id']?.toString() ?? '';

        if (allowedBrandIds != null && !allowedBrandIds.contains(brandId)) {
          continue;
        }

        final product = ProductModel(
          id: productRow['id']?.toString() ?? '',
          name: productRow['title']?.toString() ?? '',
          description: productRow['description']?.toString() ?? '',
          price: priceAtPurchase,
          category: categoryRow?['name']?.toString() ?? '',
          brand: brandRow?['brand_name']?.toString() ?? '',
          brandId: brandId,
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
      final profileData = customerId != null ? profileMap[customerId] : null;
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
                profileData?['full_name']?.toString() ?? '',
            shippingAddressPhone:
                shippingData?['phone_number']?.toString() ?? '',
            shippingAddressStreet: '$street${city.isNotEmpty ? ', $city' : ''}',
            payment: paymentMap[orderId],
            statusHistory: historyMap[orderId] ?? const [],
          ),
        );
      }
    }

    return orders;
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final previousStatus = await _loadOrderStatus(orderId);

    await Supabase.instance.client
        .from('orders')
        .update({'status': _statusToDatabaseValue(status)})
        .eq('id', orderId);

    if (status == OrderStatus.canceled &&
        previousStatus != OrderStatus.canceled &&
        previousStatus != OrderStatus.refund) {
      await restoreStockForOrder(orderId);
    }

    if (previousStatus != status) {
      await NotificationService.instance.notifyOrderStatusChanged(
        orderId,
        status.name,
      );
    }

    final orders = ordersNotifier.value
        .map(
          (order) => order.id == orderId
              ? order.copyWith(
                  status: status,
                  statusHistory: [
                    ...order.statusHistory,
                    OrderStatusHistoryEntry(
                      status: status,
                      changedAt: DateTime.now(),
                    ),
                  ],
                )
              : order,
        )
        .toList();
    ordersNotifier.value = orders;
  }

  Future<void> reserveStockForOrder(String orderId) async {
    if (orderId.isEmpty) return;

    try {
      await Supabase.instance.client.rpc(
        'reserve_order_stock',
        params: {'p_order_id': orderId},
      );
      return;
    } catch (e) {
      if (!_isMissingStockRpc(e)) rethrow;
      debugPrint('Stock reservation RPC unavailable: $e');
    }

    final items = await _loadOrderStockItems(orderId);
    await _adjustVariantStock(items, reserve: true);
  }

  Future<void> restoreStockForOrder(String orderId) async {
    if (orderId.isEmpty) return;

    try {
      await Supabase.instance.client.rpc(
        'restore_order_stock',
        params: {'p_order_id': orderId},
      );
      return;
    } catch (e) {
      if (!_isMissingStockRpc(e)) rethrow;
      debugPrint('Stock restore RPC unavailable: $e');
    }

    final items = await _loadOrderStockItems(orderId);
    await _adjustVariantStock(items, reserve: false);
  }

  bool _isMissingStockRpc(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('pgrst202') ||
        message.contains('could not find') ||
        message.contains('schema cache') ||
        message.contains('function') && message.contains('not found');
  }

  Future<OrderStatus> _loadOrderStatus(String orderId) async {
    final cached = ordersNotifier.value.where((order) => order.id == orderId);
    if (cached.isNotEmpty) return cached.first.status;

    try {
      final row = await Supabase.instance.client
          .from('orders')
          .select('status')
          .eq('id', orderId)
          .single();
      return _statusFromDatabaseValue(row['status']?.toString() ?? '');
    } catch (e) {
      debugPrint('Error loading order status: $e');
      return OrderStatus.pending;
    }
  }

  Future<Map<String, int>> _loadOrderStockItems(String orderId) async {
    final rows = await Supabase.instance.client
        .from('order_items')
        .select('product_variant_id,quantity')
        .eq('order_id', orderId);

    final items = <String, int>{};
    for (final row in rows as List<dynamic>) {
      final variantId = row['product_variant_id']?.toString();
      if (variantId == null || variantId.isEmpty) continue;
      final quantity = (row['quantity'] as num?)?.toInt() ?? 0;
      if (quantity <= 0) continue;
      items[variantId] = (items[variantId] ?? 0) + quantity;
    }
    return items;
  }

  Future<void> _adjustVariantStock(
    Map<String, int> items, {
    required bool reserve,
  }) async {
    for (final entry in items.entries) {
      final row = await Supabase.instance.client
          .from('product_variants')
          .select('stock_quantity')
          .eq('id', entry.key)
          .single();
      final currentStock = (row['stock_quantity'] as num?)?.toInt() ?? 0;
      final nextStock = reserve
          ? currentStock - entry.value
          : currentStock + entry.value;
      if (nextStock < 0) {
        throw Exception('Not enough stock available for this product.');
      }

      await Supabase.instance.client
          .from('product_variants')
          .update({'stock_quantity': nextStock})
          .eq('id', entry.key);
    }
  }

  String _statusToDatabaseValue(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.inDelivery:
        return 'in-delivery';
      case OrderStatus.completed:
        return 'completed';
      case OrderStatus.canceled:
        return 'cancel';
      case OrderStatus.refund:
        return 'refund';
    }
  }

  OrderStatus _statusFromDatabaseValue(String value) {
    switch (value.trim().toLowerCase()) {
      case 'in-delivery':
      case 'in_delivery':
      case 'in delivery':
        return OrderStatus.inDelivery;
      case 'confirmed':
      case 'confirm':
        return OrderStatus.confirmed;
      case 'arrived':
      case 'delivered':
      case 'completed':
        return OrderStatus.completed;
      case 'cancel':
      case 'canceled':
      case 'cancelled':
        return OrderStatus.canceled;
      case 'refund':
      case 'refunded':
        return OrderStatus.refund;
      default:
        return OrderStatus.pending;
    }
  }

  Future<Map<String, List<OrderStatusHistoryEntry>>> _loadStatusHistory(
    List<String> orderIds,
  ) async {
    final historyMap = <String, List<OrderStatusHistoryEntry>>{};
    if (orderIds.isEmpty) return historyMap;

    try {
      final rows = await Supabase.instance.client
          .from('order_status_history')
          .select('order_id,status,changed_at')
          .filter('order_id', 'in', orderIds)
          .order('changed_at', ascending: true);

      for (final row in rows as List<dynamic>) {
        final orderId = row['order_id']?.toString();
        final changedAtString = row['changed_at']?.toString();
        if (orderId == null || changedAtString == null) continue;
        final entry = OrderStatusHistoryEntry(
          status: _statusFromDatabaseValue(row['status']?.toString() ?? ''),
          changedAt: DateTime.parse(changedAtString),
        );
        historyMap.putIfAbsent(orderId, () => []).add(entry);
      }
    } catch (e) {
      debugPrint('Error loading order status history: $e');
    }

    return historyMap;
  }

  void placeOrder(
    List<CartItem> items, {
    String? orderId,
    OrderStatus status = OrderStatus.pending,
    String shippingAddressLabel = '',
    String shippingAddressRecipient = '',
    String shippingAddressPhone = '',
    String shippingAddressStreet = '',
    OrderPaymentDetails? payment,
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
        payment: payment,
        statusHistory: [
          OrderStatusHistoryEntry(status: status, changedAt: DateTime.now()),
        ],
      ),
    );
    ordersNotifier.value = orders;
  }

  Future<void> cancelOrder(String orderId) {
    return updateOrderStatus(orderId, OrderStatus.canceled);
  }

  Future<List<OrderModel>> _completeOverdueInDeliveryOrders(
    List<OrderModel> orders,
  ) async {
    final now = DateTime.now();
    final updatedOrders = <OrderModel>[];

    for (final order in orders) {
      if (order.status != OrderStatus.inDelivery) {
        updatedOrders.add(order);
        continue;
      }

      final inDeliveryAt = order.statusHistory
          .where((entry) => entry.status == OrderStatus.inDelivery)
          .map((entry) => entry.changedAt)
          .fold<DateTime?>(null, (latest, changedAt) {
            if (latest == null || changedAt.isAfter(latest)) return changedAt;
            return latest;
          });

      if (inDeliveryAt == null ||
          now.difference(inDeliveryAt) < const Duration(days: 10)) {
        updatedOrders.add(order);
        continue;
      }

      await updateOrderStatus(order.id, OrderStatus.completed);
      updatedOrders.add(
        order.copyWith(
          status: OrderStatus.completed,
          statusHistory: [
            ...order.statusHistory,
            OrderStatusHistoryEntry(
              status: OrderStatus.completed,
              changedAt: now,
            ),
          ],
        ),
      );
    }

    return updatedOrders;
  }
}
