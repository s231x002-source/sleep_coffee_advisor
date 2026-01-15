
// lib/ui/home_page.dart
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/notification_service.dart';
import '../services/schedule_service.dart';
import '../services/in_app_notification_service.dart';

import '../domain/advice.dart';
import '../domain/coffee_recommender.dart';

// ✅ いったんここに置く（後で config.dart に移してOK）
const bool DEBUG_SHORT_DELAYS = true;

// ここに main.dart にあった HomePage を移植してください。
// いまは「UIの置き場を移す」のが目的なので、ロジックは後でcontroller化してOKです。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  TimeOfDay _bed = const TimeOfDay(hour: 23, minute: 30);
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  double _feeling = 6;
  Advice? _advice;
  late final CoffeeRecommender _recommender = CoffeeRecommender();
  bool _force24h = true;

  final _scheduler = ScheduleService();

  Future<void> _pickTime({required bool isBed}) async {
    final picked = await showTimePicker(
      context: context,
      helpText: isBed ? '就寝時刻を選択' : '起床時刻を選択',
      initialTime: isBed ? _bed : _wake,
      initialEntryMode: TimePickerEntryMode.dial,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            alwaysUse24HourFormat: _force24h ? true : media.alwaysUse24HourFormat,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => isBed ? _bed = picked : _wake = picked);
    }
  }

  void _calculate() {
    setState(() {
      _advice = _recommender.advise(
        bedTime: _bed,
        wakeTime: _wake,
        wakeFeeling: _feeling,
      );
    });
    _saveBrewHistoryAndSchedule();
  }

  /// ✅ 保存 + 通知（Web/デスクトップはSnackBar、モバイルはOS通知も併用）
  Future<void> _saveBrewHistoryAndSchedule() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('No UID: not signed in');
      return;
    }

    try {
      final advice = _advice;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('brews')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'wakeFeeling': _feeling.round(),
        'bedTime': _fmt(_bed),
        'wakeTime': _fmt(_wake),
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
    }

    // ✅ ここから通知スケジューリング
    final now = DateTime.now();

    // Web/デスクトップ：アプリ内通知
    // モバイル：アプリ内通知 + OS通知（将来の確認用）

    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

    // まず「予約した」ことが分かるように即時SnackBar
    await InAppNotificationService.instance.showNow(
      title: '通知を予約しました',
      body: DEBUG_SHORT_DELAYS
          ? '指定時刻にリマインドします'
          : '指定時刻にリマインドします',
      payload: 'scheduled',
    );


// テストしやすい短い遅延に切替（遅延だけデバッグ、文言は本番のまま）
    final restAt = DEBUG_SHORT_DELAYS
        ? now.add(const Duration(seconds: 5))
        : _scheduler.restAfterCaffeine(now);

    DateTime? dropAt;
    if (_advice != null) {
      dropAt = DEBUG_SHORT_DELAYS
          ? now.add(const Duration(seconds: 10))
          : _scheduler.concentrationDrop(now, _advice!.score);
    }

// ✅ 表示したい本番文言
    const restBody = '摂取から4時間経過。軽いストレッチや目の休息を。';
    const focusBody = 'そろそろ集中力が落ち始めます。5〜10分の休憩がおすすめ。';

// （任意）デバッグ中だと分かる注記だけ追加（本文自体は変えない）
    final restBodyShown =
    DEBUG_SHORT_DELAYS ? '$restBody' : restBody;

    final focusBodyShown =
    DEBUG_SHORT_DELAYS ? '$focusBody' : focusBody;

// 休憩（アプリ内）
    await InAppNotificationService.instance.scheduleAt(
      when: restAt,
      title: '休憩のタイミングです',
      body: restBodyShown,
      payload: 'rest',
    );

// 集中力低下（アプリ内）
    if (dropAt != null) {
      await InAppNotificationService.instance.scheduleAt(
        when: dropAt,
        title: '集中力の低下タイミング予測',
        body: focusBodyShown,
        payload: 'focus',
      );
    }


    // ✅ モバイルのみ：OS通知も併用（将来スマホで「本物の通知」が出ることを確認するため）
    if (isMobile) {
      await NotificationService.instance.scheduleAt(
        when: restAt,
        title: '休憩のタイミングです',
        body: '摂取から4時間経過。軽いストレッチや目の休息を。',
        payload: 'rest',
      );
      if (dropAt != null) {
        await NotificationService.instance.scheduleAt(
          when: dropAt,
          title: '集中力の低下タイミング予測',
          body: 'そろそろ集中力が落ち始めます。5〜10分の休憩がおすすめ。',
          payload: 'focus',
        );
      }
    }
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('睡眠×コーヒー提案'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [cs.primaryContainer, cs.secondaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bedtime_rounded, color: cs.onPrimaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '今日のコンディションに合う一杯を提案します',
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                        softWrap: true,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const _SectionTitle('1. 起きた時の調子（1〜10）'),
              Card.outlined(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: '起きた時の調子',
                          value: _feeling.toStringAsFixed(0),
                          hint: '1から10の間で選択',
                          child: Slider(
                            min: 1,
                            max: 10,
                            divisions: 9,
                            value: _feeling,
                            label: _feeling.toStringAsFixed(0),
                            onChanged: (v) => setState(() => _feeling = v),
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 48,
                        child: Text(
                          '',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _SectionTitle('2. 時刻（24時間表記）'),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: '就寝時刻',
                      value: _fmt(_bed),
                      onTap: () => _pickTime(isBed: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: '起床時刻',
                      value: _fmt(_wake),
                      onTap: () => _pickTime(isBed: false),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('24時間表記を強制'),
                  value: _force24h,
                  onChanged: (v) => setState(() => _force24h = v),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.local_cafe_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('提案する'),
                  ),
                  onPressed: _calculate,
                ),
              ),
              const SizedBox(height: 16),
              if (_advice != null) _ResultCard(advice: _advice!),
              const SizedBox(height: 24),
              Text('Flutter (Material 3) Demo', style: TextStyle(color: cs.outline)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ) ??
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.schedule_rounded),
        ).copyWith(labelText: label),
        child: Text(
          value,
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final Advice advice;
  const _ResultCard({required this.advice});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = advice.totalSleep.inHours;
    final m = advice.totalSleep.inMinutes % 60;

    late final Color badge;
    if (advice.caffeineLevel >= 8) {
      badge = Colors.redAccent;
    } else if (advice.caffeineLevel >= 5) {
      badge = cs.primary;
    } else if (advice.caffeineLevel >= 3) {
      badge = Colors.teal;
    } else {
      badge = Colors.blueGrey;
    }

    return Card.outlined(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('分析結果',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('総睡眠時間：${h}時間${m}分'),
          Text('総合スコア：${advice.score.toStringAsFixed(1)} / 10'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.local_cafe_rounded, color: badge),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        advice.coffeeName,
                        style: TextStyle(
                          color: badge,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('カフェインレベル：${advice.caffeineLevel} / 10',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
