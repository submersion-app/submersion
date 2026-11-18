import 'dart:async';

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
      <
        ({
          String documentId,
          String diverId,
          String title,
          DocumentReminderStage stage,
        })
      >[];
  final cancelled = <String>[];

  /// Every schedule and cancel, in order, as `schedule:<id>` or
  /// `cancel:<id>`.
  final log = <String>[];

  /// Runs while a full schedule reads the pending reminders: after it has
  /// read the documents that remind.
  Future<void> Function()? onPending;

  /// Documents with a reminder pending in the OS and the diver each
  /// payload names, null for a payload from before it named one.
  Map<String, String?> pending = {};

  @override
  Future<Map<String, String?>> pendingDocumentReminders() async {
    await onPending?.call();
    return pending;
  }

  @override
  Future<Set<String>> pendingDraftReminderIds() async => const {};

  @override
  Future<int> scheduleDocumentReminder({
    required String documentId,
    required String diverId,
    required String title,
    required String body,
    required DocumentReminderStage stage,
    required DateTime scheduledDate,
  }) async {
    log.add('schedule:$documentId');
    scheduled.add((
      documentId: documentId,
      diverId: diverId,
      title: title,
      stage: stage,
    ));
    return 1;
  }

  @override
  Future<void> cancelDocumentReminders(String documentId) async {
    log.add('cancel:$documentId');
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
    service.pending = {
      permit.id: 'd1',
      undated.id: 'd1',
      'deleted-elsewhere': 'd1',
    };
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
    service.pending = {renewed.id: 'd2'};
    await scheduler.scheduleAll(settings: const AppSettings(), diverId: 'd1');
    expect(service.cancelled, contains(renewed.id));
    expect(
      service.scheduled.where((s) => s.documentId == renewed.id),
      isNotEmpty,
    );
  });

  group('medical clearances (#4541)', () {
    DateTime inDays(int n) => DateTime(now.year, now.month, now.day + n);

    test('saving a renewal cancels the old clearance\'s reminders and arms '
        'the new one\'s', () async {
      final old = await save(DocumentType.medicalClearance, inDays(10));
      final renewal = await save(DocumentType.medicalClearance, inDays(400));
      await scheduler.updateForDocument(renewal, const AppSettings());
      expect(service.cancelled, containsAll([old.id, renewal.id]));
      expect(service.scheduled.map((s) => s.documentId).toSet(), {renewal.id});
    });

    test('updating a superseded clearance schedules nothing for it', () async {
      final old = await save(DocumentType.medicalClearance, inDays(10));
      await save(DocumentType.medicalClearance, inDays(400));
      await scheduler.updateForDocument(old, const AppSettings());
      expect(service.cancelled, contains(old.id));
      expect(service.scheduled.where((s) => s.documentId == old.id), isEmpty);
    });

    test('a full schedule cancels a superseded clearance\'s pending '
        'reminders', () async {
      final old = await save(DocumentType.medicalClearance, inDays(10));
      final renewal = await save(DocumentType.medicalClearance, inDays(400));
      service.pending = {old.id: 'd1'};
      await scheduler.scheduleAll(settings: const AppSettings(), diverId: 'd1');
      expect(service.cancelled, contains(old.id));
      expect(service.scheduled.map((s) => s.documentId).toSet(), {renewal.id});
    });

    test('once the renewal is gone, the old clearance reminds again', () async {
      final old = await save(DocumentType.medicalClearance, inDays(10));
      final renewal = await save(DocumentType.medicalClearance, inDays(400));
      await DocumentRepository().delete(renewal.id);
      await scheduler.updateForDocument(renewal, const AppSettings());
      expect(service.scheduled.map((s) => s.documentId).toSet(), {old.id});
    });

    test('an undated renewal issued later silences the dated clearance and '
        'reminds of nothing itself', () async {
      final old = await save(DocumentType.medicalClearance, inDays(10));
      final renewal = await DocumentRepository().save(
        Document(
          id: '',
          diverId: 'd1',
          owner: const DocumentOwner.personal(),
          type: DocumentType.medicalClearance,
          issueDate: inDays(30),
          createdAt: now,
          updatedAt: now,
        ),
        const [],
      );
      await scheduler.updateForDocument(renewal, const AppSettings());
      expect(service.cancelled, contains(old.id));
      expect(service.scheduled, isEmpty);
    });

    test(
      'another profile\'s pending clearances rebuild its set once',
      () async {
        await DatabaseService.instance.database.customStatement(
          'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
          "VALUES ('d2', 'Ben', 0, 0, 0)",
        );
        Future<Document> clearance(DateTime expiry) =>
            DocumentRepository().save(
              Document(
                id: '',
                diverId: 'd2',
                owner: const DocumentOwner.personal(),
                type: DocumentType.medicalClearance,
                expiryDate: expiry,
                createdAt: now,
                updatedAt: now,
              ),
              const [],
            );
        final old = await clearance(inDays(10));
        final renewal = await clearance(inDays(400));
        service.pending = {old.id: 'd2', renewal.id: 'd2'};
        await scheduler.scheduleAll(
          settings: const AppSettings(),
          diverId: 'd1',
        );
        expect(service.cancelled.where((id) => id == old.id), hasLength(1));
        expect(service.scheduled.map((s) => s.documentId).toSet(), {
          renewal.id,
        });
      },
    );

    test('a re-arm after a delete cancels the deleted clearances last, so '
        'one an earlier re-arm armed stays silent (#4609)', () async {
      final old = await save(DocumentType.medicalClearance, inDays(10));
      final renewal = await save(DocumentType.medicalClearance, inDays(400));
      await DocumentRepository(
        cancelReminders: (_) async {},
        clearancesDeleted: (_) {},
      ).delete(renewal.id);
      // An earlier re-arm read the renewal before it went, then armed it.
      await scheduler.updateForDocument(renewal, const AppSettings());
      service.cancelled.clear();
      await scheduler.updateClearancesForDiver(
        'd1',
        const AppSettings(),
        deletedIds: [renewal.id],
      );
      expect(service.cancelled.last, renewal.id);
      expect(service.scheduled.map((s) => s.documentId), contains(old.id));
    });

    test('a renewal deleted while a full schedule runs stays silent, and the '
        'clearance it superseded reminds again (#4609)', () async {
      final old = await save(DocumentType.medicalClearance, inDays(10));
      final renewal = await save(DocumentType.medicalClearance, inDays(400));
      final deletes = StreamController<Map<String, Set<String>>>.broadcast();
      addTearDown(deletes.close);
      scheduler = NotificationScheduler(
        notificationService: service,
        clearanceDeletes: deletes.stream,
      );
      // The run has read the renewal as the one that reminds; the delete
      // lands now, and its own re-arm finishes before the run arms.
      service.onPending = () async {
        service.onPending = null;
        await DocumentRepository(
          cancelReminders: (_) async {},
          clearancesDeleted: (_) {},
        ).delete(renewal.id);
        deletes.add({
          'd1': {renewal.id},
        });
        await Future<void>.delayed(Duration.zero);
      };
      await scheduler.scheduleAll(settings: const AppSettings(), diverId: 'd1');
      expect(
        service.log.lastIndexOf('cancel:${renewal.id}'),
        greaterThan(service.log.lastIndexOf('schedule:${renewal.id}')),
      );
      expect(
        service.log.lastIndexOf('schedule:${old.id}'),
        greaterThan(service.log.lastIndexOf('cancel:${old.id}')),
      );
    });

    test('a re-arm after a rolled-back delete keeps the restored clearance '
        'reminding (#4609)', () async {
      await save(DocumentType.medicalClearance, inDays(10));
      final renewal = await save(DocumentType.medicalClearance, inDays(400));
      // The delete named the renewal, then its transaction rolled back.
      await scheduler.updateClearancesForDiver(
        'd1',
        const AppSettings(),
        deletedIds: [renewal.id],
      );
      expect(service.scheduled.map((s) => s.documentId).toSet(), {renewal.id});
      // Only the arm's own cancel, before it schedules.
      expect(service.cancelled.where((id) => id == renewal.id), hasLength(1));
    });

    group('a renewal deleted on another device (#4609)', () {
      late Document old;
      late Document renewal;

      setUp(() async {
        final db = DatabaseService.instance.database;
        await db.customStatement(
          'INSERT INTO divers (id, name, is_default, created_at, updated_at) '
          "VALUES ('d2', 'Ben', 0, 0, 0)",
        );
        Future<Document> clearance(DateTime expiry) =>
            DocumentRepository().save(
              Document(
                id: '',
                diverId: 'd2',
                owner: const DocumentOwner.personal(),
                type: DocumentType.medicalClearance,
                expiryDate: expiry,
                createdAt: now,
                updatedAt: now,
              ),
              const [],
            );
        old = await clearance(inDays(10));
        renewal = await clearance(inDays(400));
        // A sync applies the delete as a raw row delete, re-arming nothing.
        await db.customStatement('DELETE FROM documents WHERE id = ?', [
          renewal.id,
        ]);
      });

      test('brings back the clearance it superseded, for a profile not '
          'active here', () async {
        // The old clearance was superseded, so only the renewal reminds.
        service.pending = {renewal.id: 'd2'};
        await scheduler.scheduleAll(
          settings: const AppSettings(),
          diverId: 'd1',
        );
        expect(service.cancelled, contains(renewal.id));
        expect(service.scheduled.map((s) => s.documentId).toSet(), {old.id});
        expect(service.scheduled.map((s) => s.diverId).toSet(), {'d2'});
      });

      test('is only cancelled when its reminder names no diver', () async {
        service.pending = {renewal.id: null};
        await scheduler.scheduleAll(
          settings: const AppSettings(),
          diverId: 'd1',
        );
        expect(service.cancelled, contains(renewal.id));
        expect(service.scheduled, isEmpty);
      });
    });

    test('retyping the renewal as another type makes the old clearance '
        'remind again', () async {
      final old = await save(DocumentType.medicalClearance, inDays(10));
      final renewal = await save(DocumentType.medicalClearance, inDays(60));
      final retyped = await DocumentRepository().save(
        renewal.copyWith(type: DocumentType.permit),
        const [],
      );
      await scheduler.updateForDocument(retyped, const AppSettings());
      expect(service.scheduled.map((s) => s.documentId).toSet(), {
        old.id,
        retyped.id,
      });
      // Only the re-arm's own cancel: settling the clearances afterwards
      // must not take back the reminders just armed for the permit.
      expect(service.cancelled.where((id) => id == retyped.id), hasLength(1));
    });
  });

  test('the background refresh, with no active profile, refreshes pending '
      'reminders too', () async {
    final permit = await save(
      DocumentType.permit,
      DateTime(now.year, now.month, now.day + 60),
    );
    service.pending = {permit.id: 'd1'};
    await scheduler.scheduleAll(settings: const AppSettings());
    expect(service.scheduled.map((s) => s.documentId).toSet(), {permit.id});
  });
}
