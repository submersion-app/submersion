import 'package:submersion/core/services/notification_service.dart';

/// Records the kind of every service reminder; every other member no-ops.
class RecordingNotificationService implements NotificationService {
  final reminderKinds = <String>[];

  @override
  Future<int> scheduleServiceReminder({
    required String scheduleId,
    required String equipmentId,
    required String equipmentName,
    required String kindName,
    required String? brandModel,
    required DateTime scheduledDate,
    required int daysBefore,
  }) async {
    reminderKinds.add(kindName);
    return 1;
  }

  @override
  Future<Set<String>> pendingDocumentReminderIds() async => const {};

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}
