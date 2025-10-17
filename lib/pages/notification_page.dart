import 'package:flutter/material.dart';
import 'package:RoyalClinic/services/local_notification_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
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
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.95),
        elevation: 0,
        title: const Text(
          'Notifikasi',
          style: TextStyle(
            color: Color(0xFF0F1C1A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_notificationService.notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                _notificationService.markAllAsRead();
                setState(() {});
              },
              child: const Text(
                'Tandai Semua',
                style: TextStyle(
                  color: Color(0xFF00897B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE7F4F2),
              Color(0xFFF8FFFE),
            ],
          ),
        ),
        child: _notificationService.notifications.isEmpty
            ? _buildEmptyState()
            : _buildNotificationList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 80,
            color: Color(0xFF4DB6AC),
          ),
          SizedBox(height: 16),
          Text(
            'Belum ada notifikasi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F1C1A),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Notifikasi akan muncul di sini',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6A7A77),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notificationService.notifications.length,
      itemBuilder: (context, index) {
        final notification = _notificationService.notifications[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: notification.isRead 
                ? Colors.white 
                : const Color(0xFF00897B).withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: notification.isRead 
                  ? Colors.white.withOpacity(0.6)
                  : const Color(0xFF00897B).withOpacity(0.2),
            ),
          ),
          child: ListTile(
            leading: Icon(
              Icons.notifications,
              color: const Color(0xFF00897B),
            ),
            title: Text(
              notification.title,
              style: TextStyle(
                fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
              ),
            ),
            subtitle: Text(notification.body),
            onTap: () {
              _notificationService.markAsRead(notification.id);
              setState(() {});
            },
          ),
        );
      },
    );
  }
}