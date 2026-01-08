
// lib/services/notification_service_mobile.dart
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'notification_service_stub.dart';

class NotificationService implements NotificationServiceBase {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

  @override
  Future<void> init() async {
    tz.initializeTimeZones();

    // ★重要：ローカルロケーションを明示（zonedScheduleが安定）[3](https://fluttergems.dev/notification-toast/)
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final initSettings = InitializationSettings(android: androidInit);
    await _fln.initialize(initSettings);

    if (Platform.isAndroid) {
      final enabled = await _fln
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();

      if (enabled == false) {
        await _fln
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }

      const channel = AndroidNotificationChannel(
        'brew_channel',
        'コーヒー・休憩通知',
        description: '摂取履歴に基づく休憩/集中力通知',
        importance: Importance.high,
      );

      await _fln
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  @override
  Future<int> showNow({required String title, required String body, String? payload}) async {
    final id = DateTime.now().millisecondsSinceEpoch % 0x7fffffff;
    await _fln.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails('brew_channel', 'コーヒー・休憩通知'),
      ),
      payload: payload,
    );
    return id;
  }

  @override
  Future<int> scheduleAt({required DateTime when, required String title, required String body, String? payload}) async {
    final id = DateTime.now().millisecondsSinceEpoch % 0x7fffffff;
    final tzTime = tz.TZDateTime.from(when, tz.local);
    await _fln.zonedSchedule(
      id,
      title,
      body,
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails('brew_channel', 'コーヒー・休憩通知'),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
      //uiLocalNotificationDateInterpretation:
      //UILocalNotificationDateInterpretation.absoluteTime,
    );
    return id;
  }

  @override
  Future<void> cancel(int id) => _fln.cancel(id);

  @override
  Future<void> cancelAll() => _fln.cancelAll();
}
