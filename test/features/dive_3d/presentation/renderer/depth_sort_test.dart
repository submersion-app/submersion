import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/depth_sort.dart';

/// The reference order: a STABLE sort by `double.compareTo`, which is the
/// order the painter used to get from `List.sort` (minus its arbitrary
/// placement of equal depths).
List<int> _reference(Float32List depths) {
  final order = List<int>.generate(depths.length, (i) => i);
  // List.sort is not stable; break ties on the index to make it so.
  order.sort((a, b) {
    final c = depths[a].compareTo(depths[b]);
    return c != 0 ? c : a.compareTo(b);
  });
  return order;
}

List<int> _sorted(Float32List depths) {
  final scratch = DepthSortScratch();
  final order = Uint32List(depths.length);
  sortIndicesByDepth(depths, order, scratch);
  return order.toList();
}

void main() {
  test('an empty list sorts to nothing', () {
    expect(_sorted(Float32List(0)), isEmpty);
  });

  test('a single depth sorts to itself', () {
    expect(_sorted(Float32List.fromList([3.5])), [0]);
  });

  test('orders negatives, zeros and infinities as compareTo does', () {
    final depths = Float32List.fromList([
      2.5,
      -0.0,
      double.infinity,
      -7.25,
      0.0,
      double.negativeInfinity,
      -1e-30,
      1e-30,
      -2.5,
    ]);
    expect(_sorted(depths), _reference(depths));
  });

  test('every NaN sorts last, whatever its sign bit', () {
    final depths = Float32List.fromList([1, 0, -2, 0]);
    final bits = depths.buffer.asUint32List();
    bits[1] = 0xFFC00000; // a NaN with the sign bit set
    bits[3] = 0x7FC00001; // a positive NaN with a payload
    expect(depths[1].isNaN && depths[3].isNaN, isTrue);
    // compareTo puts every NaN after every number, NaNs tied with each
    // other, so they keep their index order.
    expect(_sorted(depths), [2, 0, 1, 3]);
    expect(_reference(depths), [2, 0, 1, 3]);
  });

  test('equal depths keep their original order', () {
    final depths = Float32List.fromList([1, 0, 1, 0, 1, 0]);
    expect(_sorted(depths), [1, 3, 5, 0, 2, 4]);
  });

  test('matches the reference on a large random set', () {
    final random = math.Random(4259);
    final depths = Float32List(20000);
    for (var i = 0; i < depths.length; i++) {
      // Coarse steps put plenty of exact ties among real spread.
      depths[i] = (random.nextInt(4000) - 2000) / 16;
    }
    expect(_sorted(depths), _reference(depths));
  });

  test('scratch is reused across sorts of different sizes', () {
    final scratch = DepthSortScratch();
    final big = Float32List.fromList([5, 4, 3, 2, 1]);
    final bigOrder = Uint32List(5);
    sortIndicesByDepth(big, bigOrder, scratch);
    expect(bigOrder, [4, 3, 2, 1, 0]);

    final small = Float32List.fromList([2, -1, 0]);
    final smallOrder = Uint32List(3);
    sortIndicesByDepth(small, smallOrder, scratch);
    expect(smallOrder, [1, 2, 0]);
  });

  test('a view into a larger buffer sorts only its own range', () {
    final backing = Float32List.fromList([9, 3, 1, 2, 9]);
    final view = Float32List.sublistView(backing, 1, 4);
    final order = Uint32List(3);
    sortIndicesByDepth(view, order, DepthSortScratch());
    expect(order, [1, 2, 0]);
  });
}
