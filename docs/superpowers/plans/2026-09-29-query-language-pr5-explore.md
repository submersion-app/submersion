# Entity Query Language PR 5: Explore on the Shared Registry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Explore compiles a sentence to one `QueryNode` over the dive query registry, and one name index serves both Explore's sentences and the typed query language.

**Architecture:** Explore's model contract (`ParsedQuery`, schema v2 after phase 2) is unchanged. Its compiler stops building a `DiveFilterState` and lowers every clause, mention and time phrase straight to query nodes on registry paths, taken from a curated field list whose dimensions, enum values and bounds come from the registry. The two name indexes merge into one pure `NameIndex` in `lib/core/query/names/`, loaded by one `NameIndexLoader` in `lib/features/query/data/`; the typed parser resolves against it (gaining alternate names), and Explore's fuzzy resolver reads the same entries.

**Tech Stack:** Flutter, Dart, Riverpod 3 (legacy `StateProvider`), Drift/SQLite, the entity query language (`lib/core/query`, `lib/features/query`), Explore (`lib/features/explore`).

**Spec:** `docs/superpowers/specs/2026-09-25-entity-query-language-design.md` (Program shape row 5; "Explore" under Unit 5; "Open items"). Explore's own spec: `docs/superpowers/specs/2026-09-19-explore-natural-language-search-design.md`.

## Decisions (fixed with Eric on 2026-09-29; do not re-litigate)

| Question | Decision |
| --- | --- |
| Sequencing against Explore phase 2 | Write this plan now; start implementing only after branch `ericgriffin/explore-phase2-registry-2195` has merged to main. PR 5 migrates all 25 Explore fields, including phase 2's seven. |
| The model's field vocabulary | A curated list of registry paths the model may name, keeping every current field name. Specs (dimension, enum values, bounds) come from the registry. Stored recent queries and the native constrained-decoding schema stay valid. No schema version bump. |
| The two name indexes | Unify: one index serves sentences and typed queries. |
| What the dive list and Insights receive on handoff | One query: `DiveFilterState(query: node)`, shown as query chips. |

## Calls made while planning (for Eric's review)

- **The pure index lives in core, the loader in features.** `NameIndex`, `NameEntry` and `NameTarget` move to `lib/core/query/names/name_index.dart`. The loader imports the registry, the database, the equipment attribute catalog and the species name lookup, so it lives in `lib/features/query/data/name_index_loader.dart`, as the existing loader does: `app_query_registry.dart` states "the core query package never imports a feature".
- **Visibility follows the typed index.** The unified loader uses the typed loader's explicit SQL rules (own rows, unowned rows, `is_shared` sites and trips, `equipment_shares`), not Explore's `getAll*` repository calls.
- **A typed query prints the primary name.** Every row has one primary label: the registry `name` field (a species' stored common name, an item's name). Alternate labels (a built-in species' localized name, its scientific name, an item's brand and model) resolve to the same row, and the resolved `RefValue` carries the primary label, so `parse(print(ast)) == ast` still holds. Primary labels are tried before alternates, so another row's alternate never shadows a primary name.
- **Places, attribute choices and legacy buddy names are sentence-only entries.** They carry no single row, so the typed parser skips them (`NameTarget.isRow` is false).
- **A place lowers to site place conditions, not a site id list.** "Bonaire" becomes `site.island = "Bonaire"` (or an `OR` over each column the label came from), so a saved or handed-off query stays right when a new Bonaire site is added, and its chip reads as the place rather than a list of forty sites.
- **Mentions of one kind OR together.** Sites and places, species, gear items, tags, centers, trips and computers each become one membership condition, as sites, species, gear and tags already did. Centers, trips and computers change from "the last one wins" to OR. Buddies stay AND (each resolved buddy must be on the dive), and each attribute choice stays its own AND condition.
- **Rating and bottom time bounds are whole numbers**, as the filter axes they replace were (`minRating`, `minBottomTimeMinutes`); rating's upper bound is now rounded too.
- **Explore types that collide with core are renamed**, since Explore now imports core query types: `CompiledQuery` becomes `ExploreCompilation`, `QueryCompiler` becomes `ExploreCompiler`, `CompilerContext` becomes `ExploreCompilerContext`, and Explore's `QuerySubject` becomes `ParsedSubject`. JSON names do not change.

## Global Constraints

- Branch `ericgriffin/query-lang-pr5-explore`, merged up to a main that contains Explore phase 2. The PR body says `Refs #2365` (the program issue stays open until the program closes it) and `Refs #2195`.
- No schema change: no new table, no rung, `currentSchemaVersion` unchanged.
- Explore's JSON contract (`ParsedQuery`, `kQuerySchemaVersion`, field, op, unit and mention-kind names, `QueryMention.identity`) must not change. `NameEntry.identity` keeps its exact string format, because pinned identities are stored in recent queries.
- Every `NameTarget` value keeps its current name (identities embed `target.name`).
- The native prompt stays under 7,000 characters (`nl_prompt_test.dart`).
- Parameterized SQL only: the diver id is bound; table and column names come from registry constants.
- Units respect the diver's settings: bare numbers ground through core `groundToStorage` with `queryUnitPrefsProvider`.
- Files stay at or under 800 lines; never grow a file already over 800.
- TDD: every new test is watched failing before the code that passes it. A characterization test that pins existing behavior before a refactor is watched passing, and that is stated in its step.
- Tests restore any process-wide state they change (CI bundles test files in one isolate). Paths in tests use `p.join` and `Directory.systemTemp`.
- Run `dart format .` before each commit. Stage explicit paths, never `git add -A`.
- No em-dashes, en-dashes as punctuation, double hyphens or spaced hyphens in prose anywhere, including comments and commit messages. No attribution trailers.
- Codegen: Bash refuses a bare `build` token, so run `dart run build_runner build --delete-conflicting-outputs` from a script file.

## Review Focus

1. **A recent query saved before PR 5 reruns unchanged.** A stored `ParsedQuery` with a pinned mention identity (for example `buddyId:b1::::`) reruns to the same chips and the same dives. Test: Task 3 Step 1 (`identity keeps its stored format`) and Task 5 Step 1 (fixture case `pinned buddy`).
2. **A German diver types a built-in species' German name in the typed editor.** It resolves to the species and prints the stored primary name. Test: Task 1 Step 1 (`an alternate label resolves to the row and prints the primary label`) and Task 2 Step 1 (`a built-in species gets its localized name as an alternate`).
3. **A label shared across rows.** When one item's brand and model equals another item's name, the typed parser picks the item whose primary name it is. Test: Task 1 Step 1 (`a primary name wins over another row's alternate`).
4. **A handed-off query is editable and savable in the dive list.** The node Explore hands over carries real primary labels, so its chips read as names and a saved query stores labels, not ids. Test: Task 6 Step 1 (`the handoff carries named refs`).
5. **A place label that is both a region and an island** lowers to an `OR` over both columns and finds dives at either. Test: Task 5 Step 1 (`a merged place ORs its columns`).

---

## Pre-flight (before Task 1)

- [ ] **Step 1: Confirm phase 2 has merged and merge main**

```bash
git fetch origin
git log --oneline origin/main | grep -m3 -i "phase 2\|derived\|2195"
git merge --no-edit origin/main
```

Expected: phase 2's squash commit is on main; the merge succeeds.

- [ ] **Step 2: Confirm the phase 2 names this plan consumes**

```bash
grep -n "sac\|finalStop\|finding\|pressureRate" lib/features/explore/domain/dive_field_catalog.dart | head -20
grep -n "kQuerySchemaVersion\|barMin\|psiMin" lib/features/explore/domain/query_model.dart
grep -n "barMin\|psiMin\|pressureRate" lib/core/query/domain/query_value.dart lib/core/query/registry/query_field.dart lib/core/query/units/unit_prefs.dart
grep -n "findingQueryEntity" lib/features/dive_log/query/dive_child_query_entities.dart
grep -n "sacTrend" lib/features/explore/domain/chart_selection.dart
```

Expected:
- `ExploreDiveField` has `sac`, `sacTrend`, `sacChange`, `finalStop`, `finalStopExcursion`, `finalStopDuration` and `finding`.
- `kQuerySchemaVersion = 2`, and `ClauseUnit.barMin` and `ClauseUnit.psiMin` exist.
- Core has `QueryUnit.barMin`, `QueryUnit.psiMin` and `FieldDimension.pressureRate`.
- `findingQueryEntity` exists.
- `ChartKind.sacTrend` exists.

If any name differs, use the merged name everywhere this plan uses it, and note it in the ledger.

- [ ] **Step 3: Initialize the worktree**

```bash
git submodule update --init --recursive
flutter pub get
```

Then run codegen from a script (`dart run build_runner build --delete-conflicting-outputs`), and `flutter analyze --fatal-infos`. Expected: no issues.

---

### Task 1: The unified `NameIndex` in core

**Files:**
- Create: `lib/core/query/names/name_index.dart`
- Modify: `lib/core/query/syntax/query_parser.dart:19-21` (the stale comment)
- Test: `test/core/query/names/name_index_test.dart`

**Interfaces:**
- Consumes: `NameResolver`, `NameEntries` (`lib/core/query/syntax/query_parser.dart`); `QuerySubject`; `RefValue`; `suggestNames` (`lib/core/query/syntax/query_suggestions.dart`).
- Produces:
  - `enum NameTarget { siteId, sitePlace, speciesId, equipmentId, attrChoice, buddyId, legacyBuddyName, tagId, centerId, tripId, computerId, siteTypeId, courseId, diveTypeId }` with `bool get isRow`.
  - `NameTarget rowTargetFor(QuerySubject subject)`.
  - `class NameEntry`, with fields:
    - `QuerySubject subject`, `String label`, `List<String> ids`, `NameTarget target`;
    - `int rank`, `bool primary`, `String? attrKey`, `String? attrChoice`;
    - `List<String> placeFields`;
    - the getter `String identity`.
  - `class NameIndex implements NameResolver, NameEntries`:
    - `NameIndex(Iterable<NameEntry>)`, `factory NameIndex.fromRefs(Map<QuerySubject, List<RefValue>>)`, `static final NameIndex empty`;
    - `List<NameEntry> entries`, `Iterable<NameEntry> forSubject(QuerySubject)`, `List<RefValue> refs(QuerySubject)`, `String? labelOf(QuerySubject, String id)`;
    - `resolve`, `candidates`, `refEntries`.

- [ ] **Step 1: Write the failing test**

Create `test/core/query/names/name_index_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/names/name_index.dart';

NameEntry _row(
  QuerySubject subject,
  String id,
  String label, {
  bool primary = true,
  int rank = 0,
}) => NameEntry(
  subject: subject,
  label: label,
  ids: [id],
  target: rowTargetFor(subject),
  primary: primary,
  rank: rank,
);

void main() {
  test('fromRefs holds one primary row per ref', () {
    final index = NameIndex.fromRefs({
      QuerySubject.sites: const [RefValue('s1', 'Salt Pier')],
    });
    expect(index.refs(QuerySubject.sites), const [RefValue('s1', 'Salt Pier')]);
    expect(index.labelOf(QuerySubject.sites, 's1'), 'Salt Pier');
    expect(index.resolve(QuerySubject.sites, ' salt pier '), const RefValue('s1', 'Salt Pier'));
  });

  test('an alternate label resolves to the row and prints the primary label', () {
    final index = NameIndex([
      _row(QuerySubject.species, 'sp1', 'Green sea turtle', rank: 1),
      _row(QuerySubject.species, 'sp1', 'Gruene Meeresschildkroete', primary: false),
      _row(QuerySubject.species, 'sp1', 'Chelonia mydas', primary: false, rank: 2),
    ]);
    expect(
      index.resolve(QuerySubject.species, 'gruene meeresschildkroete'),
      const RefValue('sp1', 'Green sea turtle'),
    );
    expect(
      index.resolve(QuerySubject.species, 'Chelonia mydas'),
      const RefValue('sp1', 'Green sea turtle'),
    );
    expect(index.refs(QuerySubject.species), const [RefValue('sp1', 'Green sea turtle')]);
  });

  test('a primary name wins over another row\'s alternate', () {
    final index = NameIndex([
      _row(QuerySubject.equipment, 'e2', 'Apeks XTX50', primary: false, rank: 1),
      _row(QuerySubject.equipment, 'e1', 'Apeks XTX50'),
    ]);
    expect(index.resolve(QuerySubject.equipment, 'Apeks XTX50')!.id, 'e1');
  });

  test('sentence-only entries never resolve a typed ref', () {
    final index = NameIndex(const [
      NameEntry(
        subject: QuerySubject.sites,
        label: 'Bonaire',
        ids: ['s1', 's2'],
        target: NameTarget.sitePlace,
        placeFields: ['island'],
      ),
      NameEntry(
        subject: QuerySubject.buddies,
        label: 'Bob',
        ids: [],
        target: NameTarget.legacyBuddyName,
        rank: 1,
      ),
    ]);
    expect(index.resolve(QuerySubject.sites, 'Bonaire'), isNull);
    expect(index.resolve(QuerySubject.buddies, 'Bob'), isNull);
    expect(index.refs(QuerySubject.sites), isEmpty);
    expect(index.forSubject(QuerySubject.sites), hasLength(1));
  });

  test('identity keeps its stored format', () {
    const buddy = NameEntry(
      subject: QuerySubject.buddies,
      label: 'Ana',
      ids: ['b1'],
      target: NameTarget.buddyId,
    );
    const legacy = NameEntry(
      subject: QuerySubject.buddies,
      label: 'Bob',
      ids: [],
      target: NameTarget.legacyBuddyName,
    );
    const choice = NameEntry(
      subject: QuerySubject.equipment,
      label: 'Trilaminate',
      ids: [],
      target: NameTarget.attrChoice,
      attrKey: 'material',
      attrChoice: 'trilaminate',
    );
    expect(buddy.identity, 'buddyId:b1::::');
    expect(legacy.identity, 'legacyBuddyName::::Bob');
    expect(choice.identity, 'attrChoice::material:trilaminate:');
  });

  test('candidates suggest row labels only', () {
    final index = NameIndex([
      _row(QuerySubject.sites, 's1', 'Salt Pier'),
      const NameEntry(
        subject: QuerySubject.sites,
        label: 'Salt Island',
        ids: ['s9'],
        target: NameTarget.sitePlace,
        placeFields: ['island'],
      ),
    ]);
    expect(index.candidates(QuerySubject.sites, 'Salt Pie'), ['Salt Pier']);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/query/names/name_index_test.dart`
Expected: compilation FAIL, `Target of URI doesn't exist: 'package:submersion/core/query/names/name_index.dart'`.

- [ ] **Step 3: Write the index**

Create `lib/core/query/names/name_index.dart`:

```dart
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/syntax/query_suggestions.dart';

/// What a label lowers to when a sentence or a typed query names it
/// (#2365). The names are stored inside pinned identities, so they never
/// change.
enum NameTarget {
  siteId,
  sitePlace,
  speciesId,
  equipmentId,
  attrChoice,
  buddyId,
  legacyBuddyName,
  tagId,
  centerId,
  tripId,
  computerId,
  siteTypeId,
  courseId,
  diveTypeId;

  /// Whether the entry names one row a typed ref can hold. A place, an
  /// attribute choice and a legacy buddy name are for sentences only.
  bool get isRow => switch (this) {
    sitePlace || attrChoice || legacyBuddyName => false,
    _ => true,
  };
}

/// The row target for a ref subject.
NameTarget rowTargetFor(QuerySubject subject) => switch (subject) {
  QuerySubject.sites => NameTarget.siteId,
  QuerySubject.species => NameTarget.speciesId,
  QuerySubject.equipment => NameTarget.equipmentId,
  QuerySubject.buddies => NameTarget.buddyId,
  QuerySubject.tags => NameTarget.tagId,
  QuerySubject.centers => NameTarget.centerId,
  QuerySubject.trips => NameTarget.tripId,
  QuerySubject.computers => NameTarget.computerId,
  QuerySubject.siteTypes => NameTarget.siteTypeId,
  QuerySubject.courses => NameTarget.courseId,
  QuerySubject.diveTypes => NameTarget.diveTypeId,
  _ => throw ArgumentError.value(subject, 'subject', 'not a ref subject'),
};

/// One label the diver's data offers, and what it maps to.
class NameEntry {
  const NameEntry({
    required this.subject,
    required this.label,
    required this.ids,
    required this.target,
    this.rank = 0,
    this.primary = false,
    this.attrKey,
    this.attrChoice,
    this.placeFields = const [],
  });

  final QuerySubject subject;
  final String label;

  /// One id for a row target; every site id under a place; empty for an
  /// attribute choice or a legacy buddy name (the label is the value).
  final List<String> ids;
  final NameTarget target;

  /// Match-group order for sentences; lower ranks are tried first.
  final int rank;

  /// The one label a typed ref prints for its row: the registry name.
  final bool primary;
  final String? attrKey;
  final String? attrChoice;

  /// The site columns a place label came from, in the order country,
  /// region, island, city.
  final List<String> placeFields;

  /// Identity for deduplication and for a pinned pick. Its format is
  /// stored in recent queries; never change it.
  String get identity =>
      '${target.name}:${ids.join(',')}:${attrKey ?? ''}:${attrChoice ?? ''}:'
      '${target == NameTarget.legacyBuddyName ? label : ''}';
}

/// A snapshot of every name the diver's data offers (#2365): the typed
/// parser resolves `site = "Salt Pier"` through [resolve], the builder's
/// pickers list [refs], a saved query checks its ids through [labelOf],
/// and Explore's resolver matches sentences against [forSubject].
class NameIndex implements NameResolver, NameEntries {
  NameIndex(Iterable<NameEntry> entries) : entries = List.unmodifiable(entries) {
    for (final e in this.entries) {
      _bySubject.putIfAbsent(e.subject, () => []).add(e);
      if (e.primary && e.target.isRow) {
        final id = e.ids.single;
        _labels.putIfAbsent(e.subject, () => {})[id] = e.label;
        _refs.putIfAbsent(e.subject, () => []).add(RefValue(id, e.label));
      }
    }
    for (final list in _bySubject.values) {
      // Primary names first, then alternates by rank, so another row's
      // alternate never shadows a primary name.
      list.sort((a, b) {
        if (a.primary != b.primary) return a.primary ? -1 : 1;
        return a.rank.compareTo(b.rank);
      });
    }
  }

  /// One primary row per ref, for tests and for callers with bare refs.
  factory NameIndex.fromRefs(Map<QuerySubject, List<RefValue>> refs) =>
      NameIndex([
        for (final e in refs.entries)
          for (final r in e.value)
            NameEntry(
              subject: e.key,
              label: r.label,
              ids: [r.id],
              target: rowTargetFor(e.key),
              primary: true,
            ),
      ]);

  static final NameIndex empty = NameIndex(const []);

  final List<NameEntry> entries;
  final _bySubject = <QuerySubject, List<NameEntry>>{};
  final _labels = <QuerySubject, Map<String, String>>{};
  final _refs = <QuerySubject, List<RefValue>>{};

  Iterable<NameEntry> forSubject(QuerySubject subject) =>
      _bySubject[subject] ?? const [];

  /// Every row of [subject] by its primary label.
  List<RefValue> refs(QuerySubject subject) => _refs[subject] ?? const [];

  @override
  Iterable<RefValue> refEntries(QuerySubject kind) => refs(kind);

  String? labelOf(QuerySubject subject, String id) => _labels[subject]?[id];

  /// An exact, case-insensitive match on any row label, primary names
  /// first. The ref carries the primary label, so printing it and parsing
  /// the print gives back the same ref.
  @override
  RefValue? resolve(QuerySubject kind, String text) {
    final wanted = text.trim().toLowerCase();
    if (wanted.isEmpty) return null;
    for (final e in forSubject(kind)) {
      if (!e.target.isRow) continue;
      if (e.label.trim().toLowerCase() != wanted) continue;
      final id = e.ids.single;
      return RefValue(id, labelOf(kind, id) ?? e.label);
    }
    return null;
  }

  @override
  List<String> candidates(QuerySubject kind, String text) => suggestNames(
    text,
    {
      for (final e in forSubject(kind))
        if (e.target.isRow) e.label,
    },
  );
}
```

In `lib/core/query/syntax/query_parser.dart`, replace the comment line that says "The NameIndex from Explore implements this in PR 5" with: `/// [NameIndex] in lib/core/query/names/ implements this.`

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/core/query/names/name_index_test.dart`
Expected: `All tests passed!` (6 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/core/query test/core/query
git add lib/core/query/names/name_index.dart lib/core/query/syntax/query_parser.dart test/core/query/names/name_index_test.dart
git commit -m "feat(query): one name index for sentences and typed queries, with alternate labels"
```

---

### Task 2: One loader for every name

**Files:**
- Create: `lib/features/query/data/name_index_loader.dart`
- Delete: `lib/features/query/data/query_name_index.dart`
- Modify: `lib/features/query/presentation/providers/query_name_index_provider.dart`
- Modify: `lib/features/query/domain/saved_query_load.dart` (parameter types `QueryNameIndex` to `NameIndex`)
- Modify: `lib/features/query/presentation/entity_query_editor.dart:76` (`QueryNameIndex.empty` to `NameIndex.empty`)
- Modify: `lib/features/query/presentation/providers/saved_query_providers.dart` (type only, if named)
- Test: `test/features/query/data/name_index_loader_test.dart` (create); delete `test/features/query/data/query_name_index_test.dart` after porting each of its cases into the new file
- Modify tests: `test/features/query/domain/saved_query_load_test.dart`, `test/features/query/presentation/dive_query_editor_test.dart`, `test/features/query/presentation/entity_query_editor_test.dart`, `test/features/query/presentation/providers/query_name_index_provider_test.dart`, `test/features/dive_log/presentation/pages/dive_search_page_query_test.dart`, `test/architecture/provider_tick_build_smoke_test.dart`: every `const QueryNameIndex({...})` becomes `NameIndex.fromRefs({...})` (drop `const`), and every `QueryNameIndex` type becomes `NameIndex`.

**Interfaces:**
- Consumes: Task 1's `NameIndex`, `NameEntry`, `NameTarget`, `rowTargetFor`; `appQueryRegistry`; `builtInSpeciesName(AppLocalizations, String id)` (`lib/features/marine_life/presentation/species_name_lookup.dart`); `EquipmentAttributeCatalog.attributesFor`, `AttributeKind.choice`, `def.choiceKeys`; `attributeChoiceLabel(AppLocalizations, String key, String choice)`; `l10nForLocaleTag(String)` (`lib/l10n/l10n_extension.dart`).
- Produces:
  - `class NameIndexLoader`, with `NameIndexLoader(AppDatabase)`, `static const List<QuerySubject> refSubjects`, `static Set<String> get tables` and `Future<NameIndex> load({String? diverId, required AppLocalizations l10n})`.
  - `queryNameIndexProvider`, which is now a `FutureProvider<NameIndex>`.

- [ ] **Step 1: Write the failing test**

Create `test/features/query/data/name_index_loader_test.dart`. It seeds the dive query fixture (`test/features/dive_log/query/dive_query_fixture.dart`). Before writing it, open `test/features/query/data/query_name_index_test.dart` and copy each of its visibility cases (own rows, unowned rows, shared sites and trips, equipment shares, the other diver's rows hidden) into this file unchanged except for `QueryNameIndexLoader(db).load(diverId: ...)` becoming `NameIndexLoader(db).load(diverId: ..., l10n: _en)` and results read through `index.refs(subject)`. Then add:

```dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/domain/query_value.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/query/data/name_index_loader.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../helpers/test_database.dart';
import '../../dive_log/query/dive_query_fixture.dart';

final _en = l10nForLocaleTag('en');

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
  });
  tearDown(tearDownTestDatabase);

  Future<NameIndex> load({String? diverId = 'me'}) =>
      NameIndexLoader(db).load(diverId: diverId, l10n: _en);

  test('places merge sites by label and remember their columns', () async {
    final index = await load();
    final bonaire = index
        .forSubject(QuerySubject.sites)
        .singleWhere((e) => e.target == NameTarget.sitePlace && e.label == 'Bonaire');
    expect(bonaire.ids.toSet(), {'s1', 's2'});
    expect(bonaire.placeFields, ['country']);
    expect(bonaire.rank, 0);
  });

  test('a legacy buddy name is a sentence-only buddy entry', () async {
    final index = await load();
    final bob = index
        .forSubject(QuerySubject.buddies)
        .singleWhere((e) => e.target == NameTarget.legacyBuddyName);
    expect(bob.label, 'Bob');
    expect(bob.rank, 1);
    expect(index.resolve(QuerySubject.buddies, 'Bob'), isNull);
  });

  test('an item\'s brand and model is an alternate label', () async {
    await db.customStatement(
      "UPDATE equipment SET brand = 'Apeks', model = 'XTX50' WHERE id = 'g_bcd'",
    );
    final index = await load();
    expect(
      index.resolve(QuerySubject.equipment, 'apeks xtx50'),
      const RefValue('g_bcd', 'g_bcd'),
    );
  });

  test('a built-in species gets its localized name as an alternate', () async {
    final de = l10nForLocaleTag('de');
    final builtIn = await db
        .customSelect("SELECT id, common_name FROM species WHERE is_built_in = 1 LIMIT 1")
        .getSingleOrNull();
    if (builtIn == null) {
      markTestSkipped('no built-in species seeded in the test database');
      return;
    }
    final id = builtIn.read<String>('id');
    final index = await NameIndexLoader(db).load(diverId: 'me', l10n: de);
    final localized = index
        .forSubject(QuerySubject.species)
        .where((e) => e.ids.contains(id) && !e.primary && e.rank == 0);
    expect(localized, isNotEmpty);
    expect(
      index.resolve(QuerySubject.species, localized.first.label)!.label,
      builtIn.read<String>('common_name'),
    );
  });

  test('every curated choice attribute choice is a gear entry', () async {
    final index = await load();
    final choices = index
        .forSubject(QuerySubject.equipment)
        .where((e) => e.target == NameTarget.attrChoice);
    expect(choices, isNotEmpty);
    expect(choices.every((e) => e.attrKey != null && e.attrChoice != null), isTrue);
  });

  test('the tick follows the ref tables, the shares and dives', () {
    expect(NameIndexLoader.tables, containsAll(['dive_sites', 'buddies', 'equipment_shares', 'dives']));
  });
}
```

If the built-in species case reports skipped, check how `setUpTestDatabase` seeds species. If it seeds none, replace that case with one that inserts a species row (`is_built_in = 1`) whose id `builtInSpeciesName` knows (take the first id from `lib/features/marine_life/presentation/species_name_lookup.dart`), and assert no skip. A test that skips proves nothing.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/query/data/name_index_loader_test.dart`
Expected: compilation FAIL, `Target of URI doesn't exist: 'package:submersion/features/query/data/name_index_loader.dart'`.

- [ ] **Step 3: Write the loader**

Create `lib/features/query/data/name_index_loader.dart`. Keep the visibility block from `QueryNameIndexLoader.load` exactly as it is (the `visible`/`variables` construction, including the `switch` on sites, trips and equipment); the new parts are the extra columns and the alternate entries:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/marine_life/presentation/species_name_lookup.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Loads the one [NameIndex] Explore and the typed language share (#2365):
/// every visible row by its registry name, the alternate labels a sentence
/// may use, places, attribute choices and legacy buddy names.
class NameIndexLoader {
  NameIndexLoader(this._db);

  final AppDatabase _db;

  /// The subjects a relation can point at by name.
  static const refSubjects = [
    QuerySubject.sites,
    QuerySubject.siteTypes,
    QuerySubject.trips,
    QuerySubject.centers,
    QuerySubject.computers,
    QuerySubject.courses,
    QuerySubject.buddies,
    QuerySubject.tags,
    QuerySubject.diveTypes,
    QuerySubject.equipment,
    QuerySubject.species,
  ];

  /// The columns read beside the name, for alternates and places.
  static const _extra = {
    QuerySubject.sites: ['country', 'region', 'island', 'city'],
    QuerySubject.species: ['scientific_name', 'is_built_in'],
    QuerySubject.equipment: ['brand', 'model'],
  };

  /// The place columns in rank order: country 0, region 1, island 2, city 3.
  static const _placeColumns = ['country', 'region', 'island', 'city'];

  /// The tables a change tick must follow: the ref tables, the share table
  /// that makes another diver's equipment visible, and dives, whose legacy
  /// buddy text is a name.
  static Set<String> get tables => {
    for (final s in refSubjects) appQueryRegistry.entityFor(s).table,
    'equipment_shares',
    'dives',
  };

  Future<NameIndex> load({
    String? diverId,
    required AppLocalizations l10n,
  }) async {
    final entries = <NameEntry>[];
    var siteRows = const <QueryRow>[];
    for (final subject in refSubjects) {
      final rows = await _rows(subject, diverId);
      if (subject == QuerySubject.sites) siteRows = rows;
      for (final row in rows) {
        final id = row.read<String>('id');
        final label = row.read<String?>('label');
        if (label == null || label.isEmpty) continue;
        entries.add(
          NameEntry(
            subject: subject,
            label: label,
            ids: [id],
            target: rowTargetFor(subject),
            // A built-in species' localized name ranks ahead of its stored
            // name for sentences, as Explore ranked them.
            rank: subject == QuerySubject.species ? 1 : 0,
            primary: true,
          ),
        );
        entries.addAll(_alternates(subject, id, label, row, l10n));
      }
    }
    entries.addAll(_places(siteRows));
    entries.addAll(_attributeChoices(l10n));
    entries.addAll(await _legacyBuddyNames(diverId));
    final seen = <String>{};
    return NameIndex([
      for (final e in entries)
        if (seen.add('${e.subject.name}|${e.label}|${e.identity}')) e,
    ]);
  }

  /// The visible rows of [subject]: id, registry name and the extra
  /// columns. Visibility is the typed loader's rule set, unchanged.
  Future<List<QueryRow>> _rows(QuerySubject subject, String? diverId) {
    final entity = appQueryRegistry.entityFor(subject);
    final nameSql = entity.field('name')!.sql.replaceAll('{r}', 't');
    final extra = [
      for (final c in _extra[subject] ?? const <String>[]) ', t.$c AS $c',
    ].join();
    final scope = entity.diverScopeColumn;
    final visible = <String>[];
    final variables = <Variable<Object>>[];
    if (scope != null) {
      if (diverId != null) {
        visible.add('t.$scope = ?');
        variables.add(Variable<String>(diverId));
      }
      visible.add('t.$scope IS NULL');
      switch (subject) {
        case QuerySubject.sites || QuerySubject.trips:
          visible.add('t.is_shared = 1');
        case QuerySubject.equipment when diverId != null:
          visible.add(
            't.${entity.idColumn} IN (SELECT equipment_id '
            'FROM equipment_shares WHERE diver_id = ?)',
          );
          variables.add(Variable<String>(diverId));
        default:
          break;
      }
    }
    final where = visible.isEmpty ? '' : 'WHERE ${visible.join(' OR ')}';
    return _db
        .customSelect(
          'SELECT t.${entity.idColumn} AS id, $nameSql AS label$extra '
          'FROM ${entity.table} t $where ORDER BY label',
          variables: variables,
        )
        .get();
  }

  /// Places: every non-empty country, region, island and city of a visible
  /// site. One label merges across sites and columns, keeping the lowest
  /// column rank, the union of site ids and every column it came from.
  static List<NameEntry> _places(List<QueryRow> sites) {
    final ids = <String, Set<String>>{};
    final ranks = <String, int>{};
    final fields = <String, Set<String>>{};
    for (final row in sites) {
      final id = row.read<String>('id');
      for (var rank = 0; rank < _placeColumns.length; rank++) {
        final column = _placeColumns[rank];
        final label = row.read<String?>(column)?.trim();
        if (label == null || label.isEmpty) continue;
        ids.putIfAbsent(label, () => {}).add(id);
        fields.putIfAbsent(label, () => {}).add(column);
        final existing = ranks[label];
        if (existing == null || rank < existing) ranks[label] = rank;
      }
    }
    return [
      for (final label in ranks.keys)
        NameEntry(
          subject: QuerySubject.sites,
          label: label,
          ids: ids[label]!.toList(),
          target: NameTarget.sitePlace,
          rank: ranks[label]!,
          placeFields: [
            for (final c in _placeColumns)
              if (fields[label]!.contains(c)) c,
          ],
        ),
    ];
  }

  /// Every choice of every curated choice attribute, by its localized
  /// label, so "trilaminate" lowers to a condition.
  static List<NameEntry> _attributeChoices(AppLocalizations l10n) => [
    for (final type in EquipmentType.values)
      for (final def in EquipmentAttributeCatalog.attributesFor(type))
        if (def.kind == AttributeKind.choice)
          for (final choice in def.choiceKeys)
            NameEntry(
              subject: QuerySubject.equipment,
              label: attributeChoiceLabel(l10n, def.key, choice),
              ids: const [],
              target: NameTarget.attrChoice,
              rank: 2,
              attrKey: def.key,
              attrChoice: choice,
            ),
  ];

  /// The distinct legacy `dives.buddy` texts, as sentence-only buddies.
  Future<List<NameEntry>> _legacyBuddyNames(String? diverId) async {
    final diverFilter = diverId != null ? 'AND diver_id = ?' : '';
    final rows = await _db
        .customSelect(
          'SELECT DISTINCT buddy FROM dives '
          "WHERE buddy IS NOT NULL AND buddy <> '' $diverFilter "
          'ORDER BY buddy',
          variables: [if (diverId != null) Variable<String>(diverId)],
        )
        .get();
    return [
      for (final r in rows)
        NameEntry(
          subject: QuerySubject.buddies,
          label: r.read<String>('buddy'),
          ids: const [],
          target: NameTarget.legacyBuddyName,
          rank: 1,
        ),
    ];
  }

  Iterable<NameEntry> _alternates(
    QuerySubject subject,
    String id,
    String label,
    QueryRow row,
    AppLocalizations l10n,
  ) sync* {
    switch (subject) {
      case QuerySubject.species:
        final builtIn = (row.read<int?>('is_built_in') ?? 0) == 1;
        final localized = builtIn ? builtInSpeciesName(l10n, id) : null;
        if (localized != null && localized != label) {
          yield NameEntry(
            subject: subject,
            label: localized,
            ids: [id],
            target: NameTarget.speciesId,
          );
        }
        final sci = row.read<String?>('scientific_name');
        if (sci != null && sci.isNotEmpty) {
          yield NameEntry(
            subject: subject,
            label: sci,
            ids: [id],
            target: NameTarget.speciesId,
            rank: 2,
          );
        }
      case QuerySubject.equipment:
        final brandModel = [
          row.read<String?>('brand'),
          row.read<String?>('model'),
        ].whereType<String>().where((s) => s.isNotEmpty).join(' ');
        if (brandModel.isNotEmpty && brandModel != label) {
          yield NameEntry(
            subject: subject,
            label: brandModel,
            ids: [id],
            target: NameTarget.equipmentId,
            rank: 1,
          );
        }
      default:
        break;
    }
  }
}
```

`AttributeKind` comes from `equipment_attribute_catalog.dart` and `EquipmentType` from `core/constants/enums.dart`; check both imports against `NameIndexBuilder`'s before deleting it. If the file passes 400 lines, move `_places`, `_attributeChoices` and `_legacyBuddyNames` into `name_index_sentence_entries.dart` beside it (the two static ones as top-level functions, the legacy query taking the database).

Replace `lib/features/query/presentation/providers/query_name_index_provider.dart`'s body:

```dart
/// The one name index the parser, the builder's pickers, saved-query
/// loading and Explore's resolver read (#2365). Reloads when any ref table
/// or the locale changes, so a synced site or a renamed buddy shows up
/// without a restart and localized species names follow the app language.
final queryNameIndexProvider = FutureProvider<NameIndex>((ref) async {
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchTables(NameIndexLoader.tables));
  final locale = ref.watch(localeProvider);
  return NameIndexLoader(
    DatabaseService.instance.database,
  ).load(diverId: diverId, l10n: l10nForLocaleTag(locale));
});
```

(Import `localeProvider` from wherever `explore_providers.dart` imports it: `settings_providers.dart`.) Delete `lib/features/query/data/query_name_index.dart`, and update each consumer and test listed under **Files**.

- [ ] **Step 4: Run the loader test and the query area**

Run: `flutter test test/features/query test/core/query test/features/dive_log/presentation/pages/dive_search_page_query_test.dart test/architecture/provider_tick_build_smoke_test.dart`
Expected: `All tests passed!`, with no skipped case in `name_index_loader_test.dart`.

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze --fatal-infos
dart format lib test
git add lib/features/query lib/core/query test/features/query test/core/query test/features/dive_log/presentation/pages/dive_search_page_query_test.dart test/architecture/provider_tick_build_smoke_test.dart
git status --short
git commit -m "feat(query): one loader builds every name, typed queries accept alternate labels"
```

Check `git status --short` shows nothing left unstaged under the paths you changed before committing.

---

### Task 3: Explore resolves against the shared index

**Files:**
- Delete: `lib/features/explore/domain/name_index.dart`, `lib/features/explore/data/name_index_builder.dart`, `test/features/explore/data/name_index_builder_test.dart` (its place, species-rank, brand-model, attribute and legacy cases are covered by Task 2's loader test; port any case Task 2 lacks into `name_index_loader_test.dart` first)
- Modify: `lib/features/explore/domain/entity_resolver.dart`
- Modify: `lib/features/explore/domain/compiled_query.dart`, rename to `explore_compilation.dart` (class `ExploreCompilation`)
- Modify: `lib/features/explore/domain/query_compiler.dart`, rename to `explore_compiler.dart` (classes `ExploreCompiler`, `ExploreCompilerContext`)
- Modify: `lib/features/explore/domain/query_model.dart` (`enum QuerySubject` renamed `ParsedSubject`; JSON names unchanged)
- Modify: `lib/features/explore/presentation/providers/explore_providers.dart` (delete `nameIndexProvider`; read `queryNameIndexProvider`)
- Modify: `lib/features/explore/presentation/widgets/explore_chip_rows.dart`, `lib/features/explore/domain/nl_engine.dart` (`ParsedSubject`)
- Modify tests under `test/features/explore/`: `entity_resolver_test.dart`, every `query_compiler*_test.dart` (rename the files to `explore_compiler*_test.dart`), `explore_providers_test.dart`, `explore_providers_db_test.dart`, `explore_page_test.dart`, `chip_labeler_test.dart`, `query_model_test.dart`, `nl_prompt_test.dart`

**Interfaces:**
- Consumes: Task 1's `NameIndex`, `NameEntry`, `NameTarget`; Task 2's `queryNameIndexProvider`.
- Produces:
  - `({QuerySubject subject, Set<NameTarget> targets}) mentionScope(MentionKind kind)`;
  - `Iterable<NameEntry> entriesForKind(NameIndex index, MentionKind kind)`;
  - `MentionKind mentionKindOf(NameTarget target)`;
  - `class ExploreCompilation` (same fields as `CompiledQuery` for now);
  - `abstract final class ExploreCompiler` with `static ExploreCompilation compile(ParsedQuery, ExploreCompilerContext)`;
  - `enum ParsedSubject`.

- [ ] **Step 1: Write the failing resolver test**

In `test/features/explore/domain/entity_resolver_test.dart`, change the index built in the tests from `NameIndex([NameEntry(kind: MentionKind.x, ...)])` to the core index. Each entry gets `subject:` from `mentionScope(kind).subject`, and `primary: true` where the old entry was the row's name (rank 0 for sites, buddies, tags, centers, trips, computers and gear items; rank 1 for a species' common name). Add:

```dart
  test('a pinned identity keeps its stored format and still wins', () {
    final index = NameIndex(const [
      NameEntry(
        subject: QuerySubject.buddies,
        label: 'John Smith',
        ids: ['b1'],
        target: NameTarget.buddyId,
        primary: true,
      ),
      NameEntry(
        subject: QuerySubject.buddies,
        label: 'John Smith',
        ids: ['b2'],
        target: NameTarget.buddyId,
        primary: true,
      ),
    ]);
    final r = resolveMention(
      const QueryMention(kind: MentionKind.buddy, text: 'John Smith', identity: 'buddyId:b2::::'),
      index,
    );
    expect((r as Resolved).entry.ids, ['b2']);
  });

  test('mentionKindOf inverts mentionScope for every target', () {
    for (final kind in MentionKind.values) {
      for (final t in mentionScope(kind).targets) {
        expect(mentionKindOf(t), kind, reason: t.name);
      }
    }
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/explore/domain/entity_resolver_test.dart`
Expected: compilation FAIL (`mentionScope`, `mentionKindOf` undefined; `NameEntry` has no `subject`).

- [ ] **Step 3: Move the resolver onto the core index**

In `entity_resolver.dart`, import `package:submersion/core/query/names/name_index.dart` and `package:submersion/core/query/domain/query_subject.dart`, and add:

```dart
/// The index subject and targets a mention kind is looked up under.
({QuerySubject subject, Set<NameTarget> targets}) mentionScope(
  MentionKind kind,
) => switch (kind) {
  MentionKind.site => (subject: QuerySubject.sites, targets: {NameTarget.siteId}),
  MentionKind.place => (subject: QuerySubject.sites, targets: {NameTarget.sitePlace}),
  MentionKind.species => (subject: QuerySubject.species, targets: {NameTarget.speciesId}),
  MentionKind.gear => (
    subject: QuerySubject.equipment,
    targets: {NameTarget.equipmentId, NameTarget.attrChoice},
  ),
  MentionKind.buddy => (
    subject: QuerySubject.buddies,
    targets: {NameTarget.buddyId, NameTarget.legacyBuddyName},
  ),
  MentionKind.tag => (subject: QuerySubject.tags, targets: {NameTarget.tagId}),
  MentionKind.center => (subject: QuerySubject.centers, targets: {NameTarget.centerId}),
  MentionKind.trip => (subject: QuerySubject.trips, targets: {NameTarget.tripId}),
  MentionKind.computer => (subject: QuerySubject.computers, targets: {NameTarget.computerId}),
};

Iterable<NameEntry> entriesForKind(NameIndex index, MentionKind kind) {
  final scope = mentionScope(kind);
  return index
      .forSubject(scope.subject)
      .where((e) => scope.targets.contains(e.target));
}

/// The mention kind a picked entry pins as.
MentionKind mentionKindOf(NameTarget target) => switch (target) {
  NameTarget.siteId => MentionKind.site,
  NameTarget.sitePlace => MentionKind.place,
  NameTarget.speciesId => MentionKind.species,
  NameTarget.equipmentId || NameTarget.attrChoice => MentionKind.gear,
  NameTarget.buddyId || NameTarget.legacyBuddyName => MentionKind.buddy,
  NameTarget.tagId => MentionKind.tag,
  NameTarget.centerId => MentionKind.center,
  NameTarget.tripId => MentionKind.trip,
  NameTarget.computerId => MentionKind.computer,
  NameTarget.siteTypeId || NameTarget.courseId || NameTarget.diveTypeId =>
    throw ArgumentError.value(target, 'target', 'no mention kind'),
};
```

In `resolveMention`, replace `index.forKind(kind)` with `entriesForKind(index, kind)`. The rank groups are unchanged: sort each kind's entries by `rank` as today, ignoring `primary`. Do the same in the compiler's `_nearest`.

Apply the renames (files and classes) listed under **Files**, and rename Explore's `QuerySubject` to `ParsedSubject` with every use. In `explore_providers.dart`:
- delete `nameIndexProvider` and its builder imports;
- `_compileAndPublish` reads `queryNameIndexProvider.future`;
- `_compileSync` reads `queryNameIndexProvider` with `NameIndex.empty` as the fallback;
- `resolveWith` builds the pinned mention with `kind: mentionKindOf(entry.target)`.

In tests, override `queryNameIndexProvider` where they overrode `nameIndexProvider`.

- [ ] **Step 4: Run the Explore and query tests**

Run: `flutter test test/features/explore test/features/query`
Expected: `All tests passed!` Explore's behavior is unchanged; only its types moved.

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze --fatal-infos
dart format lib test
git add lib/features/explore test/features/explore lib/features/query test/features/query
git status --short
git commit -m "refactor(explore): resolve mentions against the shared name index"
```

---

### Task 4: Explore's fields come from the registry

**Files:**
- Create: `lib/features/explore/domain/explore_fields.dart`
- Delete: `lib/features/explore/domain/dive_field_catalog.dart`, `lib/features/explore/domain/unit_grounding.dart`, `test/features/explore/domain/dive_field_catalog_test.dart`, `test/features/explore/domain/unit_grounding_test.dart`
- Modify: `explore_compiler.dart`, `explore_compilation.dart` (`ClauseChip.field` becomes `ExploreField`, `dimension` becomes core `FieldDimension`), `chart_selection.dart`, `nl_engine.dart`, `chip_labeler.dart`, `explore_providers.dart` (delete `unitPrefsProvider`; read `queryUnitPrefsProvider`)
- Test: `test/features/explore/domain/explore_fields_test.dart` (create); update `chip_labeler_test.dart`, `nl_prompt_test.dart`, `chart_selection_test.dart`, `explore_compiler*_test.dart` (`ExploreDiveField.x` becomes `exploreField('x')!`; the `UnitPrefs` record literal becomes core `UnitPrefs`, see its constructor in `lib/core/query/units/unit_prefs.dart`)

**Interfaces:**
- Consumes: `diveQueryEntity`, `appQueryRegistry`, `resolvePath(QueryRegistry, QueryEntity, FieldPath)`, core `FieldDimension`, `QueryUnit`, `groundToStorage`, `UnitPrefs`, `queryUnitPrefsProvider`.
- Produces:
  - `enum ExploreValueKind { number, enumName, flag, typeName }`;
  - `class ExploreField`, with fields `name`, `path`, `kind`, `wholeNumbers`, `bounds`, `tokens`, and getters `field`, `dimension`, `enumValues`, `ops`, `accepts(double)`;
  - `final List<ExploreField> kExploreFields` (25 entries);
  - `ExploreField? exploreField(String name)`;
  - `QueryUnit? queryUnitOf(ClauseUnit? unit)`;
  - `const List<String> kWeekdayTokens` (moved here unchanged).

- [ ] **Step 1: Write the failing test**

Create `test/features/explore/domain/explore_fields_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

void main() {
  test('the model keeps every field name it had', () {
    expect(kExploreFields.map((f) => f.name), [
      'depth', 'avgDepth', 'bottomTime', 'waterTemp', 'airTemp', 'visibility',
      'rating', 'o2', 'diveNumber', 'waterType', 'diveMode', 'entryMethod',
      'currentStrength', 'favorite', 'deco', 'noBuddy', 'weekday', 'diveType',
      'sac', 'sacTrend', 'sacChange', 'finalStop', 'finalStopExcursion',
      'finalStopDuration', 'finding',
    ]);
  });

  test('every number and enum field resolves on the dive registry', () {
    for (final f in kExploreFields) {
      if (f.kind == ExploreValueKind.flag && f.name == 'noBuddy') continue;
      expect(f.field, isNotNull, reason: f.name);
    }
  });

  test('dimensions and enum values come from the registry', () {
    expect(exploreField('depth')!.dimension, FieldDimension.depth);
    expect(exploreField('sac')!.dimension, FieldDimension.pressureRate);
    expect(exploreField('o2')!.dimension, FieldDimension.percent);
    expect(exploreField('waterType')!.enumValues, diveQueryEntity.field('waterType')!.enumValues);
    expect(exploreField('weekday')!.enumValues, kWeekdayTokens);
  });

  test('bounds: the registry sanity first, Explore\'s own where it has none', () {
    expect(exploreField('depth')!.accepts(401), isFalse);
    expect(exploreField('visibility')!.accepts(201), isFalse);
    expect(exploreField('o2')!.accepts(0.5), isFalse);
    expect(exploreField('bottomTime')!.accepts(1441), isFalse);
    expect(exploreField('diveNumber')!.accepts(-1), isFalse);
  });

  test('ops follow the value kind', () {
    expect(exploreField('depth')!.ops, contains(ClauseOp.between));
    expect(exploreField('waterType')!.ops, {ClauseOp.eq, ClauseOp.inList, ClauseOp.not});
    expect(exploreField('favorite')!.ops, {ClauseOp.eq});
    expect(exploreField('diveType')!.ops, {ClauseOp.eq, ClauseOp.inList});
  });

  test('o2 and finding reach through a relation', () {
    expect(exploreField('o2')!.path, ['tanks', 'o2']);
    expect(exploreField('finding')!.path, ['findings', 'rule']);
    expect(FieldPath(exploreField('diveType')!.path), FieldPath(['types', 'name']));
  });

  test('clause units map to query units; rate units without a query unit stay bare', () {
    expect(queryUnitOf(ClauseUnit.ft), isNotNull);
    expect(queryUnitOf(ClauseUnit.barMin), isNotNull);
    expect(queryUnitOf(ClauseUnit.lMin), isNull);
    expect(queryUnitOf(null), isNull);
  });

  test('an unknown name is null', () => expect(exploreField('nope'), isNull));
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/explore/domain/explore_fields_test.dart`
Expected: compilation FAIL, `Target of URI doesn't exist: '.../explore_fields.dart'`.

- [ ] **Step 3: Write the field list**

Create `lib/features/explore/domain/explore_fields.dart`:

```dart
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_registry.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// The weekday tokens the model writes, Monday first: a token's index plus
/// one is its [DateTime.weekday].
const List<String> kWeekdayTokens = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

enum ExploreValueKind { number, enumName, flag, typeName }

const Set<ClauseOp> _ordering = {
  ClauseOp.lt, ClauseOp.lte, ClauseOp.gt, ClauseOp.gte, ClauseOp.eq, ClauseOp.between,
};
const Set<ClauseOp> _membership = {ClauseOp.eq, ClauseOp.inList, ClauseOp.not};

/// One field the model may name (#2365 PR 5): its word, the dive registry
/// path it lowers onto, and everything else read from the registry.
class ExploreField {
  const ExploreField(
    this.name,
    this.path,
    this.kind, {
    this.wholeNumbers = false,
    this.bounds,
    this.tokens,
  });

  /// The model's word: part of the stored JSON contract, never renamed.
  final String name;
  final List<String> path;
  final ExploreValueKind kind;

  /// Bounds round to whole numbers, as the filter axes they replace did.
  final bool wholeNumbers;

  /// Explore's own bounds where the registry declares no sanity.
  final ({double min, double max})? bounds;

  /// The model's tokens when they differ from the registry's enum names.
  final List<String>? tokens;

  /// The registry field at [path], or null for a relation (noBuddy).
  QueryField? get field =>
      resolvePath(appQueryRegistry, diveQueryEntity, FieldPath(path)).field;

  FieldDimension get dimension =>
      kind == ExploreValueKind.number ? field!.dimension : FieldDimension.none;

  List<String>? get enumValues => tokens ?? field?.enumValues;

  Set<ClauseOp> get ops => switch (kind) {
    ExploreValueKind.number => _ordering,
    ExploreValueKind.enumName => _membership,
    ExploreValueKind.flag => const {ClauseOp.eq},
    ExploreValueKind.typeName => const {ClauseOp.eq, ClauseOp.inList},
  };

  /// Whether a grounded value is plausible: the registry's sanity, else
  /// [bounds], else any non-negative number.
  bool accepts(double v) {
    final range = field?.sanity ?? bounds;
    if (range != null) return v >= range.min && v <= range.max;
    return v >= 0;
  }
}

/// Every field the model may name, in the prompt's order.
const List<ExploreField> kExploreFields = [
  ExploreField('depth', ['depth'], ExploreValueKind.number),
  ExploreField('avgDepth', ['avgDepth'], ExploreValueKind.number),
  ExploreField('bottomTime', ['bottomTime'], ExploreValueKind.number,
      wholeNumbers: true, bounds: (min: 0, max: 24 * 60)),
  ExploreField('waterTemp', ['waterTemp'], ExploreValueKind.number),
  ExploreField('airTemp', ['airTemp'], ExploreValueKind.number),
  ExploreField('visibility', ['visibility'], ExploreValueKind.number,
      bounds: (min: 0, max: 200)),
  ExploreField('rating', ['rating'], ExploreValueKind.number, wholeNumbers: true),
  ExploreField('o2', ['tanks', 'o2'], ExploreValueKind.number,
      bounds: (min: 1, max: 100)),
  ExploreField('diveNumber', ['diveNumber'], ExploreValueKind.number),
  ExploreField('waterType', ['waterType'], ExploreValueKind.enumName),
  ExploreField('diveMode', ['diveMode'], ExploreValueKind.enumName),
  ExploreField('entryMethod', ['entryMethod'], ExploreValueKind.enumName),
  ExploreField('currentStrength', ['currentStrength'], ExploreValueKind.enumName),
  ExploreField('favorite', ['favorite'], ExploreValueKind.flag),
  ExploreField('deco', ['deco'], ExploreValueKind.flag),
  ExploreField('noBuddy', ['buddies'], ExploreValueKind.flag),
  ExploreField('weekday', ['weekday'], ExploreValueKind.enumName, tokens: kWeekdayTokens),
  ExploreField('diveType', ['types', 'name'], ExploreValueKind.typeName),
  ExploreField('sac', ['sac'], ExploreValueKind.number),
  ExploreField('sacTrend', ['sacTrend'], ExploreValueKind.enumName),
  ExploreField('sacChange', ['sacChange'], ExploreValueKind.number),
  ExploreField('finalStop', ['finalStop'], ExploreValueKind.enumName),
  ExploreField('finalStopExcursion', ['finalStopExcursion'], ExploreValueKind.number),
  ExploreField('finalStopDuration', ['finalStopDuration'], ExploreValueKind.number),
  ExploreField('finding', ['findings', 'rule'], ExploreValueKind.enumName),
];

ExploreField? exploreField(String name) {
  for (final f in kExploreFields) {
    if (f.name == name) return f;
  }
  return null;
}

/// A clause unit as the query language's unit. The volume rate units the
/// model may write have no query unit; a bare number takes the diver's.
QueryUnit? queryUnitOf(ClauseUnit? unit) => switch (unit) {
  null => null,
  ClauseUnit.m => QueryUnit.m,
  ClauseUnit.ft => QueryUnit.ft,
  ClauseUnit.c => QueryUnit.c,
  ClauseUnit.f => QueryUnit.f,
  ClauseUnit.bar => QueryUnit.bar,
  ClauseUnit.psi => QueryUnit.psi,
  ClauseUnit.min => QueryUnit.min,
  ClauseUnit.barMin => QueryUnit.barMin,
  ClauseUnit.psiMin => QueryUnit.psiMin,
  ClauseUnit.lMin || ClauseUnit.cuftMin => null,
};
```

Check the `QueryUnit` value names against `lib/core/query/domain/query_value.dart` and correct any that differ (for example Celsius). Keep the switch exhaustive with no `_` arm, so a new clause unit fails to compile until it is mapped.

Then migrate the users:

- **`explore_compiler.dart`:**
  - `DiveFieldCatalog.parse(c.field)` becomes `exploreField(c.field)`, and `spec.ops` / `spec.valueType` / `spec.enumValues` become `field.ops` / `field.kind` / `field.enumValues`.
  - `ground()` becomes:

    ```dart
    double.parse(groundToStorage(v, queryUnitOf(c.unit), field.dimension, units).toStringAsFixed(2))
    ```

    with `units` now core `UnitPrefs`.
  - `_inRange(field, v)` becomes `field.accepts(v)`.
  - Every `switch (field)` over `ExploreDiveField` becomes a switch over `field.name` (string patterns). The lowering targets stay the same in this task.
- **`explore_compilation.dart`:** `ClauseChip.field` has type `ExploreField`, and `dimension` is core `FieldDimension`.
- **`chart_selection.dart`:** `numericFields` is a `List<String>` of names, with the trend map keyed by `'depth'`, `'waterTemp'` and `'bottomTime'` (plus phase 2's `'sac'`).
- **`nl_engine.dart`:**
  - `'fields': kExploreFields.map((f) => f.name).toList()`;
  - `_oneOf(String name)` reads `exploreField(name)!.enumValues!`.
- **`chip_labeler.dart`:**
  - `fieldName(ExploreField f)` switches on `f.name`, with the same l10n keys;
  - `_value` takes core `FieldDimension`, adding a `FieldDimension.weight` and a `FieldDimension.volume` arm that format like `count` (no Explore field uses them);
  - `_enumValue` switches on `field.name`.
- **`explore_providers.dart`:** delete `unitPrefsProvider`; `_publish` reads `queryUnitPrefsProvider`.

- [ ] **Step 4: Run the Explore tests**

Run: `flutter test test/features/explore`
Expected: `All tests passed!`, including `nl_prompt_test.dart`'s length budget and `chip_labeler_test.dart`'s "every catalog field has a label", now iterating `kExploreFields`.

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze --fatal-infos
dart format lib test
git add lib/features/explore test/features/explore
git status --short
git commit -m "refactor(explore): the model's fields and units come from the query registry"
```

---

### Task 5: Explore lowers to one query

**Files:**
- Create: `lib/features/explore/domain/explore_clause_lowering.dart`, `lib/features/explore/domain/explore_mention_lowering.dart`
- Modify: `explore_compiler.dart` (orchestration only; the per-clause and per-mention code moves to the two new files), `explore_compilation.dart` (`DiveFilterState filter` becomes `QueryNode? query`)
- Test: `test/features/explore/domain/explore_lowering_fixture_test.dart` (create); rewrite the `filter` assertions in `explore_compiler_test.dart`, `explore_compiler_query_fields_test.dart`, `explore_compiler_buddies_test.dart`, `explore_compiler_rating_test.dart`, `explore_compiler_time_test.dart`

**Interfaces:**
- Consumes: Task 3's `mentionScope`, `resolveMention`, `NameIndex.labelOf`; Task 4's `ExploreField`; `equipmentAttrConditionNode(EquipmentAttrCondition)` (`lib/features/equipment/query/equipment_attr_condition_query.dart`); `parseDateText`.
- Produces:
  - `ExploreCompilation.query` (`QueryNode?`), no `filter`;
  - `({List<QueryNode> nodes, ClauseChip? chip, String? error}) lowerClause(QueryClause c, ExploreField? field, UnitPrefs units)`;
  - `List<QueryNode> lowerMentions(List<NameEntry> resolved, NameIndex names)`;
  - `List<QueryNode> lowerTime(DateTime? start, DateTime? end)`.

- [ ] **Step 1: Write the fixture test, and watch it pass on today's lowering**

This test pins what each sentence finds, on the six-dive fixture, before the lowering changes. Create `test/features/explore/domain/explore_lowering_fixture_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/explore/domain/explore_compiler.dart';
import 'package:submersion/features/explore/domain/query_model.dart';
import 'package:submersion/features/query/data/name_index_loader.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../helpers/test_database.dart';
import '../../dive_log/query/dive_query_fixture.dart';

QueryClause _c(String field, ClauseOp op, Object value, {ClauseUnit? unit}) =>
    QueryClause(field: field, op: op, value: value, unit: unit, text: field);
QueryMention _m(MentionKind kind, String text, {String? identity}) =>
    QueryMention(kind: kind, text: text, identity: identity);

void main() {
  late AppDatabase db;
  setUp(() async {
    db = await setUpTestDatabase();
    await seedQueryFixture(db);
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> ids(ParsedQuery q) async {
    final names = await NameIndexLoader(db).load(diverId: 'me', l10n: l10nForLocaleTag('en'));
    final compiled = ExploreCompiler.compile(
      q,
      ExploreCompilerContext(units: kMetricPrefs, names: names, now: DateTime(2026, 6, 1)),
    );
    expect(compiled.unresolved, isEmpty);
    expect(compiled.unplaced, isEmpty);
    return DiveRepository().getDiveIdsMatching(_filterOf(compiled), diverId: 'me');
  }

  ParsedQuery q({
    List<QueryClause> clauses = const [],
    List<QueryMention> mentions = const [],
    String? time,
  }) => ParsedQuery(
    subject: ParsedSubject.dives,
    clauses: clauses,
    mentions: mentions,
    time: time == null ? null : QueryTime(time),
    unplaced: const [],
  );

  final cases = <String, (ParsedQuery, Set<String>)>{
    'deeper than 20 m': (q(clauses: [_c('depth', ClauseOp.gt, 20, unit: ClauseUnit.m)]), {'d2', 'd3', 'd5'}),
    'depth between 20 and 30': (q(clauses: [_c('depth', ClauseOp.between, [20, 30])]), {'d2', 'd3'}),
    'water colder than 20 c': (q(clauses: [_c('waterTemp', ClauseOp.lt, 20, unit: ClauseUnit.c)]), {'d3'}),
    'bottom time at least 45': (q(clauses: [_c('bottomTime', ClauseOp.gte, 45)]), {'d1', 'd2'}),
    'no buddy': (q(clauses: [_c('noBuddy', ClauseOp.eq, true)]), {'d3', 'd4'}),
    'place Bonaire': (q(mentions: [_m(MentionKind.place, 'Bonaire')]), {'d1', 'd2', 'd3'}),
    'site Cenote or place Bonaire': (
      q(mentions: [_m(MentionKind.site, 'Cenote'), _m(MentionKind.place, 'Bonaire')]),
      {'d1', 'd2', 'd3', 'd5'},
    ),
    'buddy Ana': (q(mentions: [_m(MentionKind.buddy, 'Ana')]), {'d1', 'd5'}),
    'buddies Ana and Cid': (
      q(mentions: [_m(MentionKind.buddy, 'Ana'), _m(MentionKind.buddy, 'Cid')]),
      {'d5'},
    ),
    'pinned buddy': (
      q(mentions: [_m(MentionKind.buddy, 'Ana', identity: 'buddyId:b1::::')]),
      {'d1', 'd5'},
    ),
    'legacy buddy Bob': (q(mentions: [_m(MentionKind.buddy, 'Bob')]), {'d2'}),
    'gear g_wet': (q(mentions: [_m(MentionKind.gear, 'g_wet')]), {'d1', 'd5'}),
    'in 2025': (q(time: '2025'), {'d1', 'd2', 'd3', 'd5'}),
    'deep in Bonaire in 2025': (
      q(
        clauses: [_c('depth', ClauseOp.gt, 20, unit: ClauseUnit.m)],
        mentions: [_m(MentionKind.place, 'Bonaire')],
        time: '2025',
      ),
      {'d2', 'd3'},
    ),
  };

  for (final e in cases.entries) {
    test('finds the same dives: ${e.key}', () async {
      expect(await ids(e.value.$1), e.value.$2);
    });
  }
}
```

Define `_filterOf` at the bottom of the file. In this step it is:

```dart
DiveFilterState _filterOf(ExploreCompilation c) => c.filter;
```

Run: `flutter test test/features/explore/domain/explore_lowering_fixture_test.dart`
Expected: `All tests passed!` (14 cases). This step is a characterization: it pins today's lowering before the rewrite, so it passes first. If a case fails, the fixture expectation is wrong. Re-derive it from the fixture table in `dive_query_fixture.dart`; never change the lowering to fit.

- [ ] **Step 2: Add the new cases and switch the test to the query, then watch it fail**

Change `_filterOf` to:

```dart
DiveFilterState _filterOf(ExploreCompilation c) => DiveFilterState(query: c.query);
```

Then add two cases after the loop's map. Before building the index for them, write the extra rows:

```dart
  test('a merged place ORs its columns', () async {
    await db.customStatement(
      "UPDATE dive_sites SET region = 'Bonaire', country = 'Caribbean Netherlands' WHERE id = 's1'",
    );
    await db.customStatement(
      "UPDATE dive_sites SET island = 'Bonaire', country = 'Caribbean Netherlands' WHERE id = 's2'",
    );
    expect(await ids(q(mentions: [_m(MentionKind.place, 'Bonaire')])), {'d1', 'd2', 'd3'});
  });

  test('two centers OR together', () async {
    await db.customStatement(
      "INSERT INTO dive_centers (id, name, created_at, updated_at) VALUES "
      "('c1', 'Buddy Dive', 0, 0), ('c2', 'Dive Friends', 0, 0)",
    );
    await db.customStatement("UPDATE dives SET dive_center_id = 'c1' WHERE id = 'd1'");
    await db.customStatement("UPDATE dives SET dive_center_id = 'c2' WHERE id = 'd3'");
    expect(
      await ids(q(mentions: [_m(MentionKind.center, 'Buddy Dive'), _m(MentionKind.center, 'Dive Friends')])),
      {'d1', 'd3'},
    );
  });
```

Run: `flutter test test/features/explore/domain/explore_lowering_fixture_test.dart`
Expected: compilation FAIL, `The getter 'query' isn't defined for the type 'ExploreCompilation'`.

- [ ] **Step 3: Lower clauses to nodes**

Create `explore_clause_lowering.dart`, the clause half of today's compiler rewritten to emit nodes:

```dart
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/explore/domain/explore_compilation.dart';
import 'package:submersion/features/explore/domain/explore_fields.dart';
import 'package:submersion/features/explore/domain/query_model.dart';

typedef LoweredClause = ({
  List<QueryNode> nodes,
  ClauseChip? chip,
  String? error,
});

LoweredClause _fail(String error) =>
    (nodes: const [], chip: null, error: error);

/// One model clause as query nodes on its registry path (#2365 PR 5). The
/// model chose the words; units, bounds and values are decided here.
LoweredClause lowerClause(
  QueryClause c,
  ExploreField? field,
  UnitPrefs units,
) {
  if (field == null) return _fail('unknownField');
  if (!field.ops.contains(c.op)) return _fail('invalid');
  return switch (field.kind) {
    ExploreValueKind.number => _number(c, field, units),
    ExploreValueKind.flag => _flag(c, field),
    ExploreValueKind.enumName => _enum(c, field),
    ExploreValueKind.typeName => _typeName(c, field),
  };
}

List<String> _strings(Object raw) =>
    raw is List ? raw.whereType<String>().toList() : [if (raw is String) raw];

LoweredClause _flag(QueryClause c, ExploreField field) {
  final v = c.value;
  if (v != true && v != false) return _fail('invalid');
  final on = v == true;
  final QueryNode? node = switch (field.name) {
    'favorite' when on => ConditionNode(
      FieldPath(['favorite']),
      QueryOp.eq,
      const BoolValue(true),
    ),
    'deco' => ConditionNode(FieldPath(['deco']), QueryOp.eq, BoolValue(on)),
    'noBuddy' when on => ConditionNode(
      FieldPath(['buddies']),
      QueryOp.isEmpty,
      null,
    ),
    _ => null,
  };
  if (node == null) return _fail('invalid');
  return (
    nodes: [node],
    chip: ClauseChip(
      field: field,
      op: c.op,
      value: on,
      dimension: FieldDimension.none,
    ),
    error: null,
  );
}

LoweredClause _enum(QueryClause c, ExploreField field) {
  final values = _strings(c.value);
  if (values.isEmpty) return _fail('invalid');
  final allowed = field.enumValues!;
  if (values.any((v) => !allowed.contains(v))) return _fail('invalid');
  // The model's tokens (weekday: mon..sun) map onto the registry's names,
  // which run Monday first too.
  final tokens = field.tokens;
  final names = tokens == null
      ? values
      : [for (final v in values) field.field!.enumValues![tokens.indexOf(v)]];
  final QueryNode node = ConditionNode(
    FieldPath(field.path),
    QueryOp.inList,
    ListValue([for (final n in names) EnumValue(n)]),
  );
  // "Not" keeps the dives where the field was never recorded: the query
  // tree's NOT treats an unknown as not matching, where the complement of
  // the listed values would silently drop every blank dive.
  return (
    nodes: [c.op == ClauseOp.not ? NotNode(node) : node],
    chip: ClauseChip(
      field: field,
      op: c.op,
      value: values,
      dimension: FieldDimension.none,
    ),
    error: null,
  );
}

/// A dive type is the diver's own entity, named in their words: an exact
/// (case-insensitive) match on any of the names through the types junction.
LoweredClause _typeName(QueryClause c, ExploreField field) {
  final values = _strings(c.value);
  if (values.isEmpty) return _fail('invalid');
  return (
    nodes: [
      ConditionNode(
        FieldPath(field.path),
        QueryOp.inList,
        ListValue([for (final v in values) StringValue(v)]),
      ),
    ],
    chip: ClauseChip(
      field: field,
      op: c.op,
      value: values,
      dimension: FieldDimension.none,
    ),
    error: null,
  );
}

LoweredClause _number(QueryClause c, ExploreField field, UnitPrefs units) {
  double ground(num v) => double.parse(
    groundToStorage(
      v,
      queryUnitOf(c.unit),
      field.dimension,
      units,
    ).toStringAsFixed(2),
  );
  double? lo;
  double? hi;
  Object chipValue;
  if (c.op == ClauseOp.between) {
    final raw = c.value;
    if (raw is! List || raw.length != 2 || raw.any((v) => v is! num)) {
      return _fail('invalid');
    }
    var a = ground(raw[0] as num);
    var b = ground(raw[1] as num);
    if (b < a) (a, b) = (b, a);
    if (!field.accepts(a) || !field.accepts(b)) return _fail('outOfRange');
    lo = a;
    hi = b;
    chipValue = [a, b];
  } else {
    final raw = c.value;
    if (raw is! num) return _fail('invalid');
    final v = ground(raw);
    chipValue = v;
    // The number said is what must be plausible; an "exactly" band may
    // reach half a unit past the bound.
    if (!field.accepts(v)) return _fail('outOfRange');
    switch (c.op) {
      case ClauseOp.lt:
      case ClauseOp.lte:
        hi = v;
      case ClauseOp.gt:
      case ClauseOp.gte:
        lo = v;
      case ClauseOp.eq:
        // A measured value is almost never exactly the number said, so
        // "exactly 15 m" is the half unit either side of it in the unit the
        // diver used. SAC is read to a tenth. Counts stay exact.
        final half = switch (field.dimension) {
          FieldDimension.depth || FieldDimension.temperature => 0.5,
          FieldDimension.pressureRate => 0.05,
          _ => 0.0,
        };
        lo = half == 0 ? v : ground(raw - half);
        hi = half == 0 ? v : ground(raw + half);
      default:
        return _fail('invalid');
    }
  }
  if (field.wholeNumbers) {
    lo = lo?.roundToDouble();
    hi = hi?.roundToDouble();
  }
  final key = field.path.last;
  final bounds = <QueryNode>[
    if (lo != null)
      ConditionNode(FieldPath([key]), QueryOp.gte, NumberValue(lo, null)),
    if (hi != null)
      ConditionNode(FieldPath([key]), QueryOp.lte, NumberValue(hi, null)),
  ];
  // A child field (a tank's O2) scopes both bounds to one row, as the old
  // minO2Percent/maxO2Percent axis did.
  final nodes = field.path.length == 1
      ? bounds
      : <QueryNode>[
          ScopedNode(
            FieldPath(field.path.sublist(0, field.path.length - 1)),
            bounds.length == 1 ? bounds.single : AndNode(bounds),
          ),
        ];
  // The chip reports the op the query ACTUALLY applies: every bound is
  // inclusive, so a strict "deeper than 20" shows as "at least 20".
  return (
    nodes: nodes,
    chip: ClauseChip(
      field: field,
      op: switch (c.op) {
        ClauseOp.gt => ClauseOp.gte,
        ClauseOp.lt => ClauseOp.lte,
        _ => c.op,
      },
      value: chipValue,
      dimension: field.dimension,
    ),
    error: null,
  );
}
```

If phase 2 changed the "exactly" band (Pre-flight Step 2), take its half sizes, not the ones above.

Create `explore_mention_lowering.dart`:

```dart
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/query/equipment_attr_condition_query.dart';

/// The resolved mentions as query nodes, grouped by kind (#2365 PR 5).
/// Sites and places OR into one node; species, gear items, tags, centers,
/// trips and computers each OR into one membership; every buddy, legacy
/// buddy name and attribute choice is its own condition, ANDed.
List<QueryNode> lowerMentions(List<NameEntry> resolved, NameIndex names) {
  RefValue ref(QuerySubject s, String id) => RefValue(id, names.labelOf(s, id) ?? id);
  ListValue refs(QuerySubject s, Iterable<String> ids) =>
      ListValue([for (final id in {...ids}) ref(s, id)]);
  final out = <QueryNode>[];

  final siteIds = [for (final e in resolved) if (e.target == NameTarget.siteId) ...e.ids];
  final places = [for (final e in resolved) if (e.target == NameTarget.sitePlace) e];
  final siteParts = <QueryNode>[
    if (siteIds.isNotEmpty)
      ConditionNode(FieldPath(['site']), QueryOp.inList, refs(QuerySubject.sites, siteIds)),
    for (final p in places)
      for (final column in p.placeFields)
        ConditionNode(FieldPath(['site', column]), QueryOp.eq, StringValue(p.label)),
  ];
  if (siteParts.isNotEmpty) {
    out.add(siteParts.length == 1 ? siteParts.single : OrNode(siteParts));
  }

  void membership(NameTarget target, QuerySubject subject, List<String> path) {
    final ids = [for (final e in resolved) if (e.target == target) ...e.ids];
    if (ids.isEmpty) return;
    out.add(ConditionNode(FieldPath(path), QueryOp.inList, refs(subject, ids)));
  }

  membership(NameTarget.speciesId, QuerySubject.species, ['sightings', 'species']);
  membership(NameTarget.equipmentId, QuerySubject.equipment, ['gear']);
  membership(NameTarget.tagId, QuerySubject.tags, ['tags']);
  membership(NameTarget.centerId, QuerySubject.centers, ['center']);
  membership(NameTarget.tripId, QuerySubject.trips, ['trip']);
  membership(NameTarget.computerId, QuerySubject.computers, ['computer']);

  for (final e in resolved) {
    switch (e.target) {
      case NameTarget.attrChoice:
        out.add(
          ScopedNode(
            FieldPath(['gear']),
            equipmentAttrConditionNode(
              EquipmentAttrCondition(key: e.attrKey!, choices: {e.attrChoice!}),
            ),
          ),
        );
      case NameTarget.buddyId:
        out.add(ConditionNode(FieldPath(['buddies']), QueryOp.eq, ref(QuerySubject.buddies, e.ids.single)));
      case NameTarget.legacyBuddyName:
        out.add(ConditionNode(FieldPath(['legacyBuddy']), QueryOp.eq, StringValue(e.label)));
      default:
        break;
    }
  }
  return out;
}

/// A time phrase's bounds, as the date filter lowered them.
List<QueryNode> lowerTime(DateTime? start, DateTime? end) => [
  if (start != null) ConditionNode(FieldPath(['date']), QueryOp.gte, DateValue(start)),
  if (end != null) ConditionNode(FieldPath(['date']), QueryOp.lte, DateValue(end)),
];
```

The site place fields are `country`, `region`, `island` and `city` on the site registry (`site_query_entity.dart`), which compare case-insensitively on trimmed text.

In `explore_compiler.dart`, the orchestration keeps its shape:
- It collects clause nodes in clause order, then `lowerMentions(resolvedEntries, ctx.names)`, then `lowerTime(range.start, range.end)`.
- The query is `nodes.isEmpty ? null : nodes.length == 1 ? nodes.single : AndNode(nodes)`.
- A non-dive subject returns `query: null`.
- `ExploreCompilation` drops `filter` and gains `final QueryNode? query`.
- Delete `_andQuery` and every `DiveFilterState` import from the domain folder.

- [ ] **Step 4: Run the fixture test**

Run: `flutter test test/features/explore/domain/explore_lowering_fixture_test.dart`
Expected: `All tests passed!` (16 cases). Every case from Step 1 still finds the same dives.

- [ ] **Step 5: Rewrite the compiler tests' filter assertions**

Add a helper to `test/features/explore/domain/explore_compiler_test.dart`, and import it into the other compiler test files:

```dart
/// The top-level conditions of a compiled query, flattening one AND.
List<QueryNode> partsOf(ExploreCompilation c) => switch (c.query) {
  null => const [],
  AndNode(:final children) => children,
  final node => [node],
};
```

Each old assertion becomes a membership check on `partsOf(compiled)`:

| Old assertion | New assertion |
| --- | --- |
| `filter.minDepth == 20` | contains `ConditionNode(FieldPath(['depth']), QueryOp.gte, NumberValue(20, null))` |
| `filter.maxDepth == x` | `depth lte x` |
| `filter.minWaterTemp` / `maxWaterTemp` | `waterTemp gte` / `lte` |
| `filter.minVisibility` / `maxVisibility` | `visibility gte` / `lte` |
| `filter.minO2Percent` / `maxO2Percent` | `ScopedNode(FieldPath(['tanks']), ...)` holding `o2 gte` / `lte` |
| `filter.minBottomTimeMinutes` | `bottomTime gte` (a whole number) |
| `filter.minRating` plus a `rating lte` in `filter.query` | `rating gte` and `rating lte` (both whole numbers) |
| `filter.waterTypes == [WaterType.salt]` | `ConditionNode(FieldPath(['waterType']), QueryOp.inList, ListValue([EnumValue('salt')]))` |
| `filter.weekdays == [6, 7]` | `weekday inList [saturday, sunday]` |
| `filter.favoritesOnly` | `favorite eq BoolValue(true)` |
| `filter.decoOnly == on` | `deco eq BoolValue(on)` |
| `filter.noBuddyOnly` | `ConditionNode(FieldPath(['buddies']), QueryOp.isEmpty, null)` |
| `filter.siteIds` | a `site inList` of `RefValue`s carrying site names, or place conditions |
| `filter.speciesIds` | `sightings.species inList` |
| `filter.equipmentIds` | `gear inList` |
| `filter.equipmentAttrConditions` | the `ScopedNode(FieldPath(['gear']), equipmentAttrConditionNode(...))` |
| `filter.buddyId` (first buddy) | `buddies eq RefValue` (every buddy the same way) |
| `filter.tagIds` | `tags inList` |
| `filter.diveCenterId` / `tripId` / `computerId` | `center` / `trip` / `computer inList` |
| `filter.startDate` / `endDate` | `date gte` / `lte DateValue` |
| `filter.query` trees (`query_fields`, `buddies` tests) | the same nodes, now top-level parts |
| `filter.hasActiveFilters == false` for a non-dive subject | `compiled.query` is null |

A test whose point was that the first water-type or weekday clause used the plain axis becomes: two water-type clauses give two separate `waterType inList` parts. The buddies test "`buddyNameFilter` stays null" is deleted, since there is no filter any more.

Run: `flutter test test/features/explore/domain`
Expected: `All tests passed!`

- [ ] **Step 6: Analyze and commit**

```bash
flutter analyze --fatal-infos
dart format lib test
git add lib/features/explore test/features/explore
git status --short
git commit -m "feat(explore): a sentence compiles to one query on the dive registry"
```

`flutter analyze` will fail in `explore_providers.dart` and `explore_page.dart` until Task 6. If it does, fold Task 6 Step 3's provider change into this commit instead of committing a red analyze, and note that in the ledger.

---

### Task 6: Results, charts and the handoff read the query

**Files:**
- Modify: `lib/features/explore/presentation/providers/explore_providers.dart`, `lib/features/explore/presentation/pages/explore_page.dart`
- Test: `test/features/explore/presentation/pages/explore_page_test.dart`, `test/features/explore/presentation/providers/explore_providers_db_test.dart`, `test/features/explore/presentation/providers/explore_providers_test.dart`

**Interfaces:**
- Consumes: Task 5's `ExploreCompilation.query`.
- Produces:
  - `final exploreQueryNodeProvider = StateProvider<QueryNode?>`, Explore's own scope;
  - `final exploreFilterProvider = Provider<DiveFilterState>`, which derives `DiveFilterState(query: node)` for the repositories.

- [ ] **Step 1: Write the failing handoff test**

In `explore_page_test.dart`, replace the two handoff tests' `diveFilterProvider` and `insightsFilterProvider` expectations. The page is pumped with a compilation whose query is a buddy condition, `RefValue('b1', 'Ana')`. Assert:

```dart
    final handed = container.read(diveFilterProvider);
    expect(handed.query, isA<ConditionNode>());
    final ref = ((handed.query! as ConditionNode).value! as RefValue);
    expect(ref.label, 'Ana', reason: 'the handoff carries named refs');
    expect(handed.minDepth, isNull, reason: 'no legacy axis is set');
```

Name the test `the handoff carries named refs`. Build the page's compilation through the real `ExploreCompiler` with a `NameIndex.fromRefs({QuerySubject.buddies: [RefValue('b1', 'Ana')]})` override on `queryNameIndexProvider`, so the label comes from the index and not the test.

Run: `flutter test test/features/explore/presentation/pages/explore_page_test.dart`
Expected: FAIL (compilation errors from `exploreFilterProvider` being assigned, or the old filter shape).

- [ ] **Step 2: Hold the query, derive the filter**

In `explore_providers.dart`:

```dart
/// Explore's own scope, so editing chips never rescopes the dive list or
/// Statistics until the diver asks for a handoff.
final exploreQueryNodeProvider = StateProvider<QueryNode?>((ref) => null);

/// The scope as the repositories take it: the query alone, no legacy axis.
final exploreFilterProvider = Provider<DiveFilterState>(
  (ref) => DiveFilterState(query: ref.watch(exploreQueryNodeProvider)),
);
```

`_begin`, `clear` and `_publish` write `exploreQueryNodeProvider` (`null`, `null`, `compiled.query`). Results, count, charts and `_exploreTick` keep reading `exploreFilterProvider`.

In `explore_page.dart`:
- the handoff bar's gate becomes `compiled != null && compiled.query != null`;
- both buttons write `DiveFilterState(query: ref.read(exploreQueryNodeProvider))`;
- update the comment above them.

Check `test/architecture/` for `exploreFilterProvider` (`grep -rn exploreFilterProvider test/architecture`). A tick smoke entry for it moves to `exploreQueryNodeProvider` if it listed the `StateProvider`.

- [ ] **Step 3: Move the provider tests to the node**

In `explore_providers_db_test.dart`, every `c.read(exploreFilterProvider.notifier).state = const DiveFilterState(minDepth: 20)` becomes:

```dart
c.read(exploreQueryNodeProvider.notifier).state = ConditionNode(
  FieldPath(['depth']),
  QueryOp.gte,
  const NumberValue(20, null),
);
```

Also:
- Other axis literals move the same way, per the table in Task 5 Step 5.
- The `nameIndexProvider` overrides become `queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty)`.
- In `explore_providers_test.dart`, assertions on `exploreFilterProvider` state compare `.query`.

- [ ] **Step 4: Run the Explore, dive list and Insights tests**

Run: `flutter test test/features/explore test/features/dive_log/presentation test/features/insights test/architecture`
Expected: `All tests passed!`

- [ ] **Step 5: Analyze and commit**

```bash
flutter analyze --fatal-infos
dart format lib test
git add lib/features/explore test/features/explore test/architecture
git status --short
git commit -m "feat(explore): results, charts and the handoff read one query"
```

---

### Task 7: Stale notes and the spec

**Files:**
- Modify: `lib/core/query/syntax/date_grammar.dart:1-3` (the header says Explore still has a copy that PR 5 deletes; Explore already uses this file)
- Modify: `docs/superpowers/specs/2026-09-25-entity-query-language-design.md` (a "Deviations recorded during implementation (PR 5)" section after PR 4's)

- [ ] **Step 1: Fix the header**

Replace the date grammar's first comment lines with:

```dart
/// The date phrases the typed language and Explore's sentences share
/// (#2365): `2025`, `May 2025`, `last 30 days`, `since 2024`, ISO days and
/// ranges.
```

- [ ] **Step 2: Record the deviations**

Append to the spec, after the PR 4 deviations:

```markdown
### Deviations recorded during implementation (PR 5)

- **The loader lives in features.** `NameIndex`, `NameEntry` and `NameTarget` moved to `lib/core/query/names/`; `NameIndexLoader` lives in `lib/features/query/data/`, because it reads the registry, the equipment attribute catalog and the species name lookup, and core never imports a feature.
- **One index.** The typed index and Explore's index merged. A typed ref now also resolves by an alternate label (a built-in species' localized or scientific name, an item's brand and model) and prints its primary name; places, attribute choices and legacy buddy names are sentence-only entries.
- **Places lower to site place conditions** (`site.island = "Bonaire"`, an OR over each column the label came from), so a saved or handed-off query keeps finding new sites in the place.
- **Mentions of one kind OR together**, centers, trips and computers included (they were "the last one wins"); buddies and attribute choices stay ANDed.
- **Rating and bottom time bounds are whole numbers**, as the filter axes they replaced were.
- **`time_grammar` needed no move.** Explore already read `lib/core/query/syntax/date_grammar.dart`.
- **Profile-derived predicates came as registry fields** (Explore phase 2: `sac`, `sacTrend`, `sacChange`, `finalStop`, `finalStopExcursion`, `finalStopDuration`, `findings`), not through `derivedPredicateCondition`, which never reached main.
- **`DiveFilterState` stays the repositories' argument.** Explore holds a `QueryNode` and wraps it as `DiveFilterState(query: node)` for results, counts, charts and the handoff, which the dive list shows as query chips.
```

- [ ] **Step 3: Run the whole suite**

Run: `flutter test --exclude-tags performance > "$TMPDIR/pr5_suite.txt" 2>&1; tail -3 "$TMPDIR/pr5_suite.txt"`
Expected: `All tests passed!` (pre-existing skips only).

- [ ] **Step 4: Commit**

```bash
dart format lib test
git add lib/core/query/syntax/date_grammar.dart docs/superpowers/specs/2026-09-25-entity-query-language-design.md
git commit -m "docs(query): record the PR 5 deviations"
```

---

## Self-review notes

- Spec coverage:
  - Program row 5 and Unit 5 "Explore":
    - `CompiledQuery.filter` becomes a `QueryNode` (Task 5);
    - `ExploreDiveField` and `DiveFieldCatalog` are replaced (Task 4);
    - `NameIndex` and `NameIndexBuilder` move (Tasks 1 to 3);
    - `unit_grounding` is deleted in favor of core units (Task 4);
    - `time_grammar` was already moved, and Task 7 records it.
  - The derived-fields line of "Derived fields" is met by phase 2 and recorded in Task 7.
- The handoff shape and the index unification follow the 2026-09-29 decisions table.
- Types used across tasks: `NameIndex`, `NameEntry`, `NameTarget`, `rowTargetFor` (Task 1); `NameIndexLoader`, `queryNameIndexProvider` (Task 2); `mentionScope`, `mentionKindOf`, `ExploreCompilation`, `ExploreCompiler`, `ExploreCompilerContext`, `ParsedSubject` (Task 3); `ExploreField`, `kExploreFields`, `exploreField`, `queryUnitOf`, `kWeekdayTokens` (Task 4); `lowerMentions`, `lowerTime`, `ExploreCompilation.query` (Task 5); `exploreQueryNodeProvider` (Task 6).
