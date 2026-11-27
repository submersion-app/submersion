import 'package:submersion/features/equipment/domain/entities/equipment_suggestion.dart';
import 'package:submersion/features/marine_life/domain/services/species_suggestion_url.dart'
    show speciesSuggestionMaxUrlLength, speciesSuggestionRepository;
import 'package:submersion/shared/utils/longest_fitting_prefix.dart';

/// The issue form a suggestion fills, under `.github/ISSUE_TEMPLATE/`. Its
/// field ids are the query keys below, and its labels are applied by GitHub
/// for every reporter, unlike a `labels=` URL parameter, which GitHub drops
/// for anyone who cannot triage the repository (issue #5103).
const String equipmentSuggestionTemplate = 'equipment-suggestion.yml';

/// Builds the prefilled issue-form URL for [suggestion]. The app sends
/// nothing itself; the diver reviews and posts the issue in their browser.
///
/// Labels are English with the enum name alongside, whatever the app's
/// language, so a maintainer can map the request straight to code; [locale]
/// records the language the diver wrote in.
///
/// The free text gives way when the URL would pass
/// [speciesSuggestionMaxUrlLength]: the reason first, then the example, and
/// the name only as a last resort, because it is what a maintainer acts on.
Uri buildEquipmentSuggestionUrl({
  required EquipmentSuggestion suggestion,
  required String locale,
  required String appVersion,
}) {
  final example = suggestion.example?.trim() ?? '';
  final parent = suggestion.parent;

  Uri build(String name, String reason, String example) =>
      Uri.https('github.com', '/$speciesSuggestionRepository/issues/new', {
        'template': equipmentSuggestionTemplate,
        'title': 'Equipment suggestion: $name',
        'kind': switch (suggestion.kind) {
          EquipmentSuggestionKind.category => 'Category',
          EquipmentSuggestionKind.subcategory => 'Subcategory',
        },
        'name': name,
        'parent': parent == null
            ? 'None'
            : '${parent.displayName} (${parent.name})',
        'reason': reason,
        if (example.isNotEmpty) 'example': example,
        'locale': locale,
        'app_version': appVersion,
      });

  bool fits(Uri uri) => uri.toString().length <= speciesSuggestionMaxUrlLength;

  final reason = longestFittingPrefix(
    suggestion.reason,
    (v) => fits(build(suggestion.name, v, example)),
  );
  // An example trimmed to nothing is left out rather than sent empty.
  final keptExample = longestFittingPrefix(
    example,
    (v) => fits(build(suggestion.name, reason, v)),
  );
  final name = longestFittingPrefix(
    suggestion.name,
    (v) => fits(build(v, reason, keptExample)),
    floor: 1,
  );
  return build(name, reason, keptExample);
}
