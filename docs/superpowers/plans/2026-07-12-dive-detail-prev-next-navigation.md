# Dive Detail Previous / Next Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user step to the adjacent dive from the dive detail page via Previous/Next buttons (and Left/Right arrow keys on desktop), following the current list filter + sort order.

**Architecture:** A new lightweight repository query returns the ordered dive IDs for the active filter+sort (reusing the visible list's SQL clauses). Riverpod providers expose that list and compute each dive's `(previousId, nextId)`. A reusable `DiveNavButtons` widget renders the controls; the detail page mounts it in both surfaces and handles navigation + keyboard shortcuts.

**Tech Stack:** Flutter (Material 3), Riverpod, go_router, Drift, `flutter_test`.

## Global Constraints

- All Dart must pass `dart format .` with no changes (run before every commit).
- All Dart must pass `flutter analyze` with no new issues.
- No emojis in code/comments. Immutability; small focused files.
- `DiveRepository` is a single concrete class in
  `lib/features/dive_log/data/repositories/dive_repository_impl.dart` — there is
  **no separate abstract interface** to update.
- The existing `getPreviousDive(String diveId)` is the chronological
  surface-interval/deco "previous by entry time" query — **unrelated**. Do not
  reuse or modify it; the new navigation is filter+sort aware.
- `getOrderedDiveIds` MUST reuse `_buildFilterWhereClauses` and
  `_buildSortOrderBy` so its order matches `getDiveSummaries` exactly.
- Adjacency follows `diveFilterProvider` + `diveSortProvider` (app-global).
- Scope: dives only.
- Worktree hygiene (project memory): never `git add -A` (records stale submodule
  gitlink); stage explicit paths. Pre-push hook runs vs the main tree — if
  pushing, `--no-verify`. Do not push unless asked.

---

### Task 1: `getOrderedDiveIds` repository query

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart` (add method near `getDiveSummaries`, ~line 1473)
- Test: `test/features/dive_log/data/repositories/dive_ordered_ids_test.dart` (new)

**Interfaces:**
- Consumes: private `_buildFilterWhereClauses(filter, whereClauses, args)` and `_buildSortOrderBy(sort)` on the same class; `PerfTimer.measure`; `_db.customSelect`.
- Produces: `Future<List<String>> getOrderedDiveIds({String? diverId, DiveFilterState filter, SortState<DiveSortField>? sort})` returning dive IDs in the active filter+sort order (no pagination).

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/data/repositories/dive_ordered_ids_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<String> insertDive(String id, int dateTimeMs, {int? number}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.dives).insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(dateTimeMs),
            diveNumber: Value(number),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  test('returns ids in the same order as getDiveSummaries (date desc)', () async {
    await insertDive('a', 1000, number: 1);
    await insertDive('b', 3000, number: 3);
    await insertDive('c', 2000, number: 2);

    const sort = SortState(
      field: DiveSortField.date,
      direction: SortDirection.descending,
    );

    final ids = await repository.getOrderedDiveIds(sort: sort);
    final summaries = await repository.getDiveSummaries(sort: sort, limit: 1000);

    expect(ids, summaries.map((s) => s.id).toList());
    expect(ids, ['b', 'c', 'a']); // newest first
  });

  test('respects sort direction (date asc)', () async {
    await insertDive('a', 1000);
    await insertDive('b', 3000);
    await insertDive('c', 2000);

    final ids = await repository.getOrderedDiveIds(
      sort: const SortState(
        field: DiveSortField.date,
        direction: SortDirection.ascending,
      ),
    );
    expect(ids, ['a', 'c', 'b']);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/data/repositories/dive_ordered_ids_test.dart`
Expected: FAIL — `getOrderedDiveIds` is not defined.

- [ ] **Step 3: Implement the method**

In `dive_repository_impl.dart`, add immediately after `getDiveSummaries` (before `getDiveCount`):

```dart
  /// Returns every dive id matching [filter] in [sort] order — the same order
  /// as [getDiveSummaries] but without pagination and selecting only the id.
  ///
  /// Used to compute previous/next navigation from the detail page. Distinct
  /// from [getPreviousDive], which is the chronological surface-interval query.
  Future<List<String>> getOrderedDiveIds({
    String? diverId,
    DiveFilterState filter = const DiveFilterState(),
    SortState<DiveSortField>? sort,
  }) async {
    try {
      return await PerfTimer.measure('getOrderedDiveIds', () async {
        final whereClauses = <String>[];
        final args = <Variable<Object>>[];

        if (diverId != null) {
          whereClauses.add('d.diver_id = ?');
          args.add(Variable(diverId));
        }

        _buildFilterWhereClauses(filter, whereClauses, args);

        final whereClause = whereClauses.isNotEmpty
            ? 'WHERE ${whereClauses.join(' AND ')}'
            : '';
        final orderByClause = _buildSortOrderBy(sort);

        final sql =
            'SELECT d.id '
            'FROM dives d '
            'LEFT JOIN dive_sites s ON d.site_id = s.id '
            '$whereClause '
            'ORDER BY $orderByClause';

        final rows = await _db
            .customSelect(
              sql,
              variables: args,
              readsFrom: {_db.dives, _db.diveSites},
            )
            .get();

        return rows.map((r) => r.read<String>('id')).toList();
      });
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get ordered dive ids',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/data/repositories/dive_ordered_ids_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_ordered_ids_test.dart
flutter analyze lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_ordered_ids_test.dart
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart test/features/dive_log/data/repositories/dive_ordered_ids_test.dart
git commit -m "feat(dive-log): getOrderedDiveIds query for adjacent-dive navigation"
```
Expected: format no changes, analyze clean, both tests pass.

---

### Task 2: Ordered-ids + neighbors providers

**Files:**
- Modify: `lib/features/dive_log/presentation/providers/dive_providers.dart`
- Test: `test/features/dive_log/presentation/providers/dive_neighbors_provider_test.dart` (new)

**Interfaces:**
- Consumes: `diveRepositoryProvider`, `currentDiverIdProvider` (from `diver_providers.dart`, already imported/available in `dive_providers.dart`), `diveFilterProvider`, `diveSortProvider`, and `getOrderedDiveIds` from Task 1.
- Produces:
  - `typedef DiveNeighbors = ({String? previousId, String? nextId});`
  - `final orderedDiveIdsProvider = FutureProvider.autoDispose<List<String>>(...)`
  - `final diveNeighborsProvider = Provider.family<DiveNeighbors, String>(...)`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/providers/dive_neighbors_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

void main() {
  test('middle item has both neighbors', () async {
    final container = ProviderContainer(
      overrides: [orderedDiveIdsProvider.overrideWith((ref) async => ['a', 'b', 'c'])],
    );
    addTearDown(container.dispose);
    await container.read(orderedDiveIdsProvider.future);
    expect(
      container.read(diveNeighborsProvider('b')),
      (previousId: 'a', nextId: 'c'),
    );
  });

  test('first item has no previous', () async {
    final container = ProviderContainer(
      overrides: [orderedDiveIdsProvider.overrideWith((ref) async => ['a', 'b', 'c'])],
    );
    addTearDown(container.dispose);
    await container.read(orderedDiveIdsProvider.future);
    expect(
      container.read(diveNeighborsProvider('a')),
      (previousId: null, nextId: 'b'),
    );
  });

  test('last item has no next', () async {
    final container = ProviderContainer(
      overrides: [orderedDiveIdsProvider.overrideWith((ref) async => ['a', 'b', 'c'])],
    );
    addTearDown(container.dispose);
    await container.read(orderedDiveIdsProvider.future);
    expect(
      container.read(diveNeighborsProvider('c')),
      (previousId: 'b', nextId: null),
    );
  });

  test('id not in list has no neighbors', () async {
    final container = ProviderContainer(
      overrides: [orderedDiveIdsProvider.overrideWith((ref) async => ['a', 'b', 'c'])],
    );
    addTearDown(container.dispose);
    await container.read(orderedDiveIdsProvider.future);
    expect(
      container.read(diveNeighborsProvider('z')),
      (previousId: null, nextId: null),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/providers/dive_neighbors_provider_test.dart`
Expected: FAIL — `orderedDiveIdsProvider` / `diveNeighborsProvider` / `DiveNeighbors` undefined.

- [ ] **Step 3: Add the providers**

In `dive_providers.dart`, near the other list providers (after `sortedFilteredDivesProvider`), add:

```dart
/// A dive's adjacent ids in the current filter+sort order.
typedef DiveNeighbors = ({String? previousId, String? nextId});

/// All dive ids in the active filter+sort order — the source for previous/next
/// navigation from the detail page. IDs only (not full dives), so it stays
/// cheap even on large libraries. Recomputes when filter/sort/diver change.
final orderedDiveIdsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final diverId = ref.watch(currentDiverIdProvider);
  final filter = ref.watch(diveFilterProvider);
  final sort = ref.watch(diveSortProvider);
  final repository = ref.watch(diveRepositoryProvider);
  return repository.getOrderedDiveIds(
    diverId: diverId,
    filter: filter,
    sort: sort,
  );
});

/// The previous/next dive ids adjacent to [diveId] in the current list order.
/// Both are null when the dive is not in the current filtered list.
final diveNeighborsProvider = Provider.family<DiveNeighbors, String>((
  ref,
  diveId,
) {
  final ids = ref.watch(orderedDiveIdsProvider).valueOrNull ?? const <String>[];
  final index = ids.indexOf(diveId);
  if (index < 0) return (previousId: null, nextId: null);
  return (
    previousId: index > 0 ? ids[index - 1] : null,
    nextId: index < ids.length - 1 ? ids[index + 1] : null,
  );
});
```

If `currentDiverIdProvider` is not already imported in `dive_providers.dart`, add:
`import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';`
(check the existing imports first — the paginated notifier already reads it, so it is likely imported).

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/providers/dive_neighbors_provider_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/providers/dive_providers.dart test/features/dive_log/presentation/providers/dive_neighbors_provider_test.dart
flutter analyze lib/features/dive_log/presentation/providers/dive_providers.dart test/features/dive_log/presentation/providers/dive_neighbors_provider_test.dart
git add lib/features/dive_log/presentation/providers/dive_providers.dart test/features/dive_log/presentation/providers/dive_neighbors_provider_test.dart
git commit -m "feat(dive-log): orderedDiveIds + diveNeighbors providers"
```
Expected: format no changes, analyze clean, tests pass.

---

### Task 3: `DiveNavButtons` widget

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/dive_nav_buttons.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_nav_buttons_test.dart` (new)

**Interfaces:**
- Consumes: `diveNeighborsProvider(diveId)` from Task 2; `context.l10n` for tooltips.
- Produces: `class DiveNavButtons extends ConsumerWidget` with
  `const DiveNavButtons({required String diveId, required void Function(String neighborId) onNavigate})`.

Localization: add two ARB keys (English + all 10 non-en locales per project
memory `l10n-all-locales`, then regenerate): `diveLog_detail_tooltip_previousDive`
= "Previous dive", `diveLog_detail_tooltip_nextDive` = "Next dive". If adding to
all locales is heavy, use the English value in every locale as a placeholder
(translation follow-up) — but the keys MUST exist in every locale's ARB and be
regenerated, or the build breaks.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/presentation/widgets/dive_nav_buttons_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_nav_buttons.dart';

Widget _host({
  required String diveId,
  required List<String> ids,
  required void Function(String) onNavigate,
}) {
  return ProviderScope(
    overrides: [orderedDiveIdsProvider.overrideWith((ref) async => ids)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) {
            // Prime the future so the family reads a value.
            ref.watch(orderedDiveIdsProvider);
            return DiveNavButtons(diveId: diveId, onNavigate: onNavigate);
          },
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('middle item: both enabled, tap navigates', (tester) async {
    final tapped = <String>[];
    await tester.pumpWidget(_host(
      diveId: 'b',
      ids: ['a', 'b', 'c'],
      onNavigate: tapped.add,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.tap(find.byIcon(Icons.chevron_right));
    expect(tapped, ['a', 'c']);
  });

  testWidgets('first item: previous disabled', (tester) async {
    await tester.pumpWidget(_host(
      diveId: 'a',
      ids: ['a', 'b', 'c'],
      onNavigate: (_) {},
    ));
    await tester.pumpAndSettle();

    final prev = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.chevron_left),
        matching: find.byType(IconButton),
      ),
    );
    expect(prev.onPressed, isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_nav_buttons_test.dart`
Expected: FAIL — `DiveNavButtons` / `dive_nav_buttons.dart` do not exist.

- [ ] **Step 3: Add the ARB keys**

Add to `lib/l10n/arb/app_en.arb` (and each of the 10 non-en `app_<locale>.arb`
files — English value as placeholder is acceptable pending translation):

```json
"diveLog_detail_tooltip_previousDive": "Previous dive",
"diveLog_detail_tooltip_nextDive": "Next dive",
```

Regenerate: `flutter gen-l10n` (or `flutter pub get` if the project regenerates
on pub get — check `l10n.yaml`).

- [ ] **Step 4: Implement the widget**

Create `lib/features/dive_log/presentation/widgets/dive_nav_buttons.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// Previous / next controls for stepping to the dive adjacent to [diveId] in
/// the current list (filter + sort) order. Each button is disabled when there
/// is no neighbor in that direction (list ends, or dive not in the filter).
class DiveNavButtons extends ConsumerWidget {
  const DiveNavButtons({
    super.key,
    required this.diveId,
    required this.onNavigate,
  });

  final String diveId;
  final void Function(String neighborId) onNavigate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final neighbors = ref.watch(diveNeighborsProvider(diveId));
    final previousId = neighbors.previousId;
    final nextId = neighbors.nextId;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: context.l10n.diveLog_detail_tooltip_previousDive,
          onPressed: previousId == null ? null : () => onNavigate(previousId),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: context.l10n.diveLog_detail_tooltip_nextDive,
          onPressed: nextId == null ? null : () => onNavigate(nextId),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_nav_buttons_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/widgets/dive_nav_buttons.dart test/features/dive_log/presentation/widgets/dive_nav_buttons_test.dart
flutter analyze lib/features/dive_log/presentation/widgets/dive_nav_buttons.dart test/features/dive_log/presentation/widgets/dive_nav_buttons_test.dart lib/l10n
git add lib/features/dive_log/presentation/widgets/dive_nav_buttons.dart test/features/dive_log/presentation/widgets/dive_nav_buttons_test.dart lib/l10n
git commit -m "feat(dive-log): DiveNavButtons previous/next widget + l10n"
```
Expected: format no changes, analyze clean, tests pass.

---

### Task 4: Wire into DiveDetailPage — surfaces, navigation, arrow keys

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Test: `test/features/dive_log/presentation/pages/dive_detail_nav_test.dart` (new)

**Interfaces:**
- Consumes: `DiveNavButtons` (Task 3), `orderedDiveIdsProvider` (Task 2, for the widget test override), `widget.embedded`, `widget.diveId`, `context.go`/`context.replace`.
- Produces: navigation behavior; a private `void _navigateToDive(String neighborId)` helper.

- [ ] **Step 1: Add the navigation helper**

In `_DiveDetailPageState` (the state class of `DiveDetailPage`), add near `diveId`:

```dart
  void _navigateToDive(String neighborId) {
    if (widget.embedded) {
      // Master-detail: swap the selected item (the DetailScrollRetainer keeps
      // the scroll offset, so you land on the same section of the next dive).
      context.go('/dives?selected=$neighborId');
    } else {
      // Standalone route: replace so stepping through dives does not pile up
      // the back stack.
      context.replace('/dives/$neighborId');
    }
  }
```

Add the import at the top (grouped with local imports):
```dart
import 'package:submersion/features/dive_log/presentation/widgets/dive_nav_buttons.dart';
```

- [ ] **Step 2: Add nav buttons to the standalone AppBar**

In `_buildContent`, in the standalone `Scaffold`'s `AppBar`, prepend the buttons
to `actions`. The current actions list begins:

```dart
      appBar: AppBar(
        title: Text(context.l10n.diveLog_detail_appBar),
        actions: [
          IconButton(
            icon: Icon(
              dive.isFavorite ? Icons.favorite : Icons.favorite_border,
```

Insert before that first `IconButton`:

```dart
        actions: [
          DiveNavButtons(diveId: diveId, onNavigate: _navigateToDive),
          IconButton(
            icon: Icon(
              dive.isFavorite ? Icons.favorite : Icons.favorite_border,
```

- [ ] **Step 3: Add nav buttons to the embedded header**

In `_buildEmbeddedHeader`, the header `Row` ends its `Expanded` name column and
then has the favorite `IconButton`. Insert the nav buttons right before the
favorite button:

```dart
          // Favorite toggle
          IconButton(
            icon: Icon(
              dive.isFavorite ? Icons.favorite : Icons.favorite_border,
```

becomes:

```dart
          DiveNavButtons(diveId: dive.id, onNavigate: _navigateToDive),
          // Favorite toggle
          IconButton(
            icon: Icon(
              dive.isFavorite ? Icons.favorite : Icons.favorite_border,
```

- [ ] **Step 4: Add arrow-key shortcuts**

Wrap both widgets `_buildContent` returns in `CallbackShortcuts` + `Focus`.
There are two return sites:

- Embedded: `return Column(children: [_buildEmbeddedHeader(...), Expanded(child: body)]);`
- Standalone: `return Scaffold(appBar: AppBar(...), body: body ...);`

Wrap each returned widget by passing it through the helper — e.g. the embedded
one becomes:

```dart
    if (widget.embedded) {
      return _wrapWithDiveShortcuts(
        dive,
        Column(
          children: [
            _buildEmbeddedHeader(context, ref, dive, hasRawData: hasRawData),
            Expanded(child: body),
          ],
        ),
      );
    }
```

and the standalone `return Scaffold(...)` becomes
`return _wrapWithDiveShortcuts(dive, Scaffold(...));` (wrap the whole existing
`Scaffold(...)` expression unchanged).

Add the helper to `_DiveDetailPageState`:

```dart
  Widget _wrapWithDiveShortcuts(Dive dive, Widget child) {
    final neighbors = ref.watch(diveNeighborsProvider(dive.id));
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          final id = neighbors.previousId;
          if (id != null) _navigateToDive(id);
        },
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          final id = neighbors.nextId;
          if (id != null) _navigateToDive(id);
        },
      },
      child: Focus(autofocus: false, child: child),
    );
  }
```

Add imports:
```dart
import 'package:flutter/services.dart'; // LogicalKeyboardKey (if not present)
```
(`diveNeighborsProvider` comes from the dive providers import already used by the
page; confirm it is imported — the page already imports `dive_providers.dart`.)

- [ ] **Step 5: Write the widget test**

Create `test/features/dive_log/presentation/pages/dive_detail_nav_test.dart`.

**Coverage note (honest scoping):** a full `DiveDetailPage` needs a seeded DB and
many providers, which the existing dive-detail tests avoid. This test therefore
covers the navigation *contract* — `DiveNavButtons` in a router host firing the
same `context.go('/dives?selected=$id')` the embedded surface uses. The two
page-specific behaviours that can't be cheaply unit-tested here — the
embedded-vs-standalone branch in `_navigateToDive` and the arrow-key bindings in
`_wrapWithDiveShortcuts` — are verified in Task 5's manual check (steps 5-6).
Do not claim automated coverage for the arrow keys.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_nav_buttons.dart';

void main() {
  testWidgets('embedded onNavigate swaps the selected query param', (
    tester,
  ) async {
    String? lastLocation;
    final router = GoRouter(
      initialLocation: '/dives?selected=b',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (context, state) {
            lastLocation = state.uri.toString();
            return Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  ref.watch(orderedDiveIdsProvider);
                  return DiveNavButtons(
                    diveId: 'b',
                    onNavigate: (id) => context.go('/dives?selected=$id'),
                  );
                },
              ),
            );
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orderedDiveIdsProvider.overrideWith((ref) async => ['a', 'b', 'c']),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(lastLocation, '/dives?selected=c');
  });
}
```

- [ ] **Step 6: Run the test**

Run: `flutter test test/features/dive_log/presentation/pages/dive_detail_nav_test.dart`
Expected: PASS.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/pages/dive_detail_nav_test.dart
flutter analyze lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/pages/dive_detail_nav_test.dart
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart test/features/dive_log/presentation/pages/dive_detail_nav_test.dart
git commit -m "feat(dive-log): previous/next buttons + arrow keys on dive detail"
```
Expected: format no changes, analyze clean, test passes.

---

### Task 5: Whole-project verification + manual check

**Files:** none (verification only).

- [ ] **Step 1: Whole-project format and analyze**

```bash
dart format .
flutter analyze
```
Expected: `dart format .` no changes; `flutter analyze` "No issues found!". Commit any format-only changes if produced.

- [ ] **Step 2: Run the dive_log suite**

```bash
flutter test test/features/dive_log 2>&1 | tail -20
```
Expected: all pass (same pass/skip set as before, plus the new tests).

- [ ] **Step 3: Manual verification (run skill, macOS)**

Launch the app (honor the single-instance rule — check for an existing session
first). Then:
1. Open Dives (wide window, master-detail). Open a dive, click Next a few times —
   confirm it steps to adjacent dives and the scroll section is retained.
2. Confirm Previous is disabled on the newest dive and Next on the oldest (with
   default date-desc sort).
3. Change the sort (e.g. by depth) and confirm Next/Previous follow the new
   order.
4. Filter the list to exclude the open dive and confirm both buttons disable.
5. Focus the detail pane and press Left / Right arrows — confirm they step
   previous / next.
6. On a narrow window (or the standalone route), confirm the AppBar buttons work
   and the back stack does not grow per step.

---

## Notes for the executor

- Navigation intentionally differs by surface: embedded uses `context.go(?selected=)`, standalone uses `context.replace(/dives/:id)`. Do not unify them.
- The nav order must match the visible list; it does because `getOrderedDiveIds` reuses `getDiveSummaries`'s `_buildFilterWhereClauses` / `_buildSortOrderBy`. If you change one, change both.
- Arrow keys are Left = previous, Right = next (Up/Down stay with scrolling).
- If an edit's "current code" block does not match (line drift), locate the named method/anchor and apply the same change.
