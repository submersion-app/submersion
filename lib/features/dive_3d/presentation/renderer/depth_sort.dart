import 'dart:typed_data';

/// Working memory for [sortIndicesByDepth], kept between calls so a sort
/// per frame allocates nothing once the buffers have grown to fit.
class DepthSortScratch {
  Uint32List _keys = Uint32List(0);
  Uint32List _keysOut = Uint32List(0);
  Uint32List _orderOut = Uint32List(0);
  final Int32List _counts = Int32List(256);

  /// Sizes the buffers for [n] keys: grows them when short, and shrinks
  /// them when the soup got much smaller (a coarser terrain stage), so a
  /// one-off dense mesh does not pin its working memory for good.
  void _ensure(int n) {
    if (_keys.length >= n && _keys.length <= n * 2) return;
    _keys = Uint32List(n);
    _keysOut = Uint32List(n);
    _orderOut = Uint32List(n);
  }
}

/// Fills [order] with the indices of [depths], smallest depth first.
///
/// The order is the one `double.compareTo` gives (-0.0 before 0.0, NaN
/// last), and it is stable: equal depths keep their index order, so ties
/// between a terrain triangle and a drape resolve the same way on every
/// frame instead of flickering with an unstable sort.
///
/// It is an LSD radix sort over the float bits, four 8-bit passes that skip
/// any byte every key shares. That is linear in the count and calls no
/// comparator, which matters because the 3D painter sorts every triangle of
/// a dense terrain (half a million on the finest grid) on each orbit frame
/// (issue #4259).
void sortIndicesByDepth(
  Float32List depths,
  Uint32List order,
  DepthSortScratch scratch,
) {
  final n = depths.length;
  assert(order.length == n, 'order needs one slot per depth');
  if (n == 0) return;
  scratch._ensure(n);

  // Reinterpret each float as an unsigned key that sorts the same way:
  // flip every bit of a negative (so more negative sorts lower), and only
  // the sign bit of a positive (so it sorts above every negative). Every
  // NaN, whatever its sign bit or payload, takes the top key: compareTo
  // puts NaN after +infinity and ties NaNs with each other.
  final bits = depths.buffer.asUint32List(depths.offsetInBytes, n);
  var keys = scratch._keys;
  var idx = order;
  var keysOut = scratch._keysOut;
  var idxOut = scratch._orderOut;
  for (var i = 0; i < n; i++) {
    final b = bits[i];
    keys[i] = (b & 0x7FFFFFFF) > 0x7F800000
        ? 0xFFFFFFFF
        : (b & 0x80000000) != 0
        ? ~b
        : b | 0x80000000;
    idx[i] = i;
  }

  final counts = scratch._counts;
  for (var shift = 0; shift < 32; shift += 8) {
    counts.fillRange(0, 256, 0);
    for (var i = 0; i < n; i++) {
      counts[(keys[i] >> shift) & 0xFF]++;
    }
    // Every key has the same byte here: the pass would move nothing.
    if (counts[(keys[0] >> shift) & 0xFF] == n) continue;
    var sum = 0;
    for (var d = 0; d < 256; d++) {
      final c = counts[d];
      counts[d] = sum;
      sum += c;
    }
    for (var i = 0; i < n; i++) {
      final k = keys[i];
      final slot = counts[(k >> shift) & 0xFF]++;
      keysOut[slot] = k;
      idxOut[slot] = idx[i];
    }
    final k = keys;
    keys = keysOut;
    keysOut = k;
    final o = idx;
    idx = idxOut;
    idxOut = o;
  }
  if (!identical(idx, order)) order.setRange(0, n, idx);
}
