import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_species_catalogue.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

Species _species(String id, {bool builtIn = false}) => Species(
  id: id,
  commonName: id,
  category: SpeciesCategory.fish,
  isBuiltIn: builtIn,
);

/// Issue #4578: a full backup wrote all of the bundled species, which every
/// install already has, so the catalogue keeps only what a restore needs.
void main() {
  group('uddfBackupSpecies', () {
    test('keeps every custom species and only the sighted bundled ones', () {
      final custom = _species('custom');
      final unusedCustom = _species('unused-custom');
      final seenBundled = _species('seen', builtIn: true);
      final unseenBundled = _species('unseen', builtIn: true);

      final catalogue = uddfBackupSpecies(
        all: [custom, seenBundled, unseenBundled, unusedCustom],
        sighted: [seenBundled, custom],
      );

      expect(catalogue.map((s) => s.id), ['custom', 'seen', 'unused-custom']);
    });

    test('adds a sighted species the full list does not hold', () {
      final stray = _species('stray', builtIn: true);

      final catalogue = uddfBackupSpecies(all: const [], sighted: [stray]);

      expect(catalogue, [stray]);
    });

    test('is empty with no custom species and no sightings', () {
      final catalogue = uddfBackupSpecies(
        all: [_species('bundled', builtIn: true)],
        sighted: const [],
      );

      expect(catalogue, isEmpty);
    });
  });
}
