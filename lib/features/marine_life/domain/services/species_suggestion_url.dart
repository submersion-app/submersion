import 'package:submersion/features/marine_life/domain/entities/species.dart';

/// Where suggestions land: a prefilled issue form in the project's GitHub
/// repository. The app sends nothing itself; the diver posts the issue from
/// their own account in the browser.
const String speciesSuggestionRepository = 'submersion-app/submersion';

/// The issue form a suggestion fills, under `.github/ISSUE_TEMPLATE/`. Its
/// field ids are the query keys below. The form applies the
/// `species-suggestion` label for every reporter; a `labels=` URL parameter
/// is dropped for anyone who cannot triage the repository, which is how the
/// first suggestions from divers arrived unlabelled (issue #5103).
const String speciesSuggestionTemplate = 'species-suggestion.yml';

/// Browsers and GitHub both accept URLs comfortably below this.
const int speciesSuggestionMaxUrlLength = 8000;

/// Builds the prefilled issue-form URL for [species]. A species with no
/// scientific name or taxonomy class leaves those fields out.
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
        'template': speciesSuggestionTemplate,
        'title': 'Species suggestion: $commonName',
        'common_name': commonName,
        if (species.scientificName != null) 'scientific_name': scientificName,
        'category': species.category.name,
        if (species.taxonomyClass != null) 'taxonomy_class': taxonomyClass,
        'description': description,
        'locale': locale,
        'app_version': appVersion,
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
