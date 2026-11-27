import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/text/fuzzy_match.dart' show foldForSearch;
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The extra words a type answers to in [l10n], besides its label: the other
/// words divers use for a cylinder ("tank", "bottle") and for its band.
List<String> _searchWords(AppLocalizations l10n, EquipmentType type) =>
    switch (type) {
      EquipmentType.tank => l10n.equipment_searchWords_cylinder.split(','),
      EquipmentType.tankBand => l10n.equipment_searchWords_tankBand.split(','),
      _ => const [],
    };

/// Every equipment type's words, folded by [foldForSearch], across all of the
/// app's languages, keyed on the type's stored name (issue #5106).
///
/// Matching every language, not just the active one, keeps the compiler
/// locale-free and gives a saved search the same items on every device, as
/// dive types do (issue #2884).
final Map<String, List<String>> _typeWords = Map.unmodifiable({
  for (final type in EquipmentType.values)
    type.name: List<String>.unmodifiable({
      for (final locale in AppLocalizations.supportedLocales)
        for (final word in [
          type.localizedName(lookupAppLocalizations(locale)),
          ..._searchWords(lookupAppLocalizations(locale), type),
        ])
          if (word.trim().isNotEmpty) foldForSearch(word.trim()),
    }),
});

/// The stored names of the equipment types whose label in any app language,
/// or one of whose search words, contains [term], ignoring case, accents and
/// surrounding whitespace.
Set<String> equipmentTypeNamesMatching(String term) {
  final needle = foldForSearch(term.trim());
  if (needle.isEmpty) return const {};
  return {
    for (final MapEntry(key: name, value: words) in _typeWords.entries)
      if (words.any((w) => w.contains(needle))) name,
  };
}

/// An item whose type [equipmentTypeNamesMatching] finds: "tank" or "bottle"
/// finds a cylinder named "AL80", and "regulator" every regulator.
const kEquipmentTypeTextSearch = TextSearchExpansion(
  sql: '{r}.type IN ({values})',
  values: equipmentTypeNamesMatching,
);
