import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_buoyancy_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';

/// Which computer the profile's buoyancy line models (issue #4593): the
/// card's own result while the primary (or the only) series is drawn, the
/// drawn computer's samples and pressures otherwise.
void main() {
  const diveId = 'dive-1';
  final now = DateTime(2026, 5, 6);

  DiveDataSource source(String id, {required bool isPrimary}) => DiveDataSource(
    id: id,
    diveId: diveId,
    computerId: 'computer-$id',
    isPrimary: isPrimary,
    importedAt: now,
    createdAt: now,
  );

  final dive = Dive(
    id: diveId,
    diveNumber: 1,
    dateTime: now,
    tanks: const [
      DiveTank(
        id: 't1',
        volume: 11,
        workingPressure: 207,
        startPressure: 200,
        endPressure: 50,
        material: TankMaterial.aluminum,
        presetName: 'al80',
      ),
    ],
    waterType: WaterType.salt,
  );

  List<DiveProfilePoint> points(List<int> timestamps) => [
    for (final t in timestamps)
      DiveProfilePoint(timestamp: t, depth: t == timestamps.first ? 0 : 18),
  ];

  FittedWeightModel model() => WeightPredictionEngine.fit(
    observations: const [],
    gearById: (_) => null,
    bodyWeightKg: 75,
  );

  // A stand-in for the card's result, built from the primary series.
  BuoyancyTwinOutcome cardOutcome() {
    final input = BuoyancyTwinAssembler.assemble(
      dive: dive.copyWith(profile: points([0, 10, 20])),
      tankPressures: const {},
      model: model(),
      bodyWeightKg: null,
    )!;
    final result = runBuoyancyTwin(input);
    return BuoyancyTwinOutcome(
      result: result,
      outputs: TwinAnalyzer.analyze(result),
    );
  }

  ProviderContainer container({
    required SourceProfile? active,
    required List<DiveDataSource> sources,
    BuoyancyTwinOutcome? card,
  }) {
    final c = ProviderContainer(
      overrides: [
        activeSourceProfileProvider(diveId).overrideWithValue(active),
        diveDataSourcesProvider(diveId).overrideWith((ref) async => sources),
        diveProvider(diveId).overrideWith((ref) async => dive),
        activeSourceTankPressuresProvider(
          diveId,
        ).overrideWith((ref) async => const {}),
        buoyancyTwinProvider(diveId).overrideWith((ref) async => card),
        weightCalibrationProvider.overrideWith((ref) async => model()),
        latestDiverWeightProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('single source reuses the card result', () async {
    final card = cardOutcome();
    final c = container(active: null, sources: const [], card: card);
    final result = await c.read(chartBuoyancyTwinProvider(diveId).future);
    expect(identical(result, card.result), isTrue);
  });

  test(
    'primary source on a multi-source dive reuses the card result',
    () async {
      // The card models the primary rows, which are the series the chart draws
      // for the primary computer, so the dive page runs the model once.
      final primary = source('s1', isPrimary: true);
      final card = cardOutcome();
      final c = container(
        active: SourceProfile(
          sourceId: 's1',
          computerId: primary.computerId,
          isEdited: false,
          points: points([0, 10, 20]),
        ),
        sources: [primary, source('s2', isPrimary: false)],
        card: card,
      );
      final result = await c.read(chartBuoyancyTwinProvider(diveId).future);
      expect(identical(result, card.result), isTrue);
    },
  );

  test('secondary source models its own points', () async {
    final secondaryPoints = points([0, 7, 14, 21, 28]);
    final c = container(
      active: SourceProfile(
        sourceId: 's2',
        computerId: 'computer-s2',
        isEdited: false,
        points: secondaryPoints,
      ),
      sources: [source('s1', isPrimary: true), source('s2', isPrimary: false)],
      card: cardOutcome(),
    );
    final result = await c.read(chartBuoyancyTwinProvider(diveId).future);
    expect(result, isNotNull);
    expect([for (final s in result!.samples) s.timestamp], [0, 7, 14, 21, 28]);
  });

  test('secondary source without pressures still models', () async {
    final c = container(
      active: SourceProfile(
        sourceId: 's2',
        computerId: 'computer-s2',
        isEdited: false,
        points: points([0, 30, 60]),
      ),
      sources: [source('s1', isPrimary: true), source('s2', isPrimary: false)],
      card: cardOutcome(),
    );
    final result = await c.read(chartBuoyancyTwinProvider(diveId).future);
    expect(result, isNotNull);
    expect(result!.pressuresEstimated, isTrue);
    expect(result.samples, hasLength(3));
  });

  test('a secondary source still loading its samples models nothing', () async {
    // The empty placeholder drawn before the profiles arrive.
    final c = container(
      active: const SourceProfile(
        sourceId: 's2',
        computerId: 'computer-s2',
        isEdited: false,
        points: [],
      ),
      sources: [source('s1', isPrimary: true), source('s2', isPrimary: false)],
      card: cardOutcome(),
    );
    expect(await c.read(chartBuoyancyTwinProvider(diveId).future), isNull);
  });

  test('an unmodelable dive gives null on a secondary source', () async {
    final c = ProviderContainer(
      overrides: [
        activeSourceProfileProvider(diveId).overrideWithValue(
          SourceProfile(
            sourceId: 's2',
            computerId: 'computer-s2',
            isEdited: false,
            points: points([0, 10]),
          ),
        ),
        diveDataSourcesProvider(diveId).overrideWith(
          (ref) async => [
            source('s1', isPrimary: true),
            source('s2', isPrimary: false),
          ],
        ),
        diveProvider(
          diveId,
        ).overrideWith((ref) async => dive.copyWith(tanks: const [])),
        activeSourceTankPressuresProvider(
          diveId,
        ).overrideWith((ref) async => const {}),
        weightCalibrationProvider.overrideWith((ref) async => model()),
        latestDiverWeightProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(c.dispose);
    expect(await c.read(chartBuoyancyTwinProvider(diveId).future), isNull);
  });

  group('buoyancyModelableProvider', () {
    test('true with a tank, false with no tank and no suit', () async {
      final withTank = ProviderContainer(
        overrides: [diveProvider(diveId).overrideWith((ref) async => dive)],
      );
      addTearDown(withTank.dispose);
      expect(
        await withTank.read(buoyancyModelableProvider(diveId).future),
        isTrue,
      );

      final bare = ProviderContainer(
        overrides: [
          diveProvider(
            diveId,
          ).overrideWith((ref) async => dive.copyWith(tanks: const [])),
        ],
      );
      addTearDown(bare.dispose);
      expect(
        await bare.read(buoyancyModelableProvider(diveId).future),
        isFalse,
      );
    });

    test('false when the dive is missing', () async {
      final c = ProviderContainer(
        overrides: [diveProvider(diveId).overrideWith((ref) async => null)],
      );
      addTearDown(c.dispose);
      expect(await c.read(buoyancyModelableProvider(diveId).future), isFalse);
    });
  });
}
