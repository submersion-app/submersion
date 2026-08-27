import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Calculate normalization factor to align profile-based SAC with tank-based SAC.
/// The segments are calculated from profile pressure data, but dive.sacPressure
/// uses tank start/end pressures - these can differ, so we normalize.
double calculateSacNormalizationFactor(Dive dive, ProfileAnalysis? analysis) {
  if (analysis?.sacSegments == null || analysis!.sacSegments!.isEmpty) {
    return 1.0;
  }

  final diveSacPressure = dive.sacPressure;
  if (diveSacPressure == null || diveSacPressure <= 0) {
    return 1.0;
  }

  // Calculate weighted average of segment SAC (weighted by duration)
  double totalWeightedSac = 0;
  int totalDuration = 0;
  for (final segment in analysis.sacSegments!) {
    totalWeightedSac += segment.sacRate * segment.durationSeconds;
    totalDuration += segment.durationSeconds;
  }

  if (totalDuration <= 0) return 1.0;

  final avgSegmentSac = totalWeightedSac / totalDuration;
  if (avgSegmentSac <= 0) return 1.0;

  return diveSacPressure / avgSegmentSac;
}
