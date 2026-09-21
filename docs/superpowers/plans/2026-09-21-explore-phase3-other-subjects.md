# Explore Phase 3 (Other Subjects) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Explore answer questions about the other six things a logbook holds, so "regulators due for service in 30 days", "sites in Bonaire I have not dived since 2022" and "liveaboard trips in 2024" compile into visible chips, a result list of that kind of thing, and a handoff to that subject's own page.

**Architecture:** Phase 1 hardwired one subject. Three refactors open it up without changing dive behaviour: fields become an `ExploreField` interface that six enums implement, `CompiledQuery.filter` becomes a sealed `CompiledTarget` with one variant per subject, and the page reads a subject-dispatched results widget. Each subject then plugs in a field catalog, a lowering function, a results provider and a handoff. Lowering targets are the subject's existing filter state where one exists, and a new one where it does not. The model's schema keeps ONE flat field list; the compiler rejects a field that does not belong to the declared subject.

**Tech Stack:** Dart (pure domain code), Riverpod providers, Drift for two new batch aggregates, `flutter_test` for unit, database and widget tests. No native change: the Swift adapter builds its schema from the vocabulary Dart ships, and the Android adapter is prompt-only.

**Spec:** `docs/superpowers/specs/2026-09-19-explore-natural-language-search-design.md` (section "Phase 3: other subjects").

**Earlier plans, for the seams this builds on:** `docs/superpowers/plans/2026-09-19-explore-phase1-core-dives.md` and `docs/superpowers/plans/2026-09-20-explore-phase2-derived-predicates.md`.

## Global Constraints

- No em-dashes, en-dashes as punctuation, or double hyphens anywhere: code, comments, ARB strings, commit messages.
- No mention of Claude, Claude Code or Anthropic in any commit, file, PR body, PR comment or review reply. This holds even when an automated reviewer asks for an "Addressed by" line.
- No emojis in code, comments or docs.
- Every new ARB key goes into all 11 files: `app_ar, de, en, es, fr, he, hu, it, nl, pt, zh`. `app_en.arb` is alphabetical; the others are feature-grouped, so anchor inserts on a neighbouring key and insert as TEXT. A `json.loads`/`json.dumps` round-trip of an ARB file reformats unrelated compact metadata blocks and produces a huge spurious diff. A key with more than one placeholder needs an `@key` metadata block in `app_en.arb` or `gen-l10n` orders the parameters alphabetically.
- German must say AMV, never SAC (`test/l10n/german_sac_terminology_test.dart`).
- A provider that reads a table must self-invalidate on that table's change tick (`test/architecture/provider_change_tick_test.dart`). Use `ref.invalidateSelfWhen(stream)`. A provider whose value is a function, not data, carries `// no-tick: <reason>` on the line ABOVE the declaration.
- A new aggregate over `dives` must apply `DiveStatsScope` or carry a `// stats-scope-exempt: <reason>` marker (`test/core/database/dive_stats_scope_census_test.dart`).
- Storage units are metric. Ground bare numbers through `groundToMetric` with the diver's unit settings, exactly as the dive fields do.
- No new `DiveFilterState` axis in this phase, so the three-path rule does not apply. If one turns out to be needed, it lands in all three paths with a parity test.
- Run `dart format .` before every commit and `flutter analyze` (clean, infos are fatal) before the final one. Run tests per file or directory; run the full suite once at the end, unpiped so the exit code is real.
- `TMPDIR` on the maintainer's machine may point at a mounted volume, which crashes the test harness during shutdown and still exits 0. Run `TMPDIR=/tmp flutter test ...` and prefix `git push` the same way.
- The Drift generated files (`*.g.dart`) are gitignored. Run codegen, but do not commit them. Codegen is `dart run build_runner build --delete-conflicting-outputs`; the bare word `build` in a Bash command is refused by a deny rule, so run it from a script file.
- Work in the existing worktree on a branch off the phase 2 head. Stage explicit paths, never `git add -A`. Commit after every task.
- This phase's PR **closes** the program issue: `Closes #2195`.

---

## What already exists, and what does not

The six subjects are not in the same state, and the plan's task sizes
follow that. Verified before writing:

| Subject | Filter state today | Aggregate with counts and dates | What Explore needs added |
| --- | --- | --- | --- |
| Sites | `SiteFilterState` (in `site_providers.dart`), `apply` over `List<SiteWithDiveCount>` | `SiteWithDiveCount` carries `diveCount`, `lastDivedAt`, `firstDivedAt`; batch query `SiteRepository.getDiveAggregatesBySite()` | two fields on the state |
| Equipment | `EquipmentFilterState` (`domain/models/`), `apply(items, tagIdsByEquipment)` | only `EquipmentExposureTotals` per item through a family provider, an N+1 over a list | four fields plus a batch query |
| Trips | `TripFilterState`, one field, **no `apply`** | `TripWithStats` carries `diveCount`; dates live on `Trip` | five fields plus a new `apply` |
| Buddies | none | `BuddyWithDiveCount` carries `diveCount`, `lastDiveAt`, `usualRoleId` | a new filter state and provider |
| Species | none, the page keeps `_query`/`_category`/`_sort` in widget state | `SeenSpecies` carries `totalSightings`, `diveCount`, `siteCount`, `firstSeen`, `lastSeen` | a new filter state and provider, and the page must read it |
| Centers | none | nothing; only `getDiveCountForCenter(id)` per centre, read through a family provider per row | a new filter state, a new aggregate and a batch query |

Two consequences worth stating up front. Species is the only subject whose
page holds its filter in local widget state, so the handoff has nowhere to
write until Task 8 lifts it into a provider; that lift is a real change to
an existing page, not new code beside it. And centres have no "last dived"
anywhere in the app, so `lastVisited` is deliberately absent from the centre
catalog rather than quietly approximated.

---

## File Structure

New files:

| File | Responsibility |
| --- | --- |
| `lib/features/explore/domain/explore_field.dart` | The `ExploreField` interface every subject's field enum implements, plus `FieldSpec`, `FieldDimension` and `FieldValueType` moved here so six catalogs share them without importing the dive one. |
| `lib/features/explore/domain/subject_catalog.dart` | Which fields belong to which subject, and the flat union the model's vocabulary ships. |
| `lib/features/explore/domain/compiled_target.dart` | The sealed `CompiledTarget` and one variant per subject. |
| `lib/features/explore/domain/fields/site_fields.dart` | `ExploreSiteField` and its catalog. One file per subject: six enums in one file would be 400 lines and a reviewer could not reject one subject without re-reading the others. |
| `lib/features/explore/domain/fields/equipment_fields.dart` | `ExploreEquipmentField` and its catalog. |
| `lib/features/explore/domain/fields/trip_fields.dart` | `ExploreTripField` and its catalog. |
| `lib/features/explore/domain/fields/buddy_fields.dart` | `ExploreBuddyField` and its catalog. |
| `lib/features/explore/domain/fields/species_fields.dart` | `ExploreSpeciesField` and its catalog. |
| `lib/features/explore/domain/fields/center_fields.dart` | `ExploreCenterField` and its catalog. |
| `lib/features/explore/domain/lowering/site_lowering.dart` | Lowers a site clause or mention into `SiteFilterState`. |
| `lib/features/explore/domain/lowering/equipment_lowering.dart` | Same for equipment. |
| `lib/features/explore/domain/lowering/trip_lowering.dart` | Same for trips. |
| `lib/features/explore/domain/lowering/buddy_lowering.dart` | Same for buddies. |
| `lib/features/explore/domain/lowering/species_lowering.dart` | Same for species. |
| `lib/features/explore/domain/lowering/center_lowering.dart` | Same for centres. |
| `lib/features/buddies/domain/models/buddy_filter_state.dart` | New `BuddyFilterState`, `apply` over `List<BuddyWithDiveCount>`. |
| `lib/features/marine_life/domain/models/species_filter_state.dart` | New `SpeciesFilterState`, `apply` over `List<SeenSpecies>`, wrapping the existing `filterSeenSpecies`. |
| `lib/features/dive_centers/domain/models/dive_center_filter_state.dart` | New `DiveCenterFilterState`, `apply` over the new aggregate. |
| `lib/features/dive_centers/domain/entities/dive_center_with_dive_count.dart` | The aggregate centres lack. |
| `lib/features/explore/presentation/widgets/explore_subject_results.dart` | Dispatches the result rows on the compiled target. |
| `lib/features/explore/presentation/widgets/explore_handoff_bar.dart` | Dispatches the handoff buttons on the compiled target. Lifted out of the page, which is already 219 lines and would otherwise carry seven branches inline. |

Modified files:

| File | Change |
| --- | --- |
| `lib/features/explore/domain/dive_field_catalog.dart` | `ExploreDiveField implements ExploreField`; shared spec types move out and are re-exported so phase 1 and 2 imports keep working. |
| `lib/features/explore/domain/compiled_query.dart` | `ClauseChip.field` widens to `ExploreField`; `CompiledQuery.filter` becomes `CompiledQuery.target`. |
| `lib/features/explore/domain/query_compiler.dart` | The subject guard becomes a sealed dispatch; the dive path moves behind it unchanged. |
| `lib/features/explore/domain/nl_engine.dart` | Per-subject field lines, two new examples, and the vocabulary ships the union. |
| `lib/features/explore/domain/query_model.dart` | `kQuerySchemaVersion` to 3. |
| `lib/features/explore/domain/chart_selection.dart` | A non-dive subject gets exactly one count-per-entity chart. |
| `lib/features/explore/presentation/chip_labeler.dart` | `fieldName` dispatches on the field's runtime type. |
| `lib/features/explore/presentation/providers/explore_providers.dart` | `exploreTargetProvider` beside the existing dive-only filter provider; per-subject result and count providers. |
| `lib/features/explore/presentation/pages/explore_page.dart` | Reads the two new dispatch widgets. |
| `lib/features/dive_sites/presentation/providers/site_providers.dart` | `SiteFilterState` gains `lastDivedBefore` and `minDiveCount`, applied in `apply`. |
| `lib/features/equipment/domain/models/equipment_filter_state.dart` | Gains `dueWithinDays`, `lastUsedBefore`, `lastUsedAfter`, `minDiveCount`; `apply` takes an exposure map. |
| `lib/features/equipment/data/repositories/equipment_repository_impl.dart` | A batch dive-count-and-last-used query. |
| `lib/features/trips/presentation/providers/trip_providers.dart` | `TripFilterState` gains five fields and its first `apply`. |
| `lib/features/dive_centers/data/repositories/dive_center_repository.dart` | A batch dive-count-per-centre query. |
| `lib/features/marine_life/presentation/pages/species_page.dart` | Reads `speciesFilterProvider` instead of local widget state. |
| The 11 ARB files | Field and subject labels for the new chips. |

---

## Tasks

Tasks 1 to 3 are refactors with **no behaviour change**: the dive path must
keep passing every phase 1 and phase 2 test untouched. Tasks 4 to 9 add one
subject each and are independent of one another. Tasks 10 to 12 finish the
surface.

### Task 1: The ExploreField interface and the subject catalog

**Files:**
- Create: `lib/features/explore/domain/explore_field.dart`
- Create: `lib/features/explore/domain/subject_catalog.dart`
- Modify: `lib/features/explore/domain/dive_field_catalog.dart`
- Modify: `lib/features/explore/domain/compiled_query.dart` (`ClauseChip.field`)
- Test: `test/features/explore/domain/subject_catalog_test.dart`

**Interfaces:**
- Consumes: `ClauseOp`, `QuerySubject` (`query_model.dart`).
- Produces:
  - `abstract interface class ExploreField { String get jsonName; }`
  - `FieldDimension`, `FieldValueType`, `FieldSpec` (moved here verbatim from `dive_field_catalog.dart`).
  - `abstract interface class FieldCatalog { List<ExploreField> get fields; ExploreField? parse(String jsonName); FieldSpec spec(ExploreField field); }`
  - `abstract final class SubjectCatalog { static FieldCatalog? of(QuerySubject subject); static List<String> get allJsonNames; }`
  - `ExploreDiveField implements ExploreField` (unchanged values and jsonNames).

The model's schema keeps ONE flat field list, the union of every subject's
fields. Per-subject schemas would mean the Swift adapter rebuilding its
`DynamicGenerationSchema` per sentence, and the Android adapter has no schema
at all. The compiler rejects a field that does not belong to the declared
subject instead, as `wrongSubject`, so a model that writes `depth` under
`subject: equipment` produces a visible unplaced chip rather than a wrong
filter.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/explore/domain/subject_catalog_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/explore_field.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/domain/subject_catalog.dart';

void main() {
  test('every subject has a catalog', () {
    for (final subject in QuerySubject.values) {
      expect(SubjectCatalog.of(subject), isNotNull, reason: subject.name);
    }
  });

  test('the dive catalog is reachable through the registry', () {
    final catalog = SubjectCatalog.of(QuerySubject.dives)!;
    expect(catalog.parse('depth'), ExploreDiveField.depth);
    expect(catalog.parse('sacTrend'), ExploreDiveField.sacTrend);
    expect(catalog.parse('nonsense'), isNull);
    expect(
      catalog.spec(ExploreDiveField.depth).dimension,
      FieldDimension.depth,
    );
  });

  test('a field of another subject does not parse under dives', () {
    // The guard that turns a mismatched field into wrongSubject rather than
    // a filter on the wrong axis.
    final dives = SubjectCatalog.of(QuerySubject.dives)!;
    expect(dives.parse('serviceDueWithinDays'), isNull);
  });

  test('the flat union has no duplicate json names', () {
    final all = SubjectCatalog.allJsonNames;
    expect(all.toSet().length, all.length);
    expect(all, contains('depth'));
  });

  test('every field in the union parses under exactly one subject', () {
    for (final name in SubjectCatalog.allJsonNames) {
      final owners = [
        for (final s in QuerySubject.values)
          if (SubjectCatalog.of(s)!.parse(name) != null) s,
      ];
      expect(owners, hasLength(1), reason: '$name owned by $owners');
    }
  });

  test('every field has a spec and at least one op', () {
    for (final subject in QuerySubject.values) {
      final catalog = SubjectCatalog.of(subject)!;
      for (final field in catalog.fields) {
        expect(catalog.spec(field).ops, isNotEmpty, reason: field.jsonName);
      }
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/explore/domain/subject_catalog_test.dart`
Expected: FAIL, `explore_field.dart` and `subject_catalog.dart` do not exist.

- [ ] **Step 3: Write the shared field types**

```dart
// lib/features/explore/domain/explore_field.dart
import 'package:submersion/features/explore/domain/query_model.dart';

/// What a numeric clause measures, so bare numbers can take the diver's unit.
enum FieldDimension {
  depth,
  temperature,
  pressure,
  minutes,
  days,
  percent,
  count,
  none,
}

enum FieldValueType { number, enumName, flag }

/// One queryable field of one subject.
///
/// An interface rather than a base class so each subject keeps a plain enum:
/// enums give exhaustive switches in the lowering code, which is what makes
/// an unhandled field a compile error instead of a silent no-op.
abstract interface class ExploreField {
  String get jsonName;
}

class FieldSpec {
  final FieldDimension dimension;
  final FieldValueType valueType;
  final Set<ClauseOp> ops;
  final List<String>? enumValues;

  const FieldSpec({
    required this.dimension,
    required this.valueType,
    required this.ops,
    this.enumValues,
  });
}

/// The ops every ordered numeric field accepts.
const Set<ClauseOp> kOrderingOps = {
  ClauseOp.lt,
  ClauseOp.lte,
  ClauseOp.gt,
  ClauseOp.gte,
  ClauseOp.eq,
  ClauseOp.between,
};

/// The ops an enum field accepts when several values make sense.
const Set<ClauseOp> kMembershipOps = {
  ClauseOp.eq,
  ClauseOp.inList,
  ClauseOp.not,
};

const FieldSpec kFlagSpec = FieldSpec(
  dimension: FieldDimension.none,
  valueType: FieldValueType.flag,
  ops: {ClauseOp.eq},
);

const FieldSpec kCountSpec = FieldSpec(
  dimension: FieldDimension.count,
  valueType: FieldValueType.number,
  ops: kOrderingOps,
);

const FieldSpec kDaysSpec = FieldSpec(
  dimension: FieldDimension.days,
  valueType: FieldValueType.number,
  ops: kOrderingOps,
);

/// One subject's fields.
abstract interface class FieldCatalog {
  List<ExploreField> get fields;
  ExploreField? parse(String jsonName);
  FieldSpec spec(ExploreField field);
}
```

`FieldDimension.days` is new: "due for service in 30 days" and "not dived
since 2022" both measure days, and grounding must leave them alone rather
than treating them as a depth.

- [ ] **Step 4: Point the dive catalog at the shared types**

In `dive_field_catalog.dart`, delete the local `FieldDimension`,
`FieldValueType` and `FieldSpec` declarations and the three private op sets,
add `export 'package:submersion/features/explore/domain/explore_field.dart';`
plus the matching import, declare
`enum ExploreDiveField implements ExploreField { ... }` with its values
unchanged, and replace `_ordering` / `_membership` / `_flag` with
`kOrderingOps` / `kMembershipOps` / `kFlagSpec`. Then make the catalog an
instance:

```dart
class DiveFieldCatalogImpl implements FieldCatalog {
  const DiveFieldCatalogImpl();

  @override
  List<ExploreField> get fields => ExploreDiveField.values;

  @override
  ExploreField? parse(String jsonName) => DiveFieldCatalog.parse(jsonName);

  @override
  FieldSpec spec(ExploreField field) =>
      DiveFieldCatalog.spec(field as ExploreDiveField);
}
```

Keep the existing `abstract final class DiveFieldCatalog` and its static
members exactly as they are: phase 1 and phase 2 code calls them directly,
and re-exporting through the instance means none of that has to change.

- [ ] **Step 5: Write the registry**

```dart
// lib/features/explore/domain/subject_catalog.dart
import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/explore_field.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// Which fields belong to which subject.
///
/// Every subject has an entry, so `of` never returns null in practice; the
/// nullable return exists only so a new enum value fails a test rather than
/// throwing at runtime in front of a diver.
abstract final class SubjectCatalog {
  static const Map<QuerySubject, FieldCatalog> _catalogs = {
    QuerySubject.dives: DiveFieldCatalogImpl(),
    // Tasks 4 to 9 add the other six here.
  };

  static FieldCatalog? of(QuerySubject subject) => _catalogs[subject];

  /// The flat union the model's vocabulary ships. One list, not one per
  /// subject, because the Apple adapter builds a fixed constrained schema
  /// from it and the Android adapter has none at all. The compiler rejects
  /// a field that does not belong to the declared subject.
  static List<String> get allJsonNames => [
    for (final catalog in _catalogs.values)
      for (final field in catalog.fields) field.jsonName,
  ];
}
```

- [ ] **Step 6: Widen the chip**

In `compiled_query.dart`, change `final ExploreDiveField field;` to
`final ExploreField field;` and add the import. Everything that reads
`chip.field` and compares it to an `ExploreDiveField` value still works,
because `==` on an enum against a widened static type compiles.
`chart_selection.dart` keeps its `List<ExploreDiveField>` parameter for now;
Task 10 widens it.

- [ ] **Step 7: Run the tests**

Run: `TMPDIR=/tmp flutter test test/features/explore test/l10n`
Expected: PASS, including every phase 1 and phase 2 test unchanged. This is
a refactor; a changed expectation anywhere means the refactor changed
behaviour and must be corrected rather than the test edited.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/explore test/features/explore
git add lib/features/explore/domain/explore_field.dart lib/features/explore/domain/subject_catalog.dart lib/features/explore/domain/dive_field_catalog.dart lib/features/explore/domain/compiled_query.dart test/features/explore/domain/subject_catalog_test.dart
git commit -m "refactor(explore): a field interface and a per-subject catalog registry"
```

---

### Task 2: The sealed compiled target

**Files:**
- Create: `lib/features/explore/domain/compiled_target.dart`
- Modify: `lib/features/explore/domain/compiled_query.dart`
- Modify: `lib/features/explore/domain/query_compiler.dart`
- Modify: `lib/features/explore/presentation/providers/explore_providers.dart`
- Modify: `lib/features/explore/presentation/pages/explore_page.dart`
- Test: `test/features/explore/domain/compiled_target_test.dart`

**Interfaces:**
- Produces:
  - `sealed class CompiledTarget { QuerySubject get subject; bool get hasActiveFilters; }`
  - `class DiveTarget extends CompiledTarget { final DiveFilterState filter; }`
  - `class UnsupportedTarget extends CompiledTarget` for a subject with no catalog yet.
  - `CompiledQuery.target` replacing `CompiledQuery.filter`.

Six more variants land in Tasks 4 to 9. Until then `UnsupportedTarget`
carries the subject so the page can say which kind of thing it cannot search
yet, instead of showing an empty dive list.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/explore/domain/compiled_target_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/explore/domain/compiled_target.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  test('a dive target carries its filter and its subject', () {
    const target = DiveTarget(DiveFilterState(minDepth: 20));
    expect(target.subject, QuerySubject.dives);
    expect(target.hasActiveFilters, isTrue);
    expect(target.filter.minDepth, 20);
  });

  test('an empty dive target is not active', () {
    expect(const DiveTarget(DiveFilterState()).hasActiveFilters, isFalse);
  });

  test('an unsupported subject keeps the subject it could not search', () {
    const target = UnsupportedTarget(QuerySubject.centers);
    expect(target.subject, QuerySubject.centers);
    expect(target.hasActiveFilters, isFalse);
  });

  test('targets compare by value, so a provider does not rebuild for free', () {
    expect(
      const DiveTarget(DiveFilterState(minDepth: 20)),
      const DiveTarget(DiveFilterState(minDepth: 20)),
    );
  });
}
```

The last case will FAIL unless `DiveFilterState` itself compares by value.
It does not today: it is a plain class with no `==`. Do NOT add `==` to
`DiveFilterState` in this task; that is a 37-field change with consequences
for three existing `StateProvider`s that currently rebuild on identity.
Instead delete that fourth test and note the decision inline in
`compiled_target.dart`:

```dart
/// Deliberately NOT value-equal: [DiveFilterState] compares by identity
/// today, and three StateProviders already depend on that. A target is
/// published once per compile, so identity is the right grain anyway.
```

Keep the first three cases.

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/explore/domain/compiled_target_test.dart`
Expected: FAIL, `compiled_target.dart` does not exist.

- [ ] **Step 3: Write the target**

```dart
// lib/features/explore/domain/compiled_target.dart
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

/// What a compiled sentence narrows: one subject's filter state.
///
/// Sealed so the results widget, the handoff bar and the chart selector all
/// switch exhaustively. Adding a subject without handling it everywhere is
/// a compile error, which is the point.
///
/// Deliberately NOT value-equal: [DiveFilterState] compares by identity
/// today, and three StateProviders already depend on that. A target is
/// published once per compile, so identity is the right grain anyway.
sealed class CompiledTarget {
  const CompiledTarget();

  QuerySubject get subject;

  /// Whether the sentence narrowed anything. A target that narrows nothing
  /// shows no results and no handoff, exactly as phase 1 did.
  bool get hasActiveFilters;
}

class DiveTarget extends CompiledTarget {
  final DiveFilterState filter;
  const DiveTarget(this.filter);

  @override
  QuerySubject get subject => QuerySubject.dives;

  @override
  bool get hasActiveFilters => filter.hasActiveFilters;
}

/// A subject this build cannot search yet. Carries the subject so the page
/// names it rather than showing an empty list of the wrong kind of thing.
class UnsupportedTarget extends CompiledTarget {
  @override
  final QuerySubject subject;
  const UnsupportedTarget(this.subject);

  @override
  bool get hasActiveFilters => false;
}
```

- [ ] **Step 4: Swap the field on CompiledQuery**

In `compiled_query.dart`, replace `final DiveFilterState filter;` with
`final CompiledTarget target;` and update the constructor. In
`query_compiler.dart`, the unsupported branch returns
`target: UnsupportedTarget(query.subject)` and the dive path returns
`target: DiveTarget(filter)`.

In `explore_providers.dart`, add beside the existing filter provider:

```dart
/// The compiled target, whatever its subject. The dive-only
/// [exploreFilterProvider] stays: the dive results, count and charts read
/// it, and the dive handoff writes it straight into the dive list's own
/// provider.
final exploreTargetProvider = StateProvider<CompiledTarget>(
  (ref) => const UnsupportedTarget(QuerySubject.dives),
);
```

In `_publish`, set both:

```dart
    _ref.read(exploreTargetProvider.notifier).state = compiled.target;
    if (compiled.target case DiveTarget(:final filter)) {
      _ref.read(exploreFilterProvider.notifier).state = filter;
    } else {
      _ref.read(exploreFilterProvider.notifier).state =
          const DiveFilterState();
    }
```

Clearing the dive filter on a non-dive subject matters: without it, asking
about dives and then about sites would leave the dive results list showing
the previous sentence's matches under the new sentence's chips.

Reset both in `run` and in `clear`. In `explore_page.dart`, replace
`compiled.filter.hasActiveFilters` with `compiled.target.hasActiveFilters`.

- [ ] **Step 5: Run the tests**

Run: `TMPDIR=/tmp flutter test test/features/explore`
Expected: PASS, every phase 1 and 2 test unchanged. Tests that read
`compiled.filter` are updated to `compiled.target` as a mechanical rename;
no assertion value changes.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/explore test/features/explore
git add lib/features/explore test/features/explore
git commit -m "refactor(explore): a sealed compiled target so a subject is a type, not a flag"
```

---

### Task 3: Subject dispatch for results and handoffs

**Files:**
- Create: `lib/features/explore/presentation/widgets/explore_subject_results.dart`
- Create: `lib/features/explore/presentation/widgets/explore_handoff_bar.dart`
- Modify: `lib/features/explore/presentation/pages/explore_page.dart`
- Test: `test/features/explore/presentation/widgets/explore_subject_results_test.dart`

**Interfaces:**
- Consumes: `CompiledTarget` (Task 2).
- Produces: `ExploreSubjectResults` and `ExploreHandoffBar`, both `ConsumerWidget`s that switch on `exploreTargetProvider`.

Still dives-only. This task is the seam six later tasks each add one case
to, and a widget test that asserts the unsupported message is what keeps an
unfinished subject visible rather than silently empty.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/explore/presentation/widgets/explore_subject_results_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/explore/domain/compiled_target.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/explore/presentation/widgets/explore_results_list.dart';
import 'package:submersion/features/explore/presentation/widgets/explore_subject_results.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  Future<void> pump(WidgetTester tester, CompiledTarget target) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          exploreTargetProvider.overrideWith((ref) => target),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ExploreSubjectResults()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a subject with no catalog says so by name', (tester) async {
    await pump(tester, const UnsupportedTarget(QuerySubject.centers));
    expect(find.textContaining('dive centers'), findsOneWidget);
  });

  testWidgets('a dive target renders the dive results list', (tester) async {
    await pump(tester, const DiveTarget(DiveFilterState(minDepth: 20)));
    // The dive branch delegates to the phase 1 widget, which owns its own
    // loading and empty states; asserting the type keeps this test about
    // dispatch rather than about the dive list.
    expect(find.byType(ExploreResultsList), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/explore/presentation/widgets/explore_subject_results_test.dart`
Expected: FAIL, `explore_subject_results.dart` does not exist.

- [ ] **Step 3: Write the dispatch widgets**

```dart
// lib/features/explore/presentation/widgets/explore_subject_results.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/explore/domain/compiled_target.dart';
import 'package:submersion/features/explore/presentation/providers/explore_providers.dart';
import 'package:submersion/features/explore/presentation/widgets/explore_results_list.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The matching things, whatever kind of thing the sentence asked about.
///
/// Every branch delegates to a widget that owns its own loading, error and
/// empty states, so this stays a switch and nothing else.
class ExploreSubjectResults extends ConsumerWidget {
  const ExploreSubjectResults({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(exploreTargetProvider);
    return switch (target) {
      DiveTarget() => const ExploreResultsList(),
      // Tasks 4 to 9 add one case each here.
      UnsupportedTarget(:final subject) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          context.l10n.explore_subjectNotSupported(
            exploreSubjectLabel(context, subject),
          ),
        ),
      ),
    };
  }
}
```

Add `exploreSubjectLabel(BuildContext, QuerySubject)` to `chip_labeler.dart`
as a top-level function backed by seven new ARB keys
(`explore_subject_dives` through `explore_subject_centers`), plus
`explore_subjectNotSupported` taking one placeholder. Seven keys and one
message, all eleven locales.

`ExploreHandoffBar` follows the same shape: a `switch` returning the pair of
buttons for the target's subject, with `DiveTarget` returning exactly the
two buttons the page has today and `UnsupportedTarget` returning
`SizedBox.shrink()`. Move the existing block out of `explore_page.dart`
verbatim.

- [ ] **Step 4: Run the tests**

Run: `TMPDIR=/tmp flutter test test/features/explore test/l10n`
Expected: PASS, including the existing page test that drives both handoffs.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/explore test/features/explore
git add lib/features/explore lib/l10n/arb test/features/explore
git commit -m "refactor(explore): dispatch results and handoffs on the compiled target"
```

---

### Task 4: Sites

**Files:**
- Create: `lib/features/explore/domain/fields/site_fields.dart`
- Create: `lib/features/explore/domain/lowering/site_lowering.dart`
- Modify: `lib/features/dive_sites/presentation/providers/site_providers.dart`
- Modify: `lib/features/explore/domain/subject_catalog.dart`, `compiled_target.dart`, `query_compiler.dart`
- Modify: `lib/features/explore/presentation/widgets/explore_subject_results.dart`, `explore_handoff_bar.dart`, `chip_labeler.dart`
- Modify: `lib/features/explore/presentation/providers/explore_providers.dart`
- Test: `test/features/explore/domain/site_lowering_test.dart`
- Test: `test/features/dive_sites/presentation/providers/site_filter_state_test.dart`

**Interfaces:**
- Consumes: `SiteFilterState`, `SiteWithDiveCount`, `sortedSitesWithCountsProvider`, `siteFilterProvider`.
- Produces: `ExploreSiteField`, `SiteTarget(SiteFilterState)`, `lowerSiteQuery(...)`, `exploreSiteResultsProvider`.

Sites go first because they are the cheapest: the aggregate already carries
`diveCount` and `lastDivedAt`, `SiteFilterState.apply` already takes
`List<SiteWithDiveCount>`, and the filter provider the handoff writes
already exists. Two new fields on the state and the subject works.

Fields:

| JSON field | Type | Lowers to |
| --- | --- | --- |
| `siteDepth` | number, depth | `minDepth` / `maxDepth` |
| `siteRating` | number, count (1 to 5) | `minRating` |
| `siteDifficulty` | enum of `SiteDifficulty.values.map((d) => d.name)` | `difficulty` |
| `siteHasDives` | flag | `hasDives` |
| `siteHasCoordinates` | flag | `hasCoordinates` |
| `siteDiveCount` | number, count | new `minDiveCount` |
| `lastDivedBefore` | number, days, or a time mention | new `lastDivedBefore` |

`siteDepth` rather than `depth`: every field name is globally unique across
subjects (Task 1's registry test enforces it), because the model writes one
flat field name and the compiler decides whether it belongs to the declared
subject. A shared `depth` would make "sites deeper than 30m" and "dives
deeper than 30m" indistinguishable in the vocabulary.

The place mention already resolves to `NameTarget.sitePlace`, so "in
Bonaire" needs no new resolver work; the site lowering reads the same
`NameEntry` and writes `country`/`region` instead of `DiveFilterState.siteIds`.

- [ ] **Step 1: Write the failing filter-state test**

```dart
// test/features/dive_sites/presentation/providers/site_filter_state_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

void main() {
  DiveSite site(String id) => DiveSite(
    id: id,
    name: id,
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  SiteWithDiveCount entry(String id, {int count = 0, DateTime? lastDived}) =>
      SiteWithDiveCount(
        site: site(id),
        diveCount: count,
        lastDivedAt: lastDived,
      );

  test('minDiveCount keeps only sites dived at least that often', () {
    const filter = SiteFilterState(minDiveCount: 3);
    final kept = filter.apply([
      entry('often', count: 5),
      entry('once', count: 1),
      entry('never'),
    ]);
    expect(kept.map((e) => e.site.id), ['often']);
  });

  test('lastDivedBefore keeps sites not dived since the cutoff', () {
    final filter = SiteFilterState(lastDivedBefore: DateTime(2022));
    final kept = filter.apply([
      entry('stale', count: 2, lastDived: DateTime(2021, 6, 1)),
      entry('recent', count: 2, lastDived: DateTime(2023, 6, 1)),
    ]);
    expect(kept.map((e) => e.site.id), ['stale']);
  });

  test('a site never dived counts as not dived since the cutoff', () {
    // "sites I have not dived since 2022" must include one dived never,
    // which is the whole point of asking.
    final filter = SiteFilterState(lastDivedBefore: DateTime(2022));
    final kept = filter.apply([entry('never')]);
    expect(kept.map((e) => e.site.id), ['never']);
  });

  test('the two new axes count as active', () {
    expect(const SiteFilterState(minDiveCount: 1).hasActiveFilters, isTrue);
    expect(
      SiteFilterState(lastDivedBefore: DateTime(2022)).hasActiveFilters,
      isTrue,
    );
  });

  test('clearing them empties them', () {
    final filter = SiteFilterState(
      minDiveCount: 3,
      lastDivedBefore: DateTime(2022),
    );
    final cleared = filter.copyWith(
      clearMinDiveCount: true,
      clearLastDivedBefore: true,
    );
    expect(cleared.hasActiveFilters, isFalse);
  });
}
```

The third case is the one that earns its keep: a null `lastDivedAt` must
match, and the obvious implementation (`e.lastDivedAt!.isBefore(cutoff)`)
both throws and means the opposite of what the diver asked.

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/dive_sites/presentation/providers/site_filter_state_test.dart`
Expected: FAIL, `minDiveCount` is not a parameter of `SiteFilterState`.

- [ ] **Step 3: Extend the filter state**

In `site_providers.dart`, add to `SiteFilterState`:

```dart
  /// Keep sites dived at least this many times. Null means no bound.
  final int? minDiveCount;

  /// Keep sites whose most recent dive is before this instant, INCLUDING
  /// sites never dived: "sites I have not dived since 2022" is asking for
  /// exactly those.
  final DateTime? lastDivedBefore;
```

add both to the constructor, to `hasActiveFilters`, to `copyWith` with
`clearMinDiveCount` and `clearLastDivedBefore` flags following the existing
pattern, and to `apply`:

```dart
      if (minDiveCount != null && entry.diveCount < minDiveCount!) {
        return false;
      }
      if (lastDivedBefore != null) {
        final last = entry.lastDivedAt;
        if (last != null && !last.isBefore(lastDivedBefore!)) return false;
      }
```

- [ ] **Step 4: Write the failing lowering test**

```dart
// test/features/explore/domain/site_lowering_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/explore/domain/compiled_query.dart';
import 'package:submersion/features/explore/domain/compiled_target.dart';
import 'package:submersion/features/explore/domain/name_index.dart';
import 'package:submersion/features/explore/domain/query_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  final now = DateTime(2026, 9, 19);
  const units = (
    depth: DepthUnit.meters,
    temperature: TemperatureUnit.celsius,
    pressure: PressureUnit.bar,
  );
  const names = NameIndex([
    NameEntry(
      kind: MentionKind.place,
      label: 'Bonaire',
      ids: ['s1', 's2'],
      target: NameTarget.sitePlace,
      country: 'Bonaire',
    ),
  ]);

  CompiledQuery compile(Map<String, Object?> json) => QueryCompiler.compile(
    ParsedQuery.fromJson({
      'schemaVersion': kQuerySchemaVersion,
      'subject': 'sites',
      ...json,
    }),
    CompilerContext(units: units, names: names, now: now),
  );

  SiteFilterState filterOf(CompiledQuery q) =>
      (q.target as SiteTarget).filter;

  test('the subject alone produces a site target', () {
    final q = compile(const {});
    expect(q.target, isA<SiteTarget>());
  });

  test('the spec sentence compiles', () {
    // "Sites in Bonaire I have not dived since 2022"
    final q = compile({
      'mentions': [
        {'kind': 'place', 'text': 'Bonaire'},
      ],
      'clauses': [
        {
          'field': 'lastDivedBefore',
          'op': 'lt',
          'value': '2022',
          'text': 'not dived since 2022',
        },
      ],
    });
    final f = filterOf(q);
    expect(f.country, 'Bonaire');
    expect(f.lastDivedBefore, DateTime(2022));
    expect(q.unplaced, isEmpty);
    expect(q.chips, hasLength(2));
  });

  test('a dive count lowers to the site axis', () {
    final q = compile({
      'clauses': [
        {
          'field': 'siteDiveCount',
          'op': 'gte',
          'value': 5,
          'text': 'dived at least five times',
        },
      ],
    });
    expect(filterOf(q).minDiveCount, 5);
  });

  test('a depth takes the diver unit like every other depth', () {
    final q = compile({
      'clauses': [
        {
          'field': 'siteDepth',
          'op': 'gt',
          'value': 30,
          'unit': 'm',
          'text': 'deeper than 30m',
        },
      ],
    });
    expect(filterOf(q).minDepth, 30);
  });

  test('a dive field under the site subject is unplaced, not applied', () {
    // The flat vocabulary lets the model write any field name; the
    // compiler is what keeps a dive axis out of a site query.
    final q = compile({
      'clauses': [
        {'field': 'waterTemp', 'op': 'lt', 'value': 15, 'text': 'cold'},
      ],
    });
    expect(q.unplaced.single.reason, 'wrongSubject');
    expect(filterOf(q).hasActiveFilters, isFalse);
  });
}
```

`NameEntry` may not carry a `country` today; check it and add the field if
the place entry only carries site ids. If adding a field to `NameEntry` is
larger than it looks, lower a place mention to `siteTypeIds`-style id
matching instead and say so in the deviations.

- [ ] **Step 5: Write the catalog and the lowering**

`site_fields.dart` declares `enum ExploreSiteField implements ExploreField`
with the seven json names above and a `SiteFieldCatalog implements
FieldCatalog`. `site_lowering.dart` exposes:

```dart
({SiteFilterState filter, ClauseChip? chip, String? error}) lowerSiteClause(
  QueryClause clause,
  SiteFilterState current,
  UnitPrefs units,
);

SiteFilterState lowerSiteMention(NameEntry entry, SiteFilterState current);
```

mirroring the dive lowering's shape so a reader who knows one knows all six.

Register `QuerySubject.sites: SiteFieldCatalog()` in `SubjectCatalog`, add
`SiteTarget` to `compiled_target.dart`, and add the `QuerySubject.sites`
branch to the compiler's dispatch.

- [ ] **Step 6: Wire the results and the handoff**

Add to `explore_providers.dart`:

```dart
/// Sites matching the compiled target. Reads the same sorted aggregate the
/// site list reads, so Explore and the site list cannot disagree.
final exploreSiteResultsProvider = Provider<AsyncValue<List<SiteWithDiveCount>>>(
  (ref) {
    final target = ref.watch(exploreTargetProvider);
    if (target is! SiteTarget) return const AsyncValue.data([]);
    return ref
        .watch(sortedSitesWithCountsProvider)
        .whenData((sites) => target.filter.apply(sites));
  },
);
```

Reusing `sortedSitesWithCountsProvider` rather than querying again is what
keeps the two surfaces honest, and it inherits that provider's change ticks
for free.

Add the `SiteTarget` case to `ExploreSubjectResults`, rendering the site
rows the site list already uses and pushing `/sites/<id>` on tap, and to
`ExploreHandoffBar`, writing `siteFilterProvider` and calling
`context.go('/sites')`.

- [ ] **Step 7: Run the tests**

Run: `TMPDIR=/tmp flutter test test/features/explore test/features/dive_sites test/l10n`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
dart format lib test/features
git add lib/features/explore lib/features/dive_sites lib/l10n/arb test/features/explore test/features/dive_sites
git commit -m "feat(explore): search dive sites by depth, rating, dive count and last dived"
```

---

### Task 5: Equipment

**Files:**
- Create: `lib/features/explore/domain/fields/equipment_fields.dart`
- Create: `lib/features/explore/domain/lowering/equipment_lowering.dart`
- Create: `lib/features/equipment/domain/entities/equipment_usage_totals.dart`
- Modify: `lib/features/equipment/domain/models/equipment_filter_state.dart`
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart`
- Modify: the six Explore files Task 4 touched
- Test: `test/features/equipment/domain/models/equipment_filter_state_usage_test.dart`
- Test: `test/features/equipment/data/repositories/equipment_usage_totals_test.dart`
- Test: `test/features/explore/domain/equipment_lowering_test.dart`

**Interfaces:**
- Consumes: `EquipmentFilterState`, `EquipmentItem`, `equipmentFilterProvider`, `EquipmentAttrCondition`.
- Produces:
  - `class EquipmentUsageTotals { final int diveCount; final DateTime? lastUsedAt; }`
  - `EquipmentRepository.getUsageTotalsByEquipment({String? diverId}) -> Future<Map<String, EquipmentUsageTotals>>`
  - `ExploreEquipmentField`, `EquipmentTarget(EquipmentFilterState)`, `lowerEquipmentClause(...)`.

This is the largest subject task. Equipment has no batch usage aggregate:
today a list row reads `equipmentDiveCountProvider(id)`, one provider per
row, and `EquipmentExposureTotals` is likewise per item. "Gear I have not
used since last summer" over a 200-item locker would be 200 queries, so the
batch query comes first.

`EquipmentFilterState.apply` already takes a second argument
(`tagIdsByEquipment`); the usage axes need a third. Adding a named optional
`usage` parameter keeps every existing call site compiling.

Fields:

| JSON field | Type | Lowers to |
| --- | --- | --- |
| `gearType` | enum of `EquipmentType.values.map((t) => t.name)` | `type` |
| `gearStatus` | enum of `EquipmentStatus.values.map((s) => s.name)` | `status` |
| `serviceDueWithinDays` | number, days | new `dueWithinDays` |
| `gearDiveCount` | number, count | new `minDiveCount` |
| `lastUsedBefore` | number, days, or a time mention | new `lastUsedBefore` |
| `lastUsedAfter` | number, days, or a time mention | new `lastUsedAfter` |

A gear mention that resolves to `NameTarget.attrChoice` lowers to an
`EquipmentAttrCondition`, exactly as the dive path already does, so
"trilaminate regulators" works without new resolver code.

`serviceDueOnly` stays as it is. `dueWithinDays` is the richer axis and the
existing `assert` forbids `serviceDueOnly` together with a `status`; the
lowering must therefore never set both, and a sentence asking for both
produces one clause and one unplaced item rather than a failed assert in
front of a diver.

- [ ] **Step 1: Write the failing repository test**

```dart
// test/features/equipment/data/repositories/equipment_usage_totals_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  final base = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Future<void> gear(String id) => db.into(db.equipment).insert(
    EquipmentCompanion.insert(
      id: id,
      name: id,
      type: 'regulator',
      createdAt: base,
      updatedAt: base,
    ),
  );

  Future<void> diveWithGear(String diveId, String gearId, int at) async {
    await db.into(db.dives).insert(
      DivesCompanion(
        id: Value(diveId),
        diveDateTime: Value(at),
        createdAt: Value(base),
        updatedAt: Value(base),
      ),
    );
    await db.into(db.diveEquipment).insert(
      DiveEquipmentCompanion.insert(diveId: diveId, equipmentId: gearId),
    );
  }

  test('counts dives and the most recent use per item, in one query', () async {
    await gear('reg');
    await gear('torch');
    await gear('spare');
    await diveWithGear('d1', 'reg', base);
    await diveWithGear('d2', 'reg', base + 86400000);
    await diveWithGear('d3', 'torch', base);

    final totals = await EquipmentRepository().getUsageTotalsByEquipment();
    expect(totals['reg']!.diveCount, 2);
    expect(
      totals['reg']!.lastUsedAt,
      DateTime.fromMillisecondsSinceEpoch(base + 86400000),
    );
    expect(totals['torch']!.diveCount, 1);
    // Never used: absent from the map rather than present with a zero, so
    // a caller has to decide what "never" means for its own axis.
    expect(totals.containsKey('spare'), isFalse);
  });

  test('gear linked only through a tank still counts', () async {
    // A cylinder matched through the transmitter registry reaches the dive
    // as a dive_tanks.equipment_id, never as a dive_equipment row.
    await gear('cyl');
    await db.into(db.dives).insert(
      DivesCompanion(
        id: const Value('d1'),
        diveDateTime: Value(base),
        createdAt: Value(base),
        updatedAt: Value(base),
      ),
    );
    await db.into(db.diveTanks).insert(
      DiveTanksCompanion.insert(
        id: 't1',
        diveId: 'd1',
        equipmentId: const Value('cyl'),
      ),
    );
    final totals = await EquipmentRepository().getUsageTotalsByEquipment();
    expect(totals['cyl']!.diveCount, 1);
  });
}
```

The second case matters: the equipment statistics already count both links,
and a usage total that counted only `dive_equipment` would tell a diver
their cylinder had never been used.

Check `DiveTanksCompanion.insert`'s required parameters before writing it;
the tank table has several non-nullable columns.

- [ ] **Step 2: Run test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/equipment/data/repositories/equipment_usage_totals_test.dart`
Expected: FAIL, `getUsageTotalsByEquipment` is not defined.

- [ ] **Step 3: Write the aggregate and the query**

```dart
// lib/features/equipment/domain/entities/equipment_usage_totals.dart
/// How much one item has actually been dived.
///
/// Counts both ways gear reaches a dive: the dive_equipment junction and a
/// dive_tanks.equipment_id, which is how a cylinder matched through the
/// transmitter registry is linked. An item never dived has no entry.
class EquipmentUsageTotals {
  final int diveCount;
  final DateTime? lastUsedAt;
  const EquipmentUsageTotals({required this.diveCount, this.lastUsedAt});
}
```

In the repository, one query with a `UNION` over the two link tables,
grouped by equipment id, taking `COUNT(DISTINCT dive_id)` and
`MAX(dive_date_time)`:

```dart
  /// Dive count and most recent use for every item the diver has dived, in
  /// ONE query. The per-item providers are a family, so a list of 200 items
  /// would otherwise be 200 round trips.
  // stats-scope-exempt: a usage total, not a statistic; an excluded dive
  // still means the diver used the gear.
  Future<Map<String, EquipmentUsageTotals>> getUsageTotalsByEquipment({
    String? diverId,
  }) async {
    final where = diverId != null ? 'WHERE d.diver_id = ?' : '';
    final rows = await _db
        .customSelect(
          'SELECT equipment_id AS id, COUNT(DISTINCT dive_id) AS n, '
          'MAX(at) AS last_at FROM ('
          '  SELECT de.equipment_id, de.dive_id, d.dive_date_time AS at '
          '  FROM dive_equipment de JOIN dives d ON d.id = de.dive_id $where'
          '  UNION '
          '  SELECT dt.equipment_id, dt.dive_id, d.dive_date_time AS at '
          '  FROM dive_tanks dt JOIN dives d ON d.id = dt.dive_id '
          '  WHERE dt.equipment_id IS NOT NULL'
          '${diverId != null ? ' AND d.diver_id = ?' : ''}'
          ') GROUP BY equipment_id',
          variables: [
            if (diverId != null) Variable(diverId),
            if (diverId != null) Variable(diverId),
          ],
          readsFrom: {_db.dives, _db.diveEquipment, _db.diveTanks},
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('id'): EquipmentUsageTotals(
          diveCount: r.read<int>('n'),
          lastUsedAt: DateTime.fromMillisecondsSinceEpoch(
            r.read<int>('last_at'),
          ),
        ),
    };
  }
```

`UNION`, not `UNION ALL`: a dive that links the same item both ways must
count once. Verify the emitted SQL against the fixture rather than trusting
the string; the two-branch `WHERE` interpolation above is the easiest thing
in this plan to get subtly wrong.

- [ ] **Step 4: Extend the filter state**

Add `dueWithinDays`, `minDiveCount`, `lastUsedBefore`, `lastUsedAfter`, all
nullable, to `EquipmentFilterState` with constructor entries,
`hasActiveFilters`, `copyWith` clear flags, and a third optional argument on
`apply`:

```dart
  List<EquipmentItem> apply(
    List<EquipmentItem> equipment,
    Map<String, Iterable<String>> tagIdsByEquipment, {
    Map<String, EquipmentUsageTotals> usage = const {},
    DateTime? now,
  })
```

`now` is injected rather than read from the clock so the `dueWithinDays`
test is not time-dependent; default it to `clock.now()`, which main adopted
for trips in #2207. An item absent from `usage` has never been dived:
`minDiveCount` excludes it, `lastUsedBefore` includes it, `lastUsedAfter`
excludes it. Write one test per rule; those three asymmetries are where an
"obvious" implementation goes wrong.

- [ ] **Step 5: Write the catalog, the lowering and the wiring**

`equipment_fields.dart` declares `enum ExploreEquipmentField implements
ExploreField` with the six json names above and an
`EquipmentFieldCatalog implements FieldCatalog`. `equipment_lowering.dart`
exposes `lowerEquipmentClause` and `lowerEquipmentMention` with the same
signatures Task 4 gives for sites; the mention path lowers a gear
`attrChoice` entry to an `EquipmentAttrCondition`, as the dive path already
does.

Register `QuerySubject.equipment: EquipmentFieldCatalog()` in
`SubjectCatalog`, add `EquipmentTarget` to `compiled_target.dart`, and add
the `QuerySubject.equipment` branch to the compiler's dispatch.

Add `exploreEquipmentResultsProvider`, which watches the existing equipment
list source, the tag map and the new usage map and applies the filter. Add
the `EquipmentTarget` case to `ExploreSubjectResults`, rendering the row the
equipment list uses and pushing `/equipment/<id>` on tap, and to
`ExploreHandoffBar`, writing `equipmentFilterProvider` then calling
`context.go('/equipment')`.

- [ ] **Step 6: Run the tests**

Run: `TMPDIR=/tmp flutter test test/features/explore test/features/equipment test/l10n`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib test/features
git add lib/features/explore lib/features/equipment lib/l10n/arb test/features/explore test/features/equipment
git commit -m "feat(explore): search equipment by type, status, service due and use"
```

---

### Task 6: Trips

**Files:**
- Create: `lib/features/explore/domain/fields/trip_fields.dart`
- Create: `lib/features/explore/domain/lowering/trip_lowering.dart`
- Modify: `lib/features/trips/presentation/providers/trip_providers.dart`
- Modify: the six Explore files
- Test: `test/features/trips/presentation/providers/trip_filter_state_test.dart`
- Test: `test/features/explore/domain/trip_lowering_test.dart`

**Interfaces:**
- Consumes: `TripFilterState`, `TripWithStats`, `sortedFilteredTripsProvider`, `tripFilterProvider`.
- Produces: `ExploreTripField`, `TripTarget(TripFilterState)`, `TripFilterState.apply`.

`TripFilterState` has one field and **no `apply`**: the equipment axis is
resolved by a provider that intersects trip ids. The five new axes are all
answerable from `TripWithStats` in memory, so this task gives the state its
first `apply` and leaves the equipment axis exactly where it is.

Fields:

| JSON field | Type | Lowers to |
| --- | --- | --- |
| `tripType` | enum of `TripType.values.map((t) => t.name)` | `tripType` |
| `tripStartAfter` | time | `startAfter` |
| `tripEndBefore` | time | `endBefore` |
| `tripDiveCount` | number, count | `minDiveCount` |
| `tripLocation` | free text | `location`, matched case-insensitively as a substring |

"Liveaboard trips in 2024" is a `tripType` clause plus a time mention, and
the time grammar already parses "2024", so the lowering maps the parsed
range onto `startAfter` and `endBefore` together.

- [ ] **Step 1: Write the failing filter-state test**

```dart
// test/features/trips/presentation/providers/trip_filter_state_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

void main() {
  TripWithStats trip(
    String id, {
    TripType type = TripType.shoreBased,
    DateTime? start,
    DateTime? end,
    int dives = 0,
    String? location,
  }) => TripWithStats(
    trip: Trip(
      id: id,
      name: id,
      startDate: start ?? DateTime(2024, 1, 1),
      endDate: end ?? DateTime(2024, 1, 8),
      tripType: type,
      location: location,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    ),
    diveCount: dives,
  );

  test('the type axis keeps only that kind of trip', () {
    const filter = TripFilterState(tripType: TripType.liveaboard);
    final kept = filter.apply([
      trip('boat', type: TripType.liveaboard),
      trip('shore'),
    ]);
    expect(kept.map((t) => t.trip.id), ['boat']);
  });

  test('a year narrows on both ends', () {
    final filter = TripFilterState(
      startAfter: DateTime(2024),
      endBefore: DateTime(2025),
    );
    final kept = filter.apply([
      trip('in', start: DateTime(2024, 6, 1), end: DateTime(2024, 6, 8)),
      trip('before', start: DateTime(2023, 6, 1), end: DateTime(2023, 6, 8)),
      trip('after', start: DateTime(2025, 6, 1), end: DateTime(2025, 6, 8)),
    ]);
    expect(kept.map((t) => t.trip.id), ['in']);
  });

  test('a trip straddling the end of the range is excluded', () {
    // endBefore is a bound on the trip's END, so a trip that starts inside
    // 2024 and ends in 2025 is not a 2024 trip.
    final filter = TripFilterState(
      startAfter: DateTime(2024),
      endBefore: DateTime(2025),
    );
    final kept = filter.apply([
      trip('newYear', start: DateTime(2024, 12, 28), end: DateTime(2025, 1, 4)),
    ]);
    expect(kept, isEmpty);
  });

  test('location matches case-insensitively as a substring', () {
    const filter = TripFilterState(location: 'bonaire');
    final kept = filter.apply([
      trip('yes', location: 'Kralendijk, Bonaire'),
      trip('no', location: 'Cozumel'),
      trip('none'),
    ]);
    expect(kept.map((t) => t.trip.id), ['yes']);
  });

  test('the equipment axis is untouched and still has no apply rule', () {
    // It is resolved by intersecting trip ids in a provider; applying it
    // here as well would double-filter and silently drop trips.
    const filter = TripFilterState(equipmentId: 'reg');
    expect(filter.apply([trip('any')]).map((t) => t.trip.id), ['any']);
  });
}
```

The third and fifth cases both pin decisions an implementer would otherwise
guess at, and the fifth is the one that would corrupt existing behaviour.

- [ ] **Step 2: Run the test to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/trips/presentation/providers/trip_filter_state_test.dart`
Expected: FAIL, `tripType` is not a parameter of `TripFilterState`.

- [ ] **Step 3: Extend the filter state**

Add `tripType`, `startAfter`, `endBefore`, `minDiveCount` and `location` to
`TripFilterState` with constructor entries, `hasActiveFilters`, `copyWith`
clear flags, and the state's first `apply(List<TripWithStats>)`. Keep
`equipmentId` OUT of `apply`: it is resolved by intersecting trip ids in
`filteredTripsProvider`, and applying it here as well would double-filter.

- [ ] **Step 4: Write the catalog and the lowering**

`trip_fields.dart` declares `enum ExploreTripField implements ExploreField`
with the five json names above and a `TripFieldCatalog implements
FieldCatalog`. `trip_lowering.dart` exposes `lowerTripClause` and
`lowerTripMention` with the same signatures Task 4 gives for sites, and maps
a parsed time range onto `startAfter` and `endBefore` together.

- [ ] **Step 5: Register and wire**

Register `QuerySubject.trips: TripFieldCatalog()` in `SubjectCatalog`, add
`TripTarget` to `compiled_target.dart`, add the compiler branch, add an
`exploreTripResultsProvider` reading `sortedFilteredTripsProvider` and
applying the filter, add the `TripTarget` case to `ExploreSubjectResults`
rendering the trip row the trip list uses and pushing `/trips/<id>` on tap,
and add the handoff writing `tripFilterProvider` then `context.go('/trips')`.

- [ ] **Step 6: Run the tests and commit**

Run: `TMPDIR=/tmp flutter test test/features/explore test/features/trips test/l10n`

```bash
dart format lib test/features
git add lib/features/explore lib/features/trips lib/l10n/arb test/features/explore test/features/trips
git commit -m "feat(explore): search trips by type, dates, location and dive count"
```

---

### Task 7: Buddies

**Files:**
- Create: `lib/features/buddies/domain/models/buddy_filter_state.dart`
- Create: `lib/features/explore/domain/fields/buddy_fields.dart`
- Create: `lib/features/explore/domain/lowering/buddy_lowering.dart`
- Modify: `lib/features/buddies/presentation/providers/buddy_providers.dart` (a new `buddyFilterProvider`)
- Modify: the six Explore files
- Test: `test/features/buddies/domain/models/buddy_filter_state_test.dart`
- Test: `test/features/explore/domain/buddy_lowering_test.dart`

**Interfaces:**
- Consumes: `BuddyWithDiveCount` (`buddy`, `diveCount`, `lastDiveAt`, `usualRoleId`), `allBuddiesWithDiveCountProvider`.
- Produces: `BuddyFilterState`, `buddyFilterProvider`, `ExploreBuddyField`, `BuddyTarget`.

The aggregate already carries everything the spec asks for, so this is a
new filter state and nothing more.

```dart
// lib/features/buddies/domain/models/buddy_filter_state.dart
class BuddyFilterState {
  final int? minDiveCount;
  final DateTime? lastDiveAfter;
  final DateTime? lastDiveBefore;

  /// `BuddyWithDiveCount.usualRoleId`: the role the diver most often logs
  /// this buddy in, not a role stored on the buddy.
  final String? roleId;

  const BuddyFilterState({
    this.minDiveCount,
    this.lastDiveAfter,
    this.lastDiveBefore,
    this.roleId,
  });

  bool get hasActiveFilters =>
      minDiveCount != null ||
      lastDiveAfter != null ||
      lastDiveBefore != null ||
      roleId != null;

  List<BuddyWithDiveCount> apply(List<BuddyWithDiveCount> buddies) =>
      buddies.where((b) {
        if (minDiveCount != null && b.diveCount < minDiveCount!) return false;
        if (roleId != null && b.usualRoleId != roleId) return false;
        final last = b.lastDiveAt;
        // Never dived with: not after any cutoff, but genuinely before one.
        if (lastDiveAfter != null &&
            (last == null || !last.isAfter(lastDiveAfter!))) {
          return false;
        }
        if (lastDiveBefore != null &&
            last != null &&
            !last.isBefore(lastDiveBefore!)) {
          return false;
        }
        return true;
      }).toList();
}
```

- [ ] **Step 1: Write the failing filter-state test**

One case per rule, following Task 4's shape. The three that earn their keep
are the null asymmetries: a buddy never dived with must be excluded by
`minDiveCount`, excluded by `lastDiveAfter`, and INCLUDED by
`lastDiveBefore`. Write them as three separate tests so a failure names the
rule that broke.

- [ ] **Step 2: Run it to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/buddies/domain/models/buddy_filter_state_test.dart`
Expected: FAIL, the file does not exist.

- [ ] **Step 3: Write the filter state**

The code above, plus a `buddyFilterProvider` (`StateProvider<BuddyFilterState>`)
in `buddy_providers.dart` for the handoff to write.

**Before writing it, check whether `Buddy` has a favourite flag.** The spec
lists a `favoritesOnly` axis; the entity appears not to carry one. If it
does not, drop the axis and record that in the deviations rather than
inventing a column.

- [ ] **Step 4: Write the catalog and the lowering**

Fields: `buddyDiveCount` (count), `buddyLastDiveAfter` and
`buddyLastDiveBefore` (time), `buddyRole` (enum of the diver's role ids,
resolved through the `NameIndex` rather than hardcoded).

"Who have I dived with most this year" carries no clause at all: it is a
time mention plus a sort. Explore does not sort, so the honest compile is a
`BuddyTarget` with `lastDiveAfter` from the time mention and the results
ordered by the buddy list's existing sort. Test that explicitly, so the
partial answer is a recorded decision rather than a surprise.

- [ ] **Step 5: Register and wire**

Register the catalog, add `BuddyTarget`, add the compiler branch, add an
`exploreBuddyResultsProvider` reading `allBuddiesWithDiveCountProvider` and
applying the filter, add the results case rendering the buddy row the buddy
list uses and pushing `/buddies/<id>` on tap, and add the handoff writing
`buddyFilterProvider` then `context.go('/buddies')`.

- [ ] **Step 6: Run the tests and commit**

Run: `TMPDIR=/tmp flutter test test/features/explore test/features/buddies test/l10n`

```bash
dart format lib test/features
git add lib/features/explore lib/features/buddies lib/l10n/arb test/features/explore test/features/buddies
git commit -m "feat(explore): search buddies by dive count, last dive and role"
```

---

### Task 8: Species

**Files:**
- Create: `lib/features/marine_life/domain/models/species_filter_state.dart`
- Create: `lib/features/explore/domain/fields/species_fields.dart`
- Create: `lib/features/explore/domain/lowering/species_lowering.dart`
- Modify: `lib/features/marine_life/presentation/providers/seen_species_providers.dart` (a new `speciesFilterProvider`)
- Modify: `lib/features/marine_life/presentation/pages/species_page.dart`
- Modify: the six Explore files
- Test: `test/features/marine_life/domain/models/species_filter_state_test.dart`
- Test: `test/features/marine_life/presentation/pages/species_page_filter_test.dart`
- Test: `test/features/explore/domain/species_lowering_test.dart`

**Interfaces:**
- Consumes: `SeenSpecies` (`totalSightings`, `diveCount`, `siteCount`, `firstSeen`, `lastSeen`), `filterSeenSpecies`, `SeenSpeciesSort`, `SpeciesCategory`.
- Produces: `SpeciesFilterState`, `speciesFilterProvider`, `ExploreSpeciesField`, `SpeciesTarget`.

This is the only subject whose page keeps its filter in local widget state
(`_query`, `_category`, `_sort` in `_SpeciesPageState`). The handoff needs
somewhere to write, so the task lifts those three into a provider and has
the page read it. That is a real change to a working page, so it gets its
own widget test asserting the page still filters, sorts and searches exactly
as before.

- [ ] **Step 1: Write the failing filter-state test**

Cover each numeric and date axis, and one case asserting the wrapped
`filterSeenSpecies` still applies the query, category and sort unchanged.

- [ ] **Step 2: Run it to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/marine_life/domain/models/species_filter_state_test.dart`
Expected: FAIL, the file does not exist.

- [ ] **Step 3: Write the filter state**

`SpeciesFilterState` wraps the existing pure function rather than
reimplementing it:

```dart
  List<SeenSpecies> apply(
    List<SeenSpecies> entries, {
    required SpeciesNameOf nameOf,
  }) {
    final narrowed = filterSeenSpecies(
      entries,
      query: query,
      category: category,
      sort: sort,
      nameOf: nameOf,
    );
    return narrowed.where((e) {
      if (minSightings != null && e.totalSightings < minSightings!) {
        return false;
      }
      if (maxSightings != null && e.totalSightings > maxSightings!) {
        return false;
      }
      if (firstSeenAfter != null && !e.firstSeen.isAfter(firstSeenAfter!)) {
        return false;
      }
      if (lastSeenBefore != null && !e.lastSeen.isBefore(lastSeenBefore!)) {
        return false;
      }
      return true;
    }).toList();
  }
```

`firstSeen` and `lastSeen` are non-nullable on `SeenSpecies`, so none of the
null asymmetries from Tasks 4 to 7 apply here.

- [ ] **Step 4: Lift the page's local state into a provider**

Add `speciesFilterProvider` (`StateProvider<SpeciesFilterState>`) to
`seen_species_providers.dart`, and change `_SpeciesPageState` to read and
write it instead of `_query`, `_category` and `_sort`. Check the exact shape
of those three fields before moving them. Write
`species_page_filter_test.dart` asserting the page still searches, filters
by category and sorts exactly as before; this is a change to a working page,
so the test is the safety net, not a formality.

- [ ] **Step 5: Write the catalog and the lowering**

Fields: `speciesSightings` (count, and `maxSightings` is what makes "species
I have only seen once" work as `eq 1`), `speciesFirstSeenAfter` and
`speciesLastSeenBefore` (time), `speciesCategory` (enum of
`SpeciesCategory.values`).

"Species I have only seen once" compiles to
`SpeciesFilterState(minSightings: 1, maxSightings: 1)` from a single `eq`
clause. Test that explicitly: an `eq` that set only `minSightings` would
return every species instead of the rare ones, which is the opposite answer.

- [ ] **Step 6: Register and wire**

Register the catalog, add `SpeciesTarget`, add the compiler branch, add an
`exploreSpeciesResultsProvider` reading `seenSpeciesProvider` and applying
the filter, add the results case rendering `SeenSpeciesTile` and pushing
`/species/<id>` on tap, and add the handoff writing `speciesFilterProvider`
then `context.go('/species')`.

- [ ] **Step 7: Run the tests and commit**

Run: `TMPDIR=/tmp flutter test test/features/explore test/features/marine_life test/l10n`

```bash
dart format lib test/features
git add lib/features/explore lib/features/marine_life lib/l10n/arb test/features/explore test/features/marine_life
git commit -m "feat(explore): search species by sightings, dates and category"
```

---

### Task 9: Dive centers

**Files:**
- Create: `lib/features/dive_centers/domain/entities/dive_center_with_dive_count.dart`
- Create: `lib/features/dive_centers/domain/models/dive_center_filter_state.dart`
- Create: `lib/features/explore/domain/fields/center_fields.dart`
- Create: `lib/features/explore/domain/lowering/center_lowering.dart`
- Modify: `lib/features/dive_centers/data/repositories/dive_center_repository.dart`
- Modify: `lib/features/dive_centers/presentation/providers/dive_center_providers.dart`
- Modify: the six Explore files
- Test: `test/features/dive_centers/data/repositories/dive_center_dive_counts_test.dart`
- Test: `test/features/dive_centers/domain/models/dive_center_filter_state_test.dart`
- Test: `test/features/explore/domain/center_lowering_test.dart`

**Interfaces:**
- Consumes: `DiveCenter` (`country`, `city`, `rating`), `allDiveCentersProvider`.
- Produces:
  - `class DiveCenterWithDiveCount { final DiveCenter center; final int diveCount; }`
  - `DiveCenterRepository.getDiveCountsByCenter({String? diverId}) -> Future<Map<String, int>>`
  - `DiveCenterFilterState`, `diveCenterFilterProvider`, `ExploreCenterField`, `CenterTarget`.

Centres have no aggregate at all: a list row reads
`diveCenterDiveCountProvider(id)`, one provider per centre. "Centers in
Mexico I have used more than twice" needs the batch query, so it comes
first, mirroring Task 5's shape but over the single `dives.dive_center_id`
column rather than a union.

- [ ] **Step 1: Write the failing repository test**

One dive per centre plus a centre with none, asserting the map counts each
correctly and omits the unused centre, following Task 5's shape.

- [ ] **Step 2: Run it to verify it fails**

Run: `TMPDIR=/tmp flutter test test/features/dive_centers/data/repositories/dive_center_dive_counts_test.dart`
Expected: FAIL, `getDiveCountsByCenter` is not defined.

- [ ] **Step 3: Write the aggregate and the query**

One `GROUP BY dives.dive_center_id`, carrying the same
`// stats-scope-exempt:` reasoning as Task 5: a usage count is not a
statistic, and an excluded dive still means the diver used the centre.

- [ ] **Step 4: Write the filter state**

Fields: `centerCountry` (free text), `centerCity` (free text),
`centerDiveCount` (count), `centerRating` (count, 1 to 5).

**No `lastVisited` field.** The app stores no "last dived with this centre"
anywhere, and deriving one would mean a second aggregate this task does not
need. Record the omission in the deviations rather than approximating it
from the centre's own `updatedAt`, which means something else entirely.

- [ ] **Step 5: Write the catalog and the lowering**

The country mention is a `place` kind, which the `NameIndex` already
resolves for sites. Decide explicitly whether a `place` mention under the
centre subject lowers to `centerCountry`, and test it; leaving it to the
resolver's default would silently produce a site-shaped result.

- [ ] **Step 6: Register and wire**

Register the catalog, add `CenterTarget`, add the compiler branch, add an
`exploreCenterResultsProvider` joining `allDiveCentersProvider` with the new
counts and applying the filter, add the results case rendering
`DiveCenterListTile` and pushing `/dive-centers/<id>` on tap, and add the
handoff writing `diveCenterFilterProvider` then
`context.go('/dive-centers')`.

- [ ] **Step 7: Run the tests and commit**

Run: `TMPDIR=/tmp flutter test test/features/explore test/features/dive_centers test/l10n`

```bash
dart format lib test/features
git add lib/features/explore lib/features/dive_centers lib/l10n/arb test/features/explore test/features/dive_centers
git commit -m "feat(explore): search dive centers by place, rating and use"
```

---

### Task 10: Charts for the other subjects

**Files:**
- Modify: `lib/features/explore/domain/chart_selection.dart`
- Modify: `lib/features/explore/presentation/providers/explore_providers.dart`
- Modify: `lib/features/explore/presentation/widgets/explore_charts.dart`
- Test: `test/features/explore/domain/chart_selection_subject_test.dart`

**Interfaces:**
- Consumes: `CompiledTarget`, `ExploreField`.
- Produces: `selectCharts` gains a `required QuerySubject subject` parameter and a `ChartKind.subjectCounts`.

The spec fixes this: "charts for non-dive subjects are a single
count-per-entity bar chart". One chart, not three, and never a trend: a list
of sites has no time axis.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/explore/domain/chart_selection_subject_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/explore/domain/chart_selection.dart';
import 'package:submersion/features/explore/domain/dive_field_catalog.dart';
import 'package:submersion/features/explore/domain/explore_field.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  List<ChartRequest> forSubject(
    QuerySubject subject, {
    List<ExploreField> numericFields = const [],
  }) => selectCharts(
    subject: subject,
    numericFields: numericFields,
    resolvedEntityCounts: const {},
  );

  test('a dive query keeps the phase 1 rules exactly', () {
    final charts = forSubject(
      QuerySubject.dives,
      numericFields: [ExploreDiveField.depth],
    );
    expect(charts.first.kind, ChartKind.divesOverTime);
    expect(charts.map((c) => c.kind), contains(ChartKind.depthTrend));
  });

  test('another subject gets exactly one count chart', () {
    for (final subject in QuerySubject.values) {
      if (subject == QuerySubject.dives) continue;
      final charts = forSubject(subject);
      expect(charts, hasLength(1), reason: subject.name);
      expect(charts.single.kind, ChartKind.subjectCounts);
    }
  });

  test('a numeric field on another subject adds no trend', () {
    // A list of sites has no time axis, so a depth trend would be a chart
    // of nothing. The dive rules must not leak across the subject switch.
    final charts = forSubject(
      QuerySubject.sites,
      numericFields: [ExploreDiveField.depth],
    );
    expect(charts.single.kind, ChartKind.subjectCounts);
  });

  test('the three-chart cap still holds', () {
    final charts = selectCharts(
      subject: QuerySubject.dives,
      numericFields: [
        ExploreDiveField.depth,
        ExploreDiveField.waterTemp,
        ExploreDiveField.bottomTime,
      ],
      resolvedEntityCounts: const {MentionKind.buddy: 3},
    );
    expect(charts.length, lessThanOrEqualTo(kMaxExploreCharts));
  });
}
```

- [ ] **Step 2: Run it failing, then implement**

Widen `numericFields` to `List<ExploreField>`, add the
`subject` parameter and an early return for a non-dive subject, add
`ChartKind.subjectCounts`, and have `exploreChartDataProvider` answer it by
counting the dives behind each result entity: dives per site for sites,
dives per buddy for buddies, and so on, reusing the statistics repository's
existing top-entity queries where they exist. For a subject with no such
query, count from the aggregate the results provider already loaded rather
than adding a query.

Update the three existing `selectCharts` call sites and their tests. Run
`TMPDIR=/tmp flutter test test/features/explore` and commit:

```bash
git commit -m "feat(explore): one count chart for a non-dive subject"
```

---

### Task 11: The prompt, the vocabulary and schema v3

**Files:**
- Modify: `lib/features/explore/domain/query_model.dart` (`kQuerySchemaVersion` to 3)
- Modify: `lib/features/explore/domain/nl_engine.dart`
- Modify: `lib/features/explore/presentation/chip_labeler.dart`
- Modify: the 11 ARB files
- Test: `test/features/explore/domain/nl_prompt_test.dart` (extend)

**Interfaces:**
- Consumes: `SubjectCatalog.allJsonNames` (Task 1).

The version bump is what makes a stale adapter fail loudly rather than emit
field names this build cannot place. The Swift adapter builds its schema
from the vocabulary Dart ships, so it picks the new fields up with no native
change, and the Android adapter is prompt-only.

The vocabulary swaps `DiveFieldCatalog.jsonNames` for
`SubjectCatalog.allJsonNames`. One flat list, as Task 1 decided.

The prompt gains one line per subject naming that subject's fields, and two
worked examples: a site sentence and an equipment sentence, since those are
the two shapes the spec names.

**The budget is the constraint.** `nl_prompt_test.dart` asserts the
instructions stay under 7,000 characters, because the Apple context is 4,096
tokens on shipping hardware and the schema shares it. Measured before
writing this plan, the phase 2 prompt is **4,276** characters. Six subject
field lines at roughly 200 characters each plus two examples at roughly 300
lands near 5,900. That fits, but only just:

- [ ] **Step 1: Add the fields and examples, then measure before anything else.**

Write a throwaway test that prints `NlPrompt.instructions().length` and run
it. If the result exceeds 6,500, shorten the per-subject lines rather than
raising the budget: the budget is a hardware limit, not a style rule.
Delete the throwaway test afterwards.

- [ ] **Step 2: Extend the prompt test**

```dart
  test('the prompt names every field of every subject', () {
    final text = NlPrompt.instructions();
    for (final name in SubjectCatalog.allJsonNames) {
      expect(text, contains(name), reason: name);
    }
  });

  test('the prompt names every subject', () {
    final text = NlPrompt.instructions();
    for (final subject in QuerySubject.values) {
      expect(text, contains(subject.name), reason: subject.name);
    }
  });

  test('the vocabulary ships the union, not just the dive fields', () {
    expect(NlPrompt.vocabulary()['fields'], SubjectCatalog.allJsonNames);
    expect(NlPrompt.vocabulary()['schemaVersion'], 3);
  });
```

- [ ] **Step 3: Labels**

`chip_labeler.fieldName` becomes a dispatch on the runtime type:

```dart
  String fieldName(ExploreField f) => switch (f) {
    ExploreDiveField() => _diveFieldName(f),
    ExploreSiteField() => _siteFieldName(f),
    // ... one per subject
    _ => f.jsonName,
  };
```

The `_ => f.jsonName` fallback is deliberate: a field added without a label
shows its raw name rather than throwing in front of a diver, and a test
asserts no catalog field falls through:

```dart
  test('every field has a label, so none falls back to its json name', () {
    final labeler = ChipLabeler(AppLocalizationsEn(), unitFormatter);
    for (final subject in QuerySubject.values) {
      for (final field in SubjectCatalog.of(subject)!.fields) {
        expect(
          labeler.fieldName(field),
          isNot(field.jsonName),
          reason: field.jsonName,
        );
      }
    }
  });
```

One ARB key per field across all eleven locales. Insert as text anchored on
a neighbouring key; a JSON round-trip reformats unrelated metadata blocks.
German says AMV, never SAC.

- [ ] **Step 4: Fix the version fan-out**

Bumping `kQuerySchemaVersion` breaks every test that hardcoded 2, which is
the point. Point them at the constant; the rejection test in
`query_model_test.dart` already uses `kQuerySchemaVersion +/- 1` and needs
no change.

- [ ] **Step 5: Run and commit**

Run: `TMPDIR=/tmp flutter test test/features/explore test/l10n`

```bash
git commit -m "feat(explore): schema v3, per-subject fields in the prompt and chip labels"
```

---

### Task 12: Whole-project verification and the pull request

**Files:**
- Modify: `docs/superpowers/specs/2026-09-19-explore-natural-language-search-design.md` (a phase 3 deviations section)

- [ ] **Step 1: Architecture guards**

Run: `TMPDIR=/tmp flutter test test/architecture test/core/database/dive_stats_scope_census_test.dart`
Expected: PASS. `test/architecture` scans all of `lib/`, and this phase adds
around twenty files, so it must run even though no task listed it.

- [ ] **Step 2: Record the deviations**

Append a "phase 3" section recording at least: whether `NameEntry` gained a
country field or the place mention lowered another way (Task 4); the exact
equipment usage query and the `UNION` decision (Task 5); that trips keep the
equipment axis out of `apply` (Task 6); that buddies dropped `favoritesOnly`
because `Buddy` has no such flag, and that "dived with most" compiles to a
time filter without a sort (Task 7); that the species page's local state
moved into a provider (Task 8); that centres have no `lastVisited` because
the app stores none (Task 9); and the measured prompt length (Task 11).

- [ ] **Step 3: Format, analyze, full suite**

```bash
dart format .
flutter analyze
TMPDIR=/tmp flutter test
```

Expected: format reports 0 changed, analyze reports `No issues found!`, and
the suite passes. Run the suite unpiped so the exit code is real, and read
the summary line as well as the code: a harness crash can print failures and
still exit 0.

- [ ] **Step 4: Commit and push**

```bash
git add docs/superpowers/specs/2026-09-19-explore-natural-language-search-design.md
git commit -m "docs(explore): record the phase 3 deviations"
TMPDIR=/tmp git push -u origin <branch>
```

- [ ] **Step 5: Open the pull request**

The body says `Closes #2195`, names the seven subjects now searchable, notes
that the query schema is now v3 and why a stale adapter fails loudly, and
repeats the manual smoke still owed from phase 1: macOS with Apple
Intelligence hardware and Android with AICore, now also checking that the
model reaches for the per-subject fields rather than forcing everything into
`dives`. No tool attribution anywhere.

---

## Self-review notes

- **Spec coverage.** The spec's phase 3 table names six subjects with a
  lowering target each: equipment (Task 5), sites (Task 4), buddies
  (Task 7), species (Task 8), trips (Task 6), centres (Task 9). It also asks
  that subject mentions reuse the same `NameIndex` (Tasks 4 to 9 all do),
  that results reuse each subject's existing list content widget with its
  detail route (Task 3's dispatch, one case per subject task), that handoffs
  write that subject's filter provider (same), and that charts for non-dive
  subjects are a single count-per-entity bar (Task 10). The sealed subject
  dispatch the spec asks for is Task 2.
- **Two spec items are not implementable as written**, and each task says
  so rather than inventing a column: buddies have no favourite flag, and
  centres have no last-visited date.
- **Type consistency.** `ExploreField`, `FieldSpec`, `FieldCatalog`,
  `SubjectCatalog`, `CompiledTarget` and its seven variants,
  `lowerSiteClause` and its five siblings, `EquipmentUsageTotals`,
  `DiveCenterWithDiveCount`, `BuddyFilterState`, `SpeciesFilterState`,
  `DiveCenterFilterState`, `ExploreSubjectResults` and `ExploreHandoffBar`
  are spelled identically across tasks.
- **Soft spots to verify against the compiler rather than trust**, each
  called out inline where it is used: whether `NameEntry` carries a country
  (Task 4); `DiveTanksCompanion.insert`'s required parameters and the
  two-branch `WHERE` interpolation in the usage query (Task 5); whether
  `Buddy` really has no favourite flag (Task 7); the exact shape of
  `_SpeciesPageState`'s three fields when lifting them (Task 8); and the
  measured prompt length before the budget assertion (Task 11).
- **Deliberate compression, stated so an executor is not surprised.**
  Tasks 1 to 5 carry full code for every step. Tasks 6 to 9 carry full code
  only where the decision is not mechanical: the trip filter test, the buddy
  filter state, the species `apply`, and every place a null value means
  something non-obvious. Their catalog, registration and wiring steps name
  the exact files, providers, routes and commit messages but point at Task 4
  for the shape, because those four subjects really are the same code with a
  different field list, and repeating it four times would bury the decisions
  that differ. If an executor reading Task 7 alone cannot proceed, read
  Task 4 first; that is the only backward reference in the plan.
- **Known judgement call.** One flat field vocabulary rather than a schema
  per subject, with the compiler rejecting a mismatched field as
  `wrongSubject`. Per-subject schemas would mean the Swift adapter rebuilding
  its constrained schema per sentence, and the Android adapter has no schema
  at all to rebuild. The cost is that the model can write a field the subject
  does not own; Tasks 4 to 9 each test that this produces a visible unplaced
  chip rather than a wrong filter.
