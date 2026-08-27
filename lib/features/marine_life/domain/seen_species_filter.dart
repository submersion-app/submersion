import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

/// Sort orders offered by the Species page.
enum SeenSpeciesSort { mostSightings, recentlySeen, firstSeen, name }

/// Resolves the name a species is displayed under.
///
/// Injected rather than read from the entity because built-in species are
/// localized at display time through `AppLocalizations`, which is
/// presentation-layer; the page passes `s.localizedCommonName(l10n)` and
/// tests pass a plain map.
typedef SpeciesNameOf = String Function(Species species);

/// Filters [entries] by [query] and [category], then sorts by [sort].
///
/// The query is trimmed and matched case-insensitively as a substring of the
/// displayed name, the stored English name (so a German diver typing "whale
/// shark" still finds Walhai) and the scientific name. Returns a new list;
/// [entries] is never mutated.
List<SeenSpecies> filterSeenSpecies(
  List<SeenSpecies> entries, {
  required String query,
  SpeciesCategory? category,
  required SeenSpeciesSort sort,
  required SpeciesNameOf nameOf,
}) {
  final needle = query.trim().toLowerCase();
  Iterable<SeenSpecies> result = entries;
  if (category != null) {
    result = result.where((e) => e.species.category == category);
  }
  if (needle.isNotEmpty) {
    result = result.where((e) => _matches(e.species, needle, nameOf));
  }
  return result.toList()..sort(_comparator(sort, nameOf));
}

bool _matches(Species species, String needle, SpeciesNameOf nameOf) {
  if (nameOf(species).toLowerCase().contains(needle)) return true;
  if (species.commonName.toLowerCase().contains(needle)) return true;
  final scientific = species.scientificName;
  return scientific != null && scientific.toLowerCase().contains(needle);
}

/// Total order on displayed name, then scientific name, then species id.
///
/// The final id tie-break matters: `List.sort` is not stable and the
/// repository query has no `ORDER BY`, so two species sharing a name would
/// otherwise swap places between loads.
int _byName(SeenSpecies a, SeenSpecies b, SpeciesNameOf nameOf) {
  final byName = nameOf(
    a.species,
  ).toLowerCase().compareTo(nameOf(b.species).toLowerCase());
  if (byName != 0) return byName;
  final byScientific = (a.species.scientificName ?? '').toLowerCase().compareTo(
    (b.species.scientificName ?? '').toLowerCase(),
  );
  if (byScientific != 0) return byScientific;
  return a.species.id.compareTo(b.species.id);
}

Comparator<SeenSpecies> _comparator(
  SeenSpeciesSort sort,
  SpeciesNameOf nameOf,
) {
  switch (sort) {
    case SeenSpeciesSort.mostSightings:
      return (a, b) {
        final bySightings = b.totalSightings.compareTo(a.totalSightings);
        if (bySightings != 0) return bySightings;
        final byDives = b.diveCount.compareTo(a.diveCount);
        if (byDives != 0) return byDives;
        return _byName(a, b, nameOf);
      };
    case SeenSpeciesSort.recentlySeen:
      return (a, b) {
        final byLast = b.lastSeen.compareTo(a.lastSeen);
        if (byLast != 0) return byLast;
        return _byName(a, b, nameOf);
      };
    case SeenSpeciesSort.firstSeen:
      return (a, b) {
        final byFirst = a.firstSeen.compareTo(b.firstSeen);
        if (byFirst != 0) return byFirst;
        return _byName(a, b, nameOf);
      };
    case SeenSpeciesSort.name:
      return (a, b) => _byName(a, b, nameOf);
  }
}
