import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/presentation/providers/change_log_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// A revert writes rows directly, so it keeps document expiry reminders in
/// step itself, as a save or delete on the Documents page does (#4607).
void main() {
  late AppDatabase db;
  late DocumentRepository documents;
  late ChangeLogRevertService service;
  late List<String> cancelled;
  late List<Document> armed;
  final repository = ChangeLogRepository();
  final now = DateTime.utc(2026, 11, 16);

  setUp(() async {
    db = await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 5000);
    cancelled = [];
    armed = [];
    documents = DocumentRepository(
      cancelReminders: (id) async => cancelled.add(id),
    );
    service = ChangeLogRevertService(
      afterDiveWrites: (_) {},
      documents: documents,
      rearmDocuments: (rearmed) async => armed.addAll(rearmed),
    );
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'diver',
            name: 'Ana',
            isDefault: const Value(true),
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  Document dated(DocumentType type, DateTime expiry, {String id = ''}) =>
      Document(
        id: id,
        diverId: 'diver',
        owner: const DocumentOwner.personal(),
        type: type,
        expiryDate: expiry,
        createdAt: now,
        updatedAt: now,
      );

  /// Clears the log, so the next operation is the only one a revert can pick
  /// up, and forgets the reminder calls the setup made.
  Future<void> startFresh() async {
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
    await SyncRepository().clearPendingRecords();
    cancelled.clear();
    armed.clear();
  }

  Future<String> newestOperation() async {
    await repository.settleAll();
    final row = await db
        .customSelect(
          'SELECT id FROM change_log_operations '
          'WHERE event_count > 0 ORDER BY last_event_id DESC LIMIT 1',
        )
        .getSingle();
    return row.read<String>('id');
  }

  Future<void> revertNewest() async =>
      service.execute(await service.planOperation(await newestOperation()));

  test('a restored document has its reminders re-armed', () async {
    final permit = await documents.save(
      dated(DocumentType.permit, now.add(const Duration(days: 10))),
      const [],
    );
    await startFresh();
    await documents.delete(permit.id);
    cancelled.clear();

    await revertNewest();

    expect(await documents.getById(permit.id), isNotNull);
    expect([for (final d in armed) d.id], [permit.id]);
    expect(cancelled, isEmpty);
  });

  test('a removed document has its reminders cancelled', () async {
    await startFresh();
    final permit = await documents.save(
      dated(DocumentType.permit, now.add(const Duration(days: 10))),
      const [],
    );

    await revertNewest();

    expect(await documents.getById(permit.id), isNull);
    expect(cancelled, [permit.id]);
    expect(armed, isEmpty);
  });

  test('removing the latest clearance re-arms the one before it', () async {
    final earlier = await documents.save(
      dated(DocumentType.medicalClearance, now.add(const Duration(days: 30))),
      const [],
    );
    await startFresh();
    final latest = await documents.save(
      dated(DocumentType.medicalClearance, now.add(const Duration(days: 400))),
      const [],
    );

    await revertNewest();

    expect(cancelled, [latest.id]);
    expect([for (final d in armed) d.id], [earlier.id]);
  });

  test('a reverted expiry edit re-arms the document as it is now', () async {
    final permit = await documents.save(
      dated(DocumentType.permit, now.add(const Duration(days: 10))),
      const [],
    );
    await startFresh();
    await documents.save(
      permit.copyWith(expiryDate: now.add(const Duration(days: 90))),
      const [],
    );

    await revertNewest();

    expect(armed.single.id, permit.id);
    expect(
      armed.single.expiryDate!.isAtSameMomentAs(permit.expiryDate!),
      isTrue,
    );
  });

  test('a revert that touches no document leaves reminders alone', () async {
    await startFresh();
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion.insert(
            id: 'b1',
            name: 'Rui',
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );

    await revertNewest();

    expect(await db.select(db.buddies).get(), isEmpty);
    expect(cancelled, isEmpty);
    expect(armed, isEmpty);
  });

  test('the app\'s revert service re-arms what a revert restores', () async {
    // The Revert sheet and the table editor take the service from this
    // provider, so it has to carry the documents' re-arm.
    final container = ProviderContainer(
      overrides: [
        documentMutationsProvider.overrideWith(
          (ref) => _RecordingMutations(ref, armed),
        ),
      ],
    );
    addTearDown(container.dispose);
    service = container.read(changeLogRevertServiceProvider);
    final permit = await documents.save(
      dated(DocumentType.permit, now.add(const Duration(days: 10))),
      const [],
    );
    await startFresh();
    await documents.delete(permit.id);

    await revertNewest();

    expect([for (final d in armed) d.id], [permit.id]);
  });
}

class _RecordingMutations extends DocumentMutations {
  _RecordingMutations(super.ref, this.armed);

  final List<Document> armed;

  @override
  Future<void> rearmReminders(Iterable<Document> documents) async =>
      armed.addAll(documents);
}
