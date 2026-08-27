import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';

void main() {
  test('decimalDegrees is the first value so it is the natural default', () {
    expect(CoordinateFormat.values.first, CoordinateFormat.decimalDegrees);
  });

  test('names are stable, since they are persisted verbatim', () {
    expect(CoordinateFormat.values.map((f) => f.name).toList(), [
      'decimalDegrees',
      'degreesDecimalMinutes',
      'degreesMinutesSeconds',
      'utm',
      'mgrs',
    ]);
  });

  test('grid formats are the ones that cannot split into two axes', () {
    expect(CoordinateFormat.utm.isGridFormat, isTrue);
    expect(CoordinateFormat.mgrs.isGridFormat, isTrue);
    expect(CoordinateFormat.decimalDegrees.isGridFormat, isFalse);
    expect(CoordinateFormat.degreesMinutesSeconds.isGridFormat, isFalse);
  });
}
