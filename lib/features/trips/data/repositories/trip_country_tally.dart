import 'dart:math' as math;

import 'package:collection/collection.dart';

import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/features/trips/domain/entities/trip_country.dart';

/// One stored country name's dives on one trip, as
/// `TripCountryQueries.getTripCountries` reads them (issue #4426).
typedef TripCountryRow = ({
  String tripId,
  String name,
  String? code,
  int dives,
  int firstDive,
});

/// Each trip's countries from [rows], keyed by trip id; a trip with no
/// recognisable country has no entry.
///
/// Countries come most dived first, a tie going to the one dived earlier,
/// then by code; stored names that mean one country ("Mexico", "México")
/// count as one.
Map<String, List<TripCountry>> tallyTripCountries(
  Iterable<TripCountryRow> rows,
) {
  final byTrip = <String, Map<String, _CountryTally>>{};
  for (final row in rows) {
    // A stored code wins; only a site without one has its text read.
    final code = siteFlagCode(country: row.name, code: row.code);
    if (code == null) continue;
    final tallies = byTrip.putIfAbsent(row.tripId, () => {});
    final tally = tallies[code];
    tallies[code] = tally == null
        ? _CountryTally.first(code, row.name, row.dives, row.firstDive)
        : tally.add(row.name, row.dives, row.firstDive);
  }
  return {
    for (final entry in byTrip.entries)
      entry.key: [
        for (final tally in entry.value.values.sorted(_CountryTally.compare))
          TripCountry(code: tally.code, name: tally.name),
      ],
  };
}

/// One country's dives on a trip, summed across the stored names that mean
/// it.
class _CountryTally {
  const _CountryTally({
    required this.code,
    required this.name,
    required this.nameDives,
    required this.nameFirst,
    required this.dives,
    required this.firstDive,
  });

  _CountryTally.first(this.code, this.name, int count, int first)
    : nameDives = count,
      nameFirst = first,
      dives = count,
      firstDive = first;

  final String code;

  /// The stored name the tooltip shows, and its own dives and first dive.
  final String name;
  final int nameDives;
  final int nameFirst;

  /// Every stored name's dives together, and the earliest of them.
  final int dives;
  final int firstDive;

  /// This tally with one more stored name's dives. The tooltip shows the
  /// name with the most dives; on a tie, the one dived first, then the
  /// lesser name, so it never depends on the order SQLite returns the
  /// groups in.
  _CountryTally add(String storedName, int count, int first) {
    final wins =
        count > nameDives ||
        (count == nameDives &&
            (first < nameFirst ||
                (first == nameFirst && storedName.compareTo(name) < 0)));
    return _CountryTally(
      code: code,
      name: wins ? storedName : name,
      nameDives: wins ? count : nameDives,
      nameFirst: wins ? first : nameFirst,
      dives: dives + count,
      firstDive: math.min(firstDive, first),
    );
  }

  /// Most dives first, then the country dived earlier, then by code so the
  /// order never wobbles.
  static int compare(_CountryTally a, _CountryTally b) {
    final byDives = b.dives.compareTo(a.dives);
    if (byDives != 0) return byDives;
    final byFirst = a.firstDive.compareTo(b.firstDive);
    if (byFirst != 0) return byFirst;
    return a.code.compareTo(b.code);
  }
}
