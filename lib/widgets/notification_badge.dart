import 'package:flutter/material.dart';
import 'package:RoyalClinic/services/local_notification_service.dart';

class NotificationBadge extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const NotificationBadge({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  final LocalNotificationService _notificationService = LocalNotificationService();

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    await _notificationService.loadNotificationsFromLocal();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notificationService.unreadCount;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: widget.onTap,
          child: widget.child,
        ),
        if (unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}