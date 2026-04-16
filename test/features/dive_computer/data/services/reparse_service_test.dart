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
            const DiveTanksCompanion(
              id: Value('tank-0'),
              diveId: Value('dive-1'),
              volume: Value(12.0),
              workingPressure: Value(200.0),
              startPressure: Value(200.0),
              endPressure: Value(50.0),
              o2Percent: Value(32.0),
              hePercent: Value(0.0),
              tankOrder: Value(0),
              tankName: Value('My Primary AL80'),
              presetName: Value('al80'),
              tankRole: Value('backGas'),
              tankMaterial: Value('aluminum'),
            ),
          );
      await db
          .into(db.diveTanks)
          .insert(
            const DiveTanksCompanion(
              id: Value('tank-1'),
              diveId: Value('dive-1'),
              volume: Value(7.0),
              startPressure: Value(200.0),
              endPressure: Value(150.0),
              o2Percent: Value(50.0),
              hePercent: Value(0.0),
              tankOrder: Value(1),
              tankName: Value('Deco Stage'),
              presetName: Value('al40'),
              tankRole: Value('deco'),
              tankMaterial: Value('aluminum'),
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

    test('multi-source dive skips event/gasSwitch/tankPressure deletion '
        'and tank carry-over', () async {
      // Arrange: dive with two sources
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertComputer('comp-2');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );
      await insertSource(
        id: 'src-2',
        diveId: 'dive-1',
        computerId: 'comp-2',
        isPrimary: false,
      );

      // Pre-existing events, gas switches, tank pressure profiles
      await db
          .into(db.diveProfileEvents)
          .insert(
            DiveProfileEventsCompanion(
              id: const Value('evt-1'),
              diveId: const Value('dive-1'),
              timestamp: const Value(60),
              eventType: const Value('bookmark'),
              createdAt: Value(nowMs),
            ),
          );

      // Pre-existing tank for carry-over check
      await db
          .into(db.diveTanks)
          .insert(
            const DiveTanksCompanion(
              id: Value('tank-0'),
              diveId: Value('dive-1'),
              volume: Value(12.0),
              o2Percent: Value(21.0),
              hePercent: Value(0.0),
              tankOrder: Value(0),
              tankName: Value('User Named Tank'),
            ),
          );

      // Act: re-parse the primary source with events and tanks
      final parsed = makeParsedDive(
        events: [pigeon.DiveEvent(timeSeconds: 120, type: 'bookmark')],
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: 0,
            volumeLiters: 11.0,
            startPressureBar: 200.0,
            endPressureBar: 50.0,
          ),
        ],
        gasMixes: [pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0)],
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

      // Assert: original event preserved (not deleted)
      final events = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.equals('dive-1'))).get();
      expect(events.length, 1);
      expect(events.first.id, 'evt-1');

      // Assert: tank NOT updated by carry-over (volume stays 12.0)
      final tanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('dive-1'))).get();
      expect(tanks.length, 1);
      expect(tanks.first.volume, 12.0);
      expect(tanks.first.tankName, 'User Named Tank');
    });

    test('non-primary source skips tank carry-over', () async {
      // Arrange: two sources, re-parse the non-primary one
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: false,
      );

      // Pre-existing tank
      await db
          .into(db.diveTanks)
          .insert(
            const DiveTanksCompanion(
              id: Value('tank-0'),
              diveId: Value('dive-1'),
              volume: Value(12.0),
              o2Percent: Value(21.0),
              hePercent: Value(0.0),
              tankOrder: Value(0),
              tankName: Value('My AL80'),
            ),
          );

      // Act: re-parse non-primary source with tank data
      final parsed = makeParsedDive(
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: 0,
            volumeLiters: 11.0,
            startPressureBar: 200.0,
            endPressureBar: 50.0,
          ),
        ],
        gasMixes: [pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0)],
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

      // Assert: tank NOT updated (volume stays 12.0, name preserved)
      final tanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('dive-1'))).get();
      expect(tanks.length, 1);
      expect(tanks.first.volume, 12.0);
      expect(tanks.first.tankName, 'My AL80');
    });

    test('events are inserted into DB during single-source re-parse', () async {
      // Arrange: single-source dive
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      // Act: re-parse with various event types
      final parsed = makeParsedDive(
        events: [
          pigeon.DiveEvent(timeSeconds: 60, type: 'bookmark'),
          pigeon.DiveEvent(timeSeconds: 120, type: 'ascent'),
          pigeon.DiveEvent(timeSeconds: 180, type: 'safetystop'),
          pigeon.DiveEvent(timeSeconds: 200, type: 'deco'),
          pigeon.DiveEvent(timeSeconds: 220, type: 'violation'),
          pigeon.DiveEvent(
            timeSeconds: 240,
            type: 'gaschange',
            data: {'value': '32.0'},
          ),
          pigeon.DiveEvent(timeSeconds: 260, type: 'PO2'),
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

      // Assert: all known event types are inserted
      final events =
          await (db.select(db.diveProfileEvents)
                ..where((t) => t.diveId.equals('dive-1'))
                ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
              .get();
      expect(events.length, 7);

      expect(events[0].eventType, 'bookmark');
      expect(events[0].severity, 'info');
      expect(events[1].eventType, 'ascentRateWarning');
      expect(events[1].severity, 'warning');
      expect(events[2].eventType, 'safetyStopStart');
      expect(events[2].severity, 'info');
      expect(events[3].eventType, 'decoStopStart');
      expect(events[3].severity, 'info');
      expect(events[4].eventType, 'decoViolation');
      expect(events[4].severity, 'alert');
      expect(events[5].eventType, 'gasSwitch');
      expect(events[5].severity, 'info');
      expect(events[5].value, 32.0);
      expect(events[6].eventType, 'ppO2High');
      expect(events[6].severity, 'alert');
    });

    test('unknown event types are not inserted', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      final parsed = makeParsedDive(
        events: [
          pigeon.DiveEvent(timeSeconds: 60, type: 'unknown_event'),
          pigeon.DiveEvent(timeSeconds: 120, type: 'bookmark'),
          pigeon.DiveEvent(timeSeconds: 180, type: 'some_random_type'),
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

      // Assert: only known event (bookmark) is inserted
      final events = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.equals('dive-1'))).get();
      expect(events.length, 1);
      expect(events.first.eventType, 'bookmark');
    });

    test('all event type synonyms map correctly', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      // Test all synonym variants
      final parsed = makeParsedDive(
        events: [
          pigeon.DiveEvent(timeSeconds: 10, type: 'safetystop_voluntary'),
          pigeon.DiveEvent(timeSeconds: 20, type: 'safetystop_mandatory'),
          pigeon.DiveEvent(timeSeconds: 30, type: 'deepstop'),
          pigeon.DiveEvent(timeSeconds: 40, type: 'gaschange2'),
          pigeon.DiveEvent(timeSeconds: 50, type: 'ceiling'),
          pigeon.DiveEvent(timeSeconds: 60, type: 'ceiling_safetystop'),
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

      final events =
          await (db.select(db.diveProfileEvents)
                ..where((t) => t.diveId.equals('dive-1'))
                ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
              .get();
      expect(events.length, 6);

      expect(events[0].eventType, 'safetyStopStart');
      expect(events[1].eventType, 'safetyStopStart');
      expect(events[2].eventType, 'decoStopStart');
      expect(events[3].eventType, 'gasSwitch');
      expect(events[4].eventType, 'decoViolation');
      expect(events[5].eventType, 'decoViolation');
    });

    test('unknown diveMode maps to oc', () async {
      await insertDive('dive-1', diveMode: 'oc');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      final parsed = makeParsedDive(diveMode: 'gauge');

      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: parsed,
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
        libdivecomputerVersion: null,
      );

      final dive = await getDive('dive-1');
      expect(dive.diveMode, 'oc');
    });

    test('null diveMode maps to oc', () async {
      await insertDive('dive-1', diveMode: 'ccr');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      final parsed = makeParsedDive(diveMode: null);

      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: parsed,
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
        libdivecomputerVersion: null,
      );

      final dive = await getDive('dive-1');
      expect(dive.diveMode, 'oc');
    });

    test('bottomTime falls back to durationSeconds when < 3 samples', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      // Only 2 samples -- _calculateBottomTimeFromSamples returns null
      final parsed = makeParsedDive(
        durationSeconds: 1800,
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
          pigeon.ProfileSample(timeSeconds: 60, depthMeters: 10.0),
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

      final dive = await getDive('dive-1');
      expect(dive.bottomTime, 1800);
    });

    test(
      'bottomTime falls back to durationSeconds when maxDepth is 0',
      () async {
        await insertDive('dive-1');
        await insertComputer('comp-1');
        await insertSource(
          id: 'src-1',
          diveId: 'dive-1',
          computerId: 'comp-1',
          isPrimary: true,
        );

        // All samples at depth 0 -- maxDepth <= 0 returns null
        final parsed = makeParsedDive(
          maxDepthMeters: 0.0,
          durationSeconds: 600,
          samples: [
            pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
            pigeon.ProfileSample(timeSeconds: 60, depthMeters: 0.0),
            pigeon.ProfileSample(timeSeconds: 120, depthMeters: 0.0),
            pigeon.ProfileSample(timeSeconds: 180, depthMeters: 0.0),
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

        final dive = await getDive('dive-1');
        expect(dive.bottomTime, 600);
      },
    );

    test('bottomTime falls back to durationSeconds when ascentStart <= '
        'descentEnd', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      // Single deep sample at one timestamp -- descent end == ascent start
      final parsed = makeParsedDive(
        maxDepthMeters: 30.0,
        durationSeconds: 1200,
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
          pigeon.ProfileSample(timeSeconds: 60, depthMeters: 30.0),
          pigeon.ProfileSample(timeSeconds: 120, depthMeters: 0.0),
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

      final dive = await getDive('dive-1');
      // The only sample at >= 85% of 30m (25.5m) is the single 30m sample
      // at t=60. descentEnd = ascentStart = 60, so bottom time returns null
      // and falls back to durationSeconds.
      expect(dive.bottomTime, 1200);
    });
  });

  // ---------------------------------------------------------------------------
  // getSourcesForDiveReparse
  // ---------------------------------------------------------------------------

  group('ReparseService.getSourcesForDiveReparse', () {
    test('returns only sources with raw data for the given dive', () async {
      await insertDive('dive-1');
      await insertDive('dive-2');
      await insertComputer('comp-1');

      final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
      // Source with rawData for dive-1
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
      // Source without rawData for dive-1
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-2'),
              diveId: const Value('dive-1'),
              computerId: const Value('comp-1'),
              isPrimary: const Value(false),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );
      // Source with rawData for dive-2 (different dive)
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-3'),
              diveId: const Value('dive-2'),
              computerId: const Value('comp-1'),
              isPrimary: const Value(true),
              rawData: Value(Uint8List.fromList([4, 5])),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );

      final sources = await service.getSourcesForDiveReparse('dive-1');
      expect(sources.length, 1);
      expect(sources.first.id, 'src-1');
    });

    test('returns empty list when no sources have raw data', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');

      final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-1'),
              diveId: const Value('dive-1'),
              computerId: const Value('comp-1'),
              isPrimary: const Value(true),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );

      final sources = await service.getSourcesForDiveReparse('dive-1');
      expect(sources, isEmpty);
    });

    test('returns empty list for nonexistent dive', () async {
      final sources = await service.getSourcesForDiveReparse(
        'nonexistent-dive',
      );
      expect(sources, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // getSourcesForComputerReparse
  // ---------------------------------------------------------------------------

  group('ReparseService.getSourcesForComputerReparse', () {
    test('returns only sources with raw data for the given computer', () async {
      await insertDive('dive-1');
      await insertDive('dive-2');
      await insertDive('dive-3');
      await insertComputer('comp-1');
      await insertComputer('comp-2');

      final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
      // Source with rawData for comp-1
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-1'),
              diveId: const Value('dive-1'),
              computerId: const Value('comp-1'),
              isPrimary: const Value(true),
              rawData: Value(Uint8List.fromList([1, 2])),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );
      // Source without rawData for comp-1
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
      // Source with rawData for comp-2 (different computer)
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-3'),
              diveId: const Value('dive-3'),
              computerId: const Value('comp-2'),
              isPrimary: const Value(true),
              rawData: Value(Uint8List.fromList([3, 4])),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );

      final sources = await service.getSourcesForComputerReparse('comp-1');
      expect(sources.length, 1);
      expect(sources.first.id, 'src-1');
    });

    test('returns empty list when no sources have raw data', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');

      final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-1'),
              diveId: const Value('dive-1'),
              computerId: const Value('comp-1'),
              isPrimary: const Value(true),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );

      final sources = await service.getSourcesForComputerReparse('comp-1');
      expect(sources, isEmpty);
    });

    test('returns empty list for nonexistent computer', () async {
      final sources = await service.getSourcesForComputerReparse(
        'nonexistent-comp',
      );
      expect(sources, isEmpty);
    });

    test(
      'returns multiple sources when computer has many dives with raw data',
      () async {
        await insertDive('dive-1');
        await insertDive('dive-2');
        await insertComputer('comp-1');

        final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
        await db
            .into(db.diveDataSources)
            .insert(
              DiveDataSourcesCompanion(
                id: const Value('src-1'),
                diveId: const Value('dive-1'),
                computerId: const Value('comp-1'),
                isPrimary: const Value(true),
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
                computerId: const Value('comp-1'),
                isPrimary: const Value(true),
                rawData: Value(Uint8List.fromList([2])),
                importedAt: Value(now),
                createdAt: Value(now),
              ),
            );

        final sources = await service.getSourcesForComputerReparse('comp-1');
        expect(sources.length, 2);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // reparseAllForComputer
  // ---------------------------------------------------------------------------

  group('ReparseService.reparseAllForComputer', () {
    Future<pigeon.ParsedDive> fakeParseFn(
      String vendor,
      String product,
      int model,
      Uint8List rawData,
    ) async {
      return makeParsedDive();
    }

    Future<void> insertSourceWithRawData({
      required String id,
      required String diveId,
      required String computerId,
      bool isPrimary = true,
      String? descriptorVendor = 'Shearwater',
      String? descriptorProduct = 'Perdix',
      int? descriptorModel = 42,
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
              rawData: Value(Uint8List.fromList([1, 2, 3])),
              descriptorVendor: Value(descriptorVendor),
              descriptorProduct: Value(descriptorProduct),
              descriptorModel: Value(descriptorModel),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );
    }

    test(
      'successfully re-parses all sources with raw data for a computer',
      () async {
        await insertComputer('comp-1');
        await insertDive('dive-1');
        await insertDive('dive-2');
        await insertSourceWithRawData(
          id: 'src-1',
          diveId: 'dive-1',
          computerId: 'comp-1',
        );
        await insertSourceWithRawData(
          id: 'src-2',
          diveId: 'dive-2',
          computerId: 'comp-1',
        );

        final result = await service.reparseAllForComputer(
          'comp-1',
          parseFn: fakeParseFn,
        );

        expect(result.succeeded, 2);
        expect(result.failed, 0);
      },
    );

    test('sources without descriptor fields are counted as failed', () async {
      await insertComputer('comp-1');
      await insertDive('dive-1');
      await insertSourceWithRawData(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
      );

      final result = await service.reparseAllForComputer(
        'comp-1',
        parseFn: fakeParseFn,
      );

      expect(result.succeeded, 0);
      expect(result.failed, 1);
    });

    test('parseFn throwing an exception counts as failed', () async {
      await insertComputer('comp-1');
      await insertDive('dive-1');
      await insertSourceWithRawData(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
      );

      final result = await service.reparseAllForComputer(
        'comp-1',
        parseFn: (vendor, product, model, rawData) async {
          throw Exception('native bridge error');
        },
      );

      expect(result.succeeded, 0);
      expect(result.failed, 1);
    });

    test('mixed results: some succeed, some fail', () async {
      await insertComputer('comp-1');
      await insertDive('dive-1');
      await insertDive('dive-2');
      await insertDive('dive-3');

      // Source with valid descriptors -- will succeed
      await insertSourceWithRawData(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
      );
      // Source missing descriptors -- will fail
      await insertSourceWithRawData(
        id: 'src-2',
        diveId: 'dive-2',
        computerId: 'comp-1',
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
      );
      // Source with valid descriptors but parseFn will throw
      await insertSourceWithRawData(
        id: 'src-3',
        diveId: 'dive-3',
        computerId: 'comp-1',
        descriptorVendor: 'Suunto',
        descriptorProduct: 'EON Core',
        descriptorModel: 99,
      );

      final result = await service.reparseAllForComputer(
        'comp-1',
        parseFn: (vendor, product, model, rawData) async {
          if (vendor == 'Suunto') {
            throw Exception('parse failure');
          }
          return makeParsedDive();
        },
      );

      expect(result.succeeded, 1);
      expect(result.failed, 2);
    });

    test(
      'returns (succeeded: 0, failed: 0) when no sources have raw data',
      () async {
        await insertComputer('comp-1');
        await insertDive('dive-1');

        // Source without rawData
        final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
        await db
            .into(db.diveDataSources)
            .insert(
              DiveDataSourcesCompanion(
                id: const Value('src-1'),
                diveId: const Value('dive-1'),
                computerId: const Value('comp-1'),
                isPrimary: const Value(true),
                importedAt: Value(now),
                createdAt: Value(now),
              ),
            );

        final result = await service.reparseAllForComputer(
          'comp-1',
          parseFn: fakeParseFn,
        );

        expect(result.succeeded, 0);
        expect(result.failed, 0);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // reparseDive
  // ---------------------------------------------------------------------------

  group('ReparseService.reparseDive', () {
    Future<pigeon.ParsedDive> fakeParseFn(
      String vendor,
      String product,
      int model,
      Uint8List rawData,
    ) async {
      return makeParsedDive();
    }

    Future<void> insertSourceWithRawData({
      required String id,
      required String diveId,
      String? computerId,
      bool isPrimary = true,
      String? descriptorVendor = 'Shearwater',
      String? descriptorProduct = 'Perdix',
      int? descriptorModel = 42,
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
              rawData: Value(Uint8List.fromList([1, 2, 3])),
              descriptorVendor: Value(descriptorVendor),
              descriptorProduct: Value(descriptorProduct),
              descriptorModel: Value(descriptorModel),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );
    }

    test('successfully re-parses all sources for a dive', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSourceWithRawData(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
      );

      final errors = await service.reparseDive('dive-1', parseFn: fakeParseFn);

      expect(errors, isEmpty);
    });

    test('sources without descriptor fields are silently skipped', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSourceWithRawData(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
      );

      final errors = await service.reparseDive('dive-1', parseFn: fakeParseFn);

      expect(errors, isEmpty);
    });

    test('parseFn throwing adds error message to returned list', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSourceWithRawData(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
      );

      final errors = await service.reparseDive(
        'dive-1',
        parseFn: (vendor, product, model, rawData) async {
          throw Exception('native bridge error');
        },
      );

      expect(errors.length, 1);
      expect(errors.first, contains('native bridge error'));
    });

    test('returns empty list when no sources have raw data', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');

      // Source without rawData
      final now = DateTime.fromMillisecondsSinceEpoch(nowMs);
      await db
          .into(db.diveDataSources)
          .insert(
            DiveDataSourcesCompanion(
              id: const Value('src-1'),
              diveId: const Value('dive-1'),
              computerId: const Value('comp-1'),
              isPrimary: const Value(true),
              importedAt: Value(now),
              createdAt: Value(now),
            ),
          );

      final errors = await service.reparseDive('dive-1', parseFn: fakeParseFn);

      expect(errors, isEmpty);
    });

    test(
      'multiple sources: one succeeds, one throws -- returns one error',
      () async {
        await insertDive('dive-1');
        await insertComputer('comp-1');
        await insertComputer('comp-2');

        await insertSourceWithRawData(
          id: 'src-1',
          diveId: 'dive-1',
          computerId: 'comp-1',
          descriptorVendor: 'Shearwater',
          descriptorProduct: 'Perdix',
          descriptorModel: 42,
        );
        await insertSourceWithRawData(
          id: 'src-2',
          diveId: 'dive-1',
          computerId: 'comp-2',
          isPrimary: false,
          descriptorVendor: 'Suunto',
          descriptorProduct: 'EON Core',
          descriptorModel: 99,
        );

        final errors = await service.reparseDive(
          'dive-1',
          parseFn: (vendor, product, model, rawData) async {
            if (vendor == 'Suunto') {
              throw Exception('Suunto parse failure');
            }
            return makeParsedDive();
          },
        );

        expect(errors.length, 1);
        expect(errors.first, contains('Suunto parse failure'));
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Coverage gap tests
  // ---------------------------------------------------------------------------

  group('Coverage: _updateSourceRow rawData/rawFingerprint branches', () {
    test('rawData and rawFingerprint are stored when provided', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      final blob = Uint8List.fromList([10, 20, 30]);
      final fp = Uint8List.fromList([0xAA, 0xBB]);

      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: makeParsedDive(),
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
        libdivecomputerVersion: null,
        rawData: blob,
        rawFingerprint: fp,
      );

      final src = await getSource('src-1');
      expect(src.rawData, isNotNull);
      expect(src.rawData!, equals(blob));
      expect(src.rawFingerprint, isNotNull);
      expect(src.rawFingerprint!, equals(fp));
    });
  });

  group('Coverage: _replaceDiveProfiles with null computerId', () {
    test('deletes and replaces profiles where computerId is null', () async {
      await insertDive('dive-1');
      // Source without a computerId (manual import, etc.)
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: null,
        isPrimary: true,
      );

      // Pre-existing profile with null computerId
      await insertProfile(
        id: 'prof-old-1',
        diveId: 'dive-1',
        computerId: null,
        timestamp: 0,
        depth: 0.0,
      );
      await insertProfile(
        id: 'prof-old-2',
        diveId: 'dive-1',
        computerId: null,
        timestamp: 60,
        depth: 15.0,
      );

      final parsed = makeParsedDive(
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
          pigeon.ProfileSample(timeSeconds: 30, depthMeters: 8.0),
          pigeon.ProfileSample(timeSeconds: 60, depthMeters: 20.0),
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

      // Old profiles should be replaced by the 3 new samples
      final profiles =
          await (db.select(db.diveProfiles)
                ..where((t) => t.diveId.equals('dive-1'))
                ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
              .get();

      expect(profiles.length, 3);
      expect(profiles[0].depth, 0.0);
      expect(profiles[1].depth, 8.0);
      expect(profiles[2].depth, 20.0);
      // All should have null computerId
      for (final p in profiles) {
        expect(p.computerId, isNull);
      }
    });
  });

  group('Coverage: _insertEvents with data map', () {
    test(
      'event with data map containing value populates value column',
      () async {
        await insertDive('dive-1');
        await insertComputer('comp-1');
        await insertSource(
          id: 'src-1',
          diveId: 'dive-1',
          computerId: 'comp-1',
          isPrimary: true,
        );

        final parsed = makeParsedDive(
          events: [
            pigeon.DiveEvent(
              timeSeconds: 60,
              type: 'gaschange',
              data: {'value': '42.5'},
            ),
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

        final events = await (db.select(
          db.diveProfileEvents,
        )..where((t) => t.diveId.equals('dive-1'))).get();
        expect(events.length, 1);
        expect(events.first.value, 42.5);
      },
    );

    test('event with null data has null value column', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      final parsed = makeParsedDive(
        events: [
          pigeon.DiveEvent(timeSeconds: 60, type: 'bookmark', data: null),
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

      final events = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.equals('dive-1'))).get();
      expect(events.length, 1);
      expect(events.first.value, isNull);
    });
  });

  group('Coverage: _carryOverTanks gas mix fallback', () {
    test('unmatched gasMixIndex falls back to 21% O2 and 0% He', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      // Tank with gasMixIndex 99, which does not match any gas mix
      final parsed = makeParsedDive(
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: 99,
            volumeLiters: 12.0,
            startPressureBar: 200.0,
            endPressureBar: 50.0,
          ),
        ],
        gasMixes: [
          // Only gas mix at index 0 -- tank references index 99
          pigeon.GasMix(index: 0, o2Percent: 36.0, hePercent: 10.0),
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

      final tanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('dive-1'))).get();
      expect(tanks.length, 1);
      // Fallback: 21% O2, 0% He
      expect(tanks.first.o2Percent, 21.0);
      expect(tanks.first.hePercent, 0.0);
    });
  });

  group('Coverage: _calculateBottomTimeFromSamples successful computation', () {
    test('returns positive bottom time for a normal dive profile', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      // Profile with a clear bottom phase: descent to 30m, plateau, ascent.
      // 85% of 30m = 25.5m. Samples at/above 25.5m: t=120 (26m), t=180 (30m),
      // t=240 (28m). descentEnd=120, ascentStart=240, bottom time = 120s.
      final parsed = makeParsedDive(
        maxDepthMeters: 30.0,
        durationSeconds: 360,
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
          pigeon.ProfileSample(timeSeconds: 60, depthMeters: 15.0),
          pigeon.ProfileSample(timeSeconds: 120, depthMeters: 26.0),
          pigeon.ProfileSample(timeSeconds: 180, depthMeters: 30.0),
          pigeon.ProfileSample(timeSeconds: 240, depthMeters: 28.0),
          pigeon.ProfileSample(timeSeconds: 300, depthMeters: 10.0),
          pigeon.ProfileSample(timeSeconds: 360, depthMeters: 0.0),
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

      final dive = await getDive('dive-1');
      // Bottom time should be 240 - 120 = 120 seconds
      expect(dive.bottomTime, 120);
    });
  });

  group('Coverage: _extractMaxCns', () {
    test('cnsEnd reflects maximum CNS from samples', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      final parsed = makeParsedDive(
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0, cns: 10.0),
          pigeon.ProfileSample(timeSeconds: 60, depthMeters: 20.0, cns: 25.0),
          pigeon.ProfileSample(timeSeconds: 120, depthMeters: 30.0, cns: 45.0),
          pigeon.ProfileSample(timeSeconds: 180, depthMeters: 10.0, cns: 30.0),
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

      final dive = await getDive('dive-1');
      // Maximum CNS across all samples is 45.0
      expect(dive.cnsEnd, 45.0);
    });
  });
}
