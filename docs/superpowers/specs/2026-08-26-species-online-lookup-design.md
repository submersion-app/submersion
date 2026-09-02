# Species online lookup and catalog suggestions. Design

**Status:** design approved in brainstorming 2026-08-26, spec awaiting review
**Branch:** `worktree-species-online-lookup`, cut from `origin/main`;
independent of parts 1 and 2, delivered as one PR.
**Origin:** user feedback on the Marine Life feature, part 3 of 3 ("the
species list that comes with the app is very limited ... crowd-source
missing species or build out the list for all users").

## 1. Problem

The bundled catalog is 511 marine species, hand-authored in
`assets/data/species.json`, seeded with `INSERT OR IGNORE` on every launch
and localized through 1,022 ARB keys per locale plus two hand-maintained
lookup switches. Growing it costs 24 translated strings and two generated
switch arms per species, and a shipped edit to an existing row never reaches
existing installs. Divers work around the gap with custom species, but the
dive picker's "add custom species" creates a name-only row with category
`other` and no scientific name, so custom species are second-class: no
taxonomy, no localized name, no way to tell "Walhai" and "Whale Shark"
apart. Nothing lets a diver hand a missing species back to the project.

## 2. Locked decisions

Made during brainstorming on 2026-08-26, in this order:

1. Direction: **online lookup plus a contribution channel**, not a bigger
   bundled catalog. A custom species becomes catalog-quality at creation
   time, and the maintainer gets a clean feed of suggestions. The bundled
   catalog, its re-seed gap and its generators stay as they are.
2. Source: **iNaturalist** (`https://api.inaturalist.org/v1`). Free read
   API, no key, autocomplete by common or scientific name, common names per
   locale, named ancestry, photos with per-photo licenses.
3. Photos from the lookup are **shown during lookup only**, never stored.
   Only photos with a non-null `license_code` are shown, each with its
   attribution string.
4. Lookups are **explicit**: the diver taps "Look up". No per-keystroke
   requests. The app promises no telemetry in `PRIVACY.md`, data entry
   often happens offline, and streaming keystrokes to a third party is a
   different privacy shape from the reef tier's per-site queries.
5. The contribution channel is a **prefilled GitHub issue** opened in the
   diver's browser from their own account. The app sends nothing itself.
6. One PR.

## 3. Verified API shape (probed 2026-08-26)

`GET /v1/taxa/autocomplete?q=whale%20shark&locale=de&per_page=1` returns
`results[]` with: `id` (52188), `name` ("Rhincodon typus"), `rank`
("species"), `rank_level`, `preferred_common_name` ("Walhai" under
`locale=de`), `english_common_name` ("Whale Shark"), `matched_term`,
`iconic_taxon_name` ("Animalia": too coarse for category mapping),
`ancestor_ids`, `observations_count`, `is_active`, `wikipedia_url`, and
`default_photo` with `license_code` ("cc-by-nc" or null), `attribution`,
`square_url`, `medium_url`.

`GET /v1/taxa/{id}?locale=de` returns `results[0].ancestors[]`, each with
`rank` and `name` (kingdom Animalia, phylum Chordata, class Chondrichthyes,
subclass Elasmobranchii, infraclass Selachii, order Orectolobiformes, family
Rhincodontidae, genus Rhincodon), plus `wikipedia_summary` and
`taxon_photos`. The two probe responses are saved as
`test/fixtures/inaturalist/autocomplete_whale_shark_de.json` and
`taxon_52188_de.json` and are the parser test fixtures.

Consequence: the category mapper needs the named ancestry, so resolving a
hit costs one extra request when the diver selects it, not per result.

## 4. Lookup service

`lib/features/marine_life/data/services/inaturalist_species_lookup_service.dart`

```dart
class INaturalistSpeciesLookupService {
  INaturalistSpeciesLookupService({http.Client? client});
  Future<List<SpeciesLookupHit>> search(String query, {required String locale});
  Future<SpeciesLookupResult> resolve(int taxonId, {required String locale});
}
```

- `package:http`, user agent `Submersion/1.0 (https://submersion.app)` (the
  string the GBIF service sends), 10 second timeout, `per_page=10`,
  `is_active=true`. `locale` is the app's language code.
- `search` maps each result to `SpeciesLookupHit(taxonId, scientificName,
  rank, commonName, matchedTerm, observationCount, photo)` where
  `commonName` is `preferred_common_name`, else `english_common_name`, else
  null, and `photo` is `SpeciesLookupPhoto(squareUrl, attribution)` only when
  `license_code` is non-null. Hits whose `rank_level` is above species
  (genus, family) are returned with `isResolvable == false`.
- `resolve` maps the taxon to `SpeciesLookupResult(commonName,
  scientificName, category, taxonomyClass, taxonId)`: `taxonomyClass` is the
  ancestor with rank `class` (null when absent), `category` comes from the
  mapper in section 5.
- A session-scoped in-memory cache keyed by (query, locale) and by taxon id.
- Failures throw `SpeciesLookupException(kind)` with kinds `offline`,
  `timeout`, `server`, `malformed`; the sheet renders one message per kind
  with a retry. Nothing retries silently.

Entities live in `lib/features/marine_life/domain/entities/species_lookup.dart`
and are immutable `Equatable`s.

## 5. Category mapper (pure)

`lib/features/marine_life/domain/services/species_category_mapper.dart`

`SpeciesCategory speciesCategoryFromAncestry(List<TaxonAncestor> ancestors)`
where `TaxonAncestor` is `(rank, name)`. Rules, first match wins:

| Ancestry | Category |
| --- | --- |
| class `Chondrichthyes` and any of orders `Rajiformes`, `Myliobatiformes`, `Torpediniformes`, `Rhinopristiformes` | `ray` |
| class `Chondrichthyes` otherwise | `shark` |
| class `Actinopterygii` | `fish` |
| class `Mammalia` | `mammal` |
| order `Testudines` | `turtle` |
| class `Anthozoa` and not order `Actiniaria` | `coral` |
| kingdom `Plantae` or kingdom `Chromista` | `plant` |
| class `Aves`, `Reptilia` or `Amphibia` | `other` |
| kingdom `Animalia` otherwise | `invertebrate` |
| anything else | `other` |

Every row has a unit test with a realistic ancestry (whale shark, manta
ray, clownfish, green sea turtle, dolphin, staghorn coral, magnificent
anemone, giant kelp, seagrass, sea snake, nudibranch, unknown).

## 6. Lookup sheet

`lib/features/marine_life/presentation/widgets/species_lookup_sheet.dart`,
opened by `showSpeciesLookupSheet(context, {initialQuery})`, a modal bottom
sheet like the app's other transient panels. Returns a
`SpeciesLookupResult?` (null when dismissed or when the escape hatch is
taken).

- A search field prefilled with `initialQuery`, a "Look up" button (also
  triggered by submit), and a result list. Each row: the licensed photo as
  a 48 px thumbnail with the attribution as its tooltip, or a category
  placeholder when no licensed photo exists; the common name (localized);
  the scientific name in italics; the observation count as a small trailing
  number. Unresolvable ranks render disabled with the rank as subtitle.
- Selecting a row shows a progress state while `resolve` runs, then pops
  with the result.
- Footer: "Species data and photos from iNaturalist".
- "Create without lookup" pops with null so callers keep their offline
  path.
- States: idle (before the first search), loading, empty ("No species found
  for ..."), error per exception kind with retry.

## 7. Entry points

1. **Species edit page** (`species_edit_page.dart`, new and edit): a "Look
   up online" `TextButton.icon` under the common-name field opens the sheet
   with the field's text; a result fills common name, scientific name,
   category and taxonomy class. Description is left alone. The diver can
   still edit anything before saving.
2. **Dive species picker** (`species_picker_sheet.dart`, the "add custom
   species" button shown when a search finds nothing): opens the sheet with
   the query; a result creates the species through
   `SpeciesRepository.createSpecies` with all four fields and selects it in
   the picker; null falls back to today's `getOrCreateSpecies(commonName,
   category: other)` so an offline diver loses nothing.
3. **Reef tier unmatched chips** (`nearby_species_tier.dart`, GBIF names the
   catalog lacks): the chip becomes an `ActionChip`. Tapping it searches the
   scientific name; exactly one resolvable hit whose scientific name matches
   creates the custom species and adds it to the site's expected list (what
   the matched chips already do); anything else opens the sheet with the
   scientific name prefilled and, on a result, does the same two steps.

`getOrCreateSpecies`'s dedupe on `LOWER(common_name)` stays; the new paths
also dedupe on scientific name so looking up a species that already exists
as a built-in selects the built-in instead of creating a twin.

## 8. Contribution channel

`lib/features/marine_life/domain/services/species_suggestion_url.dart`,
pure:

```dart
Uri buildSpeciesSuggestionUrl({
  required Species species,
  required String locale,
  required String appVersion,
});
```

Produces `https://github.com/submersion-app/submersion/issues/new` with
query parameters `title` ("Species suggestion: <common name>"), `labels`
(`species-suggestion`) and `body`: one sentence asking for the species to
be added to the bundled catalog, then a fenced JSON block with `commonName`,
`scientificName`, `category`, `taxonomyClass`, `description`, `locale` and
`appVersion`. The body is capped so the full URL stays under 8,000
characters (description truncated first).

"Suggest for the catalog" is added to the species detail page's app bar
menu for **custom species only** (`isBuiltIn == false`). It launches the URL
with `LaunchMode.externalApplication` and falls back to copying the URL to
the clipboard with a snackbar, the exact behaviour of
`launchReportIssue` in `settings_page.dart`. A maintainer step outside this
PR creates the `species-suggestion` label in the repository.

## 9. Localization

New keys in all 11 locales: `marineLife_lookup_*` (button, sheet title,
search hint, look up, create without lookup, footer attribution, empty,
error per kind, retry, observations count plural, unresolvable
rank hint), `marineLife_speciesDetail_suggestForCatalog`,
`marineLife_suggest_copyLink`, `marineLife_suggest_couldNotOpen`, and
`reef_species_addFromLookup` for the
unmatched chip tooltip. The GitHub issue title and body stay English: the
maintainer reads them.

## 10. Testing

- Parser tests against the two fixtures: every `SpeciesLookupHit` field, the
  German common name, the null-license photo dropped, `isResolvable` by
  rank level, ancestors parsed in order.
- Mapper: one test per rule row plus the two fallbacks.
- Service with a mock `http.Client`: query encoding, locale parameter, user
  agent header, timeout, non-200, malformed JSON, cache hit skips the
  network.
- URL builder: encoding of spaces and non-ASCII names, label, body
  structure, length cap with truncation.
- Widgets with a stubbed service: sheet states and selection; edit page
  fill; picker creates with resolved fields and falls back on null; reef
  chip's single-match path and sheet path; detail page menu hidden for
  built-ins, launches for customs (URL launcher stubbed).
- l10n parity; one full `flutter test` run.

## 11. Out of scope

- Growing the bundled catalog, a versioned re-seed, generators for the two
  lookup switches, freshwater species by default. Documented follow-ups.
- Storing iNaturalist taxon ids, photos, or Wikipedia summaries.
- Automatic per-keystroke search, or any background network activity.
- A maintainer pipeline that turns `species-suggestion` issues into catalog
  entries.
