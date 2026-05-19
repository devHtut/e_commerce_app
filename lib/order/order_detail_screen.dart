import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../cart/cart_item.dart';
import '../chat/chat_service.dart';
import '../customer/chat_screen.dart';
import '../product/product_review_service.dart';
import '../theme_config.dart';
import '../widgets/custom_loading_state.dart';
import '../widgets/copy_pill_button.dart';
import '../widgets/price_formatter.dart';
import 'order_service.dart';
import 'receipt_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;
  final bool isVendorView;
  final ValueChanged<OrderModel>? onOrderUpdated;

  const OrderDetailScreen({
    super.key,
    required this.order,
    this.isVendorView = false,
    this.onOrderUpdated,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  int _tabIndex = 0; // 0 => details, 1 => track
  late OrderModel _order;
  bool _savingStatus = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.darkText),
        centerTitle: true,
        title: const Text(
          'Order Details',
          style: TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        // actions: const [
        //   Padding(
        //     padding: EdgeInsets.only(right: 12),
        //     child: Icon(Icons.more_vert, color: AppColors.darkText),
        //   ),
        // ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 6),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _topTab(
                  label: 'Order Details',
                  selected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                _topTab(
                  label: 'Track Order',
                  selected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _tabIndex == 0 ? _buildOrderDetails() : _buildTrackOrder(),
          ),
        ],
      ),
    );
  }

  Widget _topTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.darkText,
              fontFamily: AppFonts.primary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderDetails() {
    final subtotal = _order.total;
    final promo = 0.00;
    final total = subtotal - promo;
    final brandNames = _order.items
        .map((item) => item.product.brand)
        .where((brand) => brand.trim().isNotEmpty)
        .toSet()
        .join(', ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        _detailSection(
          title: 'Delivery Address',
          child: _buildDeliveryAddressDetails(),
        ),
        const SizedBox(height: 10),
        _buildStatusPanel(),
        const SizedBox(height: 10),
        _detailSection(
          title: 'Your Order (${_order.items.length})',
          child: Column(
            children: [
              for (final item in _order.items) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        item.imageUrl,
                        width: 78,
                        height: 92,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: const TextStyle(
                              color: AppColors.darkText,
                              fontFamily: AppFonts.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Size: ${item.size}',
                            style: const TextStyle(
                              color: AppColors.subtleText,
                              fontFamily: AppFonts.primary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Color: ${item.colorName}',
                            style: const TextStyle(
                              color: AppColors.subtleText,
                              fontFamily: AppFonts.primary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Qty: ${item.quantity}',
                            style: const TextStyle(
                              color: AppColors.subtleText,
                              fontFamily: AppFonts.primary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatKyat(item.subtotal),
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontFamily: AppFonts.primary,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!widget.isVendorView &&
                              _order.status == OrderStatus.completed) ...[
                            const SizedBox(height: 8),
                            _ReviewActionButton(
                              order: _order,
                              item: item,
                              onSubmitted: () {
                                if (mounted) setState(() {});
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _detailSection(
          title: 'Review Summary',
          child: Column(
            children: [
              _summaryRow(
                'Subtotal (${_order.items.length} items)',
                formatKyat(subtotal),
              ),
              _summaryRow('Promo', formatDiscountKyat(promo)),
              const Divider(),
              _summaryRow('Total Payment', formatKyat(total), isTotal: true),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _detailSection(
          title: 'Information Details',
          child: Column(
            children: [
              _summaryRow(
                'Order ID',
                _order.readableId,
                trailing: CopyPillButton(
                  onPressed: _copyReadableOrderId,
                ),
              ),
              if (brandNames.isNotEmpty) _summaryRow('Brand', brandNames),
              if (_order.shippingAddressRecipient.isNotEmpty)
                _summaryRow('Customer', _order.shippingAddressRecipient),
              _summaryRow(
                'Purchase Date',
                '${_order.createdAt.day}/${_order.createdAt.month}/${_order.createdAt.year}',
              ),
              _summaryRow('Purchase Time', _formatOrderTime(_order.createdAt)),
              // if (_order.shippingAddressPhone.isNotEmpty)
              //   _summaryRow(
              //     'Contact',
              //     _order.shippingAddressPhone,
              //     trailing: widget.isVendorView
              //         ? CopyPillButton(
              //             onPressed: () => _copyText(
              //               _order.shippingAddressPhone,
              //               'Phone number copied.',
              //             ),
              //           )
              //         : null,
              //   ),
              // if (widget.isVendorView &&
              //     _order.shippingAddressStreet.isNotEmpty)
              //   _summaryRow(
              //     'Delivery Address',
              //     _order.shippingAddressStreet,
              //     trailing: CopyPillButton(
              //       onPressed: () => _copyText(
              //         _order.shippingAddressStreet,
              //         'Delivery address copied.',
              //       ),
              //     ),
              //   ),
              if (widget.isVendorView) ...[
                const SizedBox(height: 10),
                _buildCustomerMessageButton(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildPaymentDetails(),
        if (widget.isVendorView) ...[
          const SizedBox(height: 14),
          _buildVendorStatusActions(),
        ] else if (_order.status == OrderStatus.inDelivery) ...[
          const SizedBox(height: 14),
          _buildCustomerStatusActions(),
        ],
        if (_order.status != OrderStatus.pending) ...[
          const SizedBox(height: 16),
          _buildGenerateReceiptButton(),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildGenerateReceiptButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openReceiptScreen,
        icon: const Icon(
          Icons.receipt_long_outlined,
          color: AppColors.darkText,
        ),
        label: const Text(
          'Generate Receipt',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
            color: AppColors.darkText,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.primaryGreen),
          foregroundColor: AppColors.darkText,
        ),
      ),
    );
  }

  void _openReceiptScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceiptScreen(order: _order)),
    );
  }

  Future<void> _copyReadableOrderId() async {
    await _copyText(_order.readableId, 'Order ID copied.');
  }

  Future<void> _copyText(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  Widget _buildCustomerMessageButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _order.customerId.isEmpty ? null : _openCustomerChat,
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: const Text(
          'Send Message to Customer',
          style: TextStyle(
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          foregroundColor: AppColors.primaryGreen,
          side: const BorderSide(color: AppColors.primaryGreen),
        ),
      ),
    );
  }

  Future<void> _openCustomerChat() async {
    if (_order.customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer contact is unavailable.')),
      );
      return;
    }

    try {
      final customerName = _order.shippingAddressRecipient.trim();
      final chat = await ChatService.instance.createOrGetDirectChat(
        ChatStartOption(
          userId: _order.customerId,
          title: customerName.isEmpty ? 'Customer' : customerName,
          subtitle: 'Customer - Order ${_order.readableId}',
        ),
      );
      if (!mounted || chat == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatScreen(initialChatId: chat.id)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start customer chat.')),
      );
    }
  }

  Widget _buildDeliveryAddressDetails() {
    final label = _order.shippingAddressLabel.isNotEmpty
        ? _order.shippingAddressLabel
        : 'Delivery Address';
    final address = _order.shippingAddressStreet.isNotEmpty
        ? _order.shippingAddressStreet
        : 'Delivery address not available';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.primaryGreen,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.location_on, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                address,
                style: const TextStyle(
                  color: AppColors.subtleText,
                  fontFamily: AppFonts.primary,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              if (widget.isVendorView &&
                  _order.shippingAddressStreet.isNotEmpty) ...[
                const SizedBox(height: 8),
                CopyPillButton(
                  onPressed: () => _copyText(
                    _order.shippingAddressStreet,
                    'Delivery address copied.',
                  ),
                ),
              ],
              if (_order.shippingAddressPhone.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _order.shippingAddressPhone,
                        style: const TextStyle(
                          color: AppColors.subtleText,
                          fontFamily: AppFonts.primary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.isVendorView) ...[
                      const SizedBox(width: 8),
                      CopyPillButton(
                        onPressed: () => _copyText(
                          _order.shippingAddressPhone,
                          'Phone number copied.',
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPanel() {
    final averageDeliveryDate = _averageDeliveryDate;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _orderStatusBackgroundColor(_order.status),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusChip(_order.status),
          if (averageDeliveryDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  color: _orderStatusColor(_order.status),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Average delivery date: '
                    '${_formatOrderDate(averageDeliveryDate)}',
                    style: TextStyle(
                      color: _orderStatusColor(_order.status),
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    return Row(
      children: [
        Icon(Icons.info_outline, color: _orderStatusColor(status), size: 18),
        const SizedBox(width: 8),
        Text(
          _orderStatusLabel(status),
          style: TextStyle(
            color: _orderStatusColor(status),
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildVendorStatusActions() {
    final primaryStatus = switch (_order.status) {
      OrderStatus.pending => OrderStatus.confirmed,
      OrderStatus.confirmed => OrderStatus.inDelivery,
      OrderStatus.canceled => OrderStatus.refund,
      _ => null,
    };
    final primaryLabel = switch (_order.status) {
      OrderStatus.pending => 'Confirm',
      OrderStatus.confirmed => 'In Delivery',
      OrderStatus.canceled => 'Refund',
      _ => 'Confirm',
    };
    final canCancel =
        _order.status == OrderStatus.pending ||
        _order.status == OrderStatus.confirmed;

    if (primaryStatus == null && !canCancel) {
      return const SizedBox.shrink();
    }

    if (_order.status == OrderStatus.canceled) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: !_savingStatus
              ? () => _confirmAndSaveStatus(OrderStatus.refund)
              : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: AppColors.primaryGreen,
            disabledBackgroundColor: Colors.grey.shade300,
            elevation: 0,
          ),
          child: _buildStatusButtonChild('Refund'),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: canCancel && !_savingStatus
                ? () => _confirmAndSaveStatus(OrderStatus.canceled)
                : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              side: const BorderSide(color: AppColors.errorRed),
              foregroundColor: AppColors.errorRed,
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: primaryStatus != null && !_savingStatus
                ? () => _confirmAndSaveStatus(primaryStatus)
                : null,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: AppColors.primaryGreen,
              disabledBackgroundColor: Colors.grey.shade300,
              elevation: 0,
            ),
            child: _buildStatusButtonChild(primaryLabel),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerStatusActions() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: !_savingStatus
            ? () => _confirmAndSaveStatus(OrderStatus.completed)
            : null,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: AppColors.primaryGreen,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 0,
        ),
        child: _buildStatusButtonChild('Arrived'),
      ),
    );
  }

  Widget _buildStatusButtonChild(String label) {
    if (_savingStatus) {
      return const SizedBox(
        width: 72,
        height: 36,
        child: ButtonLoadingDots(),
      );
    }

    return Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: AppFonts.primary,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Future<void> _confirmAndSaveStatus(OrderStatus newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Update Order Status',
          style: TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          _statusConfirmationMessage(newStatus),
          style: const TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _orderStatusColor(newStatus),
            ),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _savingStatus = true);
    try {
      await OrderService.instance.updateOrderStatus(_order.id, newStatus);
      final updated = _order.copyWith(
        status: newStatus,
        statusHistory: [
          ..._order.statusHistory,
          OrderStatusHistoryEntry(status: newStatus, changedAt: DateTime.now()),
        ],
      );
      if (!mounted) return;
      setState(() {
        _order = updated;
        _savingStatus = false;
      });
      widget.onOrderUpdated?.call(updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Order status updated.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update order status.')),
      );
    }
  }

  String _statusConfirmationMessage(OrderStatus newStatus) {
    switch (newStatus) {
      case OrderStatus.confirmed:
        return 'Confirm this order? Customer cancellation will close after this.';
      case OrderStatus.inDelivery:
        return 'Send this confirmed order to delivery?';
      case OrderStatus.completed:
        return 'Mark this order as arrived and completed?';
      case OrderStatus.canceled:
        return 'Cancel this order?';
      case OrderStatus.refund:
        return 'Mark the refund as completed?';
      case OrderStatus.pending:
        return 'Move this order back to pending?';
    }
  }

  Widget _buildPaymentDetails() {
    final payment = _order.payment;
    if (payment == null) {
      return _detailSection(
        title: 'Payment Details',
        child: const Text(
          'No payment details found for this order.',
          style: AppTextStyles.body,
        ),
      );
    }

    return _detailSection(
      title: 'Payment Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow('Method', payment.paymentMethod),
          _summaryRow('Status', payment.status.toUpperCase()),
          _summaryRow('Transaction ID', payment.transactionId),
          _summaryRow('Amount', formatKyat(payment.amount)),
          const SizedBox(height: 10),
          const Text(
            'Payment Screenshot',
            style: TextStyle(
              color: AppColors.darkText,
              fontFamily: AppFonts.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (payment.screenshotUrl.isEmpty)
            const Text('No screenshot uploaded.', style: AppTextStyles.body)
          else
            GestureDetector(
              onTap: () => _showPaymentScreenshot(payment.screenshotUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  payment.screenshotUrl,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPaymentScreenshot(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackOrder() {
    final title = switch (_order.status) {
      OrderStatus.pending => 'Awaiting Confirmation',
      OrderStatus.confirmed => 'Order Confirmed',
      OrderStatus.inDelivery => 'Order in Delivery',
      OrderStatus.completed => 'Order Completed',
      OrderStatus.canceled => 'Order Canceled',
      OrderStatus.refund => 'Order Refunded',
    };
    final history = _order.statusHistory.isEmpty
        ? [
            OrderStatusHistoryEntry(
              status: _order.status,
              changedAt: _order.createdAt,
            ),
          ]
        : _order.statusHistory;
    final trackingEvents = _trackTimelineEvents(history);
    final progressStatuses = _trackProgressStatuses(history);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: progressStatuses.map((status) {
                  final active = _trackStepActive(status);
                  return Icon(
                    _trackStatusIcon(status),
                    color: active ? _orderStatusColor(status) : Colors.grey,
                    size: 36,
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              Row(
                children: progressStatuses.asMap().entries.map((entry) {
                  final status = entry.value;
                  return Expanded(
                    child: _TrackDot(
                      active: _trackStepActive(status),
                      color: _orderStatusColor(status),
                      showTail: entry.key != progressStatuses.length - 1,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w500,
                  fontSize: 30,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status History',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...trackingEvents.asMap().entries.map((entry) {
                final i = entry.key;
                final e = entry.value;
                return _TrackTimelineRow(
                  event: e,
                  showTail: i != trackingEvents.length - 1,
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Color _orderStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.amber.shade900;
      case OrderStatus.confirmed:
        return Colors.teal.shade700;
      case OrderStatus.inDelivery:
        return Colors.blue.shade700;
      case OrderStatus.completed:
        return AppColors.primaryGreen;
      case OrderStatus.canceled:
        return AppColors.errorRed;
      case OrderStatus.refund:
        return Colors.deepOrange.shade800;
    }
  }

  Color _orderStatusBackgroundColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.amber.shade50;
      case OrderStatus.confirmed:
        return Colors.teal.shade50;
      case OrderStatus.inDelivery:
        return Colors.blue.shade50;
      case OrderStatus.completed:
        return AppColors.primaryGreen.withValues(alpha: 0.12);
      case OrderStatus.canceled:
        return AppColors.errorRed.withValues(alpha: 0.12);
      case OrderStatus.refund:
        return Colors.deepOrange.shade50;
    }
  }

  String _orderStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'PENDING';
      case OrderStatus.confirmed:
        return 'CONFIRMED';
      case OrderStatus.inDelivery:
        return 'IN-DELIVERY';
      case OrderStatus.completed:
        return 'COMPLETED';
      case OrderStatus.canceled:
        return 'CANCELED';
      case OrderStatus.refund:
        return 'REFUND';
    }
  }

  String _statusTimelineTitle(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Payment submitted';
      case OrderStatus.confirmed:
        return 'Order confirmed';
      case OrderStatus.inDelivery:
        return 'Order sent to delivery service';
      case OrderStatus.completed:
        return 'Order completed';
      case OrderStatus.canceled:
        return 'Order canceled';
      case OrderStatus.refund:
        return 'Refund requested';
    }
  }

  String _statusTimelineLocation(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Waiting for vendor confirmation';
      case OrderStatus.confirmed:
        return 'Vendor confirmed the order';
      case OrderStatus.inDelivery:
        return 'Package handed to delivery service';
      case OrderStatus.completed:
        return 'Customer received the order';
      case OrderStatus.canceled:
        return 'Waiting for vendor refund';
      case OrderStatus.refund:
        return 'Refund completed';
    }
  }

  String _formatOrderTime(DateTime date) {
    final localDate = date.toLocal();
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatOrderDate(DateTime date) {
    final localDate = date.toLocal();
    final day = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    return '$day.$month.${localDate.year}';
  }

  DateTime? get _averageDeliveryDate {
    if (_order.status != OrderStatus.inDelivery) return null;

    final inDeliveryAt = _order.statusHistory
        .where((entry) => entry.status == OrderStatus.inDelivery)
        .map((entry) => entry.changedAt)
        .fold<DateTime?>(null, (latest, changedAt) {
          if (latest == null || changedAt.isAfter(latest)) return changedAt;
          return latest;
        });

    return (inDeliveryAt ?? DateTime.now()).add(const Duration(days: 4));
  }

  bool _trackStepActive(OrderStatus status) {
    if (status == OrderStatus.canceled || status == OrderStatus.refund) {
      return _order.status == status;
    }

    final current = _statusRank(_order.status);
    return current >= _statusRank(status);
  }

  IconData _trackStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.inventory_2;
      case OrderStatus.confirmed:
        return Icons.verified_outlined;
      case OrderStatus.inDelivery:
        return Icons.local_shipping;
      case OrderStatus.completed:
        return Icons.handshake;
      case OrderStatus.canceled:
        return Icons.cancel_outlined;
      case OrderStatus.refund:
        return Icons.payments_outlined;
    }
  }

  List<OrderStatus> _trackProgressStatuses(
    List<OrderStatusHistoryEntry> history,
  ) {
    final statuses = <OrderStatus>[
      OrderStatus.pending,
      OrderStatus.confirmed,
      OrderStatus.inDelivery,
      OrderStatus.completed,
    ];
    final historyStatuses = history.map((entry) => entry.status).toSet();

    for (final status in [OrderStatus.canceled, OrderStatus.refund]) {
      if (_order.status == status || historyStatuses.contains(status)) {
        statuses.add(status);
      }
    }

    return statuses;
  }

  List<_TrackingEvent> _trackTimelineEvents(
    List<OrderStatusHistoryEntry> history,
  ) {
    final entryByStatus = <OrderStatus, OrderStatusHistoryEntry>{};
    for (final entry in history) {
      final existing = entryByStatus[entry.status];
      if (existing == null || entry.changedAt.isAfter(existing.changedAt)) {
        entryByStatus[entry.status] = entry;
      }
    }

    final statuses = <OrderStatus>[];
    final currentRank = _statusRank(_order.status);
    if (currentRank >= 0) {
      statuses.addAll(
        [
          OrderStatus.pending,
          OrderStatus.confirmed,
          OrderStatus.inDelivery,
          OrderStatus.completed,
        ].where((status) => _statusRank(status) <= currentRank),
      );
    } else {
      statuses.add(OrderStatus.pending);
      for (final entry in history) {
        if (!statuses.contains(entry.status)) {
          statuses.add(entry.status);
        }
      }
      if (!statuses.contains(_order.status)) {
        statuses.add(_order.status);
      }
    }

    return statuses.reversed.map((status) {
      final entry = entryByStatus[status];
      return _TrackingEvent(
        status: status,
        title: _statusTimelineTitle(status),
        time: entry != null ? _formatOrderTime(entry.changedAt) : '',
        location: _statusTimelineLocation(status),
        active: status == _order.status,
        color: _orderStatusColor(status),
      );
    }).toList();
  }

  int _statusRank(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.confirmed:
        return 1;
      case OrderStatus.inDelivery:
        return 2;
      case OrderStatus.completed:
        return 3;
      case OrderStatus.canceled:
      case OrderStatus.refund:
        return -1;
    }
  }

  Widget _detailSection({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.darkText,
              fontFamily: AppFonts.primary,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isTotal = false,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: isTotal ? AppColors.darkText : AppColors.subtleText,
                fontFamily: AppFonts.primary,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.darkText,
                fontFamily: AppFonts.primary,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }
}

class _TrackingEvent {
  final OrderStatus status;
  final String title;
  final String time;
  final String location;
  final bool active;
  final Color color;

  const _TrackingEvent({
    required this.status,
    required this.title,
    required this.time,
    required this.location,
    required this.color,
    this.active = false,
  });
}

class _ReviewActionButton extends StatelessWidget {
  final OrderModel order;
  final CartItem item;
  final VoidCallback onSubmitted;

  const _ReviewActionButton({
    required this.order,
    required this.item,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProductReview?>(
      future: ProductReviewService.instance.loadOrderProductReview(
        orderId: order.id,
        productId: item.product.id,
        productVariantId: item.variantId,
      ),
      builder: (context, snapshot) {
        final review = snapshot.data;
        return OutlinedButton.icon(
          onPressed: () async {
            final submitted = await showModalBottomSheet<bool>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _ReviewSheet(
                order: order,
                item: item,
                existingReview: review,
              ),
            );
            if (submitted == true) onSubmitted();
          },
          icon: const Icon(Icons.star_border_rounded, size: 18),
          label: Text(review == null ? 'Rate Product' : 'Edit Review'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryGreen,
            side: const BorderSide(color: AppColors.primaryGreen),
          ),
        );
      },
    );
  }
}

class _ReviewSheet extends StatefulWidget {
  final OrderModel order;
  final CartItem item;
  final ProductReview? existingReview;

  const _ReviewSheet({
    required this.order,
    required this.item,
    this.existingReview,
  });

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int _rating;
  late TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.existingReview?.rating ?? 5;
    _controller = TextEditingController(
      text: widget.existingReview?.reviewText ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final brandId = widget.item.product.brandId;
    if (brandId == null || brandId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to identify product brand.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ProductReviewService.instance.submitReview(
        reviewId: widget.existingReview?.id,
        orderId: widget.order.id,
        orderItemId: widget.item.dbId,
        productId: widget.item.product.id,
        productVariantId: widget.item.variantId,
        brandId: brandId,
        rating: _rating,
        reviewText: _controller.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Thanks for your review.')));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to save review.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottom),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.item.product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.darkText,
                fontFamily: AppFonts.primary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final value = index + 1;
                return IconButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _rating = value),
                  icon: Icon(
                    value <= _rating
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: const Color(0xFFFFB300),
                    size: 34,
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              enabled: !_saving,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write a review (optional)',
                filled: true,
                fillColor: AppColors.lightGrey,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: AppColors.primaryGreen,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 72,
                        height: 36,
                        child: ButtonLoadingDots(),
                      )
                    : const Text(
                        'Submit Review',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: AppFonts.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackDot extends StatelessWidget {
  final bool active;
  final Color color;
  final bool showTail;

  const _TrackDot({
    required this.active,
    required this.color,
    required this.showTail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: active ? color : Colors.grey.shade300,
          child: const Icon(Icons.check, size: 14, color: Colors.white),
        ),
        if (showTail) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 1.5,
              color: active
                  ? color.withValues(alpha: 0.55)
                  : Colors.grey.shade300,
            ),
          ),
        ],
      ],
    );
  }
}

class _TrackTimelineRow extends StatelessWidget {
  final _TrackingEvent event;
  final bool showTail;

  const _TrackTimelineRow({required this.event, required this.showTail});

  @override
  Widget build(BuildContext context) {
    final color = event.active
        ? event.color
        : event.color.withValues(alpha: 0.45);
    final titleColor = event.active
        ? event.color
        : event.color.withValues(alpha: 0.62);
    final bodyColor = event.active ? AppColors.darkText : Colors.grey.shade500;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: event.active
                      ? event.color.withValues(alpha: 0.14)
                      : event.color.withValues(alpha: 0.08),
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(
                  _timelineIcon(event.status),
                  color: color,
                  size: 16,
                ),
              ),
              if (showTail)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: event.active
                        ? event.color.withValues(alpha: 0.28)
                        : event.color.withValues(alpha: 0.14),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: TextStyle(
                            color: titleColor,
                            fontFamily: AppFonts.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (event.active) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: event.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Current',
                            style: TextStyle(
                              color: event.color,
                              fontFamily: AppFonts.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      if (event.time.isNotEmpty)
                        Text(
                          event.time,
                          style: TextStyle(
                            color: event.active
                                ? event.color
                                : event.color.withValues(alpha: 0.55),
                            fontFamily: AppFonts.primary,
                            fontSize: 12,
                            fontWeight: event.active
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.location,
                    style: TextStyle(
                      color: bodyColor,
                      fontFamily: AppFonts.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _timelineIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.inventory_2_outlined;
      case OrderStatus.confirmed:
        return Icons.verified_outlined;
      case OrderStatus.inDelivery:
        return Icons.local_shipping_outlined;
      case OrderStatus.completed:
        return Icons.check_circle_outline;
      case OrderStatus.canceled:
        return Icons.cancel_outlined;
      case OrderStatus.refund:
        return Icons.payments_outlined;
    }
  }
}
