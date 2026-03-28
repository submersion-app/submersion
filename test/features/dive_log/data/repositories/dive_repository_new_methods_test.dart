import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<String> insertTestDive({
    String? id,
    String? diverId,
    int? diveNumber,
    String? diveComputerModel,
    String? diveComputerSerial,
    double? maxDepth,
    double? avgDepth,
    int? duration,
    double? waterTemp,
    int? entryTime,
    int? exitTime,
    int? surfaceIntervalSeconds,
    double? cnsEnd,
    String? decoAlgorithm,
    int? gradientFactorLow,
    int? gradientFactorHigh,
    String? importId,
    int? diveDateTime,
  }) async {
    final diveId = id ?? 'dive-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(diveDateTime ?? now),
            diverId: Value(diverId),
            diveNumber: Value(diveNumber),
            diveComputerModel: Value(diveComputerModel),
            diveComputerSerial: Value(diveComputerSerial),
            maxDepth: Value(maxDepth),
            avgDepth: Value(avgDepth),
            bottomTime: Value(duration),
            waterTemp: Value(waterTemp),
            entryTime: Value(entryTime),
            exitTime: Value(exitTime),
            surfaceIntervalSeconds: Value(surfaceIntervalSeconds),
            cnsEnd: Value(cnsEnd),
            decoAlgorithm: Value(decoAlgorithm),
            gradientFactorLow: Value(gradientFactorLow),
            gradientFactorHigh: Value(gradientFactorHigh),
            importId: Value(importId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return diveId;
  }

  DiveDataSourcesCompanion buildReading({
    String? id,
    required String diveId,
    bool isPrimary = false,
    String? computerModel,
    String? computerSerial,
    double? maxDepth,
    double? avgDepth,
    int? duration,
    double? waterTemp,
    DateTime? entryTime,
    DateTime? exitTime,
    int? surfaceInterval,
    double? cns,
    String? decoAlgorithm,
    int? gradientFactorLow,
    int? gradientFactorHigh,
  }) {
    final now = DateTime.now();
    return DiveDataSourcesCompanion(
      id: Value(id ?? 'reading-${now.microsecondsSinceEpoch}'),
      diveId: Value(diveId),
      isPrimary: Value(isPrimary),
      computerModel: Value(computerModel),
      computerSerial: Value(computerSerial),
      maxDepth: Value(maxDepth),
      avgDepth: Value(avgDepth),
      duration: Value(duration),
      waterTemp: Value(waterTemp),
      entryTime: Value(entryTime),
      exitTime: Value(exitTime),
      surfaceInterval: Value(surfaceInterval),
      cns: Value(cns),
      decoAlgorithm: Value(decoAlgorithm),
      gradientFactorLow: Value(gradientFactorLow),
      gradientFactorHigh: Value(gradientFactorHigh),
      importedAt: Value(now),
      createdAt: Value(now),
    );
  }

  Future<String> insertTestProfile({
    required String diveId,
    String? sourceTag,
    bool isPrimary = true,
    int timestamp = 0,
    double depth = 5.0,
    String? computerId,
  }) async {
    final tag = sourceTag ?? 'default';
    final id = 'profile-$tag-$timestamp-${diveId.hashCode}';
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
    return id;
  }

  Future<void> insertTestDiver(String diverId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(diverId),
            name: Value('Diver $diverId'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // getDataSources
  // ---------------------------------------------------------------------------

  group('getDataSources', () {
    test('returns empty list when no data sources exist', () async {
      final diveId = await insertTestDive(id: 'dive-no-sources');

      final sources = await repository.getDataSources(diveId);

      expect(sources, isEmpty);
    });

    test(
      'returns data sources ordered primary-first then by createdAt',
      () async {
        final diveId = await insertTestDive(id: 'dive-ordered-sources');

        // Insert non-primary first.
        await repository.saveComputerReading(
          buildReading(
            id: 'reading-secondary',
            diveId: diveId,
            isPrimary: false,
            computerModel: 'Suunto D5',
          ),
        );
        // Small delay to ensure distinct createdAt.
        await Future<void>.delayed(const Duration(milliseconds: 10));
        await repository.saveComputerReading(
          buildReading(
            id: 'reading-primary',
            diveId: diveId,
            isPrimary: true,
            computerModel: 'Shearwater Petrel',
          ),
        );

        final sources = await repository.getDataSources(diveId);

        expect(sources.length, equals(2));
        // Primary should come first regardless of insertion order.
        expect(sources[0].isPrimary, isTrue);
        expect(sources[0].computerModel, equals('Shearwater Petrel'));
        expect(sources[1].isPrimary, isFalse);
        expect(sources[1].computerModel, equals('Suunto D5'));
      },
    );

    test('maps all metadata fields correctly', () async {
      final diveId = await insertTestDive(id: 'dive-full-metadata');
      final entryTime = DateTime.utc(2024, 6, 15, 10, 0);
      final exitTime = DateTime.utc(2024, 6, 15, 10, 45);

      await repository.saveComputerReading(
        buildReading(
          id: 'reading-full',
          diveId: diveId,
          isPrimary: true,
          computerModel: 'Shearwater Perdix',
          computerSerial: 'SN-12345',
          maxDepth: 35.5,
          avgDepth: 18.2,
          duration: 2700,
          waterTemp: 22.5,
          entryTime: entryTime,
          exitTime: exitTime,
          surfaceInterval: 3600,
          cns: 42.0,
          decoAlgorithm: 'Buhlmann ZHL-16C',
          gradientFactorLow: 30,
          gradientFactorHigh: 70,
        ),
      );

      final sources = await repository.getDataSources(diveId);

      expect(sources.length, equals(1));
      final s = sources.first;
      expect(s.id, equals('reading-full'));
      expect(s.diveId, equals(diveId));
      expect(s.isPrimary, isTrue);
      expect(s.computerModel, equals('Shearwater Perdix'));
      expect(s.computerSerial, equals('SN-12345'));
      expect(s.maxDepth, equals(35.5));
      expect(s.avgDepth, equals(18.2));
      expect(s.duration, equals(2700));
      expect(s.waterTemp, equals(22.5));
      expect(
        s.entryTime?.millisecondsSinceEpoch,
        equals(entryTime.millisecondsSinceEpoch),
      );
      expect(
        s.exitTime?.millisecondsSinceEpoch,
        equals(exitTime.millisecondsSinceEpoch),
      );
      expect(s.surfaceInterval, equals(3600));
      expect(s.cns, equals(42.0));
      expect(s.decoAlgorithm, equals('Buhlmann ZHL-16C'));
      expect(s.gradientFactorLow, equals(30));
      expect(s.gradientFactorHigh, equals(70));
    });

    test('does not return data sources from other dives', () async {
      final diveA = await insertTestDive(id: 'dive-a');
      final diveB = await insertTestDive(id: 'dive-b');

      await repository.saveComputerReading(
        buildReading(
          id: 'reading-for-a',
          diveId: diveA,
          isPrimary: true,
          computerModel: 'Computer A',
        ),
      );
      await repository.saveComputerReading(
        buildReading(
          id: 'reading-for-b',
          diveId: diveB,
          isPrimary: true,
          computerModel: 'Computer B',
        ),
      );

      final sourcesA = await repository.getDataSources(diveA);

      expect(sourcesA.length, equals(1));
      expect(sourcesA.first.id, equals('reading-for-a'));
    });
  });

  // ---------------------------------------------------------------------------
  // hasMultipleDataSources
  // ---------------------------------------------------------------------------

  group('hasMultipleDataSources', () {
    test('returns false when no data sources exist', () async {
      final diveId = await insertTestDive(id: 'dive-none');

      final result = await repository.hasMultipleDataSources(diveId);

      expect(result, isFalse);
    });

    test('returns false with exactly one data source', () async {
      final diveId = await insertTestDive(id: 'dive-single');

      await repository.saveComputerReading(
        buildReading(id: 'only-reading', diveId: diveId, isPrimary: true),
      );

      final result = await repository.hasMultipleDataSources(diveId);

      expect(result, isFalse);
    });

    test('returns true with two or more data sources', () async {
      final diveId = await insertTestDive(id: 'dive-multi');

      await repository.saveComputerReading(
        buildReading(id: 'reading-1', diveId: diveId, isPrimary: true),
      );
      await repository.saveComputerReading(
        buildReading(id: 'reading-2', diveId: diveId, isPrimary: false),
      );

      final result = await repository.hasMultipleDataSources(diveId);

      expect(result, isTrue);
    });

    test('returns true with three data sources', () async {
      final diveId = await insertTestDive(id: 'dive-triple');

      await repository.saveComputerReading(
        buildReading(id: 'r1', diveId: diveId, isPrimary: true),
      );
      await repository.saveComputerReading(
        buildReading(id: 'r2', diveId: diveId, isPrimary: false),
      );
      await repository.saveComputerReading(
        buildReading(id: 'r3', diveId: diveId, isPrimary: false),
      );

      final result = await repository.hasMultipleDataSources(diveId);

      expect(result, isTrue);
    });

    test('does not count data sources from other dives', () async {
      final diveA = await insertTestDive(id: 'dive-a-count');
      final diveB = await insertTestDive(id: 'dive-b-count');

      await repository.saveComputerReading(
        buildReading(id: 'ra', diveId: diveA, isPrimary: true),
      );
      await repository.saveComputerReading(
        buildReading(id: 'rb', diveId: diveB, isPrimary: true),
      );

      final result = await repository.hasMultipleDataSources(diveA);

      expect(result, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // saveComputerReading
  // ---------------------------------------------------------------------------

  group('saveComputerReading', () {
    test('inserts a reading that can be retrieved', () async {
      final diveId = await insertTestDive(id: 'dive-save-reading');

      await repository.saveComputerReading(
        buildReading(
          id: 'new-reading',
          diveId: diveId,
          isPrimary: true,
          computerModel: 'Garmin MK2i',
          maxDepth: 25.0,
        ),
      );

      final sources = await repository.getDataSources(diveId);
      expect(sources.length, equals(1));
      expect(sources.first.id, equals('new-reading'));
      expect(sources.first.computerModel, equals('Garmin MK2i'));
      expect(sources.first.maxDepth, equals(25.0));
    });

    test('can insert multiple readings for the same dive', () async {
      final diveId = await insertTestDive(id: 'dive-multi-save');

      await repository.saveComputerReading(
        buildReading(id: 'r-first', diveId: diveId, isPrimary: true),
      );
      await repository.saveComputerReading(
        buildReading(id: 'r-second', diveId: diveId, isPrimary: false),
      );

      final sources = await repository.getDataSources(diveId);
      expect(sources.length, equals(2));
    });
  });

  // ---------------------------------------------------------------------------
  // deleteComputerReading
  // ---------------------------------------------------------------------------

  group('deleteComputerReading', () {
    test('removes the specified reading', () async {
      final diveId = await insertTestDive(id: 'dive-delete-reading');

      await repository.saveComputerReading(
        buildReading(id: 'to-delete', diveId: diveId, isPrimary: false),
      );
      await repository.saveComputerReading(
        buildReading(id: 'to-keep', diveId: diveId, isPrimary: true),
      );

      await repository.deleteComputerReading('to-delete');

      final sources = await repository.getDataSources(diveId);
      expect(sources.length, equals(1));
      expect(sources.first.id, equals('to-keep'));
    });

    test('does not throw when deleting non-existent reading', () async {
      await expectLater(
        repository.deleteComputerReading('non-existent-id'),
        completes,
      );
    });

    test('does not affect readings from other dives', () async {
      final diveA = await insertTestDive(id: 'dive-a-del');
      final diveB = await insertTestDive(id: 'dive-b-del');

      await repository.saveComputerReading(
        buildReading(id: 'ra-del', diveId: diveA, isPrimary: true),
      );
      await repository.saveComputerReading(
        buildReading(id: 'rb-del', diveId: diveB, isPrimary: true),
      );

      await repository.deleteComputerReading('ra-del');

      final sourcesB = await repository.getDataSources(diveB);
      expect(sourcesB.length, equals(1));
      expect(sourcesB.first.id, equals('rb-del'));
    });
  });

  // ---------------------------------------------------------------------------
  // backfillPrimaryDataSource
  // ---------------------------------------------------------------------------

  group('backfillPrimaryDataSource', () {
    test('creates a primary data source from dive metadata', () async {
      final diveId = await insertTestDive(
        id: 'dive-backfill',
        diveComputerModel: 'Shearwater Teric',
        diveComputerSerial: 'SN-TERIC-001',
        maxDepth: 42.0,
        avgDepth: 22.0,
        duration: 3600,
        waterTemp: 15.5,
        surfaceIntervalSeconds: 7200,
        cnsEnd: 55.0,
        decoAlgorithm: 'VPM-B',
        gradientFactorLow: 35,
        gradientFactorHigh: 75,
      );

      await repository.backfillPrimaryDataSource(diveId);

      final sources = await repository.getDataSources(diveId);
      expect(sources.length, equals(1));

      final s = sources.first;
      expect(s.isPrimary, isTrue);
      expect(s.computerModel, equals('Shearwater Teric'));
      expect(s.computerSerial, equals('SN-TERIC-001'));
      expect(s.maxDepth, equals(42.0));
      expect(s.avgDepth, equals(22.0));
      expect(s.duration, equals(3600));
      expect(s.waterTemp, equals(15.5));
      expect(s.surfaceInterval, equals(7200));
      expect(s.cns, equals(55.0));
      expect(s.decoAlgorithm, equals('VPM-B'));
      expect(s.gradientFactorLow, equals(35));
      expect(s.gradientFactorHigh, equals(75));
    });

    test('no-ops when a primary data source already exists', () async {
      final diveId = await insertTestDive(
        id: 'dive-backfill-noop',
        diveComputerModel: 'Original',
        maxDepth: 30.0,
      );

      // Insert existing primary reading.
      await repository.saveComputerReading(
        buildReading(
          id: 'existing-primary',
          diveId: diveId,
          isPrimary: true,
          computerModel: 'Already Primary',
        ),
      );

      await repository.backfillPrimaryDataSource(diveId);

      final sources = await repository.getDataSources(diveId);
      // Should still be exactly 1 — the existing primary, not a new one.
      expect(sources.length, equals(1));
      expect(sources.first.id, equals('existing-primary'));
      expect(sources.first.computerModel, equals('Already Primary'));
    });

    test('no-ops when the dive does not exist', () async {
      // Should not throw.
      await expectLater(
        repository.backfillPrimaryDataSource('non-existent-dive'),
        completes,
      );
    });

    test('backfills entry and exit times from dive row', () async {
      final entry = DateTime.utc(2024, 6, 15, 10, 0);
      final exit = DateTime.utc(2024, 6, 15, 10, 45);

      final diveId = await insertTestDive(
        id: 'dive-backfill-times',
        entryTime: entry.millisecondsSinceEpoch,
        exitTime: exit.millisecondsSinceEpoch,
      );

      await repository.backfillPrimaryDataSource(diveId);

      final sources = await repository.getDataSources(diveId);
      expect(sources.length, equals(1));
      expect(
        sources.first.entryTime?.millisecondsSinceEpoch,
        equals(entry.millisecondsSinceEpoch),
      );
      expect(
        sources.first.exitTime?.millisecondsSinceEpoch,
        equals(exit.millisecondsSinceEpoch),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // getImportIds
  // ---------------------------------------------------------------------------

  group('getImportIds', () {
    test('returns empty set when no dives have import IDs', () async {
      await insertTestDive(id: 'dive-no-import');

      final ids = await repository.getImportIds();

      expect(ids, isEmpty);
    });

    test('returns import IDs from all dives', () async {
      await insertTestDive(id: 'dive-import-1', importId: 'import-aaa');
      await insertTestDive(id: 'dive-import-2', importId: 'import-bbb');
      await insertTestDive(id: 'dive-no-import');

      final ids = await repository.getImportIds();

      expect(ids.length, equals(2));
      expect(ids, contains('import-aaa'));
      expect(ids, contains('import-bbb'));
    });

    test('filters by diverId when provided', () async {
      await insertTestDiver('diver-a');
      await insertTestDiver('diver-b');
      await insertTestDive(
        id: 'dive-diver-a',
        diverId: 'diver-a',
        importId: 'import-a1',
      );
      await insertTestDive(
        id: 'dive-diver-b',
        diverId: 'diver-b',
        importId: 'import-b1',
      );

      final idsA = await repository.getImportIds(diverId: 'diver-a');

      expect(idsA.length, equals(1));
      expect(idsA, contains('import-a1'));
      expect(idsA, isNot(contains('import-b1')));
    });

    test('returns all import IDs without diverId filter', () async {
      await insertTestDiver('diver-x');
      await insertTestDiver('diver-y');
      await insertTestDive(
        id: 'dive-all-1',
        diverId: 'diver-x',
        importId: 'import-x1',
      );
      await insertTestDive(
        id: 'dive-all-2',
        diverId: 'diver-y',
        importId: 'import-y1',
      );

      final ids = await repository.getImportIds();

      expect(ids.length, equals(2));
      expect(ids, contains('import-x1'));
      expect(ids, contains('import-y1'));
    });

    test('does not return duplicate import IDs', () async {
      // Each dive gets a unique import ID, so the set should deduplicate.
      await insertTestDive(id: 'dive-dup-1', importId: 'same-import');
      // Note: This inserts a second dive with the same importId which should
      // still result in a single entry in the returned set.
      await insertTestDive(id: 'dive-dup-2', importId: 'same-import');

      final ids = await repository.getImportIds();

      expect(ids.length, equals(1));
      expect(ids, contains('same-import'));
    });
  });

  // ---------------------------------------------------------------------------
  // getDiveNumberForDate
  // ---------------------------------------------------------------------------

  group('getDiveNumberForDate', () {
    test(
      'returns MAX(dive_number) + 1 via delegation to getNextDiveNumber',
      () async {
        // Insert dives with known dive numbers.
        await insertTestDive(id: 'dive-num-1', diveNumber: 10);
        await insertTestDive(id: 'dive-num-2', diveNumber: 25);
        await insertTestDive(id: 'dive-num-3', diveNumber: 15);

        // getDiveNumberForDate now delegates to getNextDiveNumber (MAX + 1).
        final result = await repository.getDiveNumberForDate(DateTime.now());

        // MAX is 25, so next number should be 26.
        expect(result, equals(26));
      },
    );

    test('returns 1 when no dives exist', () async {
      final result = await repository.getDiveNumberForDate(DateTime.now());

      expect(result, equals(1));
    });

    test(
      'ignores the dateTime parameter (delegates to getNextDiveNumber)',
      () async {
        final now = DateTime.now();
        await insertTestDive(
          id: 'dive-early',
          diveNumber: 5,
          diveDateTime: now
              .subtract(const Duration(days: 30))
              .millisecondsSinceEpoch,
        );
        await insertTestDive(
          id: 'dive-late',
          diveNumber: 20,
          diveDateTime: now
              .add(const Duration(days: 30))
              .millisecondsSinceEpoch,
        );

        // Regardless of the dateTime passed, it should return MAX + 1.
        final resultEarly = await repository.getDiveNumberForDate(
          now.subtract(const Duration(days: 60)),
        );
        final resultLate = await repository.getDiveNumberForDate(
          now.add(const Duration(days: 60)),
        );

        // Both should return the same value: 21 (MAX=20, +1).
        expect(resultEarly, equals(21));
        expect(resultLate, equals(21));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // restoreOriginalProfile (updated multi-computer behavior)
  // ---------------------------------------------------------------------------

  group('restoreOriginalProfile', () {
    test(
      'single-computer dive: deletes edited profiles and restores all originals',
      () async {
        final diveId = await insertTestDive(id: 'dive-restore-single');

        // Original profiles (will be demoted to non-primary before edit).
        await insertTestProfile(
          diveId: diveId,
          sourceTag: 'orig-1',
          isPrimary: false,
          timestamp: 0,
          depth: 10.0,
        );
        await insertTestProfile(
          diveId: diveId,
          sourceTag: 'orig-2',
          isPrimary: false,
          timestamp: 60,
          depth: 20.0,
        );

        // Edited profiles (currently primary, computerId=null).
        await insertTestProfile(
          diveId: diveId,
          sourceTag: 'edited-1',
          isPrimary: true,
          timestamp: 0,
          depth: 12.0,
        );
        await insertTestProfile(
          diveId: diveId,
          sourceTag: 'edited-2',
          isPrimary: true,
          timestamp: 60,
          depth: 22.0,
        );

        await repository.restoreOriginalProfile(diveId);

        final profiles = await (db.select(
          db.diveProfiles,
        )..where((t) => t.diveId.equals(diveId))).get();

        // Edited profiles should be deleted, originals restored to primary.
        expect(profiles.length, equals(2));
        for (final p in profiles) {
          expect(p.isPrimary, isTrue);
        }
        // Verify we have the original depths.
        final depths = profiles.map((p) => p.depth).toList()..sort();
        expect(depths, equals([10.0, 20.0]));
      },
    );

    test(
      'multi-computer dive with primary data source: only restores primary computer profiles',
      () async {
        // Create a dive computer row to use as FK.
        const computerId = 'computer-primary-id';
        final now = DateTime.now().millisecondsSinceEpoch;
        await db
            .into(db.diveComputers)
            .insert(
              DiveComputersCompanion(
                id: const Value(computerId),
                name: const Value('Shearwater Petrel'),
                model: const Value('Shearwater Petrel'),
                serialNumber: const Value('SN-001'),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );

        final diveId = await insertTestDive(id: 'dive-restore-multi');

        // Create a primary data source pointing to the computer.
        await repository.saveComputerReading(
          DiveDataSourcesCompanion(
            id: const Value('ds-primary'),
            diveId: Value(diveId),
            computerId: const Value(computerId),
            isPrimary: const Value(true),
            computerModel: const Value('Shearwater Petrel'),
            importedAt: Value(DateTime.now()),
            createdAt: Value(DateTime.now()),
          ),
        );

        // Original primary computer profiles (demoted to non-primary).
        await insertTestProfile(
          diveId: diveId,
          sourceTag: 'comp-orig-1',
          isPrimary: false,
          timestamp: 0,
          depth: 10.0,
          computerId: computerId,
        );
        await insertTestProfile(
          diveId: diveId,
          sourceTag: 'comp-orig-2',
          isPrimary: false,
          timestamp: 60,
          depth: 20.0,
          computerId: computerId,
        );

        // Secondary computer profiles (should remain non-primary).
        await insertTestProfile(
          diveId: diveId,
          sourceTag: 'sec-1',
          isPrimary: false,
          timestamp: 0,
          depth: 9.5,
          // No computerId - secondary computer.
        );

        // Edited profiles (primary, computerId=null).
        await insertTestProfile(
          diveId: diveId,
          sourceTag: 'edited-1',
          isPrimary: true,
          timestamp: 0,
          depth: 12.0,
        );

        await repository.restoreOriginalProfile(diveId);

        final profiles = await (db.select(
          db.diveProfiles,
        )..where((t) => t.diveId.equals(diveId))).get();

        // Edited profile deleted. Primary computer profiles restored.
        // Secondary computer profile remains non-primary.
        final primaryProfiles = profiles.where((p) => p.isPrimary).toList();
        final nonPrimaryProfiles = profiles.where((p) => !p.isPrimary).toList();

        expect(primaryProfiles.length, equals(2));
        for (final p in primaryProfiles) {
          expect(p.computerId, equals(computerId));
        }

        expect(nonPrimaryProfiles.length, equals(1));
        expect(nonPrimaryProfiles.first.depth, equals(9.5));
      },
    );

    test(
      'no-primary data source: restores all remaining profiles to primary',
      () async {
        final diveId = await insertTestDive(id: 'dive-restore-no-ds');

        // Non-primary data source (no primary data source exists).
        await repository.saveComputerReading(
          buildReading(
            id: 'ds-non-primary',
            diveId: diveId,
            isPrimary: false,
            computerModel: 'Some Computer',
          ),
        );

        // Original profiles (non-primary).
        await insertTestProfile(
          diveId: diveId,
          sourceTag: 'orig-a',
          isPrimary: false,
          timestamp: 0,
          depth: 15.0,
        );
        await insertTestProfile(
          diveId: diveId,
          sourceTag: 'orig-b',
          isPrimary: false,
          timestamp: 60,
          depth: 25.0,
        );

        // Edited profiles (primary, to be deleted).
        await insertTestProfile(
          diveId: diveId,
          sourceTag: 'edited',
          isPrimary: true,
          timestamp: 0,
          depth: 16.0,
        );

        await repository.restoreOriginalProfile(diveId);

        final profiles = await (db.select(
          db.diveProfiles,
        )..where((t) => t.diveId.equals(diveId))).get();

        // Edited profile deleted. Remaining profiles all promoted.
        expect(profiles.length, equals(2));
        for (final p in profiles) {
          expect(p.isPrimary, isTrue);
        }
      },
    );
  });

  // ---------------------------------------------------------------------------
  // computerSerial filter in getDiveSummaries
  // ---------------------------------------------------------------------------

  group('computerSerial filter', () {
    test('filters dives by computer serial number', () async {
      await insertTestDive(
        id: 'dive-serial-a',
        diveNumber: 1,
        diveComputerSerial: 'SN-AAA',
        diveComputerModel: 'Computer A',
      );
      await insertTestDive(
        id: 'dive-serial-b',
        diveNumber: 2,
        diveComputerSerial: 'SN-BBB',
        diveComputerModel: 'Computer B',
      );
      await insertTestDive(
        id: 'dive-serial-a2',
        diveNumber: 3,
        diveComputerSerial: 'SN-AAA',
        diveComputerModel: 'Computer A',
      );

      final summaries = await repository.getDiveSummaries(
        filter: const DiveFilterState(computerSerial: 'SN-AAA'),
      );

      expect(summaries.length, equals(2));
      final ids = summaries.map((s) => s.id).toSet();
      expect(ids, contains('dive-serial-a'));
      expect(ids, contains('dive-serial-a2'));
      expect(ids, isNot(contains('dive-serial-b')));
    });

    test('returns empty list when no dives match the serial', () async {
      await insertTestDive(
        id: 'dive-no-match',
        diveNumber: 1,
        diveComputerSerial: 'SN-CCC',
      );

      final summaries = await repository.getDiveSummaries(
        filter: const DiveFilterState(computerSerial: 'SN-NONEXISTENT'),
      );

      expect(summaries, isEmpty);
    });

    test('returns all dives when computerSerial filter is null', () async {
      await insertTestDive(
        id: 'dive-unfiltered-1',
        diveNumber: 1,
        diveComputerSerial: 'SN-111',
      );
      await insertTestDive(
        id: 'dive-unfiltered-2',
        diveNumber: 2,
        diveComputerSerial: 'SN-222',
      );

      final summaries = await repository.getDiveSummaries(
        filter: const DiveFilterState(),
      );

      expect(summaries.length, equals(2));
    });
  });

  // ---------------------------------------------------------------------------
  // createDive and updateDive with importSource / importId
  // ---------------------------------------------------------------------------

  group('importSource / importId round-trip', () {
    test('createDive persists importSource and importId', () async {
      final dive = domain.Dive(
        id: 'dive-import-src',
        dateTime: DateTime(2026, 3, 20, 10, 0),
        notes: '',
        importSource: 'garmin',
        importId: 'garmin-activity-12345',
      );

      final created = await repository.createDive(dive);
      expect(created.importSource, equals('garmin'));
      expect(created.importId, equals('garmin-activity-12345'));

      // Verify via raw query that the columns were set.
      final row = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('dive-import-src'))).getSingle();
      expect(row.importSource, equals('garmin'));
      expect(row.importId, equals('garmin-activity-12345'));
    });

    test('updateDive persists changed importSource and importId', () async {
      // Create a dive with no import fields.
      final dive = domain.Dive(
        id: 'dive-upd-import',
        dateTime: DateTime(2026, 3, 20, 10, 0),
        notes: '',
      );
      await repository.createDive(dive);

      // Update with import fields.
      await repository.updateDive(
        dive.copyWith(importSource: 'suunto', importId: 'suunto-abc-999'),
      );

      final row = await (db.select(
        db.dives,
      )..where((t) => t.id.equals('dive-upd-import'))).getSingle();
      expect(row.importSource, equals('suunto'));
      expect(row.importId, equals('suunto-abc-999'));
    });

    test(
      'getAllDives returns importSource and importId on domain entity',
      () async {
        await insertTestDive(
          id: 'dive-read-import',
          importId: 'garmin-xyz',
          diveNumber: 1,
        );

        final dives = await repository.getAllDives();
        final dive = dives.firstWhere((d) => d.id == 'dive-read-import');
        expect(dive.importId, equals('garmin-xyz'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // setPrimaryDataSource
  // ---------------------------------------------------------------------------

  group('setPrimaryDataSource', () {
    test('promotes specified reading and demotes others', () async {
      final diveId = await insertTestDive(id: 'dive-set-primary');

      await repository.saveComputerReading(
        buildReading(
          id: 'reading-a',
          diveId: diveId,
          isPrimary: true,
          computerModel: 'Computer A',
          maxDepth: 30.0,
        ),
      );
      await repository.saveComputerReading(
        buildReading(
          id: 'reading-b',
          diveId: diveId,
          isPrimary: false,
          computerModel: 'Computer B',
          maxDepth: 40.0,
        ),
      );

      await repository.setPrimaryDataSource(
        diveId: diveId,
        computerReadingId: 'reading-b',
      );

      final sources = await repository.getDataSources(diveId);
      final readingA = sources.firstWhere((s) => s.id == 'reading-a');
      final readingB = sources.firstWhere((s) => s.id == 'reading-b');

      expect(readingA.isPrimary, isFalse);
      expect(readingB.isPrimary, isTrue);
    });

    test('updates dive metadata from new primary reading', () async {
      final diveId = await insertTestDive(
        id: 'dive-meta-update',
        diveComputerModel: 'Computer A',
        maxDepth: 30.0,
      );

      await repository.saveComputerReading(
        buildReading(
          id: 'reading-old',
          diveId: diveId,
          isPrimary: true,
          computerModel: 'Computer A',
          computerSerial: 'SN-OLD',
          maxDepth: 30.0,
        ),
      );
      await repository.saveComputerReading(
        buildReading(
          id: 'reading-new',
          diveId: diveId,
          isPrimary: false,
          computerModel: 'Computer B',
          computerSerial: 'SN-NEW',
          maxDepth: 45.0,
          avgDepth: 25.0,
          duration: 3600,
          waterTemp: 18.0,
        ),
      );

      await repository.setPrimaryDataSource(
        diveId: diveId,
        computerReadingId: 'reading-new',
      );

      final diveRow = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(diveId))).getSingle();

      expect(diveRow.diveComputerModel, equals('Computer B'));
      expect(diveRow.diveComputerSerial, equals('SN-NEW'));
      expect(diveRow.maxDepth, equals(45.0));
      expect(diveRow.avgDepth, equals(25.0));
      expect(diveRow.bottomTime, equals(3600));
      expect(diveRow.waterTemp, equals(18.0));
    });

    test('no-ops when computerReadingId does not exist', () async {
      final diveId = await insertTestDive(id: 'dive-noop-primary');

      await repository.saveComputerReading(
        buildReading(
          id: 'reading-existing',
          diveId: diveId,
          isPrimary: true,
          computerModel: 'Original',
        ),
      );

      // Non-existent reading should not change anything.
      await repository.setPrimaryDataSource(
        diveId: diveId,
        computerReadingId: 'non-existent-reading',
      );

      final sources = await repository.getDataSources(diveId);
      expect(sources.length, equals(1));
      expect(sources.first.isPrimary, isTrue);
      expect(sources.first.computerModel, equals('Original'));
    });

    test('swaps profile isPrimary for the new primary computer', () async {
      // Create a dive computer row to use as FK.
      const compAId = 'comp-a-primary';
      const compBId = 'comp-b-primary';
      final now = DateTime.now().millisecondsSinceEpoch;

      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: const Value(compAId),
              name: const Value('Computer A'),
              model: const Value('Computer A'),
              serialNumber: const Value('SN-A'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: const Value(compBId),
              name: const Value('Computer B'),
              model: const Value('Computer B'),
              serialNumber: const Value('SN-B'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      final diveId = await insertTestDive(id: 'dive-swap-profiles');

      // Save two readings, one with each computer.
      await repository.saveComputerReading(
        DiveDataSourcesCompanion(
          id: const Value('ds-a'),
          diveId: Value(diveId),
          computerId: const Value(compAId),
          isPrimary: const Value(true),
          computerModel: const Value('Computer A'),
          importedAt: Value(DateTime.now()),
          createdAt: Value(DateTime.now()),
        ),
      );
      await repository.saveComputerReading(
        DiveDataSourcesCompanion(
          id: const Value('ds-b'),
          diveId: Value(diveId),
          computerId: const Value(compBId),
          isPrimary: const Value(false),
          computerModel: const Value('Computer B'),
          importedAt: Value(DateTime.now()),
          createdAt: Value(DateTime.now()),
        ),
      );

      // Insert profiles for both computers.
      await insertTestProfile(
        diveId: diveId,
        sourceTag: 'a-1',
        isPrimary: true,
        timestamp: 0,
        depth: 10.0,
        computerId: compAId,
      );
      await insertTestProfile(
        diveId: diveId,
        sourceTag: 'b-1',
        isPrimary: false,
        timestamp: 0,
        depth: 12.0,
        computerId: compBId,
      );

      // Switch primary to Computer B.
      await repository.setPrimaryDataSource(
        diveId: diveId,
        computerReadingId: 'ds-b',
      );

      final profiles = await (db.select(
        db.diveProfiles,
      )..where((t) => t.diveId.equals(diveId))).get();

      final compAProfiles = profiles.where((p) => p.computerId == compAId);
      final compBProfiles = profiles.where((p) => p.computerId == compBId);

      // Computer A profiles should be demoted.
      for (final p in compAProfiles) {
        expect(p.isPrimary, isFalse);
      }
      // Computer B profiles should be promoted.
      for (final p in compBProfiles) {
        expect(p.isPrimary, isTrue);
      }
    });

    test('handles reading with null computerId (no profile swap)', () async {
      final diveId = await insertTestDive(id: 'dive-null-comp');

      // Save a reading without computerId.
      await repository.saveComputerReading(
        buildReading(
          id: 'reading-no-comp',
          diveId: diveId,
          isPrimary: false,
          computerModel: 'Manual Entry',
          maxDepth: 20.0,
        ),
      );

      await repository.saveComputerReading(
        buildReading(
          id: 'reading-primary',
          diveId: diveId,
          isPrimary: true,
          computerModel: 'Original',
        ),
      );

      // Insert a profile with no computerId.
      await insertTestProfile(
        diveId: diveId,
        sourceTag: 'p1',
        isPrimary: true,
        timestamp: 0,
        depth: 15.0,
      );

      // Switch primary to reading with no computerId.
      await repository.setPrimaryDataSource(
        diveId: diveId,
        computerReadingId: 'reading-no-comp',
      );

      // The data source should be promoted.
      final sources = await repository.getDataSources(diveId);
      final promoted = sources.firstWhere((s) => s.id == 'reading-no-comp');
      expect(promoted.isPrimary, isTrue);

      // Profile should be demoted (since computerId is null, no profiles
      // are re-promoted).
      final profiles = await (db.select(
        db.diveProfiles,
      )..where((t) => t.diveId.equals(diveId))).get();

      for (final p in profiles) {
        expect(p.isPrimary, isFalse);
      }
    });
  });
}
