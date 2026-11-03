import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// The per-computer opt-out from auto-download (issue #3361) is synced like
/// the rest of the record, and its switch writes it on its own.
void main() {
  late DiveComputerRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveComputerRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<domain.DiveComputer> createComputer() {
    final now = DateTime(2026, 1, 1);
    return repository.createComputer(
      domain.DiveComputer(
        id: 'computer-opt-out',
        name: 'Shearwater Perdix 2',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('updateComputer persists the opt-out', () async {
    final created = await createComputer();
    expect(created.autoDownloadDisabled, isFalse);

    await repository.updateComputer(
      created.copyWith(autoDownloadDisabled: true),
    );

    final reloaded = await repository.getComputerById(created.id);
    expect(reloaded?.autoDownloadDisabled, isTrue);
  });

  test('setAutoDownloadDisabled writes the opt-out alone and marks the '
      'record for sync', () async {
    addTearDown(SyncClock.instance.reset);
    final created = await createComputer();
    // Changed on the record after the switch's copy of it was taken.
    await (db.update(
      db.diveComputers,
    )..where((t) => t.id.equals(created.id))).write(
      const DiveComputersCompanion(
        diveCount: Value(42),
        lastDiveFingerprint: Value('ABCD'),
      ),
    );
    await db.customStatement('DELETE FROM sync_records');

    await repository.setAutoDownloadDisabled(created.id, true);

    final row = await (db.select(
      db.diveComputers,
    )..where((t) => t.id.equals(created.id))).getSingle();
    expect(row.autoDownloadDisabled, isTrue);
    expect(row.diveCount, 42);
    expect(row.lastDiveFingerprint, 'ABCD');
    final pending =
        await (db.select(db.syncRecords)..where(
              (r) =>
                  r.entityType.equals('diveComputers') &
                  r.recordId.equals(created.id),
            ))
            .get();
    expect(pending, isNotEmpty);

    await repository.setAutoDownloadDisabled(created.id, false);
    final cleared = await repository.getComputerById(created.id);
    expect(cleared?.autoDownloadDisabled, isFalse);
  });
}
