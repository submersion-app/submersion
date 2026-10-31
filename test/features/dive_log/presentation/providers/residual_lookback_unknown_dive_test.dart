import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings(super.settings);

  @override
  Future<void> get settingsLoaded async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A dive the analysis knows nothing about the oxygen of (no profile, or a
/// gauge dive) must not read as a complete recovery from the dives before it:
/// their known load carries past it (#3976).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shallowAir = [
    ProfileSample(timestamp: 0, depth: 0),
    ProfileSample(timestamp: 60, depth: 3),
    ProfileSample(timestamp: 540, depth: 3),
    ProfileSample(timestamp: 600, depth: 0),
  ];

  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedDive(
    String id,
    DateTime start,
    int minutes, {
    List<ProfileSample>? samples,
    String diveMode = 'oc',
  }) async {
    final startMs = start.millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(startMs),
            entryTime: Value(startMs),
            exitTime: Value(startMs + minutes * 60000),
            runtime: Value(minutes * 60),
            diveMode: Value(diveMode),
            createdAt: Value(startMs),
            updatedAt: Value(startMs),
          ),
        );
    if (samples != null) {
      await ProfileSeriesRepository().insertSeries(
        diveId: id,
        isPrimary: true,
        samples: samples,
        now: startMs,
      );
    }
  }

  /// The known dive ends at 09:30 on 100% and the current dive starts at
  /// 10:30, with an intervening dive between 10:00 and 10:10 once a test adds
  /// one: 50 minutes of surface time, not 60.
  final knownStart = DateTime.utc(2026, 10, 31, 9);
  final middleStart = DateTime.utc(2026, 10, 31, 10);
  final currentStart = DateTime.utc(2026, 10, 31, 10, 30);

  Future<void> seedKnownAndCurrent() async {
    await seedDive('known', knownStart, 30);
    await seedDive('current', currentStart, 10, samples: shallowAir);
  }

  ProviderContainer containerFor({
    MetricDataSource cnsSource = MetricDataSource.calculated,
    List<Override> overrides = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => _FixedSettings(AppSettings(defaultCnsSource: cnsSource)),
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  final knownCns100 = profileAnalysisProvider('known').overrideWith(
    (ref) async => ProfileAnalysis.empty().copyWith(
      o2Exposure: const O2Exposure(cnsEnd: 100),
    ),
  );

  Future<O2Exposure> currentExposure(ProviderContainer container) async {
    final analysis = await container.read(
      profileAnalysisProvider('current').future,
    );
    expect(analysis, isNotNull);
    return analysis!.o2Exposure;
  }

  group('residual CNS', () {
    test('with no dive in between decays over the whole gap', () async {
      await seedKnownAndCurrent();

      final exposure = await currentExposure(
        containerFor(overrides: [knownCns100]),
      );

      expect(
        exposure.cnsStart,
        closeTo(CnsTable.cnsAfterSurfaceInterval(100, 60), 0.001),
      );
      expect(exposure.cnsIsMinimum, isFalse);
    });

    test('carries past a dive with no profile', () async {
      await seedKnownAndCurrent();
      await seedDive('manual', middleStart, 10);

      final exposure = await currentExposure(
        containerFor(overrides: [knownCns100]),
      );

      expect(
        exposure.cnsStart,
        closeTo(CnsTable.cnsAfterSurfaceInterval(100, 50), 0.001),
      );
      expect(exposure.cnsIsMinimum, isTrue);
    });

    test('carries past a gauge dive', () async {
      await seedKnownAndCurrent();
      await seedDive(
        'gauge',
        middleStart,
        10,
        samples: shallowAir,
        diveMode: 'gauge',
      );

      final exposure = await currentExposure(
        containerFor(overrides: [knownCns100]),
      );

      expect(
        exposure.cnsStart,
        closeTo(CnsTable.cnsAfterSurfaceInterval(100, 50), 0.001),
      );
      expect(exposure.cnsIsMinimum, isTrue);
    });

    test('a gauge dive holds the load it started with, marked as a minimum: '
        'the live readout projects from it when it is the last dive', () async {
      await seedDive('known', knownStart, 30);
      await seedDive(
        'gauge',
        middleStart,
        10,
        samples: shallowAir,
        diveMode: 'gauge',
      );

      final analysis = await containerFor(
        overrides: [knownCns100],
      ).read(profileAnalysisProvider('gauge').future);

      final carried = CnsTable.cnsAfterSurfaceInterval(100, 30);
      expect(analysis!.o2Exposure.cnsStart, closeTo(carried, 0.001));
      expect(analysis.o2Exposure.cnsEnd, closeTo(carried, 0.001));
      expect(analysis.o2Exposure.cnsIsMinimum, isTrue);
    });

    test('carries past a dive with no profile under the computer CNS '
        'source, from the earlier computer reading', () async {
      await seedDive(
        'known',
        knownStart,
        30,
        samples: const [
          ProfileSample(timestamp: 0, depth: 0, cns: 10),
          ProfileSample(timestamp: 900, depth: 20),
          ProfileSample(timestamp: 1800, depth: 0, cns: 60),
        ],
      );
      await seedDive('current', currentStart, 10, samples: shallowAir);
      await seedDive('manual', middleStart, 10);

      final exposure = await currentExposure(
        containerFor(cnsSource: MetricDataSource.computer),
      );

      expect(
        exposure.cnsStart,
        closeTo(CnsTable.cnsAfterSurfaceInterval(60, 50), 0.001),
      );
      expect(exposure.cnsIsMinimum, isTrue);
    });

    test('walks past several unknown dives, adding up only the surface '
        'time', () async {
      await seedKnownAndCurrent();
      await seedDive('manual-1', DateTime.utc(2026, 10, 31, 9, 40), 5);
      await seedDive('manual-2', middleStart, 10);

      final exposure = await currentExposure(
        containerFor(overrides: [knownCns100]),
      );

      // 10 + 15 + 20 minutes at the surface, 15 of the hour underwater.
      expect(
        exposure.cnsStart,
        closeTo(CnsTable.cnsAfterSurfaceInterval(100, 45), 0.001),
      );
      expect(exposure.cnsIsMinimum, isTrue);
    });

    test('a later dive keeps the minimum mark, since its residual comes from '
        'a figure that is itself a minimum', () async {
      await seedKnownAndCurrent();
      await seedDive('manual', middleStart, 10);
      await seedDive(
        'later',
        DateTime.utc(2026, 10, 31, 11),
        10,
        samples: shallowAir,
      );

      final analysis = await containerFor(
        overrides: [knownCns100],
      ).read(profileAnalysisProvider('later').future);

      expect(analysis!.o2Exposure.cnsStart, greaterThan(0));
      expect(analysis.o2Exposure.cnsIsMinimum, isTrue);
    });

    test('the mark expires once the unknown dive is outside the recovery '
        'window, even though every gap between dives is inside it', () async {
      await seedDive('manual', DateTime.utc(2026, 10, 29, 9), 10);
      await seedDive(
        'first-after',
        DateTime.utc(2026, 10, 29, 22),
        10,
        samples: shallowAir,
      );
      await seedDive(
        'second-after',
        DateTime.utc(2026, 10, 30, 11),
        10,
        samples: shallowAir,
      );

      final container = containerFor();
      final first = await container.read(
        profileAnalysisProvider('first-after').future,
      );
      final second = await container.read(
        profileAnalysisProvider('second-after').future,
      );

      expect(first!.o2Exposure.cnsIsMinimum, isTrue);
      expect(second!.o2Exposure.cnsIsMinimum, isFalse);
    });

    test('an unknown dive with nothing known before it starts at zero, '
        'marked as a minimum', () async {
      await seedDive('current', currentStart, 10, samples: shallowAir);
      await seedDive('manual', middleStart, 10);

      final exposure = await currentExposure(containerFor());

      expect(exposure.cnsStart, 0);
      expect(exposure.cnsIsMinimum, isTrue);
    });

    test('the 24h recovery window counts the surface time on both sides of '
        'an unknown dive', () async {
      await seedDive('known', DateTime.utc(2026, 10, 30, 9), 30);
      await seedDive('current', currentStart, 10, samples: shallowAir);
      // 14 hours after the known dive and 11 before the current one: neither
      // gap reaches 24 hours, together they do.
      await seedDive('manual', DateTime.utc(2026, 10, 30, 23, 30), 10);

      final exposure = await currentExposure(
        containerFor(overrides: [knownCns100]),
      );

      expect(exposure.cnsStart, 0);
      expect(exposure.cnsIsMinimum, isTrue);
    });

    test('a dive with its own computer CNS series is not a minimum: the '
        'computer logged the whole history', () async {
      await seedDive('known', knownStart, 30);
      await seedDive(
        'current',
        currentStart,
        10,
        samples: const [
          ProfileSample(timestamp: 0, depth: 0, cns: 30),
          ProfileSample(timestamp: 300, depth: 3),
          ProfileSample(timestamp: 600, depth: 0, cns: 31),
        ],
      );
      await seedDive('manual', middleStart, 10);

      final exposure = await currentExposure(
        containerFor(cnsSource: MetricDataSource.computer),
      );

      expect(exposure.cnsStart, 30);
      expect(exposure.cnsIsMinimum, isFalse);
    });

    test('a previous computer reading ends the walk unmarked', () async {
      await seedDive(
        'known',
        middleStart,
        30,
        samples: const [
          ProfileSample(timestamp: 0, depth: 0, cns: 10),
          ProfileSample(timestamp: 900, depth: 20),
          ProfileSample(timestamp: 1800, depth: 0, cns: 60),
        ],
      );
      await seedDive('manual', knownStart, 10);
      await seedDive(
        'current',
        DateTime.utc(2026, 10, 31, 11, 30),
        10,
        samples: shallowAir,
      );

      final exposure = await currentExposure(
        containerFor(cnsSource: MetricDataSource.computer),
      );

      expect(
        exposure.cnsStart,
        closeTo(CnsTable.cnsAfterSurfaceInterval(60, 60), 0.001),
      );
      expect(exposure.cnsIsMinimum, isFalse);
    });

    test('a lookback that fails starts at zero, marked as a minimum', () async {
      await seedKnownAndCurrent();

      final exposure = await currentExposure(
        containerFor(
          overrides: [
            profileAnalysisProvider(
              'known',
            ).overrideWith((ref) async => throw StateError('analysis failed')),
          ],
        ),
      );

      expect(exposure.cnsStart, 0);
      expect(exposure.cnsIsMinimum, isTrue);
    });
  });

  group('residual tissue state', () {
    const deepAir = [
      ProfileSample(timestamp: 0, depth: 0),
      ProfileSample(timestamp: 120, depth: 30),
      ProfileSample(timestamp: 1500, depth: 30),
      ProfileSample(timestamp: 1800, depth: 0),
    ];

    /// The known dive's end-of-dive tissues after [surfaceMinutes] at the
    /// surface, breathing air.
    Future<List<double>> offGassed(
      ProviderContainer container,
      int surfaceMinutes,
    ) async {
      final analysis = await container.read(
        profileAnalysisProvider('known').future,
      );
      final algorithm = BuhlmannAlgorithm()
        ..setCompartments(List.of(analysis!.decoStatuses.last.compartments))
        ..calculateSegment(
          depthMeters: 0,
          durationSeconds: surfaceMinutes * 60,
          fN2: airN2Fraction,
          fHe: 0.0,
        );
      return [for (final c in algorithm.compartments) c.currentPN2];
    }

    Future<void> seedDeepKnownAndCurrent() async {
      await seedDive('known', knownStart, 30, samples: deepAir);
      await seedDive('current', currentStart, 10, samples: shallowAir);
    }

    Future<void> expectTissuesOffGassedFor(
      int surfaceMinutes,
      ProviderContainer container,
    ) async {
      final residual = await container.read(
        residualTissueStateProvider('current').future,
      );
      final expected = await offGassed(container, surfaceMinutes);
      expect(residual, isNotNull);
      expect(
        [for (final c in residual!) c.currentPN2],
        pairwiseCompare<double, double>(
          expected,
          (actual, value) => (actual - value).abs() < 1e-6,
          'within 1e-6 of',
        ),
      );
    }

    test('with no dive in between off-gasses over the whole gap', () async {
      await seedDeepKnownAndCurrent();

      await expectTissuesOffGassedFor(60, containerFor());
    });

    test('carries past a dive with no profile', () async {
      await seedDeepKnownAndCurrent();
      await seedDive('manual', middleStart, 10);

      await expectTissuesOffGassedFor(50, containerFor());
    });

    test('carries past a gauge dive', () async {
      await seedDeepKnownAndCurrent();
      await seedDive(
        'gauge',
        middleStart,
        10,
        samples: shallowAir,
        diveMode: 'gauge',
      );

      await expectTissuesOffGassedFor(50, containerFor());
    });

    test('the 48h window counts the surface time on both sides of an unknown '
        'dive', () async {
      await seedDive(
        'known',
        DateTime.utc(2026, 10, 29, 9),
        30,
        samples: deepAir,
      );
      await seedDive('current', currentStart, 10, samples: shallowAir);
      await seedDive('manual', DateTime.utc(2026, 10, 30, 9), 10);

      final residual = await containerFor().read(
        residualTissueStateProvider('current').future,
      );

      expect(residual, isNull);
    });
  });
}
