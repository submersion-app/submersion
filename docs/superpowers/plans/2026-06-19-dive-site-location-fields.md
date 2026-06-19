# Dive Site Location Fields (City, Island, Body of Water) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add editable City and Island fields to dive sites and surface the already-stored Body of Water field, all at full parity with the existing Country/Region fields.

**Architecture:** Two new nullable text columns (`city`, `island`) join the existing-but-unmapped `body_of_water` column on the `dive_sites` table. All three flow through the Drift schema, the `DiveSite` domain entity, the repository read/write/search paths, country-filtered autocomplete suggestions, the customizable table columns (`SiteField`), the edit form, and the detail view. Sync is automatic via Drift's generated `toJson`/`fromJson`.

**Tech Stack:** Flutter, Drift ORM (SQLite), Riverpod, Flutter gen-l10n (ARB), flutter_test.

## Global Constraints

- Schema version: bump `DiveDatabase.currentSchemaVersion` from `89` to `90`. New migration block guarded with `PRAGMA table_info`.
- All migrations are idempotent / PRAGMA-guarded so a healthy DB no-ops.
- `dart format .` must pass with no changes; `flutter analyze` must be clean (whole project, not piped/tailed).
- New user-facing strings must be added to the `app_en.arb` template AND translated into all 9 non-English locales (de, es, fr, he, hu, it, nl, pt, zh) — no English fallbacks. Regenerate localizations after.
- Units: not applicable here (all three fields are free text), but never hardcode unit assumptions.
- No emojis in code/comments. Immutability: entity uses `copyWith`, never mutate.
- After changing any Drift table or any class with generated code, run `dart run build_runner build --delete-conflicting-outputs`.
- Commit after each task. No `Co-Authored-By` lines.

---

## File Structure

| File | Responsibility | Change |
| --- | --- | --- |
| `lib/core/database/database.dart` | Drift `DiveSites` table + migrations | add `city`/`island` columns, `from < 90` migration, version bump |
| `lib/features/dive_sites/domain/entities/dive_site.dart` | `DiveSite` domain entity + `locationString` | add 3 fields, `copyWith`, `props`, update getter |
| `lib/features/dive_sites/data/repositories/site_repository_impl.dart` | Read/write/search mapping | map 3 fields in read + all write paths + search |
| `lib/features/dive_sites/domain/services/site_suggestions.dart` | Autocomplete suggestion lists | 3 new helpers |
| `lib/features/dive_sites/domain/constants/site_field.dart` | Customizable table columns | 3 new `SiteField` enum values + adapter cases |
| `lib/features/dive_sites/presentation/pages/site_edit_page.dart` | Edit form | 3 new `SuggestionField`s |
| `lib/features/dive_sites/presentation/pages/site_detail_page.dart` | Detail view | 3 new location rows |
| `lib/l10n/arb/app_*.arb` (10 files) | Localized strings | 6 new keys × 10 locales |

Note: the repository's read mapper is named **`_mapRowToSite`** (not `_toEntity`).

---

## Task 1: Schema columns + migration + codegen

**Files:**
- Modify: `lib/core/database/database.dart` (table `class DiveSites` ~line 339; `currentSchemaVersion` line 1632; migration tail ~line 4163)
- Test: `test/features/dive_sites/data/repositories/site_repository_test.dart`

**Interfaces:**
- Produces: `DiveSitesCompanion` and generated `DiveSiteData` gain `city` and `island` (`String?`) fields; generated `DiveSiteData.toJson()`/`fromJson()` include `city`, `island`, `body_of_water`.

- [ ] **Step 1: Write the failing test**

Add to `test/features/dive_sites/data/repositories/site_repository_test.dart` (inside the top-level `main()` group, near other persistence tests):

```dart
test('dive_sites table persists city and island columns', () async {
  final db = DiveDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: 'site-ci',
          name: 'Test Site',
          createdAt: now,
          updatedAt: now,
          city: const Value('Cebu City'),
          island: const Value('Malapascua'),
          bodyOfWater: const Value('Visayan Sea'),
        ),
      );
  final row = await (db.select(
    db.diveSites,
  )..where((t) => t.id.equals('site-ci'))).getSingle();
  expect(row.city, 'Cebu City');
  expect(row.island, 'Malapascua');
  expect(row.bodyOfWater, 'Visayan Sea');
});
```

(If `DiveDatabase.forTesting`/`NativeDatabase.memory()` differ in this file, copy the exact in-memory construction pattern already used by neighboring tests in the same file.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart -p vm`
Expected: FAIL — compile error, `DiveSitesCompanion.insert` has no named parameter `city` / `island`.

- [ ] **Step 3: Add the columns**

In `lib/core/database/database.dart`, in `class DiveSites extends Table`, immediately after the `bodyOfWater` column (line ~352):

```dart
  TextColumn get bodyOfWater => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get island => text().nullable()();
```

- [ ] **Step 4: Bump the schema version**

In `lib/core/database/database.dart`, line ~1632:

```dart
  static const int currentSchemaVersion = 90;
```

- [ ] **Step 5: Add the migration block**

In the `onUpgrade` migrator, immediately after the `if (from < 89) await reportProgress();` line (~4184), add:

```dart
        if (from < 90) {
          // City and Island localities for dive sites (issue #344). Lets
          // divers tell apart sites that share a country and region (e.g.
          // multiple islands off Cebu). PRAGMA-guarded so a healthy database
          // no-ops; existing rows read as NULL. body_of_water already exists.
          final cols = await customSelect(
            "PRAGMA table_info('dive_sites')",
          ).get();
          if (cols.isNotEmpty) {
            final existing = cols.map((c) => c.read<String>('name')).toSet();
            if (!existing.contains('city')) {
              await customStatement(
                'ALTER TABLE dive_sites ADD COLUMN city TEXT',
              );
            }
            if (!existing.contains('island')) {
              await customStatement(
                'ALTER TABLE dive_sites ADD COLUMN island TEXT',
              );
            }
          }
        }
        if (from < 90) await reportProgress();
```

- [ ] **Step 6: Register the new version in the migration-coverage list**

`lib/core/database/database.dart` ~line 1634 has a comment "Every schema version that has a migration block in onUpgrade." Find the list/set of covered versions near there (search for `89` in that vicinity) and add `90` in the same form the others use. If no such literal list exists, skip this step.

- [ ] **Step 7: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes; `database.g.dart` now has `city`/`island` on the companion and data class.

- [ ] **Step 8: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart -p vm`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/core/database/database.dart lib/core/database/database.g.dart test/features/dive_sites/data/repositories/site_repository_test.dart
git commit -m "feat(db): add city and island columns to dive_sites (schema v90) (#344)"
```

---

## Task 2: Domain entity fields

**Files:**
- Modify: `lib/features/dive_sites/domain/entities/dive_site.dart`
- Test: `test/features/dive_sites/domain/entities/dive_site_test.dart`

**Interfaces:**
- Produces: `DiveSite` gains `final String? city`, `final String? island`, `final String? bodyOfWater`, all accepted by the constructor and `copyWith`, and present in `props`.

- [ ] **Step 1: Write the failing test**

Add to `test/features/dive_sites/domain/entities/dive_site_test.dart`:

```dart
test('copyWith updates city, island, and bodyOfWater', () {
  const site = DiveSite(id: 's1', name: 'Site');
  final updated = site.copyWith(
    city: 'Cebu City',
    island: 'Malapascua',
    bodyOfWater: 'Visayan Sea',
  );
  expect(updated.city, 'Cebu City');
  expect(updated.island, 'Malapascua');
  expect(updated.bodyOfWater, 'Visayan Sea');
  // Equatable: the new values change identity.
  expect(updated, isNot(equals(site)));
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/domain/entities/dive_site_test.dart -p vm`
Expected: FAIL — `copyWith` has no `city`/`island`/`bodyOfWater` parameters (compile error).

- [ ] **Step 3: Add the fields**

In `lib/features/dive_sites/domain/entities/dive_site.dart`:

Add fields after `region` (line ~43):

```dart
  final String? country;
  final String? region;
  final String? city;
  final String? island;
  final String? bodyOfWater;
```

Add to the constructor after `this.region,` (line ~66):

```dart
    this.country,
    this.region,
    this.city,
    this.island,
    this.bodyOfWater,
```

Add to `copyWith` parameter list after `String? region,` (line ~109):

```dart
    String? country,
    String? region,
    String? city,
    String? island,
    String? bodyOfWater,
```

Add to the `copyWith` body after `region: region ?? this.region,` (line ~131):

```dart
      country: country ?? this.country,
      region: region ?? this.region,
      city: city ?? this.city,
      island: island ?? this.island,
      bodyOfWater: bodyOfWater ?? this.bodyOfWater,
```

Add to `props` after `region,` (line ~155):

```dart
    country,
    region,
    city,
    island,
    bodyOfWater,
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/domain/entities/dive_site_test.dart -p vm`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/domain/entities/dive_site.dart test/features/dive_sites/domain/entities/dive_site_test.dart
git commit -m "feat(sites): add city, island, bodyOfWater to DiveSite entity (#344)"
```

---

## Task 3: locationString one-liner

**Files:**
- Modify: `lib/features/dive_sites/domain/entities/dive_site.dart` (`locationString` getter ~line 80)
- Test: `test/features/dive_sites/domain/entities/dive_site_test.dart`

**Interfaces:**
- Produces: `DiveSite.locationString` now prepends the locality (`city` preferred, else `island`) before the existing `region, country` base, joined with ` · `.

- [ ] **Step 1: Write the failing test**

Add to `test/features/dive_sites/domain/entities/dive_site_test.dart`:

```dart
group('locationString with locality', () {
  test('city is preferred and prepended to region, country', () {
    const site = DiveSite(
      id: 's',
      name: 'S',
      country: 'Philippines',
      region: 'Cebu',
      city: 'Cebu City',
      island: 'Mactan',
    );
    expect(site.locationString, 'Cebu City · Cebu, Philippines');
  });

  test('island is used when city is empty', () {
    const site = DiveSite(
      id: 's',
      name: 'S',
      country: 'Philippines',
      region: 'Cebu',
      island: 'Malapascua',
    );
    expect(site.locationString, 'Malapascua · Cebu, Philippines');
  });

  test('locality only, no region or country', () {
    const site = DiveSite(id: 's', name: 'S', island: 'Malapascua');
    expect(site.locationString, 'Malapascua');
  });

  test('no locality keeps region, country unchanged', () {
    const site = DiveSite(
      id: 's',
      name: 'S',
      country: 'Philippines',
      region: 'Cebu',
    );
    expect(site.locationString, 'Cebu, Philippines');
  });

  test('empty everything yields empty string', () {
    const site = DiveSite(id: 's', name: 'S');
    expect(site.locationString, '');
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/domain/entities/dive_site_test.dart -p vm`
Expected: FAIL — current getter ignores city/island, so the first three tests fail.

- [ ] **Step 3: Update the getter**

Replace the `locationString` getter (lines ~79-85) with:

```dart
  /// Compact one-line location: "<locality> · <region>, <country>".
  /// Locality prefers [city], falling back to [island]. [bodyOfWater] is
  /// intentionally excluded to keep list tiles and map popups tight.
  String get locationString {
    final base = <String>[];
    if (region != null && region!.isNotEmpty) base.add(region!);
    if (country != null && country!.isNotEmpty) base.add(country!);
    final baseStr = base.join(', ');

    final locality = (city != null && city!.isNotEmpty)
        ? city!
        : (island != null && island!.isNotEmpty ? island! : '');

    if (locality.isNotEmpty && baseStr.isNotEmpty) {
      return '$locality · $baseStr';
    }
    if (locality.isNotEmpty) return locality;
    return baseStr;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/domain/entities/dive_site_test.dart -p vm`
Expected: PASS (all locationString tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/domain/entities/dive_site.dart test/features/dive_sites/domain/entities/dive_site_test.dart
git commit -m "feat(sites): include city/island in DiveSite.locationString (#344)"
```

---

## Task 4: Repository read/write/search mapping

**Files:**
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart` (read mapper `_mapRowToSite` ~line 682; create companion ~line 70; update path ~line 709; import/merge companions ~lines 123, 493; search query ~line 609)
- Test: `test/features/dive_sites/data/repositories/site_repository_test.dart`

**Interfaces:**
- Consumes: `DiveSite` entity fields from Task 2; Drift columns from Task 1.
- Produces: a created/updated `DiveSite` round-trips `city`/`island`/`bodyOfWater`; a row written directly with `body_of_water` (as importers do) now reads back via `_mapRowToSite`; search matches on all three.

- [ ] **Step 1: Write the failing tests**

Add to `test/features/dive_sites/data/repositories/site_repository_test.dart` (use the same repository/in-memory setup as the existing tests in the file; `repository` and `db` below refer to those existing harness variables):

```dart
test('create then read round-trips city, island, bodyOfWater', () async {
  const site = DiveSite(
    id: 'rt-1',
    name: 'Round Trip',
    city: 'Cebu City',
    island: 'Malapascua',
    bodyOfWater: 'Visayan Sea',
  );
  await repository.createSite(site);
  final loaded = await repository.getSiteById('rt-1');
  expect(loaded!.city, 'Cebu City');
  expect(loaded.island, 'Malapascua');
  expect(loaded.bodyOfWater, 'Visayan Sea');
});

test('imported body_of_water is now read back into the entity', () async {
  // Simulate an importer writing the column directly (no entity mapping).
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: 'ghost-1',
          name: 'Ghost Column Site',
          createdAt: now,
          updatedAt: now,
          bodyOfWater: const Value('Coral Sea'),
        ),
      );
  final loaded = await repository.getSiteById('ghost-1');
  expect(loaded!.bodyOfWater, 'Coral Sea');
});

test('search matches city, island, and bodyOfWater', () async {
  await repository.createSite(
    const DiveSite(id: 'q-1', name: 'Alpha', city: 'Naxos Town'),
  );
  await repository.createSite(
    const DiveSite(id: 'q-2', name: 'Beta', island: 'Santorini'),
  );
  await repository.createSite(
    const DiveSite(id: 'q-3', name: 'Gamma', bodyOfWater: 'Aegean Sea'),
  );
  expect((await repository.searchSites('Naxos')).map((s) => s.id), ['q-1']);
  expect((await repository.searchSites('Santorini')).map((s) => s.id), ['q-2']);
  expect((await repository.searchSites('Aegean')).map((s) => s.id), ['q-3']);
});
```

(Confirm the exact method names — `createSite`, `getSiteById`, `searchSites` — against the existing tests in this file and adjust if the harness uses different names.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart -p vm`
Expected: FAIL — round-trip and ghost-column read return `null` for the new fields; search returns empty.

- [ ] **Step 3: Map the fields on read**

In `_mapRowToSite` (~line 694), after `region: row.region,`:

```dart
      country: row.country,
      region: row.region,
      city: row.city,
      island: row.island,
      bodyOfWater: row.bodyOfWater,
```

- [ ] **Step 4: Map the fields on every write path**

In the create companion (~line 80), after `region: Value(site.region),`:

```dart
              country: Value(site.country),
              region: Value(site.region),
              city: Value(site.city),
              island: Value(site.island),
              bodyOfWater: Value(site.bodyOfWater),
```

Apply the identical three `Value(...)` lines (matching the surrounding indentation) to each other companion that sets `country`/`region`: the update path (~line 717) and the import/merge companions (~lines 131 and 503). Search each `region: Value(site.region),` occurrence and add the three lines after it. Remove the obsolete "preserve on update (e.g. MacDive waterType / bodyOfWater)" note for `bodyOfWater` in the `_applyPatch` doc comment (~line 164) if it now misleads — leave `waterType` mention intact.

- [ ] **Step 5: Add the fields to search**

In the search query (~line 609), extend the `where` predicate:

```dart
                t.country.contains(query) |
                t.region.contains(query) |
                t.city.contains(query) |
                t.island.contains(query) |
                t.bodyOfWater.contains(query),
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/dive_sites/data/repositories/site_repository_test.dart -p vm`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_sites/data/repositories/site_repository_impl.dart test/features/dive_sites/data/repositories/site_repository_test.dart
git commit -m "feat(sites): map city/island/bodyOfWater in repository read, write, search (#344)"
```

---

## Task 5: Autocomplete suggestion helpers

**Files:**
- Modify: `lib/features/dive_sites/domain/services/site_suggestions.dart`
- Test: `test/features/dive_sites/domain/services/site_suggestions_test.dart`

**Interfaces:**
- Consumes: `DiveSite.city`, `.island`, `.bodyOfWater` from Task 2.
- Produces:
  - `List<String> suggestedCities(List<DiveSite> sites, String country, String region)`
  - `List<String> suggestedIslands(List<DiveSite> sites, String country)`
  - `List<String> suggestedBodiesOfWater(List<DiveSite> sites, String country)`
  - Each: distinct, case-insensitively de-duped, alpha-sorted; parent-filtered when the parent arg is non-empty, otherwise all distinct.

- [ ] **Step 1: Write the failing tests**

Add to `test/features/dive_sites/domain/services/site_suggestions_test.dart`:

```dart
group('suggestedCities', () {
  final sites = [
    const DiveSite(
      id: '1',
      name: 'A',
      country: 'Philippines',
      region: 'Cebu',
      city: 'Cebu City',
    ),
    const DiveSite(
      id: '2',
      name: 'B',
      country: 'Philippines',
      region: 'Bohol',
      city: 'Panglao',
    ),
    const DiveSite(
      id: '3',
      name: 'C',
      country: 'Greece',
      region: 'Cyclades',
      city: 'Naxos',
    ),
  ];

  test('filters by country and region when both set', () {
    expect(suggestedCities(sites, 'Philippines', 'Cebu'), ['Cebu City']);
  });

  test('returns all distinct cities when parent empty', () {
    expect(suggestedCities(sites, '', ''), ['Cebu City', 'Naxos', 'Panglao']);
  });
});

group('suggestedIslands', () {
  final sites = [
    const DiveSite(
      id: '1',
      name: 'A',
      country: 'Philippines',
      island: 'Malapascua',
    ),
    const DiveSite(
      id: '2',
      name: 'B',
      country: 'Greece',
      island: 'Santorini',
    ),
  ];

  test('filters by country', () {
    expect(suggestedIslands(sites, 'Philippines'), ['Malapascua']);
  });

  test('all distinct when country empty', () {
    expect(suggestedIslands(sites, ''), ['Malapascua', 'Santorini']);
  });
});

group('suggestedBodiesOfWater', () {
  final sites = [
    const DiveSite(
      id: '1',
      name: 'A',
      country: 'Philippines',
      bodyOfWater: 'Visayan Sea',
    ),
    const DiveSite(
      id: '2',
      name: 'B',
      country: 'Australia',
      bodyOfWater: 'Coral Sea',
    ),
  ];

  test('filters by country', () {
    expect(suggestedBodiesOfWater(sites, 'Australia'), ['Coral Sea']);
  });

  test('all distinct when country empty', () {
    expect(suggestedBodiesOfWater(sites, ''), ['Coral Sea', 'Visayan Sea']);
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_sites/domain/services/site_suggestions_test.dart -p vm`
Expected: FAIL — the three functions are undefined.

- [ ] **Step 3: Implement the helpers**

Append to `lib/features/dive_sites/domain/services/site_suggestions.dart`:

```dart
/// Distinct, alpha-sorted cities. When [country] and/or [region] are non-empty,
/// only cities used with that country (and region) are returned.
List<String> suggestedCities(
  List<DiveSite> sites,
  String country,
  String region,
) {
  final wantCountry = country.trim().toLowerCase();
  final wantRegion = region.trim().toLowerCase();
  final seen = <String>{};
  final cities = <String>[];
  for (final site in sites) {
    final city = site.city?.trim() ?? '';
    if (city.isEmpty) continue;
    if (wantCountry.isNotEmpty &&
        (site.country?.trim().toLowerCase() ?? '') != wantCountry) {
      continue;
    }
    if (wantRegion.isNotEmpty &&
        (site.region?.trim().toLowerCase() ?? '') != wantRegion) {
      continue;
    }
    if (seen.add(city.toLowerCase())) cities.add(city);
  }
  cities.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return cities;
}

/// Distinct, alpha-sorted islands. When [country] is non-empty, only islands
/// used with that country are returned.
List<String> suggestedIslands(List<DiveSite> sites, String country) {
  final want = country.trim().toLowerCase();
  final seen = <String>{};
  final islands = <String>[];
  for (final site in sites) {
    final island = site.island?.trim() ?? '';
    if (island.isEmpty) continue;
    if (want.isNotEmpty &&
        (site.country?.trim().toLowerCase() ?? '') != want) {
      continue;
    }
    if (seen.add(island.toLowerCase())) islands.add(island);
  }
  islands.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return islands;
}

/// Distinct, alpha-sorted bodies of water. When [country] is non-empty, only
/// bodies of water used with that country are returned.
List<String> suggestedBodiesOfWater(List<DiveSite> sites, String country) {
  final want = country.trim().toLowerCase();
  final seen = <String>{};
  final bodies = <String>[];
  for (final site in sites) {
    final body = site.bodyOfWater?.trim() ?? '';
    if (body.isEmpty) continue;
    if (want.isNotEmpty &&
        (site.country?.trim().toLowerCase() ?? '') != want) {
      continue;
    }
    if (seen.add(body.toLowerCase())) bodies.add(body);
  }
  bodies.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return bodies;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_sites/domain/services/site_suggestions_test.dart -p vm`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/domain/services/site_suggestions.dart test/features/dive_sites/domain/services/site_suggestions_test.dart
git commit -m "feat(sites): add city/island/body-of-water suggestion helpers (#344)"
```

---

## Task 6: SiteField table columns

**Files:**
- Modify: `lib/features/dive_sites/domain/constants/site_field.dart`
- Test: `test/features/dive_sites/domain/constants/site_field_test.dart`

**Interfaces:**
- Consumes: `DiveSite.city`, `.island`, `.bodyOfWater` from Task 2.
- Produces: `SiteField.city`, `SiteField.island`, `SiteField.bodyOfWater` enum values, each fully implemented across every `SiteField` getter and both `SiteFieldAdapter.extractValue`/`formatValue`.

- [ ] **Step 1: Write the failing test**

Add to `test/features/dive_sites/domain/constants/site_field_test.dart`:

```dart
test('city, island, bodyOfWater extract and format from a site', () {
  const site = DiveSite(
    id: 's',
    name: 'S',
    city: 'Cebu City',
    island: 'Malapascua',
    bodyOfWater: 'Visayan Sea',
  );
  final entity = (site: site, diveCount: 0);
  final units = UnitFormatter(const UnitSettings());
  final adapter = SiteFieldAdapter.instance;

  expect(adapter.extractValue(SiteField.city, entity), 'Cebu City');
  expect(adapter.extractValue(SiteField.island, entity), 'Malapascua');
  expect(adapter.extractValue(SiteField.bodyOfWater, entity), 'Visayan Sea');

  expect(
    adapter.formatValue(SiteField.city, 'Cebu City', units),
    'Cebu City',
  );
  expect(adapter.formatValue(SiteField.island, null, units), '--');
});
```

(Match the exact `UnitFormatter`/`UnitSettings` construction used by the existing tests in this file; copy their import and setup if different.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/domain/constants/site_field_test.dart -p vm`
Expected: FAIL — `SiteField.city` etc. are undefined.

- [ ] **Step 3: Add the enum values**

In `lib/features/dive_sites/domain/constants/site_field.dart`, in the `enum SiteField`, add to the Core group after `region,` (line ~24):

```dart
  country,
  region,
  city,
  island,
  bodyOfWater,
  diveCount,
```

- [ ] **Step 4: Implement every switch arm for the three new values**

Add cases to each `switch (this)` in `SiteField` (and `switch (field)` in the adapter). Use these exact returns:

`displayName`:
```dart
      case SiteField.city:
        return 'City';
      case SiteField.island:
        return 'Island';
      case SiteField.bodyOfWater:
        return 'Body of Water';
```

`shortLabel`:
```dart
      case SiteField.city:
        return 'City';
      case SiteField.island:
        return 'Island';
      case SiteField.bodyOfWater:
        return 'Water Body';
```

`icon`:
```dart
      case SiteField.city:
        return Icons.location_city;
      case SiteField.island:
        return Icons.landscape;
      case SiteField.bodyOfWater:
        return Icons.waves;
```

`defaultWidth`:
```dart
      case SiteField.city:
        return 110;
      case SiteField.island:
        return 110;
      case SiteField.bodyOfWater:
        return 130;
```

`minWidth`:
```dart
      case SiteField.city:
        return 60;
      case SiteField.island:
        return 60;
      case SiteField.bodyOfWater:
        return 70;
```

`sortable` — add to the `return true;` group (alongside country/region):
```dart
      case SiteField.city:
      case SiteField.island:
      case SiteField.bodyOfWater:
```

`categoryName` — add to the `SiteFieldCategory.core.name` group:
```dart
      case SiteField.city:
      case SiteField.island:
      case SiteField.bodyOfWater:
```

`isRightAligned` — add to the `return false;` group:
```dart
      case SiteField.city:
      case SiteField.island:
      case SiteField.bodyOfWater:
```

`SiteFieldAdapter.extractValue`:
```dart
      case SiteField.city:
        return site.city;
      case SiteField.island:
        return site.island;
      case SiteField.bodyOfWater:
        return site.bodyOfWater;
```

`SiteFieldAdapter.formatValue` — add to the string-passthrough group (with `country`/`region`, which `return value as String;`):
```dart
      case SiteField.city:
      case SiteField.island:
      case SiteField.bodyOfWater:
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/domain/constants/site_field_test.dart -p vm`
Expected: PASS. (If `flutter analyze` reports a non-exhaustive switch, a case was missed — add it.)

- [ ] **Step 6: Verify analyzer exhaustiveness**

Run: `flutter analyze lib/features/dive_sites/domain/constants/site_field.dart`
Expected: No issues. (Dart flags any switch missing the new enum values.)

- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_sites/domain/constants/site_field.dart test/features/dive_sites/domain/constants/site_field_test.dart
git commit -m "feat(sites): add city/island/body-of-water table columns (#344)"
```

---

## Task 7: Localization keys (all locales)

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` (template) + `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb`
- Test: regeneration + analyzer (no dedicated unit test; strings verified via the widget tests in Tasks 8-9)

**Interfaces:**
- Produces: getters `diveSites_edit_field_city_label`, `..._island_label`, `..._bodyOfWater_label`, `diveSites_detail_location_city`, `..._island`, `..._bodyOfWater` on `AppLocalizations`.

- [ ] **Step 1: Add keys to the English template**

In `lib/l10n/arb/app_en.arb`, after `"diveSites_edit_field_region_label"` (~line 3112) add:

```json
  "diveSites_edit_field_city_label": "City",
  "diveSites_edit_field_island_label": "Island",
  "diveSites_edit_field_bodyOfWater_label": "Body of Water",
```

After `"diveSites_detail_location_region"` (~line 3052) add:

```json
  "diveSites_detail_location_city": "City",
  "diveSites_detail_location_island": "Island",
  "diveSites_detail_location_bodyOfWater": "Body of Water",
```

(Watch trailing-comma JSON validity. If keys have `@`-description siblings nearby, follow that convention; if Country/Region have none, add none.)

- [ ] **Step 2: Add the same six keys to every non-English locale with translated values**

Use these translations (edit-label and detail key share the same value per locale, mirroring Country/Region):

| key suffix | de | es | fr | he | hu | it | nl | pt | zh |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| city | Stadt | Ciudad | Ville | עיר | Város | Città | Stad | Cidade | 城市 |
| island | Insel | Isla | Île | אי | Sziget | Isola | Eiland | Ilha | 岛屿 |
| bodyOfWater | Gewässer | Masa de agua | Plan d'eau | מקווה מים | Víztest | Specchio d'acqua | Wateroppervlak | Corpo de água | 水域 |

For each locale file add, in the same two locations as the template:

```json
  "diveSites_edit_field_city_label": "<city>",
  "diveSites_edit_field_island_label": "<island>",
  "diveSites_edit_field_bodyOfWater_label": "<bodyOfWater>",
```
```json
  "diveSites_detail_location_city": "<city>",
  "diveSites_detail_location_island": "<island>",
  "diveSites_detail_location_bodyOfWater": "<bodyOfWater>",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: regenerates `app_localizations*.dart` with the six new getters and no "untranslated message" warnings for these keys.

- [ ] **Step 4: Verify analyzer**

Run: `flutter analyze lib/l10n`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n
git commit -m "i18n(sites): add city/island/body-of-water labels in all locales (#344)"
```

---

## Task 8: Edit form fields

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_edit_page.dart`
- Test: `test/features/dive_sites/presentation/pages/site_edit_page_test.dart`

**Interfaces:**
- Consumes: suggestion helpers (Task 5), l10n getters (Task 7), entity fields (Task 2).
- Produces: the edit form renders City, Island, and Body of Water fields and writes their values back into the saved `DiveSite`.

- [ ] **Step 1: Write the failing test**

Add to `test/features/dive_sites/presentation/pages/site_edit_page_test.dart` (follow the file's existing pump/harness helpers):

```dart
testWidgets('renders City, Island, and Body of Water fields', (tester) async {
  await pumpSiteEditPage(tester); // use the file's existing helper
  await tester.pumpAndSettle();
  expect(find.text('City'), findsWidgets);
  expect(find.text('Island'), findsWidgets);
  expect(find.text('Body of Water'), findsWidgets);
});
```

(If the file builds the page inline rather than via a helper, copy that exact setup. The labels come from the default English l10n.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_page_test.dart -p vm`
Expected: FAIL — the three labels are not present.

- [ ] **Step 3: Add controllers and lifecycle wiring**

In `site_edit_page.dart` State class, near `_countryController`/`_regionController` (lines ~62-63):

```dart
  final _countryController = TextEditingController();
  final _regionController = TextEditingController();
  final _cityController = TextEditingController();
  final _islandController = TextEditingController();
  final _bodyOfWaterController = TextEditingController();
```

In `initState` after the region listener (~line 99):

```dart
    _cityController.addListener(_onFieldChanged);
    _islandController.addListener(_onFieldChanged);
    _bodyOfWaterController.addListener(_onFieldChanged);
```

In `dispose` after `_regionController.dispose();` (~line 132):

```dart
    _cityController.dispose();
    _islandController.dispose();
    _bodyOfWaterController.dispose();
```

In `_loadSite` after `_regionController.text = site.region ?? '';` (~line 155):

```dart
    _cityController.text = site.city ?? '';
    _islandController.text = site.island ?? '';
    _bodyOfWaterController.text = site.bodyOfWater ?? '';
```

- [ ] **Step 4: Render the three fields**

After the Country/Region `Row`'s closing `Padding` (~line 713, immediately before the next `FormSection`), add a new `Padding` with three fields. City filters by country+region; Island and Body of Water by country:

```dart
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(
                  children: [
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _countryController,
                      builder: (context, country, _) {
                        return ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _regionController,
                          builder: (context, region, _) {
                            return SuggestionField(
                              controller: _cityController,
                              suggestions: suggestedCities(
                                allSites,
                                country.text,
                                region.text,
                              ),
                              enableFuzzy: true,
                              textCapitalization: TextCapitalization.words,
                              decoration: _withMergeTextDecoration(
                                key: 'city',
                                decoration: InputDecoration(
                                  labelText: context
                                      .l10n
                                      .diveSites_edit_field_city_label,
                                  prefixIcon: const Icon(Icons.location_city),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _countryController,
                      builder: (context, country, _) {
                        return SuggestionField(
                          controller: _islandController,
                          suggestions: suggestedIslands(
                            allSites,
                            country.text,
                          ),
                          enableFuzzy: true,
                          textCapitalization: TextCapitalization.words,
                          decoration: _withMergeTextDecoration(
                            key: 'island',
                            decoration: InputDecoration(
                              labelText: context
                                  .l10n
                                  .diveSites_edit_field_island_label,
                              prefixIcon: const Icon(Icons.landscape),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _countryController,
                      builder: (context, country, _) {
                        return SuggestionField(
                          controller: _bodyOfWaterController,
                          suggestions: suggestedBodiesOfWater(
                            allSites,
                            country.text,
                          ),
                          enableFuzzy: true,
                          textCapitalization: TextCapitalization.words,
                          decoration: _withMergeTextDecoration(
                            key: 'bodyOfWater',
                            decoration: InputDecoration(
                              labelText: context
                                  .l10n
                                  .diveSites_edit_field_bodyOfWater_label,
                              prefixIcon: const Icon(Icons.waves),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
```

(Confirm the suggestions import is present; add `import 'package:submersion/features/dive_sites/domain/services/site_suggestions.dart';` only if not already imported. `allSites` is the same list variable the Country/Region fields already use.)

- [ ] **Step 5: Wire the values into the saved entity**

Find where the page builds the `DiveSite` to save (search for `country: ` and `_countryController.text` in this file). In that `copyWith`/constructor, add:

```dart
      city: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      island: _islandController.text.trim().isEmpty
          ? null
          : _islandController.text.trim(),
      bodyOfWater: _bodyOfWaterController.text.trim().isEmpty
          ? null
          : _bodyOfWaterController.text.trim(),
```

Match the null-vs-empty convention the existing `country`/`region` save uses; if they pass empty strings rather than null, mirror that instead.

- [ ] **Step 6: Add a save round-trip assertion to the test**

Extend the widget test (or add a second test) to enter text into the City field and assert the saved site carries it, using the file's existing save-trigger helper. Example shape:

```dart
testWidgets('saves entered City value', (tester) async {
  await pumpSiteEditPage(tester);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextFormField, 'City'),
    'Cebu City',
  );
  await tapSave(tester); // file's existing save helper
  await tester.pumpAndSettle();
  expect(lastSavedSite.city, 'Cebu City'); // file's capture mechanism
});
```

(If the test harness has no save-capture mechanism, keep only the render test from Step 1 and rely on Task 4's repository round-trip for save coverage. Do not invent a harness.)

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/dive_sites/presentation/pages/site_edit_page_test.dart -p vm`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib/features/dive_sites/presentation/pages/site_edit_page.dart test/features/dive_sites/presentation/pages/site_edit_page_test.dart
git commit -m "feat(sites): add City/Island/Body of Water to the site edit form (#344)"
```

---

## Task 9: Detail view rows

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (`_buildLocationSection` ~line 733)
- Test: `test/features/dive_sites/presentation/pages/site_detail_page_test.dart`

**Interfaces:**
- Consumes: l10n getters (Task 7), entity fields (Task 2).
- Produces: the detail location section shows City, Island, and Body of Water rows (each hidden when empty, like Country/Region).

- [ ] **Step 1: Write the failing test**

Add to `test/features/dive_sites/presentation/pages/site_detail_page_test.dart` (follow the file's existing pump helper and the way it injects a site):

```dart
testWidgets('shows city, island, and body of water when set', (tester) async {
  const site = DiveSite(
    id: 's',
    name: 'Site',
    city: 'Cebu City',
    island: 'Malapascua',
    bodyOfWater: 'Visayan Sea',
  );
  await pumpSiteDetail(tester, site); // use the file's existing helper
  await tester.pumpAndSettle();
  expect(find.text('Cebu City'), findsOneWidget);
  expect(find.text('Malapascua'), findsOneWidget);
  expect(find.text('Visayan Sea'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/presentation/pages/site_detail_page_test.dart -p vm`
Expected: FAIL — the three values are not rendered.

- [ ] **Step 3: Add the rows**

In `_buildLocationSection`, after the Region `_buildDetailRow` (the one ending ~line 771, before the GPS row ~line 772), add:

```dart
            _buildDetailRow(
              context,
              Icons.location_city,
              context.l10n.diveSites_detail_location_city,
              site.city?.isNotEmpty == true
                  ? site.city!
                  : context.l10n.diveSites_detail_location_notSet,
              isEmpty: site.city?.isNotEmpty != true,
            ),
            _buildDetailRow(
              context,
              Icons.landscape,
              context.l10n.diveSites_detail_location_island,
              site.island?.isNotEmpty == true
                  ? site.island!
                  : context.l10n.diveSites_detail_location_notSet,
              isEmpty: site.island?.isNotEmpty != true,
            ),
            _buildDetailRow(
              context,
              Icons.waves,
              context.l10n.diveSites_detail_location_bodyOfWater,
              site.bodyOfWater?.isNotEmpty == true
                  ? site.bodyOfWater!
                  : context.l10n.diveSites_detail_location_notSet,
              isEmpty: site.bodyOfWater?.isNotEmpty != true,
            ),
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_sites/presentation/pages/site_detail_page_test.dart -p vm`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/presentation/pages/site_detail_page.dart test/features/dive_sites/presentation/pages/site_detail_page_test.dart
git commit -m "feat(sites): show City/Island/Body of Water on the site detail view (#344)"
```

---

## Task 10: Sync round-trip verification

**Files:**
- Test: `test/core/services/sync/` (add to an existing serializer round-trip test file, or create `sync_dive_site_location_fields_test.dart` if none fits)

**Interfaces:**
- Consumes: Drift `DiveSiteData.toJson()`/`DiveSite.fromJson()` (regenerated in Task 1).
- Produces: confirmation that `city`/`island`/`bodyOfWater` survive a serialize→deserialize cycle, with no production sync code change required.

- [ ] **Step 1: Locate an existing dive-site sync test pattern**

Run: `grep -rln "DiveSite" test/core/services/sync`
Read one matching file to copy its DB/serializer setup. If none exists, create the new file using the in-memory `DiveDatabase` pattern from `site_repository_test.dart`.

- [ ] **Step 2: Write the round-trip test**

```dart
test('dive site city/island/bodyOfWater survive toJson/fromJson', () async {
  final db = DiveDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  final now = DateTime.now().millisecondsSinceEpoch;
  await db.into(db.diveSites).insert(
        DiveSitesCompanion.insert(
          id: 'sync-1',
          name: 'Sync Site',
          createdAt: now,
          updatedAt: now,
          city: const Value('Cebu City'),
          island: const Value('Malapascua'),
          bodyOfWater: const Value('Visayan Sea'),
        ),
      );
  final row = await (db.select(db.diveSites)
        ..where((t) => t.id.equals('sync-1')))
      .getSingle();

  final json = row.toJson();
  final restored = DiveSite.fromJson(json);

  expect(restored.city, 'Cebu City');
  expect(restored.island, 'Malapascua');
  expect(restored.bodyOfWater, 'Visayan Sea');
});
```

(`DiveSite` here is the generated Drift data class — confirm its name in `database.g.dart`; the repository imports it as the Drift row type.)

- [ ] **Step 3: Run the test**

Run: `flutter test test/core/services/sync/<file>.dart -p vm`
Expected: PASS — confirms the generated serialization already carries the new columns; no sync source change needed.

- [ ] **Step 4: Commit**

```bash
git add test/core/services/sync/
git commit -m "test(sync): verify dive site location fields round-trip through serialization (#344)"
```

---

## Task 11: Full verification sweep

**Files:** none (verification only)

- [ ] **Step 1: Format**

Run: `dart format .`
Expected: "0 changed" (or commit any formatting). If files change:
```bash
dart format .
git add -A && git commit -m "style: dart format (#344)"
```

- [ ] **Step 2: Analyze whole project**

Run: `flutter analyze`
Expected: No issues. (Do not pipe/tail — read the full output.)

- [ ] **Step 3: Run the full dive_sites + sync suites**

Run: `flutter test test/features/dive_sites test/core/services/sync -p vm`
Expected: All pass.

- [ ] **Step 4: Run the complete suite**

Run: `flutter test`
Expected: All pass (watch for snapshot/golden or "all SiteField values" exhaustiveness tests that may need the three new values added — update them if they enumerate fields).

- [ ] **Step 5: Final commit if anything changed**

```bash
git add -A
git commit -m "test(sites): finalize city/island/body-of-water field suite (#344)"
```

---

## Self-Review Notes

- **Spec coverage:** schema/migration (T1), entity (T2), locationString (T3), repository read/write/search incl. ghost-column fix (T4), suggestions (T5), table columns (T6), localization all locales (T7), edit form (T8), detail view (T9), sync verification (T10), full sweep (T11). All spec sections mapped.
- **Out of scope honored:** no `site_matcher`, filter sheet, or new importer source mapping touched.
- **Type consistency:** entity fields `city`/`island`/`bodyOfWater` (String?) used identically across T2-T10; suggestion signatures fixed in T5 and consumed verbatim in T8; `_mapRowToSite` (correct method name) used in T4.
- **Known harness adaptation points (flagged, not placeholders):** widget/repository tests instruct copying the file's existing pump/setup helpers because those names vary by file; the actual assertions and production code are fully specified.
