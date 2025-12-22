
// lib/services/notification_service_stub.dart
abstract class NotificationServiceBase {
  Future<void> init();
  Future<int> showNow({
    required String title,
    required String body,
    String? payload,
  });

  Future<int> scheduleAt({
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  });
  Future<void> cancel(int id);
  Future<void> cancelAll();
}
