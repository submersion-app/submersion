import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/entities/gradient_factor_source.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// An analysis must never invent a gradient factor pair it did not run with.
///
/// Review of #1047 flagged that `ProfileAnalysis` carried a hardcoded default
/// source. Any default is a claim about the diver's settings that nothing
/// verified -- and `ProfileAnalysis.empty().copyWith(decoStatuses: ...)` does
/// reach the deco card (see dive_detail_page_test.dart), so that claim could
/// be displayed. Unattributed is a state, not a number.
void main() {
  group('ProfileAnalysis.gfSource attribution', () {
    test('is absent on an analysis that computed nothing', () {
      expect(ProfileAnalysis.empty().gfSource, isNull);
    });

    test('is absent rather than fabricated on a bare const construction', () {
      // The const constructor has many required fields; a defaulted gfSource
      // would silently attribute every such object to the diver's settings.
      final analysis = ProfileAnalysis.empty().copyWith(maxDepth: 30);

      expect(analysis.gfSource, isNull);
    });

    test('reports the settings origin for a service configured with plain '
        'gradient factors', () {
      // A caller passing only gfLow/gfHigh is by construction configuring the
      // service from the diver's settings.
      final analysis = ProfileAnalysisService(gfLow: 0.45, gfHigh: 0.8).analyze(
        diveId: 'd1',
        depths: const [0, 10, 20, 20, 10, 0],
        timestamps: const [0, 60, 120, 180, 240, 300],
      );

      expect(analysis.gfSource, isNotNull);
      expect(analysis.gfSource!.low, 45);
      expect(analysis.gfSource!.high, 80);
      expect(analysis.gfSource!.origin, GfOrigin.diverSettings);
    });

    test('reports the computer origin when given a resolved source', () {
      final source = GradientFactorSource.resolve(
        diveGfLow: 45,
        diveGfHigh: 80,
        settingsGfLow: 50,
        settingsGfHigh: 85,
      );
      final analysis = ProfileAnalysisService(gfSource: source).analyze(
        diveId: 'd1',
        depths: const [0, 10, 20, 20, 10, 0],
        timestamps: const [0, 60, 120, 180, 240, 300],
      );

      expect(analysis.gfSource, source);
      // And the engine actually ran on that pair.
      expect(analysis.decoStatuses.first.gfLow, closeTo(0.45, 1e-9));
    });

    test('stamps the source even when the profile is unusable', () {
      // The empty-profile early return is still an answer from a configured
      // service, so it can say what it would have used.
      final source = GradientFactorSource.resolve(
        diveGfLow: 45,
        diveGfHigh: 80,
        settingsGfLow: 50,
        settingsGfHigh: 85,
      );
      final analysis = ProfileAnalysisService(
        gfSource: source,
      ).analyze(diveId: 'd1', depths: const [], timestamps: const []);

      expect(analysis.gfSource, source);
    });
  });
}
