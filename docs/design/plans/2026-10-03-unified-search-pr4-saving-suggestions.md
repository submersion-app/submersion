# Unified Dive Search, PR 4: Saving and Suggestions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Save the whole dive search as one saved query and load it back as the whole search, remember recent searches (typed and asked), and show saved searches, recent searches and syntax hints when the search field is empty; this closes #2773.

**Architecture:** Saving reuses the existing saved-query flow (`saveQueryFromEditor`) with `DiveFilterState.toQuery()`, and loading writes `DiveFilterState(query: load.node)` so the axes clear. A census test proves every filter axis survives JSON, relabelling, printing and re-parsing; two lowerings that wrap one condition in an "and" group are fixed so the trees compare equal. The Explore recent-queries table gains a `kind` (typed or asked, cache database v19); a new suggestions widget under the field lists saved chips, recents and hints, and `DiveAskNotifier.replay` reruns an asked recent from its stored parse without the model.

**Tech Stack:** Flutter, Riverpod (legacy providers via `core/providers/provider.dart`), Drift (local cache database), go_router, gen-l10n (11 locales).

**Spec:** `docs/superpowers/specs/2026-10-02-unified-dive-search-design.md` (sections 3.8, 4.1 states 2 and 4, 4.2 saved chips, 5.4, 5.5, 7 "Save", 8 row 4, 9 rows 6 and 8). Issue #2773 (this PR `Closes` it). Branch `ericgriffin/dive-search-saving`, from `main` after PR 3 (#2857) merges.

## Global Constraints

- Never use the em-dash character, or an en-dash, double hyphen or spaced hyphen as punctuation, anywhere (code, comments, commits, ARB values, PR text).
- No mention of Claude, Claude Code or Anthropic in any commit, PR text or file.
- Every user-visible string goes through `context.l10n`; new keys are translated into all 10 non-en ARBs (values below, matching each file's register: de and fr and pt formal, es it nl hu informal, he plural); `@` metadata in `app_en.arb` only; `flutter gen-l10n` after ARB edits.
- Anything showing units follows the active diver's unit settings (`queryUnitPrefsProvider` for query text).
- The recents change is a cache-database change (`LocalCacheDatabase`), never a rung on the synced schema.
- Paths in tests via `p.join`; process-wide state restored in `addTearDown`.
- Files under 800 lines; imports grouped dart, flutter, packages, local.
- `dart format .` before every commit; conventional commits, no trailers.
- PR body: `Closes #2773`; Screenshots section says they were skipped at the maintainer's request (do not tick "No visible UI change").

## Rulings made while planning (confirm at review)

1. **Save lives in the search row's chip row** (spec 4.1 state 4), saving `toQuery()` of what applies (under "All dives" that is the typed query alone). The Refine panel's Rules group keeps its own Save of the rule query, which is a query-editor action.
2. **Loading a saved search replaces the whole search**, from the suggestions and from the Refine panel's saved chips (spec 5.4; PR 2 ruling 4 said PR 4 would change the panel).
3. **A typed recent applies as typed text does** (`copyWith(query:)`, axes kept); an asked recent replays its answer (stored parse, no model) or asks again when an older prompt wrote it.
4. **Typed searches are recorded on Enter, or when the field loses focus after the diver typed a valid query** (spec 5.5). A query that arrived from outside (a chip, an answer, a saved search) is not recorded as typed.
5. **Asked recents show only where Ask can answer;** typed recents always show.
6. **Hints follow the diver's units** (`depth > 30m` or `depth > 100ft`), and `buddy = <name>` uses the diver's first buddy, or is left out when there is none. The field's own hint text (PR 1's "Search, or try depth > 30m") is unchanged here; making it unit-aware is a follow-up.
7. **One-condition "and" groups are no longer built** by the custom-field and gear-attribute lowerings. They behave the same, but a printed and re-parsed search did not compare equal, which the census and Undo comparisons need.

## Review Focus

1. **A saved search whose site, buddy or gear was deleted:** loading it applies with the flag the saved-query loader already gives, never an exception, and the chips show the stale label. Pinned in Task 6.
2. **Imperial diver:** a saved depth or temperature prints in the diver's units in the field and the recents list, and a recent typed in feet reloads to the same stored value. Pinned in Task 1 (census in feet) and Task 6.
3. **Recents of another diver or language** never show (the table is keyed by diver and locale). Pinned in Task 3.
4. **Typed and asked recents with the same text** do not overwrite each other. Pinned in Task 3.
5. **Saving with nothing to save** (no axis, no query, or "All dives" with no query) offers no Save. Pinned in Task 5.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `lib/features/dive_log/query/dive_filter_query.dart` | modify | no one-condition group for the custom-field axis |
| `lib/features/equipment/query/equipment_attr_condition_query.dart` | modify | no one-condition group for an attribute condition |
| `lib/core/query/presentation/query_text_field.dart` | modify | `onSubmitted`; `QueryTextOverride(text, commit: true)` |
| `lib/core/database/local_cache_database.dart` | modify | `RecentQueries.kind`, v19 rung, beforeOpen self-heal |
| `lib/features/explore/data/recent_query_repository.dart` | modify | kind-aware `list`, `recordTyped`, typed rows |
| `lib/features/explore/presentation/providers/recent_query_providers.dart` | modify | `recentTypedRecorderProvider` |
| `lib/features/dive_log/presentation/providers/dive_ask_providers.dart` | modify | `replay(RecentQuery)` |
| `lib/features/dive_log/presentation/widgets/search/dive_search_suggestions.dart` | create | saved chips, Manage, recents, hints |
| `lib/features/dive_log/presentation/widgets/search/dive_search_header.dart` | modify | Save, suggestions, typed recording, recents and hints taps |
| `lib/features/dive_log/presentation/widgets/refine/refine_panel.dart` | modify | a saved chip loads the whole search |
| `lib/l10n/arb/app_*.arb` | modify | 6 new keys |

---

### Task 0: Start from main with PR 3

- [ ] **Step 1:** Wait for #2857 to merge (auto-merge is on). Then:

```bash
git fetch origin main
git merge --no-edit origin/main
```

Expected: a clean merge; `lib/features/dive_log/presentation/providers/dive_ask_providers.dart` exists.

- [ ] **Step 2:** Run codegen (`dart run build_runner build --delete-conflicting-outputs`, from a scratchpad script because a bare `build` token is refused in Bash), then `flutter analyze`. Expected: no issues.

---

### Task 1: Every filter axis survives saving and reloading

**Files:**
- Modify: `lib/features/dive_log/query/dive_filter_query.dart` (custom-field axis)
- Modify: `lib/features/equipment/query/equipment_attr_condition_query.dart`
- Create: `test/features/dive_log/query/dive_filter_save_census_test.dart`

**Interfaces:**
- Produces: no API; the census guards every later change to `DiveFilterState`.

- [ ] **Step 1: Write the failing census**

Create `test/features/dive_log/query/dive_filter_save_census_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/presentation/query_tree_edit.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/query/dive_filter_query.dart';
import 'package:submersion/features/dive_log/query/dive_query_entity.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';

/// Spec 5.4: Save writes toQuery() of the whole search and loading shows it
/// as text. Every axis must survive the saved JSON, relabelling from the
/// name index, printing and re-parsing, or a saved search would come back
/// different from what the diver saved.
void main() {
  const labels = {
    QuerySubject.sites: {'Salt Pier': 's1', 'Bari Reef': 's2'},
    QuerySubject.trips: {'Bonaire 2025': 't1'},
    QuerySubject.centers: {'Buddy Dive': 'c1'},
    QuerySubject.computers: {'Perdix': 'k1'},
    QuerySubject.diveTypes: {'Shore': 'shore'},
    QuerySubject.tags: {'Night': 'g1', 'Wreck': 'g2'},
    QuerySubject.equipment: {'Reg A': 'e1'},
    QuerySubject.buddies: {'Ana Lee': 'b1'},
    QuerySubject.species: {'Turtle': 'sp1'},
  };
  final samples = <String, DiveFilterState>{
    'startDate': DiveFilterState(startDate: DateTime(2025, 1, 1)),
    'endDate': DiveFilterState(endDate: DateTime(2025, 6, 30)),
    'diveTypeId': const DiveFilterState(diveTypeId: 'shore'),
    'siteId': const DiveFilterState(siteId: 's1'),
    'tripId': const DiveFilterState(tripId: 't1'),
    'diveCenterId': const DiveFilterState(diveCenterId: 'c1'),
    'minDepth': const DiveFilterState(minDepth: 10),
    'maxDepth': const DiveFilterState(maxDepth: 30.5),
    'favoritesOnly': const DiveFilterState(favoritesOnly: true),
    'excludedFromStatsOnly': const DiveFilterState(excludedFromStatsOnly: true),
    'decoOnly': const DiveFilterState(decoOnly: false),
    'noBuddyOnly': const DiveFilterState(noBuddyOnly: true),
    'tagIds': const DiveFilterState(tagIds: ['g1', 'g2']),
    'weekdays': const DiveFilterState(weekdays: [1, 6]),
    'equipmentIds': const DiveFilterState(equipmentIds: ['e1']),
    'buddyNameFilter': const DiveFilterState(buddyNameFilter: 'Ana'),
    'buddyId': const DiveFilterState(buddyId: 'b1'),
    'diveIds': const DiveFilterState(diveIds: ['d1', 'd2']),
    'minO2Percent': const DiveFilterState(minO2Percent: 28),
    'maxO2Percent': const DiveFilterState(maxO2Percent: 36),
    'minRating': const DiveFilterState(minRating: 4),
    'minBottomTimeMinutes': const DiveFilterState(minBottomTimeMinutes: 30),
    'maxBottomTimeMinutes': const DiveFilterState(maxBottomTimeMinutes: 60),
    'computerId': const DiveFilterState(computerId: 'k1'),
    'customFieldKey': const DiveFilterState(customFieldKey: 'Guide'),
    'customFieldValue': const DiveFilterState(
      customFieldKey: 'Guide',
      customFieldValue: 'Sam',
    ),
    'equipmentAttrConditions': const DiveFilterState(
      equipmentAttrConditions: [
        EquipmentAttrCondition(key: 'hose_type', choices: {'hp', 'lpi'}),
      ],
    ),
    'minWaterTemp': const DiveFilterState(minWaterTemp: 18),
    'maxWaterTemp': const DiveFilterState(maxWaterTemp: 26),
    'minVisibility': const DiveFilterState(minVisibility: 5),
    'maxVisibility': const DiveFilterState(maxVisibility: 20),
    'waterTypes': const DiveFilterState(waterTypes: [WaterType.salt]),
    'speciesIds': const DiveFilterState(speciesIds: ['sp1']),
    'siteIds': const DiveFilterState(siteIds: ['s1', 's2']),
    'query': DiveFilterState(query: TextNode(['manta'])),
  };

  test('every DiveFilterState field has a sample', () {
    final state = File(
      p.join('lib', 'features', 'dive_log', 'domain', 'models',
          'dive_filter_state.dart'),
    ).readAsStringSync();
    final fields = RegExp(r'^  final [\w<>?, ]+ (\w+);', multiLine: true)
        .allMatches(state)
        .map((m) => m[1]!)
        .toSet()
      // Not a search axis: it switches the others off (spec 5.3).
      ..remove('axesSuspended');
    expect(fields.difference(samples.keys.toSet()), isEmpty);
  });

  for (final (unitName, prefs) in [
    ('metric', kMetricPrefs),
    (
      'imperial',
      const UnitPrefs(
        depth: DepthUnit.feet,
        temperature: TemperatureUnit.fahrenheit,
        pressure: PressureUnit.psi,
        weight: WeightUnit.pounds,
        volume: VolumeUnit.cubicFeet,
      ),
    ),
  ]) {
    final ctx = QueryEditorContext(
      registry: appQueryRegistry,
      root: diveQueryEntity,
      prefs: prefs,
      names: const MapNameResolver(labels),
      labels: const MapQueryLabels(),
      now: () => DateTime(2026, 9, 25),
    );
    final index = NameIndex([
      for (final MapEntry(key: subject, value: byLabel) in labels.entries)
        for (final MapEntry(key: label, value: id) in byLabel.entries)
          NameEntry(
            subject: subject,
            label: label,
            ids: [id],
            target: NameTarget.forSubject(subject),
          ),
    ]);
    for (final MapEntry(key: name, value: filter) in samples.entries) {
      test('$name survives save and reload ($unitName)', () {
        final saved = normalizeQuery(filter.toQuery())!;
        final reloaded = queryNodeFromJson(
          (jsonDecode(jsonEncode(queryNodeToJson(saved))) as Map)
              .cast<String, Object?>(),
        );
        expect(reloaded, saved, reason: 'JSON');
        final shown = refreshRefLabels(
          reloaded,
          diveQueryEntity,
          appQueryRegistry,
          index,
        );
        final text = ctx.printer.print(shown);
        final reparsed = switch (ctx.parser.parse(text)) {
          ParseOk(:final node) => normalizeQuery(node),
          ParseFailure(:final error) => fail('"$text": ${error.message}'),
        };
        expect(
          jsonEncode(queryNodeToJson(_idsOnly(reparsed!))),
          jsonEncode(queryNodeToJson(_idsOnly(saved))),
          reason: text,
        );
      });
    }
  }
}

/// [node] with every ref label dropped, so a tree compares by ids: the
/// saved query stores ids and relabels them on load.
QueryNode _idsOnly(QueryNode node) => switch (node) {
  AndNode(:final children) => AndNode([for (final c in children) _idsOnly(c)]),
  OrNode(:final children) => OrNode([for (final c in children) _idsOnly(c)]),
  NotNode(:final child) => NotNode(_idsOnly(child)),
  ScopedNode(:final path, :final inner) => ScopedNode(path, _idsOnly(inner)),
  ConditionNode(:final path, :final op, :final value) =>
    ConditionNode(path, op, _valueIdsOnly(value)),
  TextNode() => node,
};

QueryValue? _valueIdsOnly(QueryValue? v) => switch (v) {
  RefValue(:final id) => RefValue(id, null),
  ListValue(:final items) => ListValue([for (final i in items) _valueIdsOnly(i)!]),
  _ => v,
};
```

`NameTarget.forSubject` stands for the target of a plain entity reference of each subject; if `NameTarget` has no such helper, map each subject to its id target explicitly (`QuerySubject.sites => NameTarget.siteId`, and so on, from `lib/core/query/names/name_index.dart`). If `RefValue`'s constructor differs (`RefValue(id, label)` is what the probe printed), match it.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_log/query/dive_filter_save_census_test.dart`
Expected: `customFieldKey` and `equipmentAttrConditions` fail in both unit systems (a one-condition "and" group inside a scoped search re-parses without the group); every other axis passes. (A probe on 2026-10-03 found exactly these two.)

- [ ] **Step 3: Implement**

In `dive_filter_query.dart`, the custom-field part becomes:

```dart
    if (customFieldKey != null && customFieldKey!.isNotEmpty) {
      final key = c('key', QueryOp.eq, StringValue(customFieldKey!));
      final value = customFieldValue;
      parts.add(
        ScopedNode(
          FieldPath(['customFields']),
          // No one-condition group: it re-parses without it (#2773 census).
          value == null || value.isEmpty
              ? key
              : AndNode([
                  key,
                  c('value', QueryOp.contains, StringValue(value)),
                ]),
        ),
      );
    }
```

In `equipment_attr_condition_query.dart`, build the parts as a list and return the single part directly when there is one:

```dart
QueryNode equipmentAttrConditionNode(EquipmentAttrCondition cond) {
  QueryNode c(String key, QueryOp op, QueryValue v) =>
      ConditionNode(FieldPath([key]), op, v);
  final types = cond.types.map((t) => t.name).toList()..sort();
  final choices = cond.choices.toList()..sort();
  final parts = <QueryNode>[
    if (types.isNotEmpty)
      c(
        'type',
        QueryOp.inList,
        ListValue([for (final t in types) EnumValue(t)]),
      ),
    ScopedNode(
      FieldPath(['attributes']),
      AndNode([
        c('key', QueryOp.eq, StringValue(cond.key)),
        c('custom', QueryOp.eq, const BoolValue(false)),
        if (choices.isNotEmpty)
          c(
            'valueText',
            QueryOp.inList,
            ListValue([for (final ch in choices) StringValue(ch)]),
          ),
        if (cond.min != null)
          c('valueNum', QueryOp.gte, NumberValue(cond.min!, null)),
        if (cond.max != null)
          c('valueNum', QueryOp.lte, NumberValue(cond.max!, null)),
      ]),
    ),
  ];
  // No one-condition group: it re-parses without it (#2773 census).
  return parts.length == 1 ? parts.single : AndNode(parts);
}
```

- [ ] **Step 4: Run it, and the suites that read these lowerings**

Run: `flutter test test/features/dive_log/query test/features/equipment test/features/explore`
Expected: all pass. A test that pinned the old group shape is updated to the single condition (same semantics); say so in the commit.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log/query/dive_filter_query.dart lib/features/equipment/query/equipment_attr_condition_query.dart test/features/dive_log/query/dive_filter_save_census_test.dart
git commit -m "test(dive-log): every filter axis survives save and reload; drop one-condition groups"
```

---

### Task 2: QueryTextField submit and committing overrides

**Files:**
- Modify: `lib/core/query/presentation/query_text_field.dart`
- Test: `test/core/query/presentation/query_text_field_test.dart`

**Interfaces:**
- Produces:
  - `QueryTextField({..., VoidCallback? onSubmitted})`, called on Enter (the keyboard's search action).
  - `QueryTextOverride(String text, {bool commit = false})`: with `commit`, the text is parsed and committed as if typed (reported through `onTextChanged`, committed through `onChanged`), after the frame.

- [ ] **Step 1: Write the failing tests**

```dart
  testWidgets('Enter calls onSubmitted', (tester) async {
    var submitted = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QueryTextField(
            context: context,
            value: null,
            onChanged: (_) {},
            onSubmitted: () => submitted++,
            fieldKey: fieldKey,
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(fieldKey), 'manta');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    expect(submitted, 1);
  });

  testWidgets('a committing override applies the text as if typed', (
    tester,
  ) async {
    QueryNode? committed;
    final texts = <String>[];
    late StateSetter setOuter;
    QueryTextOverride? override;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (ctx, setState) {
              setOuter = setState;
              return QueryTextField(
                context: context,
                value: null,
                onChanged: (n) => committed = n,
                onTextChanged: texts.add,
                textOverride: override,
                fieldKey: fieldKey,
              );
            },
          ),
        ),
      ),
    );
    setOuter(() => override = QueryTextOverride('manta', commit: true));
    await tester.pump();
    await tester.pump();
    expect(committed, TextNode(['manta']));
    expect(texts, ['manta']);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/query/presentation/query_text_field_test.dart`
Expected: compile errors for `onSubmitted` and `commit`.

- [ ] **Step 3: Implement**

`QueryTextOverride`:

```dart
class QueryTextOverride {
  QueryTextOverride(this.text, {this.commit = false});
  final String text;

  /// Parse and commit [text] as if the diver typed it (a hint tapped),
  /// rather than only showing it (Undo).
  final bool commit;
}
```

Constructor `this.onSubmitted,` and field:

```dart
  /// Called when the diver presses Enter (the keyboard's search action).
  final VoidCallback? onSubmitted;
```

`TextField(... onSubmitted: (_) => widget.onSubmitted?.call(), ...)`.

In `didUpdateWidget`, at the end of the override block:

```dart
      if (override.commit) {
        // After the frame: committing calls the parent back, and this
        // runs inside its build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _onEdited(_controller.text);
        });
      }
```

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/core/query/presentation/query_text_field_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core/query/presentation/query_text_field.dart test/core/query/presentation/query_text_field_test.dart
git commit -m "feat(query): an Enter callback and committing overrides on QueryTextField"
```

---

### Task 3: Recent searches, typed and asked

**Files:**
- Modify: `lib/core/database/local_cache_database.dart`
- Modify: `lib/features/explore/data/recent_query_repository.dart`
- Modify: `lib/features/explore/presentation/providers/recent_query_providers.dart`
- Create: `test/core/database/local_cache_migration_v19_recent_kind_test.dart`
- Modify: `test/features/explore/data/recent_query_repository_test.dart`

**Interfaces:**
- Produces:
  - `enum RecentQueryKind { typed, asked }`
  - `RecentQuery` gains `final RecentQueryKind kind;` and `final QueryNode? node;` (typed rows; `parsed` stays for asked rows)
  - `RecentQueryRepository.recordTyped(String text, QueryNode node, {required String locale, required String diverId})`
  - `typedef RecentTypedRecorder = Future<void> Function(String text, QueryNode node, String locale, String diverId);` and `recentTypedRecorderProvider`

- [ ] **Step 1: Write the failing tests**

In `test/features/explore/data/recent_query_repository_test.dart` (it already sets up an in-memory cache database), add:

```dart
  test('typed and asked recents keep their kind and do not collide', () async {
    final repo = RecentQueryRepository();
    await repo.record(
      'manta',
      'en',
      const ParsedQuery(subject: ParsedSubject.dives),
      diverId: 'ana',
    );
    await repo.recordTyped('manta', TextNode(['manta']), locale: 'en', diverId: 'ana');
    final rows = await repo.list(diverId: 'ana', locale: 'en');
    expect(rows.map((r) => r.kind).toSet(), {
      RecentQueryKind.typed,
      RecentQueryKind.asked,
    });
    final typed = rows.singleWhere((r) => r.kind == RecentQueryKind.typed);
    expect(typed.node, TextNode(['manta']));
    expect(typed.sentence, 'manta');
  });

  test('a typed recent survives a list read', () async {
    final repo = RecentQueryRepository();
    await repo.recordTyped('depth > 30m', ConditionNode(
      FieldPath(['depth']),
      QueryOp.gt,
      const NumberValue(30, null),
    ), locale: 'en', diverId: 'ana');
    await repo.list(diverId: 'ana', locale: 'en');
    expect(await repo.list(diverId: 'ana', locale: 'en'), hasLength(1));
  });

  test('another diver or language never sees a typed recent', () async {
    final repo = RecentQueryRepository();
    await repo.recordTyped('manta', TextNode(['manta']), locale: 'en', diverId: 'ana');
    expect(await repo.list(diverId: 'ben', locale: 'en'), isEmpty);
    expect(await repo.list(diverId: 'ana', locale: 'de'), isEmpty);
  });
```

Create `test/core/database/local_cache_migration_v19_recent_kind_test.dart`, modelled on `local_cache_migration_v17_swiss_bathy_reference_level_test.dart`: build a v18 database file with the v18 `recent_queries` shape and one row, open it with the current `LocalCacheDatabase`, and assert the row reads back with `kind` `asked` and that a `typed` row can be inserted.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/explore/data/recent_query_repository_test.dart test/core/database/local_cache_migration_v19_recent_kind_test.dart`
Expected: compile errors (`recordTyped`, `RecentQueryKind`, `kind`).

- [ ] **Step 3: Implement**

`RecentQueries` table: add

```dart
  /// typed (a query the diver wrote) or asked (a sentence put to the
  /// model); older rows were all asked (#2773).
  TextColumn get kind => text().withDefault(const Constant('asked'))();
```

`schemaVersion => 19`, and the rung (after the v18 one):

```dart
      // v19: recent searches gain a kind, typed or asked (#2773). Rows the
      // v18 rung created were all asked; the column default says so.
      if (from < 19) {
        final cols = await customSelect(
          "PRAGMA table_info('recent_queries')",
        ).get();
        final names = cols.map((c) => c.read<String>('name')).toSet();
        if (names.isNotEmpty && !names.contains('kind')) {
          await m.addColumn(recentQueries, recentQueries.kind);
        }
      }
```

In `beforeOpen`, add `kind TEXT NOT NULL DEFAULT 'asked',` to the `CREATE TABLE IF NOT EXISTS recent_queries` statement, and after it the same column check as the rung, issuing `ALTER TABLE recent_queries ADD COLUMN kind TEXT NOT NULL DEFAULT 'asked'` when the column is missing.

Repository:

```dart
enum RecentQueryKind { typed, asked }
```

`RecentQuery` gains `kind` and `node` (both constructor parameters; `kind` defaults to `RecentQueryKind.asked`). Keys are prefixed by kind so the same text typed and asked are two rows: `static String keyFor(String sentence, [RecentQueryKind kind = RecentQueryKind.asked]) => '${kind.name}:${fuzzy.normalize(sentence).replaceAll(RegExp(r'\s+'), ' ')}';` (existing asked rows keep their old, unprefixed keys; a re-asked sentence then writes a prefixed row and the old one ages out under the cap).

`record` writes `kind: const Value('asked')`. New:

```dart
  /// A query the diver typed and committed. Stored as its tree, so it
  /// prints in the diver's current units when shown.
  Future<void> recordTyped(
    String text,
    QueryNode node, {
    required String locale,
    required String diverId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.recentQueries)
        .insertOnConflictUpdate(
          RecentQueriesCompanion(
            diverId: Value(diverId),
            key: Value(keyFor(text, RecentQueryKind.typed)),
            sentence: Value(text),
            locale: Value(locale),
            parsedJson: Value(jsonEncode(queryNodeToJson(node))),
            schemaVersion: const Value(0),
            subject: const Value('dives'),
            kind: const Value('typed'),
            lastUsedAt: Value(now),
          ),
        );
    await _trim(diverId);
  }
```

Move the cap `DELETE` from `record` into `Future<void> _trim(String diverId)` and call it from both. In `list`, branch on `r.kind` before the schema checks: a `typed` row decodes `queryNodeFromJson` (a `FormatException` or schema error marks it stale) into `RecentQuery(kind: typed, node: ..., parsed: null, ...)`; an `asked` row keeps today's path.

`recent_query_providers.dart`:

```dart
typedef RecentTypedRecorder =
    Future<void> Function(
      String text,
      QueryNode node,
      String locale,
      String diverId,
    );

// no-tick: a write function, as recentQueryRecorderProvider.
final recentTypedRecorderProvider = Provider<RecentTypedRecorder>((ref) {
  final repo = ref.watch(recentQueryRepositoryProvider);
  return (text, node, locale, diverId) =>
      repo.recordTyped(text, node, locale: locale, diverId: diverId);
});
```

Run codegen (scratchpad script) after the table change. Search the tests for a hard-coded cache schema version (`grep -rn "schemaVersion, 18" test`) and update it to 19.

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/features/explore test/core/database`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/core/database/local_cache_database.dart lib/features/explore test/core/database test/features/explore
git commit -m "feat(explore): recent searches remember whether they were typed or asked"
```

---

### Task 4: Replay an asked recent

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/dive_ask_providers.dart`
- Test: `test/features/dive_log/presentation/providers/dive_ask_providers_test.dart`

**Interfaces:**
- Consumes: `RecentQuery` (Task 3).
- Produces: `Future<String?> replay(RecentQuery recent)`, same return contract as `ask`.

- [ ] **Step 1: Write the failing tests**

```dart
  test('a recent with a current parse replays without the model', () async {
    final engine = _Engine(_turtles);
    final c = make(engine);
    final parsed = ParsedQuery.fromJson(
      (jsonDecode(_deep) as Map).cast<String, Object?>(),
    );
    final route = await askOf(c).replay(
      RecentQuery(
        sentence: 'deep dives',
        locale: 'en',
        parsed: parsed,
        lastUsedAt: DateTime(2026, 10, 1),
      ),
    );
    expect(route, isNull);
    expect(engine.compileCalls, 0);
    expect(boundOf(stateOf(c).answer!.compiled, 'depth', QueryOp.gte), 40);
  });

  test('a recent from an older prompt asks the model again', () async {
    final engine = _Engine(_deep);
    final c = make(engine);
    await askOf(c).replay(
      RecentQuery(
        sentence: 'deep dives',
        locale: 'en',
        parsed: null,
        lastUsedAt: DateTime(2026, 10, 1),
      ),
    );
    expect(engine.compileCalls, 1);
  });
```

(`import 'dart:convert';` and the `RecentQuery` import from `recent_query_repository.dart`.)

- [ ] **Step 2: Run them to verify they fail**

Expected: compile error, `replay` not defined.

- [ ] **Step 3: Implement**

```dart
  /// A recent asked sentence: its stored parse when the current prompt
  /// wrote it (no model call), otherwise the model again, so an older
  /// parse's invented period is not replayed (#2838).
  Future<String?> replay(RecentQuery recent) async {
    final parsed = recent.parsed;
    if (parsed == null) return ask(recent.sentence);
    final request = ++_request;
    state = const AskState(running: true);
    try {
      final names = await _ref.read(exploreNameIndexProvider.future);
      if (request != _request) return null;
      return _publish(
        AskAnswer(
          sentence: recent.sentence,
          parsed: parsed,
          compiled: _compile(parsed, names),
          previousQuery: _ref.read(diveFilterProvider).query,
        ),
        handOff: true,
      );
    } catch (e, stackTrace) {
      _log.error('Replaying a recent failed', error: e, stackTrace: stackTrace);
      _fail(request, NlError.unknown);
      return null;
    }
  }
```

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/features/dive_log/presentation/providers/dive_ask_providers_test.dart`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log/presentation/providers/dive_ask_providers.dart test/features/dive_log/presentation/providers/dive_ask_providers_test.dart
git commit -m "feat(dive-log): replay a recent question from its stored answer"
```

---

### Task 5: Save the whole search

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/search/dive_search_header.dart`
- Test: `test/features/dive_log/presentation/widgets/search/dive_search_header_test.dart`

**Interfaces:**
- Produces: `const kDiveSearchSaveKey = ValueKey('dive-search-save');`

- [ ] **Step 1: Write the failing tests**

```dart
  testWidgets('Save stores the whole search as one query', (tester) async {
    QueryNode? saved;
    await pumpHeader(
      tester,
      filter: DiveFilterState(minDepth: 30, query: TextNode(['manta'])),
      saveOverride: (node) => saved = node,
    );
    await tester.tap(find.byKey(kDiveSearchSaveKey));
    await tester.pumpAndSettle();
    expect(
      saved,
      normalizeQuery(
        DiveFilterState(minDepth: 30, query: TextNode(['manta'])).toQuery(),
      ),
    );
  });

  // Review Focus 5.
  testWidgets('no Save under All dives with nothing typed', (tester) async {
    await pumpHeader(
      tester,
      filter: const DiveFilterState(minDepth: 30, axesSuspended: true),
    );
    expect(find.byKey(kDiveSearchSaveKey), findsNothing);
  });
```

`saveOverride` is a new `pumpHeader` parameter that overrides a provider the header calls to save, so the test does not need the dialog. Add to `dive_search_providers.dart`:

```dart
/// Saves a dive query under a name the diver gives; a provider so tests
/// can stand in for the dialog and the repository.
final diveSearchSaverProvider =
    Provider<Future<void> Function(BuildContext context, WidgetRef ref, QueryNode node)>(
      (ref) => (context, widgetRef, node) => saveQueryFromEditor(
        context,
        widgetRef,
        subject: QuerySubject.dives,
        node: node,
      ),
    );
```

and in the test harness `if (saveOverride != null) diveSearchSaverProvider.overrideWithValue((context, ref, node) async => saveOverride(node))`.

- [ ] **Step 2: Run them to verify they fail**

Expected: compile error, `kDiveSearchSaveKey` not defined.

- [ ] **Step 3: Implement**

In the chip row, before Open in Insights:

```dart
                  if (normalizeQuery(filter.toQuery()) case final whole?)
                    IconButton(
                      key: kDiveSearchSaveKey,
                      tooltip: l10n.common_action_save,
                      icon: const Icon(Icons.bookmark_add_outlined),
                      onPressed: () =>
                          ref.read(diveSearchSaverProvider)(context, ref, whole),
                    ),
```

(`toQuery()` honours "All dives": it then returns the typed query alone, and null when nothing is typed.)

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/search/`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log test/features/dive_log
git commit -m "feat(dive-log): save the whole search from the search row"
```

---

### Task 6: Suggestions under an empty field

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/search/dive_search_suggestions.dart`
- Modify: `lib/features/dive_log/presentation/widgets/search/dive_search_header.dart`
- Modify: `lib/l10n/arb/app_*.arb` (6 keys), then `flutter gen-l10n`
- Test: `test/features/dive_log/presentation/widgets/search/dive_search_suggestions_test.dart`

**Interfaces:**
- Consumes: `recentQueriesProvider`, `RecentQuery`/`RecentQueryKind` (Task 3), `SavedQueryChipRow`, `exploreEnabledProvider`, `allBuddiesProvider`, `queryUnitPrefsProvider`.
- Produces: `DiveSearchSuggestions({required ValueChanged<SavedQueryLoad> onSaved, required ValueChanged<RecentQuery> onRecent, required ValueChanged<String> onHint})`; keys `kDiveSearchSuggestionsKey`, `kDiveSearchManageSavedKey`.

New strings (`app_en.arb`, after `diveLog_ask_asked`):

```json
  "diveLog_search_manageSaved": "Manage",
  "diveLog_search_recentTitle": "Recent",
  "diveLog_search_recentTyped": "Typed search",
  "diveLog_search_recentAsked": "Asked question",
  "diveLog_search_hintsTitle": "Try",
  "diveLog_search_hintAsk": "or ask a question",
```

| key | ar | de | es | fr | he | hu | it | nl | pt | zh |
|---|---|---|---|---|---|---|---|---|---|---|
| manageSaved | إدارة | Verwalten | Gestionar | Gérer | ניהול | Kezelés | Gestisci | Beheren | Gerenciar | 管理 |
| recentTitle | الأخيرة | Zuletzt | Recientes | Récentes | אחרונים | Legutóbbiak | Recenti | Recent | Recentes | 最近 |
| recentTyped | بحث مكتوب | Eingegebene Suche | Búsqueda escrita | Recherche saisie | חיפוש שהוקלד | Begépelt keresés | Ricerca digitata | Getypte zoekopdracht | Pesquisa digitada | 输入的搜索 |
| recentAsked | سؤال مطروح | Gestellte Frage | Pregunta hecha | Question posée | שאלה שנשאלה | Feltett kérdés | Domanda posta | Gestelde vraag | Pergunta feita | 提出的问题 |
| hintsTitle | جرّب | Probieren Sie | Prueba | Essayez | נסו | Próbáld | Prova | Probeer | Experimente | 试试 |
| hintAsk | أو اطرح سؤالًا | oder stellen Sie eine Frage | o haz una pregunta | ou posez une question | או שאלו שאלה | vagy tegyél fel egy kérdést | o fai una domanda | of stel een vraag | ou faça uma pergunta | 或提出问题 |

(Keys are prefixed `diveLog_search_` in the ARBs.)

- [ ] **Step 1: Write the failing tests**

Create `dive_search_suggestions_test.dart` with overrides for `savedQueryLoadsProvider('dives')`, `recentQueriesProvider`, `exploreEnabledProvider`, `allBuddiesProvider` and `queryUnitPrefsProvider`, rendering `DiveSearchSuggestions` with recording callbacks:

```dart
  testWidgets('lists saved searches, recents with their kind, and hints', (
    tester,
  ) async {
    await pumpSuggestions(
      tester,
      recents: [
        RecentQuery(
          sentence: 'manta',
          locale: 'en',
          parsed: null,
          kind: RecentQueryKind.typed,
          node: TextNode(['manta']),
          lastUsedAt: DateTime(2026, 10, 2),
        ),
        RecentQuery(
          sentence: 'turtles in Bonaire',
          locale: 'en',
          parsed: const ParsedQuery(subject: ParsedSubject.dives),
          lastUsedAt: DateTime(2026, 10, 1),
        ),
      ],
      askEnabled: true,
    );
    expect(find.text('Recent'), findsOneWidget);
    expect(find.byTooltip('Typed search'), findsOneWidget);
    expect(find.byTooltip('Asked question'), findsOneWidget);
    expect(find.text('depth > 30m'), findsOneWidget);
    expect(find.text('or ask a question'), findsOneWidget);
    await tester.tap(find.text('depth > 30m'));
    expect(hints, ['depth > 30m']);
    await tester.tap(find.text('manta'));
    expect(recentsTapped.single.sentence, 'manta');
  });

  // Review Focus 2.
  testWidgets('hints follow the diver units', (tester) async {
    await pumpSuggestions(tester, imperial: true);
    expect(find.text('depth > 100ft'), findsOneWidget);
  });

  testWidgets('asked recents hide where Ask cannot answer', (tester) async {
    await pumpSuggestions(
      tester,
      recents: [
        RecentQuery(
          sentence: 'turtles in Bonaire',
          locale: 'en',
          parsed: const ParsedQuery(subject: ParsedSubject.dives),
          lastUsedAt: DateTime(2026, 10, 1),
        ),
      ],
      askEnabled: false,
    );
    expect(find.text('turtles in Bonaire'), findsNothing);
    expect(find.text('or ask a question'), findsNothing);
  });

  testWidgets('the buddy hint uses a real buddy, or is left out', (
    tester,
  ) async {
    await pumpSuggestions(tester, buddyNames: ['Ana Lee']);
    expect(find.text('buddy = "Ana Lee"'), findsOneWidget);
  });
```

In `dive_search_header_test.dart`:

```dart
  testWidgets('an empty focused field shows suggestions; typing hides them', (
    tester,
  ) async {
    await pumpHeader(tester);
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pump();
    expect(find.byKey(kDiveSearchSuggestionsKey), findsOneWidget);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump();
    expect(find.byKey(kDiveSearchSuggestionsKey), findsNothing);
  });

  // Review Focus 1.
  testWidgets('a saved search loads as the whole search, axes cleared', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      filter: const DiveFilterState(minDepth: 30),
      savedLoads: [
        SavedQueryLoad(
          SavedQuery(id: 'q1', name: 'Mantas', subject: 'dives', diverId: 'd'),
          node: TextNode(['manta']),
        ),
      ],
    );
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pump();
    await tester.tap(find.text('Mantas'));
    await tester.pumpAndSettle();
    expect(filterOf(), DiveFilterState(query: TextNode(['manta'])));
  });

  testWidgets('Enter records a typed search', (tester) async {
    final typed = <String>[];
    await pumpHeader(tester, typedRecorder: (text, node, l, d) async => typed.add(text));
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(typed, ['manta']);
  });

  testWidgets('a hint is typed in and applied', (tester) async {
    await pumpHeader(tester);
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pump();
    await tester.tap(find.text('manta'));
    await tester.pump();
    await tester.pump(kDiveSearchDebounce * 2);
    expect(filterOf().query, TextNode(['manta']));
  });
```

(`savedLoads` and `typedRecorder` are new `pumpHeader` parameters overriding `savedQueryLoadsProvider('dives')` and `recentTypedRecorderProvider`; the `SavedQuery` constructor follows `lib/features/query/domain/entities/`.)

- [ ] **Step 2: Run them to verify they fail**

Expected: compile errors (`DiveSearchSuggestions`, `kDiveSearchSuggestionsKey`, the new keys).

- [ ] **Step 3: Implement**

Add the 6 strings to all 11 ARBs, `flutter gen-l10n`, then create `dive_search_suggestions.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/explore/data/recent_query_repository.dart';
import 'package:submersion/features/explore/presentation/providers/explore_gate_providers.dart';
import 'package:submersion/features/explore/presentation/providers/recent_query_providers.dart';
import 'package:submersion/features/query/domain/saved_query_load.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/features/query/presentation/widgets/saved_query_chip_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const kDiveSearchSuggestionsKey = ValueKey('dive-search-suggestions');
const kDiveSearchManageSavedKey = ValueKey('dive-search-manage-saved');

/// What the empty search field offers (#2773, spec 4.1 state 2): saved
/// searches with a Manage link, recent searches (typed and asked, marked),
/// and syntax hints in the diver's units.
class DiveSearchSuggestions extends ConsumerWidget {
  const DiveSearchSuggestions({
    super.key,
    required this.onSaved,
    required this.onRecent,
    required this.onHint,
  });

  final ValueChanged<SavedQueryLoad> onSaved;
  final ValueChanged<RecentQuery> onRecent;
  final ValueChanged<String> onHint;

  static const _recentShown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final askEnabled = ref.watch(exploreEnabledProvider);
    final recents = [
      for (final r in ref.watch(recentQueriesProvider).value ?? const [])
        if (r.kind == RecentQueryKind.typed || askEnabled) r,
    ].take(_recentShown).toList();
    final metric = ref.watch(queryUnitPrefsProvider).depth == DepthUnit.meters;
    final buddy = ref.watch(allBuddiesProvider).value?.firstOrNull?.name;
    final hints = [
      'manta',
      '"blue hole"',
      metric ? 'depth > 30m' : 'depth > 100ft',
      if (buddy != null) 'buddy = "$buddy"',
    ];
    // Inside the field's tap region, like the jump rows: a desktop mouse
    // press elsewhere unfocuses the field before the tap lands.
    return TextFieldTapRegion(
      child: Padding(
        key: kDiveSearchSuggestionsKey,
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: SavedQueryChipRow(
                    subject: QuerySubject.dives,
                    onApply: onSaved,
                  ),
                ),
                TextButton(
                  key: kDiveSearchManageSavedKey,
                  onPressed: () => context.push('/saved-queries'),
                  child: Text(l10n.diveLog_search_manageSaved),
                ),
              ],
            ),
            if (recents.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(l10n.diveLog_search_recentTitle, style: theme.textTheme.labelLarge),
              for (final r in recents)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Tooltip(
                    message: r.kind == RecentQueryKind.typed
                        ? l10n.diveLog_search_recentTyped
                        : l10n.diveLog_search_recentAsked,
                    child: Icon(
                      r.kind == RecentQueryKind.typed
                          ? Icons.history
                          : Icons.auto_awesome,
                      size: 18,
                    ),
                  ),
                  title: Text(r.sentence, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => onRecent(r),
                ),
            ],
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.diveLog_search_hintsTitle, style: theme.textTheme.labelLarge),
                for (final h in hints)
                  ActionChip(
                    label: Text(h, style: const TextStyle(fontFamily: 'monospace')),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onHint(h),
                  ),
                if (askEnabled)
                  Text(l10n.diveLog_search_hintAsk, style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

Header changes:

- `QueryTextField(... onSubmitted: _recordTyped, ...)`.
- A flag `bool _typedSinceRecord = false;` set true in `_onTextChanged` when the text is non-empty, cleared in `_recordTyped` and in the filter listener (a query from outside is not typed).
- In `_onFocusChange`, when focus is lost and `_typedSinceRecord`, call `_recordTyped()`.
- `_recordTyped()`:

```dart
  /// Remembers the query the diver typed (Enter, or leaving the field
  /// after typing), for the recent searches; a convenience, so a failure
  /// is logged, never shown.
  Future<void> _recordTyped() async {
    final node = _local;
    if (node == null || !_typedSinceRecord) return;
    _typedSinceRecord = false;
    final text = _editorContext().printer.print(node);
    final locale = ref.read(localeProvider);
    final record = ref.read(recentTypedRecorderProvider);
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      await record(text, node, locale, diverId ?? '');
    } catch (e, stackTrace) {
      _log.warning('Could not remember a typed search', error: e, stackTrace: stackTrace);
    }
  }
```

(`const _log = LoggerService('DiveSearchHeader');` at the top of the file.)

- Suggestions show while the field has focus and is empty: `final showSuggestions = _focus.hasFocus && _local == null && _text.trim().isEmpty;`, placed after the Ask notice: `if (showSuggestions) DiveSearchSuggestions(onSaved: _applySaved, onRecent: _applyRecent, onHint: _applyHint),`.
- Handlers:

```dart
  /// A saved search is the whole search (spec 5.4): the axes clear.
  void _applySaved(SavedQueryLoad load) {
    _debounce?.cancel();
    ref.read(diveFilterProvider.notifier).state = DiveFilterState(
      query: load.node,
    );
  }

  void _applyRecent(RecentQuery recent) {
    if (recent.kind == RecentQueryKind.typed) {
      final notifier = ref.read(diveFilterProvider.notifier);
      notifier.state = notifier.state.copyWith(
        query: recent.node,
        clearQuery: recent.node == null,
      );
      return;
    }
    setState(() => _text = recent.sentence);
    _runAsk(recent.sentence, () => ref.read(diveAskProvider.notifier).replay(recent));
  }

  void _applyHint(String hint) {
    setState(() => _textOverride = QueryTextOverride(hint, commit: true));
    _focus.requestFocus();
  }
```

- Refactor `_ask()` so its body after the guard is `_runAsk(sentence, () => ref.read(diveAskProvider.notifier).ask(sentence));`, where `_runAsk(String sentence, Future<String?> Function() run)` holds today's flush, await, `_text` clearing and navigation.

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/features/dive_log/presentation/widgets/search/ test/l10n`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/l10n/arb lib/features/dive_log test/features/dive_log
git commit -m "feat(dive-log): saved searches, recent searches and hints under an empty search field"
```

---

### Task 7: The Refine panel's saved chips load the whole search

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/refine/refine_panel.dart:175-189`
- Test: `test/features/dive_log/presentation/widgets/refine/refine_panel_test.dart`

- [ ] **Step 1: Write the failing test**

Following the panel test's existing saved-chip test (search it for `SavedQueryChipRow` or `savedQueryLoadsProvider`), change its expectation, or add one: with `DiveFilterState(minDepth: 30)` in the target provider, tapping a saved chip whose node is `TextNode(['manta'])` leaves exactly `DiveFilterState(query: TextNode(['manta']))`.

- [ ] **Step 2: Run it to verify it fails**

Expected: FAIL, `minDepth` is still 30 (the chip keeps the other axes today).

- [ ] **Step 3: Implement**

```dart
            onApply: (load) {
              // The whole saved search (spec 5.4): the axes clear.
              ref.read(widget.filterProvider.notifier).state = DiveFilterState(
                query: load.node,
              );
              widget.onApplied?.call();
              _close();
            },
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/refine/ test/features/insights test/features/connections`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format lib test
git add lib/features/dive_log/presentation/widgets/refine/refine_panel.dart test/features/dive_log/presentation/widgets/refine/
git commit -m "feat(dive-log): a saved chip in the Refine panel loads the whole saved search"
```

---

### Task 8: Whole-branch checks

- [ ] **Step 1:** `flutter test test/architecture`, then the full suite to a log file. Expected: all pass.
- [ ] **Step 2:** `dart format --set-exit-if-changed lib test && flutter analyze`. Expected: clean.
- [ ] **Step 3:** Confirm by test name that spec 9 rows 6 (recent sentences) and 8 (saved queries) and spec 7 "Save" each have a passing test; list them in the PR body, which says `Closes #2773`.
