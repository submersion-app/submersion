import 'dart:convert';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

/// Where suggestions land: a prefilled new-issue page in the project's
/// GitHub repository. The app sends nothing itself; the diver posts the
/// issue from their own account in the browser.
const String speciesSuggestionRepository = 'submersion-app/submersion';
const String speciesSuggestionLabel = 'species-suggestion';

/// Browsers and GitHub both accept URLs comfortably below this.
const int speciesSuggestionMaxUrlLength = 8000;

/// Builds the prefilled issue URL for [species]. The body carries a JSON
/// block a maintainer (or a script) can lift straight into the catalog.
///
/// Every field a diver types is free text with no length limit, so any of
/// them can carry the URL past [speciesSuggestionMaxUrlLength]. They give
/// way least-identifying first: the description, then the taxonomy class,
/// then the common name, and the scientific name only as a last resort,
/// because that is what a maintainer needs to act on the suggestion.
Uri buildSpeciesSuggestionUrl({
  required Species species,
  required String locale,
  required String appVersion,
}) {
  var description = species.description ?? '';
  var taxonomyClass = species.taxonomyClass ?? '';
  var commonName = species.commonName;
  var scientificName = species.scientificName ?? '';

  Uri build() =>
      Uri.https('github.com', '/$speciesSuggestionRepository/issues/new', {
        'title': 'Species suggestion: $commonName',
        'labels': speciesSuggestionLabel,
        'body': _body(
          commonName: commonName,
          // A species with no scientific name or class stays null in the
          // JSON, as it was before any truncation.
          scientificName: species.scientificName == null
              ? null
              : scientificName,
          taxonomyClass: species.taxonomyClass == null ? null : taxonomyClass,
          description: description,
          category: species.category,
          locale: locale,
          appVersion: appVersion,
        ),
      });

  var uri = build();

  /// Trims one field until the URL fits or the field is down to [floor].
  void shrink(String Function() read, void Function(String) write, int floor) {
    while (uri.toString().length > speciesSuggestionMaxUrlLength &&
        read().length > floor) {
      final over = uri.toString().length - speciesSuggestionMaxUrlLength;
      // Encoded characters can be three bytes each; cut generously.
      final cut = (over ~/ 3 + 1).clamp(1, read().length - floor);
      write(read().substring(0, read().length - cut));
      uri = build();
    }
  }

  shrink(() => description, (v) => description = v, 0);
  shrink(() => taxonomyClass, (v) => taxonomyClass = v, 0);
  shrink(() => commonName, (v) => commonName = v, 1);
  shrink(() => scientificName, (v) => scientificName = v, 1);
  return uri;
}

String _body({
  required String commonName,
  required String? scientificName,
  required String? taxonomyClass,
  required String description,
  required SpeciesCategory category,
  required String locale,
  required String appVersion,
}) {
  final json = const JsonEncoder.withIndent('  ').convert({
    'commonName': commonName,
    'scientificName': scientificName,
    'category': category.name,
    'taxonomyClass': taxonomyClass,
    'description': description,
    'locale': locale,
    'appVersion': appVersion,
  });
  return 'Please consider adding this species to the bundled catalog.\n\n'
      '```json\n$json\n```\n';
}
