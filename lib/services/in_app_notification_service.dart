
// lib/services/in_app_notification_service.dart
import 'dart:async';
import 'package:flutter/material.dart';

class InAppNotificationService {
  InAppNotificationService._();
  static final instance = InAppNotificationService._();

  GlobalKey<ScaffoldMessengerState>? _messengerKey;
  final Map<int, Timer> _timers = {};

  /// MaterialApp の scaffoldMessengerKey を渡してバインドする
  void bind(GlobalKey<ScaffoldMessengerState> key) {
    _messengerKey ??= key; // 何度呼ばれてもOK
  }

  int _newId() => DateTime.now().millisecondsSinceEpoch % 0x7fffffff;

  Future<int> showNow({
    required String title,
    required String body,
    String? payload,
    Duration duration = const Duration(seconds: 6),
  }) async {
    final id = _newId();
    final messenger = _messengerKey?.currentState;

    if (messenger == null) {
      // まだMaterialAppが立ち上がっていない等
      debugPrint('InAppNotificationService: messenger not ready');
      return id;
    }

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$title\n$body'),
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return id;
  }

  Future<int> scheduleAt({
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    final id = _newId();
    final delay = when.difference(DateTime.now());

    if (delay.isNegative) {
      // 過去の時間なら即表示
      await showNow(title: title, body: body, payload: payload);
      return id;
    }

    _timers[id]?.cancel();
    _timers[id] = Timer(delay, () async {
      await showNow(title: title, body: body, payload: payload);
    });

    return id;
  }

  Future<void> cancel(int id) async {
    _timers.remove(id)?.cancel();
  }

  Future<void> cancelAll() async {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
  }
}
