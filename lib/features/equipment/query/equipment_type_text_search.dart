import 'package:meta/meta.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/text/fuzzy_match.dart' show foldForSearch;
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The extra words a type answers to in [l10n], besides its label: the other
/// words divers use for a cylinder ("tank", "bottle") and for its band.
List<String> _searchWords(AppLocalizations l10n, EquipmentType type) =>
    switch (type) {
      EquipmentType.tank => splitSearchWords(
        l10n.equipment_searchWords_cylinder,
      ),
      EquipmentType.tankBand => splitSearchWords(
        l10n.equipment_searchWords_tankBand,
      ),
      _ => const [],
    };

/// A translator's comma list of search words, split on the comma of any app
/// language (`,` `،` `、` `，`), trimmed, empty pieces dropped.
@visibleForTesting
List<String> splitSearchWords(String list) => [
  for (final word in list.split(RegExp('[,\u060C\u3001\uFF0C]')))
    if (word.trim().isNotEmpty) word.trim(),
];

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

/// Scripts written without spaces between words (Chinese, Japanese,
/// Korean): a term there may sit anywhere in a label.
final _unspacedScript = RegExp(r'[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]');

final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// Shorter terms would reach most types through words of other languages
/// the diver never sees ("al" is in a dozen labels); the item's own name,
/// brand and model still match them.
const _minimumTermLength = 3;

/// Whether [needle] starts a word of [label]. In an unspaced script it may
/// sit anywhere.
bool _startsAWord(String label, String needle) {
  if (_unspacedScript.hasMatch(needle)) return label.contains(needle);
  if (needle.length < _minimumTermLength) return false;
  for (
    var i = label.indexOf(needle);
    i >= 0;
    i = label.indexOf(needle, i + 1)
  ) {
    if (i == 0 || !_letterOrDigit.hasMatch(label[i - 1])) return true;
  }
  return false;
}

/// The stored names of the equipment types whose label in any app language,
/// or one of whose search words, has a word starting with [term], ignoring
/// case, accents and surrounding whitespace.
Set<String> equipmentTypeNamesMatching(String term) {
  final needle = foldForSearch(term.trim());
  if (needle.isEmpty) return const {};
  return {
    for (final MapEntry(key: name, value: words) in _typeWords.entries)
      if (words.any((w) => _startsAWord(w, needle))) name,
  };
}

/// An item whose type [equipmentTypeNamesMatching] finds: "tank" or "bottle"
/// finds a cylinder named "AL80", and "regulator" every regulator.
const kEquipmentTypeTextSearch = TextSearchExpansion(
  sql: '{r}.type IN ({values})',
  values: equipmentTypeNamesMatching,
);
