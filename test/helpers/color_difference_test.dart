import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'color_difference.dart';

/// The reference pairs published with the CIEDE2000 formula (Sharma, Wu and
/// Dalal, 2005, table 1), so the chart colour tests stand on a known-good
/// distance.
void main() {
  const pairs = [
    ((50.0, 2.6772, -79.7751), (50.0, 0.0, -82.7485), 2.0425),
    ((50.0, -1.3802, -84.2814), (50.0, 0.0, -82.7485), 1.0),
    ((50.0, 2.5, 0.0), (50.0, 0.0, -2.5), 4.3065),
    ((50.0, 2.5, 0.0), (73.0, 25.0, -18.0), 27.1492),
    ((60.2574, -34.0099, 36.2677), (60.4626, -34.1751, 39.4387), 1.2644),
    ((22.7233, 20.0904, -46.694), (23.0331, 14.973, -42.5619), 2.0373),
    ((2.0776, 0.0795, -1.135), (0.9033, -0.0636, -0.5514), 0.9082),
  ];
  for (final (index, (first, second, expected)) in pairs.indexed) {
    test('reference pair ${index + 1} is $expected apart', () {
      expect(ciede2000(first, second), closeTo(expected, 1e-4));
      expect(ciede2000(second, first), closeTo(expected, 1e-4));
    });
  }

  test('a colour is no distance from itself', () {
    expect(colorDifference(Colors.indigo, Colors.indigo), 0);
  });
}
