import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';

void main() {
  final saltEnv = DiveEnvironment.forConditions(waterType: WaterType.salt);

  TwinTankInput tank({double? start, double? end}) => TwinTankInput(
    id: 't1',
    label: 'AL80',
    presetName: 'al80',
    volumeL: 11.0,
    workingPressureBar: 207,
    material: TankMaterial.aluminum,
    o2Percent: 21,
    startPressureBar: start,
    endPressureBar: end,
  );

  TwinInput input({
    required List<TwinProfileSample> profile,
    List<TwinTankInput>? tanks,
    double leadKg = 6.0,
    double droppableLeadKg = 4.0,
    TwinSuitInput suit = const TwinSuitInput(
      kind: TwinSuitKind.wetsuit,
      anchorKg: 3.0,
      source: TermSource.typeDefault,
    ),
    List<TwinStaticTerm> staticTerms = const [
      TwinStaticTerm(label: 'personal', kg: 5.0, source: TermSource.measured),
      TwinStaticTerm(label: 'water', kg: 0.0, source: TermSource.physics),
    ],
  }) => TwinInput(
    profile: profile,
    tanks: tanks ?? [tank(start: 200, end: 50)],
    suit: suit,
    staticTerms: staticTerms,
    leadKg: leadKg,
    droppableLeadKg: droppableLeadKg,
    environment: saltEnv,
  );

  // A 30 m dive that ends with a sustained 5 m stop (samples every 10 s).
  List<TwinProfileSample> profileWithStop() {
    final samples = <TwinProfileSample>[];
    var t = 0;
    samples.add(TwinProfileSample(timestamp: t, depthM: 0));
    for (t = 30; t <= 300; t += 30) {
      samples.add(TwinProfileSample(timestamp: t, depthM: 30));
    }
    // ascent
    samples.add(const TwinProfileSample(timestamp: 330, depthM: 15));
    // 5 m stop held for 180 s
    for (t = 360; t <= 540; t += 30) {
      samples.add(TwinProfileSample(timestamp: t, depthM: 5));
    }
    samples.add(const TwinProfileSample(timestamp: 570, depthM: 0));
    return samples;
  }

  group('anchor detection', () {
    test('finds the sustained shallow stop', () {
      final outputs = TwinAnalyzer.analyze(
        runBuoyancyTwin(input(profile: profileWithStop())),
      );
      expect(outputs.verdict.anchor.kind, TwinAnchorKind.detectedStop);
      expect(outputs.verdict.anchor.depthM, closeTo(5.0, 0.5));
    });

    test('falls back to a shallow window on a direct ascent', () {
      final direct = <TwinProfileSample>[
        const TwinProfileSample(timestamp: 0, depthM: 0),
        const TwinProfileSample(timestamp: 60, depthM: 30),
        const TwinProfileSample(timestamp: 120, depthM: 30),
        const TwinProfileSample(timestamp: 180, depthM: 8),
        const TwinProfileSample(timestamp: 200, depthM: 3),
        const TwinProfileSample(timestamp: 210, depthM: 0),
      ];
      final outputs = TwinAnalyzer.analyze(
        runBuoyancyTwin(input(profile: direct)),
      );
      expect(outputs.verdict.anchor.kind, TwinAnchorKind.shallowWindow);
    });

    test('empty profile uses the safety-stop convention', () {
      final outputs = TwinAnalyzer.analyze(
        runBuoyancyTwin(input(profile: const [])),
      );
      expect(outputs.verdict.anchor.kind, TwinAnchorKind.convention);
    });
  });

  group('verdict terms', () {
    test('sum to the verdict net and include a negative lead term', () {
      final outputs = TwinAnalyzer.analyze(
        runBuoyancyTwin(input(profile: profileWithStop())),
      );
      final termSum = outputs.verdict.terms.fold(0.0, (s, t) => s + t.kg);
      expect(termSum, closeTo(outputs.verdict.netKg, 1e-9));
      final lead = outputs.verdict.terms.firstWhere((t) => t.label == 'lead');
      expect(lead.kg, closeTo(-6.0, 1e-9));
    });
  });

  group('derived outputs', () {
    test('min ditchable uses the worst net plus the margin', () {
      // Craft a very-heavy rig: worst net about -4.5 kg.
      // lead 12 makes the whole dive strongly negative.
      final outputs = TwinAnalyzer.analyze(
        runBuoyancyTwin(input(profile: profileWithStop(), leadKg: 12.0)),
      );
      final worstNet = outputs.verdict.netKg; // not used directly here
      // minDitchable = max(0, margin - worstNet); with a negative worstNet
      // it exceeds the margin.
      expect(
        outputs.minDitchableKg,
        greaterThan(TwinAnalyzer.kDitchableMarginKg),
      );
      expect(worstNet, isNotNull);
    });

    test('min ditchable formula matches max(0, margin - worstNet)', () {
      final result = runBuoyancyTwin(input(profile: profileWithStop()));
      final outputs = TwinAnalyzer.analyze(result);
      final worst = result.samples
          .map((s) => s.netKg)
          .reduce((a, b) => a < b ? a : b);
      expect(
        outputs.minDitchableKg,
        closeTo(
          (TwinAnalyzer.kDitchableMarginKg - worst).clamp(0.0, double.infinity),
          1e-9,
        ),
      );
    });

    test('peak lift demand equals the negated worst net when heavy', () {
      final result = runBuoyancyTwin(
        input(profile: profileWithStop(), leadKg: 12.0),
      );
      final outputs = TwinAnalyzer.analyze(result);
      final worst = result.samples
          .map((s) => s.netKg)
          .reduce((a, b) => a < b ? a : b);
      expect(outputs.peakLiftDemandKg, closeTo(-worst, 1e-9));
    });

    test('ideal lead = carried lead + net at the anchor', () {
      final result = runBuoyancyTwin(input(profile: profileWithStop()));
      final outputs = TwinAnalyzer.analyze(result);
      expect(
        outputs.idealLeadKg,
        closeTo(
          (6.0 + outputs.verdict.netKg).clamp(0.0, double.infinity),
          1e-9,
        ),
      );
    });

    test('begin and end nets are taken from in-water samples', () {
      final result = runBuoyancyTwin(input(profile: profileWithStop()));
      final outputs = TwinAnalyzer.analyze(result);
      final inWater = result.samples.where((s) => s.depthM > 1.0).toList();
      expect(outputs.beginNetKg, closeTo(inWater.first.netKg, 1e-9));
      expect(outputs.endNetKg, closeTo(inWater.last.netKg, 1e-9));
    });
  });
}
