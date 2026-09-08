import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotify {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static VoidCallback? onOpen;
  static const channel = AndroidNotificationChannel(
    'mrsos_alerts',
    'Avisos de MRSoS',
    description: 'Tickets, reuniones y visitas de soporte',
    importance: Importance.high,
  );

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@drawable/ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (_) => onOpen?.call(),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
      _initialized = true;
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) onOpen?.call();
    } catch (_) {
      _initialized = false;
    }
  }

  static Future<bool> requestPermission() async {
    await init();
    if (!_initialized) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true) ??
        false;
  }

  static Future<void> clear() async {
    if (_initialized) await _plugin.cancelAll();
  }

  static Future<void> show({
    required String title,
    required String body,
    int? id,
  }) async {
    await init();
    if (!_initialized) return;
    await _plugin.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mrsos_alerts',
          'Avisos de MRSoS',
          icon: '@drawable/ic_notification',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          presentBadge: false,
        ),
      ),
      payload: 'inbox',
    );
  }
}
