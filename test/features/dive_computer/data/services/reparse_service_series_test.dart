import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libdivecomputer_plugin/libdivecomputer_plugin.dart' as pigeon;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/data/services/libdc_sample_units.dart';
import 'package:submersion/features/dive_computer/data/services/reparse_service.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

void main() {
  late AppDatabase db;
  late ReparseService service;
  late ProfileSeriesRepository profileSeries;
  late TankPressureSeriesRepository tankSeries;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = ReparseService(db: db);
    profileSeries = ProfileSeriesRepository(
      database: db,
      syncRepository: SyncRepository(database: db),
    );
    tankSeries = TankPressureSeriesRepository(
      database: db,
      syncRepository: SyncRepository(database: db),
    );
  });

  tearDown(() => db.close());

  // ---------------------------------------------------------------------------
  // Helpers, copied from reparse_service_test.dart.
  // ---------------------------------------------------------------------------

  final nowMs = DateTime.utc(2026, 1, 15, 10, 0).millisecondsSinceEpoch;

  Future<void> insertDive(String id) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(nowMs),
            notes: const Value(''),
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
    int? timeOffsetSeconds,
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
            timeOffsetSeconds: Value(timeOffsetSeconds),
            importedAt: Value(now),
            createdAt: Value(now),
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

  Future<void> apply(pigeon.ParsedDive parsed) => service.applyParsedUpdate(
    diveId: 'dive-1',
    sourceRowId: 'src-1',
    parsed: parsed,
    descriptorVendor: 'Shearwater',
    descriptorProduct: 'Perdix',
    descriptorModel: 42,
    libdivecomputerVersion: '0.8.0',
  );

  Future<void> seedDive({int? timeOffsetSeconds}) async {
    await insertDive('dive-1');
    await insertComputer('comp-1');
    await insertSource(
      id: 'src-1',
      diveId: 'dive-1',
      computerId: 'comp-1',
      timeOffsetSeconds: timeOffsetSeconds,
    );
  }

  // ---------------------------------------------------------------------------
  // Tests
  // ---------------------------------------------------------------------------

  test(
    'applyParsedUpdate replaces the computer series with the parsed samples, '
    'offset applied',
    () async {
      await seedDive(timeOffsetSeconds: 5);
      final stale = await profileSeries.insertSeries(
        diveId: 'dive-1',
        computerId: 'comp-1',
        sourceId: 'src-1',
        samples: const [ProfileSample(timestamp: 0, depth: 99.0)],
        now: 1000,
      );
      await apply(
        makeParsedDive(
          samples: [
            pigeon.ProfileSample(timeSeconds: 0, depthMeters: 0.0),
            pigeon.ProfileSample(timeSeconds: 30, depthMeters: 12.0),
          ],
        ),
      );
      final rows = await profileSeries.getSeriesForDive('dive-1');
      expect(rows, hasLength(1));
      expect(rows.single.id, isNot(stale));
      expect(rows.single.computerId, 'comp-1');
      expect(rows.single.sourceId, 'src-1');
      expect(rows.single.isPrimary, isTrue);
      expect(rows.single.samples.map((s) => (s.timestamp, s.depth)).toList(), [
        (5, 0.0),
        (35, 12.0),
      ]);
      final tombstones = await db.select(db.deletionLog).get();
      expect(tombstones.map((t) => (t.entityType, t.recordId)).toList(), [
        ('diveProfileSeries', stale),
      ]);
    },
  );

  test(
    'a primary single-source reparse replaces the tank pressure series',
    () async {
      await seedDive();
      await db
          .into(db.diveTanks)
          .insert(
            const DiveTanksCompanion(
              id: Value('tank-0'),
              diveId: Value('dive-1'),
              computerId: Value('comp-1'),
              tankOrder: Value(0),
              o2Percent: Value(32.0),
              hePercent: Value(0.0),
              tankRole: Value('backGas'),
            ),
          );
      final stale = await tankSeries.insertSeries(
        diveId: 'dive-1',
        tankId: 'tank-0',
        computerId: 'comp-1',
        samples: const [TankPressureSample(timestamp: 0, pressure: 999.0)],
        now: 1000,
      );
      await apply(
        makeParsedDive(
          tanks: [
            pigeon.TankInfo(index: 0, gasMixIndex: 0, volumeLiters: 12.0),
          ],
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
              depthMeters: 10.0,
              pressureBar: 150.0,
              tankIndex: 0,
            ),
          ],
        ),
      );
      final rows = await tankSeries.getSeriesForDive('dive-1');
      expect(rows, hasLength(1));
      expect(rows.single.id, isNot(stale));
      expect(rows.single.tankId, 'tank-0');
      expect(rows.single.computerId, 'comp-1');
      expect(rows.single.samples.map((s) => s.pressure), [200.0, 150.0]);
      final tombstones = await db.select(db.deletionLog).get();
      expect(
        tombstones.map((t) => (t.entityType, t.recordId)),
        contains(('tankPressureSeries', stale)),
      );
    },
  );

  test('ndl, ceiling and rbt derive from decoType exactly as the legacy row '
      'did', () async {
    await seedDive();
    await apply(
      makeParsedDive(
        samples: [
          pigeon.ProfileSample(
            timeSeconds: 0,
            depthMeters: 0.0,
            decoType: 0,
            decoTime: 600,
            rbt: 12,
          ),
          pigeon.ProfileSample(
            timeSeconds: 60,
            depthMeters: 20.0,
            decoType: 1,
            decoTime: 120,
            decoDepth: 6.0,
          ),
        ],
      ),
    );
    final samples = (await profileSeries.getSeriesForDive(
      'dive-1',
    )).single.samples;
    expect(samples[0].ndl, 600);
    expect(samples[0].ceiling, isNull);
    expect(samples[0].rbt, libdcRbtToSeconds(12));
    expect(samples[1].ndl, isNull);
    expect(samples[1].ceiling, 6.0);
    expect(samples[1].decoType, 1);
  });
}
