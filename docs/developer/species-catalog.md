# Species Catalog

The bundled species catalog is `assets/data/species.json` (685 species at
version 2). Its `version` gates a one-time upgrade pass on each device that
rewrites the catalog rows a diver never edited, so a release can add or correct
species without touching a diver's own changes. The user-facing side is
described in the user guide's
[Marine Life and Photos](../user/marine-life-and-photos.md) page.

## Adding species

1. Add entries to `tool/data/freshwater_species_seed.json` (the generator reads
   only this file), with descriptions in all 11 locales, and add any locale names iNaturalist
   lacks to `tool/data/freshwater_species_name_overrides.json`.
2. Run `dart run tool/generate_freshwater_species.dart` (needs the network). It
   writes the catalog rows and the localized names file and bumps the version.
3. Run, in order:
   - `dart run tool/generate_species_arb_keys.dart`
   - `flutter gen-l10n`
   - `dart run tool/generate_species_lookups.dart`
   - `dart run tool/generate_species_gbif_keys.dart` (needs the network)
4. Run `flutter test test/features/marine_life/presentation/species_lookup_coverage_test.dart`.

## Suggestions from divers

The in-app **Suggest for the catalog** action opens the
`.github/ISSUE_TEMPLATE/species-suggestion.yml` issue form with its fields
filled in (`lib/features/marine_life/domain/services/species_suggestion_url.dart`).
The form applies the `species-suggestion` label for every reporter, so filter
by that label. A field id renamed in the form must be renamed in the builder
too; `species_suggestion_url_test.dart` fails when they disagree. Suggestions
filed before the form (such as #4330 and #4334) carry no label: their titles
start with `Species suggestion:`.
Accepted species go into the seed the same way as above.
