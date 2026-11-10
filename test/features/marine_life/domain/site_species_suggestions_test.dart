import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/site_species_suggestions.dart';

SiteSpeciesSummary _spotted(
  String id, {
  required int dives,
  int? animals,
  String? name,
}) => SiteSpeciesSummary(
  speciesId: id,
  speciesName: name ?? id,
  category: SpeciesCategory.fish,
  sightingCount: dives,
  animalCount: animals ?? dives,
  diveCount: dives,
);

SiteSpeciesEntry _expected(String id, {String? name}) => SiteSpeciesEntry(
  id: 'entry-$id',
  siteId: 'site',
  speciesId: id,
  speciesName: name ?? id,
  category: SpeciesCategory.turtle,
  notes: '',
  createdAt: DateTime.utc(2026),
);

String _plainName(String id, String storedName) => storedName;

void main() {
  group('buildSiteSpeciesSuggestions', () {
    test('orders sighted species by dives, then animals, then name', () {
      final suggestions = buildSiteSpeciesSuggestions(
        spotted: [
          _spotted('wrasse', dives: 2, animals: 2),
          _spotted('shark', dives: 5),
          _spotted('jack', dives: 2, animals: 40),
          _spotted('Angelfish', dives: 2, animals: 2),
        ],
        expected: const [],
        displayName: _plainName,
      );

      expect(suggestions.map((s) => s.speciesId), [
        'shark',
        'jack',
        'Angelfish',
        'wrasse',
      ]);
      expect(suggestions.first.diveCount, 5);
      expect(suggestions.every((s) => !s.isExpectedOnly), isTrue);
    });

    test('appends expected species never sighted, alphabetically', () {
      final suggestions = buildSiteSpeciesSuggestions(
        spotted: [_spotted('shark', dives: 1)],
        expected: [_expected('turtle'), _expected('manta')],
        displayName: _plainName,
      );

      expect(suggestions.map((s) => s.speciesId), ['shark', 'manta', 'turtle']);
      expect(suggestions[1].isExpectedOnly, isTrue);
      expect(suggestions[1].diveCount, 0);
      expect(suggestions[1].category, SpeciesCategory.turtle);
    });

    test('lists a species both sighted and expected once, as sighted', () {
      final suggestions = buildSiteSpeciesSuggestions(
        spotted: [_spotted('turtle', dives: 3)],
        expected: [_expected('turtle')],
        displayName: _plainName,
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.single.isExpectedOnly, isFalse);
      expect(suggestions.single.diveCount, 3);
    });

    test('leaves out species already on the dive', () {
      final suggestions = buildSiteSpeciesSuggestions(
        spotted: [_spotted('shark', dives: 1), _spotted('jack', dives: 1)],
        expected: [_expected('turtle')],
        excludeSpeciesIds: const {'shark', 'turtle'},
        displayName: _plainName,
      );

      expect(suggestions.map((s) => s.speciesId), ['jack']);
    });

    test('sorts names as the diver reads them', () {
      final suggestions = buildSiteSpeciesSuggestions(
        spotted: const [],
        expected: [
          _expected('a', name: 'Zebra shark'),
          _expected('b', name: 'Barracuda'),
        ],
        // The display name reverses the stored order, as a translation can.
        displayName: (id, stored) => id == 'a' ? 'Aal' : 'Pfeilhecht',
      );

      expect(suggestions.map((s) => s.speciesId), ['a', 'b']);
    });
  });
}
