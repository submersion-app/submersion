import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

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

      final pressures = await (db.select(
        db.tankPressureProfiles,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(pressures, isNotEmpty);
      for (final pressure in pressures) {
        expect(pressure.computerId, computerId);
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
