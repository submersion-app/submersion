# Query Language PR 4: Buddies, Centers, Certifications, Courses and Species Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the five lists that have no filter today (buddies, dive centers, certifications, courses, marine-life species) the query engine: complete their registries (enum fields, text search, relations), add one query state per list with a filter icon, a filter sheet, removable chips and a "nothing matches" state, narrow each list in SQL through an id set, move the course status chips into that SQL path, and add the `certifications.buddy_id` index at schema rung 245.

**Architecture:** PR 3 built every shared piece except the ones a list with no filter sheet needs. This plan adds those once in `lib/features/query/`: `entityQueryIdsProvider` (a compiled query's id set for any root entity), `narrowByQuery` (the list narrowed by it, a pass-through with no query), and three widgets (`QueryFilterButton` with `showQueryFilterSheet`, `QueryChipsFrame`, `QueryNoMatchState`). Each list then gets a `StateProvider<QueryNode?>` (courses: a small `CourseFilterState` holding the status chips and the query) and one `filtered...Provider` that every view of that list (list, compact pane, table) reads, so loading, sorting and grouping stay where they are. Each list's search route is unchanged; its columns become the registry's `textSearchSql`, so a bare word in a query searches the same columns.

**Tech Stack:** Flutter, Riverpod 3 (hand-written providers, legacy `StateProvider`), Drift (split database layout), the ARB pipeline (`flutter gen-l10n`, generated Dart committed), `scripts/gen_query_label_lookup.py`.

**Spec:** `docs/design/specs/2026-09-25-entity-query-language-design.md`, Units 3, 5 ("Other entities") and 6 ("Placement": "Buddies, centers, certifications, courses, species: a new filter icon in the app bar"), plus "Amendments recorded while planning PR 1" and the three "Deviations recorded during implementation" sections (PR 1, PR 2, PR 3), which are authoritative where the body differs. Program issue #2365 (`Refs #2365`; PR 5 closes it).

## Decisions settled for this plan

Settled with Eric on 2026-09-28, or ruled here where the code forced a choice. Each is recorded in the spec in Task 13.

- **Species: both pages** (Eric). The nav Species page (the diver's sighted species, `seenSpeciesProvider`) and the Manage catalog (`speciesListNotifierProvider`, all ~685 rows) each get a query, held separately (`seenSpeciesQueryProvider`, `speciesCatalogQueryProvider`), both over `QuerySubject.species`, so saved species queries serve either page.
- **Course status chips move into SQL** (Eric). `CourseFilterState(status, query)` lowers In progress to `completionDate:none` and Completed to `completionDate:any`, ANDed with the query. The chips now read and write that state, so they also apply in table mode, which ignored them before.
- **Full registries** (Eric): enum fields where the column stores an enum name (certification `agency` and `level`, course `agency`, species `category`), text search over each list's existing search columns, and relations: buddy `dives`; certification `buddy`, `instructor`, `course`; course `instructor`, `certification`, `dives`; center `dives`; species `sightings`, `sites`, `dives`.
- **Index rung 245** (Eric): `idx_certifications_buddy_id` on `certifications(buddy_id)`, index-only, re-asserted in `beforeOpen`. Main is at 242; 243 is held by #2409, 244 by #2538, 241 by both #2493 and #2562 (their clash, not ours), 236 by #2407. Re-scan before the push.
- **Search routes stay.** Buddies, certifications and centers search in a separate `showSearch` route that never narrowed the list; courses have no search UI. The spec's "existing `LIKE` search expressed as a `Text` node" becomes each registry's `textSearchSql` over the same columns, so a bare quoted word in a query matches what the search route matches. The routes themselves are unchanged.
- **Enum text compares the stored name.** A certification whose stored `level` is not a `CertificationLevel` name (a legacy or imported string) matches `level:any` but no `level = X`, including `level = other`; the Dart mapper shows it as Other. The same holds for course agency and species category.
- **Species text search is English for built-ins.** SQL sees the stored English `common_name`; the pages' own search fields keep matching the translated name as well. A query's bare word therefore finds a built-in species by its English or scientific name only.
- **Relations are not diver-scoped.** As with PR 3's `sites.dives`, a hop reaches every diver's rows: `species.sightings.count >= 3` on the nav Species page counts every diver's sightings of that species, and the page still lists only this diver's species.
- **The dive center map stays unfiltered**, like the site map: only the list, compact pane and table read the filter.
- **Search delegates move to their own files** (buddies, certifications, centers), so the three content files, already over the 800-line cap, end smaller than on main after the filter wiring.

## Global Constraints

- Branch `ericgriffin/query-lang-pr4-people-and-species` in worktree `.claude/worktrees/query-lang-pr3-sites-equipment-trips` (reused after PR 3 merged), off `origin/main` at `8d6ab69c821`. Run every command from that directory. It is initialised (submodules, `flutter pub get`, codegen).
- No em-dashes anywhere (code, comments, docs, commits, PR text); no spaced hyphen or double hyphen as prose punctuation. No emojis. No mention of the tool or its vendor in anything written to the repository or GitHub.
- TDD: each task writes its failing test first, runs it red, then implements.
- Values reach SQL only as bound parameters; table and column names come only from registry constants.
- Anything showing a number with a unit uses the active diver's unit settings (`queryUnitPrefsProvider`); stored values stay metric.
- Schema: `currentSchemaVersion` becomes **245**. The database is split: helpers in `lib/core/database/migrations/helpers/*.dart`, steps in `migrations/ladder/rungs_v231_onward.dart`, backstops in `migrations/before_open.dart`; `database.dart` keeps only `migrationVersions`, `currentSchemaVersion` and the table list.
- New ARB keys go in `app_en.arb` (with `@` metadata) and all ten other locales (ar, de, es, fr, he, hu, it, nl, pt, zh), translated. After editing ARBs run `flutter gen-l10n` and commit the generated `lib/l10n/arb/app_localizations*.dart`; after adding any `query_*` key run `python3.14 scripts/gen_query_label_lookup.py`.
- Files stay under 800 lines; a file already over it must not grow. Split by responsibility. Imports grouped dart, flutter, packages, local.
- Some Dart files are CRLF (`site_filter_sheet.dart` among them): after any scripted rewrite, `git diff --numstat` must show only the lines you meant to change.
- After each task: `dart format .`, `flutter analyze --fatal-infos` clean, the task's tests green. Run `flutter test test/architecture/ test/l10n/` after any new `lib/` file or ARB change.
- Local `flutter test`: never pipe into `grep` without checking the tail; never run two suites at once. Check `df -h /Volumes/fltmp` before a long run.
- Commit only at the plan's commit steps, staging explicit paths. The PR touches `presentation/`; Eric decides on screenshots (he skipped them for PR 3). Open it with `Refs #2365`, then `gh pr edit <n> --add-reviewer "@copilot"`.

## Review Focus

Inputs the spec implies that a person would hit first, each pinned by a test in the owning task.

1. **A query that hides every row** says "Nothing matches this query" with a Clear button, never the list's "add your first buddy" empty state. (Task 1, `QueryNoMatchState`; Task 8, "a query that keeps nothing shows the no-match state".)
2. **An invalid saved query applied to a list** shows the list's error state, not an empty list or a crash. (Task 1, "an invalid query is the id set's error".)
3. **Table mode honours the filter**: a course status chip and a query both narrow the table, which ignored the chips before. (Task 11, "table mode reads the filtered courses".)
4. **Status chips and a query compose**: Completed plus `agency = padi` keeps only completed PADI courses. (Task 11, "status and query compose".)
5. **A stored enum string outside the enum** (a legacy certification level) is found by `level:any` and by no `level = X`. (Task 3, "an unknown stored level is set but equals nothing".)

## File structure

Created:

| File | Responsibility |
| --- | --- |
| `lib/features/query/presentation/widgets/query_filter_sheet.dart` | `QueryFilterButton`, `showQueryFilterSheet`, `QueryFilterSheet` (a list's filter sheet when it has none of its own) |
| `lib/features/query/presentation/widgets/query_chips_frame.dart` | `QueryChipsFrame` (chip bar above a list body), `QueryNoMatchState` |
| `lib/features/buddies/presentation/providers/buddy_query_providers.dart` | `buddyQueryProvider`, `filteredBuddiesWithDiveCountProvider` |
| `lib/features/buddies/presentation/widgets/buddy_search_delegate.dart` | `BuddySearchDelegate`, moved verbatim out of `buddy_list_content.dart` |
| `lib/features/certifications/presentation/providers/certification_query_providers.dart` | `certificationQueryProvider`, `filteredCertificationsProvider` |
| `lib/features/certifications/presentation/widgets/certification_search_delegate.dart` | `CertificationSearchDelegate`, moved verbatim |
| `lib/features/dive_centers/presentation/providers/dive_center_query_providers.dart` | `diveCenterQueryProvider`, `filteredDiveCentersProvider` |
| `lib/features/dive_centers/presentation/widgets/dive_center_search_delegate.dart` | `DiveCenterSearchDelegate`, moved verbatim |
| `lib/features/courses/domain/models/course_filter_state.dart` | `CourseStatusFilter`, `CourseFilterState` |
| `lib/features/courses/query/course_filter_query.dart` | `CourseFilterQuery.toQuery()` |
| `lib/features/courses/presentation/providers/course_query_providers.dart` | `courseFilterProvider`, `filteredCoursesProvider` |
| `lib/features/marine_life/presentation/providers/species_query_providers.dart` | `seenSpeciesQueryProvider`, `speciesCatalogQueryProvider`, `filteredSeenSpeciesProvider`, `filteredSpeciesCatalogProvider` |

Modified (main ones): `query_id_set_providers.dart`, `narrow_by_ids.dart`, the five entity files, `app_query_labels.dart`, `buddy_migrations.dart`, `rungs_v231_onward.dart`, `before_open.dart`, `database.dart`, the four list content files and their pages, `species_page.dart`, `species_manage_page.dart`, the ARB files and the spec.

### The ARB helper (used by Tasks 1 to 6)

Task 1 Step 1 writes this script to `.dart_tool/pr4_arb_add.py` (git-ignored). It inserts each new `query_*` key in sorted position in every locale, copying the value from an existing key per locale (`from`), or taking it from `values`, with an optional English override (`en`):

```python
"""Insert query_* ARB keys in sorted position in every locale.

Usage: python3.14 .dart_tool/pr4_arb_add.py SPEC.json  (from the worktree root)

SPEC maps a new key to {"description": str, and either "from": source key
(copied per locale) or "values": {locale: text}; optional "en": English
override}. Keys already present are left alone.
"""
import json
import pathlib
import re
import sys

ARB_DIR = pathlib.Path('lib/l10n/arb')
KEY = re.compile(r'^  "([^"@][^"]*)": ')
spec = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))

for arb in sorted(ARB_DIR.glob('app_*.arb')):
    locale = arb.stem[len('app_'):]
    text = arb.read_text(encoding='utf-8')
    data = json.loads(text)
    lines = text.split('\n')
    for new_key in sorted(spec):
        if new_key in data:
            continue
        entry = spec[new_key]
        if locale == 'en' and 'en' in entry:
            value = entry['en']
        elif 'from' in entry:
            value = data[entry['from']]
        else:
            value = entry['values'][locale]
        block = [f'  {json.dumps(new_key, ensure_ascii=False)}: '
                 f'{json.dumps(value, ensure_ascii=False)},']
        if locale == 'en':
            meta = json.dumps({'description': entry['description']},
                              ensure_ascii=False)
            block.append(f'  "@{new_key}": {meta},')
        at = None
        last_query = None
        for i, line in enumerate(lines):
            m = KEY.match(line)
            if not m or not m.group(1).startswith('query_'):
                continue
            last_query = i
            if at is None and m.group(1) > new_key:
                at = i
        if at is None:
            at = last_query + 1
            if locale == 'en' and lines[at].startswith('  "@'):
                at += 1
        lines[at:at] = block
        data[new_key] = value
    out = '\n'.join(lines)
    json.loads(out)
    arb.write_text(out, encoding='utf-8')
    print(arb.name, 'ok')
```

After each run: `flutter gen-l10n` and `python3.14 scripts/gen_query_label_lookup.py`.

---

### Task 1: Shared list query pieces

**Files:**
- Modify: `lib/features/query/presentation/providers/query_id_set_providers.dart`, `lib/features/query/presentation/providers/narrow_by_ids.dart`
- Create: `lib/features/query/presentation/widgets/query_filter_sheet.dart`, `lib/features/query/presentation/widgets/query_chips_frame.dart`
- Modify: `lib/l10n/arb/app_*.arb` (11), regenerate
- Test: `test/features/query/presentation/providers/entity_query_ids_test.dart`, `test/features/query/presentation/widgets/query_filter_sheet_test.dart`, `test/features/query/presentation/widgets/query_chips_frame_test.dart`

**Interfaces:**
- Produces:
  - `typedef EntityQueryKey = ({QueryEntity root, QueryNode query});`
  - `final entityQueryIdsProvider = FutureProvider.autoDispose.family<Set<String>, EntityQueryKey>` (compiles and runs through `watchQueryIds`; a compile error is its error).
  - `AsyncValue<List<T>> narrowByQuery<T>(Ref ref, AsyncValue<List<T>> items, QueryEntity root, QueryNode? query, String Function(T item) idOf)`: `items` unchanged when `query` is null, else `narrowByIds` over the id set.
  - `class QueryFilterButton extends StatelessWidget { const QueryFilterButton({super.key, required bool active, required VoidCallback onPressed, bool compact = false}); }`
  - `Future<void> showQueryFilterSheet(BuildContext context, {required QuerySubject subject, required QueryEntity root, required QueryNode? initial, required void Function(WidgetRef ref, QueryNode? query) onApply})`
  - `class QueryChipsFrame extends ConsumerWidget { const QueryChipsFrame({super.key, required QueryEntity root, required QueryNode? query, required ValueChanged<QueryNode?> onChanged, required Widget child}); }`
  - `class QueryNoMatchState extends StatelessWidget { const QueryNoMatchState({super.key, required VoidCallback onClear}); }`
  - ARB keys `query_filter_tooltip` ("Filter"), `query_filter_clear` ("Clear"), `query_list_noMatch` ("Nothing matches this query").

- [ ] **Step 1: Write the ARB helper and the three keys**

Write the script in "The ARB helper" above to `.dart_tool/pr4_arb_add.py`, and this spec to `.dart_tool/pr4_arb_task1.json`:

```json
{
  "query_filter_tooltip": {"from": "connections_tab_filter", "description": "Tooltip of the filter icon that opens a list's query filter sheet"},
  "query_filter_clear": {"from": "diveSites_list_activeFilter_clear", "description": "Clears a list's query, in its chip bar, filter sheet and no-match state"},
  "query_list_noMatch": {"description": "Shown when a list's query hides every row", "values": {
    "en": "Nothing matches this query",
    "ar": "لا شيء يطابق هذا الاستعلام",
    "de": "Nichts entspricht dieser Abfrage",
    "es": "Nada coincide con esta consulta",
    "fr": "Rien ne correspond à cette requête",
    "he": "אין תוצאות התואמות לשאילתה זו",
    "hu": "Semmi sem felel meg ennek a lekérdezésnek",
    "it": "Nessun risultato corrisponde a questa query",
    "nl": "Niets komt overeen met deze query",
    "pt": "Nada corresponde a esta consulta",
    "zh": "没有与此查询匹配的结果"
  }}
}
```

Run: `python3.14 .dart_tool/pr4_arb_add.py .dart_tool/pr4_arb_task1.json`, then `flutter gen-l10n`, then `python3.14 scripts/gen_query_label_lookup.py`.
Expected: eleven `ok` lines; `git diff --numstat -- lib/l10n/arb/*.arb` shows 1 added line per locale (2 in `app_en.arb`).

- [ ] **Step 2: Write the failing provider test**

```dart
// test/features/query/presentation/providers/entity_query_ids_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Any root entity's query as an id set, and a list narrowed by it (#2365).
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final (id, name) in [('ann', 'Ann'), ('bob', 'Bob')]) {
      await db.customStatement(
        'INSERT INTO buddies (id, name, created_at, updated_at) '
        "VALUES ('$id', '$name', $now, $now)",
      );
    }
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  final ann = ConditionNode(
    FieldPath(['name']),
    QueryOp.eq,
    const StringValue('Ann'),
  );

  test('a query rooted at any entity runs as an id set', () async {
    final key = (root: buddyQueryEntity, query: ann);
    final sub = container.listen(entityQueryIdsProvider(key), (_, _) {});
    addTearDown(sub.close);
    expect(await container.read(entityQueryIdsProvider(key).future), {'ann'});
  });

  test('an invalid query is the id set\'s error', () async {
    final key = (
      root: buddyQueryEntity,
      query: ConditionNode(
        FieldPath(['noSuchField']),
        QueryOp.eq,
        const StringValue('x'),
      ),
    );
    final sub = container.listen(entityQueryIdsProvider(key), (_, _) {});
    addTearDown(sub.close);
    await expectLater(
      container.read(entityQueryIdsProvider(key).future),
      throwsA(anything),
    );
  });

  test('no query passes the list through; a query narrows it', () async {
    final rows = AsyncValue.data(['ann', 'bob']);
    final probe = Provider((ref) => narrowByQuery<String>(
      ref,
      rows,
      buddyQueryEntity,
      null,
      (s) => s,
    ));
    expect(container.read(probe).value, ['ann', 'bob']);

    final narrowed = Provider((ref) => narrowByQuery<String>(
      ref,
      rows,
      buddyQueryEntity,
      ann,
      (s) => s,
    ));
    final sub = container.listen(narrowed, (_, _) {});
    addTearDown(sub.close);
    await container.read(
      entityQueryIdsProvider((root: buddyQueryEntity, query: ann)).future,
    );
    await container.pump();
    expect(container.read(narrowed).value, ['ann']);
  });
}
```

- [ ] **Step 3: Run it to verify it fails**

Run: `flutter test test/features/query/presentation/providers/entity_query_ids_test.dart`
Expected: FAIL to compile: `entityQueryIdsProvider` and `narrowByQuery` are undefined.

- [ ] **Step 4: Implement the provider and the narrowing helper**

Append to `lib/features/query/presentation/providers/query_id_set_providers.dart` (add the imports `package:submersion/core/query/domain/query_node.dart`, `package:submersion/core/query/registry/query_entity.dart`, `package:submersion/features/query/app_query_registry.dart`):

```dart
/// A list's query and the entity it roots at: the key of
/// [entityQueryIdsProvider]. Registry entities are single instances, so the
/// record compares by the query's value.
typedef EntityQueryKey = ({QueryEntity root, QueryNode query});

/// The ids [EntityQueryKey.query] selects for any list that has no filter
/// state of its own (#2365 PR 4). A query the compiler refuses is this
/// provider's error, which the list shows as its error state.
final entityQueryIdsProvider = FutureProvider.autoDispose
    .family<Set<String>, EntityQueryKey>(
      (ref, key) async => watchQueryIds(
        ref,
        compileQuery(key.query, key.root, appQueryRegistry),
      ),
    );
```

Append to `lib/features/query/presentation/providers/narrow_by_ids.dart` (add the imports `package:submersion/core/query/domain/query_node.dart`, `package:submersion/core/query/registry/query_entity.dart`, `package:submersion/features/query/presentation/providers/query_id_set_providers.dart`):

```dart
/// [items] narrowed by [query] rooted at [root] (#2365), by [narrowByIds]'s
/// rules. No query passes the list through without touching the database,
/// so a list with no filter never waits on an id set.
AsyncValue<List<T>> narrowByQuery<T>(
  Ref ref,
  AsyncValue<List<T>> items,
  QueryEntity root,
  QueryNode? query,
  String Function(T item) idOf,
) => query == null
    ? items
    : narrowByIds(
        items,
        ref.watch(entityQueryIdsProvider((root: root, query: query))),
        idOf,
      );
```

- [ ] **Step 5: Run the provider test to verify it passes**

Run: `flutter test test/features/query/presentation/providers/entity_query_ids_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 6: Write the failing widget tests**

```dart
// test/features/query/presentation/widgets/query_chips_frame_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/query/presentation/widgets/query_chips_frame.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  final ann = ConditionNode(
    FieldPath(['name']),
    QueryOp.eq,
    const StringValue('Ann'),
  );
  final fav = ConditionNode(
    FieldPath(['favorite']),
    QueryOp.eq,
    const BoolValue(true),
  );

  Future<List<QueryNode?>> pump(WidgetTester tester, QueryNode? query) async {
    final changes = <QueryNode?>[];
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: QueryChipsFrame(
          root: buddyQueryEntity,
          query: query,
          onChanged: changes.add,
          child: const Text('BODY'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return changes;
  }

  testWidgets('no query shows only the body', (tester) async {
    await pump(tester, null);
    expect(find.text('BODY'), findsOneWidget);
    expect(find.byType(InputChip), findsNothing);
  });

  testWidgets('one chip per condition; delete leaves the rest', (
    tester,
  ) async {
    final changes = await pump(tester, AndNode([ann, fav]));
    expect(find.byType(InputChip), findsNWidgets(2));
    tester
        .widget<InputChip>(find.byType(InputChip).first)
        .onDeleted!();
    expect(changes, [fav]);
  });

  testWidgets('Clear clears the whole query', (tester) async {
    final changes = await pump(tester, ann);
    await tester.tap(find.text('Clear'));
    expect(changes, [null]);
  });

  testWidgets('the no-match state offers Clear', (tester) async {
    var cleared = 0;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: QueryNoMatchState(onClear: () => cleared++),
      ),
    );
    expect(find.text('Nothing matches this query'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    expect(cleared, 1);
  });
}
```

```dart
// test/features/query/presentation/widgets/query_filter_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/presentation/widgets/query_filter_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const now = 1735689600000;
  final ann = ConditionNode(
    FieldPath(['name']),
    QueryOp.eq,
    const StringValue('Ann'),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<List<QueryNode?>> open(WidgetTester tester, QueryNode? initial) async {
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'me'});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(c.dispose);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 2400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final applied = <QueryNode?>[];
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showQueryFilterSheet(
                  context,
                  subject: QuerySubject.buddies,
                  root: buddyQueryEntity,
                  initial: initial,
                  onApply: (ref, q) => applied.add(q),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    return applied;
  }

  testWidgets('Apply hands the typed query to onApply', (tester) async {
    final applied = await open(tester, null);
    await tester.enterText(find.byType(TextField).first, 'name = "Ann"');
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(applied, [ann]);
  });

  testWidgets('Clear then Apply hands null', (tester) async {
    final applied = await open(tester, ann);
    await tester.tap(find.byKey(const ValueKey('query_filter_sheet_clear')));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(applied, [null]);
  });

  testWidgets('Cancel applies nothing', (tester) async {
    final applied = await open(tester, ann);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(applied, isEmpty);
  });

  testWidgets('the button shows a badge only while a query is active', (
    tester,
  ) async {
    Future<void> pumpButton(bool active) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: QueryFilterButton(active: active, onPressed: () {}),
        ),
      ),
    );
    await pumpButton(false);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    await pumpButton(true);
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
  });
}
```

- [ ] **Step 7: Run them to verify they fail**

Run: `flutter test test/features/query/presentation/widgets/query_chips_frame_test.dart test/features/query/presentation/widgets/query_filter_sheet_test.dart`
Expected: FAIL to compile: the two widget files do not exist.

- [ ] **Step 8: Implement the widgets**

```dart
// lib/features/query/presentation/widgets/query_chips_frame.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/query/presentation/entity_query_chips.dart';
import 'package:submersion/features/query/presentation/providers/query_unit_prefs_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A list body with its query's chips above it (#2365): Clear, then one
/// removable chip per top-level condition, printed in the diver's units.
/// With no query it is the body alone.
class QueryChipsFrame extends ConsumerWidget {
  const QueryChipsFrame({
    super.key,
    required this.root,
    required this.query,
    required this.onChanged,
    required this.child,
  });

  final QueryEntity root;
  final QueryNode? query;
  final ValueChanged<QueryNode?> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query == null) return child;
    final colorScheme = Theme.of(context).colorScheme;
    final chips = entityQueryChips(
      root,
      query,
      ref.watch(queryUnitPrefsProvider),
    );
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.clear_all, size: 18),
                  label: Text(context.l10n.query_filter_clear),
                  onPressed: () => onChanged(null),
                ),
                const SizedBox(width: 8),
                for (final chip in chips)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: InputChip(
                      label: Text(chip.label),
                      onDeleted: () => onChanged(chip.rest),
                      deleteIconColor: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// A list's empty state when its query hid every row (#2365): says the
/// query matched nothing rather than that the diver has no rows.
class QueryNoMatchState extends StatelessWidget {
  const QueryNoMatchState({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.query_list_noMatch,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear_all),
              label: Text(context.l10n.query_filter_clear),
            ),
          ],
        ),
      ),
    );
  }
}
```

```dart
// lib/features/query/presentation/widgets/query_filter_sheet.dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/query/presentation/app_query_labels.dart';
import 'package:submersion/features/query/presentation/widgets/query_sheet_section.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/sheet_messenger_scope.dart';

/// The filter icon of a list with no filter sheet of its own (#2365): a
/// badge shows while a query is active.
class QueryFilterButton extends StatelessWidget {
  const QueryFilterButton({
    super.key,
    required this.active,
    required this.onPressed,
    this.compact = false,
  });

  final bool active;
  final VoidCallback onPressed;

  /// The 20 px icon of a master pane's compact bar.
  final bool compact;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.query_filter_tooltip,
    onPressed: onPressed,
    icon: Badge(
      isLabelVisible: active,
      child: Icon(Icons.filter_list, size: compact ? 20 : null),
    ),
  );
}

/// Opens [QueryFilterSheet]. [onApply] runs with the sheet's own ref (the
/// launching page may be gone by then) and the query the diver applied,
/// null when they cleared it.
Future<void> showQueryFilterSheet(
  BuildContext context, {
  required QuerySubject subject,
  required QueryEntity root,
  required QueryNode? initial,
  required void Function(WidgetRef ref, QueryNode? query) onApply,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (_) => QueryFilterSheet(
    subject: subject,
    root: root,
    initial: initial,
    onApply: onApply,
  ),
);

/// A query-only filter sheet: the Saved row and the editor, Clear, Cancel
/// and Apply. Edits stay local until Apply.
class QueryFilterSheet extends ConsumerStatefulWidget {
  const QueryFilterSheet({
    super.key,
    required this.subject,
    required this.root,
    required this.initial,
    required this.onApply,
  });

  final QuerySubject subject;
  final QueryEntity root;
  final QueryNode? initial;
  final void Function(WidgetRef ref, QueryNode? query) onApply;

  @override
  ConsumerState<QueryFilterSheet> createState() => _QueryFilterSheetState();
}

class _QueryFilterSheetState extends ConsumerState<QueryFilterSheet> {
  late QueryNode? _query = widget.initial;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppQueryLabels(context).entity(widget.subject),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('query_filter_sheet_clear'),
                    onPressed: () => setState(() => _query = null),
                    child: Text(context.l10n.query_filter_clear),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SheetMessengerScope(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    QuerySheetSection(
                      subject: widget.subject,
                      root: widget.root,
                      value: _query,
                      onChanged: (node) => setState(() => _query = node),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.l10n.common_action_cancel),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          widget.onApply(ref, _query);
                          Navigator.of(context).pop();
                        },
                        child: Text(context.l10n.common_action_apply),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 9: Run the widget tests and the guards**

Run: `flutter test test/features/query/ test/architecture/ test/l10n/`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add lib/features/query/presentation/providers/query_id_set_providers.dart lib/features/query/presentation/providers/narrow_by_ids.dart lib/features/query/presentation/widgets/query_filter_sheet.dart lib/features/query/presentation/widgets/query_chips_frame.dart lib/features/query/presentation/query_label_lookup.dart lib/l10n/arb test/features/query/presentation/providers/entity_query_ids_test.dart test/features/query/presentation/widgets/query_filter_sheet_test.dart test/features/query/presentation/widgets/query_chips_frame_test.dart
git commit -m "feat(query): a filter button, sheet, chip frame and no-match state for any list"
```

---

### Task 2: Buddy registry: dives and text search

**Files:**
- Modify: `lib/features/buddies/query/buddy_query_entity.dart`
- Modify: `lib/l10n/arb/app_*.arb`, regenerate
- Test: `test/features/buddies/query/buddy_query_entity_test.dart`

**Interfaces:**
- Produces: buddy relation `dives` (junction `dive_buddies`); buddy text search over name, email, phone; ARB `query_buddies_dives`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/buddies/query/buddy_query_entity_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      'INSERT INTO buddies (id, name, email, phone, created_at, updated_at) '
      "VALUES ('ann', 'Ann', 'ann@reef.test', '555-0100', $now, $now), "
      "('bob', 'Bob', NULL, NULL, $now, $now)",
    );
    await sql(
      'INSERT INTO dives (id, dive_date_time, max_depth, created_at, '
      "updated_at) VALUES ('d1', $now, 32, $now, $now)",
    );
    await sql(
      'INSERT INTO dive_buddies (id, dive_id, buddy_id, created_at) '
      "VALUES ('db1', 'd1', 'ann', $now)",
    );
  });
  tearDown(tearDownTestDatabase);

  final buddies = appQueryRegistry.entityFor(QuerySubject.buddies);
  final parser = QueryParser(
    appQueryRegistry,
    buddies,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 9, 28),
      names: const MapNameResolver({}),
    ),
  );

  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, buddies, appQueryRegistry), isEmpty);
    final q = compileQuery(node, buddies, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('dives and text search are queryable', () async {
    expect(await ids('dives:any'), {'ann'});
    expect(await ids('dives:none'), {'bob'});
    expect(await ids('dives.maxDepth > 30'), {'ann'});
    expect(await ids('"reef.test"'), {'ann'});
    expect(await ids('"0100"'), {'ann'});
    expect(await ids('"bo"'), {'bob'});
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/buddies/query/buddy_query_entity_test.dart`
Expected: FAIL: the parse of `dives:any` fails (unknown field or relation `dives`).

- [ ] **Step 3: Add the ARB key**

Spec `.dart_tool/pr4_arb_task2.json`:

```json
{"query_buddies_dives": {"from": "query_sites_dives", "description": "Query builder: a buddy's dives"}}
```

Run the helper, `flutter gen-l10n`, `python3.14 scripts/gen_query_label_lookup.py`.

- [ ] **Step 4: Implement**

In `lib/features/buddies/query/buddy_query_entity.dart`, replace the header comment with `/// Every field and relation a buddy query can name (#2365). The buddy list's query roots here; dive paths reach it through \`buddies\`.`, add to the `QueryEntity(...)` arguments:

```dart
  // The buddy search route's columns (name, email, phone).
  textSearchSql: [
    "{r}.name LIKE ? ESCAPE '\\'",
    "{r}.email LIKE ? ESCAPE '\\'",
    "{r}.phone LIKE ? ESCAPE '\\'",
  ],
```

and add to `relations`:

```dart
    QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.junction,
      // IN (subquery), as the dive side's junction hops: SQLite probes
      // dives by key.
      joinSql:
          '{to}.id IN (SELECT j.dive_id FROM dive_buddies j '
          'WHERE j.buddy_id = {from}.id)',
      isMany: true,
      labelKey: 'query_buddies_dives',
      tables: ['dive_buddies'],
    ),
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/buddies/query/ test/features/query/presentation/query_labels_test.dart test/features/dive_log/query/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/buddies/query/buddy_query_entity.dart lib/features/query/presentation/query_label_lookup.dart lib/l10n/arb test/features/buddies/query/buddy_query_entity_test.dart
git commit -m "feat(query): the buddy registry names dives and searches name, email and phone"
```

---

### Task 3: Certification registry: agency and level enums, owner, instructor, course, text search

**Files:**
- Modify: `lib/features/certifications/query/certification_query_entity.dart`, `lib/features/query/presentation/app_query_labels.dart`
- Modify: `test/core/query/syntax/query_parser_test.dart` (one expectation)
- Modify: `lib/l10n/arb/app_*.arb`, regenerate
- Test: `test/features/certifications/query/certification_query_entity_test.dart`; extend `test/features/query/presentation/query_labels_test.dart`

**Interfaces:**
- Produces: certification fields `agency` (enumName over `CertificationAgency` names), `level` (enumName over `CertificationLevel` names), `instructorNumber`, `notes`; relations `buddy` and `instructor` (fk to buddies), `course` (fk to courses); text search over name, agency, card number. `AppQueryLabels.enumValue` localizes the three enums (Tasks 4 and 6 add their cases).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/certifications/query/certification_query_entity_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', $now, $now)",
    );
    await sql(
      'INSERT INTO buddies (id, name, created_at, updated_at) '
      "VALUES ('ann', 'Ann', $now, $now), ('bob', 'Bob', $now, $now)",
    );
    await sql(
      'INSERT INTO courses (id, diver_id, name, agency, start_date, '
      "created_at, updated_at) VALUES ('aow', 'me', 'AOW', 'padi', $now, "
      '$now, $now)',
    );
    await sql(
      'INSERT INTO certifications (id, diver_id, buddy_id, instructor_id, '
      'course_id, name, agency, level, card_number, created_at, updated_at) '
      "VALUES ('c1', 'me', NULL, NULL, 'aow', 'Open Water', 'padi', "
      "'openWater', 'PX-1', $now, $now), "
      "('c2', NULL, 'ann', 'bob', NULL, 'Rescue', 'ssi', 'rescue', NULL, "
      '$now, $now), '
      "('c3', 'me', NULL, NULL, NULL, 'Old card', 'other', 'mysteryLevel', "
      'NULL, $now, $now)',
    );
  });
  tearDown(tearDownTestDatabase);

  final certs = appQueryRegistry.entityFor(QuerySubject.certifications);
  final parser = QueryParser(
    appQueryRegistry,
    certs,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 9, 28),
      names: const MapNameResolver({}),
    ),
  );

  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, certs, appQueryRegistry), isEmpty);
    final q = compileQuery(node, certs, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('agency and level are enums; owner, instructor, course are hops', () async {
    expect(await ids('agency = padi'), {'c1'});
    expect(await ids('level in [rescue, openWater]'), {'c1', 'c2'});
    expect(await ids('buddy.name = Ann'), {'c2'});
    expect(await ids('instructor.name = Bob'), {'c2'});
    expect(await ids('course.name = AOW'), {'c1'});
    expect(await ids('"px-1"'), {'c1'});
  });

  test('an unknown stored level is set but equals nothing', () async {
    expect(await ids('level:any'), {'c1', 'c2', 'c3'});
    expect(await ids('level = other'), isEmpty);
  });

  test('an enum field refuses a value outside the enum', () {
    final parsed = parser.parse('level = notALevel');
    final errors = parsed is ParseOk
        ? validateQuery(parsed.node, certs, appQueryRegistry)
        : const ['parse refused'];
    expect(errors, isNotEmpty);
  });
}
```

Extend the `AppQueryLabels localises` test in `test/features/query/presentation/query_labels_test.dart`, after its last `expect`:

```dart
    final certs = appQueryRegistry.entityFor(QuerySubject.certifications);
    expect(labels.enumValue(certs.field('agency')!, 'padi'), 'PADI');
    expect(labels.enumValue(certs.field('level')!, 'rescue'), 'Rescue Diver');
```

`level` becomes an enum, so `buddies.certifications.level = rescue` parses to an enum value: in `test/core/query/syntax/query_parser_test.dart`, change that case's expected value from `const StringValue('rescue')` to `const EnumValue('rescue')`.

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/certifications/query/ test/features/query/presentation/query_labels_test.dart test/core/query/syntax/query_parser_test.dart`
Expected: FAIL: `buddy.name` does not parse (no relation `buddy`), the label test gets `padi` back unlocalized, and the parser still yields a `StringValue` for `level`.

- [ ] **Step 3: Add the ARB keys**

Spec `.dart_tool/pr4_arb_task3.json`:

```json
{
  "query_certifications_notes": {"from": "query_sites_notes", "description": "Query builder: a certification's notes"},
  "query_certifications_instructorNumber": {"from": "enum_certificationField_instructorNumber", "en": "Instructor number", "description": "Query builder: the instructor number on a certification"},
  "query_certifications_buddy": {"from": "enum_diveField_buddy", "description": "Query builder: the buddy a certification belongs to"},
  "query_certifications_instructor": {"from": "courses_section_instructor", "description": "Query builder: a certification's instructor"},
  "query_certifications_course": {"from": "query_dives_course", "description": "Query builder: the course a certification came from"}
}
```

Run the helper, `flutter gen-l10n`, `python3.14 scripts/gen_query_label_lookup.py`.

- [ ] **Step 4: Implement the registry**

Replace `lib/features/certifications/query/certification_query_entity.dart` with:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

QueryField _text(String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_certifications_$key',
);

QueryField _date(String key, String column) => QueryField(
  key: key,
  type: FieldType.date,
  dateFrame: DateFrame.localInstant,
  sql: '{r}.$column',
  emptySql: '{r}.$column IS NULL',
  labelKey: 'query_certifications_$key',
);

/// A buddy's certification row, as stored in `buddy_id`/`instructor_id`.
QueryRelation _buddy(String key, String column) => QueryRelation(
  key: key,
  target: QuerySubject.buddies,
  shape: RelationShape.fk,
  joinSql: '{to}.id = {from}.$column',
  isMany: false,
  labelKey: 'query_certifications_$key',
);

/// Every field and relation a certification query can name (#2365). The
/// certification list's query roots here; `buddies.certifications` reaches
/// it from dives. `agency` and `level` store enum names, so they compare as
/// enums; a stored name outside the enum is set but equals no value.
final certificationQueryEntity = QueryEntity(
  subject: QuerySubject.certifications,
  table: 'certifications',
  diverScopeColumn: 'diver_id',
  // The certification search route's columns.
  textSearchSql: const [
    "{r}.name LIKE ? ESCAPE '\\'",
    "{r}.agency LIKE ? ESCAPE '\\'",
    "{r}.card_number LIKE ? ESCAPE '\\'",
  ],
  fields: [
    _text('name', 'name'),
    QueryField(
      key: 'agency',
      type: FieldType.enumName,
      sql: '{r}.agency',
      emptySql: "({r}.agency IS NULL OR TRIM({r}.agency) = '')",
      labelKey: 'query_certifications_agency',
      enumValues: [for (final a in CertificationAgency.values) a.name],
    ),
    QueryField(
      key: 'level',
      type: FieldType.enumName,
      sql: '{r}.level',
      emptySql: "({r}.level IS NULL OR TRIM({r}.level) = '')",
      labelKey: 'query_certifications_level',
      enumValues: [for (final l in CertificationLevel.values) l.name],
    ),
    _text('cardNumber', 'card_number'),
    _text('instructorName', 'instructor_name'),
    _text('instructorNumber', 'instructor_number'),
    _text('notes', 'notes'),
    _date('issueDate', 'issue_date'),
    _date('expiryDate', 'expiry_date'),
  ],
  relations: [
    _buddy('buddy', 'buddy_id'),
    _buddy('instructor', 'instructor_id'),
    const QueryRelation(
      key: 'course',
      target: QuerySubject.courses,
      shape: RelationShape.fk,
      joinSql: '{to}.id = {from}.course_id',
      isMany: false,
      labelKey: 'query_certifications_course',
    ),
  ],
);
```

In `lib/features/query/presentation/app_query_labels.dart`, add the imports `package:submersion/features/certifications/presentation/certification_agency_display.dart` and `package:submersion/features/certifications/presentation/certification_level_display.dart`, and these cases before `default:`:

```dart
      case 'query_certifications_agency':
        return byName(CertificationAgency.values)?.localizedName(_l10n) ??
            value;
      case 'query_certifications_level':
        return byName(CertificationLevel.values)?.localizedName(_l10n) ??
            value;
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/certifications/query/ test/features/query/ test/core/query/ test/features/dive_log/query/`
Expected: PASS (the dive semantics fixture stores `rescue`, so `buddies.certifications.level = rescue` still finds d1 and d5).

- [ ] **Step 6: Commit**

```bash
git add lib/features/certifications/query/certification_query_entity.dart lib/features/query/presentation/app_query_labels.dart lib/features/query/presentation/query_label_lookup.dart lib/l10n/arb test/features/certifications/query/certification_query_entity_test.dart test/features/query/presentation/query_labels_test.dart test/core/query/syntax/query_parser_test.dart
git commit -m "feat(query): certification agency and level are enums; owner, instructor and course are hops"
```

---

### Task 4: Course registry: agency enum, location, instructor, certification, dives

**Files:**
- Modify: `lib/features/courses/query/course_query_entity.dart`, `lib/features/query/presentation/app_query_labels.dart`
- Modify: `lib/l10n/arb/app_*.arb`, regenerate
- Test: `test/features/courses/query/course_query_entity_test.dart`; extend `query_labels_test.dart`

**Interfaces:**
- Produces: course fields `agency` (enumName), `location`, `instructorName`, `notes`; relations `instructor` (fk buddies), `certification` (either link direction), `dives` (child); text search over name and location.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/courses/query/course_query_entity_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', $now, $now)",
    );
    await sql(
      'INSERT INTO buddies (id, name, created_at, updated_at) '
      "VALUES ('ian', 'Ian', $now, $now)",
    );
    await sql(
      'INSERT INTO courses (id, diver_id, name, agency, start_date, '
      'completion_date, instructor_id, certification_id, location, '
      'created_at, updated_at) VALUES '
      "('aow', 'me', 'AOW', 'padi', $now, $now, 'ian', NULL, 'Bonaire Dive', "
      '$now, $now), '
      "('tec', 'me', 'Tec 40', 'tdi', $now, NULL, NULL, 'cTec', NULL, $now, "
      '$now)',
    );
    await sql(
      'INSERT INTO certifications (id, diver_id, course_id, name, agency, '
      "created_at, updated_at) VALUES ('cAow', 'me', 'aow', 'AOW card', "
      "'padi', $now, $now), ('cTec', 'me', NULL, 'Tec card', 'tdi', $now, "
      '$now)',
    );
    await sql(
      'INSERT INTO dives (id, dive_date_time, course_id, created_at, '
      "updated_at) VALUES ('d1', $now, 'aow', $now, $now)",
    );
  });
  tearDown(tearDownTestDatabase);

  final courses = appQueryRegistry.entityFor(QuerySubject.courses);
  final parser = QueryParser(
    appQueryRegistry,
    courses,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 9, 28),
      names: const MapNameResolver({}),
    ),
  );

  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, courses, appQueryRegistry), isEmpty);
    final q = compileQuery(node, courses, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('agency, instructor, certification and dives are queryable', () async {
    expect(await ids('agency = tdi'), {'tec'});
    expect(await ids('instructor.name = Ian'), {'aow'});
    // Either link direction finds the certification.
    expect(await ids('certification.name = "AOW card"'), {'aow'});
    expect(await ids('certification.name = "Tec card"'), {'tec'});
    expect(await ids('dives:any'), {'aow'});
    expect(await ids('completionDate:none'), {'tec'});
    expect(await ids('"bonaire"'), {'aow'});
  });
}
```

Extend `query_labels_test.dart`'s widget test:

```dart
    final courses = appQueryRegistry.entityFor(QuerySubject.courses);
    expect(labels.enumValue(courses.field('agency')!, 'padi'), 'PADI');
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/courses/query/ test/features/query/presentation/query_labels_test.dart`
Expected: FAIL: `instructor.name` does not parse, and the course agency label returns `padi`.

- [ ] **Step 3: Add the ARB keys**

Spec `.dart_tool/pr4_arb_task4.json`:

```json
{
  "query_courses_location": {"from": "query_trips_location", "description": "Query builder: where a course was taken"},
  "query_courses_instructorName": {"from": "query_certifications_instructorName", "description": "Query builder: a course's instructor name"},
  "query_courses_notes": {"from": "query_sites_notes", "description": "Query builder: a course's notes"},
  "query_courses_instructor": {"from": "courses_section_instructor", "description": "Query builder: a course's instructor (a buddy)"},
  "query_courses_certification": {"from": "buddies_section_certification", "description": "Query builder: the certification a course led to"},
  "query_courses_dives": {"from": "query_sites_dives", "description": "Query builder: a course's dives"}
}
```

Run the helper, `flutter gen-l10n`, `python3.14 scripts/gen_query_label_lookup.py`.

- [ ] **Step 4: Implement**

Replace `lib/features/courses/query/course_query_entity.dart` with:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

QueryField _text(String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_courses_$key',
);

QueryField _date(String key, String column) => QueryField(
  key: key,
  type: FieldType.date,
  dateFrame: DateFrame.localInstant,
  sql: '{r}.$column',
  emptySql: '{r}.$column IS NULL',
  labelKey: 'query_courses_$key',
);

/// Every field and relation a course query can name (#2365). The course
/// list's query (and its status chips, as `completionDate:none`/`:any`)
/// roots here; dives reach it through `course`.
final courseQueryEntity = QueryEntity(
  subject: QuerySubject.courses,
  table: 'courses',
  diverScopeColumn: 'diver_id',
  textSearchSql: const [
    "{r}.name LIKE ? ESCAPE '\\'",
    "{r}.location LIKE ? ESCAPE '\\'",
  ],
  fields: [
    _text('name', 'name'),
    QueryField(
      key: 'agency',
      type: FieldType.enumName,
      sql: '{r}.agency',
      emptySql: "({r}.agency IS NULL OR TRIM({r}.agency) = '')",
      labelKey: 'query_courses_agency',
      enumValues: [for (final a in CertificationAgency.values) a.name],
    ),
    _date('startDate', 'start_date'),
    _date('completionDate', 'completion_date'),
    _text('location', 'location'),
    _text('instructorName', 'instructor_name'),
    _text('notes', 'notes'),
  ],
  relations: const [
    QueryRelation(
      key: 'instructor',
      target: QuerySubject.buddies,
      shape: RelationShape.fk,
      joinSql: '{to}.id = {from}.instructor_id',
      isMany: false,
      labelKey: 'query_courses_instructor',
    ),
    // The link is stored on either side (courses.certification_id or
    // certifications.course_id); the course detail reads both.
    QueryRelation(
      key: 'certification',
      target: QuerySubject.certifications,
      shape: RelationShape.custom,
      joinSql: '({to}.id = {from}.certification_id OR {to}.course_id = {from}.id)',
      isMany: true,
      labelKey: 'query_courses_certification',
    ),
    QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.child,
      joinSql: '{to}.course_id = {from}.id',
      isMany: true,
      labelKey: 'query_courses_dives',
    ),
  ],
);
```

In `app_query_labels.dart`, extend the certification agency case so both keys share it:

```dart
      case 'query_certifications_agency':
      case 'query_courses_agency':
        return byName(CertificationAgency.values)?.localizedName(_l10n) ??
            value;
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/courses/query/ test/features/query/ test/features/dive_log/query/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/courses/query/course_query_entity.dart lib/features/query/presentation/app_query_labels.dart lib/features/query/presentation/query_label_lookup.dart lib/l10n/arb test/features/courses/query/course_query_entity_test.dart test/features/query/presentation/query_labels_test.dart
git commit -m "feat(query): the course registry names agency, instructor, certification and dives"
```

---

### Task 5: Dive center registry: rating, affiliations, coordinates, dives

**Files:**
- Modify: `lib/features/dive_centers/query/dive_center_query_entity.dart`
- Modify: `lib/l10n/arb/app_*.arb`, regenerate
- Test: `test/features/dive_centers/query/dive_center_query_entity_test.dart`

**Interfaces:**
- Produces: center fields `stateProvince`, `affiliations` (text, so `affiliations ~ PADI`), `rating` (number, 0 to 5), `notes`, `coordinates` (bool with `:none`/`:any`); relation `dives` (child); text search over name, city, country.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_centers/query/dive_center_query_entity_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      'INSERT INTO dive_centers (id, name, city, country, affiliations, '
      'rating, latitude, longitude, created_at, updated_at) VALUES '
      "('reef', 'Reef Divers', 'Kralendijk', 'Bonaire', 'PADI,SSI', 4, 12.1, "
      '-68.2, $now, $now), '
      "('lake', 'Lake Club', 'Zug', 'Switzerland', 'CMAS', 2, NULL, NULL, "
      '$now, $now)',
    );
    await sql(
      'INSERT INTO dives (id, dive_date_time, dive_center_id, max_depth, '
      "created_at, updated_at) VALUES ('d1', $now, 'reef', 25, $now, $now)",
    );
  });
  tearDown(tearDownTestDatabase);

  final centers = appQueryRegistry.entityFor(QuerySubject.centers);
  final parser = QueryParser(
    appQueryRegistry,
    centers,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 9, 28),
      names: const MapNameResolver({}),
    ),
  );

  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, centers, appQueryRegistry), isEmpty);
    final q = compileQuery(node, centers, appQueryRegistry);
    final rows = await db
        .customSelect(
          q.idSubquery(),
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('rating, affiliations, coordinates and dives are queryable', () async {
    expect(await ids('rating >= 3'), {'reef'});
    expect(await ids('affiliations ~ ssi'), {'reef'});
    expect(await ids('coordinates:none'), {'lake'});
    expect(await ids('dives.maxDepth > 20'), {'reef'});
    expect(await ids('dives:none'), {'lake'});
    expect(await ids('"zug"'), {'lake'});
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_centers/query/dive_center_query_entity_test.dart`
Expected: FAIL: `rating` is not a field.

- [ ] **Step 3: Add the ARB keys**

Spec `.dart_tool/pr4_arb_task5.json`:

```json
{
  "query_centers_stateProvince": {"from": "enum_diveCenterField_stateProvince", "description": "Query builder: a dive center's state or province"},
  "query_centers_affiliations": {"from": "enum_diveCenterField_affiliations", "description": "Query builder: a dive center's agency affiliations"},
  "query_centers_rating": {"from": "query_sites_rating", "description": "Query builder: a dive center's rating"},
  "query_centers_notes": {"from": "query_sites_notes", "description": "Query builder: a dive center's notes"},
  "query_centers_coordinates": {"from": "query_sites_coordinates", "description": "Query builder: whether a dive center has a map position"},
  "query_centers_dives": {"from": "query_sites_dives", "description": "Query builder: dives made with a dive center"}
}
```

Run the helper, `flutter gen-l10n`, `python3.14 scripts/gen_query_label_lookup.py`.

- [ ] **Step 4: Implement**

Replace `lib/features/dive_centers/query/dive_center_query_entity.dart` with:

```dart
import 'package:submersion/core/query/domain/query_node.dart' show QueryOp;
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

QueryField _text(String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_centers_$key',
);

/// Every field and relation a dive center query can name (#2365). The
/// center list's query roots here; dives reach it through `center`.
/// `affiliations` is the comma-separated text the edit page writes, so it
/// is matched with contains (`affiliations ~ PADI`).
const diveCenterQueryEntity = QueryEntity(
  subject: QuerySubject.centers,
  table: 'dive_centers',
  diverScopeColumn: 'diver_id',
  // The center search route's columns.
  textSearchSql: [
    "{r}.name LIKE ? ESCAPE '\\'",
    "{r}.city LIKE ? ESCAPE '\\'",
    "{r}.country LIKE ? ESCAPE '\\'",
  ],
  fields: [
    QueryField(
      key: 'name',
      type: FieldType.text,
      sql: '{r}.name',
      emptySql: "({r}.name IS NULL OR TRIM({r}.name) = '')",
      labelKey: 'query_centers_name',
    ),
    QueryField(
      key: 'city',
      type: FieldType.text,
      sql: '{r}.city',
      emptySql: "({r}.city IS NULL OR TRIM({r}.city) = '')",
      labelKey: 'query_centers_city',
    ),
    QueryField(
      key: 'country',
      type: FieldType.text,
      sql: '{r}.country',
      emptySql: "({r}.country IS NULL OR TRIM({r}.country) = '')",
      labelKey: 'query_centers_country',
    ),
    QueryField(
      key: 'stateProvince',
      type: FieldType.text,
      sql: '{r}.state_province',
      emptySql:
          "({r}.state_province IS NULL OR TRIM({r}.state_province) = '')",
      labelKey: 'query_centers_stateProvince',
    ),
    QueryField(
      key: 'affiliations',
      type: FieldType.text,
      sql: '{r}.affiliations',
      emptySql: "({r}.affiliations IS NULL OR TRIM({r}.affiliations) = '')",
      labelKey: 'query_centers_affiliations',
    ),
    QueryField(
      key: 'rating',
      type: FieldType.number,
      dimension: FieldDimension.count,
      sql: '{r}.rating',
      emptySql: '{r}.rating IS NULL',
      labelKey: 'query_centers_rating',
      sanity: (min: 0, max: 5),
    ),
    QueryField(
      key: 'notes',
      type: FieldType.text,
      sql: '{r}.notes',
      emptySql: "({r}.notes IS NULL OR TRIM({r}.notes) = '')",
      labelKey: 'query_centers_notes',
    ),
    // Like the site field: both halves, and `:none`/`:any` besides =.
    QueryField(
      key: 'coordinates',
      type: FieldType.bool,
      ops: {QueryOp.eq, QueryOp.neq, QueryOp.isEmpty, QueryOp.isSet},
      sql: '({r}.latitude IS NOT NULL AND {r}.longitude IS NOT NULL)',
      emptySql: '({r}.latitude IS NULL OR {r}.longitude IS NULL)',
      labelKey: 'query_centers_coordinates',
    ),
  ],
  relations: [
    QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.child,
      joinSql: '{to}.dive_center_id = {from}.id',
      isMany: true,
      labelKey: 'query_centers_dives',
    ),
  ],
);
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/dive_centers/query/ test/features/query/ test/features/dive_log/query/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_centers/query/dive_center_query_entity.dart lib/features/query/presentation/query_label_lookup.dart lib/l10n/arb test/features/dive_centers/query/dive_center_query_entity_test.dart
git commit -m "feat(query): the dive center registry names rating, affiliations, coordinates and dives"
```

---

### Task 6: Species registry: category enum, taxonomy, built-in, sightings, sites, dives

**Files:**
- Modify: `lib/features/marine_life/query/species_query_entity.dart`, `lib/features/query/presentation/app_query_labels.dart`
- Modify: `lib/l10n/arb/app_*.arb`, regenerate
- Test: `test/features/marine_life/query/species_query_entity_test.dart`; extend `query_labels_test.dart`

**Interfaces:**
- Produces: species fields `category` (enumName over `SpeciesCategory` names), `taxonomyClass`, `description`, `builtIn` (bool); relations `sightings` (child), `sites` (junction `site_species`), `dives` (through `sightings`); text search over common name, scientific name, taxonomy class.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/marine_life/query/species_query_entity_test.dart
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/compiler/query_validator.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/syntax/query_parser.dart';
import 'package:submersion/core/query/units/unit_prefs.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    // Custom ids, clear of the seeded built-in catalog.
    await sql(
      'INSERT INTO species (id, common_name, scientific_name, category, '
      'taxonomy_class, is_built_in) VALUES '
      "('t_whale', 'Test Whale', 'Testus maximus', 'mammal', 'Mammalia', 0), "
      "('t_coral', 'Test Coral', NULL, 'coral', 'Anthozoa', 1)",
    );
    await sql(
      'INSERT INTO dive_sites (id, name, created_at, updated_at) '
      "VALUES ('s1', 'Reef', $now, $now)",
    );
    await sql(
      'INSERT INTO site_species (id, site_id, species_id, created_at) '
      "VALUES ('ss1', 's1', 't_coral', $now)",
    );
    await sql(
      'INSERT INTO dives (id, dive_date_time, max_depth, created_at, '
      "updated_at) VALUES ('d1', $now, 18, $now, $now)",
    );
    await sql(
      'INSERT INTO sightings (id, dive_id, species_id, count) '
      "VALUES ('g1', 'd1', 't_whale', 3)",
    );
  });
  tearDown(tearDownTestDatabase);

  final species = appQueryRegistry.entityFor(QuerySubject.species);
  final parser = QueryParser(
    appQueryRegistry,
    species,
    ParseContext(
      prefs: kMetricPrefs,
      now: DateTime(2026, 9, 28),
      names: const MapNameResolver({}),
    ),
  );

  Future<Set<String>> ids(String text) async {
    final parsed = parser.parse(text);
    expect(parsed, isA<ParseOk>(), reason: '$parsed');
    final node = (parsed as ParseOk).node;
    expect(validateQuery(node, species, appQueryRegistry), isEmpty);
    final q = compileQuery(node, species, appQueryRegistry);
    final rows = await db
        .customSelect(
          '${q.idSubquery()}',
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    // Only this test's rows; the seeded catalog is not the subject here.
    return {
      for (final r in rows)
        if (r.read<String>('id').startsWith('t_')) r.read<String>('id'),
    };
  }

  test('category, built-in, sightings, sites and dives are queryable', () async {
    expect(await ids('category = mammal'), {'t_whale'});
    expect(await ids('builtIn = true'), {'t_coral'});
    expect(await ids('sightings.count >= 3'), {'t_whale'});
    expect(await ids('sites:any'), {'t_coral'});
    expect(await ids('dives.maxDepth > 10'), {'t_whale'});
    expect(await ids('"anthozoa"'), {'t_coral'});
    expect(await ids('"testus"'), {'t_whale'});
  });
}
```

Extend `query_labels_test.dart`'s widget test:

```dart
    final species = appQueryRegistry.entityFor(QuerySubject.species);
    expect(labels.enumValue(species.field('category')!, 'plant'), 'Plant/Algae');
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/marine_life/query/ test/features/query/presentation/query_labels_test.dart`
Expected: FAIL: `category = mammal` fails validation or `builtIn` is unknown; the label returns `plant`.

- [ ] **Step 3: Add the ARB keys**

Spec `.dart_tool/pr4_arb_task6.json`:

```json
{
  "query_species_taxonomyClass": {"from": "marineLife_speciesEdit_taxonomyClassLabel", "en": "Taxonomy class", "description": "Query builder: a species' taxonomy class"},
  "query_species_description": {"from": "diveSites_edit_field_description_label", "description": "Query builder: a species' description"},
  "query_species_builtIn": {"from": "query_diveTypes_builtIn", "description": "Query builder: whether a species comes from the built-in catalog"},
  "query_species_sightings": {"from": "query_dives_sightings", "description": "Query builder: a species' sightings"},
  "query_species_sites": {"from": "query_entity_sites", "description": "Query builder: the sites a species is expected at"},
  "query_species_dives": {"from": "query_sites_dives", "description": "Query builder: the dives a species was sighted on"}
}
```

Run the helper, `flutter gen-l10n`, `python3.14 scripts/gen_query_label_lookup.py`.

- [ ] **Step 4: Implement**

Replace `lib/features/marine_life/query/species_query_entity.dart` with:

```dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';

QueryField _text(String key, String column) => QueryField(
  key: key,
  type: FieldType.text,
  sql: '{r}.$column',
  emptySql: "({r}.$column IS NULL OR TRIM({r}.$column) = '')",
  labelKey: 'query_species_$key',
);

/// Every field and relation a species query can name (#2365). Both species
/// pages root here (the diver's sighted species and the catalog); dives
/// reach it through `sightings.species`. Species are global (no diver
/// column), and SQL sees the stored English common name, so a built-in
/// species is found by its English or scientific name.
final speciesQueryEntity = QueryEntity(
  subject: QuerySubject.species,
  table: 'species',
  textSearchSql: const [
    "{r}.common_name LIKE ? ESCAPE '\\'",
    "{r}.scientific_name LIKE ? ESCAPE '\\'",
    "{r}.taxonomy_class LIKE ? ESCAPE '\\'",
  ],
  fields: [
    _text('name', 'common_name'),
    _text('scientificName', 'scientific_name'),
    QueryField(
      key: 'category',
      type: FieldType.enumName,
      sql: '{r}.category',
      emptySql: "({r}.category IS NULL OR TRIM({r}.category) = '')",
      labelKey: 'query_species_category',
      enumValues: [for (final c in SpeciesCategory.values) c.name],
    ),
    _text('taxonomyClass', 'taxonomy_class'),
    _text('description', 'description'),
    const QueryField(
      key: 'builtIn',
      type: FieldType.bool,
      sql: '{r}.is_built_in',
      emptySql: '0',
      labelKey: 'query_species_builtIn',
    ),
  ],
  relations: const [
    QueryRelation(
      key: 'sightings',
      target: QuerySubject.sightings,
      shape: RelationShape.child,
      joinSql: '{to}.species_id = {from}.id',
      isMany: true,
      labelKey: 'query_species_sightings',
    ),
    QueryRelation(
      key: 'sites',
      target: QuerySubject.sites,
      shape: RelationShape.junction,
      joinSql:
          '{to}.id IN (SELECT j.site_id FROM site_species j '
          'WHERE j.species_id = {from}.id)',
      isMany: true,
      labelKey: 'query_species_sites',
      tables: ['site_species'],
    ),
    QueryRelation(
      key: 'dives',
      target: QuerySubject.dives,
      shape: RelationShape.custom,
      joinSql:
          '{to}.id IN (SELECT s.dive_id FROM sightings s '
          'WHERE s.species_id = {from}.id)',
      isMany: true,
      labelKey: 'query_species_dives',
      tables: ['sightings'],
    ),
  ],
);
```

In `app_query_labels.dart`, add the import `package:submersion/features/marine_life/presentation/species_display.dart` and before `default:`:

```dart
      case 'query_species_category':
        return byName(SpeciesCategory.values)?.localizedName(_l10n) ?? value;
```

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/marine_life/query/ test/features/query/ test/features/dive_log/query/ test/architecture/`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/marine_life/query/species_query_entity.dart lib/features/query/presentation/app_query_labels.dart lib/features/query/presentation/query_label_lookup.dart lib/l10n/arb test/features/marine_life/query/species_query_entity_test.dart test/features/query/presentation/query_labels_test.dart
git commit -m "feat(query): the species registry names category, built-in, sightings, sites and dives"
```

---

### Task 7: Schema rung 245: index certifications by buddy

**Files:**
- Modify: `lib/core/database/migrations/helpers/buddy_migrations.dart`, `lib/core/database/migrations/ladder/rungs_v231_onward.dart`, `lib/core/database/migrations/before_open.dart`, `lib/core/database/database.dart`
- Modify: `test/features/dive_log/query/dive_query_semantics_test.dart` (the query-plan test), `test/core/database/migration_v242_equipment_service_status_test.dart` (relax its exact version)
- Test: `test/core/database/migration_v245_certifications_buddy_index_test.dart`

**Interfaces:**
- Produces: index `idx_certifications_buddy_id ON certifications (buddy_id)`; `currentSchemaVersion == 245`; `migrationVersions` ends with 245.

- [ ] **Step 1: Write the failing tests**

```dart
// test/core/database/migration_v245_certifications_buddy_index_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

const _index = 'idx_certifications_buddy_id';

Future<bool> _hasIndex(AppDatabase db) async {
  final rows = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
        variables: [const Variable<String>(_index)],
      )
      .get();
  return rows.isNotEmpty;
}

void main() {
  test('v245 is the current schema version and in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, 245);
    expect(AppDatabase.migrationVersions.last, 245);
    expect(AppDatabase.migrationStepCount(242), 1);
  });

  test('a fresh database indexes certifications by buddy', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await _hasIndex(db), isTrue);
  });

  test('a database stranded before v245 gains the index', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('''
          CREATE TABLE certifications (
            id TEXT NOT NULL PRIMARY KEY,
            buddy_id TEXT,
            name TEXT NOT NULL,
            agency TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);
    expect(await _hasIndex(db), isTrue);
  });
}
```

In `test/features/dive_log/query/dive_query_semantics_test.dart`, the query-plan test: replace the comment and set

```dart
    // The root scan is expected; every correlated hop whose correlation
    // column is indexed must be a SEARCH. Since v245 that includes
    // `certifications.buddy_id`, so no hop is exempt.
    const unindexedHops = <String>{};
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/database/migration_v245_certifications_buddy_index_test.dart test/features/dive_log/query/dive_query_semantics_test.dart`
Expected: FAIL: version is 242, no index, and the plan test reports a `SCAN r2` line.

- [ ] **Step 3: Implement**

Append to `lib/core/database/migrations/helpers/buddy_migrations.dart` (inside the extension):

```dart
  /// v245: index certifications by buddy (#2365). `buddies.certifications`
  /// hops and the buddy detail's certification reads correlate on it.
  /// Idempotent, so it doubles as the beforeOpen backstop.
  Future<void> _assertCertificationsBuddyIndex() async {
    if (!await _tableExists('certifications')) return;
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_certifications_buddy_id '
      'ON certifications (buddy_id)',
    );
  }
```

At the end of the ladder in `rungs_v231_onward.dart`:

```dart
    // v245: index certifications by buddy (issue #2365). Index-only rung;
    // re-asserted in beforeOpen.
    if (from < 245) {
      await _assertCertificationsBuddyIndex();
    }
    if (from < 245) await reportProgress();
```

In `before_open.dart`, beside the v242 backstop:

```dart
    // v245 backstop: the certifications buddy index (idempotent).
    await _assertCertificationsBuddyIndex();
```

In `database.dart`: `currentSchemaVersion = 245;` and append to `migrationVersions`:

```dart
    // v245: idx_certifications_buddy_id (issue #2365, PR 4). Index-only;
    // the floor does not move. 243 and 244 were held by #2409 and #2538
    // when this was taken.
    245,
```

In `migration_v242_equipment_service_status_test.dart`, relax its exact version check to `greaterThanOrEqualTo(242)` with the comment `// Relaxed once v245 landed on top; the newest rung owns the exact assertion.`

- [ ] **Step 4: Run the tests**

Run: `flutter test test/core/database/ test/features/dive_log/query/`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/database/migrations/helpers/buddy_migrations.dart lib/core/database/migrations/ladder/rungs_v231_onward.dart lib/core/database/migrations/before_open.dart lib/core/database/database.dart test/core/database/migration_v245_certifications_buddy_index_test.dart test/core/database/migration_v242_equipment_service_status_test.dart test/features/dive_log/query/dive_query_semantics_test.dart
git commit -m "feat(db): v245 indexes certifications by buddy"
```

---

### Task 8: Buddy list on the query

**Files:**
- Create: `lib/features/buddies/presentation/providers/buddy_query_providers.dart`
- Create: `lib/features/buddies/presentation/widgets/buddy_search_delegate.dart` (moved)
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_content.dart`, `lib/features/buddies/presentation/pages/buddy_list_page.dart`
- Test: `test/features/buddies/presentation/providers/buddy_query_providers_test.dart`; add a group to `test/features/buddies/presentation/widgets/buddy_list_content_test.dart`

**Interfaces:**
- Consumes: `narrowByQuery`, `QueryFilterButton`, `showQueryFilterSheet`, `QueryChipsFrame`, `QueryNoMatchState` (Task 1); `buddyQueryEntity` (Task 2).
- Produces: `final buddyQueryProvider = StateProvider<QueryNode?>((ref) => null);` and `final filteredBuddiesWithDiveCountProvider = Provider<AsyncValue<List<BuddyWithDiveCount>>>`.

- [ ] **Step 1: Write the failing provider test**

```dart
// test/features/buddies/presentation/providers/buddy_query_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', $now, $now)",
    );
    await sql(
      'INSERT INTO buddies (id, diver_id, name, is_favorite, created_at, '
      "updated_at) VALUES ('ann', 'me', 'Ann', 1, $now, $now), "
      "('bob', 'me', 'Bob', 0, $now, $now)",
    );
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'me'});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<List<String>> visible() async {
    final sub = container.listen(
      filteredBuddiesWithDiveCountProvider,
      (_, _) {},
    );
    addTearDown(sub.close);
    for (var i = 0; i < 200; i++) {
      final v = container.read(filteredBuddiesWithDiveCountProvider);
      if (v.hasError) throw v.error!;
      if (v.hasValue && !v.isLoading) {
        return [for (final b in v.value!) b.buddy.id];
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('the buddy list never settled');
  }

  test('no query lists every buddy; a query narrows them', () async {
    expect(await visible(), unorderedEquals(['ann', 'bob']));
    container.read(buddyQueryProvider.notifier).state = ConditionNode(
      FieldPath(['favorite']),
      QueryOp.eq,
      const BoolValue(true),
    );
    expect(await visible(), ['ann']);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/buddies/presentation/providers/buddy_query_providers_test.dart`
Expected: FAIL to compile: the providers file does not exist.

- [ ] **Step 3: Implement the providers**

```dart
// lib/features/buddies/presentation/providers/buddy_query_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/features/buddies/domain/entities/buddy_with_dive_count.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';

/// The buddy list's query (#2365): typed, built or applied from a saved
/// query in the filter sheet; null lists every buddy.
final buddyQueryProvider = StateProvider<QueryNode?>((ref) => null);

/// The buddy list: every visible buddy with its dive count, narrowed to the
/// query's ids. The list, compact pane and table all read this.
final filteredBuddiesWithDiveCountProvider =
    Provider<AsyncValue<List<BuddyWithDiveCount>>>(
      (ref) => narrowByQuery(
        ref,
        ref.watch(allBuddiesWithDiveCountProvider),
        buddyQueryEntity,
        ref.watch(buddyQueryProvider),
        (b) => b.buddy.id,
      ),
    );
```

- [ ] **Step 4: Run the provider test to verify it passes**

Run: `flutter test test/features/buddies/presentation/providers/buddy_query_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing widget tests**

Add to `test/features/buddies/presentation/widgets/buddy_list_content_test.dart`, inside `main()` (imports: `package:submersion/core/query/domain/query_node.dart`, `package:submersion/features/buddies/presentation/providers/buddy_query_providers.dart`, `package:submersion/features/query/presentation/providers/query_id_set_providers.dart`, `package:submersion/features/query/presentation/widgets/query_chips_frame.dart`):

```dart
  group('query (#2365)', () {
    final fav = ConditionNode(
      FieldPath(['favorite']),
      QueryOp.eq,
      const BoolValue(true),
    );

    Future<void> pumpWithQuery(
      WidgetTester tester, {
      required Set<String> ids,
      ListViewMode viewMode = ListViewMode.detailed,
    }) async {
      final overrides = await _buildPhoneOverrides(
        buddies: [
          _makeBuddy(id: 'b1', name: 'Alice'),
          _makeBuddy(id: 'b2', name: 'Bob'),
        ],
        viewMode: viewMode,
      );
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            buddyQueryProvider.overrideWith((ref) => fav),
            entityQueryIdsProvider.overrideWith((ref, key) async => ids),
          ],
          child: const BuddyListContent(showAppBar: true),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the query narrows the list and shows its chip', (
      tester,
    ) async {
      await pumpWithQuery(tester, ids: {'b1'});
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Bob'), findsNothing);
      expect(find.text('favorite = true'), findsOneWidget);
    });

    testWidgets('a query that keeps nothing shows the no-match state', (
      tester,
    ) async {
      await pumpWithQuery(tester, ids: const {});
      expect(find.byType(QueryNoMatchState), findsOneWidget);
    });

    testWidgets('table mode reads the filtered buddies', (tester) async {
      await pumpWithQuery(tester, ids: {'b2'}, viewMode: ListViewMode.table);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Alice'), findsNothing);
    });
  });
```

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/features/buddies/presentation/widgets/buddy_list_content_test.dart --plain-name "query (#2365)"`
Expected: FAIL: Bob is still listed (the content reads the unfiltered provider) and no chip shows.

- [ ] **Step 7: Move the search delegate out**

Move the class `BuddySearchDelegate` (from `class BuddySearchDelegate extends SearchDelegate<Buddy?> {` to its closing brace at the end of `buddy_list_content.dart`) verbatim into `lib/features/buddies/presentation/widgets/buddy_search_delegate.dart`. Give the new file the imports the class uses (run `dart analyze` on it and add each import it names, taken from `buddy_list_content.dart`'s own import block), import the new file from `buddy_list_content.dart` and from any test that referenced the class through the content file, and remove imports the content file no longer uses. `git diff --stat` must show the delegate's lines leaving one file and arriving in the other.

- [ ] **Step 8: Wire the list**

In `buddy_list_content.dart` (add imports for `buddy_query_providers.dart`, `buddy_query_entity.dart`, `query_subject.dart`, `query_filter_sheet.dart`, `query_chips_frame.dart`):

1. In `build`, replace `ref.watch(allBuddiesWithDiveCountProvider)` with `ref.watch(filteredBuddiesWithDiveCountProvider)`, and in the scroll helper replace `ref.read(allBuddiesWithDiveCountProvider)` with `ref.read(filteredBuddiesWithDiveCountProvider)`. Leave the refresh calls (`ref.invalidate(allBuddiesWithDiveCountProvider)`) as they are.
2. Add to the state class:

```dart
  void _openQueryFilter() => showQueryFilterSheet(
    context,
    subject: QuerySubject.buddies,
    root: buddyQueryEntity,
    initial: ref.read(buddyQueryProvider),
    onApply: (ref, query) =>
        ref.read(buddyQueryProvider.notifier).state = query,
  );

  void _setQuery(QueryNode? query) =>
      ref.read(buddyQueryProvider.notifier).state = query;

  /// The list body with the query's chips above it.
  Widget _withQueryChips(Widget child) => QueryChipsFrame(
    root: buddyQueryEntity,
    query: ref.watch(buddyQueryProvider),
    onChanged: _setQuery,
    child: child,
  );
```

3. In `buildContent()`, wrap the returned `buddiesAsync.when(...)` as `return _withQueryChips(buddiesAsync.when(...));`. In `_buildTableModeScaffold`, change `final tableContent = _buildTableView(context, buddiesAsync);` to `final tableContent = _withQueryChips(_buildTableView(context, buddiesAsync));`.
4. At the top of `_buildEmptyState`, before its current body:

```dart
    // A query that hid every buddy is not "no buddies yet".
    if (ref.watch(buddyQueryProvider) != null) {
      return QueryNoMatchState(onClear: () => _setQuery(null));
    }
```

5. Insert the filter button immediately before the `IconButton(key: const ValueKey('enter_selection'), ...)` in the mobile `AppBar.actions`:

```dart
                    QueryFilterButton(
                      active: ref.watch(buddyQueryProvider) != null,
                      onPressed: _openQueryFilter,
                    ),
```

and before the same key in `_buildCompactAppBar`:

```dart
          QueryFilterButton(
            active: ref.watch(buddyQueryProvider) != null,
            onPressed: _openQueryFilter,
            compact: true,
          ),
```

In `buddy_list_page.dart`'s table-mode `appBarActions`, insert before the sort `IconButton` (the one with `Icons.sort`), with imports for the query providers, entity, subject and sheet:

```dart
            Consumer(
              builder: (context, ref, _) => QueryFilterButton(
                active: ref.watch(buddyQueryProvider) != null,
                compact: true,
                onPressed: () => showQueryFilterSheet(
                  context,
                  subject: QuerySubject.buddies,
                  root: buddyQueryEntity,
                  initial: ref.read(buddyQueryProvider),
                  onApply: (ref, query) =>
                      ref.read(buddyQueryProvider.notifier).state = query,
                ),
              ),
            ),
```

- [ ] **Step 9: Run the buddy tests and check sizes**

Run: `flutter test test/features/buddies/ test/architecture/`
Expected: PASS. Then `wc -l lib/features/buddies/presentation/widgets/buddy_list_content.dart` is below 1092 (its size on main).

- [ ] **Step 10: Commit**

```bash
git add lib/features/buddies/presentation/providers/buddy_query_providers.dart lib/features/buddies/presentation/widgets/buddy_search_delegate.dart lib/features/buddies/presentation/widgets/buddy_list_content.dart lib/features/buddies/presentation/pages/buddy_list_page.dart test/features/buddies
git commit -m "feat(buddies): the buddy list filters through a query, with a filter sheet and chips"
```

---

### Task 9: Certification list on the query

**Files:**
- Create: `lib/features/certifications/presentation/providers/certification_query_providers.dart`
- Create: `lib/features/certifications/presentation/widgets/certification_search_delegate.dart` (moved)
- Modify: `lib/features/certifications/presentation/widgets/certification_list_content.dart`, `lib/features/certifications/presentation/pages/certification_list_page.dart`
- Test: `test/features/certifications/presentation/providers/certification_query_providers_test.dart`; add a group to `certification_list_content_test.dart`

**Interfaces:**
- Consumes: Task 1 pieces; `certificationQueryEntity` (Task 3).
- Produces: `certificationQueryProvider` (`StateProvider<QueryNode?>`), `filteredCertificationsProvider` (`Provider<AsyncValue<List<Certification>>>`, narrowing `certificationListNotifierProvider`).

- [ ] **Step 1: Write the failing provider test**

```dart
// test/features/certifications/presentation/providers/certification_query_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_query_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', $now, $now)",
    );
    await sql(
      'INSERT INTO certifications (id, diver_id, name, agency, level, '
      "created_at, updated_at) VALUES ('c1', 'me', 'OW', 'padi', "
      "'openWater', $now, $now), ('c2', 'me', 'Nitrox', 'ssi', 'nitrox', "
      '$now, $now)',
    );
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'me'});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<List<String>> visible() async {
    final sub = container.listen(filteredCertificationsProvider, (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 200; i++) {
      final v = container.read(filteredCertificationsProvider);
      if (v.hasError) throw v.error!;
      if (v.hasValue && !v.isLoading) return [for (final c in v.value!) c.id];
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('the certification list never settled');
  }

  test('no query lists every certification; a query narrows them', () async {
    expect(await visible(), unorderedEquals(['c1', 'c2']));
    container.read(certificationQueryProvider.notifier).state = ConditionNode(
      FieldPath(['agency']),
      QueryOp.eq,
      const EnumValue('ssi'),
    );
    expect(await visible(), ['c2']);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/certifications/presentation/providers/certification_query_providers_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the providers**

```dart
// lib/features/certifications/presentation/providers/certification_query_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/query/certification_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';

/// The certification list's query (#2365); null lists every certification.
final certificationQueryProvider = StateProvider<QueryNode?>((ref) => null);

/// The certification list narrowed to the query's ids; the grouped list,
/// compact pane and table all read this.
final filteredCertificationsProvider =
    Provider<AsyncValue<List<Certification>>>(
      (ref) => narrowByQuery(
        ref,
        ref.watch(certificationListNotifierProvider),
        certificationQueryEntity,
        ref.watch(certificationQueryProvider),
        (c) => c.id,
      ),
    );
```

- [ ] **Step 4: Run the provider test to verify it passes**

Run: `flutter test test/features/certifications/presentation/providers/certification_query_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing widget tests**

Add to `certification_list_content_test.dart`, inside `main()` (imports as in Task 8 Step 5, with `certification_query_providers.dart`):

```dart
  group('query (#2365)', () {
    final padi = ConditionNode(
      FieldPath(['agency']),
      QueryOp.eq,
      const EnumValue('padi'),
    );

    Future<void> pumpWithQuery(
      WidgetTester tester, {
      required Set<String> ids,
      ListViewMode viewMode = ListViewMode.detailed,
    }) async {
      final overrides = await _buildPhoneOverrides(
        certs: [
          _makeCert(id: 'c1', name: 'Open Water'),
          _makeCert(id: 'c2', name: 'Nitrox'),
        ],
        viewMode: viewMode,
      );
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            certificationQueryProvider.overrideWith((ref) => padi),
            entityQueryIdsProvider.overrideWith((ref, key) async => ids),
          ],
          child: const CertificationListContent(showAppBar: true),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the query narrows the list and shows its chip', (
      tester,
    ) async {
      await pumpWithQuery(tester, ids: {'c1'});
      expect(find.text('Open Water'), findsWidgets);
      expect(find.text('Nitrox'), findsNothing);
      expect(find.text('agency = padi'), findsOneWidget);
    });

    testWidgets('a query that keeps nothing shows the no-match state', (
      tester,
    ) async {
      await pumpWithQuery(tester, ids: const {});
      expect(find.byType(QueryNoMatchState), findsOneWidget);
    });

    testWidgets('table mode reads the filtered certifications', (
      tester,
    ) async {
      await pumpWithQuery(tester, ids: {'c2'}, viewMode: ListViewMode.table);
      expect(find.text('Nitrox'), findsWidgets);
      expect(find.text('Open Water'), findsNothing);
    });
  });
```

Give the file's `_buildPhoneOverrides` a `ListViewMode viewMode = ListViewMode.detailed` parameter and pass it to its `certificationListViewModeProvider.overrideWith((ref) => viewMode)` (it hard-codes `ListViewMode.detailed` today). Chips print enum values as stored, so the agency chip reads `agency = padi`.

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/features/certifications/presentation/widgets/certification_list_content_test.dart --plain-name "query (#2365)"`
Expected: FAIL: both certifications still listed.

- [ ] **Step 7: Move the search delegate and wire the list**

Move `CertificationSearchDelegate` verbatim into `certification_search_delegate.dart` as in Task 8 Step 7. Then in `certification_list_content.dart`, apply Task 8 Step 8's five edits with these names: provider `certificationListNotifierProvider` becomes `filteredCertificationsProvider` in `build` and in the scroll helper's `ref.read`; query provider `certificationQueryProvider`; entity `certificationQueryEntity`; subject `QuerySubject.certifications`; the table branch's `Expanded(child: _buildTableView(context, certificationsAsync))` becomes `Expanded(child: _withQueryChips(_buildTableView(context, certificationsAsync)))`; `buildContent()` wraps its `certificationsAsync.when(...)`; the no-match guard goes at the top of `_buildEmptyState`; the filter button goes before `ValueKey('enter_selection')` in the mobile actions and the compact bar, and before the sort `IconButton` in `certification_list_page.dart`'s `appBarActions`. Leave `refresh()` and every other reader of `certificationListNotifierProvider` (summary, wallet) unchanged.

- [ ] **Step 8: Run the certification tests and check sizes**

Run: `flutter test test/features/certifications/ test/architecture/`
Expected: PASS; `wc -l` of `certification_list_content.dart` is below 971.

- [ ] **Step 9: Commit**

```bash
git add lib/features/certifications/presentation/providers/certification_query_providers.dart lib/features/certifications/presentation/widgets/certification_search_delegate.dart lib/features/certifications/presentation/widgets/certification_list_content.dart lib/features/certifications/presentation/pages/certification_list_page.dart test/features/certifications
git commit -m "feat(certifications): the certification list filters through a query"
```

---

### Task 10: Dive center list on the query

**Files:**
- Create: `lib/features/dive_centers/presentation/providers/dive_center_query_providers.dart`
- Create: `lib/features/dive_centers/presentation/widgets/dive_center_search_delegate.dart` (moved)
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart`, `lib/features/dive_centers/presentation/pages/dive_center_list_page.dart`
- Test: `test/features/dive_centers/presentation/providers/dive_center_query_providers_test.dart`; add a group to `dive_center_list_content_test.dart`

**Interfaces:**
- Consumes: Task 1 pieces; `diveCenterQueryEntity` (Task 5).
- Produces: `diveCenterQueryProvider`, `filteredDiveCentersProvider` (narrowing `diveCenterListNotifierProvider`). The map (`dive_center_map_content.dart`, `dive_center_map_page.dart`) keeps reading the unfiltered notifier.

- [ ] **Step 1: Write the failing provider test**

```dart
// test/features/dive_centers/presentation/providers/dive_center_query_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_query_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', $now, $now)",
    );
    await sql(
      'INSERT INTO dive_centers (id, diver_id, name, rating, created_at, '
      "updated_at) VALUES ('reef', 'me', 'Reef', 5, $now, $now), "
      "('lake', 'me', 'Lake', 2, $now, $now)",
    );
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'me'});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<List<String>> visible() async {
    final sub = container.listen(filteredDiveCentersProvider, (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 200; i++) {
      final v = container.read(filteredDiveCentersProvider);
      if (v.hasError) throw v.error!;
      if (v.hasValue && !v.isLoading) return [for (final c in v.value!) c.id];
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('the center list never settled');
  }

  test('no query lists every center; a query narrows them', () async {
    expect(await visible(), unorderedEquals(['reef', 'lake']));
    container.read(diveCenterQueryProvider.notifier).state = ConditionNode(
      FieldPath(['rating']),
      QueryOp.gte,
      const NumberValue(4, null),
    );
    expect(await visible(), ['reef']);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/dive_centers/presentation/providers/dive_center_query_providers_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the providers**

```dart
// lib/features/dive_centers/presentation/providers/dive_center_query_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/query/dive_center_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';

/// The dive center list's query (#2365); null lists every center. The map
/// stays unfiltered, like the site map.
final diveCenterQueryProvider = StateProvider<QueryNode?>((ref) => null);

/// The center list narrowed to the query's ids; the list, compact pane and
/// table read this.
final filteredDiveCentersProvider = Provider<AsyncValue<List<DiveCenter>>>(
  (ref) => narrowByQuery(
    ref,
    ref.watch(diveCenterListNotifierProvider),
    diveCenterQueryEntity,
    ref.watch(diveCenterQueryProvider),
    (c) => c.id,
  ),
);
```

- [ ] **Step 4: Run the provider test to verify it passes**

Run: `flutter test test/features/dive_centers/presentation/providers/dive_center_query_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing widget tests**

Add to `dive_center_list_content_test.dart`, inside `main()`:

```dart
  group('query (#2365)', () {
    final good = ConditionNode(
      FieldPath(['rating']),
      QueryOp.gte,
      const NumberValue(4, null),
    );

    Future<void> pumpWithQuery(
      WidgetTester tester, {
      required Set<String> ids,
      ListViewMode viewMode = ListViewMode.detailed,
    }) async {
      final overrides = await _buildPhoneOverrides(
        centers: [
          _makeCenter(id: 'k1', name: 'Reef Divers', rating: 5),
          _makeCenter(id: 'k2', name: 'Lake Club', rating: 2),
        ],
        viewMode: viewMode,
      );
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            diveCenterQueryProvider.overrideWith((ref) => good),
            entityQueryIdsProvider.overrideWith((ref, key) async => ids),
          ],
          child: const DiveCenterListContent(showAppBar: true),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the query narrows the list and shows its chip', (
      tester,
    ) async {
      await pumpWithQuery(tester, ids: {'k1'});
      expect(find.text('Reef Divers'), findsWidgets);
      expect(find.text('Lake Club'), findsNothing);
      expect(find.text('rating >= 4'), findsOneWidget);
    });

    testWidgets('a query that keeps nothing shows the no-match state', (
      tester,
    ) async {
      await pumpWithQuery(tester, ids: const {});
      expect(find.byType(QueryNoMatchState), findsOneWidget);
    });

    testWidgets('table mode reads the filtered centers', (tester) async {
      await pumpWithQuery(tester, ids: {'k2'}, viewMode: ListViewMode.table);
      expect(find.text('Lake Club'), findsWidgets);
      expect(find.text('Reef Divers'), findsNothing);
    });
  });
```

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/features/dive_centers/presentation/widgets/dive_center_list_content_test.dart --plain-name "query (#2365)"`
Expected: FAIL.

- [ ] **Step 7: Move the search delegate and wire the list**

Move `DiveCenterSearchDelegate` into `dive_center_search_delegate.dart` as in Task 8 Step 7. Then apply Task 8 Step 8's edits in `dive_center_list_content.dart` with: `diveCenterListNotifierProvider` becomes `filteredDiveCentersProvider` in `build` and the scroll helper's `ref.read`; query provider `diveCenterQueryProvider`; entity `diveCenterQueryEntity`; subject `QuerySubject.centers`; the table branch's `Expanded(child: _buildTableView(context, centersAsync))` becomes `Expanded(child: _withQueryChips(_buildTableView(context, centersAsync)))`; the button before `ValueKey('enter_selection')` in the mobile actions and compact bar, and before the sort `IconButton` in `dive_center_list_page.dart`'s `appBarActions`. Leave the map, the map toggle, `refresh()` and the other notifier readers unchanged.

- [ ] **Step 8: Run the center tests and check sizes**

Run: `flutter test test/features/dive_centers/ test/architecture/`
Expected: PASS; `wc -l` of `dive_center_list_content.dart` is below 1048.

- [ ] **Step 9: Commit**

```bash
git add lib/features/dive_centers/presentation/providers/dive_center_query_providers.dart lib/features/dive_centers/presentation/widgets/dive_center_search_delegate.dart lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart lib/features/dive_centers/presentation/pages/dive_center_list_page.dart test/features/dive_centers
git commit -m "feat(dive-centers): the center list filters through a query; the map stays unfiltered"
```

---

### Task 11: Course list: status chips and query in SQL

**Files:**
- Create: `lib/features/courses/domain/models/course_filter_state.dart`, `lib/features/courses/query/course_filter_query.dart`, `lib/features/courses/presentation/providers/course_query_providers.dart`
- Modify: `lib/features/courses/presentation/widgets/course_list_content.dart`, `lib/features/courses/presentation/pages/course_list_page.dart`
- Test: `test/features/courses/query/course_filter_query_test.dart`, `test/features/courses/query/course_filter_query_census_test.dart`, `test/features/courses/presentation/providers/course_query_providers_test.dart`; add a group to `course_list_content_test.dart`

**Interfaces:**
- Consumes: Task 1 pieces; `courseQueryEntity` (Task 4).
- Produces:
  - `enum CourseStatusFilter { all, inProgress, completed }`
  - `class CourseFilterState { const CourseFilterState({CourseStatusFilter status = CourseStatusFilter.all, QueryNode? query}); final CourseStatusFilter status; final QueryNode? query; bool get hasActiveFilters; CourseFilterState copyWith({CourseStatusFilter? status, QueryNode? query, bool clearQuery = false}); }` with value equality.
  - `extension CourseFilterQuery on CourseFilterState { QueryNode? toQuery(); }`
  - `final courseFilterProvider = StateProvider<CourseFilterState>((ref) => const CourseFilterState());`
  - `final filteredCoursesProvider = Provider<AsyncValue<List<Course>>>`

- [ ] **Step 1: Write the failing lowering and census tests**

```dart
// test/features/courses/query/course_filter_query_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/courses/domain/models/course_filter_state.dart';
import 'package:submersion/features/courses/query/course_filter_query.dart';

void main() {
  final padi = ConditionNode(
    FieldPath(['agency']),
    QueryOp.eq,
    const EnumValue('padi'),
  );
  final open = ConditionNode(
    FieldPath(['completionDate']),
    QueryOp.isEmpty,
    null,
  );
  final done = ConditionNode(
    FieldPath(['completionDate']),
    QueryOp.isSet,
    null,
  );

  test('status lowers to completionDate; the query ANDs on', () {
    expect(const CourseFilterState().toQuery(), isNull);
    expect(
      const CourseFilterState(status: CourseStatusFilter.inProgress).toQuery(),
      open,
    );
    expect(
      const CourseFilterState(status: CourseStatusFilter.completed).toQuery(),
      done,
    );
    expect(CourseFilterState(query: padi).toQuery(), padi);
    expect(
      CourseFilterState(
        status: CourseStatusFilter.completed,
        query: padi,
      ).toQuery(),
      AndNode([done, padi]),
    );
  });

  test('filter states compare by value', () {
    expect(
      CourseFilterState(query: padi),
      CourseFilterState(query: padi),
    );
    expect(
      const CourseFilterState(status: CourseStatusFilter.completed)
          .copyWith(clearQuery: true)
          .hasActiveFilters,
      isTrue,
    );
    expect(const CourseFilterState().hasActiveFilters, isFalse);
  });
}
```

```dart
// test/features/courses/query/course_filter_query_census_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Every CourseFilterState field is lowered: a field added to the state and
/// not named in course_filter_query.dart fails here (#2365).
void main() {
  test('every CourseFilterState field is lowered', () {
    final state = File(
      p.join('lib', 'features', 'courses', 'domain', 'models',
          'course_filter_state.dart'),
    ).readAsStringSync();
    final start = state.indexOf('class CourseFilterState');
    expect(start, isNonNegative);
    final body = state.substring(start, state.indexOf('\n}\n', start));
    final fields = RegExp(
      r'^  final [\w<>?, .]+ (\w+);',
      multiLine: true,
    ).allMatches(body).map((m) => m.group(1)!).toList();
    expect(fields, containsAll(['status', 'query']));
    final lowering = File(
      p.join('lib', 'features', 'courses', 'query', 'course_filter_query.dart'),
    ).readAsStringSync();
    for (final f in fields) {
      expect(lowering, contains(RegExp('\\b$f\\b')), reason: f);
    }
  });
}
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/courses/query/course_filter_query_test.dart test/features/courses/query/course_filter_query_census_test.dart`
Expected: FAIL: the state and lowering files do not exist.

- [ ] **Step 3: Implement the state and its lowering**

```dart
// lib/features/courses/domain/models/course_filter_state.dart
import 'package:flutter/foundation.dart';

import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;

/// The course list's status chips.
enum CourseStatusFilter { all, inProgress, completed }

/// The course list's filter (#2365): the status chips and the advanced
/// query, lowered together by `CourseFilterQuery.toQuery`.
@immutable
class CourseFilterState {
  const CourseFilterState({this.status = CourseStatusFilter.all, this.query});

  final CourseStatusFilter status;

  /// The advanced part: typed, built or applied from a saved query.
  final QueryNode? query;

  bool get hasActiveFilters =>
      status != CourseStatusFilter.all || query != null;

  CourseFilterState copyWith({
    CourseStatusFilter? status,
    QueryNode? query,
    bool clearQuery = false,
  }) => CourseFilterState(
    status: status ?? this.status,
    query: clearQuery ? null : (query ?? this.query),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CourseFilterState &&
          other.status == status &&
          other.query == query;

  @override
  int get hashCode => Object.hash(status, query);

  @override
  String toString() => 'CourseFilterState(status: $status, query: $query)';
}
```

```dart
// lib/features/courses/query/course_filter_query.dart
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/courses/domain/models/course_filter_state.dart';

/// Lowers the course list's filter to the query tree (#2365). The ONLY
/// evaluator of a CourseFilterState: a field added to it and not named here
/// fails `course_filter_query_census_test`. A course is in progress while
/// it has no completion date, which is how the entity defines it.
extension CourseFilterQuery on CourseFilterState {
  QueryNode? toQuery() {
    final parts = <QueryNode>[
      if (status == CourseStatusFilter.inProgress)
        ConditionNode(FieldPath(['completionDate']), QueryOp.isEmpty, null),
      if (status == CourseStatusFilter.completed)
        ConditionNode(FieldPath(['completionDate']), QueryOp.isSet, null),
      ?query,
    ];
    if (parts.isEmpty) return null;
    return parts.length == 1 ? parts.first : AndNode(parts);
  }
}
```

- [ ] **Step 4: Run them to verify they pass**

Run: `flutter test test/features/courses/query/`
Expected: PASS.

- [ ] **Step 5: Write the failing provider test**

```dart
// test/features/courses/presentation/providers/course_query_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/courses/domain/models/course_filter_state.dart';
import 'package:submersion/features/courses/presentation/providers/course_query_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    Future<void> sql(String s) => db.customStatement(s);
    await sql(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', $now, $now)",
    );
    await sql(
      'INSERT INTO courses (id, diver_id, name, agency, start_date, '
      'completion_date, created_at, updated_at) VALUES '
      "('ow', 'me', 'OW', 'padi', $now, $now, $now, $now), "
      "('aow', 'me', 'AOW', 'padi', $now, NULL, $now, $now), "
      "('tec', 'me', 'Tec', 'tdi', $now, $now, $now, $now)",
    );
    SharedPreferences.setMockInitialValues({currentDiverIdKey: 'me'});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<Set<String>> visible() async {
    final sub = container.listen(filteredCoursesProvider, (_, _) {});
    addTearDown(sub.close);
    for (var i = 0; i < 200; i++) {
      final v = container.read(filteredCoursesProvider);
      if (v.hasError) throw v.error!;
      if (v.hasValue && !v.isLoading) return {for (final c in v.value!) c.id};
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    fail('the course list never settled');
  }

  test('status and query compose', () async {
    expect(await visible(), {'ow', 'aow', 'tec'});
    final state = container.read(courseFilterProvider.notifier);
    state.state = const CourseFilterState(
      status: CourseStatusFilter.inProgress,
    );
    expect(await visible(), {'aow'});
    state.state = CourseFilterState(
      status: CourseStatusFilter.completed,
      query: ConditionNode(
        FieldPath(['agency']),
        QueryOp.eq,
        const EnumValue('padi'),
      ),
    );
    expect(await visible(), {'ow'});
  });
}
```

- [ ] **Step 6: Run it to verify it fails**

Run: `flutter test test/features/courses/presentation/providers/course_query_providers_test.dart`
Expected: FAIL to compile.

- [ ] **Step 7: Implement the providers**

```dart
// lib/features/courses/presentation/providers/course_query_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/models/course_filter_state.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/query/course_filter_query.dart';
import 'package:submersion/features/courses/query/course_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';

/// The course list's filter (#2365): the status chips and the query.
final courseFilterProvider = StateProvider<CourseFilterState>(
  (ref) => const CourseFilterState(),
);

/// The course list narrowed by the status chips and the query in SQL; the
/// list, compact pane and table all read this, so the chips now apply in
/// table mode too.
final filteredCoursesProvider = Provider<AsyncValue<List<Course>>>(
  (ref) => narrowByQuery(
    ref,
    ref.watch(courseListNotifierProvider),
    courseQueryEntity,
    ref.watch(courseFilterProvider).toQuery(),
    (c) => c.id,
  ),
);
```

- [ ] **Step 8: Run it to verify it passes**

Run: `flutter test test/features/courses/presentation/providers/course_query_providers_test.dart`
Expected: PASS.

- [ ] **Step 9: Write the failing widget tests**

Add to `course_list_content_test.dart`, inside `main()` (imports: `query_node.dart`, `course_filter_state.dart`, `course_query_providers.dart`, `query_id_set_providers.dart`, `query_chips_frame.dart`):

```dart
  group('status chips and query (#2365)', () {
    Future<ProviderContainer> pump(
      WidgetTester tester, {
      required Set<String> ids,
      CourseFilterState filter = const CourseFilterState(),
      ListViewMode viewMode = ListViewMode.detailed,
    }) async {
      final overrides = await _buildPhoneOverrides(
        courses: [
          _makeCourse(id: 'k1', name: 'Open Water'),
          _makeCourse(id: 'k2', name: 'Rescue'),
        ],
        viewMode: viewMode,
      );
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            courseFilterProvider.overrideWith((ref) => filter),
            entityQueryIdsProvider.overrideWith((ref, key) async => ids),
          ],
          child: const CourseListContent(showAppBar: true),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(CourseListContent)),
      );
    }

    testWidgets('a status chip writes the filter state', (tester) async {
      final c = await pump(tester, ids: const {});
      await tester.tap(find.text('In Progress'));
      await tester.pumpAndSettle();
      expect(
        c.read(courseFilterProvider).status,
        CourseStatusFilter.inProgress,
      );
    });

    testWidgets('table mode reads the filtered courses', (tester) async {
      await pump(
        tester,
        ids: {'k2'},
        filter: const CourseFilterState(status: CourseStatusFilter.completed),
        viewMode: ListViewMode.table,
      );
      expect(find.text('Rescue'), findsWidgets);
      expect(find.text('Open Water'), findsNothing);
    });

    testWidgets('a query that keeps nothing shows the no-match state', (
      tester,
    ) async {
      await pump(
        tester,
        ids: const {},
        filter: CourseFilterState(
          query: ConditionNode(
            FieldPath(['agency']),
            QueryOp.eq,
            const EnumValue('tdi'),
          ),
        ),
      );
      expect(find.byType(QueryNoMatchState), findsOneWidget);
    });
  });
```

Give the file's `_buildPhoneOverrides` a `ListViewMode viewMode = ListViewMode.detailed` parameter and pass it to its `courseListViewModeProvider.overrideWith((ref) => viewMode)` (it hard-codes `ListViewMode.detailed` today).

- [ ] **Step 10: Run them to verify they fail**

Run: `flutter test test/features/courses/presentation/widgets/course_list_content_test.dart --plain-name "status chips and query"`
Expected: FAIL: the chip writes widget state, not the provider; table mode lists both courses.

- [ ] **Step 11: Wire the list**

In `course_list_content.dart` (add imports: `course_filter_state.dart`, `course_query_providers.dart`, `course_query_entity.dart`, `query_subject.dart`, `query_node.dart show QueryNode`, `query_filter_sheet.dart`, `query_chips_frame.dart`):

1. Delete the field `String _filterStatus = 'all'; // 'all', 'in_progress', 'completed'`.
2. In `build`, replace `ref.watch(courseListNotifierProvider)` with `ref.watch(filteredCoursesProvider)`; in the bulk "mark complete" helper, replace `ref.read(courseListNotifierProvider).value` with `ref.read(filteredCoursesProvider).value`.
3. `_visibleCourses` now only sorts (the provider filtered):

```dart
  /// The filtered courses, sorted. Shared by the list and by the pruning in
  /// [build] so the selection never holds a course the filter has hidden.
  List<Course> _visibleCourses(
    List<Course> courses,
    SortState<CourseSortField> sort,
  ) => applyCourseSorting(courses, sort);
```

4. In `_buildFilterChips`, read the state once at the top, `final status = ref.watch(courseFilterProvider).status;`, and for each chip replace `_filterStatus == 'all'` with `status == CourseStatusFilter.all` (and `'in_progress'` with `CourseStatusFilter.inProgress`, `'completed'` with `CourseStatusFilter.completed`), and each `setState(() => _filterStatus = ...)` with `_setStatus(CourseStatusFilter.<value>)`, where:

```dart
  void _setStatus(CourseStatusFilter status) {
    final notifier = ref.read(courseFilterProvider.notifier);
    notifier.state = notifier.state.copyWith(status: status);
  }

  void _setQuery(QueryNode? query) {
    final notifier = ref.read(courseFilterProvider.notifier);
    notifier.state = query == null
        ? notifier.state.copyWith(clearQuery: true)
        : notifier.state.copyWith(query: query);
  }

  void _openQueryFilter() => showQueryFilterSheet(
    context,
    subject: QuerySubject.courses,
    root: courseQueryEntity,
    initial: ref.read(courseFilterProvider).query,
    onApply: (ref, query) {
      final notifier = ref.read(courseFilterProvider.notifier);
      notifier.state = query == null
          ? notifier.state.copyWith(clearQuery: true)
          : notifier.state.copyWith(query: query);
    },
  );

  Widget _withQueryChips(Widget child) => QueryChipsFrame(
    root: courseQueryEntity,
    query: ref.watch(courseFilterProvider).query,
    onChanged: _setQuery,
    child: child,
  );
```

5. `_buildEmptyState`: first, `final filter = ref.watch(courseFilterProvider); if (filter.query != null) return QueryNoMatchState(onClear: () => _setQuery(null));`, then compute the message from `filter.status` (`CourseStatusFilter.inProgress` gives `courses_empty_noInProgress`, `.completed` gives `courses_empty_noCompleted`, otherwise `courses_empty_title`).
6. Wrap `buildContent()`'s `coursesAsync.when(...)` and the table branch's `_buildTableView(context, coursesAsync)` in `_withQueryChips(...)`, as in Task 8.
7. Put `QueryFilterButton(active: ref.watch(courseFilterProvider).query != null, onPressed: _openQueryFilter)` before `ValueKey('enter_selection')` in the mobile actions, the compact version (`compact: true`) in the compact bar, and a `Consumer`-wrapped button before the sort `IconButton` in `course_list_page.dart`'s `appBarActions` (as in Task 8, with `courseFilterProvider`'s query and the `onApply` above).

- [ ] **Step 12: Run the course tests**

Run: `flutter test test/features/courses/ test/architecture/`
Expected: PASS.

- [ ] **Step 13: Commit**

```bash
git add lib/features/courses/domain/models/course_filter_state.dart lib/features/courses/query/course_filter_query.dart lib/features/courses/presentation/providers/course_query_providers.dart lib/features/courses/presentation/widgets/course_list_content.dart lib/features/courses/presentation/pages/course_list_page.dart test/features/courses
git commit -m "feat(courses): the status chips and a query filter the course list in SQL, table mode included"
```

---

### Task 12: Both species pages on the query

**Files:**
- Create: `lib/features/marine_life/presentation/providers/species_query_providers.dart`
- Modify: `lib/features/marine_life/presentation/pages/species_page.dart`, `lib/features/marine_life/presentation/pages/species_manage_page.dart`
- Test: `test/features/marine_life/presentation/providers/species_query_providers_test.dart`; add groups to `species_page_test.dart` and `species_manage_page_test.dart`

**Interfaces:**
- Consumes: Task 1 pieces; `speciesQueryEntity` (Task 6).
- Produces: `seenSpeciesQueryProvider`, `speciesCatalogQueryProvider` (`StateProvider<QueryNode?>`), `filteredSeenSpeciesProvider` (`Provider<AsyncValue<List<SeenSpecies>>>`), `filteredSpeciesCatalogProvider` (`Provider<AsyncValue<List<Species>>>`).

- [ ] **Step 1: Write the failing provider test**

```dart
// test/features/marine_life/presentation/providers/species_query_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_query_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO species (id, common_name, category, is_built_in) VALUES '
      "('t_whale', 'Test Whale', 'mammal', 0), "
      "('t_coral', 'Test Coral', 'coral', 0)",
    );
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('the catalog query narrows the catalog', () async {
    final sub = container.listen(filteredSpeciesCatalogProvider, (_, _) {});
    addTearDown(sub.close);
    container.read(speciesCatalogQueryProvider.notifier).state = ConditionNode(
      FieldPath(['category']),
      QueryOp.eq,
      const EnumValue('mammal'),
    );
    Set<String> ours() => {
      for (final s
          in container.read(filteredSpeciesCatalogProvider).value ?? const [])
        if (s.id.startsWith('t_')) s.id,
    };
    for (var i = 0; i < 200 && ours().isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(ours(), {'t_whale'});
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/marine_life/presentation/providers/species_query_providers_test.dart`
Expected: FAIL to compile.

- [ ] **Step 3: Implement the providers**

```dart
// lib/features/marine_life/presentation/providers/species_query_providers.dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart' show QueryNode;
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/query/species_query_entity.dart';
import 'package:submersion/features/query/presentation/providers/narrow_by_ids.dart';

/// The nav Species page's query (#2365): over the species this diver has
/// sighted. Held apart from the catalog's, as each page's search is.
final seenSpeciesQueryProvider = StateProvider<QueryNode?>((ref) => null);

/// The species catalog's (Manage page) query.
final speciesCatalogQueryProvider = StateProvider<QueryNode?>((ref) => null);

/// The diver's sighted species narrowed to the query's ids; the page's own
/// search, category chips and sort still apply on top, in Dart.
final filteredSeenSpeciesProvider = Provider<AsyncValue<List<SeenSpecies>>>(
  (ref) => narrowByQuery(
    ref,
    ref.watch(seenSpeciesProvider),
    speciesQueryEntity,
    ref.watch(seenSpeciesQueryProvider),
    (s) => s.species.id,
  ),
);

/// The catalog narrowed to the query's ids; the Manage page's search and
/// category chips still apply on top.
final filteredSpeciesCatalogProvider = Provider<AsyncValue<List<Species>>>(
  (ref) => narrowByQuery(
    ref,
    ref.watch(speciesListNotifierProvider),
    speciesQueryEntity,
    ref.watch(speciesCatalogQueryProvider),
    (s) => s.id,
  ),
);
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/features/marine_life/presentation/providers/species_query_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing page tests**

In `species_page_test.dart`, add a parameter to `_pumpPage`: `List<Override> extra = const []`, appended to its overrides list, and add inside `main()`:

```dart
  group('query (#2365)', () {
    final sharks = ConditionNode(
      FieldPath(['category']),
      QueryOp.eq,
      const EnumValue('shark'),
    );

    testWidgets('the query narrows the sighted species', (tester) async {
      await _pumpPage(
        tester,
        [_whaleShark, _turtle],
        extra: [
          seenSpeciesQueryProvider.overrideWith((ref) => sharks),
          entityQueryIdsProvider.overrideWith(
            (ref, key) async => {'sp_whale_shark'},
          ),
        ],
      );
      expect(find.text('Whale Shark'), findsOneWidget);
      expect(find.text('Green Sea Turtle'), findsNothing);
      expect(find.text('category = shark'), findsOneWidget);
    });

    testWidgets('a query that keeps nothing shows the no-match state', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        [_whaleShark, _turtle],
        extra: [
          seenSpeciesQueryProvider.overrideWith((ref) => sharks),
          entityQueryIdsProvider.overrideWith((ref, key) async => const {}),
        ],
      );
      expect(find.byType(QueryNoMatchState), findsOneWidget);
    });
  });
```

In `species_manage_page_test.dart`, give `host` a parameter `List<Override> extra = const []` appended to its overrides, and add:

```dart
  testWidgets('the catalog query narrows the catalog (#2365)', (tester) async {
    await tester.pumpWidget(
      host(
        species: [
          _species(id: 's1', name: 'Aaa fish'),
          _species(id: 's2', name: 'Bbb fish'),
        ],
        extra: [
          speciesCatalogQueryProvider.overrideWith(
            (ref) => ConditionNode(
              FieldPath(['name']),
              QueryOp.eq,
              const StringValue('Bbb fish'),
            ),
          ),
          entityQueryIdsProvider.overrideWith((ref, key) async => {'s2'}),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Bbb fish'), findsOneWidget);
    expect(find.text('Aaa fish'), findsNothing);
  });
```

(Imports in both tests: `query_node.dart`, `species_query_providers.dart`, `query_id_set_providers.dart`, `query_chips_frame.dart`.)

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/features/marine_life/presentation/pages/`
Expected: FAIL: both species still listed.

- [ ] **Step 7: Wire the two pages**

`species_page.dart` (imports: `species_query_providers.dart`, `species_query_entity.dart`, `query_subject.dart`, `query_filter_sheet.dart`, `query_chips_frame.dart`):

1. `final entriesAsync = ref.watch(filteredSeenSpeciesProvider);` in `build`.
2. First entry of `AppBar.actions`:

```dart
          QueryFilterButton(
            active: ref.watch(seenSpeciesQueryProvider) != null,
            onPressed: () => showQueryFilterSheet(
              context,
              subject: QuerySubject.species,
              root: speciesQueryEntity,
              initial: ref.read(seenSpeciesQueryProvider),
              onApply: (ref, query) =>
                  ref.read(seenSpeciesQueryProvider.notifier).state = query,
            ),
          ),
```

3. Wrap the body's `Expanded` child: `Expanded(child: QueryChipsFrame(root: speciesQueryEntity, query: ref.watch(seenSpeciesQueryProvider), onChanged: (q) => ref.read(seenSpeciesQueryProvider.notifier).state = q, child: entriesAsync.when(...)))`.
4. At the top of `_buildList`: `if (entries.isEmpty && ref.watch(seenSpeciesQueryProvider) != null) { return QueryNoMatchState(onClear: () => ref.read(seenSpeciesQueryProvider.notifier).state = null); }`.

`species_manage_page.dart`, the same four edits with `speciesCatalogQueryProvider` and `filteredSpeciesCatalogProvider`: the provider in `build` (it feeds both `selectableIds` and the list); the button first in the non-selection `AppBar.actions`, before `ValueKey('enter_selection')`; the frame around the body's `Expanded` child `speciesAsync.when(...)`; and the no-match guard at the top of `_buildSpeciesList(allSpecies)` when `allSpecies.isEmpty` and the catalog query is set.

- [ ] **Step 8: Run the species tests**

Run: `flutter test test/features/marine_life/ test/architecture/`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib/features/marine_life/presentation/providers/species_query_providers.dart lib/features/marine_life/presentation/pages/species_page.dart lib/features/marine_life/presentation/pages/species_manage_page.dart test/features/marine_life
git commit -m "feat(marine-life): the sighted-species page and the catalog each filter through a query"
```

---

### Task 13: Spec record, verification and the PR

**Files:**
- Modify: `docs/design/specs/2026-09-25-entity-query-language-design.md`

- [ ] **Step 1: Record the deviations**

Add "## Deviations recorded during implementation (PR 4)" after the PR 3 section, one bullet per item in "Decisions settled for this plan" above, plus any ledgered ruling from the tasks, worded as facts, no em-dashes.

- [ ] **Step 2: Full verification**

1. `git fetch origin main` and merge it (never rebase); resolve; `flutter analyze --fatal-infos`; `flutter test test/architecture/ test/l10n/`.
2. Re-scan the schema ladder (open PR diffs and every worktree scalar). If 245 was taken, renumber the rung, its test, the `database.dart` comment and the spec note.
3. Run the whole suite once: `flutter test --exclude-tags performance`, logged to a file and read with the Read tool. Every failure is fixed or shown to pass alone and named in the PR.
4. Check line endings: no changed Dart file flipped between CRLF and LF against `origin/main`.

- [ ] **Step 3: Commit, push, open the PR**

```bash
git add docs/design/specs/2026-09-25-entity-query-language-design.md
git commit -m "docs(query): record the PR 4 deviations"
git push -u origin HEAD
gh pr create --title "feat(query): entity query language, PR 4: buddies, centers, certifications, courses and species" --body-file <body file>
gh pr edit <n> --add-reviewer "@copilot"
```

The body: what each list gained (filter icon, sheet, chips, no-match state), the registry additions, the course chips moving into SQL (and applying in table mode), the v245 index, the accepted gaps (enum text, English species search, unscoped relations, unfiltered center map), `Refs #2365`, the Screenshots section as Eric decides, and the test plan. No attribution lines.
