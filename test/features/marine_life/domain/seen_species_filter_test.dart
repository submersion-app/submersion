import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/seen_species_filter.dart';

SeenSpecies _entry({
  required String id,
  required String name,
  String? scientific,
  SpeciesCategory category = SpeciesCategory.fish,
  int sightings = 1,
  int dives = 1,
  DateTime? first,
  DateTime? last,
}) => SeenSpecies(
  species: Species(
    id: id,
    commonName: name,
    scientificName: scientific,
    category: category,
    isBuiltIn: id.startsWith('sp_'),
  ),
  totalSightings: sightings,
  diveCount: dives,
  siteCount: 1,
  firstSeen: first ?? DateTime(2024, 1, 1),
  lastSeen: last ?? DateTime(2024, 1, 1),
);

/// Stands in for the ARB lookup: built-ins get a "translated" name.
String _german(Species s) => switch (s.id) {
  'sp_whale_shark' => 'Walhai',
  'sp_green_sea_turtle' => 'Suppenschildkroete',
  _ => s.commonName,
};

String _english(Species s) => s.commonName;

List<String> _ids(List<SeenSpecies> entries) =>
    entries.map((e) => e.species.id).toList();

void main() {
  final whaleShark = _entry(
    id: 'sp_whale_shark',
    name: 'Whale Shark',
    scientific: 'Rhincodon typus',
    category: SpeciesCategory.shark,
    sightings: 5,
    dives: 4,
    first: DateTime(2022, 6, 1),
    last: DateTime(2024, 3, 1),
  );
  final turtle = _entry(
    id: 'sp_green_sea_turtle',
    name: 'Green Sea Turtle',
    scientific: 'Chelonia mydas',
    category: SpeciesCategory.turtle,
    sightings: 3,
    dives: 3,
    first: DateTime(2023, 1, 1),
    last: DateTime(2024, 6, 1),
  );
  final anemone = _entry(
    id: 'c1',
    name: 'anemone (my own)',
    category: SpeciesCategory.invertebrate,
    sightings: 3,
    dives: 2,
    first: DateTime(2021, 1, 1),
    last: DateTime(2023, 12, 1),
  );
  final all = [turtle, anemone, whaleShark];

  List<SeenSpecies> run({
    String query = '',
    SpeciesCategory? category,
    SeenSpeciesSort sort = SeenSpeciesSort.mostSightings,
    SpeciesNameOf nameOf = _english,
  }) => filterSeenSpecies(
    all,
    query: query,
    category: category,
    sort: sort,
    nameOf: nameOf,
  );

  group('matching', () {
    test('empty query returns every entry', () {
      expect(run(), hasLength(3));
    });

    test('matches the localized name from nameOf', () {
      expect(_ids(run(query: 'walh', nameOf: _german)), ['sp_whale_shark']);
    });

    test('still matches the stored English name under a translated name', () {
      expect(_ids(run(query: 'whale', nameOf: _german)), ['sp_whale_shark']);
    });

    test('matches the scientific name', () {
      expect(_ids(run(query: 'chelonia')), ['sp_green_sea_turtle']);
    });

    test('ignores case and surrounding whitespace', () {
      expect(_ids(run(query: '  WHALE ')), ['sp_whale_shark']);
    });

    test('a query nothing matches returns an empty list', () {
      expect(run(query: 'zzz'), isEmpty);
    });

    test('category narrows to that category only', () {
      expect(_ids(run(category: SpeciesCategory.turtle)), [
        'sp_green_sea_turtle',
      ]);
    });

    test('query and category combine', () {
      expect(run(query: 'whale', category: SpeciesCategory.turtle), isEmpty);
    });
  });

  group('sorting', () {
    test('mostSightings: sightings desc, then dives desc, then name', () {
      // turtle and anemone tie on 3 sightings; turtle has more dives.
      expect(_ids(run()), ['sp_whale_shark', 'sp_green_sea_turtle', 'c1']);
    });

    test('mostSightings breaks a full tie on name', () {
      final a = _entry(id: 'a', name: 'Zebra', sightings: 2, dives: 2);
      final b = _entry(id: 'b', name: 'Apple', sightings: 2, dives: 2);
      final sorted = filterSeenSpecies(
        [a, b],
        query: '',
        sort: SeenSpeciesSort.mostSightings,
        nameOf: _english,
      );
      expect(_ids(sorted), ['b', 'a']);
    });

    test('recentlySeen: lastSeen desc', () {
      expect(_ids(run(sort: SeenSpeciesSort.recentlySeen)), [
        'sp_green_sea_turtle',
        'sp_whale_shark',
        'c1',
      ]);
    });

    test('firstSeen: firstSeen asc, the order of discovery', () {
      expect(_ids(run(sort: SeenSpeciesSort.firstSeen)), [
        'c1',
        'sp_whale_shark',
        'sp_green_sea_turtle',
      ]);
    });

    test('name: localized name asc, case-insensitive', () {
      expect(_ids(run(sort: SeenSpeciesSort.name)), [
        'c1',
        'sp_green_sea_turtle',
        'sp_whale_shark',
      ]);
      // Under German names Walhai must still sort last.
      expect(
        _ids(run(sort: SeenSpeciesSort.name, nameOf: _german)).last,
        'sp_whale_shark',
      );
    });
  });

  group('name tie-breaks are total', () {
    test('identical names fall back to the species id', () {
      final a = _entry(id: 'b-second', name: 'Grouper');
      final b = _entry(id: 'a-first', name: 'Grouper');
      List<String> sortedIds(List<SeenSpecies> input) => _ids(
        filterSeenSpecies(
          input,
          query: '',
          sort: SeenSpeciesSort.name,
          nameOf: _english,
        ),
      );
      // Same result whichever order the query happened to return them in.
      expect(sortedIds([a, b]), ['a-first', 'b-second']);
      expect(sortedIds([b, a]), ['a-first', 'b-second']);
    });

    test('scientific names compare case-insensitively', () {
      final upper = _entry(id: 'u', name: 'Grouper', scientific: 'Epinephelus');
      final lower = _entry(
        id: 'l',
        name: 'Grouper',
        scientific: 'aethaloperca',
      );
      final sorted = filterSeenSpecies(
        [upper, lower],
        query: '',
        sort: SeenSpeciesSort.name,
        nameOf: _english,
      );
      // A case-sensitive compare would put "Epinephelus" before
      // "aethaloperca" because uppercase sorts first in ASCII.
      expect(_ids(sorted), ['l', 'u']);
    });
  });

  test('does not mutate the input list', () {
    final input = [whaleShark, anemone, turtle];
    final snapshot = List<SeenSpecies>.of(input);
    filterSeenSpecies(
      input,
      query: '',
      sort: SeenSpeciesSort.name,
      nameOf: _english,
    );
    expect(input, snapshot);
  });
}
