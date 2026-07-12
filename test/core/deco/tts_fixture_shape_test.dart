// test/core/deco/tts_fixture_shape_test.dart
//
// End-to-end shape tests over the committed SSRF fixtures. These pin the
// *shape* of the gas-aware calculated TTS curve (monotone, step-free across the
// recorded gas switch, 0 at the surface) on real recorded data.
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
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
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

List<DiveProfilePoint> _profilePoints(Map<String, dynamic> dive) =>
    (dive['profile'] as List)
        .map(
          (p) => DiveProfilePoint(
            timestamp: (p as Map)['timestamp'] as int,
            depth: p['depth'] as double,
            setpoint: p['setpoint'] as double?,
            ppO2: p['ppO2'] as double?,
          ),
        )
        .toList();

/// Diluent mix straight from the fixture's TankRole.diluent cylinder.
GasMix _diluentMix(Map<String, dynamic> dive) =>
    ((dive['tanks'] as List).cast<Map>().firstWhere(
          (t) => t['role'] == TankRole.diluent,
        ))['gasMix']
        as GasMix;

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

  group('CCR fixtures compute loop deco (issue #455)', () {
    test(
      'fixture 003 @ minute 40 matches Subsurface TTS (24 min +/- 2)',
      () async {
        final dive = await _parseFixture(
          '003_ccr_with_setpoint_switch_and_calculated_po2.ssrf.xml',
        );
        final depths = _depths(dive);
        final timestamps = _timestamps(dive);
        final points = _profilePoints(dive);

        final resolved = resolveRebreatherPpO2(points);
        expect(resolved, isNotNull, reason: 'fixture carries po2 samples');

        final segments = buildCcrProfileGasSegments(
          timestamps: timestamps,
          loopPpO2Curve: resolved!.curve,
          diluentMix: _diluentMix(dive),
        );
        expect(segments, isNotNull);
        expect(segments!.first.setpoint, isNotNull);

        // Issue #455 reference point: GF 45/75, minute 40 (44.1 m, loop ppO2
        // ~1.26 bar). App used to show ~17 min (OC EAN40 model); Subsurface
        // shows 24 min.
        final service = ProfileAnalysisService(gfLow: 0.45, gfHigh: 0.75);
        final analysis = service.analyze(
          diveId: 'fixture-003',
          depths: depths,
          timestamps: timestamps,
          diveMode: DiveMode.ccr,
          gasSegments: segments,
          rebreatherPpO2Curve: resolved.curve,
        );

        var idx = timestamps.indexOf(2400);
        if (idx < 0) {
          // Nearest sample to minute 40 if 2400 s is not an exact sample.
          idx = timestamps.indexWhere((t) => t >= 2400);
        }
        expect(
          idx,
          isNonNegative,
          reason: 'fixture 003 must span past minute 40 (2400 s)',
        );
        final ttsMinutes = analysis.ttsCurve![idx] / 60.0;
        expect(ttsMinutes, closeTo(24.0, 2.0));
      },
    );

    test('fixture 002 (setpoint samples only) builds setpoint segments and '
        'surfaces with TTS 0', () async {
      final dive = await _parseFixture(
        '002_ccr_only_low_sp_no_calculated_po2.ssrf.xml',
      );
      final timestamps = _timestamps(dive);
      final points = _profilePoints(dive);

      final resolved = resolveRebreatherPpO2(points);
      expect(
        resolved,
        isNotNull,
        reason: 'setpoint samples drive the fallback',
      );

      final segments = buildCcrProfileGasSegments(
        timestamps: timestamps,
        loopPpO2Curve: resolved!.curve,
        diluentMix: _diluentMix(dive),
      );
      expect(segments!.every((s) => s.setpoint != null), isTrue);

      final service = ProfileAnalysisService(gfLow: 0.45, gfHigh: 0.75);
      final analysis = service.analyze(
        diveId: 'fixture-002',
        depths: _depths(dive),
        timestamps: timestamps,
        diveMode: DiveMode.ccr,
        gasSegments: segments,
        rebreatherPpO2Curve: resolved.curve,
      );
      expect(analysis.ttsCurve!.last, 0);
    });
  });
}
