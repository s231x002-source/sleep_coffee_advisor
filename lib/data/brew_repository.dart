
// lib/data/brew_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class BrewRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance; // ← フィールドで定義

  Future<DocumentReference<Map<String, dynamic>>> addBrew({
    required String uid,
    required int wakeFeeling,
    required String bedTime,
    required String wakeTime,
    required Map<String, dynamic>? advice,
  }) async {
    return await _db
        .collection('users')
        .doc(uid)
        .collection('brews')
        .add({
      'timestamp': FieldValue.serverTimestamp(),
      'wakeFeeling': wakeFeeling,
      'bedTime': bedTime,
      'wakeTime': wakeTime,
      'advice': advice,
    });
  }

  Future<void> addNotificationPlan({
    required String uid,
    required String type, // 'rest' or 'focus'
    required DateTime scheduledAt,
    required int notificationId,
    String? brewId,
  }) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .add({
      'type': type,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'notificationId': notificationId,
      'brewId': brewId,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'scheduled',
    });
  }
}