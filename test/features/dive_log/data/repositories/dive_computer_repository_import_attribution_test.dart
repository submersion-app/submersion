import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';

import '../../../../helpers/test_database.dart';

/// Task 2: write-path attribution.
///
/// Every tank / tank-pressure / event row created by a computer download
/// must be stamped with the importing computer's id, so that later
/// consolidation (unlink, per-source UI) can attribute rows back to their
/// source. Null remains the sentinel for manual/legacy rows; this test
/// verifies download-created rows get an explicit id, not null.
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

  Future<String> insertComputer({
    String id = 'computer-1',
    String name = 'Shearwater Perdix',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value(name),
            manufacturer: const Value('Shearwater'),
            model: const Value('Perdix'),
            serialNumber: const Value('SN-12345'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  test('importProfile stores the transmitter serial on the tank row', () async {
    // The serial is the cylinder's identity across computers; a download
    // that drops it leaves consolidation with only the gas-mix heuristic.
    final computerId = await insertComputer();

    final diveId = await repository.importProfile(
      computerId: computerId,
      profileStartTime: DateTime(2026, 6, 1, 9, 0),
      points: const [
        ProfilePointData(timestamp: 0, depth: 0.0, pressure: 200.0),
        ProfilePointData(timestamp: 600, depth: 20.0, pressure: 150.0),
      ],
      durationSeconds: 1800,
      maxDepth: 25.0,
      tanks: const [
        TankData(index: 0, o2Percent: 32.0, transmitterSerial: '180777'),
        TankData(index: 1, o2Percent: 50.0),
      ],
    );

    final tanks =
        await (db.select(db.diveTanks)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
            .get();
    expect(tanks.map((t) => t.transmitterSerial), ['180777', null]);
  });

  test('importProfile stores where a tank role came from (#2595)', () async {
    final computerId = await insertComputer();

    final diveId = await repository.importProfile(
      computerId: computerId,
      profileStartTime: DateTime(2026, 6, 1, 9, 0),
      points: const [ProfilePointData(timestamp: 0, depth: 0.0)],
      durationSeconds: 1800,
      maxDepth: 25.0,
      tanks: const [
        TankData(
          index: 0,
          o2Percent: 100.0,
          role: 'oxygenSupply',
          roleSource: 'transmitterName',
          transmitterSerial: '180777',
        ),
        TankData(index: 1, o2Percent: 21.0, role: 'diluent'),
      ],
    );

    final tanks =
        await (db.select(db.diveTanks)
              ..where((t) => t.diveId.equals(diveId))
              ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
            .get();
    expect(tanks.map((t) => t.roleSource), ['transmitterName', null]);
  });

  test('importProfile stamps the reading\'s source on the tank rows', () async {
    // Issue #2716: a later consolidation keeps each source's copies of one
    // cylinder apart by it.
    final computerId = await insertComputer();

    final diveId = await repository.importProfile(
      computerId: computerId,
      profileStartTime: DateTime(2026, 6, 1, 9, 0),
      points: const [
        ProfilePointData(timestamp: 0, depth: 0.0, pressure: 200.0),
        ProfilePointData(timestamp: 600, depth: 20.0, pressure: 150.0),
      ],
      durationSeconds: 1800,
      maxDepth: 25.0,
      tanks: const [
        TankData(index: 0, o2Percent: 32.0),
        TankData(index: 1, o2Percent: 50.0),
      ],
    );

    final source = await (db.select(
      db.diveDataSources,
    )..where((s) => s.diveId.equals(diveId))).getSingle();
    final tanks = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals(diveId))).get();
    expect(tanks, hasLength(2));
    for (final tank in tanks) {
      expect(tank.sourceId, source.id);
    }
  });

  test('replacing a source hands its tanks to the fresh reading', () async {
    // The re-download path: clearSourceAndProfiles drops the old reading,
    // importProfile writes a new one for the same dive and keeps the tanks.
    final computerId = await insertComputer();
    final start = DateTime(2026, 6, 1, 9, 0);
    Future<String> download() => repository.importProfile(
      computerId: computerId,
      profileStartTime: start,
      points: const [
        ProfilePointData(timestamp: 0, depth: 0.0),
        ProfilePointData(timestamp: 600, depth: 20.0),
      ],
      durationSeconds: 1800,
      maxDepth: 25.0,
      tanks: const [TankData(index: 0, o2Percent: 32.0)],
    );
    final diveId = await download();
    final oldSource = (await (db.select(
      db.diveDataSources,
    )..where((s) => s.diveId.equals(diveId))).getSingle()).id;

    await repository.clearSourceAndProfiles(
      diveId: diveId,
      computerId: computerId,
    );
    final released = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals(diveId))).getSingle();
    expect(released.sourceId, isNull);

    expect(await download(), diveId);
    final fresh = (await (db.select(
      db.diveDataSources,
    )..where((s) => s.diveId.equals(diveId))).getSingle()).id;
    expect(fresh, isNot(oldSource));
    final tank = await (db.select(
      db.diveTanks,
    )..where((t) => t.diveId.equals(diveId))).getSingle();
    expect(tank.sourceId, fresh);
  });

  test(
    'importProfile stamps computerId on tanks, pressures, and events',
    () async {
      final computerId = await insertComputer();
      final entryTime = DateTime(2026, 6, 1, 9, 0);

      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: const [
          ProfilePointData(timestamp: 0, depth: 0.0, pressure: 200.0),
          ProfilePointData(timestamp: 600, depth: 20.0, pressure: 150.0),
        ],
        durationSeconds: 1800,
        maxDepth: 25.0,
        tanks: const [TankData(index: 0, o2Percent: 32.0)],
        events: const [EventData(timestamp: 300, type: 'safetystop')],
      );

      final tanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(tanks, isNotEmpty);
      for (final tank in tanks) {
        expect(tank.computerId, computerId);
      }

      final pressureSeries = await TankPressureSeriesRepository()
          .getSeriesForDive(diveId);
      expect(pressureSeries, isNotEmpty);
      for (final series in pressureSeries) {
        expect(series.computerId, computerId);
      }

      final events = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(events, isNotEmpty);
      for (final event in events) {
        expect(event.computerId, computerId);
      }
    },
  );
}
