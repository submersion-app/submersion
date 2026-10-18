import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_section_colors.dart';

void main() {
  group('EquipmentSectionColors.readableOn', () {
    test('picks the candidate that reads best on the fill', () {
      expect(
        EquipmentSectionColors.readableOn(Colors.white, [
          Colors.yellow,
          Colors.black,
        ]),
        Colors.black,
      );
    });

    test('falls back to black or white when no candidate reads', () {
      const fill = Color(0xFF808080);
      // Mid grey against near-mid greys: neither candidate reaches 4.5:1.
      final picked = EquipmentSectionColors.readableOn(fill, [
        const Color(0xFF909090),
        const Color(0xFF707070),
      ]);
      expect(picked, anyOf(Colors.black, Colors.white));
      expect(contrastRatio(picked, fill), greaterThanOrEqualTo(4.5));
    });
  });

  group('contrastRatio', () {
    test('is 21 for black on white, either way round', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(contrastRatio(Colors.white, Colors.black), closeTo(21, 0.01));
    });

    test('is 1 for a colour against itself', () {
      expect(contrastRatio(Colors.teal, Colors.teal), closeTo(1, 0.0001));
    });
  });
}
