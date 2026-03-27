import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';

import '../../../../helpers/test_database.dart';

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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<String> insertComputer({
    String id = 'computer-1',
    String name = 'Shearwater Perdix',
    String? diverId,
    String? manufacturer = 'Shearwater',
    String? model = 'Perdix',
    String? serialNumber = 'SN-12345',
    String? bluetoothAddress,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            diverId: Value(diverId),
            name: Value(name),
            manufacturer: Value(manufacturer),
            model: Value(model),
            serialNumber: Value(serialNumber),
            bluetoothAddress: Value(bluetoothAddress),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  Future<String> insertDive({
    String? id,
    String? computerId,
    int? diveDateTime,
    int? entryTime,
    int? exitTime,
    int? duration,
    double? maxDepth,
    double? avgDepth,
    int? diveNumber,
  }) async {
    final diveId = id ?? 'dive-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(diveDateTime ?? now),
            computerId: Value(computerId),
            entryTime: Value(entryTime),
            exitTime: Value(exitTime),
            bottomTime: Value(duration),
            maxDepth: Value(maxDepth),
            avgDepth: Value(avgDepth),
            diveNumber: Value(diveNumber),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return diveId;
  }

  Future<void> insertProfile({
    required String diveId,
    String? computerId,
    int timestamp = 0,
    double depth = 5.0,
    bool isPrimary = false,
  }) async {
    final id = 'profile-$timestamp-${DateTime.now().microsecondsSinceEpoch}';
    await db
        .into(db.diveProfiles)
        .insert(
          DiveProfilesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            timestamp: Value(timestamp),
            depth: Value(depth),
          ),
        );
  }

  Future<void> insertDataSource({
    required String diveId,
    String? computerId,
    bool isPrimary = false,
  }) async {
    final id = 'ds-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // deleteComputer - FK reference clearing
  // ---------------------------------------------------------------------------

  group('deleteComputer', () {
    test('nulls out FK references in dive_profiles before deleting', () async {
      final computerId = await insertComputer();
      final diveId = await insertDive();
      await insertProfile(
        diveId: diveId,
        computerId: computerId,
        timestamp: 0,
        depth: 10.0,
      );

      await repository.deleteComputer(computerId);

      // Profile should still exist but with null computerId.
      final profiles = await (db.select(
        db.diveProfiles,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(profiles, hasLength(1));
      expect(profiles.first.computerId, isNull);

      // Computer should be deleted.
      final computers = await (db.select(
        db.diveComputers,
      )..where((t) => t.id.equals(computerId))).get();
      expect(computers, isEmpty);
    });

    test(
      'nulls out FK references in dive_data_sources before deleting',
      () async {
        final computerId = await insertComputer();
        final diveId = await insertDive();
        await insertDataSource(
          diveId: diveId,
          computerId: computerId,
          isPrimary: true,
        );

        await repository.deleteComputer(computerId);

        // Data source should still exist but with null computerId.
        final sources = await (db.select(
          db.diveDataSources,
        )..where((t) => t.diveId.equals(diveId))).get();
        expect(sources, hasLength(1));
        expect(sources.first.computerId, isNull);
      },
    );

    test('handles deletion when no FK references exist', () async {
      final computerId = await insertComputer(id: 'standalone-computer');

      await repository.deleteComputer('standalone-computer');

      final computers = await (db.select(
        db.diveComputers,
      )..where((t) => t.id.equals(computerId))).get();
      expect(computers, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // importProfile with forceNew parameter
  // ---------------------------------------------------------------------------

  group('importProfile', () {
    test(
      'forceNew=true skips dive matching and always creates new dive',
      () async {
        final computerId = await insertComputer();

        // Create an existing dive that would normally match.
        final entryTime = DateTime(2026, 3, 15, 10, 0);
        await insertDive(
          id: 'existing-dive',
          computerId: computerId,
          diveDateTime: entryTime.millisecondsSinceEpoch,
          entryTime: entryTime.millisecondsSinceEpoch,
          exitTime: entryTime
              .add(const Duration(minutes: 45))
              .millisecondsSinceEpoch,
          duration: 45 * 60,
          maxDepth: 30.0,
        );

        // Import a profile with the same timestamp but forceNew=true.
        final resultDiveId = await repository.importProfile(
          computerId: computerId,
          profileStartTime: entryTime,
          points: [
            const ProfilePointData(timestamp: 0, depth: 0.0),
            const ProfilePointData(timestamp: 60, depth: 10.0),
            const ProfilePointData(timestamp: 120, depth: 20.0),
          ],
          durationSeconds: 45 * 60,
          maxDepth: 30.0,
          forceNew: true,
        );

        // Should create a new dive, not match the existing one.
        expect(resultDiveId, isNot(equals('existing-dive')));

        // Verify both dives exist.
        final allDives = await db.select(db.dives).get();
        expect(allDives.length, equals(2));
      },
    );

    test(
      'forceNew=false (default) matches existing dive by timestamp',
      () async {
        final computerId = await insertComputer();

        // Create an existing dive.
        final entryTime = DateTime(2026, 3, 15, 10, 0);
        await insertDive(
          id: 'existing-dive',
          computerId: computerId,
          diveDateTime: entryTime.millisecondsSinceEpoch,
          entryTime: entryTime.millisecondsSinceEpoch,
          exitTime: entryTime
              .add(const Duration(minutes: 45))
              .millisecondsSinceEpoch,
          duration: 45 * 60,
          maxDepth: 30.0,
        );

        // Import a profile with a matching timestamp.
        final resultDiveId = await repository.importProfile(
          computerId: computerId,
          profileStartTime: entryTime,
          points: [
            const ProfilePointData(timestamp: 0, depth: 0.0),
            const ProfilePointData(timestamp: 60, depth: 10.0),
          ],
          durationSeconds: 45 * 60,
          maxDepth: 30.0,
        );

        // Should match the existing dive.
        expect(resultDiveId, equals('existing-dive'));

        // Only one dive should exist.
        final allDives = await db.select(db.dives).get();
        expect(allDives.length, equals(1));
      },
    );

    test('creates a data source record when creating a new dive', () async {
      final computerId = await insertComputer();

      final entryTime = DateTime(2026, 3, 15, 10, 0);
      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: [
          const ProfilePointData(timestamp: 0, depth: 0.0, temperature: 22.0),
          const ProfilePointData(timestamp: 60, depth: 15.0, temperature: 21.0),
          const ProfilePointData(
            timestamp: 120,
            depth: 25.0,
            temperature: 20.0,
          ),
        ],
        durationSeconds: 45 * 60,
        maxDepth: 25.0,
        avgDepth: 15.0,
      );

      // Verify a data source was created.
      final dataSources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(dataSources, hasLength(1));
      expect(dataSources.first.computerId, equals(computerId));
      expect(dataSources.first.isPrimary, isTrue);
      expect(dataSources.first.maxDepth, equals(25.0));
      expect(dataSources.first.avgDepth, equals(15.0));
      expect(dataSources.first.duration, equals(45 * 60));
    });

    test('data source derives min water temp from profile samples', () async {
      final computerId = await insertComputer();

      final entryTime = DateTime(2026, 3, 15, 10, 0);
      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: [
          const ProfilePointData(timestamp: 0, depth: 0.0, temperature: 24.0),
          const ProfilePointData(timestamp: 60, depth: 15.0, temperature: 21.0),
          const ProfilePointData(
            timestamp: 120,
            depth: 25.0,
            temperature: 19.5,
          ),
        ],
        durationSeconds: 30 * 60,
        maxDepth: 25.0,
      );

      final dataSources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(dataSources.first.waterTemp, equals(19.5));
    });

    test('data source derives max CNS from profile samples', () async {
      final computerId = await insertComputer();

      final entryTime = DateTime(2026, 3, 15, 10, 0);
      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: [
          const ProfilePointData(timestamp: 0, depth: 0.0, cns: 10.0),
          const ProfilePointData(timestamp: 60, depth: 15.0, cns: 25.0),
          const ProfilePointData(timestamp: 120, depth: 25.0, cns: 42.0),
        ],
        durationSeconds: 30 * 60,
        maxDepth: 25.0,
      );

      final dataSources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(dataSources.first.cns, equals(42.0));
    });

    test(
      'data source waterTemp is null when no samples have temperature',
      () async {
        final computerId = await insertComputer();

        final entryTime = DateTime(2026, 3, 15, 10, 0);
        final diveId = await repository.importProfile(
          computerId: computerId,
          profileStartTime: entryTime,
          points: [
            const ProfilePointData(timestamp: 0, depth: 0.0),
            const ProfilePointData(timestamp: 60, depth: 15.0),
          ],
          durationSeconds: 30 * 60,
          maxDepth: 15.0,
        );

        final dataSources = await (db.select(
          db.diveDataSources,
        )..where((t) => t.diveId.equals(diveId))).get();
        expect(dataSources.first.waterTemp, isNull);
      },
    );

    test('data source includes deco algorithm and GF settings', () async {
      final computerId = await insertComputer();

      final entryTime = DateTime(2026, 3, 15, 10, 0);
      final diveId = await repository.importProfile(
        computerId: computerId,
        profileStartTime: entryTime,
        points: [const ProfilePointData(timestamp: 0, depth: 0.0)],
        durationSeconds: 30 * 60,
        maxDepth: 25.0,
        decoAlgorithm: 'Buhlmann ZHL-16C',
        gfLow: 30,
        gfHigh: 70,
      );

      final dataSources = await (db.select(
        db.diveDataSources,
      )..where((t) => t.diveId.equals(diveId))).get();
      expect(dataSources.first.decoAlgorithm, equals('Buhlmann ZHL-16C'));
      expect(dataSources.first.gradientFactorLow, equals(30));
      expect(dataSources.first.gradientFactorHigh, equals(70));
    });
  });
}
