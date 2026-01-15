
// lib/domain/coffee_recommender.dart
import 'package:flutter/material.dart';
import 'advice.dart';

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
