import 'package:submersion/features/equipment/domain/entities/equipment_suggestion.dart';
import 'package:submersion/features/marine_life/domain/services/species_suggestion_url.dart'
    show speciesSuggestionMaxUrlLength, speciesSuggestionRepository;

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
  var name = suggestion.name;
  var reason = suggestion.reason;
  var example = suggestion.example?.trim() ?? '';
  final hasExample = example.isNotEmpty;
  final parent = suggestion.parent;

  Uri build() =>
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
        if (hasExample) 'example': example,
        'locale': locale,
        'app_version': appVersion,
      });

  var uri = build();

  /// Trims one field until the URL fits or the field is down to [floor].
  void shrink(String Function() read, void Function(String) write, int floor) {
    while (uri.toString().length > speciesSuggestionMaxUrlLength &&
        read().length > floor) {
      final over = uri.toString().length - speciesSuggestionMaxUrlLength;
      // Encoded characters can be three bytes each, or more for a character
      // outside the basic plane; cut generously.
      final cut = (over ~/ 3 + 1).clamp(1, read().length - floor);
      write(read().substring(0, read().length - cut));
      uri = build();
    }
  }

  shrink(() => reason, (v) => reason = v, 0);
  shrink(() => example, (v) => example = v, 0);
  shrink(() => name, (v) => name = v, 1);
  return uri;
}
