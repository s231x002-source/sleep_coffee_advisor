
// lib/controllers/home_controller.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';

import '../data/brew_repository.dart';
import '../domain/advice.dart';
import '../domain/coffee_recommender.dart';
import '../services/in_app_notification_service.dart';
import '../services/notification_service.dart';
import '../services/schedule_service.dart';

class HomeController {
  HomeController({
    required BrewRepository repo,
    required ScheduleService scheduler,
    required CoffeeRecommender recommender,
  })  : _repo = repo,
        _scheduler = scheduler,
        _recommender = recommender;

  final BrewRepository _repo;
  final ScheduleService _scheduler;
  final CoffeeRecommender _recommender;

  bool get _isMobile =>
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);


  Advice calculate({
    required TimeOfDay bedTime,
    required TimeOfDay wakeTime,
    required double wakeFeeling,
  }) {
    return _recommender.advise(
      bedTime: bedTime,
      wakeTime: wakeTime,
      wakeFeeling: wakeFeeling,
    );
  }

  /// 保存 + 通知予約（アプリ内 / モバイルOS）
  Future<void> saveAndSchedule({
    required Advice advice,
    required int wakeFeeling,
    required String bedTimeText,
    required String wakeTimeText,
    required bool debugShortDelays,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('No UID: not signed in');
      return;
    }

    // 1) Brew保存
    final brewRef = await _repo.addBrew(
      uid: uid,
      wakeFeeling: wakeFeeling,
      bedTime: bedTimeText,
      wakeTime: wakeTimeText,
      advice: advice.toJson(),
    );

    // 2) 予約時刻計算
    final now = DateTime.now();
    final restAt = debugShortDelays
        ? now.add(const Duration(seconds: 5))
        : _scheduler.restAfterCaffeine(now);

    final dropAt = debugShortDelays
        ? now.add(const Duration(seconds: 10))
        : _scheduler.concentrationDrop(now, advice.score);

    // 3) “予約した” 即時表示（アプリ内）
    await InAppNotificationService.instance.showNow(
      title: '通知を予約しました',
      body: '指定時刻にリマインドします',
      payload: 'scheduled',
    );

    const restBody = '摂取から4時間経過。軽いストレッチや目の休息を。';
    const focusBody = 'そろそろ集中力が落ち始めます。5〜10分の休憩がおすすめ。';

    // 4) アプリ内通知のスケジュール
    final restInAppId = await InAppNotificationService.instance.scheduleAt(
      when: restAt,
      title: '休憩のタイミングです',
      body: restBody,
      payload: 'rest',
    );

    final focusInAppId = await InAppNotificationService.instance.scheduleAt(
      when: dropAt,
      title: '集中力の低下タイミング予測',
      body: focusBody,
      payload: 'focus',
    );

    // 5) Firestoreに通知計画も保存（統合しやすい）
    await _repo.addNotificationPlan(
      uid: uid,
      type: 'rest',
      scheduledAt: restAt,
      notificationId: restInAppId,
      brewId: brewRef.id,
    );

    await _repo.addNotificationPlan(
      uid: uid,
      type: 'focus',
      scheduledAt: dropAt,
      notificationId: focusInAppId,
      brewId: brewRef.id,
    );

    // 6) モバイルのみ OS通知も併用
    if (_isMobile) {
      // NotificationService は conditional export で Web では Web 実装に。
      final restOsId = await NotificationService.instance.scheduleAt(
        when: restAt,
        title: '休憩のタイミングです',
        body: restBody,
        payload: 'rest',
      );

      final focusOsId = await NotificationService.instance.scheduleAt(
        when: dropAt,
        title: '集中力の低下タイミング予測',
        body: focusBody,
        payload: 'focus',
      );

      // OS通知のIDも保存したいなら追加で notifications に書くのもアリ
      //（例：type を 'rest_os' / 'focus_os' にするとメンバーと衝突しにくい）
      await _repo.addNotificationPlan(
        uid: uid,
        type: 'rest_os',
        scheduledAt: restAt,
        notificationId: restOsId,
        brewId: brewRef.id,
      );

      await _repo.addNotificationPlan(
        uid: uid,
        type: 'focus_os',
        scheduledAt: dropAt,
        notificationId: focusOsId,
        brewId: brewRef.id,
      );
    }
  }
}
