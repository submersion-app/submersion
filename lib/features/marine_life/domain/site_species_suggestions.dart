import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

/// One species the dive editor offers as a one-tap sighting, because other
/// dives at the dive's site logged it or the site's expected list names it
/// (issue #4383).
class SiteSpeciesSuggestion extends Equatable {
  final String speciesId;

  /// The stored common name, which is what a new sighting records.
  final String speciesName;
  final SpeciesCategory category;

  /// Other dives at the site that logged this species; 0 for a species only
  /// the site's expected list names.
  final int diveCount;

  /// Animals recorded across those dives, as `SiteSpeciesSummary.animalCount`
  /// weighs them: it only breaks ties between equal dive counts.
  final int animalCount;

  const SiteSpeciesSuggestion({
    required this.speciesId,
    required this.speciesName,
    required this.category,
    required this.diveCount,
    required this.animalCount,
  });

  /// Named by the site's expected list but never logged there.
  bool get isExpectedOnly => diveCount == 0;

  @override
  List<Object?> get props => [
    speciesId,
    speciesName,
    category,
    diveCount,
    animalCount,
  ];
}

/// Merges what other dives at a site logged with the site's expected list.
///
/// Sighted species come first, the ones seen on the most dives at the top:
/// a school of forty jacks on one dive should not outrank the turtle seen on
/// every dive, so the animal count only breaks ties. Expected species never
/// logged there follow, alphabetically. A species in both lists appears once,
/// as sighted, and anything in [excludeSpeciesIds] (already on the dive) is
/// left out. [displayName] gives the name the diver reads, which is what
/// alphabetical order must follow once names are translated.
List<SiteSpeciesSuggestion> buildSiteSpeciesSuggestions({
  required List<SiteSpeciesSummary> spotted,
  required List<SiteSpeciesEntry> expected,
  required String Function(String speciesId, String speciesName) displayName,
  Set<String> excludeSpeciesIds = const {},
}) {
  final collator = TextCollator();
  int byName(SiteSpeciesSuggestion a, SiteSpeciesSuggestion b) =>
      collator.compare(
        displayName(a.speciesId, a.speciesName),
        displayName(b.speciesId, b.speciesName),
      );

  final sighted =
      [
        for (final s in spotted)
          if (!excludeSpeciesIds.contains(s.speciesId))
            SiteSpeciesSuggestion(
              speciesId: s.speciesId,
              speciesName: s.speciesName,
              category: s.category,
              diveCount: s.diveCount,
              animalCount: s.animalCount,
            ),
      ]..sort((a, b) {
        final byDives = b.diveCount.compareTo(a.diveCount);
        if (byDives != 0) return byDives;
        final byAnimals = b.animalCount.compareTo(a.animalCount);
        if (byAnimals != 0) return byAnimals;
        return byName(a, b);
      });

  final sightedIds = {for (final s in spotted) s.speciesId};
  final expectedOnly = [
    for (final e in expected)
      if (!sightedIds.contains(e.speciesId) &&
          !excludeSpeciesIds.contains(e.speciesId))
        SiteSpeciesSuggestion(
          speciesId: e.speciesId,
          speciesName: e.speciesName,
          category: e.category,
          diveCount: 0,
          animalCount: 0,
        ),
  ]..sort(byName);

  return [...sighted, ...expectedOnly];
}
