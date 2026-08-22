import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// A dive's depth profile, thinned for printing.
///
/// Dive computers sample every few seconds, so an hour-long dive carries well
/// over a thousand points. A printed chart is a few inches wide and cannot
/// resolve anything close to that, and a large logbook would otherwise hold
/// every sample of every dive in memory at once. [downsampled] bounds both.
class PdfProfileSeries {
  /// Upper bound on the points handed to a chart.
  static const int maxPoints = 200;

  /// The thinned samples, in chronological order.
  final List<DiveProfilePoint> points;

  const PdfProfileSeries(this.points);

  /// Thin [raw] to at most [maxPoints] samples.
  ///
  /// Buckets the samples and keeps the deepest in each, rather than taking
  /// every Nth point. A plain stride can miss the deepest sample entirely,
  /// which would draw a chart that contradicts the dive's own max depth field.
  /// The first and last samples are always kept so the curve still starts and
  /// ends at the surface.
  factory PdfProfileSeries.downsampled(List<DiveProfilePoint> raw) {
    if (raw.length <= maxPoints) return PdfProfileSeries(List.of(raw));

    final kept = <DiveProfilePoint>[raw.first];
    // Interior buckets only: the first and last samples are added by hand, so
    // the budget for bucketed samples is maxPoints - 2.
    const buckets = maxPoints - 2;
    final interiorLength = raw.length - 2;

    for (var bucket = 0; bucket < buckets; bucket++) {
      final start = 1 + (interiorLength * bucket) ~/ buckets;
      final end = 1 + (interiorLength * (bucket + 1)) ~/ buckets;
      if (end <= start) continue;

      var deepest = raw[start];
      for (var i = start + 1; i < end; i++) {
        if (raw[i].depth > deepest.depth) deepest = raw[i];
      }
      kept.add(deepest);
    }

    kept.add(raw.last);
    return PdfProfileSeries(kept);
  }

  bool get isEmpty => points.isEmpty;

  bool get isNotEmpty => points.isNotEmpty;

  /// Deepest sample in meters, or 0 when the series carries no samples.
  double get maxDepth => points.isEmpty
      ? 0
      : points.map((p) => p.depth).reduce((a, b) => a > b ? a : b);

  /// Elapsed seconds between the first and last sample.
  int get durationSeconds =>
      points.isEmpty ? 0 : points.last.timestamp - points.first.timestamp;
}
