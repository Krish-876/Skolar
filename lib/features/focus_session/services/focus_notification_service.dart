import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FocusNotificationService {
  FocusNotificationService._();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// Initialize local notification channels and permissions.
  static Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);

    // Request Android 13+ notification permissions
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();

    _isInitialized = true;
  }

  /// Show warning when user leaves the app during active focus.
  static Future<void> showExitWarningNotification() async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'focus_session_channel',
      'Focus Session Alerts',
      channelDescription: 'Alerts and warnings for active focus sessions',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      9001,
      'Focus Session in Progress',
      'Return to Skolar to keep your session alive. Leaving again will cancel your focus.',
      notificationDetails,
    );
  }

  /// Show alert when session is cancelled due to leaving the app.
  static Future<void> showSessionCancelledNotification() async {
    await init();

    const androidDetails = AndroidNotificationDetails(
      'focus_session_channel',
      'Focus Session Alerts',
      channelDescription: 'Alerts and warnings for active focus sessions',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      9002,
      'Focus Session Cancelled',
      'Your session was cancelled because you left the app during focus time.',
      notificationDetails,
    );
  }

  /// Cancel any pending focus notifications.
  static Future<void> cancelAll() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (_) {}
  }
}
