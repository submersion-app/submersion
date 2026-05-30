import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';

void main() {
  group('iconForSpeciesCategory', () {
    test('maps each species category to its expected marine icon', () {
      final expected = <SpeciesCategory, IconData>{
        SpeciesCategory.fish: MdiIcons.fish,
        SpeciesCategory.shark: MdiIcons.shark,
        SpeciesCategory.ray: MdiIcons.fish,
        SpeciesCategory.mammal: MdiIcons.dolphin,
        SpeciesCategory.turtle: MdiIcons.turtle,
        SpeciesCategory.invertebrate: MdiIcons.jellyfish,
        SpeciesCategory.coral: Icons.park,
        SpeciesCategory.plant: Icons.grass,
        SpeciesCategory.other: Icons.more_horiz,
      };

      for (final entry in expected.entries) {
        expect(
          iconForSpeciesCategory(entry.key),
          entry.value,
          reason: 'Wrong icon for ${entry.key.name}',
        );
      }
    });

    test('uses the dolphin (marine mammal) icon for mammals, not a fish', () {
      expect(iconForSpeciesCategory(SpeciesCategory.mammal), MdiIcons.dolphin);
      expect(
        iconForSpeciesCategory(SpeciesCategory.mammal),
        isNot(MdiIcons.fish),
      );
    });

    test('never returns the paw icon for any category', () {
      for (final category in SpeciesCategory.values) {
        expect(
          iconForSpeciesCategory(category),
          isNot(Icons.pets),
          reason: '${category.name} must not use the paw icon',
        );
      }
    });

    test('covers every species category', () {
      for (final category in SpeciesCategory.values) {
        expect(iconForSpeciesCategory(category), isA<IconData>());
      }
    });
  });
}
