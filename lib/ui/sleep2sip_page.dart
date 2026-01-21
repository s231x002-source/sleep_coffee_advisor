
// lib/ui/sleep2sip_page.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../controllers/home_controller.dart';
import '../data/brew_repository.dart';
import '../domain/advice.dart';
import '../domain/coffee_recommender.dart';
import '../services/schedule_service.dart';
// 追加
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import '../services/in_app_notification_service.dart';
import 'coffee_nap_timer_page.dart';
import 'widgets/app_background.dart'; // 追加
import '../services/auth_service.dart';



class Sleep2SipPage extends StatefulWidget {
  const Sleep2SipPage({
    super.key,
    this.debugShortDelays = false,
    this.enableSaveAndNotify = true,
  });

  /// デバッグ用：通知を数秒後に出すか（本番では false 推奨）
  final bool debugShortDelays;

  /// Firestore保存＋通知予約を実行するか（まずUIだけ確認したいなら false）
  final bool enableSaveAndNotify;

  @override
  State<Sleep2SipPage> createState() => _Sleep2SipPageState();
}

class _Sleep2SipPageState extends State<Sleep2SipPage> {
  // --- 状態 ---
  double _condition = 6; // 起床時の調子（1〜10）
  TimeOfDay _sleepTime = const TimeOfDay(hour: 23, minute: 30);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  bool _force24h = true;

  final _scheduler = ScheduleService();

  Advice? _advice;

  // --- 依存 ---
  late final HomeController _controller = HomeController(
    repo: BrewRepository(),
    scheduler: ScheduleService(),
    recommender: CoffeeRecommender(),
  );

  // --- テーマカラー（Sleep2Sipデザイン） ---
  final Color coffeeDark = const Color(0xFF6B4F3A);
  final Color coffeeMilk = const Color(0xFFDCC4A2);
  final Color coffeeLatte = const Color(0xFFF7EFE5);
  final Color coffeeAccent = const Color(0xFFB07B52);

  // --- TimePicker ---
  Future<void> _pickTime(bool isSleepTime) async {
    final initial = isSleepTime ? _sleepTime : _wakeTime;

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isSleepTime ? '就寝時刻を選択' : '起床時刻を選択',
      builder: (context, child) {
        // 24時間表記を強制したい場合
        final media = MediaQuery.of(context);
        final themed = Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(primary: coffeeAccent),
          ),
          child: MediaQuery(
            data: media.copyWith(
              alwaysUse24HourFormat:
              _force24h ? true : media.alwaysUse24HourFormat,
            ),
            child: child!,
          ),
        );
        return themed;
      },
    );

    if (picked != null) {
      setState(() {
        if (isSleepTime) {
          _sleepTime = picked;
        } else {
          _wakeTime = picked;
        }
      });
    }
  }

  // --- 分析（既存の CoffeeRecommender を使う） ---
  Future<void> _analyze() async {
    final advice = _controller.calculate(
      bedTime: _sleepTime,
      wakeTime: _wakeTime,
      wakeFeeling: _condition,
    );

    setState(() => _advice = advice);

    // 保存・通知は任意（UIだけならオフでOK）
    //if (widget.enableSaveAndNotify) {
      //await _controller.saveAndSchedule(
        //advice: advice,
        //wakeFeeling: _condition.round(),
        //bedTimeText: _fmt(_sleepTime),
        //wakeTimeText: _fmt(_wakeTime),
        //debugShortDelays: widget.debugShortDelays,
      //);
    //}

    if (widget.enableSaveAndNotify) {
      await _saveBrewHistoryAndSchedule();
    }

  }


  /// ✅ 保存 + 通知（集中力低下タイミング予測通知を含む）
  Future<void> _saveBrewHistoryAndSchedule() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('No UID: not signed in');
      return;
    }

    // ---- 1) Firestore 保存 ----
    try {
      final advice = _advice;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('brews')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'wakeFeeling': _condition.round(),
        'bedTime': _fmt(_sleepTime),
        'wakeTime': _fmt(_wakeTime),
        'advice': advice == null
            ? null
            : {
          'coffeeName': advice.coffeeName,
          'caffeineLevel': advice.caffeineLevel,
          'score': advice.score,
          'totalSleepMin': advice.totalSleep.inMinutes,
        },
      });

      debugPrint('Brew history saved!');
    } catch (e, st) {
      debugPrint('Save failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存に失敗しました')),
        );
      }
      // 保存が失敗しても通知予約は続ける/やめるは好み
      // ここでは HomePage と同様に続行する構成でもOK
    }

    // ---- 2) 通知スケジューリング（集中力低下含む）----
    final now = DateTime.now();

    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    // まず「予約した」ことが分かるように即時アプリ内通知
    await InAppNotificationService.instance.showNow(
      title: '通知を予約しました',
      body: widget.debugShortDelays
          ? '（デバッグ）数秒後に通知します'
          : '指定時刻にリマインドします',
      payload: 'scheduled',
    );

    // デバッグ時は短い遅延にする
    final restAt = widget.debugShortDelays
        ? now.add(const Duration(seconds: 5))
        : _scheduler.restAfterCaffeine(now);

    DateTime? dropAt;
    if (_advice != null) {
      dropAt = widget.debugShortDelays
          ? now.add(const Duration(seconds: 10))
          : _scheduler.concentrationDrop(now, _advice!.score);
    }

    const restBody = '摂取から4時間経過。軽いストレッチや目の休息を。';
    const focusBody = 'そろそろ集中力が落ち始めます。5〜10分の休憩がおすすめ。';

    // 休憩（アプリ内）
    await InAppNotificationService.instance.scheduleAt(
      when: restAt,
      title: '休憩のタイミングです',
      body: restBody,
      payload: 'rest',
    );

    // 集中力低下（アプリ内）
    if (dropAt != null) {
      await InAppNotificationService.instance.scheduleAt(
        when: dropAt,
        title: '集中力の低下タイミング予測',
        body: focusBody,
        payload: 'focus',
      );
    }

    // モバイルのみ：OS通知も予約（将来の確認用）
    if (isMobile) {
      await NotificationService.instance.scheduleAt(
        when: restAt,
        title: '休憩のタイミングです',
        body: restBody,
        payload: 'rest',
      );

      if (dropAt != null) {
        await NotificationService.instance.scheduleAt(
          when: dropAt,
          title: '集中力の低下タイミング予測',
          body: focusBody,
          payload: 'focus',
        );
      }
    }
  }


  int _recommendedNapMinutes(Advice advice) {
    // 例：カフェインレベルが高いほど短めのナップを推奨
    if (advice.caffeineLevel >= 8) return 10;
    if (advice.caffeineLevel >= 6) return 15;
    if (advice.caffeineLevel >= 4) return 20;
    return 25;
  }


  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // scroll UI と共存するので、ここは各タブで独立した Scaffold でOK
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 12),

                // --- Title ---
                Text(
                  "Sleep2Sip",
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: coffeeLatte,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        color: Colors.black.withOpacity(0.30),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "今日のコンディションに合う一杯を提案します",
                  style: TextStyle(
                    fontSize: 15,
                    color: coffeeLatte.withOpacity(0.95),
                  ),
                ),
                const SizedBox(height: 25),

// ✅ ログイン状態表示＆ボタン
                Align(
                  alignment: Alignment.centerRight,
                  child: StreamBuilder<User?>(
                    stream: FirebaseAuth.instance.authStateChanges(),
                    builder: (context, snapshot) {
                      final user = snapshot.data;

                      final bool isSignedIn = user != null;
                      final bool isAnonymous = user?.isAnonymous ?? true;

                      // 表示文言
                      final statusText = !isSignedIn
                          ? '未ログイン'
                          : (isAnonymous ? 'ゲスト(匿名)利用中' : 'Googleでログイン中');

                      // ボタン
                      if (isSignedIn && !isAnonymous) {
                        // Googleログイン中 → ログアウト
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(statusText, style: TextStyle(color: coffeeLatte)),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await AuthService.instance.signOut();
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text('ログアウト'),
                            ),
                          ],
                        );
                      } else {
                        // ゲスト/未ログイン → Googleログイン（匿名なら link で昇格）
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(statusText, style: TextStyle(color: coffeeLatte)),
                            const SizedBox(height: 6),
                            FilledButton.icon(
                              onPressed: () async {
                                try {
                                  await AuthService.instance.signInWithGoogleOrLink();
                                } on FirebaseAuthException catch (e) {
                                  // canceled など
                                  debugPrint('Google sign-in failed: ${e.code} ${e.message}');
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('ログインに失敗しました: ${e.code}')),
                                  );
                                } catch (e) {
                                  debugPrint('Google sign-in error: $e');
                                }
                              },
                              icon: const Icon(Icons.login),
                              label: const Text('Googleでログイン'),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),


                // --- 1. Condition Slider ---
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label("1. 起きた時の調子（1〜10）"),
                      const SizedBox(height: 10),
                      Slider(
                        value: _condition,
                        min: 1,
                        max: 10,
                        divisions: 9,
                        activeColor: coffeeAccent,
                        inactiveColor: coffeeMilk,
                        onChanged: (v) => setState(() => _condition = v),
                      ),
                      Center(
                        child: Text(
                          "${_condition.toInt()} / 10",
                          style: TextStyle(
                            fontSize: 18,
                            color: coffeeDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // --- 2. Sleep/Wake Time ---
                _glassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label("2. 時刻（24時間表記）"),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _timeBox(
                              title: "就寝時刻",
                              value: _sleepTime.format(context),
                              onTap: () => _pickTime(true),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _timeBox(
                              title: "起床時刻",
                              value: _wakeTime.format(context),
                              onTap: () => _pickTime(false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '24時間表記を強制',
                          style: TextStyle(color: coffeeDark),
                        ),
                        value: _force24h,
                        onChanged: (v) => setState(() => _force24h = v),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // --- Analyze Button ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: coffeeAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 35,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                      elevation: 5,
                    ),
                    onPressed: _analyze,
                    child: const Text(
                      "提案する",
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // --- Result (fade-in) ---
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 600),
                  opacity: _advice == null ? 0 : 1,
                  child: _advice == null
                      ? const SizedBox()
                      : _glassCard(
                    child: _ResultBlock(
                      advice: _advice!,
                      coffeeDark: coffeeDark,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                _glassCard(
                  child: ListTile(
                    leading: const Icon(Icons.timer_rounded),
                    title: const Text('コーヒーナップタイマー'),
                    subtitle: const Text('コーヒーを飲んだあと短時間のお昼寝用タイマー'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CoffeeNapTimerPage(initialMinutes: 20),
                        ),
                      );
                    },
                  ),
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Text _label(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: coffeeDark,
      ),
    );
  }

  /// ガラス風カード（BackdropFilter）
  Widget _glassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ),
      ),
    );
  }

  /// 時刻選択ボックス（デザイン）
  Widget _timeBox({
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.60),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: coffeeMilk),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: coffeeDark,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: coffeeDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 結果表示ブロック（Advice を使って表示）
class _ResultBlock extends StatelessWidget {
  const _ResultBlock({
    required this.advice,
    required this.coffeeDark,
  });

  final Advice advice;
  final Color coffeeDark;

  @override
  Widget build(BuildContext context) {
    final h = advice.totalSleep.inHours;
    final m = advice.totalSleep.inMinutes % 60;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "分析結果",
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: coffeeDark,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "総睡眠時間：${h}時間${m}分",
          style: TextStyle(color: coffeeDark),
        ),
        const SizedBox(height: 6),
        Text(
          "総合スコア：${advice.score.toStringAsFixed(1)} / 10",
          style: TextStyle(color: coffeeDark),
        ),
        const SizedBox(height: 12),
        Text(
          "おすすめは：${advice.coffeeName}",
          style: TextStyle(
            fontSize: 22,
            color: coffeeDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "カフェインレベル：${advice.caffeineLevel} / 10",
          style: TextStyle(color: coffeeDark),
        ),
      ],
    );
  }
}

