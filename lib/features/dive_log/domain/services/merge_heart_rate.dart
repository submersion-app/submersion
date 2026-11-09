import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// [points] with heart rate from an Apple Health record's [samples]
/// (`[epochSeconds, bpm]`, true instants, in time order) where the profile
/// has none of its own (issue #637). [entryEpochSeconds] is the dive's entry
/// as a true instant: each sample sits at its own time less the entry, so
/// the line stays put when a download or a merge moves the dive's start.
///
/// Returns [points] itself when any point already has heart rate, so the
/// dive computer's own reading is never replaced, or when there are no
/// samples. Otherwise each point takes the nearest sample within
/// [maxGapSeconds], marked as from the Apple Watch.
List<DiveProfilePoint> mergeHeartRate(
  List<DiveProfilePoint> points,
  List<List<int>> samples, {
  required int entryEpochSeconds,
  int maxGapSeconds = 30,
}) {
  if (samples.isEmpty || points.any((p) => p.heartRate != null)) {
    return points;
  }
  final key = (samples, entryEpochSeconds, maxGapSeconds);
  final hit = _merged[points];
  if (hit != null &&
      identical(hit.$1.$1, samples) &&
      hit.$1.$2 == entryEpochSeconds &&
      hit.$1.$3 == maxGapSeconds) {
    return hit.$2;
  }
  final merged = _merge(points, samples, entryEpochSeconds, maxGapSeconds);
  _merged[points] = (key, merged);
  return merged;
}

/// The last merge of each profile list, so a chart that rebuilds during
/// playback draws the same list rather than merging thousands of points
/// again. Held weakly: it goes with the profile.
final _merged = Expando<((List<List<int>>, int, int), List<DiveProfilePoint>)>(
  'mergeHeartRate',
);

List<DiveProfilePoint> _merge(
  List<DiveProfilePoint> points,
  List<List<int>> samples,
  int entryEpochSeconds,
  int maxGapSeconds,
) {
  int at(int i) => samples[i][0] - entryEpochSeconds;
  var next = 0;
  return [
    for (final p in points)
      () {
        // Both run in time order, so the nearest sample only moves forward.
        while (next + 1 < samples.length &&
            (at(next + 1) - p.timestamp).abs() <=
                (at(next) - p.timestamp).abs()) {
          next++;
        }
        if ((at(next) - p.timestamp).abs() > maxGapSeconds) return p;
        return p.copyWith(
          heartRate: samples[next][1],
          heartRateSource: 'appleWatch',
        );
      }(),
  ];
}
