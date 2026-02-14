import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));

    // Android settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap
        print('Notification tapped: ${response.payload}');
      },
    );

    // Request permissions for Android 13+
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
    }

    final IOSFlutterLocalNotificationsPlugin? iosImplementation =
        _notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

    if (iosImplementation != null) {
      await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String medicineName,
    required String time, // Format: "HH:mm"
    String? instructions,
  }) async {
    // Parse time
    final timeParts = time.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    // Create scheduled time
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id,
      '💊 Medicine Reminder',
      'Time to take $medicineName',
      scheduledDate,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_reminders',
          'Medicine Reminders',
          channelDescription: 'Notifications for medicine schedules',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          sound: const RawResourceAndroidNotificationSound('notification'),
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          sound: 'notification.aiff',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
      payload: json.encode({
        'medicineName': medicineName,
        'instructions': instructions,
      }),
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Generate unique ID for each medicine-time combination
  int generateNotificationId(String medicineName, String time) {
    return '${medicineName}_$time'.hashCode.abs() % 2147483647;
  }
}

// Schedule model
class MedicineSchedule {
  final String medicineName;
  final List<String> times; // List of times in "HH:mm" format
  final bool isActive;

  MedicineSchedule({
    required this.medicineName,
    required this.times,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'medicineName': medicineName,
        'times': times,
        'isActive': isActive,
      };

  factory MedicineSchedule.fromJson(Map<String, dynamic> json) => MedicineSchedule(
        medicineName: json['medicineName'],
        times: List<String>.from(json['times']),
        isActive: json['isActive'] ?? true,
      );
}

// Helper class for managing schedules
class ScheduleManager {
  static const String _scheduleKey = 'MEDICINE_SCHEDULES';

  static Future<void> saveSchedule(MedicineSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    final schedules = await getAllSchedules();

    // Remove existing schedule for this medicine
    schedules.removeWhere((s) => s.medicineName == schedule.medicineName);

    // Add new schedule
    schedules.add(schedule);

    // Save to preferences
    final jsonList = schedules.map((s) => s.toJson()).toList();
    await prefs.setString(_scheduleKey, json.encode(jsonList));

    // Schedule notifications
    if (schedule.isActive) {
      await _scheduleNotifications(schedule);
    }
  }

  static Future<List<MedicineSchedule>> getAllSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_scheduleKey);

    if (jsonString == null) return [];

    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((json) => MedicineSchedule.fromJson(json)).toList();
  }

  static Future<MedicineSchedule?> getScheduleForMedicine(String medicineName) async {
    final schedules = await getAllSchedules();
    try {
      return schedules.firstWhere((s) => s.medicineName == medicineName);
    } catch (e) {
      return null;
    }
  }

  static Future<void> deleteSchedule(String medicineName) async {
    final prefs = await SharedPreferences.getInstance();
    final schedules = await getAllSchedules();

    // Cancel all notifications for this medicine
    final schedule = schedules.firstWhere(
      (s) => s.medicineName == medicineName,
      orElse: () => MedicineSchedule(medicineName: '', times: []),
    );

    for (final time in schedule.times) {
      final id = NotificationService().generateNotificationId(medicineName, time);
      await NotificationService().cancelNotification(id);
    }

    // Remove schedule
    schedules.removeWhere((s) => s.medicineName == medicineName);

    // Save
    final jsonList = schedules.map((s) => s.toJson()).toList();
    await prefs.setString(_scheduleKey, json.encode(jsonList));
  }

  static Future<void> _scheduleNotifications(MedicineSchedule schedule) async {
    final notificationService = NotificationService();

    // Cancel existing notifications
    for (final time in schedule.times) {
      final id = notificationService.generateNotificationId(schedule.medicineName, time);
      await notificationService.cancelNotification(id);
    }

    // Schedule new notifications
    final prefs = await SharedPreferences.getInstance();
    final instructions = prefs.getString('${schedule.medicineName}_USAGE') ??
                        prefs.getString('${schedule.medicineName}_TIMING');

    for (final time in schedule.times) {
      final id = notificationService.generateNotificationId(schedule.medicineName, time);
      await notificationService.scheduleNotification(
        id: id,
        medicineName: schedule.medicineName,
        time: time,
        instructions: instructions,
      );
    }
  }

  static Future<void> toggleSchedule(String medicineName, bool isActive) async {
    final schedule = await getScheduleForMedicine(medicineName);
    if (schedule == null) return;

    final updatedSchedule = MedicineSchedule(
      medicineName: schedule.medicineName,
      times: schedule.times,
      isActive: isActive,
    );

    await saveSchedule(updatedSchedule);

    if (!isActive) {
      // Cancel all notifications
      for (final time in schedule.times) {
        final id = NotificationService().generateNotificationId(medicineName, time);
        await NotificationService().cancelNotification(id);
      }
    }
  }
}