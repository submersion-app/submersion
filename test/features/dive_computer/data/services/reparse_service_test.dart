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
    double? cns,
    int? timeOffsetSeconds,
    DateTime? entryTime,
    DateTime? exitTime,
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
            cns: Value(cns),
            timeOffsetSeconds: Value(timeOffsetSeconds),
            entryTime: Value(entryTime),
            exitTime: Value(exitTime),
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

  pigeon.ParsedDive makeParsedDiveWithGps({
    double? entryLatitude,
    double? entryLongitude,
    double? exitLatitude,
    double? exitLongitude,
  }) {
    final base = makeParsedDive();
    return pigeon.ParsedDive(
      fingerprint: base.fingerprint,
      dateTimeYear: base.dateTimeYear,
      dateTimeMonth: base.dateTimeMonth,
      dateTimeDay: base.dateTimeDay,
      dateTimeHour: base.dateTimeHour,
      dateTimeMinute: base.dateTimeMinute,
      dateTimeSecond: base.dateTimeSecond,
      maxDepthMeters: base.maxDepthMeters,
      avgDepthMeters: base.avgDepthMeters,
      durationSeconds: base.durationSeconds,
      minTemperatureCelsius: base.minTemperatureCelsius,
      samples: base.samples,
      tanks: base.tanks,
      gasMixes: base.gasMixes,
      events: base.events,
      diveMode: base.diveMode,
      decoAlgorithm: base.decoAlgorithm,
      gfLow: base.gfLow,
      gfHigh: base.gfHigh,
      decoConservatism: base.decoConservatism,
      entryLatitude: entryLatitude,
      entryLongitude: entryLongitude,
      exitLatitude: exitLatitude,
      exitLongitude: exitLongitude,
    );
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

    test(
      'writes new entry/exit GPS to dives + source when source is primary',
      () async {
        // Reproduces the user-reported scenario: a dive previously downloaded
        // with the pre-patch libdivecomputer had exit GPS == entry GPS. After
        // updating to the patched libdivecomputer, re-parsing should write the
        // new (correct) exit GPS to both dives and dive_data_sources.
        await insertDive('dive-1');
        await insertComputer('comp-1');
        await insertSource(
          id: 'src-1',
          diveId: 'dive-1',
          computerId: 'comp-1',
          isPrimary: true,
        );

        // Seed both tables with the "wrong" pre-patch values: entry == exit.
        await (db.update(db.dives)..where((t) => t.id.equals('dive-1'))).write(
          const DivesCompanion(
            entryLatitude: Value(21.0),
            entryLongitude: Value(-157.0),
            exitLatitude: Value(21.0),
            exitLongitude: Value(-157.0),
          ),
        );
        await (db.update(
          db.diveDataSources,
        )..where((t) => t.id.equals('src-1'))).write(
          const DiveDataSourcesCompanion(
            entryLatitude: Value(21.0),
            entryLongitude: Value(-157.0),
            exitLatitude: Value(21.0),
            exitLongitude: Value(-157.0),
          ),
        );

        // Re-parse returns a fresh ParsedDive where exit GPS now differs.
        final parsed = makeParsedDiveWithGps(
          entryLatitude: 21.0,
          entryLongitude: -157.0,
          exitLatitude: 21.0015,
          exitLongitude: -157.0021,
        );

        await service.applyParsedUpdate(
          diveId: 'dive-1',
          sourceRowId: 'src-1',
          parsed: parsed,
          descriptorVendor: 'Shearwater',
          descriptorProduct: 'Perdix',
          descriptorModel: 5,
          libdivecomputerVersion: '0.9.0',
        );

        final dive = await getDive('dive-1');
        expect(dive.entryLatitude, 21.0);
        expect(dive.entryLongitude, -157.0);
        expect(dive.exitLatitude, 21.0015);
        expect(dive.exitLongitude, -157.0021);

        final src = await getSource('src-1');
        expect(src.entryLatitude, 21.0);
        expect(src.entryLongitude, -157.0);
        expect(src.exitLatitude, 21.0015);
        expect(src.exitLongitude, -157.0021);
      },
    );

    test(
      'reparseDive end-to-end: parses raw and writes new GPS to dives',
      () async {
        // Mirrors the user-facing "Re-parse raw data" path: a real source row
        // with rawData + descriptor info, then reparseDive(parseFn) → DB write.
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
                sourceFormat: const Value('dive_computer'),
                rawData: Value(Uint8List.fromList(List.filled(64, 0xAB))),
                descriptorVendor: const Value('Shearwater'),
                descriptorProduct: const Value('Perdix'),
                descriptorModel: const Value(5),
                libdivecomputerVersion: const Value('0.9.0'),
                entryLatitude: const Value(21.0),
                entryLongitude: const Value(-157.0),
                exitLatitude: const Value(21.0),
                exitLongitude: const Value(-157.0),
                importedAt: Value(now),
                createdAt: Value(now),
              ),
            );
        await (db.update(db.dives)..where((t) => t.id.equals('dive-1'))).write(
          const DivesCompanion(
            entryLatitude: Value(21.0),
            entryLongitude: Value(-157.0),
            exitLatitude: Value(21.0),
            exitLongitude: Value(-157.0),
          ),
        );

        // Fake parser: returns a ParsedDive with NEW exit GPS — the value the
        // patched libdivecomputer would produce.
        Future<pigeon.ParsedDive> fakeParse(
          String vendor,
          String product,
          int model,
          Uint8List raw,
        ) async {
          return makeParsedDiveWithGps(
            entryLatitude: 21.0,
            entryLongitude: -157.0,
            exitLatitude: 21.0015,
            exitLongitude: -157.0021,
          );
        }

        final errors = (await service.reparseDive(
          'dive-1',
          parseFn: fakeParse,
        )).errors;

        expect(errors, isEmpty);
        final dive = await getDive('dive-1');
        expect(dive.exitLatitude, 21.0015);
        expect(dive.exitLongitude, -157.0021);
      },
    );

    test(
      'reparseDive silently skips sources missing descriptor info',
      () async {
        // A source row with rawData but no descriptor vendor/product/model
        // (e.g. older import). reparseDive returns no errors, but no actual
        // re-parse happens. This is the silent-skip trap.
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
                sourceFormat: const Value('dive_computer'),
                rawData: Value(Uint8List.fromList(List.filled(64, 0xAB))),
                // descriptor* deliberately left absent
                entryLatitude: const Value(21.0),
                entryLongitude: const Value(-157.0),
                exitLatitude: const Value(21.0),
                exitLongitude: const Value(-157.0),
                importedAt: Value(now),
                createdAt: Value(now),
              ),
            );

        var parserCalls = 0;
        Future<pigeon.ParsedDive> fakeParse(
          String vendor,
          String product,
          int model,
          Uint8List raw,
        ) async {
          parserCalls++;
          return makeParsedDive();
        }

        final errors = (await service.reparseDive(
          'dive-1',
          parseFn: fakeParse,
        )).errors;

        // Documents current behavior: no errors reported, parser not invoked.
        expect(errors, isEmpty);
        expect(parserCalls, 0);
      },
    );

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

    test('refreshes DiveDataSources.cns from the re-parsed samples', () async {
      // Arrange: the source row carries the CNS the original download derived.
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
        cns: 12.0,
      );

      // Act: re-parse produces a higher CNS, as a libdivecomputer fix might.
      final parsed = makeParsedDive(
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0, cns: 5.0),
          pigeon.ProfileSample(timeSeconds: 60, depthMeters: 20.0, cns: 41.0),
          pigeon.ProfileSample(timeSeconds: 120, depthMeters: 25.0, cns: 55.0),
          pigeon.ProfileSample(timeSeconds: 180, depthMeters: 5.0, cns: 55.0),
        ],
      );

      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: parsed,
        descriptorVendor: 'Shearwater',
        descriptorProduct: 'Perdix',
        descriptorModel: 42,
        libdivecomputerVersion: '0.9.0',
      );

      // Assert: the source row and the dive row agree, both on the new value.
      final src = await getSource('src-1');
      final dive = await getDive('dive-1');
      expect(src.cns, 55.0);
      expect(dive.cnsEnd, 55.0);
    });

    test(
      'clears DiveDataSources.cns when the re-parse reports no CNS',
      () async {
        // Arrange
        await insertDive('dive-1', cnsEnd: 12.0);
        await insertComputer('comp-1');
        await insertSource(
          id: 'src-1',
          diveId: 'dive-1',
          computerId: 'comp-1',
          isPrimary: true,
          cns: 12.0,
        );

        // Act: the default samples carry no CNS at all.
        await service.applyParsedUpdate(
          diveId: 'dive-1',
          sourceRowId: 'src-1',
          parsed: makeParsedDive(),
          descriptorVendor: 'Shearwater',
          descriptorProduct: 'Perdix',
          descriptorModel: 42,
          libdivecomputerVersion: '0.9.0',
        );

        // Assert: a stale value is not left behind on either row.
        final src = await getSource('src-1');
        final dive = await getDive('dive-1');
        expect(src.cns, isNull);
        expect(dive.cnsEnd, isNull);
      },
    );

    test('derives water temp from profile samples when the computer reports no '
        'top-level minimum', () async {
      // Shearwater and friends leave ParsedDive.minTemperatureCelsius null
      // and carry temperature only in the per-sample stream. The download
      // path derives the minimum from those samples; re-parse must too, or
      // re-parsing an already-downloaded dive blanks its water temp and the
      // Data Sources row renders "-".
      await insertDive('dive-1', waterTemp: 18.0);
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
        waterTemp: 18.0,
      );

      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: makeParsedDive(
          minTemperatureCelsius: null,
          samples: [
            pigeon.ProfileSample(
              timeSeconds: 0,
              depthMeters: 0.0,
              temperatureCelsius: 21.0,
            ),
            pigeon.ProfileSample(
              timeSeconds: 60,
              depthMeters: 20.0,
              temperatureCelsius: 14.5,
            ),
            pigeon.ProfileSample(
              timeSeconds: 120,
              depthMeters: 10.0,
              temperatureCelsius: 16.0,
            ),
          ],
        ),
        descriptorVendor: 'Shearwater',
        descriptorProduct: 'Perdix',
        descriptorModel: 42,
        libdivecomputerVersion: '0.9.0',
      );

      final src = await getSource('src-1');
      expect(src.waterTemp, 14.5);
      final dive = await getDive('dive-1');
      expect(dive.waterTemp, 14.5);
    });

    test('a top-level minimum still wins over the sample stream', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: makeParsedDive(
          minTemperatureCelsius: 12.0,
          samples: [
            pigeon.ProfileSample(
              timeSeconds: 0,
              depthMeters: 0.0,
              temperatureCelsius: 21.0,
            ),
          ],
        ),
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
        libdivecomputerVersion: null,
      );

      final src = await getSource('src-1');
      expect(src.waterTemp, 12.0);
      final dive = await getDive('dive-1');
      expect(dive.waterTemp, 12.0);
    });

    test(
      'a re-parse with no temperature anywhere preserves the dive water temp '
      'a diver entered by hand',
      () async {
        // Mirrors the entry/exit GPS treatment on the Dives row: the source
        // row records exactly what the computer provided (null), but the dive
        // keeps the value stamped from another source.
        await insertDive('dive-1', waterTemp: 24.0);
        await insertComputer('comp-1');
        await insertSource(
          id: 'src-1',
          diveId: 'dive-1',
          computerId: 'comp-1',
          isPrimary: true,
        );

        await service.applyParsedUpdate(
          diveId: 'dive-1',
          sourceRowId: 'src-1',
          parsed: makeParsedDive(
            minTemperatureCelsius: null,
            samples: [
              pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
              pigeon.ProfileSample(timeSeconds: 60, depthMeters: 20.0),
            ],
          ),
          descriptorVendor: null,
          descriptorProduct: null,
          descriptorModel: null,
          libdivecomputerVersion: null,
        );

        final dive = await getDive('dive-1');
        expect(dive.waterTemp, 24.0);
        final src = await getSource('src-1');
        expect(src.waterTemp, isNull);
      },
    );

    test('refreshes the source row entry/exit window from the re-parsed '
        'clock (#1207)', () async {
      // Arrange: a source row stamped with the original download's window.
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
        duration: 2400,
        entryTime: DateTime.utc(2026, 1, 15, 10, 0),
        exitTime: DateTime.utc(2026, 1, 15, 10, 40),
      );

      // Act: re-parse moves the start by an hour and lengthens the dive.
      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: makeParsedDive(hour: 11, durationSeconds: 3000),
        descriptorVendor: 'Suunto',
        descriptorProduct: 'EON Core',
        descriptorModel: 99,
        libdivecomputerVersion: '0.9.0',
      );

      // Assert: the source row's window tracks the dive's own clock.
      final src = await getSource('src-1');
      final dive = await getDive('dive-1');
      expect(
        src.entryTime!.millisecondsSinceEpoch,
        DateTime.utc(2026, 1, 15, 11, 0).millisecondsSinceEpoch,
      );
      expect(
        src.exitTime!.millisecondsSinceEpoch,
        DateTime.utc(2026, 1, 15, 11, 50).millisecondsSinceEpoch,
      );
      expect(src.entryTime!.millisecondsSinceEpoch, dive.entryTime);
      expect(src.exitTime!.millisecondsSinceEpoch, dive.exitTime);
    });

    test('records the raw parsed window on an offset-bearing source, not the '
        're-based one (#1207)', () async {
      // Arrange: a consolidated secondary whose profile is re-based by 10
      // minutes. entry_time/exit_time stay in the source's own parse frame --
      // the download path stamps them unshifted and consolidation copies them
      // across untouched, recording the shift in timeOffsetSeconds instead.
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(id: 'src-primary', diveId: 'dive-1', isPrimary: true);
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: false,
        timeOffsetSeconds: 600,
        entryTime: DateTime.utc(2026, 1, 15, 10, 0),
        exitTime: DateTime.utc(2026, 1, 15, 10, 40),
      );

      // Act
      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-1',
        parsed: makeParsedDive(hour: 11, durationSeconds: 3000),
        descriptorVendor: 'Suunto',
        descriptorProduct: 'EON Core',
        descriptorModel: 99,
        libdivecomputerVersion: '0.9.0',
      );

      // Assert: no offset folded into the recorded window.
      final src = await getSource('src-1');
      expect(
        src.entryTime!.millisecondsSinceEpoch,
        DateTime.utc(2026, 1, 15, 11, 0).millisecondsSinceEpoch,
      );
      expect(
        src.exitTime!.millisecondsSinceEpoch,
        DateTime.utc(2026, 1, 15, 11, 50).millisecondsSinceEpoch,
      );
      expect(src.timeOffsetSeconds, 600);
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

    test('re-parsing a consolidated source re-bases its profile onto the '
        "dive's time base, not the raw download's (#1177)", () async {
      await insertDive('dive-1');
      await insertComputer('comp-primary');
      await insertComputer('comp-secondary');
      await insertSource(
        id: 'src-primary',
        diveId: 'dive-1',
        computerId: 'comp-primary',
        isPrimary: true,
      );
      // Consolidation folded this computer in and shifted its samples 60s
      // forward to line them up with the primary's clock.
      await insertSource(
        id: 'src-secondary',
        diveId: 'dive-1',
        computerId: 'comp-secondary',
        isPrimary: false,
        timeOffsetSeconds: 60,
      );
      await insertProfile(
        id: 'prof-secondary',
        diveId: 'dive-1',
        computerId: 'comp-secondary',
        timestamp: 60,
        depth: 0.0,
        isPrimary: false,
      );

      final parsed = makeParsedDive(
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
          pigeon.ProfileSample(timeSeconds: 30, depthMeters: 5.0),
          pigeon.ProfileSample(timeSeconds: 60, depthMeters: 12.0),
        ],
      );

      await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-secondary',
        parsed: parsed,
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
        libdivecomputerVersion: null,
      );

      final profiles =
          await (db.select(db.diveProfiles)
                ..where((t) => t.computerId.equals('comp-secondary'))
                ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
              .get();

      // Without the offset these land at 0/30/60 and the secondary strand
      // sits a minute to the left of the primary's on every comparison view.
      expect(profiles.map((p) => p.timestamp), [60, 90, 120]);
      expect(profiles.map((p) => p.depth), [0.0, 5.0, 12.0]);
    });

    test('re-parsing leaves the recorded offset intact, so a second '
        're-parse lands on the same time base (#1177)', () async {
      await insertDive('dive-1');
      await insertComputer('comp-primary');
      await insertComputer('comp-secondary');
      await insertSource(
        id: 'src-primary',
        diveId: 'dive-1',
        computerId: 'comp-primary',
        isPrimary: true,
      );
      await insertSource(
        id: 'src-secondary',
        diveId: 'dive-1',
        computerId: 'comp-secondary',
        isPrimary: false,
        timeOffsetSeconds: 60,
      );

      final parsed = makeParsedDive(
        samples: [pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0)],
      );

      // reparseAllForComputer walks every dive for a computer after a
      // libdivecomputer upgrade, so the same row is re-parsed repeatedly over
      // the app's life. Each pass must find the offset still there.
      for (var i = 0; i < 2; i++) {
        await service.applyParsedUpdate(
          diveId: 'dive-1',
          sourceRowId: 'src-secondary',
          parsed: parsed,
          descriptorVendor: null,
          descriptorProduct: null,
          descriptorModel: null,
          libdivecomputerVersion: null,
        );
      }

      expect((await getSource('src-secondary')).timeOffsetSeconds, 60);
      final profiles = await (db.select(
        db.diveProfiles,
      )..where((t) => t.computerId.equals('comp-secondary'))).get();
      expect(profiles.map((p) => p.timestamp), [60]);
    });

    test('a source with no recorded offset re-parses on the raw time base '
        '(#1177)', () async {
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
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
          pigeon.ProfileSample(timeSeconds: 30, depthMeters: 5.0),
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

      final profiles =
          await (db.select(db.diveProfiles)
                ..where((t) => t.diveId.equals('dive-1'))
                ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
              .get();
      expect(profiles.map((p) => p.timestamp), [0, 30]);
    });

    test('an offset-bearing source that is a dive\'s only row is refused '
        'outright, so events never need re-basing (#1177 x #1164)', () async {
      // The only shape in which the event/gas-switch/tank-pressure re-inserts
      // could ever see a non-zero offset is a consolidated dive that ended up
      // single-source. DiveConsolidationService.apply backfills a primary
      // source row on the target before folding anything in, so that shape
      // does not arise from consolidation; and were it reached some other way
      // the row would be non-primary, which #1164's ownership guard refuses.
      // Pinned here because it is what licenses applying the offset to the
      // profile strand alone.
      await insertDive('dive-1');
      await insertComputer('comp-secondary');
      await insertSource(
        id: 'src-secondary',
        diveId: 'dive-1',
        computerId: 'comp-secondary',
        isPrimary: false,
        timeOffsetSeconds: 90,
      );
      await insertProfile(
        id: 'prof-existing',
        diveId: 'dive-1',
        computerId: 'comp-secondary',
        timestamp: 90,
        depth: 12.0,
        isPrimary: false,
      );

      final parsed = makeParsedDive(
        samples: [pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0)],
        events: [pigeon.DiveEvent(timeSeconds: 0, type: 'bookmark')],
      );

      final result = await service.applyParsedUpdate(
        diveId: 'dive-1',
        sourceRowId: 'src-secondary',
        parsed: parsed,
        descriptorVendor: null,
        descriptorProduct: null,
        descriptorModel: null,
        libdivecomputerVersion: null,
      );

      expect(result.profilePreserved, isTrue);
      final profiles = await (db.select(
        db.diveProfiles,
      )..where((t) => t.diveId.equals('dive-1'))).get();
      expect(profiles.single.id, 'prof-existing');
      final events = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.equals('dive-1'))).get();
      expect(events, isEmpty);
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

      // Tank 2: new tank inserted, stamped with the source's computerId
      final t2 = tanks.firstWhere((t) => t.tankOrder == 2);
      expect(t2.o2Percent, 100.0);
      expect(t2.startPressure, 200.0);
      expect(t2.endPressure, 100.0);
      expect(t2.computerId, 'comp-1');
    });

    test('synthesizes tanks from gas mixes when the computer reports no '
        'tank records (transmitter-less, e.g. Aqualung i330R)', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );
      // No existing tank rows: the original tank-driven import dropped the
      // gas mixes entirely, so the dive fell back to the 21% air default.

      final parsed = makeParsedDive(
        tanks: [], // no transmitter: parser reports gas mixes only
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 50.0, hePercent: 0.0),
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

      final tanks =
          await (db.select(db.diveTanks)
                ..where((t) => t.diveId.equals('dive-1'))
                ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
              .get();

      expect(tanks.length, 2);
      expect(tanks[0].tankOrder, 0);
      expect(tanks[0].o2Percent, 32.0);
      expect(tanks[0].hePercent, 0.0);
      // The computer reported gases, not cylinders: no pressures/volume.
      expect(tanks[0].startPressure, isNull);
      expect(tanks[0].endPressure, isNull);
      expect(tanks[0].volume, isNull);
      expect(tanks[1].tankOrder, 1);
      expect(tanks[1].o2Percent, 50.0);
    });

    test('re-inserts tank pressure profiles and backfills start/end pressure '
        'from samples when the tank summary has no pressure (AI)', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      // Existing tank with previously-derived pressures, plus a stale pressure
      // profile row that the re-parse must replace.
      await db
          .into(db.diveTanks)
          .insert(
            const DiveTanksCompanion(
              id: Value('tank-0'),
              diveId: Value('dive-1'),
              volume: Value(12.0),
              startPressure: Value(225.9),
              endPressure: Value(93.5),
              o2Percent: Value(32.0),
              hePercent: Value(0.0),
              tankOrder: Value(0),
              tankRole: Value('backGas'),
            ),
          );
      await db
          .into(db.tankPressureProfiles)
          .insert(
            TankPressureProfilesCompanion.insert(
              id: 'stale-pp',
              diveId: 'dive-1',
              tankId: 'tank-0',
              timestamp: 0,
              pressure: 999.0,
            ),
          );

      // Air-integrated tank: summary pressure is null, pressure lives in the
      // sample stream.
      final parsed = makeParsedDive(
        tanks: [pigeon.TankInfo(index: 0, gasMixIndex: 0, volumeLiters: 12.0)],
        gasMixes: [pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0)],
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 0,
            depthMeters: 0.0,
            pressureBar: 220.0,
            tankIndex: 0,
          ),
          pigeon.ProfileSample(
            timeSeconds: 60,
            depthMeters: 18.0,
            pressureBar: 150.0,
            tankIndex: 0,
          ),
          pigeon.ProfileSample(
            timeSeconds: 120,
            depthMeters: 5.0,
            pressureBar: 90.0,
            tankIndex: 0,
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

      // Pressure profiles replaced with the parsed samples (stale row gone).
      final profiles =
          await (db.select(db.tankPressureProfiles)
                ..where((t) => t.diveId.equals('dive-1'))
                ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
              .get();
      expect(profiles.length, 3);
      expect(profiles.first.pressure, 220.0);
      expect(profiles.last.pressure, 90.0);
      expect(profiles.every((p) => p.tankId == 'tank-0'), isTrue);
      expect(
        profiles.every((p) => p.computerId == 'comp-1'),
        isTrue,
        reason: 'pressure profiles are stamped with the source computerId',
      );

      // Tank start/end pressure backfilled from first/last sample.
      final tank = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('dive-1'))).getSingle();
      expect(tank.startPressure, 220.0);
      expect(tank.endPressure, 90.0);
    });

    test('keeps both transmitters when a sample reports two tank pressures '
        '(issue #1223)', () async {
      // A CCR dive with an O2 and a diluent transmitter: libdivecomputer
      // reports both on the same sample. The wrapper used to keep only the last
      // one, so the O2 tank ended up with no readings at all and the chart drew
      // it as a flat "(est.)" line between its start and end pressure.
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      final parsed = makeParsedDive(
        tanks: [
          pigeon.TankInfo(index: 0, gasMixIndex: 0, usage: 1),
          pigeon.TankInfo(index: 1, gasMixIndex: 1, usage: 2),
        ],
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 100.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 21.0, hePercent: 0.0),
        ],
        samples: [
          // pressureBar/tankIndex still carry the last reading of each sample;
          // the per-tank list is the complete record.
          pigeon.ProfileSample(
            timeSeconds: 0,
            depthMeters: 0.0,
            pressureBar: 191.0,
            tankIndex: 1,
            tankPressuresBar: const [193.0, 191.0],
          ),
          pigeon.ProfileSample(
            timeSeconds: 60,
            depthMeters: 18.0,
            pressureBar: 150.0,
            tankIndex: 1,
            tankPressuresBar: const [188.0, 150.0],
          ),
          // The diluent transmitter drops out: the O2 tank keeps reporting and
          // must not inherit the gap.
          pigeon.ProfileSample(
            timeSeconds: 120,
            depthMeters: 5.0,
            pressureBar: 185.0,
            tankIndex: 0,
            tankPressuresBar: const [185.0],
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

      final tanks =
          await (db.select(db.diveTanks)
                ..where((t) => t.diveId.equals('dive-1'))
                ..orderBy([(t) => OrderingTerm.asc(t.tankOrder)]))
              .get();
      expect(tanks, hasLength(2));

      Future<List<double>> pressuresFor(String tankId) async {
        final rows =
            await (db.select(db.tankPressureProfiles)
                  ..where((t) => t.tankId.equals(tankId))
                  ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
                .get();
        return [for (final r in rows) r.pressure];
      }

      expect(await pressuresFor(tanks[0].id), [
        193.0,
        188.0,
        185.0,
      ], reason: 'the O2 transmitter must keep every reading it reported');
      expect(
        await pressuresFor(tanks[1].id),
        [191.0, 150.0],
        reason: 'the diluent transmitter keeps its own readings, gap included',
      );

      // Start/end pressure is backfilled per tank from its own series, so the
      // O2 tank no longer borrows the diluent's numbers.
      expect(tanks[0].startPressure, 193.0);
      expect(tanks[0].endPressure, 185.0);
      expect(tanks[1].startPressure, 191.0);
      expect(tanks[1].endPressure, 150.0);
    });

    test('derives and inserts gas switches from per-sample gas-mix '
        'transitions on a single-source primary re-parse', () async {
      // Shearwater-style multi-gas dive: transmitter tank 0 breathes 32%, then
      // the diver switches to a 99% deco gas (no transmitter -> synthesized
      // cylinder). The switch is only encoded as a per-sample gasMixIndex
      // change, so the gas_switches table must be derived from it.
      const unknownGasMixIndex = 4294967295;

      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      // A stale switch that must be cleared and replaced by the re-parse.
      await db
          .into(db.diveTanks)
          .insert(
            const DiveTanksCompanion(
              id: Value('stale-tank'),
              diveId: Value('dive-1'),
              o2Percent: Value(21.0),
              hePercent: Value(0.0),
              tankOrder: Value(0),
            ),
          );
      await db
          .into(db.gasSwitches)
          .insert(
            GasSwitchesCompanion(
              id: const Value('stale-switch'),
              diveId: const Value('dive-1'),
              timestamp: const Value(10),
              tankId: const Value('stale-tank'),
              createdAt: Value(nowMs),
            ),
          );

      final parsed = makeParsedDive(
        gasMixes: [
          pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0),
          pigeon.GasMix(index: 1, o2Percent: 99.0, hePercent: 0.0),
        ],
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: unknownGasMixIndex,
            startPressureBar: 240.0,
            endPressureBar: 90.0,
          ),
        ],
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 0,
            depthMeters: 0.0,
            tankIndex: 0,
            gasMixIndex: 0,
          ),
          pigeon.ProfileSample(
            timeSeconds: 120,
            depthMeters: 25.0,
            tankIndex: 0,
            gasMixIndex: 0,
          ),
          pigeon.ProfileSample(
            timeSeconds: 180,
            depthMeters: 6.0,
            tankIndex: 0,
            gasMixIndex: 1,
          ),
          pigeon.ProfileSample(
            timeSeconds: 240,
            depthMeters: 5.0,
            tankIndex: 0,
            gasMixIndex: 1,
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

      final switches = await (db.select(
        db.gasSwitches,
      )..where((t) => t.diveId.equals('dive-1'))).get();

      expect(
        switches,
        hasLength(1),
        reason: 'one switch at the 32%->99% change',
      );
      expect(switches.single.id, isNot('stale-switch'));
      expect(switches.single.timestamp, 180);
      expect(switches.single.depth, 6.0);

      // The switch must point at the 99% deco cylinder.
      final decoTank = await (db.select(
        db.diveTanks,
      )..where((t) => t.o2Percent.equals(99.0))).getSingle();
      expect(switches.single.tankId, decoTank.id);
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

    test('DiveTanks carry-over keeps a stored volume the computer does not '
        'report', () async {
      // Computers report pressure, not cylinder size, so a volume on the row
      // was entered by the diver (or filled from the default preset). A
      // re-parse must not null it out and make L/min SAC vanish (issue #386).
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );
      await db
          .into(db.diveTanks)
          .insert(
            const DiveTanksCompanion(
              id: Value('tank-0'),
              diveId: Value('dive-1'),
              volume: Value(12.0),
              startPressure: Value(200.0),
              endPressure: Value(50.0),
              o2Percent: Value(21.0),
              hePercent: Value(0.0),
              tankOrder: Value(0),
            ),
          );

      final parsed = makeParsedDive(
        tanks: [
          pigeon.TankInfo(
            index: 0,
            gasMixIndex: 0,
            startPressureBar: 210.0,
            endPressureBar: 40.0,
          ),
        ],
        gasMixes: [pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0)],
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

      final tank = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('dive-1'))).getSingle();
      // Pressures follow the computer; the size the computer never saw stays.
      expect(tank.startPressure, 210.0);
      expect(tank.endPressure, 40.0);
      expect(tank.volume, 12.0);
    });

    test(
      'DiveTanks carry-over treats a zero parsed volume as unreported',
      () async {
        // The native bridges already map a libdc volume of 0 to null, but the
        // Dart layer must not rely on that: 0 means "missing" everywhere else
        // in the tank code, so it must not clobber a stored size either.
        await insertDive('dive-1');
        await insertComputer('comp-1');
        await insertSource(
          id: 'src-1',
          diveId: 'dive-1',
          computerId: 'comp-1',
          isPrimary: true,
        );
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
              ),
            );

        await service.applyParsedUpdate(
          diveId: 'dive-1',
          sourceRowId: 'src-1',
          parsed: makeParsedDive(
            tanks: [
              pigeon.TankInfo(index: 0, gasMixIndex: 0, volumeLiters: 0.0),
            ],
            gasMixes: [
              pigeon.GasMix(index: 0, o2Percent: 21.0, hePercent: 0.0),
            ],
          ),
          descriptorVendor: null,
          descriptorProduct: null,
          descriptorModel: null,
          libdivecomputerVersion: null,
        );

        final tank = await (db.select(
          db.diveTanks,
        )..where((t) => t.diveId.equals('dive-1'))).getSingle();
        expect(tank.volume, 12.0);
      },
    );

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
      expect(
        events.every((e) => e.computerId == 'comp-1'),
        isTrue,
        reason: 'events are stamped with the source computerId',
      );

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

      final parsed = makeParsedDive(diveMode: 'unrecognized_mode');

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

    test('gauge diveMode maps to gauge', () async {
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
      expect(dive.diveMode, 'gauge');
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

    test('bottomTime falls back to durationSeconds when the bottom span '
        'is zero', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

      // Only the first sample reaches the ascent threshold (min(max(6,
      // 9.9), 25.5) = 9.9 m), so ascent start == surface departure and the
      // computed span is zero.
      final parsed = makeParsedDive(
        maxDepthMeters: 30.0,
        durationSeconds: 1200,
        samples: [
          pigeon.ProfileSample(timeSeconds: 0, depthMeters: 30.0),
          pigeon.ProfileSample(timeSeconds: 60, depthMeters: 1.0),
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
      // Ascent start (t=0) minus surface departure (t=0) is zero, so bottom
      // time returns null and falls back to durationSeconds.
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

      final errors = (await service.reparseDive(
        'dive-1',
        parseFn: fakeParseFn,
      )).errors;

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

      final errors = (await service.reparseDive(
        'dive-1',
        parseFn: fakeParseFn,
      )).errors;

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

      final errors = (await service.reparseDive(
        'dive-1',
        parseFn: (vendor, product, model, rawData) async {
          throw Exception('native bridge error');
        },
      )).errors;

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

      final errors = (await service.reparseDive(
        'dive-1',
        parseFn: fakeParseFn,
      )).errors;

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

        final errors = (await service.reparseDive(
          'dive-1',
          parseFn: (vendor, product, model, rawData) async {
            if (vendor == 'Suunto') {
              throw Exception('Suunto parse failure');
            }
            return makeParsedDive();
          },
        )).errors;

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

  group('Coverage: null-computerId source stamps null attribution', () {
    test('new tank, tank pressure profile, and event rows all carry a null '
        'computerId when the source has none (manual import, no computer '
        'association)', () async {
      await insertDive('dive-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: null,
        isPrimary: true,
      );
      // No pre-existing tanks: exercises the _carryOverTanks new-tank
      // insert branch, which is the one that stamps computerId.

      final parsed = makeParsedDive(
        tanks: [pigeon.TankInfo(index: 0, gasMixIndex: 0, volumeLiters: 12.0)],
        gasMixes: [pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0)],
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 0,
            depthMeters: 0.0,
            pressureBar: 200.0,
            tankIndex: 0,
          ),
          pigeon.ProfileSample(
            timeSeconds: 60,
            depthMeters: 18.0,
            pressureBar: 100.0,
            tankIndex: 0,
          ),
        ],
        events: [pigeon.DiveEvent(timeSeconds: 30, type: 'bookmark')],
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
      expect(tanks, hasLength(1));
      expect(tanks.single.computerId, isNull);

      final pressures = await (db.select(
        db.tankPressureProfiles,
      )..where((t) => t.diveId.equals('dive-1'))).get();
      expect(pressures, isNotEmpty);
      expect(pressures.every((p) => p.computerId == null), isTrue);

      final events = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.equals('dive-1'))).get();
      expect(events, hasLength(1));
      expect(events.single.computerId, isNull);
    });
  });

  group('Coverage: _carryOverTanks gas mix fallback', () {
    test(
      'unmatched gasMixIndex falls back to the primary (first) mix',
      () async {
        await insertDive('dive-1');
        await insertComputer('comp-1');
        await insertSource(
          id: 'src-1',
          diveId: 'dive-1',
          computerId: 'comp-1',
          isPrimary: true,
        );

        // Tank gas-mix link unmatched (e.g. DC_GASMIX_UNKNOWN on Shearwater)
        // and no per-sample gas to disambiguate: the transmitter tank resolves
        // to the dive's primary mix (not a hardcoded air default), and the
        // second reported gas is kept as a pressureless cylinder rather than
        // being dropped.
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
            pigeon.GasMix(index: 0, o2Percent: 32.0, hePercent: 0.0),
            pigeon.GasMix(index: 1, o2Percent: 21.0, hePercent: 0.0),
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
        expect(tanks.length, 2);
        // Transmitter tank: primary mix (index 0 = EAN32), with its pressures.
        final backGas = tanks.firstWhere((t) => t.o2Percent == 32.0);
        expect(backGas.tankOrder, 0);
        expect(backGas.startPressure, 200.0);
        // Second gas kept as a pressureless cylinder.
        final other = tanks.firstWhere((t) => t.o2Percent == 21.0);
        expect(other.startPressure, isNull);
      },
    );

    test('falls back to air only when there are no gas mixes at all', () async {
      await insertDive('dive-1');
      await insertComputer('comp-1');
      await insertSource(
        id: 'src-1',
        diveId: 'dive-1',
        computerId: 'comp-1',
        isPrimary: true,
      );

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
        gasMixes: [],
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
      // Ascent threshold = min(max(6, 0.33*30=9.9), 0.85*30=25.5) = 9.9 m.
      // The last sample at/deeper than 9.9 m is t=300 (10 m); bottom time
      // runs from surface departure (t=0), so 300 s.
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
      // Bottom time: surface departure t=0 to ascent start t=300
      expect(dive.bottomTime, 300);
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

  // ---------------------------------------------------------------------------
  // #1164: a source row may only rewrite the profile strand it exclusively
  // authored, in its own parse frame. A sequential combine (DiveMergeService)
  // carries every original's source row onto the merged dive demoted to
  // non-primary and re-bases the samples, so no carried row satisfies that.
  // ---------------------------------------------------------------------------
  group('ReparseService merged-dive profile guard', () {
    /// The shape DiveMergeService.apply leaves behind: a brand-new dive whose
    /// only dive_data_sources rows are carried provenance, every one demoted.
    Future<void> insertMergedDive(
      List<({String sourceId, String? computerId})> carried,
    ) async {
      await insertDive('merged-1', maxDepth: 25.0, runtime: 4200);
      final seenComputers = <String>{};
      for (final c in carried) {
        if (c.computerId != null && seenComputers.add(c.computerId!)) {
          await insertComputer(c.computerId!);
        }
        await insertSource(
          id: c.sourceId,
          diveId: 'merged-1',
          computerId: c.computerId,
          isPrimary: false,
        );
      }
    }

    /// First half at 0..180, surface gap filled at 240..300, second half
    /// re-based to 360..540 -- the timeline DiveMergeService produces.
    const mergedTimestamps = [0, 60, 120, 180, 240, 300, 360, 420, 480, 540];

    Future<void> insertMergedProfile(String? computerId) async {
      for (var i = 0; i < mergedTimestamps.length; i++) {
        final ts = mergedTimestamps[i];
        await insertProfile(
          id: 'merged-prof-$i',
          diveId: 'merged-1',
          computerId: computerId,
          timestamp: ts,
          depth: ts >= 240 && ts <= 300 ? 0.0 : 20.0,
        );
      }
    }

    Future<List<DiveProfile>> mergedProfiles() {
      return (db.select(db.diveProfiles)
            ..where((t) => t.diveId.equals('merged-1'))
            ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]))
          .get();
    }

    test('both halves and the synthesized gap survive when the carried sources '
        'share one computer', () async {
      await insertMergedDive([
        (sourceId: 'src-a', computerId: 'comp-1'),
        (sourceId: 'src-b', computerId: 'comp-1'),
      ]);
      await insertMergedProfile('comp-1');

      for (final sourceId in ['src-a', 'src-b']) {
        await service.applyParsedUpdate(
          diveId: 'merged-1',
          sourceRowId: sourceId,
          parsed: makeParsedDive(),
          descriptorVendor: null,
          descriptorProduct: null,
          descriptorModel: null,
          libdivecomputerVersion: null,
        );
      }

      final profiles = await mergedProfiles();
      expect(profiles.map((p) => p.timestamp), mergedTimestamps);
      expect(profiles.map((p) => p.id), everyElement(startsWith('merged-')));
      expect(profiles.every((p) => p.isPrimary), isTrue);
    });

    test(
      'the profile survives when the halves came from different computers',
      () async {
        await insertMergedDive([
          (sourceId: 'src-a', computerId: 'comp-1'),
          (sourceId: 'src-b', computerId: 'comp-2'),
        ]);
        await insertMergedProfile('comp-1');

        await service.applyParsedUpdate(
          diveId: 'merged-1',
          sourceRowId: 'src-a',
          parsed: makeParsedDive(),
          descriptorVendor: null,
          descriptorProduct: null,
          descriptorModel: null,
          libdivecomputerVersion: null,
        );

        expect(
          (await mergedProfiles()).map((p) => p.timestamp),
          mergedTimestamps,
        );
      },
    );

    test(
      'surface-gap events survive when only one original had a source row',
      () async {
        // A single carried row leaves isMultiSource false, so step 5 would
        // otherwise delete the merge's own surface markers.
        await insertMergedDive([(sourceId: 'src-a', computerId: 'comp-1')]);
        await insertMergedProfile('comp-1');
        for (final ts in [240, 300]) {
          await db
              .into(db.diveProfileEvents)
              .insert(
                DiveProfileEventsCompanion.insert(
                  id: 'gap-event-$ts',
                  diveId: 'merged-1',
                  timestamp: ts,
                  eventType: 'surface',
                  source: const Value('app'),
                  createdAt: nowMs,
                ),
              );
        }

        await service.applyParsedUpdate(
          diveId: 'merged-1',
          sourceRowId: 'src-a',
          parsed: makeParsedDive(),
          descriptorVendor: null,
          descriptorProduct: null,
          descriptorModel: null,
          libdivecomputerVersion: null,
        );

        final events = await (db.select(
          db.diveProfileEvents,
        )..where((t) => t.diveId.equals('merged-1'))).get();
        expect(
          events.map((e) => e.id),
          containsAll(['gap-event-240', 'gap-event-300']),
        );
        expect((await mergedProfiles()).length, mergedTimestamps.length);
      },
    );

    test(
      'a consolidated dive still re-parses its non-primary secondary strand',
      () async {
        // DiveConsolidationService demotes only the secondaries, so the target
        // keeps a primary source row -- that strand is genuinely the secondary
        // source's to rewrite and must not be caught by the guard.
        await insertDive('dive-1');
        await insertComputer('comp-1');
        await insertComputer('comp-2');
        await insertSource(
          id: 'src-primary',
          diveId: 'dive-1',
          computerId: 'comp-1',
          isPrimary: true,
        );
        await insertSource(
          id: 'src-secondary',
          diveId: 'dive-1',
          computerId: 'comp-2',
          isPrimary: false,
        );
        await insertProfile(
          id: 'stale-secondary',
          diveId: 'dive-1',
          computerId: 'comp-2',
          timestamp: 999,
          depth: 40.0,
          isPrimary: false,
        );

        await service.applyParsedUpdate(
          diveId: 'dive-1',
          sourceRowId: 'src-secondary',
          parsed: makeParsedDive(
            samples: [
              pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
              pigeon.ProfileSample(timeSeconds: 60, depthMeters: 12.0),
            ],
          ),
          descriptorVendor: null,
          descriptorProduct: null,
          descriptorModel: null,
          libdivecomputerVersion: null,
        );

        final secondary =
            await (db.select(db.diveProfiles)
                  ..where((t) => t.computerId.equals('comp-2'))
                  ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]))
                .get();
        expect(secondary.map((p) => p.timestamp), [0, 60]);
        expect(secondary.any((p) => p.isPrimary), isFalse);
      },
    );

    test(
      'a provenance-only sibling sharing the strand does not block a re-parse',
      () async {
        // Deleting a computer nulls its sources' computerId (FK setNull) and
        // _backfillProvenanceSnapshots adds rows with no computerId of their
        // own, so two rows sharing a null strand is an ordinary shape. A
        // sibling with no raw data can never be re-parsed, so it cannot
        // contend for the strand.
        await insertDive('dive-1');
        await insertSource(id: 'src-download', diveId: 'dive-1');
        await insertSource(
          id: 'src-provenance',
          diveId: 'dive-1',
          isPrimary: false,
        );
        await (db.update(
          db.diveDataSources,
        )..where((t) => t.id.equals('src-download'))).write(
          DiveDataSourcesCompanion(
            rawData: Value(Uint8List.fromList([1, 2, 3])),
          ),
        );
        await insertProfile(
          id: 'stale',
          diveId: 'dive-1',
          timestamp: 999,
          depth: 40.0,
        );

        await service.applyParsedUpdate(
          diveId: 'dive-1',
          sourceRowId: 'src-download',
          parsed: makeParsedDive(
            samples: [
              pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
              pigeon.ProfileSample(timeSeconds: 60, depthMeters: 12.0),
            ],
          ),
          descriptorVendor: null,
          descriptorProduct: null,
          descriptorModel: null,
          libdivecomputerVersion: null,
        );

        final profiles =
            await (db.select(db.diveProfiles)
                  ..where((t) => t.diveId.equals('dive-1'))
                  ..orderBy([(t) => OrderingTerm(expression: t.timestamp)]))
                .get();
        expect(profiles.map((p) => p.timestamp), [0, 60]);
      },
    );

    test(
      'reparseDive reports how many sources had their profile preserved',
      () async {
        await insertMergedDive([
          (sourceId: 'src-a', computerId: 'comp-1'),
          (sourceId: 'src-b', computerId: 'comp-1'),
        ]);
        await insertMergedProfile('comp-1');
        for (final sourceId in ['src-a', 'src-b']) {
          await (db.update(
            db.diveDataSources,
          )..where((t) => t.id.equals(sourceId))).write(
            DiveDataSourcesCompanion(
              rawData: Value(Uint8List.fromList([1, 2, 3])),
              descriptorVendor: const Value('Shearwater'),
              descriptorProduct: const Value('Perdix'),
              descriptorModel: const Value(42),
            ),
          );
        }

        Future<pigeon.ParsedDive> fakeParse(
          String vendor,
          String product,
          int model,
          Uint8List raw,
        ) async => makeParsedDive();

        final result = await service.reparseDive(
          'merged-1',
          parseFn: fakeParse,
        );

        expect(result.errors, isEmpty);
        expect(result.profilesPreserved, 2);
      },
    );
  });
}
