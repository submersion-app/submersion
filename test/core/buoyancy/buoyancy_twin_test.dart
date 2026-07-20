import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/suit_compression.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';

void main() {
  final saltEnv = DiveEnvironment.forConditions(waterType: WaterType.salt);

  TwinTankInput al80({
    double? start,
    double? end,
    List<TwinPressureSample>? series,
  }) => TwinTankInput(
    id: 't1',
    label: 'AL80',
    presetName: 'al80',
    volumeL: 11.0, // pin volume so catalog empty buoyancy (1.7) is used
    workingPressureBar: 207,
    material: TankMaterial.aluminum,
    o2Percent: 21,
    hePercent: 0,
    startPressureBar: start,
    endPressureBar: end,
    pressureSeries: series,
  );

  List<TwinProfileSample> squareProfile() => const [
    TwinProfileSample(timestamp: 0, depthM: 0),
    TwinProfileSample(timestamp: 60, depthM: 30),
    TwinProfileSample(timestamp: 120, depthM: 30),
    TwinProfileSample(timestamp: 180, depthM: 0),
  ];

  TwinInput inputWith({
    required List<TwinProfileSample> profile,
    required List<TwinTankInput> tanks,
    TwinSuitInput suit = const TwinSuitInput(
      kind: TwinSuitKind.wetsuit,
      anchorKg: 3.0,
      source: TermSource.typeDefault,
    ),
    double leadKg = 6.0,
  }) => TwinInput(
    profile: profile,
    tanks: tanks,
    suit: suit,
    staticTerms: const [
      TwinStaticTerm(label: 'personal', kg: 5.0, source: TermSource.measured),
      TwinStaticTerm(label: 'water', kg: 0.0, source: TermSource.physics),
    ],
    leadKg: leadKg,
    droppableLeadKg: 4.0,
    environment: saltEnv,
  );

  group('twinTankKgAt (cylinder swing)', () {
    test('full AL80 sinks, near-empty AL80 floats (python vectors)', () {
      final tank = al80();
      // 1.7 - 11.0 * P * 0.0012201760763964412
      expect(twinTankKgAt(tank, 200.0), closeTo(-0.9843873680721706, 1e-9));
      expect(twinTankKgAt(tank, 50.0), closeTo(1.0289031579819574, 1e-9));
    });

    test('trimix is lighter, so swings less than air', () {
      final airSwing = twinTankKgAt(al80(), 200) - twinTankKgAt(al80(), 50);
      const tmx = TwinTankInput(
        id: 't1',
        label: 'AL80',
        presetName: 'al80',
        volumeL: 11.0,
        workingPressureBar: 207,
        material: TankMaterial.aluminum,
        o2Percent: 18,
        hePercent: 45,
      );
      final tmxSwing = twinTankKgAt(tmx, 200) - twinTankKgAt(tmx, 50);
      expect(tmxSwing.abs(), lessThan(airSwing.abs()));
    });
  });

  group('twinTankPressureAt', () {
    test('measured series interpolates linearly, ignoring profile bounds', () {
      final tank = al80(
        series: const [
          TwinPressureSample(timestamp: 0, pressureBar: 200),
          TwinPressureSample(timestamp: 600, pressureBar: 100),
        ],
      );
      expect(twinTankPressureAt(tank, 300, 0, 9999), closeTo(150.0, 1e-9));
      expect(twinTankPressureAt(tank, -10, 0, 9999), closeTo(200.0, 1e-9));
      expect(twinTankPressureAt(tank, 10000, 0, 9999), closeTo(100.0, 1e-9));
    });

    test('interpolated start/end uses time fraction', () {
      final tank = al80(start: 200, end: 50);
      expect(twinTankPressureAt(tank, 0, 0, 180), closeTo(200.0, 1e-9));
      expect(twinTankPressureAt(tank, 180, 0, 180), closeTo(50.0, 1e-9));
      expect(twinTankPressureAt(tank, 90, 0, 180), closeTo(125.0, 1e-9));
    });

    test('no pressures falls back to the reserve convention (50 bar)', () {
      final tank = al80();
      expect(twinTankPressureAt(tank, 90, 0, 180), closeTo(50.0, 1e-9));
    });
  });

  group('runBuoyancyTwin', () {
    test('net at a mid-dive sample is the composed sum of terms', () {
      final input = inputWith(
        profile: squareProfile(),
        tanks: [al80(start: 200, end: 50)],
      );
      final result = runBuoyancyTwin(input);
      final sample = result.samples.firstWhere((s) => s.timestamp == 60);

      final surface = SuitCompression.surfaceFromAnchor(
        anchorKg: 3.0,
        anchorPressureBar: saltEnv.pressureAtDepth(5.0),
        surfacePressureBar: saltEnv.surfacePressureBar,
      );
      final expectedSuit = SuitCompression.buoyancyAtPressure(
        surfaceKg: surface,
        pressureBar: saltEnv.pressureAtDepth(30.0),
        surfacePressureBar: saltEnv.surfacePressureBar,
      );
      // t=60 of 0..180 -> 200 + (50-200)*(60/180) = 150 bar
      final expectedTank = twinTankKgAt(al80(start: 200, end: 50), 150.0);
      final expectedNet = expectedSuit + expectedTank + 5.0 - 6.0;

      expect(sample.netKg, closeTo(expectedNet, 1e-9));
      expect(sample.suitKg, closeTo(expectedSuit, 1e-9));
      expect(sample.tanksKg, closeTo(expectedTank, 1e-9));
    });

    test('measured series => pressuresEstimated is false', () {
      final input = inputWith(
        profile: squareProfile(),
        tanks: [
          al80(
            series: const [
              TwinPressureSample(timestamp: 0, pressureBar: 200),
              TwinPressureSample(timestamp: 180, pressureBar: 60),
            ],
          ),
        ],
      );
      expect(runBuoyancyTwin(input).pressuresEstimated, isFalse);
    });

    test('missing pressures => pressuresEstimated is true', () {
      final input = inputWith(profile: squareProfile(), tanks: [al80()]);
      expect(runBuoyancyTwin(input).pressuresEstimated, isTrue);
    });

    test('wetsuit term at a 5 m sample round-trips to the anchor', () {
      final input = inputWith(
        profile: const [
          TwinProfileSample(timestamp: 0, depthM: 0),
          TwinProfileSample(timestamp: 60, depthM: 5),
        ],
        tanks: [al80(start: 200, end: 50)],
      );
      final result = runBuoyancyTwin(input);
      final at5 = result.samples.firstWhere((s) => s.depthM == 5);
      expect(at5.suitKg, closeTo(3.0, 1e-9));
    });

    test(
      'drysuit: constant suit term and a positive gas budget on descent',
      () {
        final input = inputWith(
          profile: squareProfile(),
          tanks: [al80(start: 200, end: 50)],
          suit: const TwinSuitInput(
            kind: TwinSuitKind.drysuit,
            anchorKg: 4.0,
            source: TermSource.typeDefault,
          ),
        );
        final result = runBuoyancyTwin(input);
        expect(
          result.samples.every((s) => (s.suitKg - 4.0).abs() < 1e-9),
          isTrue,
        );
        expect(result.drysuitGasLiters, greaterThan(0));
      },
    );

    test('empty profile yields no samples', () {
      final input = inputWith(
        profile: const [],
        tanks: [al80(start: 200, end: 50)],
      );
      expect(runBuoyancyTwin(input).samples, isEmpty);
    });
  });

  group('smoothDepths', () {
    test('damps a single-sample depth spike', () {
      final profile = [
        for (var t = 0; t <= 120; t += 10)
          TwinProfileSample(timestamp: t, depthM: t == 60 ? 20.0 : 10.0),
      ];
      final smoothed = smoothDepths(profile, windowSeconds: 30);
      final idx = profile.indexWhere((s) => s.timestamp == 60);
      // Window [45,75] -> depths {10,20,10} -> ~13.3, far from the raw 20.
      expect(smoothed[idx], closeTo(13.333, 0.1));
    });

    test('preserves a sustained depth change', () {
      final profile = [
        for (var t = 0; t <= 60; t += 10)
          TwinProfileSample(timestamp: t, depthM: 10),
        for (var t = 70; t <= 130; t += 10)
          TwinProfileSample(timestamp: t, depthM: 30),
      ];
      final smoothed = smoothDepths(profile, windowSeconds: 30);
      final idx = profile.indexWhere((s) => s.timestamp == 120);
      expect(smoothed[idx], closeTo(30, 0.01));
    });

    test('empty profile yields empty output', () {
      expect(smoothDepths(const []), isEmpty);
    });
  });

  test('wetsuit curve is smoothed across a depth spike', () {
    final profile = [
      for (var t = 0; t <= 120; t += 10)
        TwinProfileSample(timestamp: t, depthM: t == 60 ? 20.0 : 10.0),
    ];
    final input = inputWith(
      profile: profile,
      tanks: [al80(start: 200, end: 50)],
    );
    final result = runBuoyancyTwin(input);
    final spike = result.samples.firstWhere((s) => s.timestamp == 60);
    final neighbor = result.samples.firstWhere((s) => s.timestamp == 40);
    final rawSpike = SuitCompression.buoyancyAtPressure(
      surfaceKg: result.suitSurfaceKg,
      pressureBar: saltEnv.pressureAtDepth(20),
      surfacePressureBar: saltEnv.surfacePressureBar,
    );
    // The spike sample's suit term sits near its neighbours, not at the raw
    // 20 m spike response.
    expect(
      (spike.suitKg - neighbor.suitKg).abs(),
      lessThan((spike.suitKg - rawSpike).abs()),
    );
    // The sample still reports its true depth.
    expect(spike.depthM, 20.0);
  });
}
