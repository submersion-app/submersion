import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_reminder_plan.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/notifications/data/services/notification_scheduler.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

/// Records document reminder calls; every other member no-ops.
class _FakeNotificationService implements NotificationService {
  final scheduled =
      <({String documentId, String title, DocumentReminderStage stage})>[];
  final cancelled = <String>[];

  @override
  Future<int> scheduleDocumentReminder({
    required String documentId,
    required String title,
    required String body,
    required DocumentReminderStage stage,
    required DateTime scheduledDate,
  }) async {
    scheduled.add((documentId: documentId, title: title, stage: stage));
    return 1;
  }

  @override
  Future<void> cancelDocumentReminders(String documentId) async {
    cancelled.add(documentId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final name = invocation.memberName.toString();
    if (name.contains('schedule')) return Future.value(0);
    return Future.value();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeNotificationService service;
  late NotificationScheduler scheduler;
  final now = DateTime.now();

  setUp(() async {
    final db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d1', 'Ana', 1, 0, 0)",
    );
    service = _FakeNotificationService();
    scheduler = NotificationScheduler(notificationService: service);
  });
  tearDown(tearDownTestDatabase);

  Future<Document> save(DocumentType type, DateTime? expiry) =>
      DocumentRepository().save(
        Document(
          id: '',
          diverId: 'd1',
          owner: const DocumentOwner.personal(),
          type: type,
          title: 'Marine park',
          expiryDate: expiry,
          createdAt: now,
          updatedAt: now,
        ),
        const [],
      );

  test('scheduleAll schedules a permit\'s two reminders, none for a card', () async {
    final permit = await save(
      DocumentType.permit,
      DateTime(now.year, now.month, now.day + 60),
    );
    await save(
      DocumentType.certificationCard,
      DateTime(now.year, now.month, now.day + 60),
    );
    await scheduler.scheduleAll(settings: const AppSettings(), diverId: 'd1');
    expect(service.scheduled.map((s) => s.documentId).toSet(), {permit.id});
    expect(service.scheduled.map((s) => s.stage), [
      DocumentReminderStage.lead,
      DocumentReminderStage.expiryDay,
    ]);
    expect(service.scheduled.first.title, 'Marine park expires soon');
  });

  test('updating after the expiry is cleared cancels and schedules none', () async {
    final permit = await save(
      DocumentType.permit,
      DateTime(now.year, now.month, now.day + 60),
    );
    await scheduler.updateForDocument(
      permit.copyWith(expiryDate: null),
      const AppSettings(),
    );
    expect(service.cancelled, [permit.id]);
    expect(service.scheduled, isEmpty);
  });

  test('notifications off schedules nothing', () async {
    await save(DocumentType.permit, DateTime(now.year, now.month, now.day + 60));
    await scheduler.scheduleAll(
      settings: const AppSettings(notificationsEnabled: false),
      diverId: 'd1',
    );
    expect(service.scheduled, isEmpty);
  });

  test('a deleted document has its reminders cancelled', () async {
    await scheduler.cancelForDocument('gone');
    expect(service.cancelled, ['gone']);
  });
}
