import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1223: a CCR dive logged with an O2 and a diluent transmitter reports
/// both pressures on the same sample. The download path used to keep a single
/// pressure per sample, so the lower-numbered tank kept only the readings taken
/// while the other transmitter was out of comms -- often none at all, which the
/// profile chart drew as a flat "(est.)" line.
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
            name: const Value('Shearwater Petrel 3'),
            manufacturer: const Value('Shearwater'),
            model: const Value('Petrel 3'),
            serialNumber: const Value('SN-1223'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return 'computer-1';
  }

  Future<List<({int timestamp, double pressure})>> seriesFor(
    String tankId,
  ) async {
    final rows =
        await (db.select(db.tankPressureProfiles)
              ..where((t) => t.tankId.equals(tankId))
              ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
            .get();
    return [
      for (final r in rows) (timestamp: r.timestamp, pressure: r.pressure),
    ];
  }

  Future<List<DiveTank>> tanksFor(String diveId) =>
      (db.select(db.diveTanks)
            ..where((t) => t.diveId.equals(diveId))
            ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
          .get();

  test('both transmitters keep their own pressure series', () async {
    final computerId = await insertComputer();

    final diveId = await repository.importProfile(
      computerId: computerId,
      profileStartTime: DateTime(2026, 8, 15, 16, 27),
      points: const [
        // pressure/tankIndex hold whichever transmitter the computer reported
        // last; tankPressures is the complete record.
        ProfilePointData(
          timestamp: 0,
          depth: 0.0,
          pressure: 191.4,
          tankIndex: 1,
          tankPressures: [192.6, 191.4],
        ),
        ProfilePointData(
          timestamp: 600,
          depth: 27.2,
          pressure: 150.0,
          tankIndex: 1,
          tankPressures: [180.0, 150.0],
        ),
        ProfilePointData(
          timestamp: 1200,
          depth: 5.0,
          pressure: 104.5,
          tankIndex: 1,
          tankPressures: [162.7, 104.5],
        ),
      ],
      durationSeconds: 1800,
      maxDepth: 27.2,
      tanks: const [
        TankData(index: 0, o2Percent: 100.0, role: 'oxygenSupply'),
        TankData(index: 1, o2Percent: 21.0, role: 'diluent'),
      ],
    );

    final tanks = await tanksFor(diveId);
    expect(tanks, hasLength(2));

    expect(await seriesFor(tanks[0].id), [
      (timestamp: 0, pressure: 192.6),
      (timestamp: 600, pressure: 180.0),
      (timestamp: 1200, pressure: 162.7),
    ], reason: 'the O2 transmitter must not be overwritten by the diluent');
    expect(await seriesFor(tanks[1].id), [
      (timestamp: 0, pressure: 191.4),
      (timestamp: 600, pressure: 150.0),
      (timestamp: 1200, pressure: 104.5),
    ]);
  });

  test(
    'a transmitter that drops out leaves a gap, not a borrowed reading',
    () async {
      final computerId = await insertComputer();

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: DateTime(2026, 8, 8, 10, 53),
        points: const [
          ProfilePointData(
            timestamp: 0,
            depth: 0.0,
            pressure: 204.1,
            tankIndex: 1,
            tankPressures: [187.4, 204.1],
          ),
          // "No comms" on the diluent transmitter: only the O2 tank reports.
          ProfilePointData(
            timestamp: 60,
            depth: 10.0,
            pressure: 185.0,
            tankIndex: 0,
            tankPressures: [185.0],
          ),
          ProfilePointData(
            timestamp: 120,
            depth: 20.0,
            pressure: 190.0,
            tankIndex: 1,
            tankPressures: [183.0, 190.0],
          ),
        ],
        durationSeconds: 600,
        maxDepth: 20.0,
        tanks: const [
          TankData(index: 0, o2Percent: 100.0, role: 'oxygenSupply'),
          TankData(index: 1, o2Percent: 21.0, role: 'diluent'),
        ],
      );

      final tanks = await tanksFor(diveId);
      expect(
        await seriesFor(tanks[0].id).then((s) => s.map((p) => p.timestamp)),
        [0, 60, 120],
      );
      expect(
        await seriesFor(tanks[1].id).then((s) => s.map((p) => p.timestamp)),
        [0, 120],
        reason: 'the diluent has no reading at 60s and must not invent one',
      );
    },
  );

  test(
    'start and end pressure are backfilled per tank from its own series',
    () async {
      final computerId = await insertComputer();

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: DateTime(2026, 8, 15, 16, 27),
        points: const [
          ProfilePointData(
            timestamp: 0,
            depth: 0.0,
            tankPressures: [192.6, 191.4],
          ),
          ProfilePointData(
            timestamp: 1200,
            depth: 5.0,
            tankPressures: [162.7, 104.5],
          ),
        ],
        durationSeconds: 1800,
        maxDepth: 27.2,
        // No summary pressures: they come from the transmitter stream.
        tanks: const [
          TankData(index: 0, o2Percent: 100.0, role: 'oxygenSupply'),
          TankData(index: 1, o2Percent: 21.0, role: 'diluent'),
        ],
      );

      final tanks = await tanksFor(diveId);
      expect(tanks[0].startPressure, 192.6);
      expect(tanks[0].endPressure, 162.7);
      expect(tanks[1].startPressure, 191.4);
      expect(tanks[1].endPressure, 104.5);
    },
  );

  test(
    'a single-transmitter dive still imports through the fallback path',
    () async {
      // UDDF/FIT imports and older native builds report one pressure per sample
      // with no per-tank list.
      final computerId = await insertComputer();

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: DateTime(2026, 8, 15, 16, 27),
        points: const [
          ProfilePointData(timestamp: 0, depth: 0.0, pressure: 200.0),
          ProfilePointData(timestamp: 600, depth: 20.0, pressure: 150.0),
        ],
        durationSeconds: 1200,
        maxDepth: 20.0,
        tanks: const [TankData(index: 0, o2Percent: 32.0)],
      );

      final tanks = await tanksFor(diveId);
      expect(tanks, hasLength(1));
      expect(await seriesFor(tanks[0].id), [
        (timestamp: 0, pressure: 200.0),
        (timestamp: 600, pressure: 150.0),
      ]);
    },
  );
}
