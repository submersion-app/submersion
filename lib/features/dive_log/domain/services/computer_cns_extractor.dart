import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Result of extracting CNS start/end from dive computer samples.
typedef ComputerCnsResult = ({double cnsStart, double cnsEnd});

/// Extracts cnsStart and cnsEnd from computer-reported per-sample CNS data.
///
/// Scans the profile for the first and last non-null CNS values.
/// Returns null unless the profile holds a computer CNS series (see
/// [hasComputerCns]).
ComputerCnsResult? extractComputerCns(List<DiveProfilePoint> profile) {
  double? first;
  double? last;
  var readings = 0;
  for (final point in profile) {
    if (point.cns != null) {
      first ??= point.cns!;
      last = point.cns!;
      readings++;
    }
  }
  if (readings < 2) return null;
  return (cnsStart: first!, cnsEnd: last!);
}

/// Whether the profile contains a computer-reported CNS series.
///
/// That takes at least two readings. A single one is not a series: the OSTC
/// reports one CNS value from its header on the first sample even when it logs
/// no CNS during the dive, and that value says nothing about the rest of the
/// dive (#2545).
bool hasComputerCns(List<DiveProfilePoint> profile) {
  var readings = 0;
  for (final point in profile) {
    if (point.cns != null && ++readings >= 2) return true;
  }
  return false;
}
