import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/species_description_lookup.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A diver's edit to a built-in species must show everywhere (issue #3669):
/// the catalog translation applies only while a field still holds the
/// catalog's English text.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final de = lookupAppLocalizations(const Locale('de'));

  const id = 'sp_whale_shark';
  const catalogName = 'Whale Shark';
  final catalogDescription = builtInSpeciesDescription(en, id)!;

  Species whaleShark({String? commonName, String? description}) => Species(
    id: id,
    commonName: commonName ?? catalogName,
    category: SpeciesCategory.shark,
    description: description ?? catalogDescription,
    isBuiltIn: true,
  );

  group('Species.localizedCommonName', () {
    test('an untouched built-in name is translated', () {
      expect(whaleShark().localizedCommonName(de), 'Walhai');
      expect(whaleShark().localizedCommonName(en), catalogName);
    });

    test('a renamed built-in shows the diver name in every locale', () {
      final renamed = whaleShark(commonName: 'Spotty');

      expect(renamed.localizedCommonName(en), 'Spotty');
      expect(renamed.localizedCommonName(de), 'Spotty');
    });

    test('a custom species always shows its stored name', () {
      const custom = Species(
        id: 'b0d7c1de-0000-4000-8000-000000000000',
        commonName: 'Whale Shark',
        category: SpeciesCategory.shark,
      );

      expect(custom.localizedCommonName(de), 'Whale Shark');
    });
  });

  group('Species.localizedDescription', () {
    test('an untouched built-in description is translated', () {
      final german = builtInSpeciesDescription(de, id)!;
      expect(german, isNot(catalogDescription));

      expect(whaleShark().localizedDescription(de), german);
    });

    test('an edited built-in description shows the diver text', () {
      final edited = whaleShark(description: 'Seen off Ningaloo.');

      expect(edited.localizedDescription(en), 'Seen off Ningaloo.');
      expect(edited.localizedDescription(de), 'Seen off Ningaloo.');
    });

    test('a cleared built-in description stays cleared', () {
      const cleared = Species(
        id: id,
        commonName: catalogName,
        category: SpeciesCategory.shark,
        isBuiltIn: true,
      );

      expect(cleared.localizedDescription(de), isNull);
    });

    test('each field follows its own edit', () {
      final renamedOnly = whaleShark(commonName: 'Spotty');

      expect(renamedOnly.localizedCommonName(de), 'Spotty');
      expect(
        renamedOnly.localizedDescription(de),
        builtInSpeciesDescription(de, id),
      );
    });
  });

  group('localizedSpeciesName', () {
    test('a built-in id with the catalog name is translated', () {
      expect(localizedSpeciesName(de, id, catalogName), 'Walhai');
    });

    test('a built-in id with an edited name shows the stored name', () {
      expect(
        localizedSpeciesName(en, 'sp_cowfish', 'Honeycomb Cowfish'),
        'Honeycomb Cowfish',
      );
      expect(localizedSpeciesName(de, id, 'Spotty'), 'Spotty');
    });

    test('an unknown id shows the stored name', () {
      expect(localizedSpeciesName(de, 'not-a-seed', 'Critter'), 'Critter');
    });
  });
}
