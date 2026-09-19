import 'package:submersion/features/universal_import/data/services/shearwater_db_reader.dart';

/// Aligns the GF99 series a Shearwater Cloud export stores in
/// `dive_log_records` onto the profile samples libdivecomputer decoded from
/// the same dive's raw bytes.
///
/// The two series come from different sources of the same log, so their
/// timestamps normally coincide but are not guaranteed to. Each sample takes
/// the GF99 point nearest in time, provided it lies within half the sample
/// interval; a sample with no point that close is left without `gf99`.
abstract final class ShearwaterGf99Aligner {
  /// Returns new sample maps, each carrying `'gf99'` (whole percent, `int`)
  /// when a series point lies close enough. The input maps are not mutated.
  static List<Map<String, dynamic>> apply(
    List<Map<String, dynamic>> samples,
    List<ShearwaterGf99Sample> series,
  ) {
    if (samples.isEmpty || series.isEmpty) return samples;

    final sorted = List<ShearwaterGf99Sample>.of(series)
      ..sort((a, b) => a.timeSeconds.compareTo(b.timeSeconds));
    final tolerance = _tolerance(samples, sorted);

    return samples.map((sample) {
      final time = sample['timestamp'];
      if (time is! num) return sample;
      final nearest = _nearest(sorted, time);
      if (nearest == null) return sample;
      if ((nearest.timeSeconds - time).abs() > tolerance) return sample;
      return <String, dynamic>{...sample, 'gf99': nearest.gf99};
    }).toList();
  }

  /// Half the typical spacing between profile samples; falls back to the
  /// series spacing when the profile has a single sample, and to an exact
  /// match when neither has two points.
  static double _tolerance(
    List<Map<String, dynamic>> samples,
    List<ShearwaterGf99Sample> sorted,
  ) {
    final sampleTimes =
        samples
            .map((s) => s['timestamp'])
            .whereType<num>()
            .map((t) => t.toDouble())
            .toList()
          ..sort();
    final interval =
        _medianInterval(sampleTimes) ??
        _medianInterval(sorted.map((p) => p.timeSeconds.toDouble()).toList());
    return interval == null ? 0 : interval / 2;
  }

  static double? _medianInterval(List<double> sortedTimes) {
    final deltas = <double>[];
    for (var i = 1; i < sortedTimes.length; i++) {
      final delta = sortedTimes[i] - sortedTimes[i - 1];
      if (delta > 0) deltas.add(delta);
    }
    if (deltas.isEmpty) return null;
    deltas.sort();
    return deltas[deltas.length ~/ 2];
  }

  /// Binary search for the series point nearest to [time].
  static ShearwaterGf99Sample? _nearest(
    List<ShearwaterGf99Sample> sorted,
    num time,
  ) {
    if (sorted.isEmpty) return null;
    var low = 0;
    var high = sorted.length - 1;
    while (low < high) {
      final mid = (low + high) ~/ 2;
      if (sorted[mid].timeSeconds < time) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    // `low` is the first point at or after `time`; the point before it is
    // the other candidate.
    final after = sorted[low];
    if (low == 0) return after;
    final before = sorted[low - 1];
    final beforeDistance = (time - before.timeSeconds).abs();
    final afterDistance = (after.timeSeconds - time).abs();
    return afterDistance < beforeDistance ? after : before;
  }
}
