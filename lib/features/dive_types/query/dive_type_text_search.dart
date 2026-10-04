import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/dive_types/presentation/dive_type_display.dart';
import 'package:submersion/features/universal_import/data/csv/transforms/dive_type_mapper.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Every built-in dive type's translated full and short names, lower-cased,
/// across all of the app's languages, keyed on the slug id.
///
/// Built-in types are stored with English names (`kSeedBuiltInDiveTypesSql`),
/// so a LIKE over `dive_types.name` cannot find "Eis" or "Épave". Matching
/// every language, not just the active one, keeps the compiler locale-free
/// and gives a saved search the same dives on every device (issue #2884).
final Map<String, List<String>> _builtInNames = Map.unmodifiable({
  for (final id in kBuiltInDiveTypeIds)
    id: List<String>.unmodifiable({
      for (final locale in AppLocalizations.supportedLocales)
        ...[
          ?builtInDiveTypeName(lookupAppLocalizations(locale), id),
          ?builtInDiveTypeShortName(lookupAppLocalizations(locale), id),
        ].map((n) => n.toLowerCase()),
    }),
});

/// The built-in dive type ids whose translated name or short name, in any app
/// language, contains [term], ignoring case and surrounding whitespace.
Set<String> builtInDiveTypeIdsMatching(String term) {
  final needle = term.trim().toLowerCase();
  if (needle.isEmpty) return const {};
  return {
    for (final MapEntry(key: id, value: names) in _builtInNames.entries)
      if (names.any((n) => n.contains(needle))) id,
  };
}

/// A dive whose types include a built-in one [builtInDiveTypeIdsMatching]
/// finds. A row on a built-in slug that is not itself built in is a diver's
/// own type (see `DiveTypeDisplay.localizedName`) and keeps its own label, so
/// the translations skip it. A junction row whose type row has not synced in
/// yet still counts: its slug is all there is to go on.
const kDiveTypeTranslatedTextSearch = TextSearchExpansion(
  sql:
      'EXISTS (SELECT 1 FROM dive_dive_types tdtx WHERE tdtx.dive_id = {r}.id '
      'AND tdtx.dive_type_id IN ({values}) AND NOT EXISTS (SELECT 1 '
      'FROM dive_types ttyx WHERE ttyx.id = tdtx.dive_type_id '
      'AND ttyx.is_built_in = 0))',
  values: builtInDiveTypeIdsMatching,
);
