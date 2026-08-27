# Dive Site & Location Field Autocomplete — Design

**Issue:** [#292](https://github.com/submersion-app/submersion/issues/292) — Add autocomplete on dive site and location fields to avoid creating variations in naming.

**Branch:** `feat/site-field-autocomplete`

**Date:** 2026-05-30

## Problem

Users enter dive site `name`, `country`, and `region` as unconstrained free text, both on the
site edit page and when assigning a site while logging a dive. This produces naming variations
("USA" vs "United States", "Manta Point" vs "Manta Pt") that fragment the data and weaken
search, filtering, and statistics. The dive-entry site picker also lets a user create a brand-new
site via "+ New site" without any check for an existing near-match, which is the most common way
duplicates are born.

## Goals

- Suggest existing values as the user types in site `name`, `country`, and `region`.
- Catch near-duplicates (fuzzy) at the two moments a duplicate is created: typing a new site name
  on the edit page, and the "+ New site" flow in the picker.
- Keep entry permissive — suggestions are hints, never hard constraints.

## Non-Goals (explicit out of scope)

- Strengthening import-path site dedup for *selected* sites (UDDF/Subsurface). This is a separate,
  sensitive concern tracked elsewhere; not touched here.
- Strict/locked country mode (force selection from a list).
- Fuzzy matching inside the picker's main results list (the picker keeps its existing substring
  list; fuzzy is surfaced only via the inline hint).
- Refactoring/extracting the picker out of `dive_edit_page.dart`. The file is large (~4600 lines),
  but extraction is unrelated to this issue and carries regression risk; noted as a known issue.

## Decisions (from brainstorming)

| Decision | Choice |
| --- | --- |
| Fields in scope | site name, country, region (edit page) + dive-entry site picker |
| Country suggestion source | Hybrid: user's existing countries first, then ISO 3166 names |
| Strictness | Permissive — suggestions are hints; free typing always allowed |
| Region scoping | Scoped by selected country; falls back to all regions if no country |
| Match style (dropdown) | Fuzzy + substring for name/region; substring for country |
| Duplicate surfacing | Inline helper text as the user types (non-blocking) |
| Duplicate UX locations | Site name (edit page) and picker "+ New site" |

## Architecture

The feature reduces to three shared primitives reused across all four touchpoints: a list of
candidate strings, a substring/fuzzy filter for the dropdown, and a fuzzy "did you mean" detector
for the inline hint. Build once, wire in four places.

### New files

| File | Responsibility |
| --- | --- |
| `lib/core/text/fuzzy_match.dart` | Pure functions: `normalize`, `diceCoefficient`, `findSimilar`. No Flutter imports. |
| `lib/features/dive_sites/domain/constants/iso_countries.dart` | `const List<String>` of ~250 English ISO 3166 country names. |
| `lib/features/dive_sites/presentation/providers/site_suggestion_providers.dart` | Three derived Riverpod providers feeding suggestion lists. |
| `lib/features/dive_sites/presentation/widgets/suggestion_field.dart` | Shared autocomplete field wrapping `RawAutocomplete<String>`; supports an optional external controller/focusNode. |
| `lib/features/dive_sites/presentation/widgets/similar_value_hint.dart` | Stateless inline "Similar to existing: X — tap to use" widget. |

### Why `RawAutocomplete`, not `Autocomplete`

The site edit page drives its fields with **external** controllers (`_nameController`,
`_countryController`, `_regionController`) and wraps each field's `InputDecoration` through a
`_withMergeTextDecoration(...)` helper that is part of the GPS site-matching "merge" subsystem
(`_initializeMergeTextField`, site_edit_page.dart:181-208). Flutter's high-level
`Autocomplete<String>` creates and owns its own internal controller, which cannot be replaced — so
it would collide with both the external controllers and the merge decoration.

`RawAutocomplete<String>` accepts `textEditingController:` and `focusNode:` and gives full control
of the `fieldViewBuilder`, so the existing `TextFormField` + merge decoration is rebuilt verbatim
inside it. There is precedent in the codebase: `import_tags_field.dart` already uses
`RawAutocomplete`.

The shared `SuggestionField` defaults to creating its own controller when the caller does not
supply one, so it also serves fresh fields that have no external controller. The lightweight
`Autocomplete<String>` pattern from `custom_field_input_row.dart` is the conceptual model for the
no-external-controller case.

## Components & integration

Mapping of each touchpoint to the shared components:

| Touchpoint | Location | Dropdown filter | Inline hint |
| --- | --- | --- | --- |
| Country | site_edit_page.dart:521 | substring over hybrid list | — |
| Region | site_edit_page.dart:535 | fuzzy + substring, scoped to selected country | — |
| Site name | site_edit_page.dart:483 | fuzzy + substring, excluding current site | yes (excludes current site) |
| Picker search | dive_edit_page.dart:3912 | keeps existing `siteMatchesPickerQuery` substring list | yes (only near-misses the list did not surface) |

### Edit-page fields

Each becomes a `RawAutocomplete<String>` driven by its existing controller. The `fieldViewBuilder`
rebuilds the same `TextFormField` + `_withMergeTextDecoration(key: ...)` it has today, so the merge
feature is untouched. The `optionsViewBuilder` renders a Material dropdown styled to match
`import_tags_field.dart`. The save path (site_edit_page.dart:1915) is unchanged.

### Region scoping

`regionSuggestionsProvider` is a `Provider.family<List<String>, String>` keyed by country text
('' = no country → all regions). The region field reads `_countryController.text` to choose the
key and rebuilds when country changes (the page already listens to its controllers via
`_onFieldChanged`).

### Site-name self-exclusion

When editing an existing site, that site's own name is filtered out of both the dropdown and the
hint candidates at the widget level (the providers stay generic), so a site never flags itself as a
duplicate.

### Picker hint

The picker is a modal bottom sheet built inline in `dive_edit_page.dart`. It searches via
`siteMatchesPickerQuery` (substring) and signals "create new" with the sentinel
`_createNewSiteSentinel = '__create_new__'` (dive_edit_page.dart:60, popped at :1155, handled at
:1161). The `SimilarValueHint` is rendered above the "+ New site" affordance and fires only when
`findSimilar(query)` returns a match that is **not already** in the visible substring list (e.g.
user typed "Manta Pt", list is empty, "Manta Point" exists). Tapping it selects the existing site
instead of creating a new one. The modal structure and the map/GPS affordances are unchanged.

## Data flow

The suggestion providers are derived synchronous providers over the existing
`sitesProvider` (`FutureProvider<List<DiveSite>>`), following the established
`filteredSitesWithCountsProvider` idiom (read `.value ?? const []`, degrade gracefully while
loading). They recompute automatically when a site is added/edited because `SiteListNotifier`
invalidates `sitesProvider`.

```dart
// Hybrid: user's distinct countries first, then ISO 3166 names not already used.
final countrySuggestionsProvider = Provider<List<String>>(...);

// Region scoped by country; '' = no country selected → all regions.
final regionSuggestionsProvider = Provider.family<List<String>, String>(...);

// All distinct site names; the widget excludes the current site before use.
final siteNameSuggestionsProvider = Provider<List<String>>(...);
```

Per-keystroke flow (region field, the richest case):

1. User types → `_regionController` fires `_onFieldChanged` → page rebuilds.
2. Region `RawAutocomplete` reads `_countryController.text`, watches `regionSuggestionsProvider(country)`.
3. `optionsBuilder` returns substring matches unioned with fuzzy matches above threshold, ranked
   by `diceCoefficient` (exact/substring first, then fuzzy by descending score) → dropdown shows
   the ranked list. (Country's `optionsBuilder` is substring-only — no fuzzy union.)
4. On select/type, the controller updates as today; the save logic is unchanged.

## Fuzzy matching

`fuzzy_match.dart`, pure Dart, no new dependency:

- `normalize(s)`: trim → lowercase → strip diacritics, so "Cancún" ≡ "cancun". This also fixes a
  gap in the current picker search, which lowercases but does not strip diacritics.
- `diceCoefficient(a, b)`: Sørensen-Dice coefficient over character bigrams, 0.0–1.0. Strings
  shorter than 2 characters fall back to normalized equality (no bigrams to compare).
- `findSimilar(input, candidates, {threshold = 0.7})`: returns the highest-scoring candidate above
  the threshold, or null.

Two distinct consumers: the **dropdown** (name/region) ranks its candidate list — substring
matches unioned with above-threshold fuzzy matches — using `diceCoefficient`; the **inline hint**
uses `findSimilar` to pick the single best near-duplicate. Country uses neither fuzzy path; its
dropdown is a plain substring filter.

Rationale for a self-contained implementation over the `string_similarity` package: the algorithm
is ~40 lines and well understood, it keeps the dependency surface minimal, and it lets normalization
(diacritic stripping) live in the same place. Swapping in a package later is a localized change.

## Error handling & edge cases

- **Empty/loading site list:** providers return `[]`; fields behave as plain text inputs (no
  dropdown, no hint). No spinner.
- **Cold-start (new user):** country dropdown still works from the ISO list; region/name have
  nothing to suggest yet. Acceptable.
- **Picker hint overlap:** hint fires only for a `findSimilar` match not already in the visible
  list, so it never duplicates a shown result.
- **Self-exclusion:** site-name dropdown and hint exclude the site being edited.
- **Performance:** distinct-value computation is O(n) over sites; bigram fuzzy match is cheap.
  Typical logs are 10s–100s of sites. No debounce required.
- **Diacritics/whitespace:** normalized consistently via `fuzzy_match.normalize`.

## Testing (TDD, 80% minimum coverage)

- `test/core/text/fuzzy_match_test.dart` — dice values, threshold boundaries, case/diacritic
  normalization, sub-2-char fallback, `findSimilar` ranking and null result. (Pure functions are
  the highest-value tests.)
- `test/.../site_suggestion_providers_test.dart` — hybrid country ordering (user values first),
  region scoping by country, distinctness, empty-state behavior.
- Widget tests — `SimilarValueHint` renders and taps; `SuggestionField` filters options and
  respects an injected external controller.
- Regression — existing `site_edit_page` and dive-entry picker tests must still pass, guarding the
  merge subsystem.

## Internationalization

New UI strings (the inline hint label, "tap to use", any "+ New site" duplicate copy) are added to
`app_en.arb` and **translated across all 10 non-en locales**, then regenerated with
`flutter gen-l10n`. ISO 3166 country names remain English-only — they are reference data, and the
hybrid's user-data half captures any localized spelling a diver actually types.

## File-size note

`dive_edit_page.dart` is ~4600 lines, well over the project's 800-line guideline. The picker hint
is added in place rather than triggering an extraction, which would be unrelated to this issue and
carry regression risk. Extraction is left as a separate follow-up.
