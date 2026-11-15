import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The net buoyancy (kg) for each sample of [drawn], the series the profile
/// chart draws (issue #4593).
///
/// The model emits one sample per input point with that point's timestamp,
/// so the two line up one to one when the model ran on the drawn series.
/// Matching by timestamp rather than index means any mismatch between the
/// modelled and drawn samples shows as a gap, never as a value shifted onto
/// the wrong moment.
List<double?> alignBuoyancyCurve(
  List<DiveProfilePoint> drawn,
  List<TwinSample> samples,
) {
  final byTimestamp = {for (final s in samples) s.timestamp: s.netKg};
  return [for (final p in drawn) byTimestamp[p.timestamp]];
}
