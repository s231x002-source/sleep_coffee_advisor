
// services/schedule_service.dart
import 'package:intl/intl.dart';

class ScheduleService {
  /// 休憩通知：カフェイン摂取（=提案確定）から 4 時間後
  DateTime restAfterCaffeine(DateTime intakeLocalTime) {
    return intakeLocalTime.add(const Duration(hours: 4));
  }

  /// 集中力予測：スコアに応じて「落ち始め区間」を返す例（簡易モデル）
  /// 例：scoreが低いほど早く落ちる → 今から (11 - round(score)) 時間後など
  DateTime concentrationDrop(DateTime nowLocal, double score) {
    final hours = (11 - score.round()).clamp(1, 8);
    return nowLocal.add(Duration(hours: hours));
  }

  String fmt(DateTime dt) => DateFormat('HH:mm').format(dt);
}
