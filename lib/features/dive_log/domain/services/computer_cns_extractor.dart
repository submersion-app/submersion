import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Result of extracting CNS start/end from dive computer samples.
typedef ComputerCnsResult = ({double cnsStart, double cnsEnd});

/// The fewest CNS readings that make a computer CNS series.
///
/// A single one is not a series: the OSTC reports one CNS value from its
/// header on the first sample even when it logs no CNS during the dive, and
/// that value says nothing about the rest of the dive (#2545).
const int _minCnsReadings = 2;

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
  if (readings < _minCnsReadings) return null;
  return (cnsStart: first!, cnsEnd: last!);
}

/// Whether the profile contains a computer-reported CNS series: at least
/// [_minCnsReadings] samples with a CNS reading.
bool hasComputerCns(List<DiveProfilePoint> profile) {
  var readings = 0;
  for (final point in profile) {
    if (point.cns != null && ++readings >= _minCnsReadings) return true;
  }
  return false;
}
