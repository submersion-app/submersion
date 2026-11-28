import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Issue #5000: a Suunto Nautic with two transmitters keeps logging on the
/// surface after the dive, and catches the diver closing both valves. The
/// export reports no end pressure for either cylinder, so the importer
/// derives one from each series, and took the 0 bar the closed valve left.
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

  Future<String> insertComputer() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: const Value('computer-1'),
            name: const Value('Suunto Nautic'),
            manufacturer: const Value('Suunto'),
            model: const Value('Nautic'),
            serialNumber: const Value('SN-5000'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return 'computer-1';
  }

  Future<List<DiveTank>> tanksFor(String diveId) =>
      (db.select(db.diveTanks)
            ..where((t) => t.diveId.equals(diveId))
            ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
          .get();

  Future<String> importSidemountDive({
    bool trimTankPressureAtSurfacing = true,
  }) async {
    final computerId = await insertComputer();
    return repository.importProfile(
      computerId: computerId,
      profileStartTime: DateTime(2026, 11, 20, 10, 0),
      points: const [
        ProfilePointData(timestamp: 0, depth: 0.0, tankPressures: [205, 206]),
        ProfilePointData(
          timestamp: 600,
          depth: 18.0,
          tankPressures: [170, 175],
        ),
        ProfilePointData(
          timestamp: 2400,
          depth: 4.0,
          tankPressures: [103, 123],
        ),
        // Back on the surface: the diver closes the valves and purges the
        // regulators while the computer is still logging.
        ProfilePointData(timestamp: 2460, depth: 0.0, tankPressures: [40, 55]),
        ProfilePointData(timestamp: 2520, depth: 0.0, tankPressures: [0, 0]),
      ],
      durationSeconds: 2520,
      maxDepth: 18.0,
      tanks: const [
        TankData(index: 0, o2Percent: 33.0, role: 'sidemountLeft'),
        TankData(index: 1, o2Percent: 33.0, role: 'sidemountRight'),
      ],
      trimTankPressureAtSurfacing: trimTankPressureAtSurfacing,
    );
  }

  test('derives each end pressure at the moment the diver surfaced', () async {
    final tanks = await tanksFor(await importSidemountDive());

    expect(tanks, hasLength(2));
    expect(tanks[0].startPressure, 205.0);
    expect(tanks[0].endPressure, 103.0);
    expect(tanks[1].startPressure, 206.0);
    expect(tanks[1].endPressure, 123.0);
  });

  test('keeps the last reading with the surfacing setting off', () async {
    final tanks = await tanksFor(
      await importSidemountDive(trimTankPressureAtSurfacing: false),
    );

    expect(tanks[0].endPressure, 0.0);
    expect(tanks[1].endPressure, 0.0);
  });

  test('leaves a reported end pressure as the source gave it', () async {
    final computerId = await insertComputer();
    final diveId = await repository.importProfile(
      computerId: computerId,
      profileStartTime: DateTime(2026, 11, 21, 10, 0),
      points: const [
        ProfilePointData(timestamp: 0, depth: 0.0, tankPressures: [205]),
        ProfilePointData(timestamp: 2400, depth: 4.0, tankPressures: [103]),
        ProfilePointData(timestamp: 2520, depth: 0.0, tankPressures: [0]),
      ],
      durationSeconds: 2520,
      maxDepth: 18.0,
      tanks: const [
        TankData(
          index: 0,
          o2Percent: 33.0,
          startPressure: 205.0,
          endPressure: 101.0,
        ),
      ],
    );

    final tanks = await tanksFor(diveId);
    expect(tanks.single.endPressure, 101.0);
  });
}
