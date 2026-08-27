// Regression test for the dive-mode half of #845 (raised as #846).
//
// A Shearwater CCR export imported as open circuit is not a cosmetic
// mislabel: the loop is never modeled, so the long shallow stops keep
// loading nitrogen at ~1 bar instead of the near-zero inspired inert a
// constant-ppO2 loop actually delivers. That turned this dive into a
// decompression violation that never happened -- our surface GF read 131
// against the 59 the Petrel 3 logged in the same file.
//
// The gas is not the issue: the dive was run on air diluent throughout, and
// modeling the loop with that same air reproduces the computer. This test
// pins both halves, so an OC fallback cannot silently return.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

const _fixture = 'test/dives/006_ccr_petrel3_shearwater-cloud-export.uddf';

/// Gradient factor the Petrel 3 itself logged on its final sample.
const _computerSurfaceGf = 59.0;

void main() {
  group('Petrel 3 CCR loop decompression (#846)', () {
    late List<double> depths;
    late List<int> timestamps;
    late List<double> loopPpO2;
    late ProfileAnalysisService service;

    setUpAll(() async {
      final content = File(_fixture).readAsStringSync();
      final result = await UddfFullImportService().importAllDataFromUddf(
        content,
      );
      final profile =
          result.dives.first['profile'] as List<Map<String, dynamic>>;

      depths = profile.map((p) => p['depth'] as double).toList();
      timestamps = profile.map((p) => p['timestamp'] as int).toList();

      // The loop curve as the app resolves it: hold the last reading across
      // samples with no oxygen data.
      double? carry;
      loopPpO2 = [
        for (final point in profile)
          carry = (point['ppO2'] as double?) ?? carry ?? 0.0,
      ];

      // The gradient factors the computer recorded for this dive.
      service = ProfileAnalysisService(gfLow: 0.40, gfHigh: 0.70);
    });

    ProfileAnalysis analyzeAsCcr(GasMix diluent) {
      final segments = buildCcrProfileGasSegments(
        timestamps: timestamps,
        loopPpO2Curve: loopPpO2,
        diluentMix: diluent,
      );
      expect(segments, isNotNull, reason: 'loop ppO2 must yield gas segments');

      return service.analyze(
        diveId: 'ccr',
        depths: depths,
        timestamps: timestamps,
        o2Fraction: diluent.o2 / 100,
        heFraction: diluent.he / 100,
        diveMode: DiveMode.ccr,
        gasSegments: segments,
        rebreatherPpO2Curve: loopPpO2,
      );
    }

    test('surfacing GF matches the computer when the loop is modeled', () {
      final analysis = analyzeAsCcr(const GasMix(o2: 21, he: 0));
      final surfaceGf = analysis.surfaceGfCurve!.last;

      expect(
        surfaceGf,
        closeTo(_computerSurfaceGf, 15),
        reason:
            'the Petrel logged $_computerSurfaceGf on its last sample; a '
            'result far from that means the loop is not being modeled',
      );
    });

    test('surfaces clear of any decompression obligation', () {
      final analysis = analyzeAsCcr(const GasMix(o2: 21, he: 0));

      // The diver surfaced 70 seconds after their last logged stop cleared.
      expect(analysis.ceilingCurve.last, 0.0);
      expect(analysis.ttsCurve!.last, 0);
    });

    test('open circuit on the same gas invents a violation', () {
      // What the bug produced, pinned so the regression is unmistakable: the
      // identical air, breathed open circuit, more than doubles the surface
      // gradient and leaves the diver in deco at the surface.
      final asOpenCircuit = service.analyze(
        diveId: 'oc',
        depths: depths,
        timestamps: timestamps,
        o2Fraction: 0.21,
      );

      expect(asOpenCircuit.surfaceGfCurve!.last, greaterThan(120));
      expect(asOpenCircuit.ceilingCurve.last, greaterThan(0));
    });
  });
}
