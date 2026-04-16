import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';

void main() {
  late AppDatabase db;
  late ReparseService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = ReparseService(db: db);
  });

  tearDown(() => db.close());

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  final nowMs = DateTime.utc(2026, 1, 15, 10, 0).millisecondsSinceEpoch;

  Future<void> insertDive(
    String id, {
    double? maxDepth,
    double? avgDepth,
    int? runtime,
    int? diveDateTime,
    double? waterTemp,
    String? notes,
    int? rating,
    String? siteId,
    String? buddy,
    String diveMode = 'oc',
    double? cnsEnd,
    double? otu,
    int? gradientFactorLow,
    int? gradientFactorHigh,
    String? decoAlgorithm,
    int? decoConservatism,
    bool isFavorite = false,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(diveDateTime ?? nowMs),
            maxDepth: Value(maxDepth),
            avgDepth: Value(avgDepth),
            runtime: Value(runtime),
            waterTemp: Value(waterTemp),
            notes: Value(notes ?? ''),
            rating: Value(rating),
            siteId: Value(siteId),
            buddy: Value(buddy),
            diveMode: Value(diveMode),
            cnsEnd: Value(cnsEnd),
            otu: Value(otu),
            gradientFactorLow: Value(gradientFactorLow),
            gradientFactorHigh: Value(gradientFactorHigh),
            decoAlgorithm: Value(decoAlgorithm),
            decoConservatism: Value(decoConservatism),
            isFavorite: Value(isFavorite),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
  }

  Future<void> insertComputer(String id) async {
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value('Test Computer $id'),
            createdAt: Value(nowMs),
            updatedAt: Value(nowMs),
          ),
        );
  }

  Future<void> insertSource({
    required String id,
    required String diveId,
    String? computerId,
    bool isPrimary = true,
    double? maxDepth,
    double? avgDepth,
    int? duration,
    double? waterTemp,
  }) async {
    final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
    await db
        .into(db.diveDataSources)
        .insert(
          DiveDataSourcesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            computerId: Value(computerId),
            isPrimary: Value(isPrimary),
            sourceFormat: const Value('dive_computer'),
            maxDepth: Value(maxDepth),
            avgDepth: Value(avgDepth),
            duration: Value(duration),
            waterTemp: Value(waterTemp),
            importedAt: Value(now),
            createdAt: Value(now),
          ),
        );
  }

  Future<void> insertProfile({
    required String id,
    required String diveId,
    String? computerId,
    required int timestamp,
    required double depth,
    bool isPrimary = true,
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
            isPrimary: Value(isPrimary),
          ),
        );
  }

  pigeon.ParsedDive makeParsedDive({
    double maxDepthMeters = 25.0,
    double avgDepthMeters = 14.0,
    int durationSeconds = 3000,
    double? minTemperatureCelsius = 18.0,
    String? diveMode,
    String? decoAlgorithm = 'buhlmann',
    int? gfLow = 30,
    int? gfHigh = 70,
    int? decoConservatism,
    int year = 2026,
    int month = 1,
    int day = 15,
    int hour = 10,
    int minute = 0,
    int second = 0,
    List<pigeon.ProfileSample>? samples,
    List<pigeon.TankInfo>? tanks,
    List<pigeon.GasMix>? gasMixes,
    List<pigeon.DiveEvent>? events,
  }) {
    return pigeon.ParsedDive(
      fingerprint: 'test-fp',
      dateTimeYear: year,
      dateTimeMonth: month,
      dateTimeDay: day,
      dateTimeHour: hour,
      dateTimeMinute: minute,
      dateTimeSecond: second,
      maxDepthMeters: maxDepthMeters,
      avgDepthMeters: avgDepthMeters,
      durationSeconds: durationSeconds,
      minTemperatureCelsius: minTemperatureCelsius,
      samples:
          samples ??
          [
            pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
            pigeon.ProfileSample(timeSeconds: 60, depthMeters: 10.0),
            pigeon.ProfileSample(
              timeSeconds: 120,
              depthMeters: 25.0,
              temperatureCelsius: 18.0,
            ),
            pigeon.ProfileSample(timeSeconds: 180, depthMeters: 5.0),
          ],
      tanks: tanks ?? [],
      gasMixes: gasMixes ?? [],
      events: events ?? [],
      diveMode: diveMode,
      decoAlgorithm: decoAlgorithm,
      gfLow: gfLow,
      gfHigh: gfHigh,
      decoConservatism: decoConservatism,
    );
  }

  Future<Dive> getDive(String id) async {
    return (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();
  }

  Future<DiveDataSourcesData> getSource(String id) async {
    return (db.select(
      db.diveDataSources,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  group('ReparseService.applyParsedUpdate', () {
    test('overwrites computer-authored fields on primary source', () async {
      // Arrange: create dive with known values
      await insertDive(
        'dive-1',
        maxDepth: 20.0,
        avgDepth: 10.0,
        runtime: 2400,
        waterTemp: 22.0,
        diveMode: 'oc',
        decoAlgorithm: 'rgbm',
        gradientFactorLow: 40,
        gradientFactorHigh: 85,
      );
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
        maxDepth: 20.0,
        avgDepth: 10.0,
        duration: 2400,
        waterTemp: 22.0,
      );

      // Act: apply a parsed update with different computer-authored values
      final parsed = makeParsedDive(
        maxDepthMeters: 30.0,
        avgDepthMeters: 16.0,
        durationSeconds: 3600,
        minTemperatureCelsius: 15.0,
        decoAlgorithm: 'buhlmann',
        gfLow: 30,
        gfHigh: 70,
        diveMode: 'ccr',
      );

      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: parsed,
        descriptorVendor: 'Shearwater',
        descriptorProduct: 'Perdix',
        descriptorModel: 42,
        libdivecomputerVersion: '0.8.0',
      );

      // Assert: computer-authored fields are updated
      final dive = await getDive('dive-1');
      expect(dive.maxDepth, 30.0);
      expect(dive.avgDepth, 16.0);
      expect(dive.runtime, 3600);
      expect(dive.waterTemp, 15.0);
      expect(dive.diveMode, 'ccr');
      expect(dive.decoAlgorithm, 'buhlmann');
      expect(dive.gradientFactorLow, 30);
      expect(dive.gradientFactorHigh, 70);
    });

    test('preserves user-authored fields on primary source', () async {
      // Arrange: create dive with user-authored fields set
      await insertDive(
        'dive-1',
        maxDepth: 20.0,
        notes: 'Great visibility today!',
        rating: 5,
        buddy: 'Alice',
        isFavorite: true,
      );
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      // Act
      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: makeParsedDive(maxDepthMeters: 30.0),
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
        libdivecomputerVersion: null,
      );

      // Assert: user-authored fields are NOT changed
      final dive = await getDive('dive-1');
      expect(dive.notes, 'Great visibility today!');
      expect(dive.rating, 5);
      expect(dive.buddy, 'Alice');
      expect(dive.isFavorite, true);
    });

    test('does NOT update Dives row for non-primary source', () async {
      // Arrange
      await insertDive('dive-1', maxDepth: 20.0, avgDepth: 10.0, runtime: 2400);
      await insertComputer('comp-1');
      await insertComputer('comp-2');
      // Primary source from comp-1
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );
      // Non-primary source from comp-2
      await insertSource(
        id: 'src-2',
        diveId: 'dive-1',
        computerId: 'comp-2',
        isPrimary: false,
      );

      // Act: update the non-primary source
      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-2',
        parsed: makeParsedDive(
          maxDepthMeters: 35.0,
          avgDepthMeters: 20.0,
          durationSeconds: 4000,
        ),
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
        libdivecomputerVersion: null,
      );

      // Assert: Dives row fields remain at original values
      final dive = await getDive('dive-1');
      expect(dive.maxDepth, 20.0);
      expect(dive.avgDepth, 10.0);
      expect(dive.runtime, 2400);
    });

    test('updates DiveDataSources snapshot fields and lastParsedAt', () async {
      // Arrange
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
        maxDepth: 20.0,
        avgDepth: 10.0,
        duration: 2400,
        waterTemp: 22.0,
      );

      // Act
      final parsed = makeParsedDive(
        maxDepthMeters: 28.5,
        avgDepthMeters: 15.5,
        durationSeconds: 3200,
        minTemperatureCelsius: 17.0,
        decoAlgorithm: 'vpm',
        gfLow: 25,
        gfHigh: 75,
      );

      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: parsed,
        descriptorVendor: 'Suunto',
        descriptorProduct: 'EON Core',
        descriptorModel: 99,
        libdivecomputerVersion: '0.9.0',
      );

      // Assert: snapshot fields on source row are updated
      final src = await getSource('src-1');
      expect(src.maxDepth, 28.5);
      expect(src.avgDepth, 15.5);
      expect(src.duration, 3200);
      expect(src.waterTemp, 17.0);
      expect(src.decoAlgorithm, 'vpm');
      expect(src.gradientFactorLow, 25);
      expect(src.gradientFactorHigh, 75);
      expect(src.descriptorVendor, 'Suunto');
      expect(src.descriptorProduct, 'EON Core');
      expect(src.descriptorModel, 99);
      expect(src.libdivecomputerVersion, '0.9.0');
      expect(src.lastParsedAt, isNotNull);
    });

    test(
      'is idempotent: same data applied twice yields identical DB state',
      () async {
        // Arrange
        await insertDive(
          'dive-1',
          maxDepth: 20.0,
          notes: 'User notes survive both runs',
          rating: 4,
        );
        await insertComputer('comp-1');
        await insertSource(
          id: 'src-1',
          diveId: 'dive-1',
          computerId: 'comp-1',
          isPrimary: true,
        );
        // Insert initial profiles that will be replaced
        await insertProfile(
          id: 'prof-old-1',
          diveId: 'dive-1',
          computerId: 'comp-1',
          timestamp: 0,
          depth: 0.0,
        );

        final parsed = makeParsedDive(
          maxDepthMeters: 25.0,
          avgDepthMeters: 14.0,
          durationSeconds: 3000,
        );

        // Act: run twice
        await service.applyParsedUpdate(
          diveId: 'dive-1',
          sourceRowId: 'src-1',
          parsed: parsed,
          descriptorVendor: 'Shearwater',
          descriptorProduct: 'Perdix',
          descriptorModel: 42,
          libdivecomputerVersion: '0.8.0',
        );

        // Snapshot after first run
        final diveAfter1 = await getDive('dive-1');
        final srcAfter1 = await getSource('src-1');
        final profilesAfter1 = await (db.select(
          db.diveProfiles,
        )..where((t) => t.diveId.equals('dive-1'))).get();

        // Second run
        await service.applyParsedUpdate(
          diveId: 'dive-1',
          sourceRowId: 'src-1',
          parsed: parsed,
          descriptorVendor: 'Shearwater',
          descriptorProduct: 'Perdix',
          descriptorModel: 42,
          libdivecomputerVersion: '0.8.0',
        );

        // Snapshot after second run
        final diveAfter2 = await getDive('dive-1');
        final srcAfter2 = await getSource('src-1');
        final profilesAfter2 = await (db.select(
          db.diveProfiles,
        )..where((t) => t.diveId.equals('dive-1'))).get();

        // Assert: same number of profiles
        expect(profilesAfter2.length, profilesAfter1.length);

        // Assert: dive fields match
        expect(diveAfter2.maxDepth, diveAfter1.maxDepth);
        expect(diveAfter2.avgDepth, diveAfter1.avgDepth);
        expect(diveAfter2.runtime, diveAfter1.runtime);

        // Assert: source fields match
        expect(srcAfter2.maxDepth, srcAfter1.maxDepth);
        expect(srcAfter2.avgDepth, srcAfter1.avgDepth);
        expect(srcAfter2.duration, srcAfter1.duration);

        // Assert: user fields survive both runs
        expect(diveAfter2.notes, 'User notes survive both runs');
        expect(diveAfter2.rating, 4);
      },
    );

    test('replaces DiveProfiles for the source computerId', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertComputer('comp-2');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      // Pre-existing profiles from comp-1 (should be replaced)
      await insertProfile(
        id: 'prof-old-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        timestamp: 0,
        depth: 0.0,
      );
      await insertProfile(
        id: 'prof-old-2',
        diveId: 'dive-1',
        computerId: 'comp-1',
        timestamp: 60,
        depth: 10.0,
      );

      // Profile from comp-2 (should NOT be touched)
      await insertProfile(
        id: 'prof-other',
        diveId: 'dive-1',
        computerId: 'comp-2',
        timestamp: 0,
        depth: 0.0,
        isPrimary: false,
      );

      // Act
      final parsed = makeParsedDive(
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
          pigeon.ProfileSample(timeSeconds: 30, depthMeters: 5.0),
          pigeon.ProfileSample(timeSeconds: 60, depthMeters: 12.0),
        ],
      );

      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: parsed,
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
        libdivecomputerVersion: null,
      );

      // Assert: 3 new profiles from comp-1, plus 1 untouched from comp-2
      final profiles =
          await (db.select(db.diveProfiles)
                ..where((t) => t.diveId.equals('dive-1'))
                ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
              .get();

      final comp1Profiles = profiles
          .where((p) => p.computerId == 'comp-1')
          .toList();
      final comp2Profiles = profiles
          .where((p) => p.computerId == 'comp-2')
          .toList();

      expect(comp1Profiles.length, 3);
      expect(comp1Profiles[0].depth, 0.0);
      expect(comp1Profiles[1].depth, 5.0);
      expect(comp1Profiles[2].depth, 12.0);

      expect(comp2Profiles.length, 1);
      expect(comp2Profiles[0].id, 'prof-other');
    });

    test('does not overwrite existing rawData with null on re-parse', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');

      final blob = Uint8List.fromList([1, 2, 3, 4, 5]);
      final fp = Uint8List.fromList([0xAB, 0xCD]);

      // Insert source with existing raw data
      final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-1'),
              diveId: const Value('dive-1'),
              computerId: const Value('comp-1'),
              isPrimary: const Value(true),
              sourceFormat: const Value('dive_computer'),
              rawData: Value(blob),
              rawFingerprint: Value(fp),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );

      // Act: re-parse with null rawData/rawFingerprint (the re-parse path)
      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: makeParsedDive(),
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
        libdivecomputerVersion: null,
        rawData: null,
        rawFingerprint: null,
      );

      // Assert: existing blob is preserved
      final src = await getSource('src-1');
      expect(src.rawData, isNotNull);
      expect(src.rawData!, equals(blob));
      expect(src.rawFingerprint, isNotNull);
      expect(src.rawFingerprint!, equals(fp));
    });

    test('getRawDataCounts returns correct counts', () async {
      await insertComputer('comp-1');
      await insertDive('dive-1');
      await insertDive('dive-2');
      await insertDive('dive-3');

      final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
      // Source with rawData
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-1'),
              diveId: const Value('dive-1'),
              computerId: const Value('comp-1'),
              isPrimary: const Value(true),
              rawData: Value(Uint8List.fromList([1, 2, 3])),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );
      // Source without rawData
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-2'),
              diveId: const Value('dive-2'),
              computerId: const Value('comp-1'),
              isPrimary: const Value(true),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );
      // Another source with rawData
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-3'),
              diveId: const Value('dive-3'),
              computerId: const Value('comp-1'),
              isPrimary: const Value(true),
              rawData: Value(Uint8List.fromList([4, 5])),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );

      final counts = await service.getRawDataCounts('comp-1');
      expect(counts.withRawData, 2);
      expect(counts.withoutRawData, 1);
    });

    test('hasRawData returns correct value', () async {
      await insertDive('dive-1');
      await insertDive('dive-2');

      final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-1'),
              diveId: const Value('dive-1'),
              rawData: Value(Uint8List.fromList([1])),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-2'),
              diveId: const Value('dive-2'),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );

      expect(await service.hasRawData('dive-1'), isTrue);
      expect(await service.hasRawData('dive-2'), isFalse);
      expect(await service.hasRawData('dive-nonexistent'), isFalse);
    });

    test('DiveTanks carry-over: overwrites computer fields, preserves user '
        'fields, handles new/removed tanks', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      // Existing tanks: tank 0 and tank 1
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: const Value('tank-0'),
              diveId: const Value('dive-1'),
              volume: const Value(12.0),
              workingPressure: const Value(200.0),
              startPressure: const Value(200.0),
              endPressure: const Value(50.0),
              o2Percent: const Value(32.0),
              hePercent: const Value(0.0),
              tankOrder: const Value(0),
              tankName: const Value('My Primary AL80'),
              presetName: const Value('al80'),
              tankRole: const Value('backGas'),
              tankMaterial: const Value('aluminum'),
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(
            DiveTanksCompanion(
              id: const Value('tank-1'),
              diveId: const Value('dive-1'),
              volume: const Value(7.0),
              startPressure: const Value(200.0),
              endPressure: const Value(150.0),
              o2Percent: const Value(50.0),
              hePercent: const Value(0.0),
              tankOrder: const Value(1),
              tankName: const Value('Deco Stage'),
              presetName: const Value('al40'),
              tankRole: const Value('deco'),
              tankMaterial: const Value('aluminum'),
            ),
          );

      // Act: re-parse with updated tank 0 and a new tank 2 (tank 1 removed)
      final parsed = makeParsedDive(
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: 0,
            volumeLiters: 11.0,
            startPressureBar: 210.0,
            endPressureBar: 40.0,
          ),
          pigeon.TankInfo(
            index: 2,
            gasMixIndex: 1,
            startPressureBar: 200.0,
            endPressureBar: 100.0,
          ),
        ],
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 36.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 100.0, hePercent: 0.0),
        ],
      );

      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: parsed,
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
        libdivecomputerVersion: null,
      );

      // Get all tanks ordered by tankOrder
      final tanks =
          await (db.select(db.diveTanks)
                ..where((t) => t.diveId.equals('dive-1'))
                ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
              .get();

      // Tank 1 was removed by the re-parse, so we should have tanks 0 and 2
      expect(tanks.length, 2);

      // Tank 0: computer fields updated, user fields preserved
      final t0 = tanks.firstWhere((t) => t.tankOrder == 0);
      // Computer-authored fields updated
      expect(t0.volume, 11.0);
      expect(t0.startPressure, 210.0);
      expect(t0.endPressure, 40.0);
      expect(t0.o2Percent, 36.0);
      // User-authored fields preserved
      expect(t0.tankName, 'My Primary AL80');
      expect(t0.presetName, 'al80');
      expect(t0.tankRole, 'backGas');
      expect(t0.tankMaterial, 'aluminum');

      // Tank 2: new tank inserted
      final t2 = tanks.firstWhere((t) => t.tankOrder == 2);
      expect(t2.o2Percent, 100.0);
      expect(t2.startPressure, 200.0);
      expect(t2.endPressure, 100.0);
    });
  });
}
