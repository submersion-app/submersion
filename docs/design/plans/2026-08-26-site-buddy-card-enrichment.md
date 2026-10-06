# Site and Buddy List Card Enrichment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Dive Sites and Buddies list cards richer by surfacing batched aggregates (last dived, max depth reached, site features, last dive together, usual role), wiring the dormant card-slot config so Settings actually controls the cards, and fixing the latent ListTile, AssetImage, and hardcoded-English bugs in those cards.

**Architecture:** Two wrapper classes (`SiteWithDiveCount`, `BuddyWithDiveCount`) move to their domain layers and carry the aggregates, which the two existing list queries compute with whole-table `GROUP BY`s (no per-row work). A shared, persisted `EntityCardConfigNotifier<F>` (sibling of `EntityTableConfigNotifier<F>`) replaces the in-memory `StateProvider`s, and a shared slot renderer (`EntityCardStat`, `EntityCardExtraFields`) resolves configurable slots through the existing field adapters. Each feature keeps its own hand-rolled tile for the fixed identity elements.

**Tech Stack:** Flutter, Riverpod (`StateNotifierProvider`, `FutureProvider`), Drift (raw `customSelect` SQL), Equatable, `flutter gen-l10n` (11 arb files), `flutter_test` widget tests with `testApp`/`ProviderScope` overrides.

**Spec:** `docs/superpowers/specs/2026-08-26-site-buddy-card-enrichment-design.md`

## Global Constraints

- Work only in the worktree. Every shell command starts with `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment` and every file path below is relative to that root. Read/Edit/Write tools need the absolute worktree path; the main checkout must not be touched.
- Never write an em-dash (U+2014) anywhere: code, comments, docs, arb values, commit messages. Use commas, colons, or two sentences.
- No emojis in code, comments, or documentation. No `Co-Authored-By` trailer and no session URL in commit messages.
- TDD: write the failing test, run it and see it fail, implement, run it and see it pass, commit.
- Files stay at or below 800 lines. `site_list_content.dart` (1553) and `buddy_list_content.dart` (1134) already exceed it; the tile extractions in Tasks 10 and 12 shrink them and must not add to them.
- Every displayed depth or date goes through `UnitFormatter` (`formatDepth`, `convertDepth`, `formatDate`). Values are stored in metres; convert only at the display edge.
- New user-facing strings get a key in all 11 arb files (`ar, de, en, es, fr, he, hu, it, nl, pt, zh`), then `flutter gen-l10n`. Check with `grep -c '"<key>"' lib/l10n/arb/app_en.arb` that a key does not already exist before adding it.
- The list tiles are hand-rolled `Row`/`Column` widgets, never `ListTile`, and nothing text-bearing goes in a trailing slot (only the chevron).
- Run `dart format .` from the worktree root before every commit. Run `flutter test <file>` directly, never piped into `grep`/`tail` (the pipe hides the exit code).
- Regenerate code after adding public methods to `SiteRepository`/`BuddyRepository` or changing l10n: `dart run build_runner build --delete-conflicting-outputs` (mocks) and `flutter gen-l10n`.
- Riverpod imports come from `package:submersion/core/providers/provider.dart`, not `flutter_riverpod` directly.
- Feature accent ids are `'sites'` and `'buddies'` (not `'dive-sites'`).

---

## File Structure

New files (one responsibility each):

| File | Responsibility |
| --- | --- |
| `lib/features/dive_sites/domain/entities/site_with_dive_count.dart` | `SiteDiveAggregate`, `SiteWithDiveCount` value classes |
| `lib/features/buddies/domain/entities/buddy_with_dive_count.dart` | `BuddyWithDiveCount` and the pure `usualRoleFor` |
| `lib/shared/providers/entity_card_config_providers.dart` | `EntityCardConfigNotifier<F>` |
| `lib/shared/widgets/entity_card/card_slot_resolver.dart` | `resolveCardSlot` |
| `lib/shared/widgets/entity_card/entity_card_stat.dart` | icon + value stat |
| `lib/shared/widgets/entity_card/entity_card_extra_fields.dart` | two-column extras grid |
| `lib/features/dive_sites/presentation/site_difficulty_display.dart` | `SiteDifficultyDisplay.localizedName` |
| `lib/features/dive_sites/presentation/widgets/site_list_tile.dart` | detailed site card |
| `lib/features/buddies/presentation/widgets/buddy_list_tile.dart` | detailed buddy card |
| `lib/features/buddies/presentation/widgets/compact_buddy_list_tile.dart` | compact buddy card |

Modified: `site_repository_impl.dart`, `buddy_repository.dart`, `site_field.dart`, `buddy_field.dart`, `site_providers.dart`, `buddy_providers.dart`, `site_list_content.dart`, `compact_site_list_tile.dart`, `buddy_list_content.dart`, `column_config_page.dart`, the 11 arb files, and the tests named in each task.

---

### Task 1: Site wrapper class and aggregate value

**Files:**
- Create: `lib/features/dive_sites/domain/entities/site_with_dive_count.dart`
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart:1038-1044` (delete class, add import + export)
- Modify: `lib/features/dive_sites/domain/constants/site_field.dart:8-9` (typedef alias)
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart:642-647` (drop record conversion)
- Modify: `test/features/dive_sites/domain/constants/site_field_test.dart`, `test/features/dive_sites/domain/constants/site_field_entry_method_test.dart` (record literals)
- Test: `test/features/dive_sites/domain/entities/site_with_dive_count_test.dart`

**Interfaces:**
- Produces: `class SiteDiveAggregate { int diveCount; DateTime? lastDivedAt; double? maxDepthReached; }` and `class SiteWithDiveCount { DiveSite site; int diveCount; DateTime? lastDivedAt; double? maxDepthReached; List<String> featureTypes; }` (const constructors, `Equatable`). `typedef SiteWithCount = SiteWithDiveCount`. `site_repository_impl.dart` re-exports the class so every existing `import ...site_repository_impl.dart` keeps compiling.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_sites/domain/entities/site_with_dive_count_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';

void main() {
  const site = DiveSite(id: 'site-1', name: 'Blue Hole');

  group('SiteWithDiveCount', () {
    test('aggregates default to null and an empty feature list', () {
      const entry = SiteWithDiveCount(site: site, diveCount: 3);

      expect(entry.lastDivedAt, isNull);
      expect(entry.maxDepthReached, isNull);
      expect(entry.featureTypes, isEmpty);
    });

    test('is value-equal on every field', () {
      final a = SiteWithDiveCount(
        site: site,
        diveCount: 3,
        lastDivedAt: DateTime(2026, 3, 5),
        maxDepthReached: 31.5,
        featureTypes: const ['wreck', 'mooring'],
      );
      final b = SiteWithDiveCount(
        site: site,
        diveCount: 3,
        lastDivedAt: DateTime(2026, 3, 5),
        maxDepthReached: 31.5,
        featureTypes: const ['wreck', 'mooring'],
      );

      expect(a, equals(b));
      expect(a.copyWith(diveCount: 4), isNot(equals(b)));
    });
  });

  group('SiteDiveAggregate', () {
    test('is value-equal', () {
      final a = SiteDiveAggregate(
        diveCount: 2,
        lastDivedAt: DateTime(2026, 1, 1),
        maxDepthReached: 18,
      );
      final b = SiteDiveAggregate(
        diveCount: 2,
        lastDivedAt: DateTime(2026, 1, 1),
        maxDepthReached: 18,
      );
      expect(a, equals(b));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_sites/domain/entities/site_with_dive_count_test.dart`
Expected: FAIL to compile, "Target of URI doesn't exist ... site_with_dive_count.dart".

- [ ] **Step 3: Create the domain file**

Create `lib/features/dive_sites/domain/entities/site_with_dive_count.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Per-site aggregate over the dives table: how many dives were logged at
/// the site, when the most recent one was, and the deepest depth reached.
/// Depths are stored in metres; convert at the display edge.
class SiteDiveAggregate extends Equatable {
  final int diveCount;
  final DateTime? lastDivedAt;
  final double? maxDepthReached;

  const SiteDiveAggregate({
    required this.diveCount,
    this.lastDivedAt,
    this.maxDepthReached,
  });

  @override
  List<Object?> get props => [diveCount, lastDivedAt, maxDepthReached];
}

/// A [DiveSite] paired with the aggregates the list surfaces render.
///
/// [featureTypes] holds the distinct `site_features.type` names placed on
/// the site, ordered by first creation, so a list card can draw one chip
/// per feature kind without a per-row query. The aggregates are optional
/// so callers that only know a count (the maps) keep constructing this.
class SiteWithDiveCount extends Equatable {
  final DiveSite site;
  final int diveCount;
  final DateTime? lastDivedAt;
  final double? maxDepthReached;
  final List<String> featureTypes;

  const SiteWithDiveCount({
    required this.site,
    required this.diveCount,
    this.lastDivedAt,
    this.maxDepthReached,
    this.featureTypes = const [],
  });

  SiteWithDiveCount copyWith({
    DiveSite? site,
    int? diveCount,
    DateTime? lastDivedAt,
    double? maxDepthReached,
    List<String>? featureTypes,
  }) {
    return SiteWithDiveCount(
      site: site ?? this.site,
      diveCount: diveCount ?? this.diveCount,
      lastDivedAt: lastDivedAt ?? this.lastDivedAt,
      maxDepthReached: maxDepthReached ?? this.maxDepthReached,
      featureTypes: featureTypes ?? this.featureTypes,
    );
  }

  @override
  List<Object?> get props => [
    site,
    diveCount,
    lastDivedAt,
    maxDepthReached,
    featureTypes,
  ];
}
```

- [ ] **Step 4: Point the repository and the adapter at it**

In `lib/features/dive_sites/data/repositories/site_repository_impl.dart`:

1. Delete the old class (currently lines 1038-1044):

```dart
/// Site with dive count
class SiteWithDiveCount {
  final domain.DiveSite site;
  final int diveCount;

  SiteWithDiveCount({required this.site, required this.diveCount});
}
```

2. Add, in the import block (after the `dive_site.dart as domain` import):

```dart
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';

// Re-exported so the many existing `site_repository_impl.dart` importers of
// SiteWithDiveCount keep compiling after the class moved to the domain layer.
export 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
```

In `lib/features/dive_sites/domain/constants/site_field.dart`, replace lines 8-9:

```dart
/// Wrapper pairing a [DiveSite] with its computed dive count.
typedef SiteWithCount = ({DiveSite site, int diveCount});
```

with:

```dart
/// Entity handed to [SiteFieldAdapter]. An alias of the repository's class so
/// the table view and the list cards share one type with no conversion.
typedef SiteWithCount = SiteWithDiveCount;
```

and add the import `import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';` after the `dive_site.dart` import.

In `lib/features/dive_sites/presentation/widgets/site_list_content.dart` replace lines 642-647:

```dart
        // Convert SiteWithDiveCount (class) to SiteWithCount (record) as
        // required by SiteFieldAdapter.
        final siteRecords = sites
            .map((s) => (site: s.site, diveCount: s.diveCount))
            .toList();
```

with nothing, and change `entities: siteRecords,` to `entities: sites,`.

- [ ] **Step 5: Convert the record literals in the adapter tests**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
sed -i '' -E 's/= \(site: ([A-Za-z]+), diveCount: ([0-9]+)\);/= SiteWithDiveCount(site: \1, diveCount: \2);/' test/features/dive_sites/domain/constants/site_field_test.dart
sed -i '' -E 's/=> \(site: site, diveCount: 0\);/=> SiteWithDiveCount(site: site, diveCount: 0);/' test/features/dive_sites/domain/constants/site_field_entry_method_test.dart
grep -n "diveCount: " test/features/dive_sites/domain/constants/site_field_test.dart test/features/dive_sites/domain/constants/site_field_entry_method_test.dart
```

Every hit must now read `SiteWithDiveCount(site: ..., diveCount: ...)`. Add to both test files the import `import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';`. Lines that were `const testEntity = (...)` stay `const`; the constructor is const.

- [ ] **Step 6: Run the tests and the analyzer**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/dive_sites/domain/entities/site_with_dive_count_test.dart test/features/dive_sites/domain/constants/ test/features/dive_sites/presentation/widgets/site_list_content_table_test.dart && flutter analyze lib/features/dive_sites test/features/dive_sites`
Expected: all PASS, "No issues found!".

- [ ] **Step 7: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
dart format .
git add lib/features/dive_sites test/features/dive_sites
git commit -m "refactor(sites): move SiteWithDiveCount to domain and carry aggregates"
```

---

### Task 2: Buddy wrapper class and usual-role rule

**Files:**
- Create: `lib/features/buddies/domain/entities/buddy_with_dive_count.dart`
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart:1005-1012` (delete class, add import + export)
- Modify: `lib/features/buddies/domain/constants/buddy_field.dart:9-10` (typedef alias)
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_content.dart:617-621` (drop record conversion)
- Modify: `test/features/buddies/domain/constants/buddy_field_test.dart` (record literals)
- Test: `test/features/buddies/domain/entities/buddy_with_dive_count_test.dart`

**Interfaces:**
- Produces: `class BuddyWithDiveCount { Buddy buddy; int diveCount; DateTime? lastDiveAt; String? usualRoleId; }` (const, `Equatable`); `String? usualRoleFor(Map<String, int> countsByRole)`; `typedef BuddyWithCount = BuddyWithDiveCount`.

- [ ] **Step 1: Write the failing test**

Create `test/features/buddies/domain/entities/buddy_with_dive_count_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';

void main() {
  final buddy = Buddy(
    id: 'b1',
    name: 'Jane',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('BuddyWithDiveCount', () {
    test('aggregates default to null', () {
      final entry = BuddyWithDiveCount(buddy: buddy, diveCount: 2);
      expect(entry.lastDiveAt, isNull);
      expect(entry.usualRoleId, isNull);
    });

    test('is value-equal on every field', () {
      final a = BuddyWithDiveCount(
        buddy: buddy,
        diveCount: 2,
        lastDiveAt: DateTime(2026, 2, 2),
        usualRoleId: 'instructor',
      );
      final b = BuddyWithDiveCount(
        buddy: buddy,
        diveCount: 2,
        lastDiveAt: DateTime(2026, 2, 2),
        usualRoleId: 'instructor',
      );
      expect(a, equals(b));
    });
  });

  group('usualRoleFor', () {
    test('returns null for a buddy with no dives', () {
      expect(usualRoleFor(const {}), isNull);
    });

    test('picks the role with the highest count', () {
      expect(
        usualRoleFor(const {'buddy': 1, 'instructor': 3, 'student': 2}),
        'instructor',
      );
    });

    test('breaks ties on role id ascending so the answer is stable', () {
      expect(usualRoleFor(const {'instructor': 2, 'buddy': 2}), 'buddy');
      expect(usualRoleFor(const {'zzz-custom': 2, 'diveGuide': 2}), 'diveGuide');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/buddies/domain/entities/buddy_with_dive_count_test.dart`
Expected: FAIL to compile, "Target of URI doesn't exist ... buddy_with_dive_count.dart".

- [ ] **Step 3: Create the domain file**

Create `lib/features/buddies/domain/entities/buddy_with_dive_count.dart`:

```dart
import 'package:equatable/equatable.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';

/// A [Buddy] paired with the aggregates the buddy list renders.
///
/// [usualRoleId] is the `dive_buddies.role` id this buddy most often holds
/// (see [usualRoleFor]); null when the buddy has no dives. It is a raw id,
/// resolved to a display name through `diveRoleMapProvider` at render time.
class BuddyWithDiveCount extends Equatable {
  final Buddy buddy;
  final int diveCount;
  final DateTime? lastDiveAt;
  final String? usualRoleId;

  const BuddyWithDiveCount({
    required this.buddy,
    required this.diveCount,
    this.lastDiveAt,
    this.usualRoleId,
  });

  @override
  List<Object?> get props => [buddy, diveCount, lastDiveAt, usualRoleId];
}

/// The role a buddy most often holds, from `{roleId: count}`.
///
/// Higher count wins. Ties break on role id ascending so two devices with
/// the same data agree on the answer. Null when the map is empty.
String? usualRoleFor(Map<String, int> countsByRole) {
  String? best;
  var bestCount = 0;
  final ids = countsByRole.keys.toList()..sort();
  for (final id in ids) {
    final count = countsByRole[id]!;
    if (count > bestCount) {
      best = id;
      bestCount = count;
    }
  }
  return best;
}
```

- [ ] **Step 4: Point the repository and the adapter at it**

In `lib/features/buddies/data/repositories/buddy_repository.dart`, delete (currently lines 1005-1012):

```dart
/// Buddy with dive count for efficient list sorting
class BuddyWithDiveCount {
  final domain.Buddy buddy;
  final int diveCount;

  const BuddyWithDiveCount({required this.buddy, required this.diveCount});
}
```

and add after the `buddy.dart as domain` import:

```dart
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
```

and extend the existing `export` block with a second export line right after it:

```dart
// Re-exported so existing importers of BuddyWithDiveCount keep compiling
// after the class moved to the domain layer.
export 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
```

In `lib/features/buddies/domain/constants/buddy_field.dart` replace lines 9-10:

```dart
/// Wrapper carrying a [Buddy] with its computed dive count.
typedef BuddyWithCount = ({Buddy buddy, int diveCount});
```

with:

```dart
/// Entity handed to [BuddyFieldAdapter]. An alias of the repository's class so
/// the table view and the list cards share one type with no conversion.
typedef BuddyWithCount = BuddyWithDiveCount;
```

and add `import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';` after the `buddy.dart` import.

In `lib/features/buddies/presentation/widgets/buddy_list_content.dart` delete lines 617-621 (the "Convert BuddyWithDiveCount (class) to BuddyWithCount (record)" comment and `buddyRecords` map) and change `entities: buddyRecords,` to `entities: buddies,`.

- [ ] **Step 5: Convert the record literals in the adapter test**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
sed -i '' -E 's/= \(buddy: ([A-Za-z]+), diveCount: ([0-9]+)\);/= BuddyWithDiveCount(buddy: \1, diveCount: \2);/' test/features/buddies/domain/constants/buddy_field_test.dart
grep -n "diveCount: " test/features/buddies/domain/constants/buddy_field_test.dart
```

Every hit must read `BuddyWithDiveCount(buddy: ..., diveCount: ...)`. Add the import `import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';` to that test.

- [ ] **Step 6: Run the tests and the analyzer**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/buddies/domain/ test/features/buddies/presentation/widgets/buddy_list_content_test.dart && flutter analyze lib/features/buddies test/features/buddies`
Expected: all PASS, "No issues found!".

- [ ] **Step 7: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
dart format .
git add lib/features/buddies test/features/buddies
git commit -m "refactor(buddies): move BuddyWithDiveCount to domain and add usualRoleFor"
```

---

### Task 3: Site aggregate queries and feature-change reactivity

**Files:**
- Modify: `lib/features/dive_sites/data/repositories/site_repository_impl.dart:790-838` (`getDiveCountsBySite`, `getSitesWithDiveCounts`)
- Modify: `lib/features/dive_sites/presentation/providers/site_providers.dart:194-204` (`sitesWithCountsProvider`)
- Test: `test/features/dive_sites/data/repositories/site_repository_aggregates_test.dart`

**Interfaces:**
- Consumes: `SiteDiveAggregate`, `SiteWithDiveCount` (Task 1).
- Produces: `Future<Map<String, SiteDiveAggregate>> getDiveAggregatesBySite()`, `Future<Map<String, List<String>>> getFeatureTypesBySite()`; `getDiveCountsBySite()` keeps its signature; `getSitesWithDiveCounts()` now fills `lastDivedAt`, `maxDepthReached`, `featureTypes`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_sites/data/repositories/site_repository_aggregates_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

Future<void> _insertDive(
  db.AppDatabase database, {
  required String id,
  required String siteId,
  required DateTime at,
  double? maxDepth,
}) async {
  final ms = at.millisecondsSinceEpoch;
  await database
      .into(database.dives)
      .insert(
        db.DivesCompanion(
          id: Value(id),
          diveDateTime: Value(ms),
          siteId: Value(siteId),
          maxDepth: Value(maxDepth),
          createdAt: Value(ms),
          updatedAt: Value(ms),
        ),
      );
}

Future<void> _insertFeature(
  db.AppDatabase database, {
  required String id,
  required String siteId,
  required String type,
  required int createdAt,
}) async {
  await database
      .into(database.siteFeatures)
      .insert(
        db.SiteFeaturesCompanion(
          id: Value(id),
          siteId: Value(siteId),
          type: Value(type),
          latitude: const Value(0),
          longitude: const Value(0),
          createdAt: Value(createdAt),
          updatedAt: Value(createdAt),
        ),
      );
}

void main() {
  late SiteRepository repository;
  late db.AppDatabase database;

  setUp(() async {
    await setUpTestDatabase();
    repository = SiteRepository();
    database = DatabaseService.instance.database;
    await repository.createSite(const DiveSite(id: 'site-a', name: 'A'));
    await repository.createSite(const DiveSite(id: 'site-b', name: 'B'));
    await repository.createSite(const DiveSite(id: 'site-c', name: 'C'));
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('getDiveAggregatesBySite', () {
    test('counts, last-dived and deepest depth per site', () async {
      await _insertDive(
        database,
        id: 'd1',
        siteId: 'site-a',
        at: DateTime(2024, 1, 10),
        maxDepth: 18,
      );
      await _insertDive(
        database,
        id: 'd2',
        siteId: 'site-a',
        at: DateTime(2024, 3, 5),
        maxDepth: 31.5,
      );
      await _insertDive(
        database,
        id: 'd3',
        siteId: 'site-b',
        at: DateTime(2023, 6, 1),
      );

      final aggregates = await repository.getDiveAggregatesBySite();

      expect(aggregates.keys, unorderedEquals(['site-a', 'site-b']));
      expect(aggregates['site-a']!.diveCount, 2);
      expect(aggregates['site-a']!.lastDivedAt, DateTime(2024, 3, 5));
      expect(aggregates['site-a']!.maxDepthReached, 31.5);
      expect(aggregates['site-b']!.diveCount, 1);
      expect(aggregates['site-b']!.maxDepthReached, isNull);
    });

    test('getDiveCountsBySite still returns plain counts', () async {
      await _insertDive(
        database,
        id: 'd1',
        siteId: 'site-a',
        at: DateTime(2024, 1, 10),
      );

      expect(await repository.getDiveCountsBySite(), {'site-a': 1});
    });
  });

  group('getFeatureTypesBySite', () {
    test('lists distinct type names ordered by first creation', () async {
      await _insertFeature(
        database,
        id: 'f1',
        siteId: 'site-a',
        type: 'wreck',
        createdAt: 100,
      );
      await _insertFeature(
        database,
        id: 'f2',
        siteId: 'site-a',
        type: 'mooring',
        createdAt: 200,
      );
      await _insertFeature(
        database,
        id: 'f3',
        siteId: 'site-a',
        type: 'wreck',
        createdAt: 300,
      );
      await _insertFeature(
        database,
        id: 'f4',
        siteId: 'site-b',
        type: 'swimThrough',
        createdAt: 50,
      );

      final types = await repository.getFeatureTypesBySite();

      expect(types['site-a'], ['wreck', 'mooring']);
      expect(types['site-b'], ['swimThrough']);
      expect(types.containsKey('site-c'), isFalse);
    });
  });

  group('getSitesWithDiveCounts', () {
    test('assembles aggregates and feature types per site', () async {
      await _insertDive(
        database,
        id: 'd1',
        siteId: 'site-a',
        at: DateTime(2024, 3, 5),
        maxDepth: 31.5,
      );
      await _insertFeature(
        database,
        id: 'f1',
        siteId: 'site-a',
        type: 'wreck',
        createdAt: 100,
      );

      final sites = await repository.getSitesWithDiveCounts();
      final a = sites.singleWhere((s) => s.site.id == 'site-a');
      final c = sites.singleWhere((s) => s.site.id == 'site-c');

      expect(a.diveCount, 1);
      expect(a.lastDivedAt, DateTime(2024, 3, 5));
      expect(a.maxDepthReached, 31.5);
      expect(a.featureTypes, ['wreck']);
      expect(c.diveCount, 0);
      expect(c.lastDivedAt, isNull);
      expect(c.maxDepthReached, isNull);
      expect(c.featureTypes, isEmpty);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/dive_sites/data/repositories/site_repository_aggregates_test.dart`
Expected: FAIL to compile, "The method 'getDiveAggregatesBySite' isn't defined".

- [ ] **Step 3: Implement the queries**

In `lib/features/dive_sites/data/repositories/site_repository_impl.dart`, replace the whole `getDiveCountsBySite` method (currently lines 790-809) with:

```dart
  /// Dive count per site. Kept for callers that only need the count; the
  /// list path uses [getDiveAggregatesBySite].
  Future<Map<String, int>> getDiveCountsBySite() async {
    final aggregates = await getDiveAggregatesBySite();
    return aggregates.map((siteId, a) => MapEntry(siteId, a.diveCount));
  }

  /// One GROUP BY over the dives table: count, most recent dive, and the
  /// deepest max_depth logged, per site. Sites with no dives are absent.
  Future<Map<String, SiteDiveAggregate>> getDiveAggregatesBySite() async {
    try {
      final result = await _db.customSelect('''
        SELECT site_id,
               COUNT(*) AS dive_count,
               MAX(dive_date_time) AS last_dived,
               MAX(max_depth) AS max_depth_reached
        FROM dives
        WHERE site_id IS NOT NULL
        GROUP BY site_id
      ''').get();

      return {
        for (final row in result)
          row.data['site_id'] as String: SiteDiveAggregate(
            diveCount: row.data['dive_count'] as int,
            lastDivedAt: row.data['last_dived'] == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(
                    row.data['last_dived'] as int,
                  ),
            maxDepthReached: (row.data['max_depth_reached'] as num?)
                ?.toDouble(),
          ),
      };
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get dive aggregates by site',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Distinct `site_features.type` names per site, ordered by the first
  /// feature of each type. One query for the whole list, so a card can show
  /// feature chips without a per-row lookup.
  Future<Map<String, List<String>>> getFeatureTypesBySite() async {
    try {
      final result = await _db.customSelect('''
        SELECT site_id, type, MIN(created_at) AS first_seen
        FROM site_features
        GROUP BY site_id, type
        ORDER BY site_id, first_seen
      ''').get();

      final types = <String, List<String>>{};
      for (final row in result) {
        types
            .putIfAbsent(row.data['site_id'] as String, () => [])
            .add(row.data['type'] as String);
      }
      return types;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get feature types by site',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

Then in `getSitesWithDiveCounts` replace the body of the `PerfTimer.measure` closure:

```dart
        final sites = await getAllSites(diverId: diverId);
        final counts = await getDiveCountsBySite();

        return sites
            .map(
              (site) => SiteWithDiveCount(
                site: site,
                diveCount: counts[site.id] ?? 0,
              ),
            )
            .toList()
          ..sort((a, b) => b.diveCount.compareTo(a.diveCount));
```

with:

```dart
        final sites = await getAllSites(diverId: diverId);
        final aggregates = await getDiveAggregatesBySite();
        final featureTypes = await getFeatureTypesBySite();

        return sites
            .map((site) {
              final a = aggregates[site.id];
              return SiteWithDiveCount(
                site: site,
                diveCount: a?.diveCount ?? 0,
                lastDivedAt: a?.lastDivedAt,
                maxDepthReached: a?.maxDepthReached,
                featureTypes: featureTypes[site.id] ?? const [],
              );
            })
            .toList()
          ..sort((a, b) => b.diveCount.compareTo(a.diveCount));
```

- [ ] **Step 4: Run the tests**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/dive_sites/data/repositories/`
Expected: all PASS (the new file and the existing `site_repository_test.dart`, whose `getDiveCountsBySite` and `getSitesWithDiveCounts` groups still hold).

- [ ] **Step 5: Refresh the list when a site feature changes**

In `lib/features/dive_sites/presentation/providers/site_providers.dart` add the import:

```dart
import 'package:submersion/features/dive_sites/presentation/providers/site_feature_providers.dart';
```

and in `sitesWithCountsProvider`, after the existing `ref.invalidateSelfWhen(ref.read(diveRepositoryProvider).watchDivesChanges());` line, add:

```dart
  // Feature chips on the list card come from site_features, so a feature
  // placed on the site map must refresh the list too.
  ref.invalidateSelfWhen(
    ref.read(siteFeatureRepositoryProvider).watchFeatureChanges(),
  );
```

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/dive_sites/presentation/providers/site_providers_test.dart`
Expected: PASS. (That test uses the real test database, so the extra stream is live and harmless.)

- [ ] **Step 6: Regenerate mocks and analyze**

Four generated `.mocks.dart` files mock `SiteRepository`; regenerate so they know the new methods:

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && dart run build_runner build --delete-conflicting-outputs && flutter analyze lib/features/dive_sites test/features/dive_sites`
Expected: build succeeds, "No issues found!".

- [ ] **Step 7: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
dart format .
git add lib/features/dive_sites test/features/dive_sites
git add -u test
git commit -m "feat(sites): batch last-dived, max depth reached and feature types per site"
```

---

### Task 4: Buddy last-dive and usual-role aggregates

**Files:**
- Modify: `lib/features/buddies/data/repositories/buddy_repository.dart:753-816` (`getAllBuddiesWithDiveCount`)
- Test: `test/features/buddies/data/repositories/buddy_repository_aggregates_test.dart`

**Interfaces:**
- Consumes: `BuddyWithDiveCount`, `usualRoleFor` (Task 2).
- Produces: `getAllBuddiesWithDiveCount()` now fills `lastDiveAt` and `usualRoleId`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/buddies/data/repositories/buddy_repository_aggregates_test.dart`:

```dart
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

import '../../../../helpers/test_database.dart';

Future<void> _insertDive(
  db.AppDatabase database, {
  required String id,
  required DateTime at,
}) async {
  final ms = at.millisecondsSinceEpoch;
  await database
      .into(database.dives)
      .insert(
        db.DivesCompanion(
          id: Value(id),
          diveDateTime: Value(ms),
          createdAt: Value(ms),
          updatedAt: Value(ms),
        ),
      );
}

Future<void> _link(
  db.AppDatabase database, {
  required String diveId,
  required String buddyId,
  String role = DiveRole.buddyId,
}) async {
  await database
      .into(database.diveBuddies)
      .insert(
        db.DiveBuddiesCompanion(
          id: Value('$diveId-$buddyId'),
          diveId: Value(diveId),
          buddyId: Value(buddyId),
          role: Value(role),
          createdAt: Value(DateTime.now().millisecondsSinceEpoch),
        ),
      );
}

void main() {
  late BuddyRepository repository;
  late db.AppDatabase database;

  setUp(() async {
    await setUpTestDatabase();
    repository = BuddyRepository();
    database = DatabaseService.instance.database;
    final now = DateTime(2026, 1, 1);
    await repository.createBuddy(
      Buddy(id: 'jane', name: 'Jane', createdAt: now, updatedAt: now),
    );
    await repository.createBuddy(
      Buddy(id: 'ken', name: 'Ken', createdAt: now, updatedAt: now),
    );
    await _insertDive(database, id: 'd1', at: DateTime(2024, 1, 10));
    await _insertDive(database, id: 'd2', at: DateTime(2024, 3, 5));
    await _insertDive(database, id: 'd3', at: DateTime(2024, 2, 1));
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<BuddyWithDiveCount> load(String id) async {
    final all = await repository.getAllBuddiesWithDiveCount();
    return all.singleWhere((b) => b.buddy.id == id);
  }

  test('lastDiveAt is the most recent linked dive', () async {
    await _link(database, diveId: 'd1', buddyId: 'jane');
    await _link(database, diveId: 'd2', buddyId: 'jane');
    await _link(database, diveId: 'd3', buddyId: 'jane');

    final jane = await load('jane');

    expect(jane.diveCount, 3);
    expect(jane.lastDiveAt, DateTime(2024, 3, 5));
  });

  test('a buddy with no dives has null aggregates and zero count', () async {
    final ken = await load('ken');

    expect(ken.diveCount, 0);
    expect(ken.lastDiveAt, isNull);
    expect(ken.usualRoleId, isNull);
  });

  test('usualRoleId is the most frequent role', () async {
    await _link(
      database,
      diveId: 'd1',
      buddyId: 'jane',
      role: DiveRole.instructorId,
    );
    await _link(
      database,
      diveId: 'd2',
      buddyId: 'jane',
      role: DiveRole.instructorId,
    );
    await _link(database, diveId: 'd3', buddyId: 'jane');

    expect((await load('jane')).usualRoleId, DiveRole.instructorId);
  });

  test('usualRoleId breaks ties on role id ascending', () async {
    await _link(
      database,
      diveId: 'd1',
      buddyId: 'ken',
      role: DiveRole.instructorId,
    );
    await _link(database, diveId: 'd2', buddyId: 'ken');

    expect((await load('ken')).usualRoleId, DiveRole.buddyId);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/buddies/data/repositories/buddy_repository_aggregates_test.dart`
Expected: the three aggregate tests FAIL (`lastDiveAt` is null, `usualRoleId` is null); the zero-count test passes.

- [ ] **Step 3: Widen the query**

In `lib/features/buddies/data/repositories/buddy_repository.dart`, inside `getAllBuddiesWithDiveCount`, replace the SQL string:

```dart
        SELECT b.*, COALESCE(dc.dive_count, 0) as dive_count
        FROM buddies b
        LEFT JOIN (
          SELECT buddy_id, COUNT(*) as dive_count
          FROM dive_buddies
          GROUP BY buddy_id
        ) dc ON b.id = dc.buddy_id
        $diverFilter
        ORDER BY b.name ASC
```

with:

```dart
        SELECT b.*, COALESCE(dc.dive_count, 0) AS dive_count, dc.last_dive
        FROM buddies b
        LEFT JOIN (
          SELECT db.buddy_id,
                 COUNT(*) AS dive_count,
                 MAX(d.dive_date_time) AS last_dive
          FROM dive_buddies db
          LEFT JOIN dives d ON d.id = db.dive_id
          GROUP BY db.buddy_id
        ) dc ON b.id = dc.buddy_id
        $diverFilter
        ORDER BY b.name ASC
```

Directly after the `results` query (before `final list = results.map(...)`), add the role query:

```dart
      // Second whole-table query: how often each buddy held each role. The
      // per-buddy winner is picked in Dart by usualRoleFor.
      final roleRows = await _db.customSelect('''
        SELECT buddy_id, role, COUNT(*) AS role_count
        FROM dive_buddies
        GROUP BY buddy_id, role
      ''').get();
      final roleCountsByBuddy = <String, Map<String, int>>{};
      for (final r in roleRows) {
        roleCountsByBuddy.putIfAbsent(
          r.data['buddy_id'] as String,
          () => {},
        )[r.data['role'] as String] = r.data['role_count'] as int;
      }
```

Change the first `return BuddyWithDiveCount(...)` inside the map to:

```dart
        final lastDive = row.data['last_dive'] as int?;
        return BuddyWithDiveCount(
          buddy: buddy,
          diveCount: row.data['dive_count'] as int,
          lastDiveAt: lastDive == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(lastDive),
          usualRoleId: usualRoleFor(roleCountsByBuddy[buddy.id] ?? const {}),
        );
```

and the final rebuild after `_withPrimaryCerts` to:

```dart
      return [
        for (final w in list)
          BuddyWithDiveCount(
            buddy: byId[w.buddy.id]!,
            diveCount: w.diveCount,
            lastDiveAt: w.lastDiveAt,
            usualRoleId: w.usualRoleId,
          ),
      ];
```

- [ ] **Step 4: Run the tests**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/buddies/data/repositories/ test/features/buddies/presentation/providers/`
Expected: all PASS.

- [ ] **Step 5: Regenerate mocks, analyze, commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
dart run build_runner build --delete-conflicting-outputs
flutter analyze lib/features/buddies test/features/buddies
dart format .
git add lib/features/buddies test/features/buddies
git add -u test
git commit -m "feat(buddies): batch last dive together and usual role per buddy"
```

Expected before the commit: "No issues found!".

---

### Task 5: New SiteField values and their translations

**Files:**
- Modify: `lib/features/dive_sites/domain/constants/site_field.dart` (enum, every switch, adapter)
- Modify: `lib/l10n/arb/app_en.arb` and the other 10 arb files
- Test: `test/features/dive_sites/domain/constants/site_field_test.dart`

**Interfaces:**
- Consumes: `SiteWithDiveCount.lastDivedAt`, `.maxDepthReached` (Task 1).
- Produces: `SiteField.depthRange` (value `({double? min, double? max})`, not sortable), `SiteField.lastDived` (`DateTime?`), `SiteField.maxDepthReached` (`double?` metres); `SiteFieldCategory.statistics`; l10n keys `enum_siteField_depthRange`, `enum_siteField_depthRange_short`, `enum_siteField_lastDived`, `enum_siteField_lastDived_short`, `enum_siteField_maxDepthReached`, `enum_siteField_maxDepthReached_short`.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/dive_sites/domain/constants/site_field_test.dart`, inside `main()` after the existing groups (the file already defines `units`, `testSite`, `testEntity`):

```dart
  group('statistics fields', () {
    const imperial = UnitFormatter(AppSettings(depthUnit: DepthUnit.feet));

    test('depthRange extracts a min/max record from the site', () {
      final value = SiteFieldAdapter.instance.extractValue(
        SiteField.depthRange,
        testEntity,
      );
      expect(value, (min: 5.0, max: 50.0));
    });

    test('depthRange is null when the site has no depths', () {
      const bare = SiteWithDiveCount(
        site: DiveSite(id: 's', name: 'Bare'),
        diveCount: 0,
      );
      expect(
        SiteFieldAdapter.instance.extractValue(SiteField.depthRange, bare),
        isNull,
      );
    });

    test('depthRange formats as a single-symbol range in metric', () {
      expect(
        SiteFieldAdapter.instance.formatValue(
          SiteField.depthRange,
          (min: 5.0, max: 50.0),
          units,
        ),
        '5-50m',
      );
    });

    test('depthRange converts both ends in imperial', () {
      expect(
        SiteFieldAdapter.instance.formatValue(
          SiteField.depthRange,
          (min: 5.0, max: 50.0),
          imperial,
        ),
        '16-164ft',
      );
    });

    test('depthRange with only a max depth formats the max', () {
      expect(
        SiteFieldAdapter.instance.formatValue(
          SiteField.depthRange,
          (min: null, max: 50.0),
          units,
        ),
        '50m',
      );
    });

    test('lastDived reads the aggregate and formats as a date', () {
      final entry = SiteWithDiveCount(
        site: testSite,
        diveCount: 1,
        lastDivedAt: DateTime(2024, 3, 5),
      );
      final value = SiteFieldAdapter.instance.extractValue(
        SiteField.lastDived,
        entry,
      );
      expect(value, DateTime(2024, 3, 5));
      expect(
        SiteFieldAdapter.instance.formatValue(SiteField.lastDived, value, units),
        units.formatDate(DateTime(2024, 3, 5)),
      );
    });

    test('maxDepthReached reads the aggregate and formats as a depth', () {
      const entry = SiteWithDiveCount(
        site: testSite,
        diveCount: 1,
        maxDepthReached: 31.5,
      );
      final value = SiteFieldAdapter.instance.extractValue(
        SiteField.maxDepthReached,
        entry,
      );
      expect(value, 31.5);
      expect(
        SiteFieldAdapter.instance.formatValue(
          SiteField.maxDepthReached,
          value,
          units,
        ),
        '32m',
      );
    });

    test('statistics fields carry the statistics category and icons', () {
      for (final f in [
        SiteField.depthRange,
        SiteField.lastDived,
        SiteField.maxDepthReached,
      ]) {
        expect(f.categoryName, 'statistics');
        expect(f.icon, isNotNull);
      }
      expect(SiteField.depthRange.sortable, isFalse);
      expect(SiteField.lastDived.sortable, isTrue);
      expect(SiteField.maxDepthReached.sortable, isTrue);
    });
  });
```

Add `import 'package:submersion/core/constants/units.dart';` to the test imports.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_sites/domain/constants/site_field_test.dart`
Expected: FAIL to compile, "Undefined name 'depthRange'".

- [ ] **Step 3: Add the enum values and category**

In `lib/features/dive_sites/domain/constants/site_field.dart`:

1. `enum SiteFieldCategory { core, depth, conditions, details, coordinates }` becomes `enum SiteFieldCategory { core, depth, conditions, details, coordinates, statistics }`.

2. In `enum SiteField`, change the last value `longitude;` to `longitude,` and append:

```dart
  // Statistics (aggregated over the dives logged at the site)
  depthRange,
  lastDived,
  maxDepthReached;
```

3. Add a case to each switch. `displayName`: `depthRange => 'Depth Range'`, `lastDived => 'Last Dived'`, `maxDepthReached => 'Your Max Depth'`. `shortLabel`: `'Depth'`, `'Last dived'`, `'Your max'`. `localizedDisplayName`: `l10n.enum_siteField_depthRange`, `l10n.enum_siteField_lastDived`, `l10n.enum_siteField_maxDepthReached`. `localizedShortLabel`: the same three with `_short`. `icon`: `Icons.straighten`, `Icons.history`, `Icons.vertical_align_bottom`. `defaultWidth`: 100, 110, 90. `minWidth`: 60, 70, 50. `sortable`: `depthRange` in the `false` group, the other two in the `true` group. `categoryName`: all three `return SiteFieldCategory.statistics.name;`. `isRightAligned`: `maxDepthReached` true, the other two false.

The `switch` statements use `case X:` form for the older getters and `=>` arms for the localized ones; follow each switch's own form.

4. In `SiteFieldAdapter.extractValue` add before the closing brace of the switch:

```dart
      case SiteField.depthRange:
        if (site.minDepth == null && site.maxDepth == null) return null;
        return (min: site.minDepth, max: site.maxDepth);
      case SiteField.lastDived:
        return entity.lastDivedAt;
      case SiteField.maxDepthReached:
        return entity.maxDepthReached;
```

5. In `SiteFieldAdapter.formatValue` add:

```dart
      case SiteField.depthRange:
        final range = value as ({double? min, double? max});
        final min = range.min;
        final max = range.max;
        if (min != null && max != null) {
          // One trailing symbol for the pair ("16-98ft"), matching the site
          // list card's historical rendering.
          final low = units.convertDepth(min).toStringAsFixed(0);
          return '$low-${units.formatDepth(max, decimals: 0)}';
        }
        return units.formatDepth(max ?? min, decimals: 0);
      case SiteField.lastDived:
        return units.formatDate(value as DateTime);
      case SiteField.maxDepthReached:
        return units.formatDepth(value as double, decimals: 0);
```

- [ ] **Step 4: Add the l10n keys to all 11 arb files**

Verify none exist yet: `grep -c '"enum_siteField_depthRange"' lib/l10n/arb/app_en.arb` must print `0`.

In `lib/l10n/arb/app_en.arb`, directly after the `"enum_siteField_longitude_short"` entry, insert:

```json
  "enum_siteField_depthRange": "Depth Range",
  "@enum_siteField_depthRange": {},
  "enum_siteField_depthRange_short": "Depth",
  "@enum_siteField_depthRange_short": {},
  "enum_siteField_lastDived": "Last Dived",
  "@enum_siteField_lastDived": {},
  "enum_siteField_lastDived_short": "Last dived",
  "@enum_siteField_lastDived_short": {},
  "enum_siteField_maxDepthReached": "Your Max Depth",
  "@enum_siteField_maxDepthReached": {},
  "enum_siteField_maxDepthReached_short": "Your max",
  "@enum_siteField_maxDepthReached_short": {},
```

If the neighbouring `enum_siteField_*` entries in `app_en.arb` carry no `"@key": {}` lines, omit them here too; match the file. In each other locale file insert the six value lines at the same place, with these values:

| Locale | depthRange | depthRange_short | lastDived | lastDived_short | maxDepthReached | maxDepthReached_short |
| --- | --- | --- | --- | --- | --- | --- |
| de | Tiefenbereich | Tiefe | Zuletzt getaucht | Zuletzt | Deine max. Tiefe | Dein Max. |
| es | Rango de profundidad | Prof. | Último buceo | Último | Tu prof. máxima | Tu máx. |
| fr | Plage de profondeur | Prof. | Dernière plongée | Dernière | Votre prof. max | Votre max |
| it | Intervallo di profondità | Prof. | Ultima immersione | Ultima | La tua prof. max | Tuo max |
| nl | Dieptebereik | Diepte | Laatst gedoken | Laatst | Jouw max. diepte | Jouw max. |
| pt | Faixa de profundidade | Prof. | Último mergulho | Último | Sua prof. máxima | Seu máx. |
| hu | Mélységtartomány | Mélység | Utolsó merülés | Utolsó | Saját max. mélység | Saját max. |
| zh | 深度范围 | 深度 | 最近潜水 | 最近 | 你的最大深度 | 你的最大 |
| ar | نطاق العمق | العمق | آخر غوص | الأخير | أقصى عمق لك | أقصاك |
| he | טווח עומק | עומק | צלילה אחרונה | אחרונה | העומק המרבי שלך | המרבי שלך |

Then regenerate and confirm every locale got all six:

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
for f in lib/l10n/arb/app_*.arb; do echo "$f $(grep -c 'enum_siteField_depthRange\|enum_siteField_lastDived\|enum_siteField_maxDepthReached' "$f")"; done
flutter gen-l10n
```

Expected: `app_en.arb 12` (values plus metadata) or `6` if the file carries no metadata, and `6` for each other locale.

- [ ] **Step 5: Run the tests and analyzer**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/dive_sites/domain/constants/ test/features/settings/presentation/pages/column_config_page_test.dart && flutter analyze lib/features/dive_sites lib/l10n`
Expected: all PASS, "No issues found!".

- [ ] **Step 6: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
dart format .
git add lib/features/dive_sites lib/l10n test/features/dive_sites
git commit -m "feat(sites): add depthRange, lastDived and maxDepthReached site fields"
```

---

### Task 6: BuddyField.lastDive and the displayName fix

**Files:**
- Modify: `lib/features/buddies/domain/constants/buddy_field.dart`
- Modify: the 11 arb files
- Test: `test/features/buddies/domain/constants/buddy_field_test.dart`

**Interfaces:**
- Consumes: `BuddyWithDiveCount.lastDiveAt` (Task 2).
- Produces: `BuddyField.lastDive` (`DateTime?`, sortable, category `statistics`); `BuddyFieldAdapter.formatValue` returns `displayName` for cert level and agency; l10n keys `enum_buddyField_lastDive`, `enum_buddyField_lastDive_short`.

- [ ] **Step 1: Write the failing tests**

Append inside `main()` of `test/features/buddies/domain/constants/buddy_field_test.dart`:

```dart
  group('lastDive and display names', () {
    test('lastDive reads the aggregate and formats as a date', () {
      final entry = BuddyWithDiveCount(
        buddy: testBuddy,
        diveCount: 15,
        lastDiveAt: DateTime(2024, 3, 5),
      );
      final value = BuddyFieldAdapter.instance.extractValue(
        BuddyField.lastDive,
        entry,
      );
      expect(value, DateTime(2024, 3, 5));
      expect(
        BuddyFieldAdapter.instance.formatValue(BuddyField.lastDive, value, units),
        units.formatDate(DateTime(2024, 3, 5)),
      );
      expect(BuddyField.lastDive.categoryName, 'statistics');
      expect(BuddyField.lastDive.sortable, isTrue);
      expect(BuddyField.lastDive.icon, Icons.history);
    });

    test('certification level and agency format as display names', () {
      expect(
        BuddyFieldAdapter.instance.formatValue(
          BuddyField.certificationLevel,
          CertificationLevel.advancedOpenWater,
          units,
        ),
        'Advanced Open Water',
      );
      expect(
        BuddyFieldAdapter.instance.formatValue(
          BuddyField.certificationAgency,
          CertificationAgency.padi,
          units,
        ),
        'PADI',
      );
    });
  });
```

If an existing test in that file asserts `formatValue(certificationLevel, ...)` equals `'advancedOpenWater'` or `formatValue(certificationAgency, ...)` equals `'padi'`, change its expectation to the display name; that old behaviour is the bug being fixed.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/buddies/domain/constants/buddy_field_test.dart`
Expected: FAIL to compile, "Undefined name 'lastDive'".

- [ ] **Step 3: Implement**

In `lib/features/buddies/domain/constants/buddy_field.dart`:

1. Change `notes;` to `notes,` and append `lastDive;` to the enum.
2. Add arms: `displayName` `BuddyField.lastDive => 'Last Dive'`; `shortLabel` `=> 'Last dive'`; `localizedDisplayName` `=> l10n.enum_buddyField_lastDive`; `localizedShortLabel` `=> l10n.enum_buddyField_lastDive_short`; `icon` `=> Icons.history`; `defaultWidth` `=> 110`; `minWidth` `=> 70`; `categoryName` `=> 'statistics'`. `sortable` and `isRightAligned` already default through `_`.
3. `extractValue`: add `BuddyField.lastDive => entity.lastDiveAt,`.
4. `formatValue`: replace the two `.name` arms and add the date arm:

```dart
    return switch (field) {
      BuddyField.certificationLevel =>
        (value as CertificationLevel).displayName,
      BuddyField.certificationAgency =>
        (value as CertificationAgency).displayName,
      BuddyField.diveCount => (value as int).toString(),
      BuddyField.lastDive => units.formatDate(value as DateTime),
      _ => value is String ? (value.isEmpty ? '--' : value) : value.toString(),
    };
```

- [ ] **Step 4: Add the l10n keys**

Verify with `grep -c '"enum_buddyField_lastDive"' lib/l10n/arb/app_en.arb` (must be `0`). After the `"enum_buddyField_notes_short"` entry in each arb file insert the two keys (en gets metadata lines only if its neighbours do):

| Locale | enum_buddyField_lastDive | enum_buddyField_lastDive_short |
| --- | --- | --- |
| en | Last Dive | Last dive |
| de | Letzter Tauchgang | Letzter TG |
| es | Último buceo | Último |
| fr | Dernière plongée | Dernière |
| it | Ultima immersione | Ultima |
| nl | Laatste duik | Laatste |
| pt | Último mergulho | Último |
| hu | Utolsó merülés | Utolsó |
| zh | 最近潜水 | 最近 |
| ar | آخر غوصة | الأخيرة |
| he | צלילה אחרונה | אחרונה |

Then `flutter gen-l10n` and confirm `for f in lib/l10n/arb/app_*.arb; do echo "$f $(grep -c enum_buddyField_lastDive "$f")"; done` prints 2 (or 4 with metadata) for every file.

- [ ] **Step 5: Run the tests and analyzer**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/buddies/domain/constants/ test/features/buddies/presentation/widgets/buddy_list_content_test.dart && flutter analyze lib/features/buddies lib/l10n`
Expected: all PASS, "No issues found!".

- [ ] **Step 6: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
dart format .
git add lib/features/buddies lib/l10n test/features/buddies
git commit -m "feat(buddies): add lastDive field and format certifications by display name"
```

---

### Task 7: Persisted EntityCardConfigNotifier

**Files:**
- Create: `lib/shared/providers/entity_card_config_providers.dart`
- Test: `test/shared/providers/entity_card_config_notifier_test.dart`

**Interfaces:**
- Consumes: `EntityCardViewConfig<F>`, `EntityCardSlotConfig<F>` (`lib/shared/models/entity_card_view_config.dart`), `ViewConfigRepository.getRawConfig/saveRawConfig`.
- Produces: `class EntityCardConfigNotifier<F extends EntityField> extends StateNotifier<EntityCardViewConfig<F>>` with `EntityCardConfigNotifier({required EntityCardViewConfig<F> defaultConfig, required F Function(String) fieldFromName})`, `Future<void> init(ViewConfigRepository repository, String diverId, String storageKey)`, `void setSlotField(String slotId, F field)`, `void setExtraFields(List<F> fields)`, `void addExtraField(F field)`, `void removeExtraField(F field)`, `void reorderExtraFields(int oldIndex, int newIndex)`, `void replace(EntityCardViewConfig<F> config)`, `void resetToDefault()`.

- [ ] **Step 1: Write the failing tests**

Create `test/shared/providers/entity_card_config_notifier_test.dart`:

```dart
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/view_config_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';

enum TestField implements EntityField {
  fieldA,
  fieldB,
  fieldC;

  @override
  String get name => toString().split('.').last;
  @override
  String get displayName => name;
  @override
  String get shortLabel => name;
  @override
  IconData? get icon => null;
  @override
  double get defaultWidth => 100;
  @override
  double get minWidth => 50;
  @override
  bool get sortable => true;
  @override
  String get categoryName => 'test';
  @override
  String localizedDisplayName(AppLocalizations l10n) => displayName;
  @override
  String localizedShortLabel(AppLocalizations l10n) => shortLabel;
  @override
  bool get isRightAligned => false;
}

TestField _fieldFromName(String name) =>
    TestField.values.firstWhere((e) => e.name == name);

const _defaultConfig = EntityCardViewConfig<TestField>(
  slots: [
    EntityCardSlotConfig(slotId: 'title', field: TestField.fieldA),
    EntityCardSlotConfig(slotId: 'stat1', field: TestField.fieldB),
  ],
);

EntityCardConfigNotifier<TestField> _makeNotifier() {
  return EntityCardConfigNotifier<TestField>(
    defaultConfig: _defaultConfig,
    fieldFromName: _fieldFromName,
  );
}

void main() {
  group('EntityCardConfigNotifier mutations', () {
    late EntityCardConfigNotifier<TestField> notifier;

    setUp(() => notifier = _makeNotifier());
    tearDown(() => notifier.dispose());

    test('starts with the default config', () {
      expect(notifier.state, _defaultConfig);
    });

    test('setSlotField swaps one slot and leaves the rest', () {
      notifier.setSlotField('stat1', TestField.fieldC);
      expect(notifier.state.slots[0].field, TestField.fieldA);
      expect(notifier.state.slots[1].field, TestField.fieldC);
    });

    test('addExtraField appends and ignores duplicates', () {
      notifier.addExtraField(TestField.fieldC);
      notifier.addExtraField(TestField.fieldC);
      expect(notifier.state.extraFields, [TestField.fieldC]);
    });

    test('removeExtraField drops the field', () {
      notifier.setExtraFields([TestField.fieldB, TestField.fieldC]);
      notifier.removeExtraField(TestField.fieldB);
      expect(notifier.state.extraFields, [TestField.fieldC]);
    });

    test('reorderExtraFields moves an item', () {
      notifier.setExtraFields([TestField.fieldA, TestField.fieldB, TestField.fieldC]);
      notifier.reorderExtraFields(0, 2);
      expect(notifier.state.extraFields, [
        TestField.fieldB,
        TestField.fieldC,
        TestField.fieldA,
      ]);
    });

    test('replace swaps the whole config and resetToDefault restores', () {
      const other = EntityCardViewConfig<TestField>(
        slots: [EntityCardSlotConfig(slotId: 'title', field: TestField.fieldC)],
        extraFields: [TestField.fieldA],
      );
      notifier.replace(other);
      expect(notifier.state, other);
      notifier.resetToDefault();
      expect(notifier.state, _defaultConfig);
    });
  });

  group('EntityCardConfigNotifier persistence', () {
    late AppDatabase db;
    late ViewConfigRepository repository;
    const diverId = 'diver-test-1';

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repository = ViewConfigRepository(db);
      DatabaseService.instance.setTestDatabase(db);
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: const Value(diverId),
              name: const Value('Test Diver'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    });

    tearDown(() async {
      DatabaseService.instance.resetForTesting();
      await db.close();
    });

    test('init loads a saved config', () async {
      const saved = EntityCardViewConfig<TestField>(
        slots: [EntityCardSlotConfig(slotId: 'title', field: TestField.fieldC)],
        extraFields: [TestField.fieldB],
      );
      await repository.saveRawConfig(
        diverId,
        'card_test',
        jsonEncode(saved.toJson()),
      );
      final notifier = _makeNotifier();
      addTearDown(notifier.dispose);

      await notifier.init(repository, diverId, 'card_test');

      expect(notifier.state, saved);
    });

    test('init keeps the default when a saved field name is unknown', () async {
      await repository.saveRawConfig(
        diverId,
        'card_test',
        jsonEncode({
          'slots': [
            {'slotId': 'title', 'field': 'fieldFromTheFuture'},
          ],
          'extraFields': <String>[],
        }),
      );
      final notifier = _makeNotifier();
      addTearDown(notifier.dispose);

      await notifier.init(repository, diverId, 'card_test');

      expect(notifier.state, _defaultConfig);
    });

    test('a mutation is persisted after the debounce', () async {
      final notifier = _makeNotifier();
      addTearDown(notifier.dispose);
      await notifier.init(repository, diverId, 'card_test');

      notifier.setSlotField('title', TestField.fieldB);
      await Future<void>.delayed(const Duration(milliseconds: 700));

      final json = await repository.getRawConfig(diverId, 'card_test');
      final reloaded = EntityCardViewConfig.fromJson<TestField>(
        jsonDecode(json!) as Map<String, dynamic>,
        _fieldFromName,
      );
      expect(reloaded.slots.first.field, TestField.fieldB);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/shared/providers/entity_card_config_notifier_test.dart`
Expected: FAIL to compile, "Target of URI doesn't exist ... entity_card_config_providers.dart".

- [ ] **Step 3: Implement the notifier**

Create `lib/shared/providers/entity_card_config_providers.dart`:

```dart
import 'dart:async';
import 'dart:convert';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/repositories/view_config_repository.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';

/// Generic StateNotifier that manages in-memory [EntityCardViewConfig] state
/// and debounces persistence to the database.
///
/// The card sibling of [EntityTableConfigNotifier]: each entity type creates
/// one provider per card mode (detailed, compact) with its own storage key,
/// for example `card_detailed_sites`.
class EntityCardConfigNotifier<F extends EntityField>
    extends StateNotifier<EntityCardViewConfig<F>> {
  static final _log = LoggerService.forClass(EntityCardConfigNotifier);

  ViewConfigRepository? _repository;
  String? _diverId;
  String? _storageKey;
  final EntityCardViewConfig<F> _defaultConfig;
  final F Function(String) _fieldFromName;
  Timer? _saveTimer;

  EntityCardConfigNotifier({
    required EntityCardViewConfig<F> defaultConfig,
    required F Function(String) fieldFromName,
  }) : _defaultConfig = defaultConfig,
       _fieldFromName = fieldFromName,
       super(defaultConfig);

  /// Load the saved config for [diverId] under [storageKey].
  ///
  /// A saved layout that names a field this build does not know (a layout
  /// written by a newer build) is ignored rather than thrown, so the list
  /// still renders with the default slots.
  Future<void> init(
    ViewConfigRepository repository,
    String diverId,
    String storageKey,
  ) async {
    _repository = repository;
    _diverId = diverId;
    _storageKey = storageKey;
    final json = await repository.getRawConfig(diverId, storageKey);
    if (json == null || !mounted) return;
    try {
      state = EntityCardViewConfig.fromJson<F>(
        jsonDecode(json) as Map<String, dynamic>,
        _fieldFromName,
      );
    } catch (e, stackTrace) {
      _log.warning(
        'Ignoring unreadable card config for $storageKey',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Mutations
  // -------------------------------------------------------------------------

  /// Assign [field] to the slot with [slotId]; unknown slot ids are ignored.
  void setSlotField(String slotId, F field) {
    state = state.copyWith(
      slots: state.slots
          .map((s) => s.slotId == slotId ? s.copyWith(field: field) : s)
          .toList(),
    );
    _save();
  }

  void setExtraFields(List<F> fields) {
    state = state.copyWith(extraFields: List<F>.unmodifiable(fields));
    _save();
  }

  void addExtraField(F field) {
    if (state.extraFields.contains(field)) return;
    setExtraFields([...state.extraFields, field]);
  }

  void removeExtraField(F field) {
    setExtraFields(state.extraFields.where((f) => f != field).toList());
  }

  /// Move the extra field at [oldIndex] to [newIndex].
  void reorderExtraFields(int oldIndex, int newIndex) {
    final fields = List<F>.from(state.extraFields);
    final item = fields.removeAt(oldIndex);
    fields.insert(newIndex.clamp(0, fields.length), item);
    setExtraFields(fields);
  }

  /// Replace the whole config; the settings page edits a copy and hands it
  /// back through this.
  void replace(EntityCardViewConfig<F> config) {
    state = config;
    _save();
  }

  void resetToDefault() {
    state = _defaultConfig;
    _save();
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  void _save() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      final repo = _repository;
      final diverId = _diverId;
      final key = _storageKey;
      if (repo != null && diverId != null && key != null) {
        repo.saveRawConfig(diverId, key, jsonEncode(state.toJson()));
      }
    });
  }
}
```

Check the logger signature before relying on it: `grep -n "void warning" -A6 lib/core/services/logger_service.dart` must show named `error` and `stackTrace` parameters (the repositories call `_log.error(..., error: e, stackTrace: stackTrace)` the same way).

- [ ] **Step 4: Run the tests**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/shared/providers/entity_card_config_notifier_test.dart && flutter analyze lib/shared test/shared`
Expected: all PASS, "No issues found!".

- [ ] **Step 5: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
dart format .
git add lib/shared/providers/entity_card_config_providers.dart test/shared/providers/entity_card_config_notifier_test.dart
git commit -m "feat(shared): add persisted EntityCardConfigNotifier"
```

---

### Task 8: Persist the site and buddy card configs and retype the settings section

**Files:**
- Modify: `lib/features/dive_sites/presentation/providers/site_providers.dart:738-766` (the two card config providers)
- Modify: `lib/features/buddies/presentation/providers/buddy_providers.dart:500-534` (the two card config providers)
- Modify: `lib/features/settings/presentation/pages/column_config_page.dart:250-306` and `922-1077`
- Test: `test/features/settings/presentation/pages/column_config_page_test.dart:182-221`
- Test: `test/features/dive_sites/presentation/providers/site_providers_test.dart` (new group)

**Interfaces:**
- Consumes: `EntityCardConfigNotifier<F>` (Task 7), `SiteField.depthRange/lastDived/maxDepthReached` (Task 5), `BuddyField.lastDive` (Task 6).
- Produces: `siteDetailedCardConfigProvider`, `siteCompactCardConfigProvider`, `buddyDetailedCardConfigProvider`, `buddyCompactCardConfigProvider` as `StateNotifierProvider<EntityCardConfigNotifier<F>, EntityCardViewConfig<F>>`; storage keys `card_detailed_sites`, `card_compact_sites`, `card_detailed_buddies`, `card_compact_buddies`. `_EntityCardConfigSection<F>` takes `ProviderListenable<EntityCardViewConfig<F>> configProvider` and `void Function(WidgetRef ref, EntityCardViewConfig<F> config) onChanged`.

- [ ] **Step 1: Write the failing provider test**

Append a group to `test/features/dive_sites/presentation/providers/site_providers_test.dart` (it already sets up the test database in `setUp`; add the imports `package:submersion/shared/providers/entity_card_config_providers.dart` and `package:submersion/features/dive_sites/domain/constants/site_field.dart` if missing):

```dart
  group('site card config providers', () {
    test('detailed config defaults to the enriched slots', () {
      final container = ProviderContainer(
        overrides: [
          currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final config = container.read(siteDetailedCardConfigProvider);
      final slotFields = {for (final s in config.slots) s.slotId: s.field};

      expect(slotFields, {
        'title': SiteField.siteName,
        'subtitle': SiteField.location,
        'stat1': SiteField.depthRange,
        'stat2': SiteField.diveCount,
      });
      expect(config.extraFields, [SiteField.lastDived, SiteField.maxDepthReached]);
      expect(
        container.read(siteDetailedCardConfigProvider.notifier),
        isA<EntityCardConfigNotifier<SiteField>>(),
      );
    });

    test('compact config defaults to count and depth range stats', () {
      final container = ProviderContainer(
        overrides: [
          currentDiverIdProvider.overrideWith((ref) => MockCurrentDiverIdNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final config = container.read(siteCompactCardConfigProvider);
      final slotFields = {for (final s in config.slots) s.slotId: s.field};

      expect(slotFields['stat1'], SiteField.diveCount);
      expect(slotFields['stat2'], SiteField.depthRange);
      expect(config.extraFields, isEmpty);
    });
  });
```

`MockCurrentDiverIdNotifier` comes from `test/helpers/mock_providers.dart` (its state is null, so `init` is never called and no database is touched).

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/dive_sites/presentation/providers/site_providers_test.dart`
Expected: FAIL ("Expected: ... stat1: SiteField.depthRange" / `isA<EntityCardConfigNotifier>` fails because the provider is still a `StateProvider`).

- [ ] **Step 3: Replace the site providers**

In `lib/features/dive_sites/presentation/providers/site_providers.dart` add the import `import 'package:submersion/shared/providers/entity_card_config_providers.dart';` and replace both `siteDetailedCardConfigProvider` and `siteCompactCardConfigProvider` definitions (the whole "Site Card View Config" section) with:

```dart
// ============================================================================
// Site Card View Config
// ============================================================================

/// Detailed site card slots. Persisted per diver under `card_detailed_sites`.
final siteDetailedCardConfigProvider =
    StateNotifierProvider<
      EntityCardConfigNotifier<SiteField>,
      EntityCardViewConfig<SiteField>
    >((ref) {
      final notifier = EntityCardConfigNotifier<SiteField>(
        defaultConfig: const EntityCardViewConfig<SiteField>(
          slots: [
            EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
            EntityCardSlotConfig(slotId: 'subtitle', field: SiteField.location),
            EntityCardSlotConfig(slotId: 'stat1', field: SiteField.depthRange),
            EntityCardSlotConfig(slotId: 'stat2', field: SiteField.diveCount),
          ],
          extraFields: [SiteField.lastDived, SiteField.maxDepthReached],
        ),
        fieldFromName: SiteFieldAdapter.instance.fieldFromName,
      );
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, 'card_detailed_sites');
      }
      return notifier;
    });

/// Compact site card slots. Persisted per diver under `card_compact_sites`.
final siteCompactCardConfigProvider =
    StateNotifierProvider<
      EntityCardConfigNotifier<SiteField>,
      EntityCardViewConfig<SiteField>
    >((ref) {
      final notifier = EntityCardConfigNotifier<SiteField>(
        defaultConfig: const EntityCardViewConfig<SiteField>(
          slots: [
            EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
            EntityCardSlotConfig(slotId: 'subtitle', field: SiteField.location),
            EntityCardSlotConfig(slotId: 'stat1', field: SiteField.diveCount),
            EntityCardSlotConfig(slotId: 'stat2', field: SiteField.depthRange),
          ],
        ),
        fieldFromName: SiteFieldAdapter.instance.fieldFromName,
      );
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, 'card_compact_sites');
      }
      return notifier;
    });
```

- [ ] **Step 4: Replace the buddy providers**

In `lib/features/buddies/presentation/providers/buddy_providers.dart` add the same import and replace the "Buddy Card View Config" section with:

```dart
// ============================================================================
// Buddy Card View Config
// ============================================================================

/// Detailed buddy card slots. Persisted per diver under
/// `card_detailed_buddies`.
final buddyDetailedCardConfigProvider =
    StateNotifierProvider<
      EntityCardConfigNotifier<BuddyField>,
      EntityCardViewConfig<BuddyField>
    >((ref) {
      final notifier = EntityCardConfigNotifier<BuddyField>(
        defaultConfig: const EntityCardViewConfig<BuddyField>(
          slots: [
            EntityCardSlotConfig(slotId: 'title', field: BuddyField.buddyName),
            EntityCardSlotConfig(slotId: 'subtitle', field: BuddyField.email),
            EntityCardSlotConfig(slotId: 'stat1', field: BuddyField.diveCount),
            EntityCardSlotConfig(slotId: 'stat2', field: BuddyField.lastDive),
          ],
        ),
        fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
      );
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, 'card_detailed_buddies');
      }
      return notifier;
    });

/// Compact buddy card slots. Persisted per diver under `card_compact_buddies`.
final buddyCompactCardConfigProvider =
    StateNotifierProvider<
      EntityCardConfigNotifier<BuddyField>,
      EntityCardViewConfig<BuddyField>
    >((ref) {
      final notifier = EntityCardConfigNotifier<BuddyField>(
        defaultConfig: const EntityCardViewConfig<BuddyField>(
          slots: [
            EntityCardSlotConfig(slotId: 'title', field: BuddyField.buddyName),
            EntityCardSlotConfig(
              slotId: 'subtitle',
              field: BuddyField.certificationLevel,
            ),
            EntityCardSlotConfig(slotId: 'stat1', field: BuddyField.diveCount),
            EntityCardSlotConfig(slotId: 'stat2', field: BuddyField.lastDive),
          ],
        ),
        fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
      );
      final diverId = ref.watch(currentDiverIdProvider);
      if (diverId != null) {
        final repo = ref.watch(viewConfigRepositoryProvider);
        notifier.init(repo, diverId, 'card_compact_buddies');
      }
      return notifier;
    });
```

- [ ] **Step 5: Retype the settings section**

In `lib/features/settings/presentation/pages/column_config_page.dart`:

1. In `_EntityCardConfigSection<F>` replace the field and constructor:

```dart
class _EntityCardConfigSection<F extends EntityField> extends ConsumerWidget {
  /// Read source. A `StateProvider` for the entities whose card config is
  /// still in-memory, a `StateNotifierProvider` for the persisted ones.
  final ProviderListenable<EntityCardViewConfig<F>> configProvider;

  /// Write sink; the section edits a copy and hands it back here.
  final void Function(WidgetRef ref, EntityCardViewConfig<F> config) onChanged;
  final List<F> allFields;
  final Map<String, List<F>> fieldsByCategory;
  final bool showExtraFields;

  const _EntityCardConfigSection({
    required this.configProvider,
    required this.onChanged,
    required this.allFields,
    required this.fieldsByCategory,
    required this.showExtraFields,
  });
```

2. Replace each of the three `ref.read(configProvider.notifier).state = config.copyWith(...)` statements in that class (slot dropdown, remove-extra button, add-extra button) with `onChanged(ref, config.copyWith(...))`, keeping the `copyWith` argument unchanged.

3. In `_buildEntityCardSection`, the `'sites'` and `'buddies'` arms become:

```dart
      'sites' => _EntityCardConfigSection<SiteField>(
        configProvider: detailed
            ? siteDetailedCardConfigProvider
            : siteCompactCardConfigProvider,
        onChanged: (ref, config) => ref
            .read(
              (detailed
                      ? siteDetailedCardConfigProvider
                      : siteCompactCardConfigProvider)
                  .notifier,
            )
            .replace(config),
        allFields: SiteField.values,
        fieldsByCategory: SiteFieldAdapter.instance.fieldsByCategory,
        showExtraFields: detailed,
      ),
      'buddies' => _EntityCardConfigSection<BuddyField>(
        configProvider: detailed
            ? buddyDetailedCardConfigProvider
            : buddyCompactCardConfigProvider,
        onChanged: (ref, config) => ref
            .read(
              (detailed
                      ? buddyDetailedCardConfigProvider
                      : buddyCompactCardConfigProvider)
                  .notifier,
            )
            .replace(config),
        allFields: BuddyField.values,
        fieldsByCategory: BuddyFieldAdapter.instance.fieldsByCategory,
        showExtraFields: detailed,
      ),
```

and the `'trips'`, `'equipment'`, `'diveCenters'` arms each gain

```dart
        onChanged: (ref, config) => ref
            .read(
              (detailed
                      ? tripDetailedCardConfigProvider
                      : tripCompactCardConfigProvider)
                  .notifier,
            )
            .state = config,
```

(with `equipment...` / `diveCenter...` provider names respectively), while `'certifications'` and `'courses'` gain `onChanged: (ref, config) => ref.read(certificationDetailedCardConfigProvider.notifier).state = config,` and the `course...` equivalent.

4. Add the import `import 'package:submersion/shared/providers/entity_card_config_providers.dart';` only if the analyzer asks for it (the page only names the providers, not the notifier type).

- [ ] **Step 6: Update the settings page test overrides**

In `test/features/settings/presentation/pages/column_config_page_test.dart` add the imports `package:submersion/shared/providers/entity_card_config_providers.dart` and, replace the four site/buddy overrides (lines 182-221) with:

```dart
      // Entity card config providers for detailed / compact card sections.
      // Sites and buddies are persisted notifiers now; the test never sets a
      // diver id, so init() is not called and nothing touches the database.
      buddyDetailedCardConfigProvider.overrideWith(
        (ref) => EntityCardConfigNotifier<BuddyField>(
          defaultConfig:
              buddyDetailedConfig ??
              const EntityCardViewConfig<BuddyField>(
                slots: [
                  EntityCardSlotConfig(
                    slotId: 'title',
                    field: BuddyField.buddyName,
                  ),
                  EntityCardSlotConfig(
                    slotId: 'subtitle',
                    field: BuddyField.email,
                  ),
                ],
              ),
          fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
        ),
      ),
      buddyCompactCardConfigProvider.overrideWith(
        (ref) => EntityCardConfigNotifier<BuddyField>(
          defaultConfig: const EntityCardViewConfig<BuddyField>(
            slots: [
              EntityCardSlotConfig(slotId: 'title', field: BuddyField.buddyName),
              EntityCardSlotConfig(slotId: 'subtitle', field: BuddyField.email),
            ],
          ),
          fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
        ),
      ),
      siteDetailedCardConfigProvider.overrideWith(
        (ref) => EntityCardConfigNotifier<SiteField>(
          defaultConfig: const EntityCardViewConfig<SiteField>(
            slots: [
              EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
              EntityCardSlotConfig(slotId: 'subtitle', field: SiteField.country),
            ],
          ),
          fieldFromName: SiteFieldAdapter.instance.fieldFromName,
        ),
      ),
      siteCompactCardConfigProvider.overrideWith(
        (ref) => EntityCardConfigNotifier<SiteField>(
          defaultConfig: const EntityCardViewConfig<SiteField>(
            slots: [
              EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
              EntityCardSlotConfig(slotId: 'subtitle', field: SiteField.country),
            ],
          ),
          fieldFromName: SiteFieldAdapter.instance.fieldFromName,
        ),
      ),
```

If a test in that file reads a site/buddy config back with `ref.read(x.notifier).state`, it still compiles (`StateNotifier.state` is readable); if it assigns to it, switch the assignment to `.replace(...)`.

- [ ] **Step 7: Run the tests and analyzer**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/dive_sites/presentation/providers/site_providers_test.dart test/features/buddies/presentation/providers/ test/features/settings/presentation/pages/column_config_page_test.dart && flutter analyze lib/features/settings lib/features/dive_sites lib/features/buddies test/features/settings`
Expected: all PASS, "No issues found!".

- [ ] **Step 8: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
dart format .
git add lib/features/dive_sites lib/features/buddies lib/features/settings test/features/dive_sites test/features/settings
git commit -m "feat(settings): persist site and buddy card slot configs per diver"
```

---

### Task 9: Shared card slot renderer

**Files:**
- Create: `lib/shared/widgets/entity_card/card_slot_resolver.dart`
- Create: `lib/shared/widgets/entity_card/entity_card_stat.dart`
- Create: `lib/shared/widgets/entity_card/entity_card_extra_fields.dart`
- Test: `test/shared/widgets/entity_card/entity_card_widgets_test.dart`

**Interfaces:**
- Consumes: `EntityFieldAdapter<T, F>`, `EntityField`, `EntityCardSlotConfig<F>`, `UnitFormatter`.
- Produces:
  - `F resolveCardSlot<F extends EntityField>(List<EntityCardSlotConfig<F>> slots, String slotId, F fallback)`
  - `class EntityCardStat<T, F extends EntityField> extends StatelessWidget` with `({required EntityFieldAdapter<T, F> adapter, required T entity, required F field, required UnitFormatter units, required Color color, String Function(F field, dynamic value)? formatter})`; renders nothing when the extracted value is null.
  - `class EntityCardExtraFields<T, F extends EntityField> extends StatelessWidget` with `({required EntityFieldAdapter<T, F> adapter, required T entity, required List<F> fields, required UnitFormatter units, required Color labelColor, required Color valueColor})`; skips null values; two columns, one under 250 px.

- [ ] **Step 1: Write the failing tests**

Create `test/shared/widgets/entity_card/entity_card_widgets_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/widgets/entity_card/card_slot_resolver.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_extra_fields.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_stat.dart';

import '../../../helpers/test_app.dart';

typedef _Entity = ({String name, double? depth});

enum _Field implements EntityField {
  title,
  depth;

  @override
  String get name => toString().split('.').last;
  @override
  String get displayName => name;
  @override
  String get shortLabel => this == _Field.title ? 'Name' : 'Depth';
  @override
  IconData? get icon => this == _Field.depth ? Icons.water : null;
  @override
  double get defaultWidth => 100;
  @override
  double get minWidth => 50;
  @override
  bool get sortable => false;
  @override
  String get categoryName => 'test';
  @override
  String localizedDisplayName(AppLocalizations l10n) => shortLabel;
  @override
  String localizedShortLabel(AppLocalizations l10n) => shortLabel;
  @override
  bool get isRightAligned => false;
}

class _Adapter extends EntityFieldAdapter<_Entity, _Field> {
  @override
  List<_Field> get allFields => _Field.values;
  @override
  Map<String, List<_Field>> get fieldsByCategory => {'test': _Field.values};
  @override
  dynamic extractValue(_Field field, _Entity entity) => switch (field) {
    _Field.title => entity.name,
    _Field.depth => entity.depth,
  };
  @override
  String formatValue(_Field field, dynamic value, UnitFormatter units) =>
      switch (field) {
        _Field.title => value as String,
        _Field.depth => units.formatDepth(value as double, decimals: 0),
      };
  @override
  _Field fieldFromName(String name) =>
      _Field.values.firstWhere((f) => f.name == name);
}

void main() {
  const units = UnitFormatter(AppSettings());
  final adapter = _Adapter();

  group('resolveCardSlot', () {
    test('returns the configured field or the fallback', () {
      const slots = [
        EntityCardSlotConfig(slotId: 'stat1', field: _Field.depth),
      ];
      expect(resolveCardSlot(slots, 'stat1', _Field.title), _Field.depth);
      expect(resolveCardSlot(slots, 'stat2', _Field.title), _Field.title);
    });
  });

  group('EntityCardStat', () {
    testWidgets('renders icon and formatted value', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: EntityCardStat<_Entity, _Field>(
            adapter: adapter,
            entity: (name: 'Reef', depth: 18.0),
            field: _Field.depth,
            units: units,
            color: Colors.black,
          ),
        ),
      );

      expect(find.byIcon(Icons.water), findsOneWidget);
      expect(find.text('18m'), findsOneWidget);
    });

    testWidgets('renders nothing for a null value', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: EntityCardStat<_Entity, _Field>(
            adapter: adapter,
            entity: (name: 'Reef', depth: null),
            field: _Field.depth,
            units: units,
            color: Colors.black,
          ),
        ),
      );

      expect(find.byIcon(Icons.water), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('a formatter override replaces the adapter formatting', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: EntityCardStat<_Entity, _Field>(
            adapter: adapter,
            entity: (name: 'Reef', depth: 18.0),
            field: _Field.depth,
            units: units,
            color: Colors.black,
            formatter: (field, value) => 'deep',
          ),
        ),
      );

      expect(find.text('deep'), findsOneWidget);
    });
  });

  group('EntityCardExtraFields', () {
    testWidgets('renders label: value pairs and skips nulls', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: EntityCardExtraFields<_Entity, _Field>(
            adapter: adapter,
            entity: (name: 'Reef', depth: null),
            fields: const [_Field.title, _Field.depth],
            units: units,
            labelColor: Colors.grey,
            valueColor: Colors.black,
          ),
        ),
      );

      expect(find.text('Name: '), findsOneWidget);
      expect(find.text('Reef'), findsOneWidget);
      expect(find.text('Depth: '), findsNothing);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/shared/widgets/entity_card/entity_card_widgets_test.dart`
Expected: FAIL to compile, "Target of URI doesn't exist ... card_slot_resolver.dart".

- [ ] **Step 3: Implement the three files**

`lib/shared/widgets/entity_card/card_slot_resolver.dart`:

```dart
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';

/// The field configured for [slotId], or [fallback] when the saved config
/// has no such slot (an older layout, or a slot this card added later).
F resolveCardSlot<F extends EntityField>(
  List<EntityCardSlotConfig<F>> slots,
  String slotId,
  F fallback,
) {
  for (final slot in slots) {
    if (slot.slotId == slotId) return slot.field;
  }
  return fallback;
}
```

`lib/shared/widgets/entity_card/entity_card_stat.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// One icon + value stat on a list card, resolved through the entity's
/// field adapter so any configurable field renders the same way.
///
/// Renders nothing when the field has no value, so a card never shows a
/// dangling "--" for a stat that does not apply (a site never dived, a
/// buddy with no last dive).
class EntityCardStat<T, F extends EntityField> extends StatelessWidget {
  final EntityFieldAdapter<T, F> adapter;
  final T entity;
  final F field;
  final UnitFormatter units;
  final Color color;

  /// Optional replacement for [EntityFieldAdapter.formatValue], for stats
  /// whose card rendering needs a plural or other l10n the adapter cannot
  /// reach ("14 dives" rather than "14").
  final String Function(F field, dynamic value)? formatter;

  const EntityCardStat({
    super.key,
    required this.adapter,
    required this.entity,
    required this.field,
    required this.units,
    required this.color,
    this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final value = adapter.extractValue(field, entity);
    if (value == null) return const SizedBox.shrink();
    final formatted =
        formatter?.call(field, value) ??
        adapter.formatValue(field, value, units);
    final style = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, color: color);
    final icon = field.icon;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          ExcludeSemantics(child: Icon(icon, size: 14, color: color)),
          const SizedBox(width: 4),
        ],
        Text(formatted, style: style),
      ],
    );
  }
}
```

`lib/shared/widgets/entity_card/entity_card_extra_fields.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// The configurable "extra fields" grid under a detailed list card: a
/// two-column wrap of `label: value` pairs (one column under 250 px), the
/// same shape the dive card uses. Fields without a value are skipped.
class EntityCardExtraFields<T, F extends EntityField> extends StatelessWidget {
  final EntityFieldAdapter<T, F> adapter;
  final T entity;
  final List<F> fields;
  final UnitFormatter units;
  final Color labelColor;
  final Color valueColor;

  const EntityCardExtraFields({
    super.key,
    required this.adapter,
    required this.entity,
    required this.fields,
    required this.units,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final entries = <(F, String)>[];
    for (final field in fields) {
      final value = adapter.extractValue(field, entity);
      if (value == null) continue;
      entries.add((field, adapter.formatValue(field, value, units)));
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final useOneColumn = constraints.maxWidth < 250;
        final width = useOneColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final (field, formatted) in entries)
              SizedBox(
                width: width,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${field.localizedShortLabel(context.l10n)}: ',
                      style: TextStyle(
                        fontSize: 11,
                        color: labelColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Flexible(
                      child: Text(
                        formatted,
                        style: TextStyle(fontSize: 11, color: valueColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run the tests and analyzer**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/shared/widgets/entity_card/ && flutter analyze lib/shared test/shared`
Expected: all PASS, "No issues found!".

- [ ] **Step 5: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
dart format .
git add lib/shared/widgets/entity_card test/shared/widgets/entity_card
git commit -m "feat(shared): add EntityCardStat and EntityCardExtraFields slot renderers"
```

---

### Task 10: Detailed site card

**Files:**
- Create: `lib/features/dive_sites/presentation/site_difficulty_display.dart`
- Create: `lib/features/dive_sites/presentation/widgets/site_list_tile.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (delete the old `SiteListTile` class at the end of the file, update the two call sites at lines ~892 and ~1224, drop unused imports)
- Modify: `test/features/dive_sites/presentation/widgets/site_list_content_test.dart:855-877`, `test/features/osm_tile_user_agent_test.dart:101-127`
- Test: `test/features/dive_sites/presentation/site_difficulty_display_test.dart`, `test/features/dive_sites/presentation/widgets/site_list_tile_test.dart`

**Interfaces:**
- Consumes: `SiteWithDiveCount` (Task 1), `SiteField` statistics values (Task 5), `siteDetailedCardConfigProvider` (Task 8), `resolveCardSlot`, `EntityCardStat`, `EntityCardExtraFields` (Task 9), `SiteFeatureGlyph.styleFor` (`lib/features/site_scape/presentation/site_feature_glyph.dart`), `siteFeatureTypeLabel` (`lib/features/site_scape/presentation/site_feature_sheet.dart`), `WaterTypeDisplay.localizedName` (`lib/features/dive_log/presentation/widgets/environment_enum_display.dart`), `resolveFeatureAccent` (`lib/shared/widgets/feature_accent.dart`).
- Produces: `extension SiteDifficultyDisplay on SiteDifficulty { String localizedName(AppLocalizations l10n); }`; `class SiteListTile extends ConsumerStatefulWidget` with `SiteListTile({Key? key, required SiteWithDiveCount entry, VoidCallback? onTap, bool isSelectionMode = false, bool isSelected = false, bool isChecked = false, bool showSharedBadge = false})` and a `String get name` convenience getter.

- [ ] **Step 1: Write the failing difficulty-label test**

Create `test/features/dive_sites/presentation/site_difficulty_display_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('every difficulty has an English label', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(SiteDifficulty.beginner.localizedName(l10n), 'Beginner');
    expect(SiteDifficulty.intermediate.localizedName(l10n), 'Intermediate');
    expect(SiteDifficulty.advanced.localizedName(l10n), 'Advanced');
    expect(SiteDifficulty.technical.localizedName(l10n), 'Technical');
  });
}
```

- [ ] **Step 2: Run it to verify it fails, then implement**

Run: `flutter test test/features/dive_sites/presentation/site_difficulty_display_test.dart`
Expected: FAIL to compile (missing file).

Create `lib/features/dive_sites/presentation/site_difficulty_display.dart`:

```dart
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized labels for [SiteDifficulty]. The enum's own `displayName`
/// stays English on purpose (exports, stored configs); UI goes through this.
extension SiteDifficultyDisplay on SiteDifficulty {
  String localizedName(AppLocalizations l10n) => switch (this) {
    SiteDifficulty.beginner => l10n.diveSites_difficulty_beginner,
    SiteDifficulty.intermediate => l10n.diveSites_difficulty_intermediate,
    SiteDifficulty.advanced => l10n.diveSites_difficulty_advanced,
    SiteDifficulty.technical => l10n.diveSites_difficulty_technical,
  };
}
```

Re-run the test. Expected: PASS.

- [ ] **Step 3: Write the failing tile tests**

Create `test/features/dive_sites/presentation/widgets/site_list_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _defaultConfig = EntityCardViewConfig<SiteField>(
  slots: [
    EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
    EntityCardSlotConfig(slotId: 'subtitle', field: SiteField.location),
    EntityCardSlotConfig(slotId: 'stat1', field: SiteField.depthRange),
    EntityCardSlotConfig(slotId: 'stat2', field: SiteField.diveCount),
  ],
  extraFields: [SiteField.lastDived, SiteField.maxDepthReached],
);

Future<List<dynamic>> _overrides({
  EntityCardViewConfig<SiteField> config = _defaultConfig,
  bool mapBackground = false,
}) async => [
  ...await getBaseOverrides(),
  siteDetailedCardConfigProvider.overrideWith(
    (ref) => EntityCardConfigNotifier<SiteField>(
      defaultConfig: config,
      fieldFromName: SiteFieldAdapter.instance.fieldFromName,
    ),
  ),
  showMapBackgroundOnSiteCardsProvider.overrideWithValue(mapBackground),
];

final _richEntry = SiteWithDiveCount(
  site: const DiveSite(
    id: 'site-1',
    name: 'Blue Hole',
    country: 'Egypt',
    region: 'South Sinai',
    city: 'Dahab',
    minDepth: 5,
    maxDepth: 50,
    difficulty: SiteDifficulty.advanced,
    waterType: WaterType.salt,
    rating: 4.5,
  ),
  diveCount: 14,
  lastDivedAt: DateTime(2024, 3, 5),
  maxDepthReached: 31.5,
  featureTypes: const ['wreck', 'mooring'],
);

const _bareEntry = SiteWithDiveCount(
  site: DiveSite(id: 'site-2', name: 'Unknown Reef'),
  diveCount: 0,
);

void main() {
  testWidgets('renders slots, rating, chips and extra fields', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        locale: const Locale('en'),
        child: SiteListTile(entry: _richEntry, onTap: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('Blue Hole'), findsOneWidget);
    expect(find.text('Dahab · South Sinai, Egypt'), findsOneWidget);
    expect(find.text('5-50m'), findsOneWidget);
    expect(find.text('14 dives'), findsOneWidget);
    expect(find.text('4.5'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    expect(find.text('Salt Water'), findsOneWidget);
    expect(find.text('Wreck'), findsOneWidget);
    expect(find.text('Mooring'), findsOneWidget);
    expect(find.text('Last dived: '), findsOneWidget);
    expect(find.text('Your max: '), findsOneWidget);
    expect(find.text('32m'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('hides stats, chips and extras that have no value', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        locale: const Locale('en'),
        child: SiteListTile(entry: _bareEntry, onTap: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('Unknown Reef'), findsOneWidget);
    expect(find.textContaining('dives'), findsNothing);
    expect(find.textContaining('Last dived'), findsNothing);
    expect(find.textContaining('--'), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('honours a reconfigured stat slot', (tester) async {
    const config = EntityCardViewConfig<SiteField>(
      slots: [
        EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
        EntityCardSlotConfig(slotId: 'subtitle', field: SiteField.country),
        EntityCardSlotConfig(slotId: 'stat1', field: SiteField.maxDepthReached),
        EntityCardSlotConfig(slotId: 'stat2', field: SiteField.rating),
      ],
    );
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(config: config),
        locale: const Locale('en'),
        child: SiteListTile(entry: _richEntry, onTap: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('Egypt'), findsOneWidget);
    expect(find.text('32m'), findsOneWidget);
    expect(find.text('5-50m'), findsNothing);
  });

  testWidgets('shows a checkbox in selection mode', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        child: SiteListTile(
          entry: _richEntry,
          isSelectionMode: true,
          isChecked: true,
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Checkbox), findsOneWidget);
  });

  testWidgets('renders a FlutterMap background for a located site', (
    tester,
  ) async {
    final located = SiteWithDiveCount(
      site: const DiveSite(
        id: 'site-3',
        name: 'Located Reef',
        location: GeoPoint(17.3155, -87.5346),
      ),
      diveCount: 0,
    );
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(mapBackground: true),
        child: SiteListTile(entry: located, onTap: () {}),
      ),
    );
    await tester.pump();

    expect(find.byType(FlutterMap), findsWidgets);
    expect(find.text('Located Reef'), findsOneWidget);
  });
}
```

`'Dahab · South Sinai, Egypt'` is what `DiveSite.locationString` produces for city + region + country (see `dive_site.dart:98-118`); if the separator in that getter differs, copy its exact output rather than changing the getter.

- [ ] **Step 4: Run the tile tests to verify they fail**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/dive_sites/presentation/widgets/site_list_tile_test.dart`
Expected: FAIL to compile (missing `site_list_tile.dart`).

- [ ] **Step 5: Create the tile**

Create `lib/features/dive_sites/presentation/widgets/site_list_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/site_difficulty_display.dart';
import 'package:submersion/features/maps/data/services/tile_cache_service.dart';
import 'package:submersion/features/maps/presentation/providers/map_tile_providers.dart';
import 'package:submersion/features/maps/presentation/widgets/map_attribution.dart';
import 'package:submersion/features/maps/presentation/widgets/trackpad_zoom_map.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_glyph.dart';
import 'package:submersion/features/site_scape/presentation/site_feature_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/shared/widgets/entity_card/card_slot_resolver.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_extra_fields.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_stat.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// Detailed list card for one dive site.
///
/// Configurable slots (title, subtitle, stat1, stat2, extra fields) come from
/// [siteDetailedCardConfigProvider]; the rating, shared badge, difficulty,
/// water type and feature chips are fixed identity elements. Hand-rolled
/// rather than a ListTile so the title keeps its font role under every theme
/// preset and nothing text-bearing sits in the trailing slot.
class SiteListTile extends ConsumerStatefulWidget {
  final SiteWithDiveCount entry;
  final VoidCallback? onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isChecked;
  final bool showSharedBadge;

  const SiteListTile({
    super.key,
    required this.entry,
    this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isChecked = false,
    this.showSharedBadge = false,
  });

  String get name => entry.site.name;

  @override
  ConsumerState<SiteListTile> createState() => _SiteListTileState();
}

class _SiteListTileState extends ConsumerState<SiteListTile> {
  final MapController _mapController = MapController();

  static const _contentInset = 52.0;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final site = entry.site;
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final config = ref.watch(siteDetailedCardConfigProvider);
    final accent = resolveFeatureAccent(
      context,
      ref,
      surface: AccentSurface.list,
      featureId: 'sites',
    );

    final showMapBackground = ref.watch(showMapBackgroundOnSiteCardsProvider);
    final location = site.location;
    final shouldShowMap =
        showMapBackground &&
        location != null &&
        !widget.isSelected &&
        !widget.isChecked;
    final primaryTextColor = shouldShowMap ? Colors.white : null;
    final secondaryTextColor = shouldShowMap
        ? Colors.white70
        : colorScheme.onSurfaceVariant;
    final statColor = shouldShowMap
        ? Colors.white
        : (accent ?? colorScheme.primary);

    final adapter = SiteFieldAdapter.instance;
    final slots = config.slots;
    final titleField = resolveCardSlot(slots, 'title', SiteField.siteName);
    final subtitleField = resolveCardSlot(
      slots,
      'subtitle',
      SiteField.location,
    );
    final stat1Field = resolveCardSlot(slots, 'stat1', SiteField.depthRange);
    final stat2Field = resolveCardSlot(slots, 'stat2', SiteField.diveCount);

    String? slotText(SiteField field) {
      final value = adapter.extractValue(field, entry);
      if (value == null) return null;
      final text = adapter.formatValue(field, value, units);
      return text.isEmpty ? null : text;
    }

    final title = slotText(titleField) ?? site.name;
    final subtitle = slotText(subtitleField);

    String formatStat(SiteField field, dynamic value) {
      if (field == SiteField.diveCount) {
        return l10n.diveSites_list_tile_diveCount(value as int);
      }
      return adapter.formatValue(field, value, units);
    }

    Widget stat(SiteField field) {
      // A count of zero reads as noise on a card; the site simply has no
      // dives yet, which the missing "Last dived" already says.
      if (field == SiteField.diveCount && entry.diveCount == 0) {
        return const SizedBox.shrink();
      }
      return EntityCardStat<SiteWithDiveCount, SiteField>(
        adapter: adapter,
        entity: entry,
        field: field,
        units: units,
        color: statColor,
        formatter: formatStat,
      );
    }

    final chips = <Widget>[
      if (site.difficulty != null)
        _SiteChip(
          icon: Icons.signal_cellular_alt,
          label: site.difficulty!.localizedName(l10n),
          color: statColor,
          textColor: primaryTextColor ?? colorScheme.onSurface,
        ),
      if (site.waterType != null)
        _SiteChip(
          icon: Icons.water_drop,
          label: site.waterType!.localizedName(l10n),
          color: statColor,
          textColor: primaryTextColor ?? colorScheme.onSurface,
        ),
      for (final typeName in entry.featureTypes)
        _SiteChip(
          icon: SiteFeatureGlyph.styleFor(typeName).$1,
          label: siteFeatureTypeLabel(l10n, typeName),
          color: SiteFeatureGlyph.styleFor(typeName).$2,
          textColor: primaryTextColor ?? colorScheme.onSurface,
        ),
    ];

    Widget buildContent() {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SelectionLeading(
                      isSelectionMode: widget.isSelectionMode,
                      isChecked: widget.isChecked,
                      onChanged: (_) => widget.onTap?.call(),
                      child: CircleAvatar(
                        backgroundColor:
                            accent?.withValues(alpha: 0.15) ??
                            colorScheme.secondaryContainer,
                        child: Icon(
                          Icons.location_on,
                          color: accent ?? colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: primaryTextColor,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (site.rating != null) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              site.rating!.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: primaryTextColor),
                            ),
                          ],
                          if (widget.showSharedBadge) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message:
                                  l10n.accessibility_label_sharedWithAllProfiles,
                              child: Icon(
                                Icons.people_outline,
                                size: 16,
                                color: primaryTextColor ?? colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: secondaryTextColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!widget.isSelectionMode)
                  ExcludeSemantics(
                    child: Icon(Icons.chevron_right, color: secondaryTextColor),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: _contentInset),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 6,
                children: [stat(stat1Field), stat(stat2Field)],
              ),
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: _contentInset),
                child: Wrap(spacing: 6, runSpacing: 4, children: chips),
              ),
            ],
            if (config.extraFields.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: _contentInset),
                child: EntityCardExtraFields<SiteWithDiveCount, SiteField>(
                  adapter: adapter,
                  entity: entry,
                  fields: config.extraFields,
                  units: units,
                  labelColor: secondaryTextColor,
                  valueColor: primaryTextColor ?? colorScheme.onSurface,
                ),
              ),
            ],
          ],
        ),
      );
    }

    final semanticsLabel = [
      l10n.diveSites_list_tile_semantics(site.name),
      if (subtitle != null) subtitle,
      if (entry.diveCount > 0)
        l10n.diveSites_list_tile_diveCount(entry.diveCount),
    ].join(', ');

    if (shouldShowMap) {
      final siteLocation = LatLng(location.latitude, location.longitude);
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          button: true,
          selected: widget.isSelected,
          label: semanticsLabel,
          child: InkWell(
            onTap: widget.onTap,
            child: Stack(
              children: [
                Positioned.fill(
                  child: TrackpadZoomMap(
                    controller: _mapController,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: siteLocation,
                        initialZoom: 13.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: ref.watch(mapTileUrlProvider),
                          userAgentPackageName: 'app.submersion',
                          maxZoom: ref.watch(mapTileMaxZoomProvider),
                          tileProvider: TileCacheService.instance.isInitialized
                              ? TileCacheService.instance.getTileProvider()
                              : null,
                        ),
                        const MapAttribution(),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.3, 0.7, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.black.withValues(alpha: 0.5),
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                buildContent(),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: widget.isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
          : widget.isChecked
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Semantics(
        button: true,
        selected: widget.isSelected,
        label: semanticsLabel,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: buildContent(),
        ),
      ),
    );
  }
}

/// A small outlined chip with an icon, used for the fixed identity row
/// (difficulty, water type, site features).
class _SiteChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  const _SiteChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 12, color: color)),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Delete the old tile and update the two call sites**

In `lib/features/dive_sites/presentation/widgets/site_list_content.dart`:

1. Delete the whole old `SiteListTile` class and its `_SiteListTileState` (from the `/// List item widget for displaying a dive site summary` comment to the end of the file).
2. Add `import 'package:submersion/features/dive_sites/presentation/widgets/site_list_tile.dart';`.
3. In `_buildSiteList`, the `ListViewMode.detailed` arm becomes:

```dart
            ListViewMode.detailed => SiteListTile(
              entry: siteData,
              isSelectionMode: _isSelectionMode,
              isSelected: isSelected,
              isChecked: isChecked,
              showSharedBadge: showSharedBadge,
              onTap: () => _handleRowTap(site.id, sites),
            ),
```

4. In `SiteSearchDelegate._buildSearchResults`, the `return SiteListTile(...)` becomes:

```dart
            return SiteListTile(
              entry: SiteWithDiveCount(site: site, diveCount: 0),
              onTap: () {
                close(context, site);
                context.push('/sites/${site.id}');
              },
            );
```

5. Run `flutter analyze lib/features/dive_sites/presentation/widgets/site_list_content.dart` and delete every import it reports as unused (expected: `flutter_map`, `latlong2`, `tile_cache_service`, `map_tile_providers`, `map_attribution`, `trackpad_zoom_map`, `selection_leading`, `unit_formatter`, possibly `feature_accent`). Keep `locationString` handling for the compact and dense arms untouched.

- [ ] **Step 7: Update the two existing tests that construct SiteListTile**

In `test/features/dive_sites/presentation/widgets/site_list_content_test.dart` (the `'SiteListTile renders a FlutterMap ...'` test), replace the `const SiteListTile(name: 'Blue Hole', location: 'Belize', latitude: 17.3155, longitude: -87.5346)` child with:

```dart
          child: SiteListTile(
            entry: const SiteWithDiveCount(
              site: DiveSite(
                id: 'blue-hole',
                name: 'Blue Hole',
                country: 'Belize',
                location: GeoPoint(17.3155, -87.5346),
              ),
              diveCount: 0,
            ),
          ),
```

and add `import 'package:submersion/features/dive_sites/presentation/widgets/site_list_tile.dart';` (`SiteWithDiveCount` already comes through `site_repository_impl.dart`). In `test/features/osm_tile_user_agent_test.dart` the `SiteListTile(name: 'Blue Hole', latitude: 17.3161, longitude: -87.5347, diveCount: 5)` becomes:

```dart
              body: SiteListTile(
                entry: SiteWithDiveCount(
                  site: DiveSite(
                    id: 'blue-hole',
                    name: 'Blue Hole',
                    location: GeoPoint(17.3161, -87.5347),
                  ),
                  diveCount: 5,
                ),
              ),
```

(drop the `const` on the enclosing `MaterialApp`/`Scaffold` if the analyzer complains) with imports for `site_list_tile.dart`, `site_with_dive_count.dart` and `dive_site.dart`.

- [ ] **Step 8: Run the tests and analyzer**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/dive_sites/presentation/ test/features/osm_tile_user_agent_test.dart && flutter analyze lib/features/dive_sites test/features/dive_sites && wc -l lib/features/dive_sites/presentation/widgets/site_list_content.dart lib/features/dive_sites/presentation/widgets/site_list_tile.dart`
Expected: all PASS, "No issues found!", `site_list_content.dart` now under 1300 lines and `site_list_tile.dart` under 450.

If `site_list_content_test.dart`'s detailed-mode tests read `tile.name` from `widgetList<SiteListTile>`, the `name` getter keeps them compiling; if one reads `tile.diveCount`, change it to `tile.entry.diveCount`.

- [ ] **Step 9: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
dart format .
git add lib/features/dive_sites test/features/dive_sites test/features/osm_tile_user_agent_test.dart
git commit -m "feat(sites): enrich the detailed site card with configurable slots, stats and feature chips"
```

---

### Task 11: Compact site card reads its config

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/compact_site_list_tile.dart` (whole file)
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (the `ListViewMode.compact` arm)
- Test: `test/features/dive_sites/presentation/widgets/compact_site_list_tile_test.dart` (rewrite)

**Interfaces:**
- Consumes: `siteCompactCardConfigProvider` (Task 8), `resolveCardSlot`, `EntityCardStat` (Task 9).
- Produces: `class CompactSiteListTile extends ConsumerWidget` with `CompactSiteListTile({Key? key, required SiteWithDiveCount entry, VoidCallback? onTap, bool isSelectionMode = false, bool isSelected = false, bool isHighlighted = false, bool showSharedBadge = false})` and `String get name`.

- [ ] **Step 1: Rewrite the test file**

Replace `test/features/dive_sites/presentation/widgets/compact_site_list_tile_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/compact_site_list_tile.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _config = EntityCardViewConfig<SiteField>(
  slots: [
    EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
    EntityCardSlotConfig(slotId: 'subtitle', field: SiteField.location),
    EntityCardSlotConfig(slotId: 'stat1', field: SiteField.diveCount),
    EntityCardSlotConfig(slotId: 'stat2', field: SiteField.depthRange),
  ],
);

Future<List<dynamic>> _overrides() async => [
  ...await getBaseOverrides(),
  siteCompactCardConfigProvider.overrideWith(
    (ref) => EntityCardConfigNotifier<SiteField>(
      defaultConfig: _config,
      fieldFromName: SiteFieldAdapter.instance.fieldFromName,
    ),
  ),
];

const _entry = SiteWithDiveCount(
  site: DiveSite(
    id: 'site-1',
    name: 'Blue Corner Wall',
    country: 'Micronesia',
    region: 'Palau',
    minDepth: 10,
    maxDepth: 30,
    rating: 4.0,
  ),
  diveCount: 12,
);

void main() {
  group('CompactSiteListTile', () {
    testWidgets('renders title, subtitle, both stats and the rating', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: await _overrides(),
          locale: const Locale('en'),
          child: CompactSiteListTile(entry: _entry, onTap: () {}),
        ),
      );
      await tester.pump();

      expect(find.text('Blue Corner Wall'), findsOneWidget);
      expect(find.text('Palau, Micronesia'), findsOneWidget);
      expect(find.text('12 dives'), findsOneWidget);
      expect(find.text('10-30m'), findsOneWidget);
      expect(find.text('4.0'), findsOneWidget);
    });

    testWidgets('shows checkbox in selection mode', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: await _overrides(),
          child: CompactSiteListTile(
            entry: _entry,
            isSelectionMode: true,
            isSelected: true,
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('handles a bare site gracefully', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: await _overrides(),
          locale: const Locale('en'),
          child: CompactSiteListTile(
            entry: const SiteWithDiveCount(
              site: DiveSite(id: 's', name: 'Unknown Site'),
              diveCount: 0,
            ),
            onTap: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Unknown Site'), findsOneWidget);
      expect(find.textContaining('dives'), findsNothing);
      expect(find.textContaining('--'), findsNothing);
    });
  });
}
```

`'Palau, Micronesia'` is `locationString` for region + country with no city or island; confirm against `dive_site.dart:98-118` and copy its exact output if it differs.

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/dive_sites/presentation/widgets/compact_site_list_tile_test.dart`
Expected: FAIL to compile ("No named parameter with the name 'entry'").

- [ ] **Step 3: Rewrite the compact tile**

Replace `lib/features/dive_sites/presentation/widgets/compact_site_list_tile.dart` with:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_checkbox_slot.dart';
import 'package:submersion/shared/widgets/entity_card/card_slot_resolver.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_stat.dart';

/// Two-line compact card tile for the site list, driven by
/// [siteCompactCardConfigProvider].
///
/// Line 1: title slot | rating | stat1 | chevron
/// Line 2: subtitle slot | stat2
class CompactSiteListTile extends ConsumerWidget {
  final SiteWithDiveCount entry;
  final VoidCallback? onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isHighlighted;
  final bool showSharedBadge;

  const CompactSiteListTile({
    super.key,
    required this.entry,
    this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isHighlighted = false,
    this.showSharedBadge = false,
  });

  String get name => entry.site.name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final slots = ref.watch(siteCompactCardConfigProvider).slots;
    final adapter = SiteFieldAdapter.instance;
    final site = entry.site;
    final cardColor = (isSelected || isHighlighted)
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : null;
    final secondaryTextColor = colorScheme.onSurfaceVariant;

    String? slotText(SiteField field) {
      final value = adapter.extractValue(field, entry);
      if (value == null) return null;
      final text = adapter.formatValue(field, value, units);
      return text.isEmpty ? null : text;
    }

    final title =
        slotText(resolveCardSlot(slots, 'title', SiteField.siteName)) ??
        site.name;
    final subtitle = slotText(
      resolveCardSlot(slots, 'subtitle', SiteField.location),
    );
    final stat2Field = resolveCardSlot(slots, 'stat2', SiteField.depthRange);
    final showSecondLine = subtitle != null || slotText(stat2Field) != null;

    String formatStat(SiteField field, dynamic value) {
      if (field == SiteField.diveCount) {
        return l10n.diveSites_list_tile_diveCount(value as int);
      }
      return adapter.formatValue(field, value, units);
    }

    Widget stat(String slotId, SiteField fallback) {
      final field = resolveCardSlot(slots, slotId, fallback);
      if (field == SiteField.diveCount && entry.diveCount == 0) {
        return const SizedBox.shrink();
      }
      return EntityCardStat<SiteWithDiveCount, SiteField>(
        adapter: adapter,
        entity: entry,
        field: field,
        units: units,
        color: secondaryTextColor,
        formatter: formatStat,
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      color: cardColor,
      child: Semantics(
        button: true,
        selected: isSelected || isHighlighted,
        label: l10n.diveSites_list_tile_semantics(site.name),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                SelectionCheckboxSlot(
                  isSelectionMode: isSelectionMode,
                  isChecked: isSelected,
                  onChanged: (_) => onTap?.call(),
                  gap: 8,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (site.rating != null) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              site.rating!.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (showSharedBadge) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message:
                                  l10n.accessibility_label_sharedWithAllProfiles,
                              child: Icon(
                                Icons.people_outline,
                                size: 16,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                          const SizedBox(width: 8),
                          stat('stat1', SiteField.diveCount),
                          ExcludeSemantics(
                            child: Icon(
                              Icons.chevron_right,
                              color: secondaryTextColor,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      if (showSecondLine) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subtitle ?? '',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: secondaryTextColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            stat('stat2', SiteField.depthRange),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Update the call site**

In `site_list_content.dart` the `ListViewMode.compact` arm becomes:

```dart
            ListViewMode.compact => CompactSiteListTile(
              entry: siteData,
              isSelectionMode: _isSelectionMode,
              isSelected: isChecked,
              isHighlighted: !_isSelectionMode && isSelected,
              showSharedBadge: showSharedBadge,
              onTap: () => _handleRowTap(site.id, sites),
            ),
```

- [ ] **Step 5: Run the tests and analyzer**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/dive_sites/presentation/ && flutter analyze lib/features/dive_sites test/features/dive_sites`
Expected: all PASS, "No issues found!". If a `site_list_content_test.dart` compact-mode test reads `tile.diveCount`, change it to `tile.entry.diveCount`.

- [ ] **Step 6: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
dart format .
git add lib/features/dive_sites test/features/dive_sites
git commit -m "feat(sites): drive the compact site card from its slot config and localize the dive count"
```

---

### Task 12: Detailed buddy card

**Files:**
- Create: `lib/features/buddies/presentation/widgets/buddy_list_tile.dart`
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_content.dart` (delete the old `BuddyListTile` class at lines ~921-1019, update the mode switch, drop unused imports)
- Test: `test/features/buddies/presentation/widgets/buddy_list_tile_test.dart`

**Interfaces:**
- Consumes: `BuddyWithDiveCount` (Task 2), `BuddyField.lastDive` (Task 6), `buddyDetailedCardConfigProvider` (Task 8), `resolveCardSlot`, `EntityCardStat`, `EntityCardExtraFields` (Task 9), `diveRoleMapProvider` (`lib/features/dive_roles/presentation/providers/dive_role_providers.dart`), `DiveRoleDisplay.localizedName` (`lib/features/dive_roles/presentation/dive_role_display.dart`), `DiveRole.buddyId`, `DiveRole.synthetic`.
- Produces: `class BuddyListTile extends ConsumerWidget` with `BuddyListTile({Key? key, required BuddyWithDiveCount entry, bool isSelected = false, bool isChecked = false, bool isSelectionMode = false, VoidCallback? onTap})`, plus `Buddy get buddy` and `int get diveCount` getters.

- [ ] **Step 1: Write the failing tests**

Create `test/features/buddies/presentation/widgets/buddy_list_tile_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_tile.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _config = EntityCardViewConfig<BuddyField>(
  slots: [
    EntityCardSlotConfig(slotId: 'title', field: BuddyField.buddyName),
    EntityCardSlotConfig(slotId: 'subtitle', field: BuddyField.email),
    EntityCardSlotConfig(slotId: 'stat1', field: BuddyField.diveCount),
    EntityCardSlotConfig(slotId: 'stat2', field: BuddyField.lastDive),
  ],
);

final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

Future<List<dynamic>> _overrides({
  EntityCardViewConfig<BuddyField> config = _config,
}) async => [
  ...await getBaseOverrides(),
  buddyDetailedCardConfigProvider.overrideWith(
    (ref) => EntityCardConfigNotifier<BuddyField>(
      defaultConfig: config,
      fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
    ),
  ),
  diveRoleMapProvider.overrideWith(
    (ref) async => {
      DiveRole.instructorId: DiveRole(
        id: DiveRole.instructorId,
        name: 'Instructor',
        isBuiltIn: true,
        createdAt: _epoch,
        updatedAt: _epoch,
      ),
    },
  ),
];

Buddy _buddy({
  String name = 'Jane Doe',
  String? email = 'jane@example.com',
  String? phone = '+1 555 0100',
  String? photoPath,
  CertificationLevel? level = CertificationLevel.rescue,
  CertificationAgency? agency = CertificationAgency.padi,
}) {
  return Buddy(
    id: 'b1',
    name: name,
    email: email,
    phone: phone,
    photoPath: photoPath,
    certificationLevel: level,
    certificationAgency: agency,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  testWidgets('renders slots, cert chip, usual role and contact icons', (
    tester,
  ) async {
    final entry = BuddyWithDiveCount(
      buddy: _buddy(),
      diveCount: 23,
      lastDiveAt: DateTime(2024, 3, 5),
      usualRoleId: DiveRole.instructorId,
    );
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        locale: const Locale('en'),
        child: BuddyListTile(entry: entry, onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('jane@example.com'), findsOneWidget);
    expect(find.text('Rescue Diver · PADI'), findsOneWidget);
    expect(find.text('23 dives'), findsOneWidget);
    expect(find.text('Instructor'), findsOneWidget);
    expect(find.byIcon(Icons.mail_outline), findsOneWidget);
    expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
    expect(find.text('JD'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('hides the usual role for the plain buddy role and empty bits', (
    tester,
  ) async {
    final entry = BuddyWithDiveCount(
      buddy: _buddy(email: null, phone: null, level: null, agency: null),
      diveCount: 0,
      usualRoleId: DiveRole.buddyId,
    );
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        locale: const Locale('en'),
        child: BuddyListTile(entry: entry, onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.byIcon(Icons.badge_outlined), findsNothing);
    expect(find.byIcon(Icons.mail_outline), findsNothing);
    expect(find.byIcon(Icons.phone_outlined), findsNothing);
    expect(find.textContaining('·'), findsNothing);
    expect(find.textContaining('--'), findsNothing);
  });

  testWidgets('loads an existing photo file and falls back to initials', (
    tester,
  ) async {
    final dir = await Directory.systemTemp.createTemp('buddy-photo');
    addTearDown(() => dir.delete(recursive: true));
    final photo = File('${dir.path}/jane.png');
    // A 1x1 transparent PNG.
    await photo.writeAsBytes(const [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);

    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        child: BuddyListTile(
          entry: BuddyWithDiveCount(
            buddy: _buddy(photoPath: photo.path),
            diveCount: 1,
          ),
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isA<FileImage>());
    expect(find.text('JD'), findsNothing);

    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        child: BuddyListTile(
          entry: BuddyWithDiveCount(
            buddy: _buddy(photoPath: '${dir.path}/missing.png'),
            diveCount: 1,
          ),
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('JD'), findsOneWidget);
  });

  testWidgets('keeps the title readable on a narrow German phone', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const longName = 'Maximiliane Schwarzenberger-Hoffmann';
    final entry = BuddyWithDiveCount(
      buddy: _buddy(name: longName),
      diveCount: 123,
      lastDiveAt: DateTime(2024, 3, 5),
      usualRoleId: DiveRole.instructorId,
    );

    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        locale: const Locale('de'),
        child: BuddyListTile(entry: entry, onTap: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.getSize(find.text(longName)).width, greaterThan(150));
  });

  testWidgets('shows a checkbox in selection mode', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        child: BuddyListTile(
          entry: BuddyWithDiveCount(buddy: _buddy(), diveCount: 1),
          isSelectionMode: true,
          isChecked: true,
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Checkbox), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/buddies/presentation/widgets/buddy_list_tile_test.dart`
Expected: FAIL to compile (missing `buddy_list_tile.dart`).

- [ ] **Step 3: Create the tile**

Create `lib/features/buddies/presentation/widgets/buddy_list_tile.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/shared/widgets/entity_card/card_slot_resolver.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_extra_fields.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_stat.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// Detailed list card for one buddy.
///
/// Configurable slots come from [buddyDetailedCardConfigProvider]; the
/// agency-tinted avatar ring, certification chip, usual-role chip and contact
/// icons are fixed identity elements. Hand-rolled rather than a ListTile so
/// the title keeps its font role under every theme preset and nothing
/// text-bearing sits in the trailing slot (issue #935).
class BuddyListTile extends ConsumerWidget {
  final BuddyWithDiveCount entry;
  final bool isSelected;
  final bool isChecked;
  final bool isSelectionMode;
  final VoidCallback? onTap;

  const BuddyListTile({
    super.key,
    required this.entry,
    this.isSelected = false,
    this.isChecked = false,
    this.isSelectionMode = false,
    this.onTap,
  });

  Buddy get buddy => entry.buddy;
  int get diveCount => entry.diveCount;

  static const _contentInset = 52.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final config = ref.watch(buddyDetailedCardConfigProvider);
    final roleMap = ref.watch(diveRoleMapProvider).value;
    final accent = resolveFeatureAccent(
      context,
      ref,
      surface: AccentSurface.list,
      featureId: 'buddies',
    );
    final secondaryTextColor = colorScheme.onSurfaceVariant;
    final statColor = accent ?? colorScheme.primary;
    final agencyColor = buddy.certificationAgency?.primaryColor;

    final adapter = BuddyFieldAdapter.instance;
    final slots = config.slots;

    String? slotText(BuddyField field) {
      final value = adapter.extractValue(field, entry);
      if (value == null) return null;
      final text = adapter.formatValue(field, value, units);
      return text.isEmpty || text == '--' ? null : text;
    }

    final title =
        slotText(resolveCardSlot(slots, 'title', BuddyField.buddyName)) ??
        buddy.name;
    final subtitle = slotText(
      resolveCardSlot(slots, 'subtitle', BuddyField.email),
    );

    String formatStat(BuddyField field, dynamic value) {
      if (field == BuddyField.diveCount) {
        return l10n.buddies_label_diveCount(value as int);
      }
      return adapter.formatValue(field, value, units);
    }

    Widget stat(String slotId, BuddyField fallback) {
      return EntityCardStat<BuddyWithDiveCount, BuddyField>(
        adapter: adapter,
        entity: entry,
        field: resolveCardSlot(slots, slotId, fallback),
        units: units,
        color: statColor,
        formatter: formatStat,
      );
    }

    final usualRoleId = entry.usualRoleId;
    final usualRole = usualRoleId == null || usualRoleId == DiveRole.buddyId
        ? null
        : (roleMap?[usualRoleId] ?? DiveRole.synthetic(usualRoleId));

    final certParts = <String>[
      if (buddy.certificationLevel != null)
        buddy.certificationLevel!.displayName,
      if (buddy.certificationAgency != null)
        buddy.certificationAgency!.displayName,
    ];

    final trailer = <Widget>[
      if (certParts.isNotEmpty)
        _BuddyChip(
          icon: Icons.card_membership,
          label: certParts.join(' · '),
          color: agencyColor ?? statColor,
        ),
      if (usualRole != null)
        _BuddyChip(
          icon: Icons.badge_outlined,
          label: usualRole.localizedName(l10n),
          color: statColor,
        ),
      if (buddy.email != null && buddy.email!.isNotEmpty)
        Tooltip(
          message: buddy.email!,
          child: Icon(Icons.mail_outline, size: 16, color: secondaryTextColor),
        ),
      if (buddy.phone != null && buddy.phone!.isNotEmpty)
        Tooltip(
          message: buddy.phone!,
          child: Icon(
            Icons.phone_outlined,
            size: 16,
            color: secondaryTextColor,
          ),
        ),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isChecked
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: buddy.name,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: SelectionLeading(
                          isSelectionMode: isSelectionMode,
                          isChecked: isChecked,
                          onChanged: (_) => onTap?.call(),
                          child: _BuddyAvatar(
                            buddy: buddy,
                            ringColor: agencyColor,
                            backgroundColor:
                                accent?.withValues(alpha: 0.15) ??
                                colorScheme.primaryContainer,
                            foregroundColor:
                                accent ?? colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: secondaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isSelectionMode)
                      ExcludeSemantics(
                        child: Icon(
                          Icons.chevron_right,
                          color: colorScheme.outline,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: _contentInset,
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      stat('stat1', BuddyField.diveCount),
                      stat('stat2', BuddyField.lastDive),
                    ],
                  ),
                ),
                if (trailer.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: _contentInset,
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: trailer,
                    ),
                  ),
                ],
                if (config.extraFields.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: _contentInset,
                    ),
                    child: EntityCardExtraFields<BuddyWithDiveCount, BuddyField>(
                      adapter: adapter,
                      entity: entry,
                      fields: config.extraFields,
                      units: units,
                      labelColor: secondaryTextColor,
                      valueColor: colorScheme.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Photo when the stored file exists, initials otherwise, inside an
/// optional 2 px ring in the certification agency's brand colour.
class _BuddyAvatar extends StatelessWidget {
  final Buddy buddy;
  final Color? ringColor;
  final Color backgroundColor;
  final Color foregroundColor;

  const _BuddyAvatar({
    required this.buddy,
    required this.ringColor,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final path = buddy.photoPath;
    final photo = path == null || path.isEmpty ? null : File(path);
    final hasPhoto = photo != null && photo.existsSync();
    final avatar = CircleAvatar(
      radius: ringColor == null ? 20 : 18,
      backgroundColor: backgroundColor,
      backgroundImage: hasPhoto ? FileImage(photo) : null,
      child: hasPhoto
          ? null
          : Text(
              buddy.initials,
              style: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
    if (ringColor == null) return avatar;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor!, width: 2),
      ),
      child: avatar,
    );
  }
}

class _BuddyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BuddyChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 12, color: color)),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Delete the old tile and wire the new one**

In `lib/features/buddies/presentation/widgets/buddy_list_content.dart`:

1. Delete the old `BuddyListTile` class (from `/// List item widget for displaying a buddy` through the closing brace of `_buildSubtitle`).
2. Add `import 'package:submersion/features/buddies/presentation/widgets/buddy_list_tile.dart';`.
3. In `_buildBuddyList`, the detailed/compact arm becomes (compact gets its own tile in Task 13; for now both modes still share):

```dart
            ListViewMode.detailed || ListViewMode.compact => BuddyListTile(
              entry: buddyWithCount,
              isSelected: isSelected,
              isChecked: isChecked,
              isSelectionMode: _isSelectionMode,
              onTap: () => _handleRowTap(buddy.id, buddies),
            ),
```

4. Run `flutter analyze lib/features/buddies/presentation/widgets/buddy_list_content.dart` and remove the imports it reports unused (expected: `selection_leading`, possibly `feature_accent`).

- [ ] **Step 5: Run the tests and analyzer**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/buddies/presentation/ && flutter analyze lib/features/buddies test/features/buddies && wc -l lib/features/buddies/presentation/widgets/buddy_list_content.dart lib/features/buddies/presentation/widgets/buddy_list_tile.dart`
Expected: all PASS, "No issues found!". `buddy_list_content_test.dart` builds the list with `allBuddiesWithDiveCountProvider` overridden and no diver id, so the config provider never touches the database; `diveRoleMapProvider` in that test reaches the real repository through `validatedCurrentDiverIdProvider`, so if it errors add `diveRoleMapProvider.overrideWith((ref) async => <String, DiveRole>{})` to `_buildPhoneOverrides` in that test. If a test there reads `tile.buddy` or `tile.diveCount` from `widgetList<BuddyListTile>`, the getters keep it compiling.

- [ ] **Step 6: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
dart format .
git add lib/features/buddies test/features/buddies
git commit -m "feat(buddies): rebuild the detailed buddy card with slots, agency ring, usual role and contact icons"
```

---

### Task 13: Compact buddy card

**Files:**
- Create: `lib/features/buddies/presentation/widgets/compact_buddy_list_tile.dart`
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_content.dart` (mode switch)
- Test: `test/features/buddies/presentation/widgets/compact_buddy_list_tile_test.dart`, `test/features/buddies/presentation/widgets/buddy_list_content_test.dart` (compact-mode routing)

**Interfaces:**
- Consumes: `buddyCompactCardConfigProvider` (Task 8), `resolveCardSlot`, `EntityCardStat` (Task 9).
- Produces: `class CompactBuddyListTile extends ConsumerWidget` with `CompactBuddyListTile({Key? key, required BuddyWithDiveCount entry, VoidCallback? onTap, bool isSelectionMode = false, bool isSelected = false, bool isHighlighted = false})` and `Buddy get buddy`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/buddies/presentation/widgets/compact_buddy_list_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/compact_buddy_list_tile.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _config = EntityCardViewConfig<BuddyField>(
  slots: [
    EntityCardSlotConfig(slotId: 'title', field: BuddyField.buddyName),
    EntityCardSlotConfig(
      slotId: 'subtitle',
      field: BuddyField.certificationLevel,
    ),
    EntityCardSlotConfig(slotId: 'stat1', field: BuddyField.diveCount),
    EntityCardSlotConfig(slotId: 'stat2', field: BuddyField.lastDive),
  ],
);

Future<List<dynamic>> _overrides() async => [
  ...await getBaseOverrides(),
  buddyCompactCardConfigProvider.overrideWith(
    (ref) => EntityCardConfigNotifier<BuddyField>(
      defaultConfig: _config,
      fieldFromName: BuddyFieldAdapter.instance.fieldFromName,
    ),
  ),
];

final _entry = BuddyWithDiveCount(
  buddy: Buddy(
    id: 'b1',
    name: 'Ken Sato',
    certificationLevel: CertificationLevel.advancedOpenWater,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  ),
  diveCount: 7,
  lastDiveAt: DateTime(2024, 3, 5),
);

void main() {
  testWidgets('renders two lines from the compact config', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        locale: const Locale('en'),
        child: CompactBuddyListTile(entry: _entry, onTap: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('Ken Sato'), findsOneWidget);
    expect(find.text('Advanced Open Water'), findsOneWidget);
    expect(find.text('7 dives'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('shows a checkbox in selection mode', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await _overrides(),
        child: CompactBuddyListTile(
          entry: _entry,
          isSelectionMode: true,
          isSelected: true,
          onTap: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(Checkbox), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/buddies/presentation/widgets/compact_buddy_list_tile_test.dart`
Expected: FAIL to compile (missing file).

- [ ] **Step 3: Create the tile**

Create `lib/features/buddies/presentation/widgets/compact_buddy_list_tile.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selection_checkbox_slot.dart';
import 'package:submersion/shared/widgets/entity_card/card_slot_resolver.dart';
import 'package:submersion/shared/widgets/entity_card/entity_card_stat.dart';

/// Two-line compact card tile for the buddy list, driven by
/// [buddyCompactCardConfigProvider]. No avatar, no chips.
///
/// Line 1: title slot | stat1 | chevron
/// Line 2: subtitle slot | stat2
class CompactBuddyListTile extends ConsumerWidget {
  final BuddyWithDiveCount entry;
  final VoidCallback? onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isHighlighted;

  const CompactBuddyListTile({
    super.key,
    required this.entry,
    this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isHighlighted = false,
  });

  Buddy get buddy => entry.buddy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final slots = ref.watch(buddyCompactCardConfigProvider).slots;
    final adapter = BuddyFieldAdapter.instance;
    final secondaryTextColor = colorScheme.onSurfaceVariant;
    final cardColor = (isSelected || isHighlighted)
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : null;

    String? slotText(BuddyField field) {
      final value = adapter.extractValue(field, entry);
      if (value == null) return null;
      final text = adapter.formatValue(field, value, units);
      return text.isEmpty || text == '--' ? null : text;
    }

    final title =
        slotText(resolveCardSlot(slots, 'title', BuddyField.buddyName)) ??
        buddy.name;
    final subtitle = slotText(
      resolveCardSlot(slots, 'subtitle', BuddyField.certificationLevel),
    );
    final stat2Field = resolveCardSlot(slots, 'stat2', BuddyField.lastDive);
    final showSecondLine = subtitle != null || slotText(stat2Field) != null;

    String formatStat(BuddyField field, dynamic value) {
      if (field == BuddyField.diveCount) {
        return l10n.buddies_label_diveCount(value as int);
      }
      return adapter.formatValue(field, value, units);
    }

    Widget stat(BuddyField field) {
      return EntityCardStat<BuddyWithDiveCount, BuddyField>(
        adapter: adapter,
        entity: entry,
        field: field,
        units: units,
        color: secondaryTextColor,
        formatter: formatStat,
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      color: cardColor,
      child: Semantics(
        button: true,
        selected: isSelected || isHighlighted,
        label: buddy.name,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                SelectionCheckboxSlot(
                  isSelectionMode: isSelectionMode,
                  isChecked: isSelected,
                  onChanged: (_) => onTap?.call(),
                  gap: 8,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          stat(resolveCardSlot(slots, 'stat1', BuddyField.diveCount)),
                          ExcludeSemantics(
                            child: Icon(
                              Icons.chevron_right,
                              color: secondaryTextColor,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      if (showSecondLine) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                subtitle ?? '',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: secondaryTextColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            stat(stat2Field),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Route compact mode to it**

In `buddy_list_content.dart` add the import for `compact_buddy_list_tile.dart` and split the mode switch:

```dart
            ListViewMode.detailed => BuddyListTile(
              entry: buddyWithCount,
              isSelected: isSelected,
              isChecked: isChecked,
              isSelectionMode: _isSelectionMode,
              onTap: () => _handleRowTap(buddy.id, buddies),
            ),
            ListViewMode.compact => CompactBuddyListTile(
              entry: buddyWithCount,
              isSelectionMode: _isSelectionMode,
              isSelected: isChecked,
              isHighlighted: !_isSelectionMode && isHighlighted,
              onTap: () => _handleRowTap(buddy.id, buddies),
            ),
```

Then in `test/features/buddies/presentation/widgets/buddy_list_content_test.dart` add a routing test next to the existing view-mode tests (reuse its `_buildPhoneOverrides` and `_makeBuddy` helpers):

```dart
    testWidgets('compact mode renders CompactBuddyListTile rows', (
      tester,
    ) async {
      final overrides = await _buildPhoneOverrides(
        buddies: [_makeBuddy(id: 'b1', name: 'Jane Doe', diveCount: 3)],
        viewMode: ListViewMode.compact,
      );
      await tester.pumpWidget(
        testApp(overrides: overrides, child: const BuddyListContent()),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CompactBuddyListTile), findsOneWidget);
      expect(find.byType(BuddyListTile), findsNothing);
    });
```

with imports for both tile files. If an existing test in that file asserts that compact mode renders `BuddyListTile`, change its expectation to `CompactBuddyListTile`.

- [ ] **Step 5: Run the tests and analyzer**

Run: `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment && flutter test test/features/buddies/ && flutter analyze lib/features/buddies test/features/buddies`
Expected: all PASS, "No issues found!".

- [ ] **Step 6: Commit**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
dart format .
git add lib/features/buddies test/features/buddies
git commit -m "feat(buddies): add a real compact buddy card driven by its slot config"
```

---

### Task 14: Whole-project verification

**Files:** none new; this task runs the gates the pre-push hook and CI apply.

- [ ] **Step 1: Format and analyze the whole project**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
dart format .
flutter analyze
```

Expected: `Analyzing site-buddy-card-enrichment...` followed by `No issues found!`. Info-level findings count as failures in CI; fix every line it lists.

- [ ] **Step 2: Confirm generated code is fresh**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
flutter gen-l10n
dart run build_runner build --delete-conflicting-outputs
git status --short
```

Expected: `git status` shows nothing outside `test/**/*.mocks.dart` (regenerated mocks) and the untracked `packages/submersion_saf/android/.gradle/`. Commit any regenerated mock that changed: `git add -u test && git commit -m "chore: regenerate mocks"`.

- [ ] **Step 3: File-length check**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
wc -l lib/features/dive_sites/presentation/widgets/site_list_content.dart lib/features/dive_sites/presentation/widgets/site_list_tile.dart lib/features/dive_sites/presentation/widgets/compact_site_list_tile.dart lib/features/buddies/presentation/widgets/buddy_list_content.dart lib/features/buddies/presentation/widgets/buddy_list_tile.dart lib/features/buddies/presentation/widgets/compact_buddy_list_tile.dart lib/shared/providers/entity_card_config_providers.dart
```

Expected: every new file under 800; the two `*_list_content.dart` files shorter than before the branch (1553 and 1134).

- [ ] **Step 4: Run the full test suite once**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
flutter test
```

Expected: the summary line `All tests passed!`. Do not run a second full suite concurrently in another session (overlapping runs fake lone failures). If a single known-flaky file fails (recovery code yo-yo, security settings recovery dialog, zip temp dir, media share helper, media store worker, plan buoyancy twin, sync replace library, sync providers restore, shearwater temp db), rerun that one file alone with `flutter test <file>` before treating it as a regression. Confirm the process ran against this tree: `ps aux | grep flutter_tester | grep -o "packages=[^ ]*"` must name `.claude/worktrees/site-buddy-card-enrichment`.

- [ ] **Step 5: Double-check the main checkout is untouched**

```bash
git -C /Users/ericgriffin/repos/submersion-app/submersion status --short
```

Expected: only the pre-existing ` M CLAUDE.md`. If any file this plan names shows as modified in the main checkout, an edit landed in the wrong tree: `git -C /Users/ericgriffin/repos/submersion-app/submersion restore <that file>` and re-apply it under the worktree path.

- [ ] **Step 6: Push and open the PR**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/site-buddy-card-enrichment
git push -u origin worktree-site-buddy-card-enrichment
```

PR title: `feat: enrich the dive site and buddy list cards`. PR body: a summary of the visible changes (site card: rating inline, stat row, difficulty/water/feature chips, last dived and your max depth; buddy card: agency ring, cert chip, dives together, last dive, usual role, contact icons, real compact tile), the persisted card-slot config now honoured by both cards, the three bug fixes (buddy photo `AssetImage`, compact site tile English count, `BuddyFieldAdapter` enum names), and the deferred follow-ups (site photo thumbnails, sort by last dived, wiring the other entities' card configs). No attribution line and no session link.
