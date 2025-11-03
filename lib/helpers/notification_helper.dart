import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class NotificationHelper {
  static final NotificationHelper _instance = NotificationHelper._internal();
  factory NotificationHelper() => _instance;
  NotificationHelper._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // ✅ Initialize
  Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permission
    await _requestPermission();
  }

  // ✅ Request Permission
  Future<void> _requestPermission() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true);
  }

  // ✅ Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('📲 Notification tapped: ${response.payload}');
    // Navigate hoặc show dialog
  }

  // ✅ Schedule daily notification
  Future<void> scheduleDailyNotification({
    required int hour,
    required int minute,
  }) async {
    await _notifications.cancel(0); // Cancel old notification

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // Nếu giờ đã qua hôm nay, schedule cho ngày mai
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint('⏰ Scheduling notification at: $scheduledDate');

    await _notifications.zonedSchedule(
      0,
      ' Học tiếng Anh hôm nay!',
      'Đã đến giờ học tiếng Anh rồi. Cùng bắt đầu nào! 🚀',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily Learning Reminder',
          channelDescription: 'Nhắc nhở học tiếng Anh hàng ngày',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, //  Ensure exact timing Idle
      matchDateTimeComponents: DateTimeComponents.time, //  Repeat daily
    );

    // Save to SharedPreferences
    await _saveNotificationTime(hour, minute);
  }

  // ✅ Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
    debugPrint('🔕 All notifications cancelled');
  }

  // ✅ Save notification time
  Future<void> _saveNotificationTime(int hour, int minute) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('notification_hour', hour);
    await prefs.setInt('notification_minute', minute);
    await prefs.setBool('notification_enabled', true);
  }

  // ✅ Get saved notification time
  Future<Map<String, dynamic>> getSavedTime() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'hour': prefs.getInt('notification_hour') ?? 9,
      'minute': prefs.getInt('notification_minute') ?? 0,
      'enabled': prefs.getBool('notification_enabled') ?? false,
    };
  }

  // ✅ Toggle notification on/off
  Future<void> toggleNotification(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_enabled', enabled);

    if (enabled) {
      final savedTime = await getSavedTime();
      await scheduleDailyNotification(
        hour: savedTime['hour'],
        minute: savedTime['minute'],
      );
    } else {
      await cancelAll();
    }
  }
}