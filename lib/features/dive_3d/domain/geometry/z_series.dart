/// Fills a metric series so the path never breaks, then picks the decimated
/// [indices]. Interior nulls interpolate linearly between their finite
/// neighbors (by sample index, which is what the decimator works in);
/// leading and trailing nulls take the nearest finite value. Returns null
/// when fewer than two finite values exist: a Z axis needs a path.
List<double>? resampleZSeries({
  required List<double?> values,
  required List<int> indices,
}) {
  final n = values.length;
  bool finite(int i) {
    final v = values[i];
    return v != null && v.isFinite;
  }

  final finiteIdx = [
    for (var i = 0; i < n; i++)
      if (finite(i)) i,
  ];
  if (finiteIdx.length < 2) return null;

  final filled = List<double>.filled(n, 0);
  var k = 0; // index into finiteIdx of the nearest finite sample at/after i
  for (var i = 0; i < n; i++) {
    if (finite(i)) {
      filled[i] = values[i]!;
      if (finiteIdx[k] < i) k++;
      continue;
    }
    if (i < finiteIdx.first) {
      filled[i] = values[finiteIdx.first]!;
    } else if (i > finiteIdx.last) {
      filled[i] = values[finiteIdx.last]!;
    } else {
      while (finiteIdx[k] < i) {
        k++;
      }
      final hi = finiteIdx[k], lo = finiteIdx[k - 1];
      final a = values[lo]!, b = values[hi]!;
      filled[i] = a + (b - a) * ((i - lo) / (hi - lo));
    }
  }
  return [for (final i in indices) filled[i]];
}
