import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/text/fuzzy_match.dart' show foldForSearch;
import 'package:submersion/features/marine_life/presentation/species_ids.dart';
import 'package:submersion/features/marine_life/presentation/species_name_lookup.dart';
import 'package:submersion/features/marine_life/query/species_text_search.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  group('builtInSpeciesIdsMatching', () {
    test('finds a translated name typed without its accents (#4498)', () {
      final french = lookupAppLocalizations(const Locale('fr'));
      final accented = [
        for (final id in kBuiltInSpeciesIds)
          if (builtInSpeciesName(french, id) case final name?
              when foldForSearch(name) != name.toLowerCase())
            (id: id, name: name),
      ];
      expect(
        accented,
        isNotEmpty,
        reason: 'the French catalogue must hold an accented name to test',
      );

      final (:id, :name) = accented.first;
      final plain = foldForSearch(name);
      expect(builtInSpeciesIdsMatching(plain), contains(id), reason: name);
      expect(builtInSpeciesIdsMatching(name), contains(id), reason: name);
    });

    test('a blank term matches nothing', () {
      expect(builtInSpeciesIdsMatching('  '), isEmpty);
    });
  });
}
