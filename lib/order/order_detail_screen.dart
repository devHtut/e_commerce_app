import 'package:flutter/material.dart';

import '../theme_config.dart';
import 'order_service.dart';

class OrderDetailScreen extends StatefulWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  int _tabIndex = 0; // 0 => details, 1 => track

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
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.more_vert, color: AppColors.darkText),
          ),
        ],
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
    final subtotal = widget.order.total;
    const serviceFee = 1.50;
    const deliveryFee = 8.50;
    const tax = 3.50;
    final promo = subtotal * 0.2;
    final total = subtotal + serviceFee + deliveryFee + tax - promo;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [
        _detailSection(
          title: 'Delivery Address',
          child: Row(
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
                  children: const [
                    Text(
                      'Home  (Andrew Ainsley)',
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '701 7th Ave, New York, NY 10036, USA',
                      style: TextStyle(
                        color: AppColors.subtleText,
                        fontFamily: AppFonts.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.primaryGreen,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                widget.order.status.name.toUpperCase(),
                style: TextStyle(
                  color: widget.order.status == OrderStatus.pending
                      ? AppColors.primaryGreen
                      : widget.order.status == OrderStatus.completed
                      ? Colors.blue
                      : AppColors.errorRed,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _detailSection(
          title: 'Your Order (${widget.order.items.length})',
          child: Column(
            children: [
              for (final item in widget.order.items) ...[
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
                          Row(
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: Color(item.colorValue),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.subtleText,
                                    width: 1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.colorName,
                                style: const TextStyle(
                                  color: AppColors.subtleText,
                                  fontFamily: AppFonts.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
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
                            '\$${item.subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontFamily: AppFonts.primary,
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                'Subtotal (${widget.order.items.length} items)',
                '\$${subtotal.toStringAsFixed(2)}',
              ),
              _summaryRow('Service Fee', '\$${serviceFee.toStringAsFixed(2)}'),
              _summaryRow(
                'Delivery Fee',
                '\$${deliveryFee.toStringAsFixed(2)}',
              ),
              _summaryRow('Tax', '\$${tax.toStringAsFixed(2)}'),
              _summaryRow('Promo', '- \$${promo.toStringAsFixed(2)}'),
              const Divider(),
              _summaryRow(
                'Total Payment',
                '\$${total.toStringAsFixed(2)}',
                isTotal: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _detailSection(
          title: 'Information Details',
          child: Column(
            children: [
              _summaryRow(
                'Purchase Date',
                '${widget.order.createdAt.day}/${widget.order.createdAt.month}/${widget.order.createdAt.year}',
              ),
              _summaryRow(
                'Purchase Hours',
                '${widget.order.createdAt.hour.toString().padLeft(2, '0')}:${widget.order.createdAt.minute.toString().padLeft(2, '0')}',
              ),
              _summaryRow(
                'Invoice Number',
                'INV${widget.order.id.substring(4, 10).toUpperCase()}TRX',
              ),
              _summaryRow(
                'Receipt Number',
                'RCP${widget.order.id.substring(4, 10).toUpperCase()}RNV',
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryGreen),
                  ),
                  child: const Text(
                    'Generate Invoice',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontFamily: AppFonts.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackOrder() {
    final arrived = widget.order.status == OrderStatus.completed;
    final pending = widget.order.status == OrderStatus.pending;
    final title = pending
        ? 'Awaiting Confirmation'
        : arrived
        ? 'Orders Has Arrived'
        : 'Orders in Delivery';
    final trackingEvents = [
      _TrackingEvent(
        title: pending
            ? 'Payment submitted'
            : arrived
            ? 'Order Has Arrived - Dec 23'
            : 'Order is being Delivered - Dec 23',
        time: pending
            ? '09:41 AM'
            : arrived
            ? '09:41 AM'
            : '08:40 AM',
        location: pending
            ? 'Waiting for vendor confirmation'
            : arrived
            ? 'Andrew Ainsley - 701 7th Ave, New York, NY 100...'
            : '4 Evergreen Street Lake Zurich, IL 60047',
        active: true,
      ),
      const _TrackingEvent(
        title: 'Order is being Delivered - Dec 22',
        time: '20:08 PM',
        location: '9177 Hillcrest Street Wheeling, WV 26003',
      ),
      const _TrackingEvent(
        title: 'Orders are in Transit - Dec 22',
        time: '17:56 PM',
        location: '891 Glen Ridge St. Gainesville, VA 20155',
      ),
      const _TrackingEvent(
        title: 'Order is being Delivered - Dec 22',
        time: '13:27 PM',
        location: '55 Summerhouse Dr. Apopka, FL 32703',
      ),
      const _TrackingEvent(
        title: 'Store Processing Orders - Dec 22',
        time: '10:20 AM',
        location: 'Orders are being processed by the Store',
      ),
      const _TrackingEvent(
        title: 'Payments Verified - Dec 22',
        time: '09:41 AM',
        location: 'Your payment has been confirmed',
      ),
    ];

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
                children: const [
                  Icon(
                    Icons.inventory_2,
                    color: AppColors.primaryGreen,
                    size: 36,
                  ),
                  Icon(
                    Icons.local_shipping,
                    color: AppColors.primaryGreen,
                    size: 36,
                  ),
                  Icon(Icons.handshake, color: Colors.grey, size: 36),
                  Icon(Icons.inventory, color: Colors.grey, size: 36),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: const [
                  Expanded(child: _TrackDot(active: true)),
                  Expanded(child: _TrackDot(active: true)),
                  Expanded(child: _TrackDot(active: false)),
                  Expanded(child: _TrackDot(active: false)),
                ],
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
              const Text(
                'Delivery Status',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontFamily: AppFonts.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 34,
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

  Widget _summaryRow(String label, String value, {bool isTotal = false}) {
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
          Text(
            value,
            style: TextStyle(
              color: AppColors.darkText,
              fontFamily: AppFonts.primary,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingEvent {
  final String title;
  final String time;
  final String location;
  final bool active;

  const _TrackingEvent({
    required this.title,
    required this.time,
    required this.location,
    this.active = false,
  });
}

class _TrackDot extends StatelessWidget {
  final bool active;

  const _TrackDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: active
              ? AppColors.primaryGreen
              : Colors.grey.shade300,
          child: const Icon(Icons.check, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Container(
            height: 1.5,
            color: active ? AppColors.primaryGreen : Colors.grey.shade300,
          ),
        ),
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
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: event.active
                        ? AppColors.primaryGreen
                        : Colors.grey.shade400,
                    width: 3,
                  ),
                  color: Colors.white,
                ),
              ),
              if (showTail)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.grey.shade300,
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
                          style: const TextStyle(
                            color: AppColors.darkText,
                            fontFamily: AppFonts.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        event.time,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontFamily: AppFonts.primary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.location,
                    style: TextStyle(
                      color: Colors.grey.shade600,
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
}
