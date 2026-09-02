import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// Duplicate dive-type guards (issue #1360).
///
/// `dive_dive_types` now carries a unique index on (dive, type), so every
/// writer has to be conflict-safe -- an unguarded duplicate insert throws
/// instead of silently duplicating, and a throw inside the sync merge is far
/// worse than the duplicate it replaces. This is the same contract
/// `dive_tags` has carried since v149.
void main() {
  late DiveRepository repository;
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    serializer = SyncDataSerializer();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<List<String>> typesOf(String diveId) async {
    final rows =
        await (db.select(db.diveDiveTypes)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([
                (t) => OrderingTerm(expression: t.createdAt),
                (t) => OrderingTerm(expression: t.id),
              ]))
            .get();
    return rows.map((r) => r.diveTypeId).toList();
  }

  Future<void> seedDive(String id, List<String> typeIds) =>
      repository.createDive(
        domain.Dive(
          id: id,
          dateTime: DateTime(2026, 1, 1),
          diveTypeIds: typeIds,
        ),
      );

  group('repository writers dedupe their input', () {
    test('createDive collapses a repeated type', () async {
      await seedDive('d1', const ['shore', 'wreck', 'shore']);

      expect(await typesOf('d1'), ['shore', 'wreck']);
    });

    test('updateDive collapses a repeated type', () async {
      await seedDive('d1', const ['shore']);
      final dive = (await repository.getDiveById('d1'))!;

      await repository.updateDive(
        dive.copyWith(diveTypeIds: const ['cave', 'cave', 'deep']),
      );

      expect(await typesOf('d1'), ['cave', 'deep']);
    });

    test('bulkReplaceDiveTypes collapses a repeated type', () async {
      await seedDive('d1', const ['shore']);

      await repository.bulkReplaceDiveTypes(
        const ['d1'],
        const ['night', 'night'],
      );

      expect(await typesOf('d1'), ['night']);
    });

    test('the representative column follows the deduped first type', () async {
      await seedDive('d1', const ['shore', 'shore', 'wreck']);

      final row = await db.select(db.dives).getSingle();
      expect(row.diveType, 'shore');
    });
  });

  group('sync absorbs a peer row for an already-occupied pair', () {
    // The #1360 fleet shape: every device that upgraded through v92 minted its
    // OWN random id for the same (dive, type) pair, and the merge keys on that
    // id. Now that the pair is unique, applying the peer's row must be a
    // no-op rather than a throw that fails the whole sync.
    Map<String, dynamic> peerRow(String id, String diveId, String typeId) => {
      'id': id,
      'diveId': diveId,
      'diveTypeId': typeId,
      'createdAt': 2000,
    };

    test('upsertRecord drops the duplicate instead of throwing', () async {
      await seedDive('d1', const ['shore']);
      final ours = (await typesOf('d1')).single;

      await serializer.upsertRecord(
        'diveDiveTypes',
        peerRow('peer-minted-id', 'd1', 'shore'),
      );

      expect(await typesOf('d1'), [ours]);
    });

    test('upsertRecords drops the duplicate instead of throwing', () async {
      await seedDive('d1', const ['shore']);

      await serializer.upsertRecords('diveDiveTypes', [
        peerRow('peer-a', 'd1', 'shore'),
        peerRow('peer-b', 'd1', 'wreck'),
      ]);

      // Order is each peer row's own created_at, which is not what this
      // asserts: the point is that 'shore' landed once, not twice.
      expect((await typesOf('d1')).toSet(), {'shore', 'wreck'});
    });

    test('a peer type the dive lacks is still applied', () async {
      await seedDive('d1', const ['shore']);

      await serializer.upsertRecord(
        'diveDiveTypes',
        peerRow('peer-night', 'd1', 'night'),
      );

      // Order is the peer row's own created_at, which is not what this asserts.
      expect((await typesOf('d1')).toSet(), {'shore', 'night'});
    });
  });
}
