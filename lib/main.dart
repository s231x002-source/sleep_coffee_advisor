//newbranch1での作業test
//hello
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// ★ 追加：Firebase Core をインポート
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ★ 追加：flutterfire configure が生成したオプション
import 'firebase_options.dart';






void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  //匿名ログイン（未ログイン時のみ）
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      await auth.signInAnonymously();
      debugPrint('Signed in anonymously. uid=${auth.currentUser?.uid}');
    } on FirebaseAuthException catch (e) {
      debugPrint('Anonymous sign-in failed: ${e.code} ${e.message}');
      // 失敗してもアプリは起動できるようにする（必要ならリトライUIを用意）
    }
  } else {
    debugPrint('Already signed in. uid=${auth.currentUser?.uid}');
  }

  runApp(const SleepCoffeeApp());
}

class SleepCoffeeApp extends StatelessWidget {
  const SleepCoffeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '睡眠×コーヒー提案',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        fontFamily: 'NotoSansJP',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        fontFamily: 'NotoSansJP',
      ),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const <Locale>[
        Locale('ja'),
        Locale('en'),
      ],
      home: const HomePage(),
    );
  }
}

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
    _saveBrewHistory();
  }

  Future<void> _saveBrewHistory() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('No UID: not signed in');
      return;
    }

    try {
      final advice = _advice; // 計算結果（nullの可能性あり）
      await FirebaseFirestore.instance
          .collection('users').doc(uid)
          .collection('brews')
          .add({
        'timestamp': FieldValue.serverTimestamp(), // サーバ時刻
        'wakeFeeling': _feeling.round(),           // 起床時の調子（1–10）
        'bedTime': _fmt(_bed),                     // 就寝時刻（"23:30"）
        'wakeTime': _fmt(_wake),                   // 起床時刻（"07:00"）
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
                          // $h 形式のlint対応: こちらは数値ではないが braceなしでOKな箇所のみ修正
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
                  fontWeight: FontWeight.w700) ??
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
  const _TimeField({required this.label, required this.value, required this.onTap, super.key});
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

class Advice {
  final Duration totalSleep;
  final double score;
  final String coffeeName;
  final int caffeineLevel;
  const Advice({
    required this.totalSleep,
    required this.score,
    required this.coffeeName,
    required this.caffeineLevel,
  });
}

class CoffeeRecommender {
  Advice advise({
    required TimeOfDay bedTime,
    required TimeOfDay wakeTime,
    required double wakeFeeling,
  }) {
    final total = _calcTotalSleep(bedTime, wakeTime);
    const target = Duration(hours: 8);
    final qtyScore =
        (10.0 - ((total - target).inMinutes.abs() / 30.0)).clamp(0, 10).toDouble();
    final score = ((qtyScore + wakeFeeling) / 2).clamp(0, 10).toDouble();
    final caffeine = (11 - score.round()).clamp(1, 10);
    final name = _nameFromLevel(caffeine);
    return Advice(
      totalSleep: total,
      score: score,
      coffeeName: name,
      caffeineLevel: caffeine,
    );
  }

  Duration _calcTotalSleep(TimeOfDay bed, TimeOfDay wake) {
    final bedM = bed.hour * 60 + bed.minute;
    final wakeM = wake.hour * 60 + wake.minute;
    var diff = wakeM - bedM;
    if (diff <= 0) diff += 24 * 60;
    return Duration(minutes: diff);
  }

  String _nameFromLevel(int level) {
    if (level >= 8) return 'エスプレッソ ダブル';
    if (level >= 6) return 'ドリップ（深煎り）';
    if (level >= 4) return 'アメリカーノ（薄め）';
    if (level >= 2) return 'カフェラテ';
    return 'デカフェ / ハーブティー';
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
          Text('総睡眠時間：$h時間$m分'),
          Text('総合スコア：${advice.score.toStringAsFixed(1)} / 10'),
          if (h == 24 && m == 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '就寝と起床が同じ時刻です。翌日の起床として計算しました。',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
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
