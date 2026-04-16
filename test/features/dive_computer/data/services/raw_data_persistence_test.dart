import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  /// Insert a minimal dive row and return its ID.
  Future<String> insertDive(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  /// Insert a minimal dive computer row and return its ID.
  Future<String> insertComputer(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('Test Computer $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  /// Insert a DiveDataSources row with optional rawData.
  Future<String> insertSource({
    required String id,
    required String diveId,
    String? computerId,
    bool isPrimary = true,
    Uint8List? rawData,
    Uint8List? rawFingerprint,
  }) async {
    final now = DateTime.now();
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            sourceFormat: const Value('dive_computer'),
            rawData: Value(rawData),
            rawFingerprint: Value(rawFingerprint),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );
    return id;
  }

  /// Insert a minimal dive tank row and return its ID.
  Future<String> insertTank({
    required String id,
    required String diveId,
  }) async {
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion(id: Value(id), diveId: Value(diveId)));
    return id;
  }

  /// Insert a dive profile point.
  Future<void> insertProfile({
    required String id,
    required String diveId,
    String? computerId,
    int timestamp = 0,
    double depth = 10.0,
  }) async {
    await db
        .into(db.diveProfiles)
        .insert(
          DiveProfilesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            timestamp: Value(timestamp),
            depth: Value(depth),
          ),
        );
  }

  /// Insert a dive profile event.
  Future<void> insertProfileEvent({
    required String id,
    required String diveId,
    int timestamp = 0,
    String eventType = 'bookmark',
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion(
            id: Value(id),
            diveId: Value(diveId),
            timestamp: Value(timestamp),
            eventType: Value(eventType),
            createdAt: Value(now),
          ),
        );
  }

  /// Insert a tank pressure profile point.
  Future<void> insertTankPressure({
    required String id,
    required String diveId,
    required String tankId,
    int timestamp = 0,
    double pressure = 200.0,
  }) async {
    await db
        .into(db.tankPressureProfiles)
        .insert(
          TankPressureProfilesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            tankId: Value(tankId),
            timestamp: Value(timestamp),
            pressure: Value(pressure),
          ),
        );
  }

  /// Insert a gas switch record.
  Future<void> insertGasSwitch({
    required String id,
    required String diveId,
    required String tankId,
    int timestamp = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.gasSwitches)
        .insert(
          GasSwitchesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            tankId: Value(tankId),
            timestamp: Value(timestamp),
            createdAt: Value(now),
          ),
        );
  }

  /// Run the same DELETE statements as clearSourceAndProfiles.
  ///
  /// This mirrors DiveComputerRepository.clearSourceAndProfiles but operates
  /// directly on the test database instead of going through the singleton.
  Future<void> clearSourceAndProfiles({
    required String diveId,
    required String computerId,
  }) async {
    await db.customStatement(
      'DELETE FROM dive_profile_events WHERE dive_id = ?',
      [diveId],
    );
    await db.customStatement(
      'DELETE FROM tank_pressure_profiles WHERE dive_id = ?',
      [diveId],
    );
    await db.customStatement('DELETE FROM gas_switches WHERE dive_id = ?', [
      diveId,
    ]);
    await db.customStatement(
      'DELETE FROM dive_profiles WHERE dive_id = ? AND computer_id = ?',
      [diveId, computerId],
    );
    await db.customStatement(
      'DELETE FROM dive_data_sources WHERE dive_id = ? AND computer_id = ?',
      [diveId, computerId],
    );
  }

  // --------------------------------------------------------------------------
  // clearSourceAndProfiles
  // --------------------------------------------------------------------------

  group('clearSourceAndProfiles', () {
    test('deletes profile events, tank pressure profiles, gas switches, '
        'profiles, and data source for the dive+computer pair', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      final tankId = await insertTank(id: 'tank-1', diveId: 'dive-1');

      // Populate all 5 tables
      await insertProfile(id: 'p-1', diveId: 'dive-1', computerId: 'comp-1');
      await insertProfile(
        id: 'p-2',
        diveId: 'dive-1',
        computerId: 'comp-1',
        timestamp: 10,
      );
      await insertSource(id: 'src-1', diveId: 'dive-1', computerId: 'comp-1');
      await insertProfileEvent(id: 'ev-1', diveId: 'dive-1');
      await insertTankPressure(id: 'tp-1', diveId: 'dive-1', tankId: tankId);
      await insertGasSwitch(id: 'gs-1', diveId: 'dive-1', tankId: tankId);

      // Verify everything was inserted
      expect(await db.select(db.diveProfiles).get(), hasLength(2));
      expect(await db.select(db.diveDataSources).get(), hasLength(1));
      expect(await db.select(db.diveProfileEvents).get(), hasLength(1));
      expect(await db.select(db.tankPressureProfiles).get(), hasLength(1));
      expect(await db.select(db.gasSwitches).get(), hasLength(1));

      await clearSourceAndProfiles(diveId: 'dive-1', computerId: 'comp-1');

      // All 5 tables should be empty for this dive+computer
      expect(await db.select(db.diveProfiles).get(), isEmpty);
      expect(await db.select(db.diveDataSources).get(), isEmpty);
      expect(await db.select(db.diveProfileEvents).get(), isEmpty);
      expect(await db.select(db.tankPressureProfiles).get(), isEmpty);
      expect(await db.select(db.gasSwitches).get(), isEmpty);
    });

    test('preserves data for other dives (different dive_id)', () async {
      await insertDive('dive-1');
      await insertDive('dive-2');
      await insertComputer('comp-1');
      final tank1 = await insertTank(id: 'tank-1', diveId: 'dive-1');
      final tank2 = await insertTank(id: 'tank-2', diveId: 'dive-2');

      // Data for dive-1 (will be cleared)
      await insertProfile(id: 'p-1', diveId: 'dive-1', computerId: 'comp-1');
      await insertSource(id: 'src-1', diveId: 'dive-1', computerId: 'comp-1');
      await insertProfileEvent(id: 'ev-1', diveId: 'dive-1');
      await insertTankPressure(id: 'tp-1', diveId: 'dive-1', tankId: tank1);
      await insertGasSwitch(id: 'gs-1', diveId: 'dive-1', tankId: tank1);

      // Data for dive-2 (must survive)
      await insertProfile(id: 'p-2', diveId: 'dive-2', computerId: 'comp-1');
      await insertSource(id: 'src-2', diveId: 'dive-2', computerId: 'comp-1');
      await insertProfileEvent(id: 'ev-2', diveId: 'dive-2');
      await insertTankPressure(id: 'tp-2', diveId: 'dive-2', tankId: tank2);
      await insertGasSwitch(id: 'gs-2', diveId: 'dive-2', tankId: tank2);

      await clearSourceAndProfiles(diveId: 'dive-1', computerId: 'comp-1');

      // dive-2 data is fully preserved
      final profiles = await db.select(db.diveProfiles).get();
      expect(profiles, hasLength(1));
      expect(profiles.first.diveId, 'dive-2');

      final sources = await db.select(db.diveDataSources).get();
      expect(sources, hasLength(1));
      expect(sources.first.diveId, 'dive-2');

      final events = await db.select(db.diveProfileEvents).get();
      expect(events, hasLength(1));
      expect(events.first.diveId, 'dive-2');

      final pressures = await db.select(db.tankPressureProfiles).get();
      expect(pressures, hasLength(1));
      expect(pressures.first.diveId, 'dive-2');

      final switches = await db.select(db.gasSwitches).get();
      expect(switches, hasLength(1));
      expect(switches.first.diveId, 'dive-2');
    });

    test('preserves profiles from other computers '
        '(same dive, different computer_id)', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertComputer('comp-2');
      final tankId = await insertTank(id: 'tank-1', diveId: 'dive-1');

      // Profiles from comp-1 (will be cleared)
      await insertProfile(
        id: 'p-1a',
        diveId: 'dive-1',
        computerId: 'comp-1',
        timestamp: 0,
      );
      await insertProfile(
        id: 'p-1b',
        diveId: 'dive-1',
        computerId: 'comp-1',
        timestamp: 10,
      );

      // Profiles from comp-2 (must survive)
      await insertProfile(
        id: 'p-2a',
        diveId: 'dive-1',
        computerId: 'comp-2',
        timestamp: 0,
      );
      await insertProfile(
        id: 'p-2b',
        diveId: 'dive-1',
        computerId: 'comp-2',
        timestamp: 10,
      );

      // Data source for comp-1 (will be cleared)
      await insertSource(id: 'src-1', diveId: 'dive-1', computerId: 'comp-1');

      // Data source for comp-2 (must survive)
      await insertSource(
        id: 'src-2',
        diveId: 'dive-1',
        computerId: 'comp-2',
        isPrimary: false,
      );

      // Per-dive derived tables (events, tank pressures, gas switches) are
      // cleared by dive_id alone (they lack a computer_id column), so they
      // will be removed regardless of which computer is being cleared.
      await insertProfileEvent(id: 'ev-1', diveId: 'dive-1');
      await insertTankPressure(id: 'tp-1', diveId: 'dive-1', tankId: tankId);
      await insertGasSwitch(id: 'gs-1', diveId: 'dive-1', tankId: tankId);

      await clearSourceAndProfiles(diveId: 'dive-1', computerId: 'comp-1');

      // comp-2 profiles survive (filtered by computer_id)
      final profiles = await db.select(db.diveProfiles).get();
      expect(profiles, hasLength(2));
      expect(profiles.every((p) => p.computerId == 'comp-2'), isTrue);

      // comp-2 data source survives (filtered by computer_id)
      final sources = await db.select(db.diveDataSources).get();
      expect(sources, hasLength(1));
      expect(sources.first.computerId, 'comp-2');

      // Per-dive derived tables are cleared entirely (by dive_id)
      expect(await db.select(db.diveProfileEvents).get(), isEmpty);
      expect(await db.select(db.tankPressureProfiles).get(), isEmpty);
      expect(await db.select(db.gasSwitches).get(), isEmpty);
    });
  });

  group('DiveDataSources blob persistence', () {
    test('stores and retrieves rawData blob byte-for-byte', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');

      // Create a non-trivial blob with various byte patterns
      final rawBytes = Uint8List.fromList([
        0x00, 0x01, 0x02, 0xFF, 0xFE, 0xAB, 0xCD, 0xEF, //
        0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80,
      ]);

      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        rawData: rawBytes,
        rawFingerprint: Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF]),
      );

      // Retrieve and verify byte-for-byte round-trip
      final row = await (db.select(
        db.diveDataSources,
      )..where((t) => t.id.equals('src-1'))).getSingle();

      expect(row.rawData, isNotNull);
      expect(row.rawData!.length, rawBytes.length);
      expect(row.rawData!, equals(rawBytes));

      // Also verify rawFingerprint round-trip
      expect(row.rawFingerprint, isNotNull);
      expect(
        row.rawFingerprint!,
        equals(Uint8List.fromList([0xDE, 0xAD, 0xBE, 0xEF])),
      );
    });

    test('rawData is nullable and null by default', () async {
      await insertDive('dive-1');

      // Insert a source row without rawData
      await insertSource(id: 'src-1', diveId: 'dive-1');

      final row = await (db.select(
        db.diveDataSources,
      )..where((t) => t.id.equals('src-1'))).getSingle();

      expect(row.rawData, isNull);
      expect(row.rawFingerprint, isNull);
    });

    test('FK setNull: deleting DiveComputer sets computerId to null '
        'while preserving rawData', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');

      final blob = Uint8List.fromList(List.generate(256, (i) => i % 256));
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        rawData: blob,
      );

      // Verify the source has a computerId before delete
      var row = await (db.select(
        db.diveDataSources,
      )..where((t) => t.id.equals('src-1'))).getSingle();
      expect(row.computerId, equals('comp-1'));

      // Verify foreign keys are enabled
      final fkResult = await db.customSelect('PRAGMA foreign_keys').getSingle();
      expect(fkResult.data['foreign_keys'], 1);

      // Delete the computer -- FK ON DELETE SET NULL should fire.
      await (db.delete(
        db.diveComputers,
      )..where((t) => t.id.equals('comp-1'))).go();

      // Re-read the source row
      row = await (db.select(
        db.diveDataSources,
      )..where((t) => t.id.equals('src-1'))).getSingle();

      // computerId should be null now
      expect(row.computerId, isNull);

      // rawData must still be intact
      expect(row.rawData, isNotNull);
      expect(row.rawData!.length, blob.length);
      expect(row.rawData!, equals(blob));
    });

    test(
      'cascade delete: deleting a Dive removes its DiveDataSources rows',
      () async {
        await insertDive('dive-1');
        await insertDive('dive-2');
        await insertComputer('comp-1');

        await insertSource(
          id: 'src-1',
          diveId: 'dive-1',
          computerId: 'comp-1',
          rawData: Uint8List.fromList([1, 2, 3]),
        );
        await insertSource(
          id: 'src-2',
          diveId: 'dive-1',
          computerId: 'comp-1',
          rawData: Uint8List.fromList([4, 5, 6]),
          isPrimary: false,
        );
        // A source for a different dive (should NOT be deleted)
        await insertSource(
          id: 'src-3',
          diveId: 'dive-2',
          computerId: 'comp-1',
          rawData: Uint8List.fromList([7, 8, 9]),
        );

        // Verify all three sources exist
        var allSources = await db.select(db.diveDataSources).get();
        expect(allSources.length, 3);

        // Delete dive-1 -- CASCADE should remove src-1 and src-2
        await (db.delete(db.dives)..where((t) => t.id.equals('dive-1'))).go();

        allSources = await db.select(db.diveDataSources).get();
        expect(allSources.length, 1);
        expect(allSources.first.id, 'src-3');
        expect(allSources.first.diveId, 'dive-2');
        // Verify the surviving source's blob is intact
        expect(allSources.first.rawData, equals(Uint8List.fromList([7, 8, 9])));
      },
    );
  });
}
