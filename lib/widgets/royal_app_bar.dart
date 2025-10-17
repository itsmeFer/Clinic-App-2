// lib/widgets/royal_app_bar.dart
import 'package:flutter/material.dart';
import 'package:RoyalClinic/services/local_notification_service.dart';
import 'package:RoyalClinic/pages/notification_page.dart';

/// Palet warna/tema ringkas biar konsisten dengan file kamu
class TealX {
  static const Color primary = Color(0xFF00897B);
  static const Color primaryDark = Color(0xFF00695C);
  static const Color primaryLight = Color(0xFF4DB6AC);

  static const Color text = Color(0xFF0F1C1A);
  static const Color textMuted = Color(0xFF6A7A77);
}

/// AppBar global: logo + judul + lonceng notif (badge) + (opsional) action tambahan
class RoyalAppBar extends StatelessWidget implements PreferredSizeWidget {
  const RoyalAppBar({
    super.key,
    this.title = 'Royal Clinic',
    this.centerTitle = false,
    this.showBack = false,
    this.trailingActions = const [],
    this.backgroundColor,
    this.elevation = 0,
  });

  final String title;
  final bool centerTitle;
  final bool showBack;
  final List<Widget> trailingActions;
  final Color? backgroundColor;
  final double elevation;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final service = LocalNotificationService();

    Widget bellWithBadge(int unread) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: 'Notifikasi',
            icon: const Icon(Icons.notifications_outlined, color: TealX.text),
            onPressed: () async {
              await service.loadNotificationsFromLocal();
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationPage()),
              );
            },
          ),
          if (unread > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unread > 99 ? '99+' : unread.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return AppBar(
      backgroundColor: backgroundColor ?? Colors.white.withOpacity(0.95),
      elevation: elevation,
      automaticallyImplyLeading: showBack,
      centerTitle: centerTitle,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ganti asset logo jika berbeda
          Image.asset('assets/gambar/logo.png', height: 24, width: 24),
          const SizedBox(width: 10),
          Text(
            title,
            style: const TextStyle(
              color: TealX.text,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
      actions: [
        // Bell + Badge realtime pakai stream dari service
        StreamBuilder<List<NotificationModel>>(
          stream: service.notificationStream,
          initialData: service.notifications,
          builder: (context, _) {
            final unread = service.unreadCount;
            return bellWithBadge(unread);
          },
        ),
        ...trailingActions,
        const SizedBox(width: 6),
      ],
    );
  }
}
