import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_series.dart';

void main() {
  test('interior gaps interpolate, ends hold the nearest value', () {
    final out = resampleZSeries(
      values: [null, 10, null, null, 40, null],
      indices: [0, 1, 2, 3, 4, 5],
    );
    expect(out, [10, 10, 20, 30, 40, 40]);
  });

  test('picks only the requested indices', () {
    final out = resampleZSeries(values: [0, 10, 20, 30], indices: [0, 2]);
    expect(out, [0, 20]);
  });

  test('fewer than two finite samples means no Z series', () {
    expect(
      resampleZSeries(values: [null, 5, null], indices: [0, 1, 2]),
      isNull,
    );
    expect(
      resampleZSeries(values: [double.nan, 5, null], indices: [0, 1, 2]),
      isNull,
    );
  });
}
