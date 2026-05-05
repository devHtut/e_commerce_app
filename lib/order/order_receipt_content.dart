import 'package:flutter/material.dart';

import '../theme_config.dart';
import 'order_service.dart';

String _receiptStatusLabel(OrderStatus status) {
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

/// Fixed-width layout rendered to PNG for order receipts.
class OrderReceiptContent extends StatelessWidget {
  final OrderModel order;

  const OrderReceiptContent({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final first = order.items.isNotEmpty ? order.items.first : null;
    final brandName = first?.product.brand.trim().isNotEmpty == true
        ? first!.product.brand
        : 'Brand';
    final logoUrl = first?.product.brandLogoUrl;
    final subtotal = order.total;
    final payment = order.payment;
    final addressLabel = order.shippingAddressLabel.isNotEmpty
        ? order.shippingAddressLabel
        : 'Delivery';
    final addressLine = order.shippingAddressStreet.isNotEmpty
        ? order.shippingAddressStreet
        : '—';
    final dateStr =
        '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}';
    final timeStr =
        '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      width: 380,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: logoUrl != null && logoUrl.isNotEmpty
                    ? Image.network(
                        logoUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _logoPlaceholder(),
                      )
                    : _logoPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brandName,
                      style: const TextStyle(
                        fontFamily: AppFonts.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppColors.darkText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Order receipt',
                      style: TextStyle(
                        fontFamily: AppFonts.primary,
                        fontSize: 13,
                        color: AppColors.subtleText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _rowLabelValue('Order reference', order.readableId, emphasize: true),
          const SizedBox(height: 6),
          _rowLabelValue('Status', _receiptStatusLabel(order.status)),
          const SizedBox(height: 6),
          _rowLabelValue('Date', '$dateStr  $timeStr'),
          const SizedBox(height: 14),
          const Text(
            'Delivery',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            addressLabel,
            style: const TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 13,
              color: AppColors.darkText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            addressLine,
            style: const TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: 12,
              color: AppColors.subtleText,
              height: 1.35,
            ),
          ),
          if (order.shippingAddressRecipient.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Recipient: ${order.shippingAddressRecipient}',
              style: const TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 12,
                color: AppColors.subtleText,
              ),
            ),
          ],
          if (order.shippingAddressPhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Contact: ${order.shippingAddressPhone}',
              style: const TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 12,
                color: AppColors.subtleText,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Items',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in order.items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: item.imageUrl.isNotEmpty
                      ? Image.network(
                          item.imageUrl,
                          width: 44,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 44,
                            height: 52,
                            color: Colors.grey.shade200,
                          ),
                        )
                      : Container(
                          width: 44,
                          height: 52,
                          color: Colors.grey.shade200,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Size: ${item.size}  ·  Color: ${item.colorName}  ·  Qty: ${item.quantity}',
                        style: const TextStyle(
                          fontFamily: AppFonts.primary,
                          fontSize: 11,
                          color: AppColors.subtleText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${item.subtotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontFamily: AppFonts.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          const Divider(height: 1),
          const SizedBox(height: 10),
          _rowLabelValue(
            'Subtotal (${order.items.length} items)',
            '\$${subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 6),
          _rowLabelValue(
            'Total',
            '\$${subtotal.toStringAsFixed(2)}',
            emphasize: true,
          ),
          const SizedBox(height: 14),
          const Text(
            'Payment',
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          if (payment == null)
            const Text(
              'No payment record on file.',
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 12,
                color: AppColors.subtleText,
              ),
            )
          else ...[
            _rowLabelValue('Method', payment.paymentMethod),
            const SizedBox(height: 4),
            _rowLabelValue('Status', payment.status.toUpperCase()),
            const SizedBox(height: 4),
            _rowLabelValue('Transaction ID', payment.transactionId),
            const SizedBox(height: 4),
            _rowLabelValue('Amount', '\$${payment.amount.toStringAsFixed(2)}'),
            if (payment.screenshotUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Payment screenshot',
                style: TextStyle(
                  fontFamily: AppFonts.primary,
                  fontSize: 11,
                  color: AppColors.subtleText,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  payment.screenshotUrl,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ],
          ],
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Thank you for your order.',
              style: TextStyle(
                fontFamily: AppFonts.primary,
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.storefront_outlined,
        color: AppColors.primaryGreen,
        size: 28,
      ),
    );
  }

  Widget _rowLabelValue(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: emphasize ? 13 : 12,
              color: AppColors.subtleText,
              fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.primary,
              fontSize: emphasize ? 14 : 12,
              color: AppColors.darkText,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
