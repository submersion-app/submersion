import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/database_service.dart';
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

  /// Document ids with a reminder pending in the OS, as payloads report.
  Set<String> pending = {};

  @override
  Future<Set<String>> pendingDocumentReminderIds() async => pending;

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

  test(
    'scheduleAll schedules a permit\'s two reminders, none for a card',
    () async {
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
    },
  );

  test(
    'updating after the expiry is cleared cancels and schedules none',
    () async {
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
    },
  );

  test('notifications off schedules nothing', () async {
    await save(
      DocumentType.permit,
      DateTime(now.year, now.month, now.day + 60),
    );
    await scheduler.scheduleAll(
      settings: const AppSettings(notificationsEnabled: false),
      diverId: 'd1',
    );
    expect(service.scheduled, isEmpty);
  });

  test('a full schedule cancels reminders of documents that are gone or no '
      'longer remind', () async {
    final permit = await save(
      DocumentType.permit,
      DateTime(now.year, now.month, now.day + 60),
    );
    final undated = await save(DocumentType.permit, null);
    service.pending = {permit.id, undated.id, 'deleted-elsewhere'};
    await scheduler.scheduleAll(settings: const AppSettings(), diverId: 'd1');
    expect(service.cancelled, containsAll([undated.id, 'deleted-elsewhere']));
    expect(service.scheduled.map((s) => s.documentId).toSet(), {permit.id});
  });

  test('a full schedule refreshes another profile\'s pending reminders with '
      'its current expiry', () async {
    await DatabaseService.instance.database.customStatement(
      'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
      "VALUES ('d2', 'Ben', 0, 0, 0)",
    );
    // Renewed on another device while d1 is the active profile: the
    // pending reminders still carry the old expiry.
    final renewed = await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'd2',
        owner: const DocumentOwner.personal(),
        type: DocumentType.insurance,
        title: 'DAN',
        expiryDate: DateTime(now.year + 1, now.month, now.day),
        createdAt: now,
        updatedAt: now,
      ),
      const [],
    );
    service.pending = {renewed.id};
    await scheduler.scheduleAll(settings: const AppSettings(), diverId: 'd1');
    expect(service.cancelled, contains(renewed.id));
    expect(
      service.scheduled.where((s) => s.documentId == renewed.id),
      isNotEmpty,
    );
  });

  test('the background refresh, with no active profile, refreshes pending '
      'reminders too', () async {
    final permit = await save(
      DocumentType.permit,
      DateTime(now.year, now.month, now.day + 60),
    );
    service.pending = {permit.id};
    await scheduler.scheduleAll(settings: const AppSettings());
    expect(service.scheduled.map((s) => s.documentId).toSet(), {permit.id});
  });
}
