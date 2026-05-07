import 'package:flutter/material.dart';

import '../theme_config.dart';
import 'notification_service.dart';

class NotificationScreen extends StatefulWidget {
  final AppNotificationAudience audience;

  const NotificationScreen({super.key, required this.audience});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late Future<List<AppNotification>> _notificationsFuture;
  final Set<String> _locallyReadNotificationIds = <String>{};
  bool _allReadLocally = false;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
  }

  Future<List<AppNotification>> _loadNotifications() {
    return NotificationService.instance.loadNotifications(
      audience: widget.audience,
    );
  }

  Future<void> _refresh() async {
    final future = _loadNotifications();
    setState(() => _notificationsFuture = future);
    await future;
  }

  Future<void> _markAllRead() async {
    setState(() {
      _allReadLocally = true;
      _locallyReadNotificationIds.clear();
    });
    NotificationService.instance.unreadCountNotifier.value = 0;

    try {
      await NotificationService.instance.markAllAsRead(
        audience: widget.audience,
      );
      await _refresh();
    } catch (e) {
      debugPrint('Unable to mark all notifications read: $e');
    }
  }

  Future<void> _markRead(AppNotification notification) async {
    if (!_isUnread(notification)) return;
    setState(() => _locallyReadNotificationIds.add(notification.id));
    final unreadCount = NotificationService.instance.unreadCountNotifier.value;
    if (unreadCount > 0) {
      NotificationService.instance.unreadCountNotifier.value = unreadCount - 1;
    }

    try {
      await NotificationService.instance.markAsRead(notification.id);
      await _refresh();
    } catch (e) {
      debugPrint('Unable to mark notification read: $e');
    }
  }

  bool _isUnread(AppNotification notification) {
    return notification.isUnread &&
        !_allReadLocally &&
        !_locallyReadNotificationIds.contains(notification.id);
  }

  String get _title {
    return widget.audience == AppNotificationAudience.vendor
        ? 'Vendor Notifications'
        : 'Notifications';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: AppColors.darkText),
        title: Text(
          _title,
          style: const TextStyle(
            color: AppColors.darkText,
            fontFamily: AppFonts.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: AppColors.primaryGreen,
                fontFamily: AppFonts.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Unable to load notifications',
              message: 'Please try again in a moment.',
              action: TextButton(
                onPressed: _refresh,
                child: const Text('Retry'),
              ),
            );
          }

          final notifications = snapshot.data ?? <AppNotification>[];
          if (notifications.isEmpty) {
            return const _EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
              message: 'Order and account updates will appear here.',
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationTile(
                  notification: notification,
                  isUnread: _isUnread(notification),
                  onTap: () => _markRead(notification),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final bool isUnread;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.isUnread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnread
                ? AppColors.primaryGreen.withValues(alpha: 0.32)
                : Colors.transparent,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _notificationColor(
                  notification.type,
                ).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _notificationIcon(notification.type),
                color: _notificationColor(notification.type),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: const TextStyle(
                            color: AppColors.darkText,
                            fontFamily: AppFonts.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    notification.message,
                    style: const TextStyle(
                      color: AppColors.subtleText,
                      fontFamily: AppFonts.primary,
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatNotificationTime(notification.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontFamily: AppFonts.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (notification.orderId != null &&
                          notification.orderId!.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            '#${notification.orderId!.substring(0, notification.orderId!.length.clamp(0, 8)).toUpperCase()}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.primaryGreen,
                              fontFamily: AppFonts.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _notificationIcon(String type) {
    if (type.contains('welcome')) return Icons.waving_hand_outlined;
    if (type.contains('payment')) return Icons.payments_outlined;
    if (type.contains('delivery')) return Icons.local_shipping_outlined;
    if (type.contains('cancel')) return Icons.cancel_outlined;
    if (type.contains('refund')) return Icons.request_quote_outlined;
    if (type.contains('completed')) return Icons.check_circle_outline;
    if (type.contains('confirmed')) return Icons.verified_outlined;
    return Icons.notifications_none_rounded;
  }

  Color _notificationColor(String type) {
    if (type.contains('cancel')) return AppColors.errorRed;
    if (type.contains('delivery')) return Colors.blue.shade700;
    if (type.contains('refund')) return Colors.deepOrange.shade800;
    if (type.contains('payment')) return Colors.amber.shade900;
    return AppColors.primaryGreen;
  }

  String _formatNotificationTime(DateTime createdAt) {
    final local = createdAt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${local.day}/${local.month}/${local.year}';
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.primaryGreen),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.darkText,
                fontFamily: AppFonts.primary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.subtleText,
                fontFamily: AppFonts.primary,
                height: 1.35,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}
