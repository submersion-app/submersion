import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';

void main() {
  test('every category resolves a color in both brightnesses', () {
    for (final brightness in Brightness.values) {
      final seen = <Color>{};
      for (final category in SpeciesCategory.values) {
        seen.add(colorForSpeciesCategory(category, brightness));
      }
      // Null (unknown category) falls back to grey.
      seen.add(colorForSpeciesCategory(null, brightness));
      expect(seen, isNotEmpty);
    }
  });

  test('shades adapt to brightness for contrast', () {
    final light = colorForSpeciesCategory(
      SpeciesCategory.fish,
      Brightness.light,
    );
    final dark = colorForSpeciesCategory(SpeciesCategory.fish, Brightness.dark);
    expect(light, isNot(equals(dark)));
  });
}
