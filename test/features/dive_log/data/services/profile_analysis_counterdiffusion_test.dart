import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/counterdiffusion_analysis.dart';
import 'package:submersion/features/gas_calculators/domain/icd_calculator.dart';

import '../../../../core/deco/gas_switch/gas_switch_test_profiles.dart';

/// Issue #4530: the profile analysis carries the counterdiffusion analysis
/// the chart and the safety review read.
void main() {
  final dive = sampleProfile(standardDecoDive);

  ProfileAnalysis analyze(List<ProfileGasSegment> segments) =>
      ProfileAnalysisService(gfLow: 0.3, gfHigh: 0.7).analyze(
        diveId: 'd1',
        depths: dive.depths,
        timestamps: dive.timestamps,
        gasSegments: segments,
        diveMode: DiveMode.oc,
      );

  test('a trimix dive switching to EAN50 carries a violation marker', () {
    final analysis = analyze([seg(0, 0.18, fHe: 0.45), seg(1910, 0.5)]);

    final counterdiffusion = analysis.counterdiffusion;
    expect(counterdiffusion.heliumPresent, isTrue);
    expect(counterdiffusion.switchMarkers.single.timestamp, 1910);
    expect(
      counterdiffusion.switchMarkers.single.severity,
      IcdSeverity.violation,
    );
    // Helium leaves 2.65 times faster than nitrogen enters on EAN50, so the
    // tissues off-gas net: opposing phases, no ICD band.
    expect(counterdiffusion.opposingRanges, isNotEmpty);
  });

  test('an air dive carries no counterdiffusion', () {
    final analysis = analyze([seg(0, 0.21), seg(1910, 0.5)]);

    expect(analysis.counterdiffusion, CounterdiffusionAnalysis.none);
  });

  test('a withheld rebreather analysis carries none', () {
    final analysis = ProfileAnalysisService(gfLow: 0.3, gfHigh: 0.7).analyze(
      diveId: 'd1',
      depths: dive.depths,
      timestamps: dive.timestamps,
      diveMode: DiveMode.ccr,
    );

    expect(analysis.tissueLoadingWithheld, isTrue);
    expect(analysis.counterdiffusion, CounterdiffusionAnalysis.none);
  });

  test('copyWith carries the field', () {
    const value = CounterdiffusionAnalysis(heliumPresent: true);
    final copy = ProfileAnalysis.empty().copyWith(counterdiffusion: value);

    expect(copy.counterdiffusion, value);
    expect(copy.copyWith().counterdiffusion, value);
    expect(
      ProfileAnalysis.empty().counterdiffusion,
      CounterdiffusionAnalysis.none,
    );
  });
}
