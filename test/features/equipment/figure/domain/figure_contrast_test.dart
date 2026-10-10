import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/figure/domain/figure_contrast.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_section_colors.dart';

void main() {
  const colors = [
    0xFF000000,
    0xFFFFFFFF,
    0xFF1C1C1E,
    0xFF1C1B1F,
    0xFF2A2A2E,
    0xFF808080,
    0xFFEF4444,
    0xFF1F3A5F,
    0xFFF4C542,
    0xFFE6E1E5,
  ];

  test('contrast matches the Flutter helper the rest of the app uses', () {
    for (final a in colors) {
      for (final b in colors) {
        expect(
          figureContrast(a, b),
          closeTo(contrastRatio(Color(a), Color(b)), 1e-6),
          reason: '${a.toRadixString(16)} on ${b.toRadixString(16)}',
        );
      }
    }
  });

  test('black on white is 21:1 and a colour on itself is 1:1', () {
    expect(figureContrast(0xFF000000, 0xFFFFFFFF), closeTo(21, 1e-9));
    expect(figureContrast(0xFF1C1C1E, 0xFF1C1C1E), 1);
  });
}
