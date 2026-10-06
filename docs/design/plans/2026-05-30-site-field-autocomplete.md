# Dive Site & Location Field Autocomplete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add suggestion-backed autocomplete to dive site name, country, and region fields (plus a near-duplicate hint in the dive-entry site picker) so users stop creating naming variations.

**Architecture:** Three pure, testable primitives — a Sørensen-Dice fuzzy matcher (`fuzzy_match.dart`), distinct-value suggestion helpers (`site_suggestions.dart`), and a bundled ISO 3166 country list — feed two small reusable widgets: `SuggestionField` (a `RawAutocomplete` wrapper preserving external controllers) and `SimilarValueHint` (an inline near-duplicate nudge). These wire into the three site-edit fields and the picker. Suggestions derive from the existing `sitesProvider`; controller-reactive bits use `ValueListenableBuilder`.

**Tech Stack:** Flutter (Material 3), Riverpod (`flutter_riverpod`), Drift (unchanged here), `flutter_test`, Flutter `gen-l10n` (ARB files, 11 locales).

**Spec:** `docs/superpowers/specs/2026-05-30-site-field-autocomplete-design.md`
**Branch:** `feat/site-field-autocomplete`

---

## Deviation from spec (intentional)

The spec described three Riverpod providers (`countrySuggestionsProvider`, `regionSuggestionsProvider.family`, `siteNameSuggestionsProvider`). During planning we found the edit page's shared `_onFieldChanged` listener only rebuilds once (when `_hasChanges` flips), which would make a country-keyed family provider and any controller-reading hint go stale after the first keystroke. This plan instead uses **pure functions over `ref.watch(sitesProvider)`** (`site_suggestions.dart`) and drives controller-reactive scoping/hints with `ValueListenableBuilder`. Same data source, same behavior, simpler, and no staleness. All other spec decisions are unchanged.

---

## File Structure

**Create:**
- `lib/core/text/fuzzy_match.dart` — pure text similarity: `normalize`, `diceCoefficient`, `findSimilar`. No Flutter imports.
- `lib/features/dive_sites/domain/constants/iso_countries.dart` — `const List<String> isoCountryNames` (ISO 3166 English names).
- `lib/features/dive_sites/domain/services/site_suggestions.dart` — pure functions `suggestedSiteNames`, `suggestedCountries`, `suggestedRegions` over `List<DiveSite>`.
- `lib/features/dive_sites/presentation/widgets/suggestion_field.dart` — `SuggestionField` widget (RawAutocomplete wrapper).
- `lib/features/dive_sites/presentation/widgets/similar_value_hint.dart` — `SimilarValueHint` widget.
- Tests mirroring each: `test/core/text/fuzzy_match_test.dart`, `test/features/dive_sites/domain/constants/iso_countries_test.dart`, `test/features/dive_sites/domain/services/site_suggestions_test.dart`, `test/features/dive_sites/presentation/widgets/suggestion_field_test.dart`, `test/features/dive_sites/presentation/widgets/similar_value_hint_test.dart`.

**Modify:**
- `lib/l10n/arb/app_en.arb` + 10 locale ARBs — two new keys (`diveSites_similarSite_useHint`, `diveSites_similarSite_warning`).
- `lib/features/dive_sites/presentation/pages/site_edit_page.dart` — name/country/region fields (lines 483-547).
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart` — picker hint (after line 3933).

**Conventions (verified in this codebase):**
- All tests import `package:flutter_test/flutter_test.dart` (even pure-Dart ones).
- Test tree mirrors `lib/` tree.
- Widget tests use `testApp(child:, overrides:)` from `test/helpers/test_app.dart` (relative import) which wraps in `ProviderScope` + localized `MaterialApp`.
- Localized strings: `context.l10n.<key>` via `package:submersion/l10n/l10n_extension.dart`.
- Run `dart format .` after each task (project requires zero formatting diffs).
- Commit messages: no `Co-Authored-By` line (user preference).

---

## Task 1: Fuzzy matching utility

**Files:**
- Create: `lib/core/text/fuzzy_match.dart`
- Test: `test/core/text/fuzzy_match_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/core/text/fuzzy_match_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/text/fuzzy_match.dart';

void main() {
  group('normalize', () {
    test('trims, lowercases, and strips diacritics', () {
      expect(normalize('  Cancún '), 'cancun');
      expect(normalize('Malapascua'), 'malapascua');
      expect(normalize('ÅÉÎÕÜ'), 'aeiou');
    });
  });

  group('diceCoefficient', () {
    test('identical normalized strings score 1.0', () {
      expect(diceCoefficient('Manta Point', 'manta point'), 1.0);
    });

    test('near-duplicate "Manta Pt" vs "Manta Point" scores above 0.7', () {
      expect(diceCoefficient('Manta Pt', 'Manta Point'), greaterThan(0.7));
    });

    test('unrelated strings score low', () {
      expect(diceCoefficient('Blue Hole', 'Shark Reef'), lessThan(0.3));
    });

    test('sub-2-char inputs fall back to equality', () {
      expect(diceCoefficient('a', 'a'), 1.0);
      expect(diceCoefficient('a', 'b'), 0.0);
    });
  });

  group('findSimilar', () {
    test('returns the best candidate at or above threshold', () {
      final result = findSimilar('Manta Pt', ['Blue Hole', 'Manta Point']);
      expect(result, 'Manta Point');
    });

    test('returns null when nothing meets the threshold', () {
      expect(findSimilar('Atlantis', ['Blue Hole', 'Shark Reef']), isNull);
    });

    test('ties resolve to the earliest-listed candidate', () {
      expect(findSimilar('Reef', ['Reef A', 'Reef B']), 'Reef A');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/text/fuzzy_match_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'submersion' ... fuzzy_match.dart` / "method not found".

- [ ] **Step 3: Write the implementation**

Create `lib/core/text/fuzzy_match.dart`:

```dart
/// Pure text-similarity helpers for suggestion and near-duplicate detection.
///
/// No Flutter imports — unit-testable in isolation.
library;

/// Common accented Latin code points mapped to their ASCII base letter.
const Map<int, String> _diacriticMap = {
  0xE0: 'a', 0xE1: 'a', 0xE2: 'a', 0xE3: 'a', 0xE4: 'a', 0xE5: 'a',
  0xE7: 'c',
  0xE8: 'e', 0xE9: 'e', 0xEA: 'e', 0xEB: 'e',
  0xEC: 'i', 0xED: 'i', 0xEE: 'i', 0xEF: 'i',
  0xF1: 'n',
  0xF2: 'o', 0xF3: 'o', 0xF4: 'o', 0xF5: 'o', 0xF6: 'o', 0xF8: 'o',
  0xF9: 'u', 0xFA: 'u', 0xFB: 'u', 0xFC: 'u',
  0xFD: 'y', 0xFF: 'y',
};

/// Normalizes [input] for comparison: trims, lowercases, and strips common
/// diacritics so "Cancún" and "cancun" compare equal.
String normalize(String input) {
  final lower = input.trim().toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    buffer.write(_diacriticMap[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}

List<String> _bigrams(String s) {
  final result = <String>[];
  for (var i = 0; i < s.length - 1; i++) {
    result.add(s.substring(i, i + 2));
  }
  return result;
}

/// Sørensen-Dice coefficient over character bigrams of the normalized inputs.
///
/// Returns 0.0 (no similarity) to 1.0 (identical). Inputs shorter than two
/// characters fall back to normalized equality.
double diceCoefficient(String a, String b) {
  final na = normalize(a);
  final nb = normalize(b);
  if (na == nb) return 1.0;
  if (na.length < 2 || nb.length < 2) return 0.0;

  final bigramsA = _bigrams(na);
  final bigramsB = _bigrams(nb);
  final used = List<bool>.filled(bigramsB.length, false);

  var intersection = 0;
  for (final bigram in bigramsA) {
    for (var i = 0; i < bigramsB.length; i++) {
      if (!used[i] && bigramsB[i] == bigram) {
        used[i] = true;
        intersection++;
        break;
      }
    }
  }
  return (2.0 * intersection) / (bigramsA.length + bigramsB.length);
}

/// Returns the candidate most similar to [input] whose Dice score is at or
/// above [threshold], or null if none qualify. Ties resolve to the
/// earliest-listed candidate.
String? findSimilar(
  String input,
  Iterable<String> candidates, {
  double threshold = 0.7,
}) {
  String? best;
  var bestScore = threshold;
  for (final candidate in candidates) {
    final score = diceCoefficient(input, candidate);
    if (score >= bestScore && (best == null || score > bestScore)) {
      best = candidate;
      bestScore = score;
    }
  }
  return best;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/text/fuzzy_match_test.dart`
Expected: PASS (all 9 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/core/text/fuzzy_match.dart test/core/text/fuzzy_match_test.dart
git add lib/core/text/fuzzy_match.dart test/core/text/fuzzy_match_test.dart
git commit -m "feat(text): add Sorensen-Dice fuzzy matching utility"
```

---

## Task 2: ISO 3166 country constant

**Files:**
- Create: `lib/features/dive_sites/domain/constants/iso_countries.dart`
- Test: `test/features/dive_sites/domain/constants/iso_countries_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_sites/domain/constants/iso_countries_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/constants/iso_countries.dart';

void main() {
  group('isoCountryNames', () {
    test('contains a broad set of countries', () {
      expect(isoCountryNames.length, greaterThan(150));
    });

    test('includes common diving destinations', () {
      expect(isoCountryNames, contains('Indonesia'));
      expect(isoCountryNames, contains('Egypt'));
      expect(isoCountryNames, contains('Philippines'));
      expect(isoCountryNames, contains('United States'));
      expect(isoCountryNames, contains('Mexico'));
    });

    test('has no duplicates', () {
      expect(isoCountryNames.toSet().length, isoCountryNames.length);
    });

    test('is sorted alphabetically', () {
      final sorted = [...isoCountryNames]..sort();
      expect(isoCountryNames, sorted);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/domain/constants/iso_countries_test.dart`
Expected: FAIL — unresolved import / `isoCountryNames` not defined.

- [ ] **Step 3: Write the implementation**

Create `lib/features/dive_sites/domain/constants/iso_countries.dart`. Use the common English short names (sorted). This list is reference data for the hybrid country suggestions:

```dart
/// English short names of countries (ISO 3166), used as fallback suggestions
/// for the dive-site country field. Reference data; kept alphabetically sorted.
const List<String> isoCountryNames = [
  'Afghanistan', 'Albania', 'Algeria', 'Andorra', 'Angola',
  'Antigua and Barbuda', 'Argentina', 'Armenia', 'Australia', 'Austria',
  'Azerbaijan', 'Bahamas', 'Bahrain', 'Bangladesh', 'Barbados', 'Belarus',
  'Belgium', 'Belize', 'Benin', 'Bhutan', 'Bolivia',
  'Bosnia and Herzegovina', 'Botswana', 'Brazil', 'Brunei', 'Bulgaria',
  'Burkina Faso', 'Burundi', 'Cambodia', 'Cameroon', 'Canada', 'Cape Verde',
  'Central African Republic', 'Chad', 'Chile', 'China', 'Colombia',
  'Comoros', 'Congo', 'Costa Rica', 'Croatia', 'Cuba', 'Cyprus', 'Czechia',
  'Democratic Republic of the Congo', 'Denmark', 'Djibouti', 'Dominica',
  'Dominican Republic', 'Ecuador', 'Egypt', 'El Salvador',
  'Equatorial Guinea', 'Eritrea', 'Estonia', 'Eswatini', 'Ethiopia', 'Fiji',
  'Finland', 'France', 'Gabon', 'Gambia', 'Georgia', 'Germany', 'Ghana',
  'Greece', 'Grenada', 'Guatemala', 'Guinea', 'Guinea-Bissau', 'Guyana',
  'Haiti', 'Honduras', 'Hungary', 'Iceland', 'India', 'Indonesia', 'Iran',
  'Iraq', 'Ireland', 'Israel', 'Italy', 'Ivory Coast', 'Jamaica', 'Japan',
  'Jordan', 'Kazakhstan', 'Kenya', 'Kiribati', 'Kuwait', 'Kyrgyzstan',
  'Laos', 'Latvia', 'Lebanon', 'Lesotho', 'Liberia', 'Libya',
  'Liechtenstein', 'Lithuania', 'Luxembourg', 'Madagascar', 'Malawi',
  'Malaysia', 'Maldives', 'Mali', 'Malta', 'Marshall Islands', 'Mauritania',
  'Mauritius', 'Mexico', 'Micronesia', 'Moldova', 'Monaco', 'Mongolia',
  'Montenegro', 'Morocco', 'Mozambique', 'Myanmar', 'Namibia', 'Nauru',
  'Nepal', 'Netherlands', 'New Zealand', 'Nicaragua', 'Niger', 'Nigeria',
  'North Korea', 'North Macedonia', 'Norway', 'Oman', 'Pakistan', 'Palau',
  'Palestine', 'Panama', 'Papua New Guinea', 'Paraguay', 'Peru',
  'Philippines', 'Poland', 'Portugal', 'Qatar', 'Romania', 'Russia',
  'Rwanda', 'Saint Kitts and Nevis', 'Saint Lucia',
  'Saint Vincent and the Grenadines', 'Samoa', 'San Marino',
  'Sao Tome and Principe', 'Saudi Arabia', 'Senegal', 'Serbia', 'Seychelles',
  'Sierra Leone', 'Singapore', 'Slovakia', 'Slovenia', 'Solomon Islands',
  'Somalia', 'South Africa', 'South Korea', 'South Sudan', 'Spain',
  'Sri Lanka', 'Sudan', 'Suriname', 'Sweden', 'Switzerland', 'Syria',
  'Taiwan', 'Tajikistan', 'Tanzania', 'Thailand', 'Timor-Leste', 'Togo',
  'Tonga', 'Trinidad and Tobago', 'Tunisia', 'Turkey', 'Turkmenistan',
  'Tuvalu', 'Uganda', 'Ukraine', 'United Arab Emirates', 'United Kingdom',
  'United States', 'Uruguay', 'Uzbekistan', 'Vanuatu', 'Vatican City',
  'Venezuela', 'Vietnam', 'Yemen', 'Zambia', 'Zimbabwe',
];
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/domain/constants/iso_countries_test.dart`
Expected: PASS. If the "is sorted" test fails, sort the list and re-run (the list above is pre-sorted; this guards typos).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/dive_sites/domain/constants/iso_countries.dart test/features/dive_sites/domain/constants/iso_countries_test.dart
git add lib/features/dive_sites/domain/constants/iso_countries.dart test/features/dive_sites/domain/constants/iso_countries_test.dart
git commit -m "feat(dive-sites): add ISO 3166 country name constant"
```

---

## Task 3: Suggestion helper functions

**Files:**
- Create: `lib/features/dive_sites/domain/services/site_suggestions.dart`
- Test: `test/features/dive_sites/domain/services/site_suggestions_test.dart`

Context: `DiveSite` has `final String id`, `final String name`, `final String? country`, `final String? region` (verified). Import path: `package:submersion/features/dive_sites/domain/entities/dive_site.dart`.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_sites/domain/services/site_suggestions_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_suggestions.dart';

DiveSite _site({
  required String id,
  required String name,
  String? country,
  String? region,
}) {
  return DiveSite(id: id, name: name, country: country, region: region);
}

void main() {
  final sites = [
    _site(id: '1', name: 'Manta Point', country: 'Indonesia', region: 'Bali'),
    _site(id: '2', name: 'Blue Hole', country: 'Egypt', region: 'Dahab'),
    _site(id: '3', name: 'Crystal Bay', country: 'Indonesia', region: 'Nusa Penida'),
  ];

  group('suggestedSiteNames', () {
    test('returns distinct names sorted case-insensitively', () {
      expect(suggestedSiteNames(sites), ['Blue Hole', 'Crystal Bay', 'Manta Point']);
    });

    test('excludes the site with excludeId', () {
      expect(suggestedSiteNames(sites, excludeId: '1'), ['Blue Hole', 'Crystal Bay']);
    });
  });

  group('suggestedCountries', () {
    test('lists the user countries first (alpha), then ISO extras', () {
      final result = suggestedCountries(sites);
      expect(result.take(2), ['Egypt', 'Indonesia']);
      // ISO extras follow and exclude already-used countries.
      expect(result, contains('Mexico'));
      expect(result.where((c) => c == 'Egypt').length, 1);
    });
  });

  group('suggestedRegions', () {
    test('scopes regions to the given country', () {
      expect(suggestedRegions(sites, 'Indonesia'), ['Bali', 'Nusa Penida']);
      expect(suggestedRegions(sites, 'Egypt'), ['Dahab']);
    });

    test('returns all distinct regions when country is empty', () {
      expect(suggestedRegions(sites, ''), ['Bali', 'Dahab', 'Nusa Penida']);
    });

    test('country match is case-insensitive', () {
      expect(suggestedRegions(sites, 'indonesia'), ['Bali', 'Nusa Penida']);
    });
  });
}
```

> Note: the `DiveSite` constructor has additional required/optional fields. If the constructor in `dive_site.dart` requires more than `id`/`name` (e.g. `description`, `notes`), add the minimal required args to `_site(...)` to satisfy it — open `lib/features/dive_sites/domain/entities/dive_site.dart` and match the constructor. The test intent (distinct/sorted/scoped) does not change.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/domain/services/site_suggestions_test.dart`
Expected: FAIL — unresolved import / functions not defined.

- [ ] **Step 3: Write the implementation**

Create `lib/features/dive_sites/domain/services/site_suggestions.dart`:

```dart
import 'package:submersion/features/dive_sites/domain/constants/iso_countries.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Distinct, alpha-sorted site names from [sites], optionally excluding the
/// site with [excludeId] (so a site being edited never suggests/flags itself).
List<String> suggestedSiteNames(List<DiveSite> sites, {String? excludeId}) {
  final seen = <String>{};
  final names = <String>[];
  for (final site in sites) {
    if (excludeId != null && site.id == excludeId) continue;
    final name = site.name.trim();
    if (name.isEmpty) continue;
    if (seen.add(name.toLowerCase())) names.add(name);
  }
  names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return names;
}

/// Hybrid country suggestions: the user's distinct countries first (alpha),
/// then ISO 3166 country names not already used (alpha).
List<String> suggestedCountries(List<DiveSite> sites) {
  final seen = <String>{};
  final userCountries = <String>[];
  for (final site in sites) {
    final country = site.country?.trim() ?? '';
    if (country.isEmpty) continue;
    if (seen.add(country.toLowerCase())) userCountries.add(country);
  }
  userCountries.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  final extras =
      isoCountryNames.where((c) => !seen.contains(c.toLowerCase())).toList();
  return [...userCountries, ...extras];
}

/// Distinct, alpha-sorted regions from [sites]. When [country] is non-empty,
/// only regions used with that country (case-insensitive) are returned;
/// otherwise all distinct regions.
List<String> suggestedRegions(List<DiveSite> sites, String country) {
  final wanted = country.trim().toLowerCase();
  final seen = <String>{};
  final regions = <String>[];
  for (final site in sites) {
    final region = site.region?.trim() ?? '';
    if (region.isEmpty) continue;
    if (wanted.isNotEmpty &&
        (site.country?.trim().toLowerCase() ?? '') != wanted) {
      continue;
    }
    if (seen.add(region.toLowerCase())) regions.add(region);
  }
  regions.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return regions;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/domain/services/site_suggestions_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/dive_sites/domain/services/site_suggestions.dart test/features/dive_sites/domain/services/site_suggestions_test.dart
git add lib/features/dive_sites/domain/services/site_suggestions.dart test/features/dive_sites/domain/services/site_suggestions_test.dart
git commit -m "feat(dive-sites): add distinct-value suggestion helpers"
```

---

## Task 4: Localization strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb`
- Modify: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Generated (committed): `lib/l10n/arb/app_localizations*.dart`

This task adds two keys with a `{siteName}` placeholder. Per project memory, **every** non-en locale must be translated, not left as English. Insert each key in alphabetical order (keys sort by name; `@key` metadata sorts immediately after its `key`). The `diveSites_similarSite_*` keys sort right after the existing `diveSites_si...`/before `diveSites_sort...` block — place them among the `diveSites_` keys near other `diveSites_` entries.

- [ ] **Step 1: Add the English template keys**

In `lib/l10n/arb/app_en.arb`, add (with metadata):

```json
  "diveSites_similarSite_useHint": "Similar to existing site \"{siteName}\". Tap to use.",
  "@diveSites_similarSite_useHint": {
    "description": "Tappable hint in the dive-entry site picker when the typed query closely matches an existing site name that is not already in the list",
    "placeholders": {
      "siteName": { "type": "Object", "description": "The existing site name" }
    }
  },
  "diveSites_similarSite_warning": "A similar site already exists: \"{siteName}\"",
  "@diveSites_similarSite_warning": {
    "description": "Passive warning under the site name field when the typed name closely matches an existing site",
    "placeholders": {
      "siteName": { "type": "Object", "description": "The existing site name" }
    }
  },
```

- [ ] **Step 2: Add translations to each locale ARB (no `@meta` needed for simple placeholder keys)**

Add these two keys to each file. Keep `{siteName}` verbatim. Verify the word for "dive site" matches each locale's existing `diveSites_*` translations; adjust if that locale uses a specific term.

`app_ar.arb`:
```json
  "diveSites_similarSite_useHint": "مشابه لموقع غوص موجود \"{siteName}\". انقر للاستخدام.",
  "diveSites_similarSite_warning": "يوجد بالفعل موقع مشابه: \"{siteName}\"",
```
`app_de.arb`:
```json
  "diveSites_similarSite_useHint": "Ähnelt vorhandenem Tauchplatz „{siteName}“. Zum Verwenden tippen.",
  "diveSites_similarSite_warning": "Ein ähnlicher Tauchplatz existiert bereits: „{siteName}“",
```
`app_es.arb`:
```json
  "diveSites_similarSite_useHint": "Similar a un sitio de buceo existente \"{siteName}\". Toca para usar.",
  "diveSites_similarSite_warning": "Ya existe un sitio similar: \"{siteName}\"",
```
`app_fr.arb`:
```json
  "diveSites_similarSite_useHint": "Similaire à un site de plongée existant « {siteName} ». Appuyez pour l'utiliser.",
  "diveSites_similarSite_warning": "Un site similaire existe déjà : « {siteName} »",
```
`app_he.arb`:
```json
  "diveSites_similarSite_useHint": "דומה לאתר צלילה קיים \"{siteName}\". הקש כדי להשתמש.",
  "diveSites_similarSite_warning": "כבר קיים אתר דומה: \"{siteName}\"",
```
`app_hu.arb`:
```json
  "diveSites_similarSite_useHint": "Hasonló egy meglévő merülőhelyhez: „{siteName}“. Koppintson a használathoz.",
  "diveSites_similarSite_warning": "Már létezik hasonló merülőhely: „{siteName}“",
```
`app_it.arb`:
```json
  "diveSites_similarSite_useHint": "Simile a un sito di immersione esistente \"{siteName}\". Tocca per usare.",
  "diveSites_similarSite_warning": "Esiste già un sito simile: \"{siteName}\"",
```
`app_nl.arb`:
```json
  "diveSites_similarSite_useHint": "Vergelijkbaar met bestaande duiklocatie \"{siteName}\". Tik om te gebruiken.",
  "diveSites_similarSite_warning": "Er bestaat al een vergelijkbare locatie: \"{siteName}\"",
```
`app_pt.arb`:
```json
  "diveSites_similarSite_useHint": "Semelhante a um local de mergulho existente \"{siteName}\". Toque para usar.",
  "diveSites_similarSite_warning": "Já existe um local semelhante: \"{siteName}\"",
```
`app_zh.arb`:
```json
  "diveSites_similarSite_useHint": "与现有潜点\"{siteName}\"相似。点按以使用。",
  "diveSites_similarSite_warning": "已存在相似的潜点：\"{siteName}\"",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: completes; the stdout should NOT list `diveSites_similarSite_*` among untranslated messages for any locale. If it does, the missing locale wasn't added — fix and re-run.

- [ ] **Step 4: Verify the getters compile**

Run: `flutter analyze lib/l10n`
Expected: No issues. Confirm `AppLocalizations` now exposes `diveSites_similarSite_useHint(Object siteName)` and `diveSites_similarSite_warning(Object siteName)` in `lib/l10n/arb/app_localizations.dart`.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/l10n/arb
git add lib/l10n/arb
git commit -m "i18n: add similar-site hint strings across all locales"
```

---

## Task 5: SimilarValueHint widget

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/similar_value_hint.dart`
- Test: `test/features/dive_sites/presentation/widgets/similar_value_hint_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_sites/presentation/widgets/similar_value_hint_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/similar_value_hint.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('SimilarValueHint', () {
    testWidgets('renders nothing when there is no near match', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: const SimilarValueHint(
            query: 'Atlantis',
            candidates: ['Blue Hole', 'Shark Reef'],
          ),
        ),
      );
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows a passive warning when onAccept is null', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: const SimilarValueHint(
            query: 'Manta Pt',
            candidates: ['Manta Point'],
          ),
        ),
      );
      expect(find.textContaining('Manta Point'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('is tappable and reports the match when onAccept is set', (
      tester,
    ) async {
      String? accepted;
      await tester.pumpWidget(
        testApp(
          child: SimilarValueHint(
            query: 'Manta Pt',
            candidates: const ['Manta Point'],
            onAccept: (value) => accepted = value,
          ),
        ),
      );
      expect(find.byType(InkWell), findsOneWidget);
      await tester.tap(find.byType(InkWell));
      expect(accepted, 'Manta Point');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/widgets/similar_value_hint_test.dart`
Expected: FAIL — unresolved import / `SimilarValueHint` not defined.

- [ ] **Step 3: Write the implementation**

Create `lib/features/dive_sites/presentation/widgets/similar_value_hint.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Inline hint shown beneath a name/search field when [query] closely matches
/// an existing value in [candidates].
///
/// When [onAccept] is non-null the hint is tappable ("tap to use") and reports
/// the matched value — used in the dive-entry site picker to select the
/// existing site. When null the hint is a passive warning — used on the site
/// create/edit form, where switching to another site is not possible.
class SimilarValueHint extends StatelessWidget {
  const SimilarValueHint({
    super.key,
    required this.query,
    required this.candidates,
    this.onAccept,
  });

  final String query;
  final List<String> candidates;
  final ValueChanged<String>? onAccept;

  @override
  Widget build(BuildContext context) {
    final match = findSimilar(query, candidates);
    if (match == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final text = onAccept != null
        ? context.l10n.diveSites_similarSite_useHint(match)
        : context.l10n.diveSites_similarSite_warning(match);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.primary),
            ),
          ),
        ],
      ),
    );

    if (onAccept == null) return content;
    return InkWell(onTap: () => onAccept!(match), child: content);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/widgets/similar_value_hint_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/dive_sites/presentation/widgets/similar_value_hint.dart test/features/dive_sites/presentation/widgets/similar_value_hint_test.dart
git add lib/features/dive_sites/presentation/widgets/similar_value_hint.dart test/features/dive_sites/presentation/widgets/similar_value_hint_test.dart
git commit -m "feat(dive-sites): add SimilarValueHint near-duplicate widget"
```

---

## Task 6: SuggestionField widget

**Files:**
- Create: `lib/features/dive_sites/presentation/widgets/suggestion_field.dart`
- Test: `test/features/dive_sites/presentation/widgets/suggestion_field_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_sites/presentation/widgets/suggestion_field_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/suggestion_field.dart';

import '../../../../helpers/test_app.dart';

void main() {
  group('SuggestionField', () {
    testWidgets('shows substring matches as the user types', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: const SuggestionField(
            suggestions: ['Indonesia', 'India', 'Egypt'],
            decoration: InputDecoration(labelText: 'Country'),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'ind');
      await tester.pumpAndSettle();

      expect(find.text('Indonesia'), findsOneWidget);
      expect(find.text('India'), findsOneWidget);
      expect(find.text('Egypt'), findsNothing);
    });

    testWidgets('writes the selection into an external controller', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        testApp(
          child: SuggestionField(
            controller: controller,
            suggestions: const ['Indonesia', 'India'],
            decoration: const InputDecoration(labelText: 'Country'),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'indo');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Indonesia').last);
      await tester.pumpAndSettle();

      expect(controller.text, 'Indonesia');
    });

    testWidgets('surfaces fuzzy near-matches when enableFuzzy is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: const SuggestionField(
            suggestions: ['Manta Point'],
            enableFuzzy: true,
            decoration: InputDecoration(labelText: 'Site'),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Manta Pt');
      await tester.pumpAndSettle();

      expect(find.text('Manta Point'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/widgets/suggestion_field_test.dart`
Expected: FAIL — unresolved import / `SuggestionField` not defined.

- [ ] **Step 3: Write the implementation**

Create `lib/features/dive_sites/presentation/widgets/suggestion_field.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/text/fuzzy_match.dart';

/// A text field with an autocomplete dropdown backed by a fixed [suggestions]
/// list. Wraps [RawAutocomplete] so an external [controller] (and the form
/// validation/decoration around it) is preserved.
///
/// When [enableFuzzy] is true the dropdown also surfaces fuzzy near-matches
/// (ranked by Dice score) below the plain substring matches; otherwise it
/// shows substring matches only. An empty query shows nothing (avoids dumping
/// a long list on focus).
class SuggestionField extends StatefulWidget {
  const SuggestionField({
    super.key,
    required this.suggestions,
    required this.decoration,
    this.controller,
    this.validator,
    this.enableFuzzy = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final List<String> suggestions;
  final InputDecoration decoration;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool enableFuzzy;
  final TextCapitalization textCapitalization;

  @override
  State<SuggestionField> createState() => _SuggestionFieldState();
}

class _SuggestionFieldState extends State<SuggestionField> {
  FocusNode? _focusNode;

  @override
  void initState() {
    super.initState();
    // RawAutocomplete requires controller and focusNode to be both null or
    // both non-null. When the caller supplies a controller we own a focus node
    // to pair with it (we must NOT dispose the external controller).
    if (widget.controller != null) {
      _focusNode = FocusNode();
    }
  }

  @override
  void dispose() {
    _focusNode?.dispose();
    super.dispose();
  }

  Iterable<String> _optionsFor(String text) {
    final query = text.trim();
    if (query.isEmpty) return const Iterable<String>.empty();
    final lower = query.toLowerCase();

    final substring =
        widget.suggestions.where((s) => s.toLowerCase().contains(lower)).toList();
    if (!widget.enableFuzzy) return substring;

    final substringSet = substring.map((s) => s.toLowerCase()).toSet();
    final fuzzy = widget.suggestions
        .where((s) => !substringSet.contains(s.toLowerCase()))
        .map((s) => (s, diceCoefficient(query, s)))
        .where((pair) => pair.$2 >= 0.7)
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return [...substring, ...fuzzy.map((pair) => pair.$1)];
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) => _optionsFor(value.text),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: widget.decoration,
          validator: widget.validator,
          textCapitalization: widget.textCapitalization,
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(option),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/widgets/suggestion_field_test.dart`
Expected: PASS (3 tests). If the "external controller" tap finds two `Indonesia` texts (field + option), `.last` targets the dropdown option — already handled in the test.

- [ ] **Step 5: Format and commit**

```bash
dart format lib/features/dive_sites/presentation/widgets/suggestion_field.dart test/features/dive_sites/presentation/widgets/suggestion_field_test.dart
git add lib/features/dive_sites/presentation/widgets/suggestion_field.dart test/features/dive_sites/presentation/widgets/suggestion_field_test.dart
git commit -m "feat(dive-sites): add SuggestionField autocomplete widget"
```

---

## Task 7: Wire country field on the site edit page

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart`

Context: `_buildForm(BuildContext context, UnitFormatter units)` builds the form. `_countryController` is the external controller; save reads `_countryController.text` (lines 1915-1920) — unchanged. The country field is the first `Expanded` in the Country & Region `Row` (lines 520-532).

- [ ] **Step 1: Add imports**

Near the other local imports at the top of `site_edit_page.dart` (after line 17), add:

```dart
import 'package:submersion/features/dive_sites/domain/services/site_suggestions.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/suggestion_field.dart';
```

- [ ] **Step 2: Read the site list once in `_buildForm`**

Find the start of `_buildForm` (the `Widget _buildForm(BuildContext context, UnitFormatter units) {` line, ~476) and add as its first statement, before `final body = Form(`:

```dart
    final allSites = ref.watch(sitesProvider).value ?? const <DiveSite>[];
```

- [ ] **Step 3: Replace the country field**

Replace the country `Expanded` (lines 520-532, the `Expanded` whose child is the `_countryController` `TextFormField`) with:

```dart
              Expanded(
                child: SuggestionField(
                  controller: _countryController,
                  suggestions: suggestedCountries(allSites),
                  textCapitalization: TextCapitalization.words,
                  decoration: _withMergeTextDecoration(
                    key: 'country',
                    decoration: InputDecoration(
                      labelText: context.l10n.diveSites_edit_field_country_label,
                      prefixIcon: const Icon(Icons.flag),
                    ),
                  ),
                ),
              ),
```

- [ ] **Step 4: Analyze**

Run: `flutter analyze lib/features/dive_sites/presentation/pages/site_edit_page.dart`
Expected: No issues.

- [ ] **Step 5: Manual verification**

Run the app (`flutter run -d macos`), open a dive site for editing or create a new one, focus Country, type "ind" → a dropdown with "India"/"Indonesia" (and ISO entries) appears; selecting one fills the field; saving persists it. Confirm the merge cycle button still appears when entering merge mode.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/dive_sites/presentation/pages/site_edit_page.dart
git add lib/features/dive_sites/presentation/pages/site_edit_page.dart
git commit -m "feat(dive-sites): autocomplete the site country field"
```

---

## Task 8: Wire region field (scoped by country)

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart`

Context: the region field is the second `Expanded` in the same `Row` (lines 534-545). It must re-scope when the country text changes; since the page does not rebuild on every keystroke, wrap it in a `ValueListenableBuilder` on `_countryController`.

- [ ] **Step 1: Replace the region field**

Replace the region `Expanded` (lines 534-545, the `Expanded` whose child is the `_regionController` `TextFormField`) with:

```dart
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _countryController,
                  builder: (context, country, _) {
                    return SuggestionField(
                      controller: _regionController,
                      suggestions: suggestedRegions(allSites, country.text),
                      enableFuzzy: true,
                      textCapitalization: TextCapitalization.words,
                      decoration: _withMergeTextDecoration(
                        key: 'region',
                        decoration: InputDecoration(
                          labelText:
                              context.l10n.diveSites_edit_field_region_label,
                          prefixIcon: const Icon(Icons.map),
                        ),
                      ),
                    );
                  },
                ),
              ),
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze lib/features/dive_sites/presentation/pages/site_edit_page.dart`
Expected: No issues.

- [ ] **Step 3: Manual verification**

In the edit form: set Country to a country you already use (e.g. "Indonesia"), focus Region, type a letter → only regions previously used with Indonesia appear. Clear Country → all regions appear. Type a near-match of an existing region → it still surfaces (fuzzy). Merge cycle button still works in merge mode.

- [ ] **Step 4: Commit**

```bash
dart format lib/features/dive_sites/presentation/pages/site_edit_page.dart
git add lib/features/dive_sites/presentation/pages/site_edit_page.dart
git commit -m "feat(dive-sites): autocomplete the region field, scoped by country"
```

---

## Task 9: Wire site name field + near-duplicate warning

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart`

Context: the name `TextFormField` is at lines 483-499, followed by `const SizedBox(height: 16)` at 500. `_originalSite?.id` excludes the site being edited. The warning must update on every keystroke → `ValueListenableBuilder` on `_nameController`. `onAccept` is omitted (null) so the hint is a passive warning, not "tap to use" (this form cannot switch sites).

- [ ] **Step 1: Add the SimilarValueHint import**

Add near the other widget imports:

```dart
import 'package:submersion/features/dive_sites/presentation/widgets/similar_value_hint.dart';
```

- [ ] **Step 2: Replace the name field**

Replace the name `TextFormField` block (lines 483-499) with a `Column` holding the `SuggestionField` and the warning:

```dart
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SuggestionField(
                controller: _nameController,
                suggestions:
                    suggestedSiteNames(allSites, excludeId: _originalSite?.id),
                enableFuzzy: true,
                textCapitalization: TextCapitalization.words,
                decoration: _withMergeTextDecoration(
                  key: 'name',
                  decoration: InputDecoration(
                    labelText: context.l10n.diveSites_edit_field_siteName_label,
                    prefixIcon: const Icon(Icons.location_on),
                    hintText: context.l10n.diveSites_edit_field_siteName_hint,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.l10n.diveSites_edit_field_siteName_validation;
                  }
                  return null;
                },
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _nameController,
                builder: (context, name, _) {
                  return SimilarValueHint(
                    query: name.text,
                    candidates: suggestedSiteNames(
                      allSites,
                      excludeId: _originalSite?.id,
                    ),
                  );
                },
              ),
            ],
          ),
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/features/dive_sites/presentation/pages/site_edit_page.dart`
Expected: No issues.

- [ ] **Step 4: Manual verification**

Create a new site; type a name close to an existing site (e.g. existing "Manta Point", type "Manta Pt") → the passive warning "A similar site already exists: \"Manta Point\"" appears below the field and updates as you type. Required-field validation still blocks empty save. Editing the existing "Manta Point" itself does NOT warn (self-excluded).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_sites/presentation/pages/site_edit_page.dart
git add lib/features/dive_sites/presentation/pages/site_edit_page.dart
git commit -m "feat(dive-sites): autocomplete site name + warn on near-duplicates"
```

---

## Task 10: Near-duplicate hint in the dive-entry site picker

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_edit_page.dart`

Context: `_SitePickerSheet.build` (lines 3864-4070). `sitesAsync = ref.watch(sitesProvider)` (3866), `normalizedQuery` (3868), `_searchQuery` (3833). The search field Padding ends at line 3933, immediately followed by `const Divider(height: 1)` (3934). The picker rebuilds on every keystroke via `setState` (3931), so the hint can read `_searchQuery` directly. Visible sites use `siteMatchesPickerQuery`; the hint should only surface a match that is NOT already visible. `widget.onSiteSelected(site)` selects and closes.

- [ ] **Step 1: Add imports**

Near the top of `dive_edit_page.dart`, with the other imports, add:

```dart
import 'package:submersion/core/text/fuzzy_match.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/similar_value_hint.dart';
```

(`siteMatchesPickerQuery` and `DiveSite` are already imported.)

- [ ] **Step 2: Insert the hint between the search field and the Divider**

After the search field `Padding` (closing at line 3933) and before `const Divider(height: 1),` (3934), insert:

```dart
        if (_searchQuery.trim().isNotEmpty)
          Builder(
            builder: (context) {
              final sites = sitesAsync.value ?? const <DiveSite>[];
              final hidden = sites
                  .where((s) => !siteMatchesPickerQuery(s, normalizedQuery))
                  .toList();
              final match = findSimilar(_searchQuery, hidden.map((s) => s.name));
              if (match == null) return const SizedBox.shrink();
              final site = hidden.firstWhere((s) => s.name == match);
              return SimilarValueHint(
                query: _searchQuery,
                candidates: [match],
                onAccept: (_) => widget.onSiteSelected(site),
              );
            },
          ),
```

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/features/dive_log/presentation/pages/dive_edit_page.dart`
Expected: No issues.

- [ ] **Step 4: Manual verification**

With an existing site "Manta Point": open a dive, tap to pick a site, type "Manta Pt" in the picker search → the list shows no exact substring match, and the tappable hint "Similar to existing site \"Manta Point\". Tap to use." appears below the search box. Tapping it selects Manta Point and closes the sheet. Typing "Manta" (a real substring) shows the site in the list and the hint does not duplicate it.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_log/presentation/pages/dive_edit_page.dart
git add lib/features/dive_log/presentation/pages/dive_edit_page.dart
git commit -m "feat(dive-log): warn on near-duplicate sites in the picker"
```

---

## Task 11: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Format check (whole project)**

Run: `dart format --set-exit-if-changed lib test`
Expected: exit 0 ("Unchanged"). If it rewrites files, commit the formatting.

- [ ] **Step 2: Analyze (whole project)**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Run the new test suites (specific files, not broad dirs)**

Run each (per project memory, target files to avoid timeouts):
```bash
flutter test test/core/text/fuzzy_match_test.dart
flutter test test/features/dive_sites/domain/constants/iso_countries_test.dart
flutter test test/features/dive_sites/domain/services/site_suggestions_test.dart
flutter test test/features/dive_sites/presentation/widgets/similar_value_hint_test.dart
flutter test test/features/dive_sites/presentation/widgets/suggestion_field_test.dart
```
Expected: all PASS.

- [ ] **Step 4: Run existing regression suites for the touched pages**

```bash
flutter test test/features/dive_sites
flutter test test/features/dive_log
```
Expected: all PASS. If a pre-existing site-edit or picker test breaks, fix the wiring (most likely the field structure changed a `find.byType(TextFormField)` count — update the test to scope to the field under test).

- [ ] **Step 5: Confirm localizations are fully translated**

Run: `flutter gen-l10n`
Expected: no `diveSites_similarSite_*` entries in the untranslated report for any locale.

- [ ] **Step 6: Final commit (only if Steps 1/5 produced changes)**

```bash
git add -A
git commit -m "chore(dive-sites): formatting and l10n regen for site autocomplete"
```

---

## Self-Review

**Spec coverage:**
- Country autocomplete (hybrid user + ISO, substring) → Tasks 2, 3, 6, 7. ✓
- Region autocomplete (fuzzy+substring, scoped by country) → Tasks 3, 6, 8. ✓
- Site name autocomplete (fuzzy+substring, self-excluded) → Tasks 3, 6, 9. ✓
- Inline near-duplicate hint, site name (passive) → Tasks 5, 9. ✓
- Inline near-duplicate hint, picker (actionable, only non-visible matches) → Tasks 5, 10. ✓
- Permissive (free typing always allowed) → `SuggestionField` never constrains input (Task 6). ✓
- Self-contained Sørensen-Dice, diacritic normalization → Task 1. ✓
- i18n across all 10 non-en locales + regen → Task 4, verified Task 11.5. ✓
- Out-of-scope (import dedup, strict mode, picker-list fuzzy, file extraction) → not implemented. ✓
- Edge cases (empty/loading list → no dropdown/hint; cold-start → ISO only) → `SuggestionField._optionsFor` returns empty on empty query; `suggested*` return `[]` for empty input; `findSimilar` returns null → `SizedBox.shrink`. ✓

**Placeholder scan:** No TBD/TODO; all steps contain real code. The only conditional note is the `_site(...)` helper in Task 3 (adjust to the actual `DiveSite` constructor) — that is a concrete instruction, not a placeholder.

**Type consistency:** `findSimilar(String, Iterable<String>, {double threshold})`, `diceCoefficient(String, String)`, `normalize(String)` used identically across Tasks 1/5/6/10. `suggestedCountries(List<DiveSite>)`, `suggestedRegions(List<DiveSite>, String)`, `suggestedSiteNames(List<DiveSite>, {String? excludeId})` used identically across Tasks 3/7/8/9. `SuggestionField({suggestions, decoration, controller?, validator?, enableFuzzy, textCapitalization})` and `SimilarValueHint({query, candidates, onAccept?})` match between their definitions (Tasks 5/6) and all call sites (Tasks 7/8/9/10). l10n getters `diveSites_similarSite_useHint(Object)` / `diveSites_similarSite_warning(Object)` defined in Task 4, consumed in Task 5. ✓

**Scope:** Single, focused feature; appropriate for one plan.
