import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// [points] with heart rate from an Apple Health record's [offsets]
/// (`[offsetSeconds, bpm]` from the entry, in time order) where the profile
/// has none of its own (issue #637).
///
/// Returns [points] itself when any point already has heart rate, so the
/// dive computer's own reading is never replaced, or when there are no
/// offsets. Otherwise each point takes the nearest sample within
/// [maxGapSeconds], marked as from the Apple Watch.
List<DiveProfilePoint> mergeHeartRate(
  List<DiveProfilePoint> points,
  List<List<int>> offsets, {
  int maxGapSeconds = 30,
}) {
  if (offsets.isEmpty || points.any((p) => p.heartRate != null)) {
    return points;
  }
  final hit = _merged[points];
  if (hit != null && identical(hit.$1, offsets) && hit.$2 == maxGapSeconds) {
    return hit.$3;
  }
  final merged = _merge(points, offsets, maxGapSeconds);
  _merged[points] = (offsets, maxGapSeconds, merged);
  return merged;
}

/// The last merge of each profile list, so a chart that rebuilds during
/// playback draws the same list rather than merging thousands of points
/// again. Held weakly: it goes with the profile.
final _merged = Expando<(List<List<int>>, int, List<DiveProfilePoint>)>(
  'mergeHeartRate',
);

List<DiveProfilePoint> _merge(
  List<DiveProfilePoint> points,
  List<List<int>> offsets,
  int maxGapSeconds,
) {
  var next = 0;
  return [
    for (final p in points)
      () {
        // Both run in time order, so the nearest sample only moves forward.
        while (next + 1 < offsets.length &&
            (offsets[next + 1][0] - p.timestamp).abs() <=
                (offsets[next][0] - p.timestamp).abs()) {
          next++;
        }
        final nearest = offsets[next];
        if ((nearest[0] - p.timestamp).abs() > maxGapSeconds) return p;
        return p.copyWith(heartRate: nearest[1], heartRateSource: 'appleWatch');
      }(),
  ];
}
