
// lib/services/notification_service_web.dart
import 'dart:async';
import 'dart:html' as html;
import 'notification_service_stub.dart';

class NotificationService implements NotificationServiceBase {
  NotificationService._();
  static final instance = NotificationService._();

  final Map<int, Timer> _timers = {};

  @override
  Future<void> init() async {
    // Webではここで権限を要求しても良いが、
    // ブラウザは「ユーザー操作中じゃないと許可ダイアログが出ない」ことがあるので、
    // ボタン押下（提案する）などのタイミングで requestPermission を呼ぶのが確実。
  }

  Future<void> _ensurePermission() async {
    if (html.Notification.permission != 'granted') {
      await html.Notification.requestPermission();
    }
  }

  @override
  Future<int> showNow({required String title, required String body, String? payload}) async {
    await _ensurePermission();
    final id = DateTime.now().millisecondsSinceEpoch % 0x7fffffff;

    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    } else {
      // 権限拒否の場合は何もしない/または画面内通知にフォールバック
    }
    return id;
  }

  @override
  Future<int> scheduleAt({required DateTime when, required String title, required String body, String? payload}) async {
    await _ensurePermission();
    final id = DateTime.now().millisecondsSinceEpoch % 0x7fffffff;

    final delay = when.difference(DateTime.now());
    if (delay.isNegative) return id;

    _timers[id] = Timer(delay, () {
      if (html.Notification.permission == 'granted') {
        html.Notification(title, body: body);
      }
    });
    return id;
  }

  @override
  Future<void> cancel(int id) async {
    _timers.remove(id)?.cancel();
  }

  @override
  Future<void> cancelAll() async {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }
}
