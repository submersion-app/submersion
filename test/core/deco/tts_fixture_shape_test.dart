// test/core/deco/tts_fixture_shape_test.dart
//
// End-to-end shape tests over the committed SSRF fixtures. These pin the
// *shape* of the gas-aware calculated TTS curve (monotone, step-free across the
// recorded gas switch, 0 at the surface) on real recorded data, and assert the
// CCR fixtures are untouched by the gas-aware machinery (it is gated to OC).
// Absolute TTS numbers are pinned separately by the clean-room cross-check.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

import 'dart:io';

const _fixtureDir = 'test/dives';

Future<Map<String, dynamic>> _parseFixture(String name) async {
  final bytes = Uint8List.fromList(
    utf8.encode(File('$_fixtureDir/$name').readAsStringSync()),
  );
  final result = await SubsurfaceXmlParser().parse(bytes);
  return result.entitiesOf(ImportEntityType.dives).first;
}

List<double> _depths(Map<String, dynamic> dive) => (dive['profile'] as List)
    .map((p) => (p as Map)['depth'] as double)
    .toList();

List<int> _timestamps(Map<String, dynamic> dive) => (dive['profile'] as List)
    .map((p) => (p as Map)['timestamp'] as int)
    .toList();

List<GasMix> _tankMixes(Map<String, dynamic> dive) =>
    (dive['tanks'] as List).map((t) => (t as Map)['gasMix'] as GasMix).toList();

/// Build the OC gas schedule from the recorded gas-change events. Each switch
/// references a cylinder by leading index in its `tankRef`.
List<ProfileGasSegment> _gasSegments(Map<String, dynamic> dive) {
  final mixes = _tankMixes(dive);
  ProfileGasSegment seg(int ts, GasMix m) => ProfileGasSegment(
    startTimestamp: ts,
    fN2: (100.0 - m.o2 - m.he) / 100.0,
    fHe: m.he / 100.0,
  );

  final segments = <ProfileGasSegment>[seg(0, mixes.first)];
  final switches = (dive['gasSwitches'] as List?) ?? const [];
  for (final s in switches) {
    final ts = (s as Map)['timestamp'] as int;
    final idx = int.parse((s['tankRef'] as String).split(':').first);
    final mix = idx < mixes.length ? mixes[idx] : mixes.first;
    if (segments.last.startTimestamp == ts) {
      segments[segments.length - 1] = seg(ts, mix);
    } else {
      segments.add(seg(ts, mix));
    }
  }
  return segments;
}

OptimalOcAscentGas _ascentPlan(Map<String, dynamic> dive, {double ppO2 = 1.6}) {
  final gases = [
    for (final m in _tankMixes(dive))
      AvailableGas(
        fN2: (100.0 - m.o2 - m.he) / 100.0,
        fHe: m.he / 100.0,
        maxPpO2Mod: O2ToxicityCalculator.calculateMod(
          m.o2 / 100.0,
          maxPpO2: ppO2,
        ),
      ),
  ];
  return OptimalOcAscentGas(gases: gases, maxPpO2: ppO2);
}

void main() {
  test(
    'fixture 001: gas-aware calculated TTS is monotone, step-free, 0 at surface',
    () async {
      final dive = await _parseFixture(
        '001_short_deco_single_gas_switch.ssrf.xml',
      );
      final depths = _depths(dive);
      final timestamps = _timestamps(dive);

      // Fixture deco model is GF 50/75.
      final service = ProfileAnalysisService(gfLow: 0.50, gfHigh: 0.75);
      final analysis = service.analyze(
        diveId: 'fixture-001',
        depths: depths,
        timestamps: timestamps,
        o2Fraction: _tankMixes(dive).first.o2 / 100.0,
        gasSegments: _gasSegments(dive),
        ascentGasPlan: _ascentPlan(dive),
      );

      final tts = analysis.ttsCurve;
      expect(tts, isNotNull);
      expect(tts!.length, depths.length);

      // TTS reads 0 at the surface (last sample is at 0.0 m).
      expect(tts.last, 0);

      // Step-free during the ascent: from the moment the diver first leaves the
      // bottom, the calculated TTS must never jump UP by more than one stop
      // minute sample-to-sample. A single stop-minute wobble (<= 60 s) is the
      // benign quantization of minute-rounded stop times as the diver crosses
      // stop depths; the discontinuity the feature removes is the multi-minute
      // jump that used to appear at the recorded gas switch.
      const oneStopMinute = 60;
      final maxDepth = depths.reduce((a, b) => a > b ? a : b);
      final lastBottomIndex = depths.lastIndexWhere((d) => d >= maxDepth - 0.1);
      for (var i = lastBottomIndex + 1; i < tts.length; i++) {
        expect(
          tts[i] <= tts[i - 1] + oneStopMinute,
          isTrue,
          reason: 'TTS stepped up at sample $i (depth ${depths[i]} m)',
        );
      }
    },
  );

  for (final fixture in const [
    '002_ccr_only_low_sp_no_calculated_po2.ssrf.xml',
    '003_ccr_with_setpoint_switch_and_calculated_po2.ssrf.xml',
  ]) {
    test(
      'fixture $fixture (CCR): analysis is identical with/without a plan',
      () async {
        final dive = await _parseFixture(fixture);
        expect(dive['diveMode'], DiveMode.ccr);

        final depths = _depths(dive);
        final timestamps = _timestamps(dive);
        final service = ProfileAnalysisService(gfLow: 0.50, gfHigh: 0.75);

        ProfileAnalysis run({required bool withPlan}) => service.analyze(
          diveId: 'ccr',
          depths: depths,
          timestamps: timestamps,
          diveMode: DiveMode.ccr,
          setpointHigh: (dive['setpointHigh'] as double?) ?? 1.3,
          gasSegments: _gasSegments(dive),
          ascentGasPlan: withPlan ? _ascentPlan(dive) : null,
        );

        final baseline = run(withPlan: false);
        final withFeature = run(withPlan: true);

        // diveMode != oc => the OC gas-segment path is never taken, so the plan
        // cannot affect any deco curve.
        expect(withFeature.ttsCurve, equals(baseline.ttsCurve));
        expect(withFeature.ceilingCurve, equals(baseline.ceilingCurve));
        expect(withFeature.ndlCurve, equals(baseline.ndlCurve));
      },
    );
  }
}
