// lib/services/local_notification_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

class LocalNotificationService {
  // ===== Singleton =====
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  // ===== Fields =====
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  Timer? _pollingTimer;
  Function(Map<String, dynamic>)? onNotificationTapped;
  List<NotificationModel> notifications = [];

  bool _isInitialized = false;

  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.4:8000/api',
  );
  static const int _maxStoredNotifications = 100;
  static const Duration _pollingInterval = Duration(seconds: 30);

  // Stream untuk update realtime ke UI
  final StreamController<List<NotificationModel>> _notificationController =
      StreamController<List<NotificationModel>>.broadcast();

  Stream<List<NotificationModel>> get notificationStream => _notificationController.stream;

  // ===== Public API =====
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _initializeLocalNotifications();
      await loadNotificationsFromLocal();
      _startPolling();

      _isInitialized = true;
      debugPrint('LocalNotificationService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing notification service: $e');
      rethrow;
    }
  }

  bool get isInitialized => _isInitialized;
  int get unreadCount => notifications.where((n) => !n.isRead).length;
  int get totalCount => notifications.length;

  // ===== Init & permissions =====
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    await _ensureAndroidChannel();
    await _requestPermissions();
  }

  Future<void> _ensureAndroidChannel() async {
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    const channel = AndroidNotificationChannel(
      'royal_clinic_channel', // harus match dengan yang dipakai di AndroidNotificationDetails
      'Royal Clinic Notifications',
      description: 'Notifikasi dari Royal Clinic',
      importance: Importance.high,
    );

    await android.createNotificationChannel(channel);
  }

  Future<void> _requestPermissions() async {
    // Android 13+ membutuhkan POST_NOTIFICATIONS
    final AndroidFlutterLocalNotificationsPlugin? android =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    // iOS/macOS: sudah diminta via DarwinInitializationSettings(request*Permission: true)
  }

  // ===== Callbacks =====
  void _onNotificationResponse(NotificationResponse response) {
    try {
      if (response.payload != null) {
        final data = jsonDecode(response.payload!);

        // Tandai read jika ada id
        if (data['notification_id'] != null) {
          markAsRead(data['notification_id'].toString());
        }

        onNotificationTapped?.call(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      debugPrint('Error handling notification response: $e');
    }
  }

  // ===== Polling =====
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) => _checkForNewNotifications());
  }

  void stopPolling() {
    _pollingTimer?.cancel();
  }

  Future<void> _checkForNewNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');

      if (authToken == null) {
        debugPrint('No auth token available for notification check');
        return;
      }

      final lastCheck =
          prefs.getString('last_notification_check') ??
              DateTime.now().subtract(const Duration(days: 1)).toIso8601String();

      final uri = Uri.parse('$_baseUrl/notifications/recent?since=$lastCheck');
      final response = await http.get(
        uri,
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        }..addAll({'Authorization': 'Bearer $authToken'}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        await _processNewNotifications(response.body, prefs);
      } else if (response.statusCode == 401) {
        debugPrint('Unauthorized: Token may be expired');
        // TODO: refresh token / force logout kalau diperlukan
      } else {
        debugPrint('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error checking notifications: $e');
    }
  }

  Future<void> _processNewNotifications(String responseBody, SharedPreferences prefs) async {
    try {
      if (responseBody.isEmpty) return;
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map) return;

      final data = Map<String, dynamic>.from(decoded as Map);
      final List<dynamic> list = (data['data'] as List?) ?? const [];

      int added = 0;

      for (final item in list) {
        if (item is! Map) continue;
        final notifData = Map<String, dynamic>.from(item);
        final notification = NotificationModel.fromServerData(notifData);

        final exists = notifications.any((n) => n.id == notification.id);
        if (!exists) {
          notifications.insert(0, notification);
          await _showLocalNotification(notification);
          added++;
        }
      }

      if (added > 0) {
        if (notifications.length > _maxStoredNotifications) {
          notifications = notifications.take(_maxStoredNotifications).toList();
        }

        // Pakai server_time kalau ada
        final serverTime = data['server_time'] as String?;
        await prefs.setString(
          'last_notification_check',
          serverTime ?? DateTime.now().toIso8601String(),
        );

        await _saveNotificationsToLocal();
        _notificationController.add(notifications);

        debugPrint('Found $added new notifications');
      }
    } catch (e) {
      debugPrint('Error processing notifications: $e');
    }
  }

  // ===== Local show / schedule =====
  Future<void> _showLocalNotification(NotificationModel notification) async {
    try {
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'royal_clinic_channel',
        'Royal Clinic Notifications',
        channelDescription: 'Notifikasi dari Royal Clinic',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        enableVibration: true,
        playSound: true,
        showWhen: true,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails, iOS: iosDetails);

      final payload = {
        ...notification.data,
        'notification_id': notification.id,
      };

      await _localNotifications.show(
        _stableId(notification.id),
        notification.title,
        notification.body,
        platformDetails,
        payload: jsonEncode(payload),
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  /// Jadwalkan notifikasi berbasis tz (opsional; dipakai kalau mau benar-benar schedule)
  Future<void> scheduleAt({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledTimeLocal,
    Map<String, dynamic>? data,
  }) async {
    try {
      if (scheduledTimeLocal.isBefore(DateTime.now())) {
        debugPrint('Cannot schedule notification in the past');
        return;
      }

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'royal_clinic_channel',
        'Royal Clinic Notifications',
        channelDescription: 'Notifikasi dari Royal Clinic',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails, iOS: iosDetails);

      final tz.TZDateTime tzTime = tz.TZDateTime.from(scheduledTimeLocal, tz.local);

      await _localNotifications.zonedSchedule(
  _stableId(id),
  title,
  body,
  tzTime,
  platformDetails,
  androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  matchDateTimeComponents: null, // atau Daily/Time kalau mau berulang
  payload: jsonEncode({...?data, 'notification_id': id}),
);


      // Simpan catatan ke list lokal (opsional untuk tampilan UI)
      final scheduledNote = NotificationModel(
        id: id,
        title: title,
        body: 'Terjadwal: $body',
        data: data ?? {},
        timestamp: DateTime.now(),
        isRead: false,
        isScheduled: true,
        scheduledTime: scheduledTimeLocal,
      );
      notifications.insert(0, scheduledNote);
      await _saveNotificationsToLocal();
      _notificationController.add(notifications);
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  /// Versi sederhana: tampilkan sekarang + info jadwal di body (MVP)
  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
    Map<String, dynamic>? data,
  }) async {
    try {
      if (scheduledTime.isBefore(DateTime.now())) {
        debugPrint('Cannot schedule notification in the past');
        return;
      }

      final notification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        data: data ?? {},
        timestamp: DateTime.now(),
        isRead: false,
        isScheduled: true,
        scheduledTime: scheduledTime,
      );

      notifications.insert(0, notification);

      final immediateNotification = notification.copyWith(
        body: '$body\n(Dijadwalkan untuk: ${_formatDateTime(scheduledTime)})',
      );

      await _showLocalNotification(immediateNotification);
      await _saveNotificationsToLocal();
      _notificationController.add(notifications);
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  int _stableId(String id) => id.hashCode & 0x7fffffff;

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} '
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  // ===== Appointment helpers (MVP masih pakai scheduleNotification) =====
  Future<void> scheduleAppointmentReminder({
    required String appointmentId,
    required DateTime appointmentDateTime,
    required String doctorName,
    required String poliName,
  }) async {
    final now = DateTime.now();

    final oneDayBefore = appointmentDateTime.subtract(const Duration(days: 1));
    if (oneDayBefore.isAfter(now)) {
      await scheduleNotification(
        title: 'Reminder: Jadwal Besok',
        body:
            'Anda memiliki jadwal konsultasi dengan Dr. $doctorName di $poliName besok pada ${_formatDateTime(appointmentDateTime)}.',
        scheduledTime: oneDayBefore,
        data: {
          'type': 'appointment_reminder',
          'appointment_id': appointmentId,
          'time_before': '1_day',
          'doctor_name': doctorName,
          'poli_name': poliName,
          'appointment_time': appointmentDateTime.toIso8601String(),
        },
      );
    }

    final twoHoursBefore = appointmentDateTime.subtract(const Duration(hours: 2));
    if (twoHoursBefore.isAfter(now)) {
      await scheduleNotification(
        title: 'Reminder: Jadwal Hari Ini',
        body:
            'Anda memiliki jadwal konsultasi dengan Dr. $doctorName di $poliName dalam 2 jam (${_formatDateTime(appointmentDateTime)}).',
        scheduledTime: twoHoursBefore,
        data: {
          'type': 'appointment_reminder',
          'appointment_id': appointmentId,
          'time_before': '2_hours',
          'doctor_name': doctorName,
          'poli_name': poliName,
          'appointment_time': appointmentDateTime.toIso8601String(),
        },
      );
    }

    final thirtyMinutesBefore = appointmentDateTime.subtract(const Duration(minutes: 30));
    if (thirtyMinutesBefore.isAfter(now)) {
      await scheduleNotification(
        title: 'Reminder: Segera Berangkat',
        body: 'Jadwal konsultasi Anda dengan Dr. $doctorName di $poliName dimulai dalam 30 menit.',
        scheduledTime: thirtyMinutesBefore,
        data: {
          'type': 'appointment_reminder',
          'appointment_id': appointmentId,
          'time_before': '30_minutes',
          'doctor_name': doctorName,
          'poli_name': poliName,
          'appointment_time': appointmentDateTime.toIso8601String(),
        },
      );
    }
  }

  Future<void> cancelAppointmentReminders(String appointmentId) async {
    try {
      // Hapus dari list lokal
      notifications.removeWhere(
        (n) => n.data['type'] == 'appointment_reminder' && n.data['appointment_id'] == appointmentId,
      );

      await _saveNotificationsToLocal();
      _notificationController.add(notifications);

      // NOTE: Bila kamu ingin batalkan notifikasi terjadwal di sistem,
      // panggil _localNotifications.cancel(idInt) dengan id yang konsisten.
      // Di MVP ini, kita belum menyimpan mapping id string -> int utk cancel spesifik.
    } catch (e) {
      debugPrint('Error canceling appointment reminders: $e');
    }
  }

  // ===== Convenience =====
  Future<void> showTestNotification() async {
    final testNotification = NotificationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: 'Test Notification',
      body: 'Ini adalah notifikasi test dari Royal Clinic - ${DateTime.now()}',
      data: const {'type': 'test'},
      timestamp: DateTime.now(),
      isRead: false,
    );

    notifications.insert(0, testNotification);
    await _showLocalNotification(testNotification);
    await _saveNotificationsToLocal();
    _notificationController.add(notifications);
  }

  void markAsRead(String notificationId) {
    final index = notifications.indexWhere((n) => n.id == notificationId);
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      _saveNotificationsToLocal();
      _markAsReadOnServer(notificationId);
      _notificationController.add(notifications);
    }
  }

  void markAllAsRead() {
    notifications = notifications.map((n) => n.copyWith(isRead: true)).toList();
    _saveNotificationsToLocal();
    _notificationController.add(notifications);

    for (final n in notifications) {
      _markAsReadOnServer(n.id);
    }
  }

  Future<void> _markAsReadOnServer(String notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('token');
      if (authToken == null) return;

      final uri = Uri.parse('$_baseUrl/notifications/$notificationId/read');
      await http
          .put(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            }..addAll({'Authorization': 'Bearer $authToken'}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Error marking notification as read on server: $e');
    }
  }

  // ===== Local storage =====
  Future<void> _saveNotificationsToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsJson =
          notifications.take(_maxStoredNotifications).map((n) => n.toJson()).toList();
      await prefs.setString('local_notifications', jsonEncode(notificationsJson));
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  Future<void> loadNotificationsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsString = prefs.getString('local_notifications');

      if (notificationsString != null) {
        final List<dynamic> notificationsJson = jsonDecode(notificationsString);
        notifications =
            notificationsJson.map((json) => NotificationModel.fromJson(Map<String, dynamic>.from(json))).toList();

        _notificationController.add(notifications);
      }
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  Future<void> clearAllNotifications() async {
    notifications.clear();
    await _saveNotificationsToLocal();
    _notificationController.add(notifications);

    await _localNotifications.cancelAll();
  }

  List<NotificationModel> getNotificationsByType(String type) {
    return notifications.where((n) => n.data['type'] == type).toList();
  }

  void dispose() {
    _pollingTimer?.cancel();
    _notificationController.close();
  }
}

// ===== Model =====
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final bool isRead;
  final bool isScheduled;
  final DateTime? scheduledTime;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.data,
    required this.timestamp,
    required this.isRead,
    this.isScheduled = false,
    this.scheduledTime,
  });

  NotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    DateTime? timestamp,
    bool? isRead,
    bool? isScheduled,
    DateTime? scheduledTime,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      isScheduled: isScheduled ?? this.isScheduled,
      scheduledTime: scheduledTime ?? this.scheduledTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'isScheduled': isScheduled,
      'scheduledTime': scheduledTime?.toIso8601String(),
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: Map<String, dynamic>.from(json['data'] ?? {}),
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
      isScheduled: json['isScheduled'] ?? false,
      scheduledTime: json['scheduledTime'] != null ? DateTime.parse(json['scheduledTime']) : null,
    );
  }

  factory NotificationModel.fromServerData(Map<String, dynamic> serverData) {
    return NotificationModel(
      id: serverData['id'].toString(),
      title: serverData['title'] ?? 'Notifikasi',
      body: serverData['body'] ?? '',
      data: Map<String, dynamic>.from(serverData['data'] ?? {}),
      timestamp: DateTime.parse(serverData['created_at']),
      isRead: serverData['is_read'] ?? false,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} hari yang lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
  }
}
