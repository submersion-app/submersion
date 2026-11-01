import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart' hide DiveSite;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/data_quality/data/services/quality_context_builder.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../helpers/drift_statement_log.dart';
import '../../../helpers/test_database.dart';

/// Issue #3864: a scan builds its contexts from the sample-free dive read, so
/// a dive's series are decoded for the detectors and not once before that.
/// What the detectors read off the dive has to come out as the full read
/// gives it, wherever that value lives.
void main() {
  late DiveRepository repository;
  late ProfileSeriesRepository profiles;
  late TankPressureSeriesRepository tanks;

  final entry = DateTime.utc(2026, 3, 1, 9);

  const profile = [
    domain.DiveProfilePoint(timestamp: 0, depth: 0, temperature: 21),
    domain.DiveProfilePoint(timestamp: 1500, depth: 18, temperature: 19),
    domain.DiveProfilePoint(timestamp: 3000, depth: 0, temperature: 20),
  ];

  /// A dive whose own row answers everything.
  domain.Dive storedDive(String id, {DateTime? at}) {
    final start = at ?? entry;
    return domain.Dive(
      id: id,
      dateTime: start,
      entryTime: start,
      exitTime: start.add(const Duration(minutes: 50)),
      runtime: const Duration(minutes: 50),
      bottomTime: const Duration(minutes: 42),
      maxDepth: 18,
      avgDepth: 11,
      waterTemp: 26,
      profile: profile,
    );
  }

  group('with the database under the app', () {
    late QualityContextBuilder builder;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
      profiles = ProfileSeriesRepository();
      tanks = TankPressureSeriesRepository();
      builder = QualityContextBuilder();
    });
    tearDown(tearDownTestDatabase);

    Future<DiveQualityContext> contextOf(String id) async =>
        (await builder.buildAll([id])).single;

    Future<domain.Dive> fullRead(String id) async =>
        (await repository.getDivesByIds([id])).single;

    test('a stored dive keeps what its row says', () async {
      await repository.createDive(storedDive('d1'));

      final dive = (await contextOf('d1')).dive;

      expect(dive.waterTemp, 26);
      expect(dive.effectiveRuntime, const Duration(minutes: 50));
      expect(dive.maxDepth, 18);
      expect(dive.avgDepth, 11);
    });

    group('a value only the samples can answer', () {
      test('water temperature comes from the profile', () async {
        await repository.createDive(
          domain.Dive(
            id: 'd1',
            dateTime: entry,
            entryTime: entry,
            runtime: const Duration(minutes: 50),
            profile: profile,
          ),
        );

        final dive = (await contextOf('d1')).dive;

        expect(dive.waterTemp, 19);
        expect(dive.waterTemp, (await fullRead('d1')).waterTemp);
      });

      test('runtime comes from the profile span', () async {
        await repository.createDive(
          domain.Dive(
            id: 'd1',
            dateTime: entry,
            entryTime: entry,
            waterTemp: 26,
            profile: profile,
          ),
        );

        final ctx = await contextOf('d1');

        expect(ctx.dive.effectiveRuntime, const Duration(seconds: 3000));
        expect(
          ctx.dive.effectiveRuntime,
          (await fullRead('d1')).effectiveRuntime,
        );
      });

      test('tank endpoints come from the pressure series', () async {
        await repository.createDive(
          domain.Dive(
            id: 'd1',
            dateTime: entry,
            entryTime: entry,
            runtime: const Duration(minutes: 50),
            waterTemp: 26,
            profile: profile,
            tanks: const [domain.DiveTank(id: 'tank-1')],
          ),
        );
        await tanks.insertSeries(
          diveId: 'd1',
          tankId: 'tank-1',
          samples: const [
            TankPressureSample(timestamp: 0, pressure: 205),
            TankPressureSample(timestamp: 3000, pressure: 62),
          ],
        );

        final tank = (await contextOf('d1')).tanks.single;
        final full = (await fullRead('d1')).tanks.single;

        expect(tank.startPressure, 205);
        expect(tank.endPressure, 62);
        expect(tank.startPressure, full.startPressure);
        expect(tank.endPressure, full.endPressure);
      });
    });

    test('a site still supplies the water type the gas checks use', () async {
      final site = await SiteRepository().createSite(
        const DiveSite(id: 's1', name: 'Quarry', waterType: WaterType.fresh),
      );
      await repository.createDive(storedDive('d1').copyWith(site: site));

      final dive = (await contextOf('d1')).dive;

      expect(dive.effectiveWaterType, WaterType.fresh);
      expect(
        dive.environment.pressureAtDepth(30),
        (await fullRead('d1')).environment.pressureAtDepth(30),
      );
    });

    test('detectors see the primary recording alone', () async {
      await repository.createDive(storedDive('d1'));
      await profiles.insertSeries(
        diveId: 'd1',
        isPrimary: false,
        samples: const [
          ProfileSample(timestamp: 700, depth: 44),
          ProfileSample(timestamp: 900, depth: 45),
        ],
      );

      final ctx = await contextOf('d1');

      expect(ctx.primarySamples.map((s) => s.t), [0, 1500, 3000]);
      expect(ctx.primarySampleCount, 3);
    });
  });

  group('what it costs', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase(
        NativeDatabase.memory(
          logStatements: true,
          setup: registerAppSqlFunctions,
        ),
      );
      DatabaseService.instance.setTestDatabase(db);
      repository = DiveRepository();
      profiles = ProfileSeriesRepository();
      tanks = TankPressureSeriesRepository();
    });
    tearDown(tearDownTestDatabase);

    /// Dives logged by two computers, each carrying a pressure series.
    /// Fixtures stay outside the zone: their writes would be counted too.
    Future<List<String>> createDives(int count) async {
      final ids = [for (var i = 0; i < count; i++) 'dive-$i'];
      for (final (i, id) in ids.indexed) {
        await repository.createDive(
          storedDive(id, at: entry.add(Duration(days: i))).copyWith(
            tanks: [
              domain.DiveTank(
                id: 'tank-$id',
                startPressure: 200,
                endPressure: 60,
              ),
            ],
          ),
        );
        await profiles.insertSeries(
          diveId: id,
          isPrimary: false,
          samples: const [ProfileSample(timestamp: 0, depth: 3)],
        );
        await tanks.insertSeries(
          diveId: id,
          tankId: 'tank-$id',
          samples: const [TankPressureSample(timestamp: 0, pressure: 200)],
        );
      }
      return ids;
    }

    test('reads each dive\'s series once', () async {
      final ids = await createDives(5);

      final read = await statementsOf(
        () => QualityContextBuilder().buildAll(ids),
      );

      expect(
        read.where((s) => s.contains('FROM "dive_profile_series"')),
        hasLength(5),
      );
      expect(
        read.where((s) => s.contains('FROM "tank_pressure_series"')),
        hasLength(5),
      );
    });

    test('never reads a recording no detector looks at', () async {
      final ids = await createDives(1);

      final read = await statementsOf(
        () => QualityContextBuilder().buildAll(ids),
      );

      expect(
        read.where((s) => s.contains('FROM "dive_profile_series"')).single,
        contains('"is_primary"'),
      );
    });
  });
}
