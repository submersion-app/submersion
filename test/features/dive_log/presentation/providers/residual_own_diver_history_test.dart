import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

class _FixedSettings extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FixedSettings() : super(const AppSettings());

  @override
  Future<void> get settingsLoaded async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Oxygen and tissue history belongs to one body: a dive's residual CNS,
/// tissue loading and OTU totals read its own diver's dives only, whoever
/// else logged in the same hour (#3923).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shallowAir = [
    ProfileSample(timestamp: 0, depth: 0),
    ProfileSample(timestamp: 60, depth: 3),
    ProfileSample(timestamp: 540, depth: 3),
    ProfileSample(timestamp: 600, depth: 0),
  ];
  const deepAir = [
    ProfileSample(timestamp: 0, depth: 0),
    ProfileSample(timestamp: 120, depth: 30),
    ProfileSample(timestamp: 1500, depth: 30),
    ProfileSample(timestamp: 1800, depth: 0),
  ];

  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    final now = DateTime.utc(2026).millisecondsSinceEpoch;
    for (final diver in ['alice', 'bob']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: Value(diver),
              name: Value(diver),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> seedDive(
    String id,
    String? diverId,
    DateTime start,
    int minutes, {
    List<ProfileSample>? samples,
  }) async {
    final startMs = start.millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diverId: Value(diverId),
            diveDateTime: Value(startMs),
            entryTime: Value(startMs),
            exitTime: Value(startMs + minutes * 60000),
            runtime: Value(minutes * 60),
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

  ProviderContainer containerFor([List<Override> overrides = const []]) {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => _FixedSettings()),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Override exposure(String diveId, O2Exposure exposure) =>
      profileAnalysisProvider(diveId).overrideWith(
        (ref) async => ProfileAnalysis.empty().copyWith(o2Exposure: exposure),
      );

  group('OTU totals', () {
    Future<void> seedSharedDay() async {
      await seedDive('alice-prior', 'alice', DateTime.utc(2026, 10, 30, 9), 60);
      await seedDive('bob-prior', 'bob', DateTime.utc(2026, 10, 30, 11), 30);
      await seedDive(
        'alice-current',
        'alice',
        DateTime.utc(2026, 10, 30, 12),
        10,
      );
    }

    List<Override> sharedDayExposures() => [
      exposure('alice-prior', const O2Exposure(otu: 10)),
      exposure('bob-prior', const O2Exposure(otu: 200)),
      exposure('alice-current', const O2Exposure(otu: 1)),
    ];

    test('residual OTU leaves out another diver\'s dive that day', () async {
      await seedSharedDay();

      final prior = await containerFor(
        sharedDayExposures(),
      ).read(residualOtuProvider('alice-current').future);

      expect(prior, 10);
    });

    test('weekly OTU leaves out another diver\'s dive that week', () async {
      await seedSharedDay();

      final weekly = await containerFor(
        sharedDayExposures(),
      ).read(weeklyOtuProvider('alice-current').future);

      expect(weekly, 11);
    });

    test('the other diver keeps their own totals', () async {
      await seedSharedDay();
      final container = containerFor(sharedDayExposures());

      expect(await container.read(residualOtuProvider('bob-prior').future), 0);
      expect(await container.read(weeklyOtuProvider('bob-prior').future), 200);
    });

    test('unassigned dives stay one diver\'s history in an all-NULL library, '
        'and never mix with an assigned diver\'s', () async {
      await seedDive('solo-prior', null, DateTime.utc(2026, 10, 30, 9), 60);
      await seedDive('bob-prior', 'bob', DateTime.utc(2026, 10, 30, 11), 30);
      await seedDive('solo-current', null, DateTime.utc(2026, 10, 30, 12), 10);

      final container = containerFor([
        exposure('solo-prior', const O2Exposure(otu: 10)),
        exposure('bob-prior', const O2Exposure(otu: 200)),
        exposure('solo-current', const O2Exposure(otu: 1)),
      ]);

      expect(
        await container.read(residualOtuProvider('solo-current').future),
        10,
      );
      expect(
        await container.read(weeklyOtuProvider('solo-current').future),
        11,
      );
    });
  });

  // Alice's known dive ends at 09:30 and her current one starts at 10:30;
  // whatever Bob logged at 10:00 must not move either end of that hour.
  final aliceKnownStart = DateTime.utc(2026, 10, 31, 9);
  final bobStart = DateTime.utc(2026, 10, 31, 10);
  final aliceCurrentStart = DateTime.utc(2026, 10, 31, 10, 30);

  Future<O2Exposure> aliceExposure(ProviderContainer container) async {
    final analysis = await container.read(
      profileAnalysisProvider('alice-current').future,
    );
    expect(analysis, isNotNull);
    return analysis!.o2Exposure;
  }

  group('residual CNS', () {
    test('decays from the diver\'s own dive, past another diver\'s', () async {
      await seedDive('alice-known', 'alice', aliceKnownStart, 30);
      await seedDive('bob-between', 'bob', bobStart, 10);
      await seedDive(
        'alice-current',
        'alice',
        aliceCurrentStart,
        10,
        samples: shallowAir,
      );

      final result = await aliceExposure(
        containerFor([
          exposure('alice-known', const O2Exposure(cnsEnd: 40)),
          exposure('bob-between', const O2Exposure(cnsEnd: 100)),
        ]),
      );

      expect(
        result.cnsStart,
        closeTo(CnsTable.cnsAfterSurfaceInterval(40, 60), 0.001),
      );
      expect(result.cnsIsMinimum, isFalse);
    });

    test('another diver\'s dive with no profile leaves no unknown mark: the '
        'diver knows everything they dived', () async {
      await seedDive('alice-known', 'alice', aliceKnownStart, 30);
      await seedDive('bob-manual', 'bob', bobStart, 10);
      await seedDive(
        'alice-current',
        'alice',
        aliceCurrentStart,
        10,
        samples: shallowAir,
      );

      final result = await aliceExposure(
        containerFor([exposure('alice-known', const O2Exposure(cnsEnd: 40))]),
      );

      expect(
        result.cnsStart,
        closeTo(CnsTable.cnsAfterSurfaceInterval(40, 60), 0.001),
      );
      expect(result.cnsIsMinimum, isFalse);
    });

    test('starts at zero when only another diver dived before', () async {
      await seedDive('bob-before', 'bob', bobStart, 10);
      await seedDive(
        'alice-current',
        'alice',
        aliceCurrentStart,
        10,
        samples: shallowAir,
      );

      final result = await aliceExposure(
        containerFor([exposure('bob-before', const O2Exposure(cnsEnd: 100))]),
      );

      expect(result.cnsStart, 0);
      expect(result.cnsIsMinimum, isFalse);
    });
  });

  // Both are keep-alive and Compare reads them beside residualCnsProvider,
  // which refreshes through the analysis: all three must move together.
  group('after an earlier dive is added', () {
    Future<void> settle() => Future<void>.delayed(
      DiveRepository.changeTickDebounce + const Duration(milliseconds: 150),
    );

    test('residual OTU counts it', () async {
      await seedDive(
        'alice-current',
        'alice',
        DateTime.utc(2026, 10, 30, 12),
        10,
      );
      final container = containerFor([
        exposure('alice-earlier', const O2Exposure(otu: 10)),
      ]);
      container.listen(residualOtuProvider('alice-current'), (_, _) {});
      expect(
        await container.read(residualOtuProvider('alice-current').future),
        0,
      );

      await seedDive(
        'alice-earlier',
        'alice',
        DateTime.utc(2026, 10, 30, 9),
        60,
      );
      await settle();

      expect(
        await container.read(residualOtuProvider('alice-current').future),
        10,
      );
    });

    test('residual tissue state starts from it', () async {
      await seedDive(
        'alice-current',
        'alice',
        aliceCurrentStart,
        10,
        samples: shallowAir,
      );
      final container = containerFor();
      container.listen(residualTissueStateProvider('alice-current'), (_, _) {});
      expect(
        await container.read(
          residualTissueStateProvider('alice-current').future,
        ),
        isNull,
      );

      await seedDive(
        'alice-earlier',
        'alice',
        aliceKnownStart,
        30,
        samples: deepAir,
      );
      await settle();

      expect(
        await container.read(
          residualTissueStateProvider('alice-current').future,
        ),
        isNotNull,
      );
    });
  });

  group('residual tissue state', () {
    test('is empty when only another diver dived before', () async {
      await seedDive('bob-deep', 'bob', bobStart, 30, samples: deepAir);
      await seedDive(
        'alice-current',
        'alice',
        DateTime.utc(2026, 10, 31, 11),
        10,
        samples: shallowAir,
      );

      final residual = await containerFor().read(
        residualTissueStateProvider('alice-current').future,
      );

      expect(residual, isNull);
    });

    test('off-gasses from the diver\'s own dive over their own surface time, '
        'past another diver\'s deeper one', () async {
      await seedDive(
        'alice-known',
        'alice',
        aliceKnownStart,
        30,
        samples: deepAir,
      );
      await seedDive(
        'alice-current',
        'alice',
        aliceCurrentStart,
        10,
        samples: shallowAir,
      );
      final expected = await containerFor().read(
        residualTissueStateProvider('alice-current').future,
      );

      await seedDive('bob-between', 'bob', bobStart, 15, samples: deepAir);
      final actual = await containerFor().read(
        residualTissueStateProvider('alice-current').future,
      );

      expect(actual, isNotNull);
      expect(
        [for (final c in actual!) c.currentPN2],
        pairwiseCompare<double, double>(
          [for (final c in expected!) c.currentPN2],
          (a, b) => (a - b).abs() < 1e-9,
          'within 1e-9 of',
        ),
      );
    });
  });
}
