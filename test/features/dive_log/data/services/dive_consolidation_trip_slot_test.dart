import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/trips/domain/services/trip_cylinder_tank_link.dart';

import '../../../../helpers/test_database.dart';

/// Issue #2661 for file imports: two file imports of one dive, consolidated,
/// whose tank rows were not merged (31% on one computer, 32% on the other).
/// A file import writes its tanks with no computer and its dive with the
/// computer the file names; consolidation stamps each file's computer on its
/// own tank rows. So each copy resolves to its own computer and can share
/// the trip cylinder slot the other holds.
void main() {
  late AppDatabase db;
  late DiveRepository diveRepo;
  late DiveConsolidationService service;

  Future<void> seedFileImport(
    String diveId,
    String tankId,
    DateTime entry, {
    required double o2,
    required String? computerId,
  }) async {
    await diveRepo.createDive(
      domain.Dive(
        id: diveId,
        dateTime: entry,
        entryTime: entry,
        runtime: const Duration(minutes: 40),
        maxDepth: 30,
        tanks: [
          domain.DiveTank(
            id: tankId,
            gasMix: domain.GasMix(o2: o2),
          ),
        ],
      ),
    );
    // As the UDDF importer leaves them: the dive names the file's computer,
    // the tank names none.
    await (db.update(db.dives)..where((d) => d.id.equals(diveId))).write(
      DivesCompanion(computerId: Value(computerId)),
    );
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion.insert(
            id: 'src-$diveId',
            diveId: diveId,
            importedAt: DateTime.utc(2026, 7, 18),
            createdAt: DateTime.utc(2026, 7, 18),
          ).copyWith(
            isPrimary: const Value(true),
            computerId: Value(computerId),
            sourceFileName: const Value('log.uddf'),
          ),
        );
  }

  Future<void> registerComputer(String id) => db
      .into(db.diveComputers)
      .insert(
        DiveComputersCompanion.insert(
          id: id,
          name: id,
          createdAt: 1,
          updatedAt: 1,
        ),
      );

  /// The slots each tank of the consolidated dive could not take, with the
  /// primary file's tank linked to slot 'a'.
  Future<Map<String, Set<String>>> takenAfterLinking() async {
    final dive = (await diveRepo.getDiveById('f1'))!;
    expect(dive.tanks, hasLength(2), reason: 'the copies were not merged');
    final tanks = [
      for (final t in dive.tanks)
        t.id == 'tank-f1' ? t.copyWith(tripCylinderId: 'a') : t,
    ];
    return {
      for (final t in tanks)
        t.id: tripCylinderIdsTakenFor(
          t,
          tanks,
          primaryComputerId: dive.computerId,
        ),
    };
  }

  setUp(() async {
    db = await setUpTestDatabase();
    diveRepo = DiveRepository();
    service = DiveConsolidationService(diveRepo);
  });

  tearDown(tearDownTestDatabase);

  test('files naming their computers: the copies can share a slot', () async {
    await registerComputer('teric');
    await registerComputer('perdix');
    await seedFileImport(
      'f1',
      'tank-f1',
      DateTime.utc(2026, 7, 18, 18),
      o2: 32,
      computerId: 'teric',
    );
    await seedFileImport(
      'f2',
      'tank-f2',
      DateTime.utc(2026, 7, 18, 18, 1),
      o2: 31,
      computerId: 'perdix',
    );
    await service.apply(targetDiveId: 'f1', secondaryDiveIds: ['f2']);

    // What tells the copies apart: consolidation stamps each file's
    // computer on its own tank row.
    final dive = (await diveRepo.getDiveById('f1'))!;
    expect(dive.computerId, 'teric');
    expect(
      {for (final t in dive.tanks) t.id == 'tank-f1': t.computerId},
      {true: 'teric', false: 'perdix'},
    );
    final taken = await takenAfterLinking();
    final copy = taken.keys.singleWhere((id) => id != 'tank-f1');
    expect(taken[copy], isEmpty);
  });

  test('files naming no computer: nothing tells the copies apart', () async {
    // The remaining limit: no computer on either side, so both copies
    // resolve to "no computer" and the slot stays taken.
    await seedFileImport(
      'f1',
      'tank-f1',
      DateTime.utc(2026, 7, 18, 18),
      o2: 32,
      computerId: null,
    );
    await seedFileImport(
      'f2',
      'tank-f2',
      DateTime.utc(2026, 7, 18, 18, 1),
      o2: 31,
      computerId: null,
    );
    await service.apply(targetDiveId: 'f1', secondaryDiveIds: ['f2']);

    final taken = await takenAfterLinking();
    final copy = taken.keys.singleWhere((id) => id != 'tank-f1');
    expect(taken[copy], {'a'});
  });
}
