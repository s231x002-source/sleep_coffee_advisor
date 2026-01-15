
// lib/domain/advice.dart
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

  Map<String, dynamic> toJson() => {
    'coffeeName': coffeeName,
    'caffeineLevel': caffeineLevel,
    'score': score,
    'totalSleepMin': totalSleep.inMinutes,
  };
}
