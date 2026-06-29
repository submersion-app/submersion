/// Returns the ascending original indices to keep when rendering a dense dive
/// profile, preserving dive-critical features: the depth envelope (including the
/// max-depth spike), every ascent-rate band boundary, and every decoType
/// transition. Min/max-per-bucket on depth preserves the envelope; force-keeps
/// preserve safety-relevant transitions.
///
/// [bands] is the per-sample ascent-rate category index (parallel to [depths]);
/// pass `AscentRatePoint.category.index`. [decoTypes] is the per-sample
/// `DiveProfilePoint.decoType` (use -1 for null). Returns the identity index
/// list when `depths.length <= targetPoints` (no-op).
///
/// Force-keeping every band crossing guarantees no two adjacent kept samples
/// span a band boundary, so the velocity recomputed on the decimated series
/// stays in the same band as the original -- a brief rapid-ascent excursion can
/// never be averaged into a safer-looking band.
List<int> decimateProfileIndices({
  required List<double> depths,
  required List<int> bands,
  required List<int> decoTypes,
  int targetPoints = 2000,
}) {
  final n = depths.length;
  if (n <= targetPoints) {
    return List<int>.generate(n, (i) => i);
  }

  final keep = <int>{0, n - 1};

  // Force-keep safety transitions: ascent-rate band crossings and decoType
  // changes (keep both sides so the boundary is exact).
  for (var i = 1; i < n; i++) {
    if (bands[i] != bands[i - 1] || decoTypes[i] != decoTypes[i - 1]) {
      keep
        ..add(i - 1)
        ..add(i);
    }
  }

  // Global max-depth spike.
  var maxIdx = 0;
  for (var i = 1; i < n; i++) {
    if (depths[i] > depths[maxIdx]) maxIdx = i;
  }
  keep.add(maxIdx);

  // Min/max-per-bucket: preserves the depth envelope within each time bucket.
  final bucketCount = (targetPoints / 2).floor().clamp(1, n);
  final bucketSize = n / bucketCount;
  for (var b = 0; b < bucketCount; b++) {
    final start = (b * bucketSize).floor();
    final end = ((b + 1) * bucketSize).floor().clamp(start + 1, n);
    var lo = start;
    var hi = start;
    for (var i = start + 1; i < end; i++) {
      if (depths[i] < depths[lo]) lo = i;
      if (depths[i] > depths[hi]) hi = i;
    }
    keep
      ..add(lo)
      ..add(hi);
  }

  final result = keep.toList()..sort();
  return result;
}
