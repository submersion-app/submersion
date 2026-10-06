# Species Online Lookup and Catalog Suggestions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a diver adds a species, let them look it up on iNaturalist so the custom species gets a localized common name, scientific name, taxonomy class and category; and let them suggest a custom species for the bundled catalog through a prefilled GitHub issue.

**Architecture:** A small `http`-backed `INaturalistSpeciesLookupService` (autocomplete, then one taxon fetch on selection) behind an abstract `SpeciesLookupService` so widgets are tested with a fake; a pure category mapper over the taxon's named ancestry; one modal `SpeciesLookupSheet` reused by three entry points (species edit page, dive species picker, reef tier's unmatched chips); a pure suggestion-URL builder and a launcher with the Settings page's clipboard fallback. No schema change, nothing stored from iNaturalist.

**Tech Stack:** Flutter, Riverpod, `package:http` (+ `package:http/testing.dart` `MockClient`), `url_launcher`, `flutter gen-l10n`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-08-26-species-online-lookup-design.md`

## Global Constraints

- Work only in `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup` on branch `worktree-species-online-lookup` (cut from `origin/main` dd6b435f62a, codegen already run). Paths are relative to that root; `flutter analyze` prints `Analyzing species-online-lookup...` when it runs in the right tree.
- **No schema change**, and nothing from iNaturalist is stored: no taxon ids, no photo URLs, no summaries. Photos are shown in lookup results only, and only when `license_code` is non-null, with their attribution.
- **Explicit lookups only**: a request is sent when the diver taps "Look up" (or submits the field). Never per keystroke. No background retries.
- Source endpoints: `https://api.inaturalist.org/v1/taxa/autocomplete` and `https://api.inaturalist.org/v1/taxa/{id}`, user agent `Submersion/1.0 (https://submersion.app)`, 10 second timeout.
- The contribution channel is a prefilled GitHub issue URL opened in the external browser; the app sends nothing itself.
- No em-dashes anywhere; no emojis in code or docs. Immutable `Equatable` entities with `copyWith`. Imports grouped dart, flutter, packages, local. Files under 800 lines.
- Tests first; run single files with `flutter test <file>` and check the exit code, never through a pipe.
- Localization: every user-visible string is an ARB key in all 11 locales (`ar de en es fr he hu it nl pt zh`); regenerated `lib/l10n/arb/app_localizations*.dart` files are committed with the ARB change. The GitHub issue title and body stay English.
- `dart format .` before every commit.
- Fixtures `test/fixtures/inaturalist/autocomplete_whale_shark_de.json` and `taxon_52188_de.json` are real API responses captured on 2026-08-26 and are already in the worktree (untracked; the first task commits them).

---

### Task 1: Lookup entities and iNaturalist response parsers

**Files:**
- Create: `lib/features/marine_life/domain/entities/species_lookup.dart`
- Create: `lib/features/marine_life/data/services/inaturalist_parsers.dart`
- Commit: `test/fixtures/inaturalist/autocomplete_whale_shark_de.json`, `test/fixtures/inaturalist/taxon_52188_de.json`
- Test: `test/features/marine_life/data/services/inaturalist_parsers_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class SpeciesLookupPhoto { squareUrl, attribution }
  class SpeciesLookupHit { taxonId, scientificName, rank, rankLevel, commonName?, matchedTerm?, observationCount, photo?, bool get isResolvable }
  class TaxonAncestor { rank, name }
  class TaxonDetail { taxonId, scientificName, commonName?, rank, ancestors }
  class SpeciesLookupResult { taxonId, commonName, scientificName, category, taxonomyClass? }
  enum SpeciesLookupErrorKind { offline, timeout, server, malformed }
  class SpeciesLookupException implements Exception { kind, detail? }
  List<SpeciesLookupHit> parseAutocomplete(String body);
  TaxonDetail parseTaxonDetail(String body);
  ```

Background (verified against the fixtures): autocomplete `results[]` carry `id`, `name` (scientific), `rank`, `rank_level` (species = 10; anything above species has a larger level), `preferred_common_name` (localized by the `locale` query parameter; "Walhai" under `de`), `english_common_name`, `matched_term`, `observations_count`, `is_active`, and `default_photo` with `license_code` (null means all rights reserved), `attribution` and `square_url`. The taxon endpoint returns `results[0].ancestors[]` with `rank` and `name`.

- [ ] **Step 1: Write the failing parser tests**

`test/features/marine_life/data/services/inaturalist_parsers_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/data/services/inaturalist_parsers.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';

String _fixture(String name) =>
    File('test/fixtures/inaturalist/$name').readAsStringSync();

void main() {
  group('parseAutocomplete', () {
    test('maps the whale shark hit with its German common name', () {
      final hits = parseAutocomplete(
        _fixture('autocomplete_whale_shark_de.json'),
      );

      final hit = hits.single;
      expect(hit.taxonId, 52188);
      expect(hit.scientificName, 'Rhincodon typus');
      expect(hit.rank, 'species');
      expect(hit.commonName, 'Walhai');
      expect(hit.matchedTerm, 'Whale Shark');
      expect(hit.observationCount, greaterThan(0));
      expect(hit.isResolvable, isTrue);
    });

    test('keeps a licensed photo with its attribution', () {
      final hit = parseAutocomplete(
        _fixture('autocomplete_whale_shark_de.json'),
      ).single;

      expect(hit.photo, isNotNull);
      expect(hit.photo!.squareUrl, startsWith('https://'));
      expect(hit.photo!.attribution, contains('CC BY-NC'));
    });

    test('drops an unlicensed photo and falls back to the English name', () {
      const body = '''
      {"results": [{
        "id": 1, "name": "Genus one", "rank": "genus", "rank_level": 20,
        "english_common_name": "Fallback", "observations_count": 3,
        "default_photo": {"license_code": null, "attribution": "(c) x",
                          "square_url": "https://x/1.jpg"}
      }]}''';

      final hit = parseAutocomplete(body).single;

      expect(hit.photo, isNull);
      expect(hit.commonName, 'Fallback');
      expect(hit.isResolvable, isFalse);
    });

    test('tolerates a hit without any common name or photo', () {
      const body =
          '{"results": [{"id": 2, "name": "Nomen nudum", "rank": "species", '
          '"rank_level": 10, "observations_count": 0}]}';

      final hit = parseAutocomplete(body).single;

      expect(hit.commonName, isNull);
      expect(hit.photo, isNull);
      expect(hit.observationCount, 0);
    });

    test('throws a malformed exception for a body that is not JSON', () {
      expect(
        () => parseAutocomplete('<html>'),
        throwsA(
          isA<SpeciesLookupException>().having(
            (e) => e.kind,
            'kind',
            SpeciesLookupErrorKind.malformed,
          ),
        ),
      );
    });
  });

  group('parseTaxonDetail', () {
    test('reads the ancestry in order with ranks', () {
      final detail = parseTaxonDetail(_fixture('taxon_52188_de.json'));

      expect(detail.taxonId, 52188);
      expect(detail.scientificName, 'Rhincodon typus');
      expect(detail.commonName, 'Walhai');
      expect(detail.rank, 'species');
      expect(detail.ancestors.first, const TaxonAncestor('kingdom', 'Animalia'));
      expect(
        detail.ancestors,
        contains(const TaxonAncestor('class', 'Chondrichthyes')),
      );
      expect(detail.ancestors.last.rank, 'genus');
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/marine_life/data/services/inaturalist_parsers_test.dart`
Expected: compilation errors, both source files missing.

- [ ] **Step 3: Write the entities and parsers**

`lib/features/marine_life/domain/entities/species_lookup.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';

/// A licensed photo shown next to a lookup hit, never stored.
class SpeciesLookupPhoto extends Equatable {
  final String squareUrl;
  final String attribution;

  const SpeciesLookupPhoto({required this.squareUrl, required this.attribution});

  @override
  List<Object?> get props => [squareUrl, attribution];
}

/// One autocomplete result.
class SpeciesLookupHit extends Equatable {
  final int taxonId;
  final String scientificName;
  final String rank;

  /// iNaturalist's numeric rank; species is 10, coarser ranks are larger.
  final int rankLevel;

  /// The common name in the requested locale, else English, else null.
  final String? commonName;
  final String? matchedTerm;
  final int observationCount;
  final SpeciesLookupPhoto? photo;

  const SpeciesLookupHit({
    required this.taxonId,
    required this.scientificName,
    required this.rank,
    required this.rankLevel,
    this.commonName,
    this.matchedTerm,
    required this.observationCount,
    this.photo,
  });

  /// Only species-rank (or finer) hits become a species row.
  bool get isResolvable => rankLevel <= 10;

  @override
  List<Object?> get props => [
    taxonId,
    scientificName,
    rank,
    rankLevel,
    commonName,
    matchedTerm,
    observationCount,
    photo,
  ];
}

class TaxonAncestor extends Equatable {
  final String rank;
  final String name;

  const TaxonAncestor(this.rank, this.name);

  @override
  List<Object?> get props => [rank, name];
}

/// The taxon endpoint's answer for one hit: what the category mapper and
/// the species row need.
class TaxonDetail extends Equatable {
  final int taxonId;
  final String scientificName;
  final String? commonName;
  final String rank;
  final List<TaxonAncestor> ancestors;

  const TaxonDetail({
    required this.taxonId,
    required this.scientificName,
    this.commonName,
    required this.rank,
    required this.ancestors,
  });

  @override
  List<Object?> get props => [taxonId, scientificName, commonName, rank, ancestors];
}

/// What a lookup hands back to the caller that creates the species.
class SpeciesLookupResult extends Equatable {
  final int taxonId;
  final String commonName;
  final String scientificName;
  final SpeciesCategory category;
  final String? taxonomyClass;

  const SpeciesLookupResult({
    required this.taxonId,
    required this.commonName,
    required this.scientificName,
    required this.category,
    this.taxonomyClass,
  });

  SpeciesLookupResult copyWith({
    int? taxonId,
    String? commonName,
    String? scientificName,
    SpeciesCategory? category,
    String? taxonomyClass,
  }) {
    return SpeciesLookupResult(
      taxonId: taxonId ?? this.taxonId,
      commonName: commonName ?? this.commonName,
      scientificName: scientificName ?? this.scientificName,
      category: category ?? this.category,
      taxonomyClass: taxonomyClass ?? this.taxonomyClass,
    );
  }

  @override
  List<Object?> get props => [
    taxonId,
    commonName,
    scientificName,
    category,
    taxonomyClass,
  ];
}

enum SpeciesLookupErrorKind { offline, timeout, server, malformed }

/// One message per kind in the sheet; nothing retries silently.
class SpeciesLookupException implements Exception {
  final SpeciesLookupErrorKind kind;
  final String? detail;

  const SpeciesLookupException(this.kind, [this.detail]);

  @override
  String toString() => 'SpeciesLookupException(${kind.name}'
      '${detail == null ? '' : ': $detail'})';
}
```

`lib/features/marine_life/data/services/inaturalist_parsers.dart`:

```dart
import 'dart:convert';

import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';

/// Parses `GET /v1/taxa/autocomplete`. Every field the UI shows is read
/// leniently: a hit missing a common name or photo is still a hit.
List<SpeciesLookupHit> parseAutocomplete(String body) {
  final results = _results(body);
  return [for (final r in results) _hit(r)];
}

/// Parses `GET /v1/taxa/{id}`: the first result with its ancestry.
TaxonDetail parseTaxonDetail(String body) {
  final results = _results(body);
  if (results.isEmpty) {
    throw const SpeciesLookupException(
      SpeciesLookupErrorKind.malformed,
      'taxon response has no results',
    );
  }
  final r = results.first;
  final ancestors = <TaxonAncestor>[
    for (final a in (r['ancestors'] as List?) ?? const [])
      if (a is Map && a['rank'] is String && a['name'] is String)
        TaxonAncestor(a['rank'] as String, a['name'] as String),
  ];
  return TaxonDetail(
    taxonId: _int(r['id']),
    scientificName: r['name'] as String,
    commonName: _commonName(r),
    rank: r['rank'] as String,
    ancestors: ancestors,
  );
}

List<Map<String, dynamic>> _results(String body) {
  try {
    final decoded = jsonDecode(body);
    final results = (decoded as Map<String, dynamic>)['results'] as List?;
    return [
      for (final r in results ?? const [])
        if (r is Map<String, dynamic>) r,
    ];
  } on FormatException catch (e) {
    throw SpeciesLookupException(SpeciesLookupErrorKind.malformed, e.message);
  } on TypeError catch (e) {
    throw SpeciesLookupException(
      SpeciesLookupErrorKind.malformed,
      e.toString(),
    );
  }
}

SpeciesLookupHit _hit(Map<String, dynamic> r) {
  try {
    return SpeciesLookupHit(
      taxonId: _int(r['id']),
      scientificName: r['name'] as String,
      rank: r['rank'] as String,
      rankLevel: _int(r['rank_level']),
      commonName: _commonName(r),
      matchedTerm: r['matched_term'] as String?,
      observationCount: _int(r['observations_count'] ?? 0),
      photo: _photo(r['default_photo']),
    );
  } on TypeError catch (e) {
    throw SpeciesLookupException(
      SpeciesLookupErrorKind.malformed,
      e.toString(),
    );
  }
}

String? _commonName(Map<String, dynamic> r) {
  final preferred = r['preferred_common_name'] as String?;
  if (preferred != null && preferred.isNotEmpty) return preferred;
  final english = r['english_common_name'] as String?;
  if (english != null && english.isNotEmpty) return english;
  return null;
}

/// Only a photo with a licence is shown; null `license_code` means all
/// rights reserved.
SpeciesLookupPhoto? _photo(Object? raw) {
  if (raw is! Map) return null;
  if (raw['license_code'] == null) return null;
  final url = raw['square_url'] as String?;
  if (url == null) return null;
  return SpeciesLookupPhoto(
    squareUrl: url,
    attribution: (raw['attribution'] as String?) ?? '',
  );
}

int _int(Object? value) => switch (value) {
  final int i => i,
  final double d => d.round(),
  final String s => int.parse(s),
  _ => throw TypeError(),
};
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/features/marine_life/data/services/inaturalist_parsers_test.dart`
Expected: `All tests passed!` (6 tests), exit code 0.

- [ ] **Step 5: Format and commit (fixtures included)**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
dart format lib/features/marine_life/domain/entities/species_lookup.dart lib/features/marine_life/data/services/inaturalist_parsers.dart test/features/marine_life/data/services/inaturalist_parsers_test.dart
git add lib/features/marine_life/domain/entities/species_lookup.dart lib/features/marine_life/data/services/inaturalist_parsers.dart test/features/marine_life/data/services/inaturalist_parsers_test.dart test/fixtures/inaturalist/
git commit -m "feat(marine-life): add iNaturalist lookup entities and response parsers"
```

---

### Task 2: Category mapper from taxon ancestry

**Files:**
- Create: `lib/features/marine_life/domain/services/species_category_mapper.dart`
- Test: `test/features/marine_life/domain/services/species_category_mapper_test.dart`

**Interfaces:**
- Consumes: `TaxonAncestor` (Task 1), `SpeciesCategory`.
- Produces: `SpeciesCategory speciesCategoryFromAncestry(List<TaxonAncestor> ancestors)`.

- [ ] **Step 1: Write the failing mapper test**

`test/features/marine_life/domain/services/species_category_mapper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/domain/services/species_category_mapper.dart';

List<TaxonAncestor> _animal(List<(String, String)> rest) => [
  const TaxonAncestor('kingdom', 'Animalia'),
  const TaxonAncestor('phylum', 'Chordata'),
  for (final (rank, name) in rest) TaxonAncestor(rank, name),
];

void main() {
  test('whale shark: Chondrichthyes without a batoid order is a shark', () {
    final ancestry = _animal([
      ('class', 'Chondrichthyes'),
      ('subclass', 'Elasmobranchii'),
      ('order', 'Orectolobiformes'),
    ]);
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.shark);
  });

  test('manta ray: Chondrichthyes with Myliobatiformes is a ray', () {
    final ancestry = _animal([
      ('class', 'Chondrichthyes'),
      ('order', 'Myliobatiformes'),
    ]);
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.ray);
  });

  test('clownfish: Actinopterygii is a fish', () {
    final ancestry = _animal([('class', 'Actinopterygii')]);
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.fish);
  });

  test('green sea turtle: Testudines is a turtle', () {
    final ancestry = _animal([
      ('class', 'Reptilia'),
      ('order', 'Testudines'),
    ]);
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.turtle);
  });

  test('dolphin: Mammalia is a mammal', () {
    final ancestry = _animal([('class', 'Mammalia')]);
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.mammal);
  });

  test('staghorn coral: Anthozoa is coral', () {
    const ancestry = [
      TaxonAncestor('kingdom', 'Animalia'),
      TaxonAncestor('phylum', 'Cnidaria'),
      TaxonAncestor('class', 'Anthozoa'),
      TaxonAncestor('order', 'Scleractinia'),
    ];
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.coral);
  });

  test('magnificent anemone: Anthozoa with Actiniaria is an invertebrate', () {
    const ancestry = [
      TaxonAncestor('kingdom', 'Animalia'),
      TaxonAncestor('class', 'Anthozoa'),
      TaxonAncestor('order', 'Actiniaria'),
    ];
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.invertebrate);
  });

  test('giant kelp (Chromista) and seagrass (Plantae) are plants', () {
    expect(
      speciesCategoryFromAncestry(const [TaxonAncestor('kingdom', 'Chromista')]),
      SpeciesCategory.plant,
    );
    expect(
      speciesCategoryFromAncestry(const [TaxonAncestor('kingdom', 'Plantae')]),
      SpeciesCategory.plant,
    );
  });

  test('sea snake: non-turtle Reptilia is other', () {
    final ancestry = _animal([('class', 'Reptilia'), ('order', 'Squamata')]);
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.other);
  });

  test('nudibranch: any other animal is an invertebrate', () {
    const ancestry = [
      TaxonAncestor('kingdom', 'Animalia'),
      TaxonAncestor('phylum', 'Mollusca'),
      TaxonAncestor('class', 'Gastropoda'),
    ];
    expect(speciesCategoryFromAncestry(ancestry), SpeciesCategory.invertebrate);
  });

  test('unknown ancestry is other', () {
    expect(speciesCategoryFromAncestry(const []), SpeciesCategory.other);
    expect(
      speciesCategoryFromAncestry(const [TaxonAncestor('kingdom', 'Fungi')]),
      SpeciesCategory.other,
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/features/marine_life/domain/services/species_category_mapper_test.dart`
Expected: compilation error, `species_category_mapper.dart` not found.

- [ ] **Step 3: Write the mapper**

`lib/features/marine_life/domain/services/species_category_mapper.dart`:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';

/// Batoid orders under Chondrichthyes; everything else in the class is a
/// shark (or a chimaera, which divers file with the sharks).
const Set<String> _batoidOrders = {
  'Rajiformes',
  'Myliobatiformes',
  'Torpediniformes',
  'Rhinopristiformes',
};

/// Maps a taxon's named ancestry to the app's category. First rule wins.
///
/// iNaturalist's `iconic_taxon_name` is too coarse (a shark is "Animalia"),
/// which is why the caller fetches the taxon's ancestors before mapping.
SpeciesCategory speciesCategoryFromAncestry(List<TaxonAncestor> ancestors) {
  bool has(String rank, String name) =>
      ancestors.any((a) => a.rank == rank && a.name == name);
  bool hasName(String name) => ancestors.any((a) => a.name == name);

  if (has('class', 'Chondrichthyes')) {
    return _batoidOrders.any(hasName) ? SpeciesCategory.ray : SpeciesCategory.shark;
  }
  if (has('class', 'Actinopterygii')) return SpeciesCategory.fish;
  if (has('class', 'Mammalia')) return SpeciesCategory.mammal;
  if (has('order', 'Testudines')) return SpeciesCategory.turtle;
  if (has('class', 'Anthozoa')) {
    return has('order', 'Actiniaria')
        ? SpeciesCategory.invertebrate
        : SpeciesCategory.coral;
  }
  if (has('kingdom', 'Plantae') || has('kingdom', 'Chromista')) {
    return SpeciesCategory.plant;
  }
  if (has('class', 'Aves') || has('class', 'Reptilia') || has('class', 'Amphibia')) {
    return SpeciesCategory.other;
  }
  if (has('kingdom', 'Animalia')) return SpeciesCategory.invertebrate;
  return SpeciesCategory.other;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/features/marine_life/domain/services/species_category_mapper_test.dart`
Expected: `All tests passed!` (11 tests), exit code 0.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
dart format lib/features/marine_life/domain/services test/features/marine_life/domain/services
git add lib/features/marine_life/domain/services/species_category_mapper.dart test/features/marine_life/domain/services/species_category_mapper_test.dart
git commit -m "feat(marine-life): map a taxon's ancestry to a species category"
```

---

### Task 3: `INaturalistSpeciesLookupService`

**Files:**
- Create: `lib/features/marine_life/data/services/species_lookup_service.dart` (the abstract interface)
- Create: `lib/features/marine_life/data/services/inaturalist_species_lookup_service.dart`
- Test: `test/features/marine_life/data/services/inaturalist_species_lookup_service_test.dart`

**Interfaces:**
- Consumes: Tasks 1 and 2; `package:http`.
- Produces:
  ```dart
  abstract class SpeciesLookupService {
    Future<List<SpeciesLookupHit>> search(String query, {required String locale});
    Future<SpeciesLookupResult> resolve(int taxonId, {required String locale});
  }
  class INaturalistSpeciesLookupService implements SpeciesLookupService {
    INaturalistSpeciesLookupService({http.Client? client, Duration timeout = const Duration(seconds: 10)});
  }
  ```

Background: the GBIF service (`lib/features/reef/data/services/nearby_species_service.dart`) is the network pattern to follow: optional `http.Client` injection, `Uri.https`, a `User-Agent` header. It swallows errors into a result wrapper; this service throws `SpeciesLookupException` instead because the sheet renders one message per failure kind.

- [ ] **Step 1: Write the failing service test**

`test/features/marine_life/data/services/inaturalist_species_lookup_service_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/services/inaturalist_species_lookup_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';

String _fixture(String name) =>
    File('test/fixtures/inaturalist/$name').readAsStringSync();

void main() {
  test('search hits the autocomplete endpoint with query, locale and agent',
      () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(_fixture('autocomplete_whale_shark_de.json'), 200);
    });
    final service = INaturalistSpeciesLookupService(client: client);

    final hits = await service.search('whale shark', locale: 'de');

    expect(captured.url.host, 'api.inaturalist.org');
    expect(captured.url.path, '/v1/taxa/autocomplete');
    expect(captured.url.queryParameters['q'], 'whale shark');
    expect(captured.url.queryParameters['locale'], 'de');
    expect(captured.url.queryParameters['per_page'], '10');
    expect(captured.url.queryParameters['is_active'], 'true');
    expect(captured.headers['user-agent'], contains('Submersion'));
    expect(hits.single.commonName, 'Walhai');
  });

  test('resolve fetches the taxon and maps category and class', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(_fixture('taxon_52188_de.json'), 200);
    });
    final service = INaturalistSpeciesLookupService(client: client);

    final result = await service.resolve(52188, locale: 'de');

    expect(captured.url.path, '/v1/taxa/52188');
    expect(captured.url.queryParameters['locale'], 'de');
    expect(result.taxonId, 52188);
    expect(result.commonName, 'Walhai');
    expect(result.scientificName, 'Rhincodon typus');
    expect(result.category, SpeciesCategory.shark);
    expect(result.taxonomyClass, 'Chondrichthyes');
  });

  test('resolve falls back to the scientific name without a common name',
      () async {
    final client = MockClient(
      (_) async => http.Response(
        '{"results":[{"id":9,"name":"Nomen nudum","rank":"species",'
        '"ancestors":[{"rank":"kingdom","name":"Animalia"}]}]}',
        200,
      ),
    );

    final result = await INaturalistSpeciesLookupService(
      client: client,
    ).resolve(9, locale: 'en');

    expect(result.commonName, 'Nomen nudum');
    expect(result.category, SpeciesCategory.invertebrate);
    expect(result.taxonomyClass, isNull);
  });

  test('a non-200 answer is a server error', () async {
    final client = MockClient((_) async => http.Response('nope', 503));

    expect(
      () => INaturalistSpeciesLookupService(client: client)
          .search('x', locale: 'en'),
      throwsA(_kind(SpeciesLookupErrorKind.server)),
    );
  });

  test('a body that is not JSON is malformed', () async {
    final client = MockClient((_) async => http.Response('<html>', 200));

    expect(
      () => INaturalistSpeciesLookupService(client: client)
          .search('x', locale: 'en'),
      throwsA(_kind(SpeciesLookupErrorKind.malformed)),
    );
  });

  test('a socket failure is offline', () async {
    final client = MockClient((_) async => throw const SocketException('down'));

    expect(
      () => INaturalistSpeciesLookupService(client: client)
          .search('x', locale: 'en'),
      throwsA(_kind(SpeciesLookupErrorKind.offline)),
    );
  });

  test('a slow answer is a timeout', () async {
    final client = MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return http.Response('{"results":[]}', 200);
    });
    final service = INaturalistSpeciesLookupService(
      client: client,
      timeout: const Duration(milliseconds: 20),
    );

    expect(
      () => service.search('x', locale: 'en'),
      throwsA(_kind(SpeciesLookupErrorKind.timeout)),
    );
  });

  test('a repeated search is served from the session cache', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls += 1;
      return http.Response(_fixture('autocomplete_whale_shark_de.json'), 200);
    });
    final service = INaturalistSpeciesLookupService(client: client);

    await service.search('Whale shark', locale: 'de');
    await service.search('  whale shark ', locale: 'DE');
    await service.search('whale shark', locale: 'en');

    expect(calls, 2);
  });
}

Matcher _kind(SpeciesLookupErrorKind kind) =>
    isA<SpeciesLookupException>().having((e) => e.kind, 'kind', kind);
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/features/marine_life/data/services/inaturalist_species_lookup_service_test.dart`
Expected: compilation error, service file not found.

- [ ] **Step 3: Write the interface and the service**

`lib/features/marine_life/data/services/species_lookup_service.dart`:

```dart
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';

/// Looks a species up online. The iNaturalist implementation is the only
/// production one; widgets depend on this interface so tests can stub it.
abstract class SpeciesLookupService {
  /// Autocomplete hits for [query] with common names in [locale].
  Future<List<SpeciesLookupHit>> search(String query, {required String locale});

  /// The fields a species row needs for one hit, category included.
  Future<SpeciesLookupResult> resolve(int taxonId, {required String locale});
}
```

`lib/features/marine_life/data/services/inaturalist_species_lookup_service.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:submersion/features/marine_life/data/services/inaturalist_parsers.dart';
import 'package:submersion/features/marine_life/data/services/species_lookup_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/domain/services/species_category_mapper.dart';

/// iNaturalist's public taxa API. Free to read, no key.
///
/// Explicit lookups only: callers send a request when the diver asks for
/// one, never per keystroke. Results are cached for the session so a
/// repeated query costs nothing.
class INaturalistSpeciesLookupService implements SpeciesLookupService {
  static const String _host = 'api.inaturalist.org';
  static const String _autocompletePath = '/v1/taxa/autocomplete';
  static const String _taxonPath = '/v1/taxa';
  static const String _userAgent = 'Submersion/1.0 (https://submersion.app)';

  final http.Client _client;
  final Duration _timeout;
  final Map<String, List<SpeciesLookupHit>> _searchCache = {};
  final Map<String, SpeciesLookupResult> _resolveCache = {};

  INaturalistSpeciesLookupService({
    http.Client? client,
    Duration timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _timeout = timeout;

  @override
  Future<List<SpeciesLookupHit>> search(
    String query, {
    required String locale,
  }) async {
    final term = query.trim();
    final key = '${locale.toLowerCase()}|${term.toLowerCase()}';
    final cached = _searchCache[key];
    if (cached != null) return cached;

    final uri = Uri.https(_host, _autocompletePath, {
      'q': term,
      'locale': locale,
      'per_page': '10',
      'is_active': 'true',
    });
    final hits = parseAutocomplete(await _get(uri));
    _searchCache[key] = hits;
    return hits;
  }

  @override
  Future<SpeciesLookupResult> resolve(
    int taxonId, {
    required String locale,
  }) async {
    final key = '${locale.toLowerCase()}|$taxonId';
    final cached = _resolveCache[key];
    if (cached != null) return cached;

    final uri = Uri.https(_host, '$_taxonPath/$taxonId', {'locale': locale});
    final detail = parseTaxonDetail(await _get(uri));
    final taxonomyClass = detail.ancestors
        .where((a) => a.rank == 'class')
        .map((a) => a.name)
        .firstOrNull;
    final result = SpeciesLookupResult(
      taxonId: detail.taxonId,
      commonName: detail.commonName ?? detail.scientificName,
      scientificName: detail.scientificName,
      category: speciesCategoryFromAncestry(detail.ancestors),
      taxonomyClass: taxonomyClass,
    );
    _resolveCache[key] = result;
    return result;
  }

  Future<String> _get(Uri uri) async {
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'User-Agent': _userAgent})
          .timeout(_timeout);
    } on TimeoutException {
      throw const SpeciesLookupException(SpeciesLookupErrorKind.timeout);
    } on SocketException catch (e) {
      throw SpeciesLookupException(SpeciesLookupErrorKind.offline, e.message);
    } on http.ClientException catch (e) {
      throw SpeciesLookupException(SpeciesLookupErrorKind.offline, e.message);
    }
    if (response.statusCode != 200) {
      throw SpeciesLookupException(
        SpeciesLookupErrorKind.server,
        'HTTP ${response.statusCode}',
      );
    }
    return response.body;
  }
}
```

`firstOrNull` comes from `package:collection` (already a dependency; add `import 'package:collection/collection.dart';` if the analyzer asks for it).

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/features/marine_life/data/services/inaturalist_species_lookup_service_test.dart`
Expected: `All tests passed!` (8 tests), exit code 0.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
dart format lib/features/marine_life/data/services test/features/marine_life/data/services
git add lib/features/marine_life/data/services/species_lookup_service.dart lib/features/marine_life/data/services/inaturalist_species_lookup_service.dart test/features/marine_life/data/services/inaturalist_species_lookup_service_test.dart
git commit -m "feat(marine-life): add the iNaturalist species lookup service"
```

---

### Task 4: Providers and the lookup locale

**Files:**
- Create: `lib/features/marine_life/presentation/providers/species_lookup_providers.dart`
- Test: `test/features/marine_life/presentation/providers/species_lookup_providers_test.dart`

**Interfaces:**
- Consumes: Task 3; `localeProvider` (`Provider<String>`, `'system'` or a language tag) from `lib/features/settings/presentation/providers/settings_providers.dart`.
- Produces:
  ```dart
  String lookupLocaleCode(String localeTag, {String Function()? systemLanguageCode});
  final speciesLookupHttpClientProvider = Provider<http.Client>;
  final speciesLookupServiceProvider = Provider<SpeciesLookupService>;
  final speciesLookupLocaleProvider = Provider<String>;
  ```

Background: `l10nForLocaleTag` in `lib/l10n/l10n_extension.dart` is the app's idiom for turning the persisted locale setting into a language code (`'system'` resolves through `PlatformDispatcher.instance.locale`); the lookup locale copies that resolution with the platform read injectable for tests. The reef feature's `reefHttpClientProvider` is the client-provider pattern (create, close on dispose, override with `MockClient` in tests).

- [ ] **Step 1: Write the failing test**

`test/features/marine_life/presentation/providers/species_lookup_providers_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_lookup_providers.dart';

void main() {
  test('a language tag becomes its lowercase language code', () {
    expect(lookupLocaleCode('de'), 'de');
    expect(lookupLocaleCode('pt-BR'), 'pt');
    expect(lookupLocaleCode('zh_Hans'), 'zh');
    expect(lookupLocaleCode('EN'), 'en');
  });

  test('system resolves through the platform language', () {
    expect(
      lookupLocaleCode('system', systemLanguageCode: () => 'fr'),
      'fr',
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/marine_life/presentation/providers/species_lookup_providers_test.dart`
Expected: compilation error, file not found.

- [ ] **Step 3: Write the providers**

`lib/features/marine_life/presentation/providers/species_lookup_providers.dart`:

```dart
import 'dart:ui';

import 'package:http/http.dart' as http;
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/marine_life/data/services/inaturalist_species_lookup_service.dart';
import 'package:submersion/features/marine_life/data/services/species_lookup_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The language code sent as iNaturalist's `locale` parameter, from the
/// persisted locale setting. Mirrors `l10nForLocaleTag`: `system` follows
/// the platform, and a region or script suffix is dropped.
String lookupLocaleCode(
  String localeTag, {
  String Function()? systemLanguageCode,
}) {
  final tag = localeTag == 'system'
      ? (systemLanguageCode ?? _platformLanguageCode)()
      : localeTag;
  return tag.split(RegExp('[-_]')).first.toLowerCase();
}

String _platformLanguageCode() => PlatformDispatcher.instance.locale.languageCode;

/// Shared client for species lookups. Overridden in tests with a MockClient.
final speciesLookupHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final speciesLookupServiceProvider = Provider<SpeciesLookupService>((ref) {
  return INaturalistSpeciesLookupService(
    client: ref.watch(speciesLookupHttpClientProvider),
  );
});

final speciesLookupLocaleProvider = Provider<String>((ref) {
  return lookupLocaleCode(ref.watch(localeProvider));
});
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/features/marine_life/presentation/providers/species_lookup_providers_test.dart`
Expected: `All tests passed!` (2 tests), exit code 0.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
dart format lib/features/marine_life/presentation/providers/species_lookup_providers.dart test/features/marine_life/presentation/providers/species_lookup_providers_test.dart
git add lib/features/marine_life/presentation/providers/species_lookup_providers.dart test/features/marine_life/presentation/providers/species_lookup_providers_test.dart
git commit -m "feat(marine-life): add species lookup providers and locale resolution"
```

---

### Task 5: Localization keys

**Files:**
- Modify: `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`
- Test: `test/l10n/species_lookup_strings_test.dart`

**Interfaces:**
- Produces `AppLocalizations` members: `marineLife_lookup_button`, `_title`, `_searchHint`, `_search`, `_createWithout`, `_attribution`, `_idle`, `_empty(String query)`, `_errorOffline`, `_errorTimeout`, `_errorServer`, `_errorMalformed`, `_retry`, `_resolving`, `_observations(int count)`, `_unresolvableRank(String rank)`; `marineLife_speciesDetail_suggestForCatalog`; `marineLife_suggest_couldNotOpen`, `marineLife_suggest_copyLink`; `reef_species_addFromLookup`.

- [ ] **Step 1: Write the failing strings test**

`test/l10n/species_lookup_strings_test.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('lookup strings exist in English', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(l10n.marineLife_lookup_button, 'Look up online');
    expect(l10n.marineLife_lookup_search, 'Look up');
    expect(l10n.marineLife_lookup_empty('zzz'), 'No species found for "zzz"');
    expect(l10n.marineLife_lookup_observations(1), '1 observation');
    expect(l10n.marineLife_lookup_observations(42), '42 observations');
    expect(l10n.marineLife_speciesDetail_suggestForCatalog, 'Suggest for the catalog');
    expect(l10n.reef_species_addFromLookup, 'Look up and add to your species');
  });

  test('lookup strings are translated in German', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('de'));

    expect(l10n.marineLife_lookup_button, 'Online nachschlagen');
    expect(l10n.marineLife_lookup_observations(2), '2 Beobachtungen');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/l10n/species_lookup_strings_test.dart`
Expected: compilation error, `marineLife_lookup_button` is not defined.

- [ ] **Step 3: Insert the keys with the script**

First confirm both anchors exist once in every locale:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
grep -l '^  "marineLife_speciesManage_searchHint": ' lib/l10n/arb/app_*.arb | wc -l
grep -l '^  "reef_species_addToExpected": ' lib/l10n/arb/app_*.arb | wc -l
```

Expected: `11` and `11`. Then save this as `/private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion/1a1e1ff7-4477-4b97-b07b-8de224f521ea/scratchpad/add_species_lookup_keys.py` (throwaway) and run it from the worktree root with `python3`:

```python
import json, re, sys
from pathlib import Path

ROOT = Path('lib/l10n/arb')
ANCHORS = {
    'marineLife_': 'marineLife_speciesManage_searchHint',
    'reef_': 'reef_species_addToExpected',
}

KEYS = [
    ('marineLife_lookup_button', None),
    ('marineLife_lookup_title', None),
    ('marineLife_lookup_searchHint', None),
    ('marineLife_lookup_search', None),
    ('marineLife_lookup_createWithout', None),
    ('marineLife_lookup_attribution', None),
    ('marineLife_lookup_idle', None),
    ('marineLife_lookup_empty', {'query': 'String'}),
    ('marineLife_lookup_errorOffline', None),
    ('marineLife_lookup_errorTimeout', None),
    ('marineLife_lookup_errorServer', None),
    ('marineLife_lookup_errorMalformed', None),
    ('marineLife_lookup_retry', None),
    ('marineLife_lookup_resolving', None),
    ('marineLife_lookup_observations', {'count': 'int'}),
    ('marineLife_lookup_unresolvableRank', {'rank': 'String'}),
    ('marineLife_speciesDetail_suggestForCatalog', None),
    ('marineLife_suggest_couldNotOpen', None),
    ('marineLife_suggest_copyLink', None),
    ('reef_species_addFromLookup', None),
]

VALUES = {
    'en': [
        'Look up online', 'Look up a species', 'Common or scientific name',
        'Look up', 'Create without lookup',
        'Species data and photos from iNaturalist',
        'Type a name and tap Look up.', 'No species found for "{query}"',
        'You appear to be offline.', 'The lookup timed out.',
        'iNaturalist returned an error. Try again later.',
        'Unexpected response from iNaturalist.', 'Retry',
        'Loading details...',
        '{count, plural, =1{1 observation} other{{count} observations}}',
        '{rank}: choose a species', 'Suggest for the catalog',
        'Could not open the browser', 'Copy link',
        'Look up and add to your species',
    ],
    'de': [
        'Online nachschlagen', 'Art nachschlagen',
        'Trivial- oder wissenschaftlicher Name', 'Nachschlagen',
        'Ohne Nachschlagen anlegen', 'Artdaten und Fotos von iNaturalist',
        'Geben Sie einen Namen ein und tippen Sie auf Nachschlagen.',
        'Keine Art für "{query}" gefunden', 'Sie scheinen offline zu sein.',
        'Zeitüberschreitung beim Nachschlagen.',
        'iNaturalist hat einen Fehler gemeldet. Versuchen Sie es später erneut.',
        'Unerwartete Antwort von iNaturalist.', 'Erneut versuchen',
        'Details werden geladen...',
        '{count, plural, =1{1 Beobachtung} other{{count} Beobachtungen}}',
        '{rank}: wählen Sie eine Art', 'Für den Katalog vorschlagen',
        'Browser konnte nicht geöffnet werden', 'Link kopieren',
        'Nachschlagen und zu Ihren Arten hinzufügen',
    ],
    'es': [
        'Buscar en línea', 'Buscar una especie', 'Nombre común o científico',
        'Buscar', 'Crear sin buscar', 'Datos y fotos de especies de iNaturalist',
        'Escribe un nombre y toca Buscar.',
        'No se encontraron especies para "{query}"',
        'Parece que no tienes conexión.', 'La búsqueda tardó demasiado.',
        'iNaturalist devolvió un error. Inténtalo más tarde.',
        'Respuesta inesperada de iNaturalist.', 'Reintentar',
        'Cargando detalles...',
        '{count, plural, =1{1 observación} other{{count} observaciones}}',
        '{rank}: elige una especie', 'Sugerir para el catálogo',
        'No se pudo abrir el navegador', 'Copiar enlace',
        'Buscar y añadir a tus especies',
    ],
    'fr': [
        'Rechercher en ligne', 'Rechercher une espèce',
        'Nom commun ou scientifique', 'Rechercher', 'Créer sans recherche',
        "Données et photos d'espèces issues d'iNaturalist",
        'Saisissez un nom puis touchez Rechercher.',
        'Aucune espèce trouvée pour "{query}"',
        'Vous semblez être hors ligne.', 'La recherche a expiré.',
        'iNaturalist a renvoyé une erreur. Réessayez plus tard.',
        "Réponse inattendue d'iNaturalist.", 'Réessayer',
        'Chargement des détails...',
        '{count, plural, =1{1 observation} other{{count} observations}}',
        '{rank} : choisissez une espèce', 'Proposer pour le catalogue',
        "Impossible d'ouvrir le navigateur", 'Copier le lien',
        'Rechercher et ajouter à vos espèces',
    ],
    'it': [
        'Cerca online', 'Cerca una specie', 'Nome comune o scientifico',
        'Cerca', 'Crea senza ricerca', 'Dati e foto delle specie da iNaturalist',
        'Digita un nome e tocca Cerca.', 'Nessuna specie trovata per "{query}"',
        'Sembra che tu sia offline.', 'La ricerca è scaduta.',
        'iNaturalist ha restituito un errore. Riprova più tardi.',
        'Risposta inattesa da iNaturalist.', 'Riprova',
        'Caricamento dei dettagli...',
        '{count, plural, =1{1 osservazione} other{{count} osservazioni}}',
        '{rank}: scegli una specie', 'Suggerisci per il catalogo',
        'Impossibile aprire il browser', 'Copia link',
        'Cerca e aggiungi alle tue specie',
    ],
    'pt': [
        'Pesquisar online', 'Pesquisar uma espécie', 'Nome comum ou científico',
        'Pesquisar', 'Criar sem pesquisar',
        'Dados e fotos de espécies do iNaturalist',
        'Digite um nome e toque em Pesquisar.',
        'Nenhuma espécie encontrada para "{query}"',
        'Você parece estar offline.', 'A pesquisa expirou.',
        'O iNaturalist retornou um erro. Tente novamente mais tarde.',
        'Resposta inesperada do iNaturalist.', 'Tentar novamente',
        'Carregando detalhes...',
        '{count, plural, =1{1 observação} other{{count} observações}}',
        '{rank}: escolha uma espécie', 'Sugerir para o catálogo',
        'Não foi possível abrir o navegador', 'Copiar link',
        'Pesquisar e adicionar às suas espécies',
    ],
    'nl': [
        'Online opzoeken', 'Een soort opzoeken',
        'Gewone of wetenschappelijke naam', 'Opzoeken',
        'Aanmaken zonder opzoeken', "Soortgegevens en foto's van iNaturalist",
        'Typ een naam en tik op Opzoeken.',
        'Geen soorten gevonden voor "{query}"', 'Je lijkt offline te zijn.',
        'Het opzoeken duurde te lang.',
        'iNaturalist gaf een fout terug. Probeer het later opnieuw.',
        'Onverwacht antwoord van iNaturalist.', 'Opnieuw proberen',
        'Details laden...',
        '{count, plural, =1{1 waarneming} other{{count} waarnemingen}}',
        '{rank}: kies een soort', 'Voorstellen voor de catalogus',
        'Kon de browser niet openen', 'Link kopiëren',
        'Opzoeken en aan je soorten toevoegen',
    ],
    'hu': [
        'Keresés online', 'Faj keresése', 'Köznapi vagy tudományos név',
        'Keresés', 'Létrehozás keresés nélkül',
        'Fajadatok és fotók az iNaturalisttól',
        'Írj be egy nevet, és koppints a Keresés gombra.',
        'Nincs találat erre: "{query}"',
        'Úgy tűnik, nincs internetkapcsolat.',
        'A keresés túllépte az időkorlátot.',
        'Az iNaturalist hibát adott vissza. Próbáld újra később.',
        'Váratlan válasz az iNaturalisttól.', 'Újra',
        'Részletek betöltése...',
        '{count, plural, =1{1 megfigyelés} other{{count} megfigyelés}}',
        '{rank}: válassz egy fajt', 'Javaslat a katalógusba',
        'Nem sikerült megnyitni a böngészőt', 'Link másolása',
        'Keresés és hozzáadás a fajaidhoz',
    ],
    'zh': [
        '在线查找', '查找物种', '常用名或学名', '查找', '不查找直接创建',
        '物种数据和照片来自 iNaturalist', '输入名称，然后点按“查找”。',
        '未找到与“{query}”匹配的物种', '你似乎处于离线状态。', '查找超时。',
        'iNaturalist 返回了错误。请稍后重试。', '来自 iNaturalist 的意外响应。',
        '重试', '正在加载详情...',
        '{count, plural, =1{1 条观察记录} other{{count} 条观察记录}}',
        '{rank}：请选择一个物种', '推荐加入目录', '无法打开浏览器', '复制链接',
        '查找并添加到你的物种',
    ],
    'ar': [
        'البحث عبر الإنترنت', 'البحث عن نوع', 'الاسم الشائع أو العلمي', 'بحث',
        'إنشاء بدون بحث', 'بيانات الأنواع والصور من iNaturalist',
        'اكتب اسمًا ثم اضغط بحث.', 'لم يُعثر على أنواع لـ "{query}"',
        'يبدو أنك غير متصل بالإنترنت.', 'انتهت مهلة البحث.',
        'أعاد iNaturalist خطأ. حاول مرة أخرى لاحقًا.',
        'استجابة غير متوقعة من iNaturalist.', 'إعادة المحاولة',
        'جارٍ تحميل التفاصيل...',
        '{count, plural, =1{مشاهدة واحدة} other{{count} مشاهدات}}',
        '{rank}: اختر نوعًا', 'اقتراح للفهرس', 'تعذر فتح المتصفح', 'نسخ الرابط',
        'البحث والإضافة إلى أنواعك',
    ],
    'he': [
        'חיפוש מקוון', 'חיפוש מין', 'שם עממי או מדעי', 'חיפוש',
        'יצירה ללא חיפוש', 'נתוני מינים ותמונות מ-iNaturalist',
        'הקלידו שם והקישו על חיפוש.', 'לא נמצאו מינים עבור "{query}"',
        'נראה שאין חיבור לאינטרנט.', 'תם הזמן המוקצב לחיפוש.',
        'iNaturalist החזיר שגיאה. נסו שוב מאוחר יותר.',
        'תגובה לא צפויה מ-iNaturalist.', 'ניסיון חוזר', 'טוען פרטים...',
        '{count, plural, =1{תצפית אחת} other{{count} תצפיות}}',
        '{rank}: בחרו מין', 'הצעה לקטלוג', 'לא ניתן לפתוח את הדפדפן',
        'העתקת קישור', 'חיפוש והוספה למינים שלכם',
    ],
}

def key_line(key, value):
    return '  ' + json.dumps(key) + ': ' + json.dumps(value, ensure_ascii=False) + ',\n'

def meta_lines(key, placeholders):
    out = ['  ' + json.dumps('@' + key) + ': {\n', '    "placeholders": {\n']
    items = list(placeholders.items())
    for i, (name, typ) in enumerate(items):
        comma = ',' if i < len(items) - 1 else ''
        out += ['      ' + json.dumps(name) + ': {\n',
                '        "type": ' + json.dumps(typ) + '\n',
                '      }' + comma + '\n']
    out += ['    }\n', '  },\n']
    return out

def find_anchor(lines, anchor):
    pattern = re.compile(r'^  "' + re.escape(anchor) + r'": ')
    hits = [i for i, l in enumerate(lines) if pattern.match(l)]
    if len(hits) != 1:
        sys.exit(f'anchor {anchor} found {len(hits)} times')
    return hits[0]

for locale, values in VALUES.items():
    if len(values) != len(KEYS):
        sys.exit(f'{locale}: {len(values)} values for {len(KEYS)} keys')
    path = ROOT / f'app_{locale}.arb'
    text = path.read_text(encoding='utf-8')
    for key, _ in KEYS:
        if f'"{key}"' in text:
            sys.exit(f'{locale}: {key} already present')
    lines = text.splitlines(keepends=True)
    blocks = {anchor: [] for anchor in ANCHORS.values()}
    for (key, placeholders), value in zip(KEYS, values):
        block = [key_line(key, value)]
        if locale == 'en' and placeholders:
            block += meta_lines(key, placeholders)
        prefix = next(p for p in ANCHORS if key.startswith(p))
        blocks[ANCHORS[prefix]].extend(block)
    for anchor, block in sorted(
        blocks.items(), key=lambda pair: find_anchor(lines, pair[0]), reverse=True
    ):
        at = find_anchor(lines, anchor) + 1
        lines[at:at] = block
    new_text = ''.join(lines)
    json.loads(new_text)
    path.write_text(new_text, encoding='utf-8')
    print(f'{locale}: added {len(KEYS)} keys')
```

Run:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
python3 /private/tmp/claude-501/-Users-ericgriffin-repos-submersion-app-submersion/1a1e1ff7-4477-4b97-b07b-8de224f521ea/scratchpad/add_species_lookup_keys.py
flutter gen-l10n
```

Expected: eleven `added 20 keys` lines.

- [ ] **Step 4: Run the strings test and the parity test**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/l10n/species_lookup_strings_test.dart test/l10n/arb_parity_test.dart`
Expected: `All tests passed!`, exit code 0.

- [ ] **Step 5: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
git add lib/l10n/arb test/l10n/species_lookup_strings_test.dart
git commit -m "feat(l10n): add species lookup and catalog suggestion strings"
```

---

### Task 6: `SpeciesLookupSheet`

**Files:**
- Create: `lib/features/marine_life/presentation/widgets/species_lookup_sheet.dart`
- Test: `test/features/marine_life/presentation/widgets/species_lookup_sheet_test.dart`

**Interfaces:**
- Consumes: `speciesLookupServiceProvider`, `speciesLookupLocaleProvider` (Task 4); entities (Task 1); Task 5 strings; `SpeciesCategoryDisplay.localizedName`, `iconForSpeciesCategory`.
- Produces: `Future<SpeciesLookupResult?> showSpeciesLookupSheet(BuildContext context, {String initialQuery = ''})` and `SpeciesLookupSheet({required String initialQuery, ScrollController? scrollController})`. The sheet pops with a `SpeciesLookupResult` on selection and with null on dismiss or "Create without lookup".

- [ ] **Step 1: Write the failing widget test**

`test/features/marine_life/presentation/widgets/species_lookup_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/services/species_lookup_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_lookup_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_lookup_sheet.dart';

import '../../../../helpers/test_app.dart';

const _whale = SpeciesLookupHit(
  taxonId: 52188,
  scientificName: 'Rhincodon typus',
  rank: 'species',
  rankLevel: 10,
  commonName: 'Whale Shark',
  observationCount: 2662,
);

const _genus = SpeciesLookupHit(
  taxonId: 1,
  scientificName: 'Rhincodon',
  rank: 'genus',
  rankLevel: 20,
  observationCount: 3000,
);

const _resolved = SpeciesLookupResult(
  taxonId: 52188,
  commonName: 'Whale Shark',
  scientificName: 'Rhincodon typus',
  category: SpeciesCategory.shark,
  taxonomyClass: 'Chondrichthyes',
);

class _FakeLookup implements SpeciesLookupService {
  _FakeLookup({this.hits = const [], this.failWith});

  final List<SpeciesLookupHit> hits;
  final SpeciesLookupException? failWith;
  final List<String> queries = [];
  final List<int> resolved = [];

  @override
  Future<List<SpeciesLookupHit>> search(
    String query, {
    required String locale,
  }) async {
    queries.add('$query@$locale');
    if (failWith != null) throw failWith!;
    return hits;
  }

  @override
  Future<SpeciesLookupResult> resolve(
    int taxonId, {
    required String locale,
  }) async {
    resolved.add(taxonId);
    return _resolved;
  }
}

/// Opens the sheet from a button so the popped value can be captured.
Future<SpeciesLookupResult? Function()> _open(
  WidgetTester tester,
  _FakeLookup service, {
  String initialQuery = '',
}) async {
  SpeciesLookupResult? popped;
  var closed = false;
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        speciesLookupServiceProvider.overrideWithValue(service),
        speciesLookupLocaleProvider.overrideWithValue('en'),
      ],
      child: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            popped = await showSpeciesLookupSheet(
              context,
              initialQuery: initialQuery,
            );
            closed = true;
          },
          child: const Text('OPEN'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  return () => closed ? popped : throw StateError('sheet still open');
}

void main() {
  testWidgets('starts idle and searches only when asked', (tester) async {
    final service = _FakeLookup(hits: const [_whale, _genus]);
    await _open(tester, service, initialQuery: 'whale');

    expect(find.text('Type a name and tap Look up.'), findsOneWidget);
    expect(service.queries, isEmpty);

    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();

    expect(service.queries, ['whale@en']);
    expect(find.text('Whale Shark'), findsOneWidget);
    expect(find.text('Rhincodon typus'), findsOneWidget);
    expect(find.text('2662 observations'), findsOneWidget);
    expect(find.text('Species data and photos from iNaturalist'), findsOneWidget);
  });

  testWidgets('a coarser rank is listed but cannot be chosen', (tester) async {
    final service = _FakeLookup(hits: const [_genus]);
    await _open(tester, service, initialQuery: 'rhincodon');
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();

    expect(find.text('genus: choose a species'), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Rhincodon'),
    );
    expect(tile.enabled, isFalse);
  });

  testWidgets('choosing a hit resolves it and pops with the result', (
    tester,
  ) async {
    final service = _FakeLookup(hits: const [_whale]);
    final read = await _open(tester, service, initialQuery: 'whale');
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Whale Shark'));
    await tester.pumpAndSettle();

    expect(service.resolved, [52188]);
    expect(read(), _resolved);
  });

  testWidgets('shows the empty state for a query with no hits', (tester) async {
    final service = _FakeLookup();
    await _open(tester, service, initialQuery: 'zzz');
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();

    expect(find.text('No species found for "zzz"'), findsOneWidget);
  });

  testWidgets('shows one message per failure kind with a retry', (
    tester,
  ) async {
    final service = _FakeLookup(
      failWith: const SpeciesLookupException(SpeciesLookupErrorKind.offline),
    );
    await _open(tester, service, initialQuery: 'whale');
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();

    expect(find.text('You appear to be offline.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(service.queries, hasLength(2));
  });

  testWidgets('Create without lookup pops with null', (tester) async {
    final service = _FakeLookup();
    final read = await _open(tester, service, initialQuery: 'whale');

    await tester.tap(find.text('Create without lookup'));
    await tester.pumpAndSettle();

    expect(read(), isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/features/marine_life/presentation/widgets/species_lookup_sheet_test.dart`
Expected: compilation error, sheet file not found.

- [ ] **Step 3: Write the sheet**

`lib/features/marine_life/presentation/widgets/species_lookup_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_lookup_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the lookup sheet. Resolves to the chosen species' fields, or null
/// when the diver dismisses it or asks to create the species without a
/// lookup (callers keep their offline path for that).
Future<SpeciesLookupResult?> showSpeciesLookupSheet(
  BuildContext context, {
  String initialQuery = '',
}) => showModalBottomSheet<SpeciesLookupResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => DraggableScrollableSheet(
    initialChildSize: 0.7,
    minChildSize: 0.4,
    maxChildSize: 0.95,
    expand: false,
    builder: (_, controller) => SpeciesLookupSheet(
      initialQuery: initialQuery,
      scrollController: controller,
    ),
  ),
);

/// Search iNaturalist for a species. Lookups are explicit: nothing is sent
/// until the diver taps Look up, so typing never leaks keystrokes and an
/// offline boat is a single clear message rather than a stream of errors.
class SpeciesLookupSheet extends ConsumerStatefulWidget {
  final String initialQuery;
  final ScrollController? scrollController;

  const SpeciesLookupSheet({
    super.key,
    required this.initialQuery,
    this.scrollController,
  });

  @override
  ConsumerState<SpeciesLookupSheet> createState() => _SpeciesLookupSheetState();
}

class _SpeciesLookupSheetState extends ConsumerState<SpeciesLookupSheet> {
  late final TextEditingController _controller;
  List<SpeciesLookupHit>? _hits;
  String _lastQuery = '';
  SpeciesLookupErrorKind? _error;
  bool _searching = false;
  int? _resolvingId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
      _lastQuery = query;
    });
    try {
      final hits = await ref
          .read(speciesLookupServiceProvider)
          .search(query, locale: ref.read(speciesLookupLocaleProvider));
      if (mounted) setState(() => _hits = hits);
    } on SpeciesLookupException catch (e) {
      if (mounted) setState(() => _error = e.kind);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _choose(SpeciesLookupHit hit) async {
    setState(() => _resolvingId = hit.taxonId);
    try {
      final result = await ref
          .read(speciesLookupServiceProvider)
          .resolve(hit.taxonId, locale: ref.read(speciesLookupLocaleProvider));
      if (mounted) Navigator.of(context).pop(result);
    } on SpeciesLookupException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.kind;
          _resolvingId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.marineLife_lookup_title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                autofocus: widget.initialQuery.isEmpty,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: l10n.marineLife_lookup_searchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const ValueKey('lookup_search'),
              onPressed: _searching ? null : _search,
              child: Text(l10n.marineLife_lookup_search),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._body(l10n, theme),
        const SizedBox(height: 16),
        OutlinedButton(
          key: const ValueKey('lookup_create_without'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.marineLife_lookup_createWithout),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.marineLife_lookup_attribution,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  List<Widget> _body(AppLocalizations l10n, ThemeData theme) {
    if (_searching) {
      return const [Center(child: CircularProgressIndicator())];
    }
    final error = _error;
    if (error != null) {
      return [
        Text(_errorText(l10n, error), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: _search,
            child: Text(l10n.marineLife_lookup_retry),
          ),
        ),
      ];
    }
    final hits = _hits;
    if (hits == null) {
      return [
        Text(
          l10n.marineLife_lookup_idle,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ];
    }
    if (hits.isEmpty) {
      return [
        Text(l10n.marineLife_lookup_empty(_lastQuery), textAlign: TextAlign.center),
      ];
    }
    return [for (final hit in hits) _HitTile(hit: hit, resolving: _resolvingId == hit.taxonId, onTap: hit.isResolvable && _resolvingId == null ? () => _choose(hit) : null)];
  }

  String _errorText(AppLocalizations l10n, SpeciesLookupErrorKind kind) =>
      switch (kind) {
        SpeciesLookupErrorKind.offline => l10n.marineLife_lookup_errorOffline,
        SpeciesLookupErrorKind.timeout => l10n.marineLife_lookup_errorTimeout,
        SpeciesLookupErrorKind.server => l10n.marineLife_lookup_errorServer,
        SpeciesLookupErrorKind.malformed =>
          l10n.marineLife_lookup_errorMalformed,
      };
}

class _HitTile extends StatelessWidget {
  final SpeciesLookupHit hit;
  final bool resolving;
  final VoidCallback? onTap;

  const _HitTile({required this.hit, required this.resolving, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final photo = hit.photo;
    final title = hit.commonName ?? hit.scientificName;
    final subtitle = hit.isResolvable
        ? hit.scientificName
        : l10n.marineLife_lookup_unresolvableRank(hit.rank);
    return ListTile(
      enabled: hit.isResolvable,
      leading: SizedBox(
        width: 48,
        height: 48,
        child: photo == null
            ? const Icon(Icons.image_not_supported_outlined)
            : Tooltip(
                message: photo.attribution,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    photo.squareUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: hit.isResolvable
            ? const TextStyle(fontStyle: FontStyle.italic)
            : null,
      ),
      trailing: resolving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              l10n.marineLife_lookup_observations(hit.observationCount),
              style: Theme.of(context).textTheme.bodySmall,
            ),
      onTap: onTap,
    );
  }
}
```

If the test's "Loading details..." string is wanted, show it in place of the spinner text; the plan keeps the spinner only.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/features/marine_life/presentation/widgets/species_lookup_sheet_test.dart`
Expected: `All tests passed!` (6 tests), exit code 0.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
dart format lib/features/marine_life/presentation/widgets/species_lookup_sheet.dart test/features/marine_life/presentation/widgets/species_lookup_sheet_test.dart
git add lib/features/marine_life/presentation/widgets/species_lookup_sheet.dart test/features/marine_life/presentation/widgets/species_lookup_sheet_test.dart
git commit -m "feat(marine-life): add the species lookup sheet"
```

---

### Task 7: "Look up online" on the species edit page

**Files:**
- Modify: `lib/features/marine_life/presentation/pages/species_edit_page.dart` (imports; the `DropdownButtonFormField<SpeciesCategory>` gets a key; a button after the common-name field; an `_applyLookup` method)
- Test: `test/features/marine_life/presentation/pages/species_edit_page_test.dart` (new; the page had no tests)

**Interfaces:**
- Consumes: `showSpeciesLookupSheet` (Task 6), `SpeciesLookupResult` (Task 1), Task 5 strings.
- Produces: the page fills common name, scientific name, category and taxonomy class from a lookup; description is untouched.

Background: `DropdownButtonFormField` takes `initialValue`, which only applies on first build, so a programmatic category change needs the field rebuilt: keying the dropdown on the category does that.

- [ ] **Step 1: Write the failing widget test**

`test/features/marine_life/presentation/pages/species_edit_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/services/species_lookup_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_edit_page.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_lookup_providers.dart';

import '../../../../helpers/test_app.dart';

class _FakeLookup implements SpeciesLookupService {
  @override
  Future<List<SpeciesLookupHit>> search(
    String query, {
    required String locale,
  }) async => const [
    SpeciesLookupHit(
      taxonId: 52188,
      scientificName: 'Rhincodon typus',
      rank: 'species',
      rankLevel: 10,
      commonName: 'Whale Shark',
      observationCount: 5,
    ),
  ];

  @override
  Future<SpeciesLookupResult> resolve(
    int taxonId, {
    required String locale,
  }) async => const SpeciesLookupResult(
    taxonId: 52188,
    commonName: 'Whale Shark',
    scientificName: 'Rhincodon typus',
    category: SpeciesCategory.shark,
    taxonomyClass: 'Chondrichthyes',
  );
}

void main() {
  testWidgets('a lookup fills name, scientific name, category and class', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          speciesLookupServiceProvider.overrideWithValue(_FakeLookup()),
          speciesLookupLocaleProvider.overrideWithValue('en'),
        ],
        child: const SpeciesEditPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'whale');
    await tester.tap(find.text('Look up online'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Whale Shark'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Whale Shark'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Rhincodon typus'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Chondrichthyes'), findsOneWidget);
    expect(find.text('Shark'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/marine_life/presentation/pages/species_edit_page_test.dart`
Expected: fails at `find.text('Look up online')` (no such button yet).

- [ ] **Step 3: Add the button and the fill**

In `species_edit_page.dart`:

1. Add imports:
```dart
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_lookup_sheet.dart';
```
2. Directly after the common-name `TextFormField(...)` (the one bound to `_commonNameController`, before the `const SizedBox(height: 16),` that precedes the scientific-name field) add:
```dart
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        key: const ValueKey('species_lookup_online'),
                        icon: const Icon(Icons.travel_explore),
                        label: Text(context.l10n.marineLife_lookup_button),
                        onPressed: _lookUpOnline,
                      ),
                    ),
```
3. Give the category dropdown a key so a programmatic change rebuilds it: on `DropdownButtonFormField<SpeciesCategory>(` add `key: ValueKey('species_category_${_category.name}'),` as the first argument.
4. Add the methods to the state class:
```dart
  Future<void> _lookUpOnline() async {
    final result = await showSpeciesLookupSheet(
      context,
      initialQuery: _commonNameController.text.trim(),
    );
    if (result != null && mounted) _applyLookup(result);
  }

  /// Fills what the lookup knows and leaves the description alone; the
  /// diver can still edit any field before saving.
  void _applyLookup(SpeciesLookupResult result) {
    setState(() {
      _commonNameController.text = result.commonName;
      _scientificNameController.text = result.scientificName;
      _taxonomyClassController.text = result.taxonomyClass ?? '';
      _category = result.category;
    });
  }
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/marine_life/presentation/pages/species_edit_page_test.dart`
Expected: `All tests passed!`, exit code 0.

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
dart format lib/features/marine_life/presentation/pages/species_edit_page.dart test/features/marine_life/presentation/pages/species_edit_page_test.dart
git add lib/features/marine_life/presentation/pages/species_edit_page.dart test/features/marine_life/presentation/pages/species_edit_page_test.dart
git commit -m "feat(marine-life): look a species up online from the edit page"
```

---

### Task 8: Lookup from the dive species picker's "add custom species"

**Files:**
- Modify: `lib/features/marine_life/data/repositories/species_repository.dart` (add `findSpeciesByScientificName`)
- Modify: `lib/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart` (`_addCustomSpecies`)
- Test: `test/features/marine_life/data/repositories/species_repository_lookup_test.dart` (new), `test/features/dive_log/presentation/widgets/pickers/species_picker_sheet_lookup_test.dart` (new)

**Interfaces:**
- Consumes: Tasks 1, 4, 6; `SpeciesRepository.createSpecies({commonName, scientificName, category, taxonomyClass, description})` and `getOrCreateSpecies({commonName, scientificName, category})`.
- Produces: `Future<Species?> SpeciesRepository.findSpeciesByScientificName(String scientificName)`; the picker's add path opens the lookup sheet, creates (or reuses) the species from the result, and falls back to today's name-only creation on null.

- [ ] **Step 1: Write the failing repository test**

`test/features/marine_life/data/repositories/species_repository_lookup_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late SpeciesRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = SpeciesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('finds a species by scientific name, case-insensitively', () async {
    final created = await repository.createSpecies(
      commonName: 'Whale Shark',
      scientificName: 'Rhincodon typus',
      category: SpeciesCategory.shark,
    );

    final found = await repository.findSpeciesByScientificName(
      'rhincodon TYPUS',
    );

    expect(found?.id, created.id);
  });

  test('returns null for an unknown or empty scientific name', () async {
    expect(await repository.findSpeciesByScientificName('Nomen nudum'), isNull);
    expect(await repository.findSpeciesByScientificName('  '), isNull);
  });
}
```

- [ ] **Step 2: Write the failing picker test**

`test/features/dive_log/presentation/widgets/pickers/species_picker_sheet_lookup_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/data/services/species_lookup_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_lookup_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _hit = SpeciesLookupHit(
  taxonId: 52188,
  scientificName: 'Rhincodon typus',
  rank: 'species',
  rankLevel: 10,
  commonName: 'Whale Shark',
  observationCount: 5,
);

const _resolved = SpeciesLookupResult(
  taxonId: 52188,
  commonName: 'Whale Shark',
  scientificName: 'Rhincodon typus',
  category: SpeciesCategory.shark,
  taxonomyClass: 'Chondrichthyes',
);

class _FakeLookup implements SpeciesLookupService {
  @override
  Future<List<SpeciesLookupHit>> search(String query, {required String locale}) async =>
      const [_hit];

  @override
  Future<SpeciesLookupResult> resolve(int taxonId, {required String locale}) async =>
      _resolved;
}

/// Records creations; `existing` is what a scientific-name lookup returns.
class _RecordingRepository extends Fake implements SpeciesRepository {
  _RecordingRepository({this.existing});

  final Species? existing;
  final List<Map<String, Object?>> created = [];
  int nameOnlyCreations = 0;

  @override
  Future<Species?> findSpeciesByScientificName(String scientificName) async =>
      existing;

  @override
  Future<Species> createSpecies({
    required String commonName,
    String? scientificName,
    required SpeciesCategory category,
    String? taxonomyClass,
    String? description,
  }) async {
    created.add({
      'commonName': commonName,
      'scientificName': scientificName,
      'category': category,
      'taxonomyClass': taxonomyClass,
    });
    return Species(
      id: 'new-1',
      commonName: commonName,
      scientificName: scientificName,
      category: category,
      taxonomyClass: taxonomyClass,
    );
  }

  @override
  Future<Species> getOrCreateSpecies({
    required String commonName,
    String? scientificName,
    required SpeciesCategory category,
  }) async {
    nameOnlyCreations += 1;
    return Species(id: 'plain-1', commonName: commonName, category: category);
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required _RecordingRepository repository,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allSpeciesProvider.overrideWith((ref) async => const []),
        speciesByCategoryProvider.overrideWith((ref, category) async => const []),
        speciesSearchProvider.overrideWith((ref, query) async => const []),
        speciesRepositoryProvider.overrideWithValue(repository),
        speciesLookupServiceProvider.overrideWithValue(_FakeLookup()),
        speciesLookupLocaleProvider.overrideWithValue('en'),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SpeciesPickerSheet(
            scrollController: ScrollController(),
            onSpeciesSelected: (_, _, _) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _typeAndAdd(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'whale');
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('whale').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a lookup result creates the species with its fields and '
      'opens the sighting dialog', (tester) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository: repository);

    await _typeAndAdd(tester);
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Whale Shark'));
    await tester.pumpAndSettle();

    expect(repository.created.single['scientificName'], 'Rhincodon typus');
    expect(repository.created.single['category'], SpeciesCategory.shark);
    expect(repository.created.single['taxonomyClass'], 'Chondrichthyes');
    expect(repository.nameOnlyCreations, 0);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('an existing species with that scientific name is reused', (
    tester,
  ) async {
    const existing = Species(
      id: 'sp_whale_shark',
      commonName: 'Whale Shark',
      scientificName: 'Rhincodon typus',
      category: SpeciesCategory.shark,
      isBuiltIn: true,
    );
    final repository = _RecordingRepository(existing: existing);
    await _pump(tester, repository: repository);

    await _typeAndAdd(tester);
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Whale Shark'));
    await tester.pumpAndSettle();

    expect(repository.created, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Create without lookup keeps the name-only path', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository: repository);

    await _typeAndAdd(tester);
    await tester.tap(find.text('Create without lookup'));
    await tester.pumpAndSettle();

    expect(repository.nameOnlyCreations, 1);
    expect(repository.created, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
```

The empty-state add button's label is `diveLog_speciesPicker_addNew(query)`; `_typeAndAdd` finds it as the last widget whose text contains the query (the search field is the first).

- [ ] **Step 3: Run both tests to verify they fail**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/features/marine_life/data/repositories/species_repository_lookup_test.dart test/features/dive_log/presentation/widgets/pickers/species_picker_sheet_lookup_test.dart`
Expected: compilation errors (`findSpeciesByScientificName` undefined) and the picker tests failing on the missing sheet.

- [ ] **Step 4: Implement**

In `species_repository.dart`, after `getOrCreateSpecies` add:

```dart
  /// The species whose scientific name equals [scientificName], ignoring
  /// case, or null. Lets a lookup select an existing row (built-in or
  /// custom) instead of creating a twin.
  Future<domain.Species?> findSpeciesByScientificName(
    String scientificName,
  ) async {
    final needle = scientificName.trim().toLowerCase();
    if (needle.isEmpty) return null;
    final row = await _db
        .customSelect(
          'SELECT id FROM species WHERE LOWER(scientific_name) = ? LIMIT 1',
          variables: [Variable.withString(needle)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return getSpeciesById(row.data['id'] as String);
  }
```

In `species_picker_sheet.dart`, add the imports

```dart
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_lookup_sheet.dart';
```

and replace `_addCustomSpecies` with:

```dart
  /// The empty state's "add" path: look the name up first so a custom
  /// species gets its scientific name, category and class; "Create without
  /// lookup" (or a dismissed sheet) keeps the old name-only creation, so an
  /// offline diver loses nothing.
  Future<void> _addCustomSpecies(String name) async {
    final result = await showSpeciesLookupSheet(context, initialQuery: name);
    if (!mounted) return;
    final repository = ref.read(speciesRepositoryProvider);
    final species = result == null
        ? await repository.getOrCreateSpecies(
            commonName: name,
            category: SpeciesCategory.other,
          )
        : await _speciesFromLookup(repository, result);
    if (mounted) _showSightingDetails(species);
  }

  Future<Species> _speciesFromLookup(
    SpeciesRepository repository,
    SpeciesLookupResult result,
  ) async {
    final existing = await repository.findSpeciesByScientificName(
      result.scientificName,
    );
    if (existing != null) return existing;
    return repository.createSpecies(
      commonName: result.commonName,
      scientificName: result.scientificName,
      category: result.category,
      taxonomyClass: result.taxonomyClass,
    );
  }
```

with `import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';` for the type.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/features/marine_life/data/repositories/species_repository_lookup_test.dart test/features/dive_log/presentation/widgets/pickers/`
Expected: `All tests passed!`, exit code 0 (the existing picker tests included).

- [ ] **Step 6: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
dart format lib/features/marine_life/data/repositories/species_repository.dart lib/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart test/features/marine_life/data/repositories/species_repository_lookup_test.dart test/features/dive_log/presentation/widgets/pickers/species_picker_sheet_lookup_test.dart
git add lib/features/marine_life/data/repositories/species_repository.dart lib/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart test/features/marine_life/data/repositories/species_repository_lookup_test.dart test/features/dive_log/presentation/widgets/pickers/species_picker_sheet_lookup_test.dart
git commit -m "feat(dive-log): look a new species up online from the species picker"
```

---

### Task 9: Add a species from the reef tier's unmatched GBIF names

**Files:**
- Modify: `lib/features/reef/presentation/widgets/nearby_species_tier.dart` (`_unmatchedChip` becomes an `ActionChip`; new `_addFromLookup`)
- Test: `test/features/reef/presentation/widgets/nearby_species_tier_lookup_test.dart` (new)

**Interfaces:**
- Consumes: Tasks 4, 6, 8 (`findSpeciesByScientificName`, `createSpecies`); `siteExpectedSpeciesNotifierProvider(siteId).notifier.addSpecies(String)`; `reef_species_addFromLookup` string.
- Produces: tapping an unmatched chip creates (or reuses) the species and adds it to the site's expected list; when the lookup is not a single exact species match, the sheet opens prefilled.

- [ ] **Step 1: Write the failing widget test**

`test/features/reef/presentation/widgets/nearby_species_tier_lookup_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/data/services/species_lookup_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_lookup_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_snapshot.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/reef/presentation/widgets/nearby_species_tier.dart';

import '../../../../helpers/l10n_test_helpers.dart';

const _location = GeoPoint(12.16, -68.28);

ReefSnapshot _snapshotWithUnmatched(List<String> names) => ReefSnapshot(
  habitat: const ReefPart.empty(),
  health: const ReefPart.empty(),
  protection: const ReefPart.empty(),
  species: ReefPart.ok(NearbySpecies(matched: const [], unmatchedNames: names)),
);

class _FakeLookup implements SpeciesLookupService {
  _FakeLookup(this.hits);
  final List<SpeciesLookupHit> hits;
  final List<int> resolved = [];

  @override
  Future<List<SpeciesLookupHit>> search(String query, {required String locale}) async => hits;

  @override
  Future<SpeciesLookupResult> resolve(int taxonId, {required String locale}) async {
    resolved.add(taxonId);
    return const SpeciesLookupResult(
      taxonId: 7,
      commonName: 'Stove-pipe Sponge',
      scientificName: 'Aplysina archeri',
      category: SpeciesCategory.invertebrate,
      taxonomyClass: 'Demospongiae',
    );
  }
}

class _RecordingRepository extends Fake implements SpeciesRepository {
  final List<String> created = [];
  final List<String> added = [];

  @override
  Future<List<SiteSpeciesEntry>> getExpectedSpeciesForSite(String siteId) async =>
      const [];

  @override
  Future<Species?> findSpeciesByScientificName(String scientificName) async => null;

  @override
  Future<Species> createSpecies({
    required String commonName,
    String? scientificName,
    required SpeciesCategory category,
    String? taxonomyClass,
    String? description,
  }) async {
    created.add(scientificName ?? commonName);
    return Species(
      id: 'new-1',
      commonName: commonName,
      scientificName: scientificName,
      category: category,
    );
  }

  @override
  Future<SiteSpeciesEntry> addExpectedSpecies({
    required String siteId,
    required String speciesId,
    String notes = '',
  }) async {
    added.add(speciesId);
    return SiteSpeciesEntry(
      id: 'entry-1',
      siteId: siteId,
      speciesId: speciesId,
      speciesName: 'Stove-pipe Sponge',
      category: SpeciesCategory.invertebrate,
      createdAt: DateTime(2026),
    );
  }
}

Widget _harness(_FakeLookup lookup, _RecordingRepository repository) =>
    ProviderScope(
      overrides: [
        reefSnapshotProvider(
          ReefSnapshotRequest(location: _location),
        ).overrideWith((ref) async => _snapshotWithUnmatched(['Aplysina archeri'])),
        allSpeciesProvider.overrideWith(
          (ref) async => const [
            Species(id: 'sp_x', commonName: 'Filler', category: SpeciesCategory.fish),
          ],
        ),
        speciesRepositoryProvider.overrideWithValue(repository),
        speciesLookupServiceProvider.overrideWithValue(lookup),
        speciesLookupLocaleProvider.overrideWithValue('en'),
      ],
      child: localizedMaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          body: NearbySpeciesTier(siteId: 'site-1', location: _location),
        ),
      ),
    );

const _exact = SpeciesLookupHit(
  taxonId: 7,
  scientificName: 'Aplysina archeri',
  rank: 'species',
  rankLevel: 10,
  commonName: 'Stove-pipe Sponge',
  observationCount: 12,
);

void main() {
  testWidgets('a single exact match creates the species and adds it to the '
      'site without opening the sheet', (tester) async {
    final lookup = _FakeLookup(const [_exact]);
    final repository = _RecordingRepository();
    await tester.pumpWidget(_harness(lookup, repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aplysina archeri'));
    await tester.pumpAndSettle();

    expect(lookup.resolved, [7]);
    expect(repository.created, ['Aplysina archeri']);
    expect(repository.added, ['new-1']);
    expect(find.text('Look up a species'), findsNothing);
  });

  testWidgets('an ambiguous answer opens the sheet prefilled', (tester) async {
    final lookup = _FakeLookup(const [
      _exact,
      SpeciesLookupHit(
        taxonId: 8,
        scientificName: 'Aplysina archeri var. b',
        rank: 'variety',
        rankLevel: 5,
        observationCount: 1,
      ),
    ]);
    final repository = _RecordingRepository();
    await tester.pumpWidget(_harness(lookup, repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aplysina archeri'));
    await tester.pumpAndSettle();

    expect(find.text('Look up a species'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Aplysina archeri'),
      findsOneWidget,
    );
    expect(repository.created, isEmpty);
  });
}
```

The `allSpeciesProvider` override is non-empty on purpose: the tier renders nothing when the catalog is empty.

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/features/reef/presentation/widgets/nearby_species_tier_lookup_test.dart`
Expected: the first test fails (the chip is not tappable; nothing created).

- [ ] **Step 3: Make the unmatched chip act**

In `nearby_species_tier.dart`, add the imports

```dart
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_lookup_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_lookup_sheet.dart';
```

replace `_unmatchedChip` with:

```dart
  /// A GBIF name the catalog lacks. The chip looks it up and adds it: this
  /// list is, in effect, the species missing from the catalog at this site.
  Widget _unmatchedChip(BuildContext context, String scientificName) {
    final theme = Theme.of(context);

    return ActionChip(
      avatar: const ExcludeSemantics(child: Icon(Icons.help_outline, size: 16)),
      label: Text(scientificName, style: theme.textTheme.bodySmall),
      tooltip: context.l10n.reef_species_addFromLookup,
      onPressed: () => _addFromLookup(scientificName),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
```

and add to the state class:

```dart
  /// One resolvable hit whose scientific name is the GBIF name goes straight
  /// through; anything else (none, several, a lookup failure) opens the
  /// sheet with the name prefilled so the diver decides.
  Future<void> _addFromLookup(String scientificName) async {
    final lookup = ref.read(speciesLookupServiceProvider);
    final locale = ref.read(speciesLookupLocaleProvider);
    SpeciesLookupResult? result;
    try {
      final hits = await lookup.search(scientificName, locale: locale);
      final exact = hits
          .where(
            (h) =>
                h.isResolvable &&
                h.scientificName.toLowerCase() == scientificName.toLowerCase(),
          )
          .toList();
      if (exact.length == 1) {
        result = await lookup.resolve(exact.single.taxonId, locale: locale);
      }
    } on SpeciesLookupException {
      result = null;
    }
    if (!mounted) return;
    result ??= await showSpeciesLookupSheet(context, initialQuery: scientificName);
    if (result == null || !mounted) return;

    final repository = ref.read(speciesRepositoryProvider);
    final species =
        await repository.findSpeciesByScientificName(result.scientificName) ??
        await repository.createSpecies(
          commonName: result.commonName,
          scientificName: result.scientificName,
          category: result.category,
          taxonomyClass: result.taxonomyClass,
        );
    if (!mounted) return;
    await ref
        .read(siteExpectedSpeciesNotifierProvider(widget.siteId).notifier)
        .addSpecies(species.id);
  }
```

`SpeciesRepository` is already reachable through `speciesRepositoryProvider` (imported via `species_providers.dart`); keep the explicit repository import only if the analyzer needs the type.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/features/reef/presentation/widgets/`
Expected: `All tests passed!`, exit code 0 (the existing tier tests count `RawChip`s; an `ActionChip` is still one `RawChip`).

- [ ] **Step 5: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
dart format lib/features/reef/presentation/widgets/nearby_species_tier.dart test/features/reef/presentation/widgets/nearby_species_tier_lookup_test.dart
git add lib/features/reef/presentation/widgets/nearby_species_tier.dart test/features/reef/presentation/widgets/nearby_species_tier_lookup_test.dart
git commit -m "feat(reef): add an unmatched nearby species to the catalog through the lookup"
```

---

### Task 10: "Suggest for the catalog": URL builder, launcher, detail page menu

**Files:**
- Create: `lib/features/marine_life/domain/services/species_suggestion_url.dart`
- Create: `lib/features/marine_life/presentation/helpers/species_suggestion_launcher.dart`
- Modify: `lib/features/marine_life/presentation/pages/species_detail_page.dart` (AppBar actions; imports)
- Test: `test/features/marine_life/domain/services/species_suggestion_url_test.dart`, `test/features/marine_life/presentation/pages/species_detail_page_suggest_test.dart`

**Interfaces:**
- Consumes: `Species`; `packageInfoProvider` (`FutureProvider<PackageInfo>` in `settings_providers.dart`) and `formatAppVersion(PackageInfo)` from `lib/core/utils/app_version.dart`; `localeProvider`; `launchUrl` from `url_launcher`; `Clipboard`; Task 5 strings; `speciesProvider(id)`, `speciesStatisticsProvider(id)` and `speciesSightingsProvider(id)` for the page test.
- Produces:
  ```dart
  Uri buildSpeciesSuggestionUrl({required Species species, required String locale, required String appVersion});
  typedef UrlLauncher = Future<bool> Function(Uri uri);
  final speciesSuggestionLaunchProvider = Provider<UrlLauncher>;
  Future<void> launchSpeciesSuggestion(BuildContext context, Uri uri, {required UrlLauncher launch});
  ```

- [ ] **Step 1: Write the failing builder test**

`test/features/marine_life/domain/services/species_suggestion_url_test.dart`:

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/services/species_suggestion_url.dart';

const _species = Species(
  id: 'c1',
  commonName: 'Stove-pipe Sponge',
  scientificName: 'Aplysina archeri',
  category: SpeciesCategory.invertebrate,
  taxonomyClass: 'Demospongiae',
  description: 'Tall purple tubes on the wall.',
);

Map<String, dynamic> _bodyJson(Uri uri) {
  final body = uri.queryParameters['body']!;
  final start = body.indexOf('```json') + '```json'.length;
  final end = body.lastIndexOf('```');
  return jsonDecode(body.substring(start, end).trim()) as Map<String, dynamic>;
}

void main() {
  test('targets a new issue with the title, label and a JSON body', () {
    final uri = buildSpeciesSuggestionUrl(
      species: _species,
      locale: 'de',
      appVersion: '1.7.6.7001',
    );

    expect(uri.scheme, 'https');
    expect(uri.host, 'github.com');
    expect(uri.path, '/submersion-app/submersion/issues/new');
    expect(uri.queryParameters['title'], 'Species suggestion: Stove-pipe Sponge');
    expect(uri.queryParameters['labels'], 'species-suggestion');

    final json = _bodyJson(uri);
    expect(json['commonName'], 'Stove-pipe Sponge');
    expect(json['scientificName'], 'Aplysina archeri');
    expect(json['category'], 'invertebrate');
    expect(json['taxonomyClass'], 'Demospongiae');
    expect(json['description'], 'Tall purple tubes on the wall.');
    expect(json['locale'], 'de');
    expect(json['appVersion'], '1.7.6.7001');
  });

  test('keeps the whole URL under the cap by truncating the description', () {
    final long = _species.copyWith(description: 'x' * 20000);

    final uri = buildSpeciesSuggestionUrl(
      species: long,
      locale: 'en',
      appVersion: '1.0.0.1',
    );

    expect(uri.toString().length, lessThanOrEqualTo(8000));
    expect(_bodyJson(uri)['scientificName'], 'Aplysina archeri');
  });

  test('encodes non-ASCII names', () {
    final uri = buildSpeciesSuggestionUrl(
      species: _species.copyWith(commonName: 'Süßwasser Grundel'),
      locale: 'de',
      appVersion: '1.0.0.1',
    );

    expect(uri.queryParameters['title'], 'Species suggestion: Süßwasser Grundel');
    expect(uri.toString(), isNot(contains('ü')));
  });
}
```

- [ ] **Step 2: Write the failing page test**

`test/features/marine_life/presentation/pages/species_detail_page_suggest_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/helpers/species_suggestion_launcher.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_detail_page.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/statistics/domain/entities/species_statistics.dart';
import 'package:submersion/features/statistics/presentation/providers/statistics_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _custom = Species(
  id: 'c1',
  commonName: 'Stove-pipe Sponge',
  scientificName: 'Aplysina archeri',
  category: SpeciesCategory.invertebrate,
);

const _builtIn = Species(
  id: 'sp_whale_shark',
  commonName: 'Whale Shark',
  category: SpeciesCategory.shark,
  isBuiltIn: true,
);

Future<List<Uri>> _pump(WidgetTester tester, Species species) async {
  final launched = <Uri>[];
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        ...overrides,
        speciesProvider(species.id).overrideWith((ref) async => species),
        speciesStatisticsProvider(species.id).overrideWith(
          (ref) async => SpeciesStatistics.empty,
        ),
        speciesSightingsProvider(species.id).overrideWith((ref) async => const []),
        packageInfoProvider.overrideWith(
          (ref) async => PackageInfo(
            appName: 'Submersion',
            packageName: 'app.submersion',
            version: '1.7.6',
            buildNumber: '7001',
          ),
        ),
        localeProvider.overrideWithValue('en'),
        speciesSuggestionLaunchProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return true;
        }),
      ],
      child: SpeciesDetailPage(speciesId: species.id),
    ),
  );
  await tester.pumpAndSettle();
  return launched;
}

void main() {
  testWidgets('a custom species offers Suggest for the catalog', (
    tester,
  ) async {
    final launched = await _pump(tester, _custom);

    await tester.tap(find.byKey(const ValueKey('species_detail_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suggest for the catalog'));
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(launched.single.host, 'github.com');
    expect(
      launched.single.queryParameters['title'],
      'Species suggestion: Stove-pipe Sponge',
    );
  });

  testWidgets('a built-in species has no menu', (tester) async {
    await _pump(tester, _builtIn);

    expect(find.byKey(const ValueKey('species_detail_menu')), findsNothing);
  });
}
```

- [ ] **Step 3: Run both tests to verify they fail**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/features/marine_life/domain/services/species_suggestion_url_test.dart test/features/marine_life/presentation/pages/species_detail_page_suggest_test.dart`
Expected: compilation errors, the two new source files are missing.

- [ ] **Step 4: Implement**

`lib/features/marine_life/domain/services/species_suggestion_url.dart`:

```dart
import 'dart:convert';

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
/// The description is the only free-text field and is truncated first when
/// the URL would exceed the cap.
Uri buildSpeciesSuggestionUrl({
  required Species species,
  required String locale,
  required String appVersion,
}) {
  var description = species.description ?? '';
  Uri build() => Uri.https(
    'github.com',
    '/$speciesSuggestionRepository/issues/new',
    {
      'title': 'Species suggestion: ${species.commonName}',
      'labels': speciesSuggestionLabel,
      'body': _body(species, description, locale, appVersion),
    },
  );

  var uri = build();
  while (uri.toString().length > speciesSuggestionMaxUrlLength &&
      description.isNotEmpty) {
    final over = uri.toString().length - speciesSuggestionMaxUrlLength;
    // Encoded characters can be three bytes each; cut generously.
    final cut = (over ~/ 3 + 1).clamp(1, description.length);
    description = description.substring(0, description.length - cut);
    uri = build();
  }
  return uri;
}

String _body(
  Species species,
  String description,
  String locale,
  String appVersion,
) {
  final json = const JsonEncoder.withIndent('  ').convert({
    'commonName': species.commonName,
    'scientificName': species.scientificName,
    'category': species.category.name,
    'taxonomyClass': species.taxonomyClass,
    'description': description,
    'locale': locale,
    'appVersion': appVersion,
  });
  return 'Please consider adding this species to the bundled catalog.\n\n'
      '```json\n$json\n```\n';
}
```

`lib/features/marine_life/presentation/helpers/species_suggestion_launcher.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/l10n/l10n_extension.dart';

typedef UrlLauncher = Future<bool> Function(Uri uri);

/// Opens URLs in the external browser. A provider so widget tests can
/// record the URL instead of leaving the app.
final speciesSuggestionLaunchProvider = Provider<UrlLauncher>((ref) {
  return (uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
});

/// Same shape as Settings' report-issue action: no `canLaunchUrl` guard (it
/// false-negatives for https on Android 11+), external mode, and a copy-link
/// snackbar when the launch fails.
Future<void> launchSpeciesSuggestion(
  BuildContext context,
  Uri uri, {
  required UrlLauncher launch,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  var didLaunch = false;
  try {
    didLaunch = await launch(uri);
  } catch (_) {
    didLaunch = false;
  }
  if (didLaunch) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(l10n.marineLife_suggest_couldNotOpen),
      action: SnackBarAction(
        label: l10n.marineLife_suggest_copyLink,
        onPressed: () => Clipboard.setData(ClipboardData(text: uri.toString())),
      ),
    ),
  );
}
```

In `species_detail_page.dart`, add the imports

```dart
import 'package:submersion/core/utils/app_version.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/services/species_suggestion_url.dart';
import 'package:submersion/features/marine_life/presentation/helpers/species_suggestion_launcher.dart';
```

replace the `actions:` list with:

```dart
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: context.l10n.marineLife_speciesDetail_editTooltip,
            onPressed: () => context.push('/species/$speciesId/edit'),
          ),
          // Only a custom species can be suggested: built-ins already are
          // the catalog.
          if (speciesAsync.value case final species? when !species.isBuiltIn)
            PopupMenuButton<String>(
              key: const ValueKey('species_detail_menu'),
              onSelected: (value) {
                if (value == 'suggest') _suggestForCatalog(context, ref, species);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'suggest',
                  child: Text(
                    context.l10n.marineLife_speciesDetail_suggestForCatalog,
                  ),
                ),
              ],
            ),
        ],
```

and add to the class:

```dart
  Future<void> _suggestForCatalog(
    BuildContext context,
    WidgetRef ref,
    Species species,
  ) async {
    final info = await ref.read(packageInfoProvider.future);
    if (!context.mounted) return;
    final uri = buildSpeciesSuggestionUrl(
      species: species,
      locale: ref.read(localeProvider),
      appVersion: formatAppVersion(info),
    );
    await launchSpeciesSuggestion(
      context,
      uri,
      launch: ref.read(speciesSuggestionLaunchProvider),
    );
  }
```

`packageInfoProvider` and `localeProvider` come from `settings_providers.dart`, which the page already imports.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup && flutter test test/features/marine_life/domain/services/species_suggestion_url_test.dart test/features/marine_life/presentation/pages/`
Expected: `All tests passed!`, exit code 0.

- [ ] **Step 6: Format and commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
dart format lib/features/marine_life test/features/marine_life
git add lib/features/marine_life/domain/services/species_suggestion_url.dart lib/features/marine_life/presentation/helpers/species_suggestion_launcher.dart lib/features/marine_life/presentation/pages/species_detail_page.dart test/features/marine_life/domain/services/species_suggestion_url_test.dart test/features/marine_life/presentation/pages/species_detail_page_suggest_test.dart
git commit -m "feat(marine-life): suggest a custom species for the catalog through a prefilled issue"
```

---

### Task 11: Docs, formatting, analysis, full test run

**Files:**
- Modify: `docs/features/marine-life.md`

- [ ] **Step 1: Update the feature doc**

In `docs/features/marine-life.md`, in the `## Adding Custom Species` section, after the numbered steps add:

```markdown
### Looking a species up online

When you add a species, tap **Look up online** to search iNaturalist by common
or scientific name. Choosing a result fills the common name (in your language
where iNaturalist has it), the scientific name, the category and the taxonomy
class; you can still edit anything before saving. The same lookup is offered
when you add a species from the dive's marine life picker, and on a dive site's
"Recorded nearby" list for names the catalog does not know yet.

Lookups happen only when you tap **Look up**; nothing is sent while you type,
and nothing from iNaturalist is stored except the fields you save.

### Suggesting a species for the catalog

On a custom species, the menu offers **Suggest for the catalog**. It opens a
prefilled GitHub issue in your browser with the species' details; posting it
is up to you.
```

- [ ] **Step 2: Format and confirm only intended files changed**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
dart format .
git status --short
```

Expected: only `docs/features/marine-life.md` (plus the untracked spec file copied in before the plan started).

- [ ] **Step 3: Analyze the whole project**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
flutter analyze --fatal-infos
```

Expected: `Analyzing species-online-lookup...` then `No issues found!`.

- [ ] **Step 4: Run the full test suite once**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
flutter test
```

Detach it to a log with the exit code appended and read the summary line yourself; check first that no other session's `flutter_tester` processes are running (`ps -axo command | grep flutter_tester | grep -o "packages=[^ ]*"`). Expected: `All tests passed!` with exit 0 and a summary line present; a run ending in `Bad state: Cannot close sink while adding stream` with no summary was killed and must be rerun.

- [ ] **Step 5: Commit the docs**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/species-online-lookup
git add docs/features/marine-life.md
git commit -m "docs: describe the online species lookup and catalog suggestions"
```

Do not push. Report the branch state and stop.

---

## Self-review notes

- Spec coverage: section 3 API shape (Task 1 fixtures and parsers); 4 service (Task 3); 5 mapper (Task 2); 6 sheet (Task 6); 7 entry points (Tasks 7, 8, 9, with the scientific-name dedupe in Task 8); 8 contribution channel (Task 10); 9 l10n (Task 5); 10 tests across tasks; docs (Task 11). Locale resolution and DI (Task 4) serve sections 4 and 6.
- Deviations, deliberate: the spec's `SpeciesLookupException(kind)` gained an optional `detail` for logs; the "Loading details..." string exists but the sheet shows a spinner in the trailing slot instead of the text (the key stays for a later polish); the reef chip treats a lookup failure as "open the sheet" rather than an error toast, which keeps the tier's one-tap promise honest.
- Type consistency: `SpeciesLookupService` (Task 3) is what every fake implements in Tasks 6 to 9; `SpeciesLookupResult` fields used by Tasks 7 to 9 (`commonName`, `scientificName`, `category`, `taxonomyClass`) are all declared in Task 1; `findSpeciesByScientificName` is added in Task 8 before Task 9 calls it; `speciesSuggestionLaunchProvider` and `launchSpeciesSuggestion` are both in Task 10's helper file; `speciesSightingsProvider` comes from the merged Species page work (`seen_species_providers.dart`), which is on `origin/main`.
