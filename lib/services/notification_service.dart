

// lib/services/notification_service.dart
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart' show kIsWeb;


// lib/services/notification_service.dart
export 'notification_service_stub.dart'
if (dart.library.io) 'notification_service_mobile.dart'
if (dart.library.html) 'notification_service_web.dart';



class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    if (kIsWeb) return; // ★Webは通知をスキップ
    // タイムゾーン初期化
    tz.initializeTimeZones();
    // ★追加：ローカルタイムゾーンを明示設定（例：日本）
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    // 初期化（Android）
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initSettings =
    InitializationSettings(android: androidInit);
    await _fln.initialize(initSettings);

    // Android 13+ の通知許可（新API名：requestNotificationsPermission）
    if (Platform.isAndroid) {
      final enabled = await _fln
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      if (enabled == false) {
        await _fln
            .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission(); // ← ここがポイント
      }

      // 通知チャネル
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'brew_channel',
        'コーヒー・休憩通知',
        description: '摂取履歴に基づく休憩/集中力通知',
        importance: Importance.high,
      );
      await _fln
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  Future<int> showNow({
    required String title,
    required String body,
    String? payload,
  }) async {
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

  Future<int> scheduleAt({
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (kIsWeb) return -1; // ★Webは予約しない
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
      // ★ 新APIで必須になったモード指定（exact にすると遅延少／inexactは省電力）
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: payload,
    );
    return id;
  }

  Future<void> cancel(int id) => _fln.cancel(id);
  Future<void> cancelAll() => _fln.cancelAll();

}
