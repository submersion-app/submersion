import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/marine_life/presentation/species_name_lookup.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Every built-in species' translated common names, lower-cased, across all
/// of the app's languages, keyed on the seed id.
///
/// Built-in species are stored with English names, so a LIKE over
/// `species.common_name` cannot find "Walhai". Matching every language, not
/// just the active one, keeps the compiler locale-free and gives a saved
/// search the same species on every device, as dive types do (issue #2884).
final Map<String, List<String>> _builtInNames = Map.unmodifiable({
  for (final id in kBuiltInSpeciesIds)
    id: List<String>.unmodifiable({
      for (final locale in AppLocalizations.supportedLocales)
        ?builtInSpeciesName(lookupAppLocalizations(locale), id)?.toLowerCase(),
    }),
});

/// The built-in species ids whose translated name, in any app language,
/// contains [term], ignoring case and surrounding whitespace.
Set<String> builtInSpeciesIdsMatching(String term) {
  final needle = term.trim().toLowerCase();
  if (needle.isEmpty) return const {};
  return {
    for (final MapEntry(key: id, value: names) in _builtInNames.entries)
      if (names.any((n) => n.contains(needle))) id,
  };
}

/// A built-in species [builtInSpeciesIdsMatching] finds. A custom species has
/// a UUID id, so it can never be one of the values.
const kSpeciesTranslatedTextSearch = TextSearchExpansion(
  sql: '{r}.id IN ({values})',
  values: builtInSpeciesIdsMatching,
);
