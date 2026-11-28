import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/shared/utils/longest_fitting_prefix.dart';

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
  Uri build({
    required String commonName,
    required String scientificName,
    required String taxonomyClass,
    required String description,
  }) => Uri.https('github.com', '/$speciesSuggestionRepository/issues/new', {
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

  bool fits(Uri uri) => uri.toString().length <= speciesSuggestionMaxUrlLength;

  var commonName = species.commonName;
  var scientificName = species.scientificName ?? '';
  var taxonomyClass = species.taxonomyClass ?? '';
  var description = species.description ?? '';
  Uri current() => build(
    commonName: commonName,
    scientificName: scientificName,
    taxonomyClass: taxonomyClass,
    description: description,
  );

  /// Trims one field to the longest prefix with which the URL fits.
  String trim(String value, void Function(String) write, {int floor = 0}) =>
      longestFittingPrefix(value, (v) {
        write(v);
        final ok = fits(current());
        write(value);
        return ok;
      }, floor: floor);

  description = trim(description, (v) => description = v);
  taxonomyClass = trim(taxonomyClass, (v) => taxonomyClass = v);
  commonName = trim(commonName, (v) => commonName = v, floor: 1);
  scientificName = trim(scientificName, (v) => scientificName = v, floor: 1);
  return current();
}
