import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/species_grouping.dart';

import 'species_test_entries.dart';

void main() {
  final fish = seenEntry('fish', first: DateTime.utc(2024, 3, 1));
  final shark = seenEntry(
    'shark',
    category: SpeciesCategory.shark,
    first: DateTime.utc(2025, 6, 1),
  );
  final coral = seenEntry(
    'coral',
    category: SpeciesCategory.coral,
    first: DateTime.utc(2025, 1, 1),
  );
  final entries = [coral, fish, shark];

  test('none is one group in the given order', () {
    final groups = groupSeenSpecies(entries, by: SpeciesGroupBy.none);
    expect(groups, hasLength(1));
    expect(groups.single.entries, entries);
  });

  test('category groups follow SpeciesCategory order and skip empty ones', () {
    final groups = groupSeenSpecies(entries, by: SpeciesGroupBy.category);
    expect(groups.map((g) => g.category), [
      SpeciesCategory.fish,
      SpeciesCategory.shark,
      SpeciesCategory.coral,
    ]);
  });

  test('first seen groups by year newest first, each species once', () {
    final groups = groupSeenSpecies(entries, by: SpeciesGroupBy.firstSeen);
    expect(groups.map((g) => g.year), [2025, 2024]);
    expect(groups.first.entries, [coral, shark]);
    expect(groups.expand((g) => g.entries), hasLength(3));
  });

  const tripA = SpeciesPlace(id: 'a', name: 'Bonaire');
  final tripB = SpeciesPlace(
    id: 'b',
    name: 'Cozumel',
    sortDate: DateTime.utc(2026, 5, 1),
  );
  final tripC = SpeciesPlace(
    id: 'c',
    name: 'Belize',
    sortDate: DateTime.utc(2025, 1, 1),
  );
  const noTrip = SpeciesPlace(id: null, name: '');

  test('trip lists a species under every trip, newest first, No trip last', () {
    final places = SpeciesPlaces(
      tripsBySpecies: {
        'fish': [tripB, tripC],
        'shark': [noTrip, tripC],
        'coral': [tripA],
      },
      sitesBySpecies: const {},
      firstTripBySpecies: const {'fish': 'c', 'shark': null, 'coral': 'a'},
      firstSiteBySpecies: const {},
    );
    final groups = groupSeenSpecies(
      entries,
      by: SpeciesGroupBy.trip,
      places: places,
    );
    expect(groups.map((g) => g.place?.id), ['b', 'c', 'a', null]);
    expect(groups[1].entries, [fish, shark]);
  });

  test('firstSeenHere marks the species whose first trip is that trip', () {
    final places = SpeciesPlaces(
      tripsBySpecies: {
        'fish': [tripB, tripC],
      },
      sitesBySpecies: const {},
      firstTripBySpecies: const {'fish': 'c'},
      firstSiteBySpecies: const {},
    );
    final groups = groupSeenSpecies(
      [fish],
      by: SpeciesGroupBy.trip,
      places: places,
    );
    expect(groups.first.firstSeenHere, isEmpty);
    expect(groups.last.firstSeenHere, {'fish'});
  });

  test('site orders by most species then name, No site last', () {
    const reef = SpeciesPlace(id: 'r', name: 'Reef');
    const arch = SpeciesPlace(id: 'x', name: 'Arch');
    const wall = SpeciesPlace(id: 'w', name: 'Wall');
    const noSite = SpeciesPlace(id: null, name: '');
    const places = SpeciesPlaces(
      tripsBySpecies: {},
      sitesBySpecies: {
        'fish': [reef, wall, noSite],
        'shark': [reef, arch],
        'coral': [noSite],
      },
      firstTripBySpecies: {},
      firstSiteBySpecies: {},
    );
    final groups = groupSeenSpecies(
      entries,
      by: SpeciesGroupBy.site,
      places: places,
    );
    expect(groups.map((g) => g.place?.id), ['r', 'x', 'w', null]);
    expect(groups.last.entries, [coral, fish]);
  });

  test('a species with no recorded place lands in the empty-place group', () {
    final groups = groupSeenSpecies(
      [fish],
      by: SpeciesGroupBy.trip,
      places: const SpeciesPlaces(
        tripsBySpecies: {},
        sitesBySpecies: {},
        firstTripBySpecies: {},
        firstSiteBySpecies: {},
      ),
    );
    expect(groups.single.place?.id, isNull);
    expect(groups.single.entries, [fish]);
  });

  test('places and groups copy with changes', () {
    const place = SpeciesPlace(id: 'a', name: 'Bonaire');
    expect(place.copyWith(name: 'Curacao').name, 'Curacao');
    expect(place.copyWith(name: 'Curacao').id, 'a');
    final group = SpeciesGroup(key: 'k', entries: [fish]);
    expect(group.copyWith(firstSeenHere: {'fish'}).firstSeenHere, {'fish'});
    expect(group.copyWith(key: 'j').entries, [fish]);
  });
}
