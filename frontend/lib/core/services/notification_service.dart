import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String _defaultChannelId = 'enosis_task_reminders';
  static const String _defaultChannelName = 'ENOSIS Task Reminders';
  static const String _urgentChannelId = 'enosis_urgent_reminders';
  static const String _urgentChannelName = 'ENOSIS Urgent Reminders';

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationService initialization notice: $e');
    }
  }

  Future<bool> requestPermissions() async {
    try {
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
      return false;
    }
  }

  NotificationDetails _buildNotificationDetails(String priority) {
    final isUrgent = priority.toLowerCase() == 'urgent';

    final androidDetails = AndroidNotificationDetails(
      isUrgent ? _urgentChannelId : _defaultChannelId,
      isUrgent ? _urgentChannelName : _defaultChannelName,
      channelDescription: isUrgent
          ? 'Urgent task deadlines requiring immediate faculty attention.'
          : 'Standard faculty productivity reminders and to-do notifications.',
      importance: isUrgent ? Importance.max : Importance.high,
      priority: isUrgent ? Priority.max : Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String priority = 'medium',
    String? payload,
  }) async {
    if (kIsWeb) return; // Local notifications plugin does not support scheduled web notifications

    try {
      await initialize();

      final now = DateTime.now();
      if (scheduledDate.isBefore(now)) {
        debugPrint('Skipping past notification schedule for id: $id');
        return;
      }

      final tzDateTime = tz.TZDateTime.from(scheduledDate, tz.local);

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        _buildNotificationDetails(priority),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('Scheduled notification $id for $scheduledDate (priority: $priority)');
    } catch (e) {
      debugPrint('Notice scheduling local notification $id: $e');
    }
  }

  Future<void> showImmediateNotification({
    required int id,
    required String title,
    required String body,
    String priority = 'medium',
    String? payload,
  }) async {
    if (kIsWeb) return;

    try {
      await initialize();
      await _notificationsPlugin.show(
        id,
        title,
        body,
        _buildNotificationDetails(priority),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Notice showing immediate notification $id: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      debugPrint('Notice cancelling notification $id: $e');
    }
  }

  Future<void> cancelAll() async {
    if (kIsWeb) return;
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Notice cancelling all notifications: $e');
    }
  }
}
