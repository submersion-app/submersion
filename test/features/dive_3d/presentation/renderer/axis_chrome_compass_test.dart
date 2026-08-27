import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';

void main() {
  test('compassCenter subtracts the pan so the rose stays in the corner', () {
    // The viewport translates the painted output by the pan offset; the
    // compass is fixed chrome, so its draw position must pre-subtract it.
    expect(
      AxisChromePainter.compassCenter(const Size(400, 300), Offset.zero),
      const Offset(36, 264),
    );
    expect(
      AxisChromePainter.compassCenter(
        const Size(400, 300),
        const Offset(50, -20),
      ),
      const Offset(-14, 284),
    );
  });
}
