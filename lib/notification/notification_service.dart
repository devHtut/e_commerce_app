import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AppNotificationAudience { customer, vendor }

class AppNotification {
  final String id;
  final AppNotificationAudience audience;
  final String title;
  final String message;
  final String type;
  final String? orderId;
  final DateTime createdAt;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.audience,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.orderId,
    this.readAt,
  });

  bool get isUnread => readAt == null;

  factory AppNotification.fromRow(Map<String, dynamic> row) {
    final audience = row['audience']?.toString().toLowerCase() == 'vendor'
        ? AppNotificationAudience.vendor
        : AppNotificationAudience.customer;
    final createdAtText = row['created_at']?.toString();
    final readAtText = row['read_at']?.toString();

    return AppNotification(
      id: row['id']?.toString() ?? '',
      audience: audience,
      title: row['title']?.toString() ?? 'Notification',
      message: row['message']?.toString() ?? '',
      type: row['type']?.toString() ?? 'general',
      orderId: row['order_id']?.toString(),
      createdAt: createdAtText != null
          ? DateTime.parse(createdAtText)
          : DateTime.now(),
      readAt: readAtText != null ? DateTime.parse(readAtText) : null,
    );
  }
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  SupabaseClient get _client => Supabase.instance.client;

  Future<void> createWelcomeNotification({
    required bool isVendor,
    String? userId,
  }) async {
    final recipientId = userId ?? _client.auth.currentUser?.id;
    if (recipientId == null || recipientId.isEmpty) return;

    await _insertNotification(
      recipientId: recipientId,
      audience: isVendor
          ? AppNotificationAudience.vendor
          : AppNotificationAudience.customer,
      title: isVendor ? 'Welcome back to your shop' : 'Welcome back',
      message: isVendor
          ? 'Your vendor dashboard is ready. Review new orders, products, and customer updates from here.'
          : 'Good to see you again. Your cart, wishlist, and order updates are waiting for you.',
      type: 'welcome',
    );
  }

  Future<void> notifyCartExpiryWarning({
    required String productName,
    required String variantInfo,
    required int daysLeft,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _insertNotification(
      recipientId: user.id,
      audience: AppNotificationAudience.customer,
      title: 'Cart item expires soon',
      message:
          'Your cart item "$productName" $variantInfo will be removed in $daysLeft day${daysLeft == 1 ? '' : 's'}. Purchase it before it expires.',
      type: 'cart_expiry_warning',
    );
  }

  Future<void> notifyCartItemRemovedFromCart({
    required String productName,
    required String variantInfo,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _insertNotification(
      recipientId: user.id,
      audience: AppNotificationAudience.customer,
      title: 'Cart item removed',
      message:
          'Your cart item "$productName" $variantInfo was removed after 30 days in your cart.',
      type: 'cart_item_removed',
    );
  }

  Future<List<AppNotification>> loadNotifications({
    AppNotificationAudience? audience,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return <AppNotification>[];

    var query = _client
        .from('notifications')
        .select('id,audience,title,message,type,order_id,created_at,read_at')
        .eq('recipient_id', user.id);

    if (audience != null) {
      query = query.eq('audience', _audienceValue(audience));
    }

    final rows = await query.order('created_at', ascending: false);
    final notifications = (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(AppNotification.fromRow)
        .toList();

    unreadCountNotifier.value = notifications
        .where((notification) => notification.isUnread)
        .length;
    return notifications;
  }

  Future<void> refreshUnreadCount({AppNotificationAudience? audience}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      unreadCountNotifier.value = 0;
      return;
    }

    var query = _client
        .from('notifications')
        .select('id')
        .eq('recipient_id', user.id)
        .filter('read_at', 'is', null);

    if (audience != null) {
      query = query.eq('audience', _audienceValue(audience));
    }

    final rows = await query;
    unreadCountNotifier.value = (rows as List<dynamic>).length;
  }

  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId);
  }

  Future<void> markAllAsRead({AppNotificationAudience? audience}) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    var query = _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('recipient_id', user.id)
        .filter('read_at', 'is', null);

    if (audience != null) {
      query = query.eq('audience', _audienceValue(audience));
    }

    await query;
    unreadCountNotifier.value = 0;
  }

  Future<void> notifyOrderPaymentSubmitted(String orderId) async {
    final context = await _loadOrderNotificationContext(orderId);
    if (context == null) return;

    await _notifyCustomerAndVendors(
      context: context,
      customerTitle: 'Payment submitted',
      customerMessage:
          'Order ${context.shortOrderId} was placed for ${context.itemSummary}. Total: \$${context.total.toStringAsFixed(2)}. The vendor will review your payment soon.',
      vendorTitle: 'New paid order',
      vendorMessage:
          '${context.customerName} paid for order ${context.shortOrderId}: ${context.itemSummary}. Total: \$${context.total.toStringAsFixed(2)}. Please review and confirm it.',
      type: 'order_payment_submitted',
    );
  }

  Future<void> notifyOrderStatusChanged(String orderId, String status) async {
    final context = await _loadOrderNotificationContext(orderId);
    if (context == null) return;

    final copy = _statusNotificationCopy(status, context);
    await _notifyCustomerAndVendors(
      context: context,
      customerTitle: copy.customerTitle,
      customerMessage: copy.customerMessage,
      vendorTitle: copy.vendorTitle,
      vendorMessage: copy.vendorMessage,
      type: copy.type,
    );
  }

  Future<void> _notifyCustomerAndVendors({
    required _OrderNotificationContext context,
    required String customerTitle,
    required String customerMessage,
    required String vendorTitle,
    required String vendorMessage,
    required String type,
  }) async {
    await _insertNotification(
      recipientId: context.customerId,
      audience: AppNotificationAudience.customer,
      title: customerTitle,
      message: customerMessage,
      type: type,
      orderId: context.orderId,
    );

    for (final vendorId in context.vendorOwnerIds) {
      await _insertNotification(
        recipientId: vendorId,
        audience: AppNotificationAudience.vendor,
        title: vendorTitle,
        message: vendorMessage,
        type: type,
        orderId: context.orderId,
      );
    }
  }

  _StatusNotificationCopy _statusNotificationCopy(
    String status,
    _OrderNotificationContext context,
  ) {
    switch (status) {
      case 'pending':
        return _StatusNotificationCopy(
          customerTitle: 'Order is pending',
          customerMessage:
              'Order ${context.shortOrderId} is waiting for vendor confirmation.',
          vendorTitle: 'Order is pending',
          vendorMessage:
              'Order ${context.shortOrderId} from ${context.customerName} is waiting for your review.',
          type: 'order_pending',
        );
      case 'confirmed':
        return _StatusNotificationCopy(
          customerTitle: 'Order confirmed',
          customerMessage:
              'Good news. The vendor confirmed order ${context.shortOrderId} for ${context.itemSummary}.',
          vendorTitle: 'Order confirmed',
          vendorMessage:
              'You confirmed order ${context.shortOrderId}. Prepare ${context.itemSummary} for delivery.',
          type: 'order_confirmed',
        );
      case 'inDelivery':
        return _StatusNotificationCopy(
          customerTitle: 'Order is on the way',
          customerMessage:
              'Order ${context.shortOrderId} is now in delivery. Keep an eye out for ${context.itemSummary}.',
          vendorTitle: 'Order sent to delivery',
          vendorMessage:
              'Order ${context.shortOrderId} for ${context.customerName} has moved to delivery.',
          type: 'order_in_delivery',
        );
      case 'completed':
        return _StatusNotificationCopy(
          customerTitle: 'Order completed',
          customerMessage:
              'Order ${context.shortOrderId} is marked completed. Thanks for shopping with us.',
          vendorTitle: 'Order completed',
          vendorMessage:
              '${context.customerName} completed order ${context.shortOrderId}.',
          type: 'order_completed',
        );
      case 'canceled':
        return _StatusNotificationCopy(
          customerTitle: 'Order canceled',
          customerMessage:
              'Order ${context.shortOrderId} was canceled. Reserved stock has been restored and refund handling can continue if needed.',
          vendorTitle: 'Order canceled',
          vendorMessage:
              'Order ${context.shortOrderId} from ${context.customerName} was canceled. Stock has been restored.',
          type: 'order_canceled',
        );
      case 'refund':
        return _StatusNotificationCopy(
          customerTitle: 'Refund completed',
          customerMessage:
              'Refund for order ${context.shortOrderId} has been marked completed.',
          vendorTitle: 'Refund completed',
          vendorMessage:
              'You marked the refund for order ${context.shortOrderId} as completed.',
          type: 'order_refund',
        );
    }

    return _StatusNotificationCopy(
      customerTitle: 'Order updated',
      customerMessage: 'Order ${context.shortOrderId} has a new update.',
      vendorTitle: 'Order updated',
      vendorMessage:
          'Order ${context.shortOrderId} from ${context.customerName} has a new update.',
      type: 'order_updated',
    );
  }

  Future<_OrderNotificationContext?> _loadOrderNotificationContext(
    String orderId,
  ) async {
    if (orderId.isEmpty) return null;

    // ⚠️ ပြင်ဆင်ချက်: readable_id ကို select လုပ်တဲ့အထဲ ထည့်ပေါင်းထားပါတယ်
    final row = await _client
        .from('orders')
        .select(
          'id,readable_id,customer_id,total_price,order_items(quantity,brand_id,product_variants(products(title)))',
        )
        .eq('id', orderId)
        .maybeSingle();

    if (row == null) return null;

    final customerId = row['customer_id']?.toString();
    if (customerId == null || customerId.isEmpty) return null;

    // ⚠️ ပြင်ဆင်ချက်: DB ထဲက readable_id ကို ယူပါတယ် (မရှိရင်သာ သာမန် orderId ကိုသုံးပါတယ်)
    final readableId = row['readable_id']?.toString() ?? orderId;

    final orderItems = row['order_items'] as List<dynamic>? ?? const [];
    final itemNames = <String>[];
    var itemCount = 0;
    final brandIds = <String>{};

    for (final item in orderItems.cast<Map<String, dynamic>>()) {
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      itemCount += quantity;
      final brandId = item['brand_id']?.toString();
      if (brandId != null && brandId.isNotEmpty) brandIds.add(brandId);

      final variant = item['product_variants'] as Map<String, dynamic>?;
      final product = variant?['products'] as Map<String, dynamic>?;
      final name = product?['title']?.toString();
      if (name != null && name.trim().isNotEmpty) itemNames.add(name.trim());
    }

    final vendorOwnerIds = await _loadVendorOwnerIds(brandIds);
    final profile = await _client
        .from('profiles')
        .select('full_name')
        .eq('id', customerId)
        .maybeSingle();
    final customerName = profile?['full_name']?.toString().trim();

    return _OrderNotificationContext(
      orderId: orderId,
      customerId: customerId,
      customerName: customerName == null || customerName.isEmpty
          ? 'Customer'
          : customerName,
      vendorOwnerIds: vendorOwnerIds,
      total: (row['total_price'] as num?)?.toDouble() ?? 0.0,
      itemSummary: _buildItemSummary(itemNames, itemCount),
      readableId:
          readableId, // ⚠️ ပြင်ဆင်ချက်: '' (အလွတ်) အစား readableId အစစ်ကို ထည့်ပေးလိုက်ပါတယ်
    );
  }

  Future<Set<String>> _loadVendorOwnerIds(Set<String> brandIds) async {
    if (brandIds.isEmpty) return <String>{};

    final rows = await _client
        .from('brands')
        .select('owner_id')
        .filter('id', 'in', brandIds.toList());

    return (rows as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((row) => row['owner_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  String _buildItemSummary(List<String> itemNames, int itemCount) {
    final countLabel = itemCount <= 1 ? '1 item' : '$itemCount items';
    if (itemNames.isEmpty) return countLabel;

    final first = itemNames.first;
    final extra = itemNames.length - 1;
    return extra > 0
        ? '$first + $extra more ($countLabel)'
        : '$first ($countLabel)';
  }

  Future<void> _insertNotification({
    required String recipientId,
    required AppNotificationAudience audience,
    required String title,
    required String message,
    required String type,
    String? orderId,
  }) async {
    try {
      await _client.from('notifications').insert({
        'recipient_id': recipientId,
        'audience': _audienceValue(audience),
        'title': title,
        'message': message,
        'type': type,
        'order_id': orderId,
        'actor_id': _client.auth.currentUser?.id,
      });

      if (recipientId == _client.auth.currentUser?.id) {
        unreadCountNotifier.value = unreadCountNotifier.value + 1;
      }
    } catch (e) {
      debugPrint('Unable to create notification: $e');
    }
  }

  String _audienceValue(AppNotificationAudience audience) {
    return switch (audience) {
      AppNotificationAudience.customer => 'customer',
      AppNotificationAudience.vendor => 'vendor',
    };
  }
}

class _OrderNotificationContext {
  final String orderId;
  final String readableId;
  final String customerId;
  final String customerName;
  final Set<String> vendorOwnerIds;
  final double total;
  final String itemSummary;

  const _OrderNotificationContext({
    required this.orderId,
    required this.readableId,
    required this.customerId,
    required this.customerName,
    required this.vendorOwnerIds,
    required this.total,
    required this.itemSummary,
  });

  String get shortOrderId => '#$readableId';
}

class _StatusNotificationCopy {
  final String customerTitle;
  final String customerMessage;
  final String vendorTitle;
  final String vendorMessage;
  final String type;

  const _StatusNotificationCopy({
    required this.customerTitle,
    required this.customerMessage,
    required this.vendorTitle,
    required this.vendorMessage,
    required this.type,
  });
}
