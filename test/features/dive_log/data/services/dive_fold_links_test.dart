import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_merge_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

/// The records that point at a dive through a nullable SET NULL link, which
/// a fold has to carry the way it carries routes (issue #3918). Foreign keys
/// stay on: the SET NULL action is what loses them.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiveConsolidationService consolidation;
  late DiveMergeService merge;

  final base = DateTime.utc(2026, 3, 1, 10);
  const tables = [
    'dive_center_gear_notes',
    'equipment_observations',
    'incidents',
    'pre_dive_sessions',
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = ON');
    diveRepo = DiveRepository();
    consolidation = DiveConsolidationService(diveRepo);
    merge = DiveMergeService(diveRepo);
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('diver1'),
            name: Value('diver1'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await db.customStatement(
      'INSERT INTO dive_centers (id, name, created_at, updated_at) '
      "VALUES ('center', 'Center', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at) '
      "VALUES ('gear', 'Regulator', 'regulator', 0, 0)",
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedDive(String id, DateTime entry, {String? serial}) async {
    await diveRepo.createDive(
      domain.Dive(
        id: id,
        diverId: 'diver1',
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 30),
        maxDepth: 18,
        diveComputerSerial: serial,
        profile: const [
          domain.DiveProfilePoint(timestamp: 0, depth: 0),
          domain.DiveProfilePoint(timestamp: 900, depth: 18),
          domain.DiveProfilePoint(timestamp: 1800, depth: 0),
        ],
      ),
    );
  }

  /// One row of each table on [diveId], ids prefixed with [prefix].
  Future<void> seedLinkedRows(String diveId, String prefix) async {
    await db.customStatement(
      'INSERT INTO dive_center_gear_notes (id, dive_center_id, gear_type, '
      'verdict, dive_id, noted_at, created_at, updated_at) '
      "VALUES ('$prefix-note', 'center', 'regulator', 'worked', '$diveId', "
      '0, 0, 0)',
    );
    await db.customStatement(
      'INSERT INTO equipment_observations (id, equipment_id, dive_id, '
      'observed_at, status, created_at, updated_at) '
      "VALUES ('$prefix-check', 'gear', '$diveId', 0, 'ok', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO incidents (id, dive_id, occurred_at, category, severity, '
      'narrative, created_at, updated_at) '
      "VALUES ('$prefix-incident', '$diveId', 0, 'gas', 'minor', 'x', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO pre_dive_sessions (id, template_name, dive_id, started_at, '
      'created_at, updated_at) '
      "VALUES ('$prefix-session', 'Checks', '$diveId', 0, 0, 0)",
    );
  }

  Future<List<String?>> diveIdsOf(String prefix) async {
    final found = <String?>[];
    for (final table in tables) {
      final row = await db
          .customSelect(
            'SELECT dive_id FROM $table WHERE id LIKE ?',
            variables: [Variable.withString('$prefix-%')],
          )
          .getSingle();
      found.add(row.read<String?>('dive_id'));
    }
    return found;
  }

  test('consolidation carries them onto the surviving dive', () async {
    await seedDive('a', base, serial: 'SN-a');
    await seedDive('b', base.add(const Duration(minutes: 1)), serial: 'SN-b');
    await seedLinkedRows('b', 'b');

    await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);

    expect(await diveIdsOf('b'), everyElement('a'));
  });

  test('a moved row is stamped and marked for sync', () async {
    await seedDive('a', base, serial: 'SN-a');
    await seedDive('b', base.add(const Duration(minutes: 1)), serial: 'SN-b');
    await seedLinkedRows('b', 'b');
    await db.delete(db.syncRecords).go();

    await consolidation.apply(targetDiveId: 'a', secondaryDiveIds: ['b']);

    final row = await db
        .customSelect(
          "SELECT dive_id, updated_at, hlc FROM incidents WHERE id = 'b-incident'",
        )
        .getSingle();
    expect(row.read<int>('updated_at'), greaterThan(0));
    expect(row.read<String?>('hlc'), isNotNull);
    final pending = await (db.select(
      db.syncRecords,
    )..where((t) => t.recordId.equals('b-incident'))).get();
    expect(pending.single.entityType, 'incidents');
  });

  test('consolidation undo puts them back, the target\'s own too', () async {
    await seedDive('a', base, serial: 'SN-a');
    await seedDive('b', base.add(const Duration(minutes: 1)), serial: 'SN-b');
    await seedLinkedRows('a', 'a');
    await seedLinkedRows('b', 'b');

    final outcome = await consolidation.apply(
      targetDiveId: 'a',
      secondaryDiveIds: ['b'],
    );
    await seedLinkedRows('a', 'since');
    await consolidation.undo(outcome.snapshot);

    expect(await diveIdsOf('a'), everyElement('a'));
    expect(await diveIdsOf('b'), everyElement('b'));
    expect(await diveIdsOf('since'), everyElement('a'));
  });

  test('undo does not bring back a row deleted after the fold', () async {
    await seedDive('a', base, serial: 'SN-a');
    await seedDive('b', base.add(const Duration(minutes: 1)), serial: 'SN-b');
    await seedLinkedRows('b', 'b');

    final outcome = await consolidation.apply(
      targetDiveId: 'a',
      secondaryDiveIds: ['b'],
    );
    await db.customStatement("DELETE FROM incidents WHERE id = 'b-incident'");
    await consolidation.undo(outcome.snapshot);

    final rows = await db
        .customSelect("SELECT id FROM incidents WHERE id = 'b-incident'")
        .get();
    expect(rows, isEmpty);
  });

  test(
    'merge carries them to the merged dive, and undo puts them back',
    () async {
      await seedDive('a', base);
      await seedDive('b', base.add(const Duration(minutes: 35)));
      await seedLinkedRows('a', 'a');
      await seedLinkedRows('b', 'b');

      final outcome = await merge.apply(['a', 'b']);
      final mergedId = outcome.mergedDive.id;

      expect(await diveIdsOf('a'), everyElement(mergedId));
      expect(await diveIdsOf('b'), everyElement(mergedId));

      await merge.undo(outcome.snapshot);

      expect(await diveIdsOf('a'), everyElement('a'));
      expect(await diveIdsOf('b'), everyElement('b'));
    },
  );
}
