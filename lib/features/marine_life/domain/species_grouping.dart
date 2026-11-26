import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/wall_clock.dart';

/// How the Species page groups its cards (issue #5027).
enum SpeciesGroupBy { none, category, firstSeen, trip, site }

/// A trip or a site a species was seen on. A null [id] is "No trip" or
/// "No site": dives without one.
class SpeciesPlace {
  const SpeciesPlace({required this.id, required this.name, this.sortDate});

  final String? id;
  final String name;

  /// A trip's start, for newest-first order. Unused for sites.
  final DateTime? sortDate;

  @override
  bool operator ==(Object other) => other is SpeciesPlace && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Where each species was seen, for the Trip and Site groupings.
class SpeciesPlaces {
  const SpeciesPlaces({
    required this.tripsBySpecies,
    required this.sitesBySpecies,
    required this.firstTripBySpecies,
    required this.firstSiteBySpecies,
  });

  final Map<String, List<SpeciesPlace>> tripsBySpecies;
  final Map<String, List<SpeciesPlace>> sitesBySpecies;

  /// The trip (or site) of each species' earliest sighting; null when that
  /// dive had none.
  final Map<String, String?> firstTripBySpecies;
  final Map<String, String?> firstSiteBySpecies;
}

/// One section of the grouped Species page. Exactly one of [category],
/// [year] and [place] is set, except for [SpeciesGroupBy.none], which sets
/// none.
class SpeciesGroup {
  const SpeciesGroup({
    required this.key,
    this.category,
    this.year,
    this.place,
    required this.entries,
    this.firstSeenHere = const {},
  });

  final String key;
  final SpeciesCategory? category;
  final int? year;
  final SpeciesPlace? place;
  final List<SeenSpecies> entries;

  /// Species ids first seen on this group's trip or site.
  final Set<String> firstSeenHere;
}

/// Splits [sorted] into the sections of [by], keeping [sorted]'s order inside
/// each. [places] is needed for [SpeciesGroupBy.trip] and
/// [SpeciesGroupBy.site]; a species with no recorded place goes to the
/// "No trip" / "No site" section, never dropped.
List<SpeciesGroup> groupSeenSpecies(
  List<SeenSpecies> sorted, {
  required SpeciesGroupBy by,
  SpeciesPlaces? places,
}) {
  switch (by) {
    case SpeciesGroupBy.none:
      return [SpeciesGroup(key: 'all', entries: sorted)];
    case SpeciesGroupBy.category:
      return [
        for (final category in SpeciesCategory.values)
          if (sorted.any((e) => e.species.category == category))
            SpeciesGroup(
              key: 'category:${category.name}',
              category: category,
              entries: [
                for (final e in sorted)
                  if (e.species.category == category) e,
              ],
            ),
      ];
    case SpeciesGroupBy.firstSeen:
      final years = {
        for (final e in sorted) wallClock(e.firstSeen).year,
      }.toList()..sort((a, b) => b.compareTo(a));
      return [
        for (final year in years)
          SpeciesGroup(
            key: 'year:$year',
            year: year,
            entries: [
              for (final e in sorted)
                if (wallClock(e.firstSeen).year == year) e,
            ],
          ),
      ];
    case SpeciesGroupBy.trip:
      return _byPlace(
        sorted,
        prefix: 'trip',
        placesOf: places?.tripsBySpecies ?? const {},
        firstOf: places?.firstTripBySpecies ?? const {},
        compare: _newestTripFirst,
      );
    case SpeciesGroupBy.site:
      return _byPlace(
        sorted,
        prefix: 'site',
        placesOf: places?.sitesBySpecies ?? const {},
        firstOf: places?.firstSiteBySpecies ?? const {},
        compare: _mostSpeciesFirst,
      );
  }
}

typedef _PlaceGroup = ({SpeciesPlace place, List<SeenSpecies> entries});

const _noPlace = SpeciesPlace(id: null, name: '');

List<SpeciesGroup> _byPlace(
  List<SeenSpecies> sorted, {
  required String prefix,
  required Map<String, List<SpeciesPlace>> placesOf,
  required Map<String, String?> firstOf,
  required int Function(_PlaceGroup a, _PlaceGroup b) compare,
}) {
  final groups = <String?, _PlaceGroup>{};
  for (final entry in sorted) {
    final seenAt = placesOf[entry.species.id];
    final where = seenAt == null || seenAt.isEmpty ? [_noPlace] : seenAt;
    for (final place in where) {
      groups
          .putIfAbsent(place.id, () => (place: place, entries: []))
          .entries
          .add(entry);
    }
  }
  final named = groups.values.where((g) => g.place.id != null).toList()
    ..sort(compare);
  final none = groups[null];
  return [
    for (final g in [...named, ?none])
      SpeciesGroup(
        key: '$prefix:${g.place.id ?? 'none'}',
        place: g.place,
        entries: g.entries,
        firstSeenHere: g.place.id == null
            ? const {}
            : {
                for (final e in g.entries)
                  if (firstOf[e.species.id] == g.place.id) e.species.id,
              },
      ),
  ];
}

int _newestTripFirst(_PlaceGroup a, _PlaceGroup b) {
  final da = a.place.sortDate;
  final db = b.place.sortDate;
  if (da != null && db != null && da != db) return db.compareTo(da);
  if (da == null && db != null) return 1;
  if (da != null && db == null) return -1;
  return compareTextForSort(a.place.name, b.place.name);
}

int _mostSpeciesFirst(_PlaceGroup a, _PlaceGroup b) {
  final byCount = b.entries.length.compareTo(a.entries.length);
  if (byCount != 0) return byCount;
  return compareTextForSort(a.place.name, b.place.name);
}
