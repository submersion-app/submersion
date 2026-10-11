# Linked-item back navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every item opened from dive details, and every "show dives" list, keeps a back arrow that returns to where the diver came from (#3292, #2784).

**Architecture:** Three small router helpers (`isPushedRoute`, `shouldRedirectToMasterDetail`, `goInPlace`) stop pushed pages from erasing the stack. A single `openDiveList` entry point pushes the dive list with a `DiveListReturn` snapshot; the pushed `DiveListPage` restores the filter and highlight when it leaves, and shows a back arrow.

**Tech Stack:** Flutter, go_router 17.5, Riverpod (`StateProvider`), flutter_test.

**Spec:** `docs/design/specs/2026-10-11-linked-item-back-navigation-design.md`

## Global Constraints

- "Pushed" means page-local: `ModalRoute.of(context)?.canPop ?? false`.
- Top-level sections (sidebar, deep link) behave exactly as before: every helper falls back to `go` and to the existing redirect when the page is not pushed.
- The import wizard keeps `go('/dives')`.
- Links that leave for another section (summary "Dive computers", "Insights"; search header routes; `MainScaffold` destinations) keep `go`.
- No em-dashes anywhere; no new user-facing strings (use `BackButton`, which carries its own localized tooltip).
- Run `dart format .` before each commit; `flutter analyze` before pushing.

## Review Focus

1. **Table mode replaying a stale highlight.** `_TableModeMasterState` defers its highlight-to-URL sync while covered and replays it when uncovered; `highlightedDiveIdProvider` is global. Expected: after back, the original dive is still selected. Pinned by the "restores highlight before the page below replays" test in Task 4.
2. **A selection, then back.** `replace` gives the route a new completer, so nothing may depend on the `push` future. Expected: select a dive in the pushed list, press back, original filter restored. Pinned in Task 4.
3. **Sidebar tap while a pushed list is open** (stack replaced by `go`). Expected: previous filter restored, no exception. Pinned by the dispose-fallback test in Task 4.
4. **Pushed dive list over a top-level dive list** (tag chip on a dive in the master-detail split). Expected: back returns to the same dive, same filter. Pinned in Task 4 (nested restore) and Task 5 (tag chip).
5. **Root deep link still redirects.** Expected: `/equipment/e1` at desktop width with nothing below still goes to `/equipment?selected=e1`. Pinned in Task 2.

---

## File Structure

| File | Responsibility |
| --- | --- |
| Create `lib/core/router/pushed_route.dart` | `isPushedRoute`, `shouldRedirectToMasterDetail` |
| Modify `lib/core/router/section_navigation.dart` | add `goInPlace` to the `SectionNavigation` extension |
| Create `lib/features/dive_log/presentation/navigation/open_dive_list.dart` | `DiveListReturn`, `openDiveList` |
| Modify `lib/core/router/app_router.dart` (`/dives` route, ~line 422) | pass `state.extra` to `DiveListPage` |
| Modify `lib/features/dive_log/presentation/pages/dive_list_page.dart` | hold and restore `DiveListReturn`; `goInPlace`; phone map back pops |
| Modify `lib/features/dive_log/presentation/widgets/dive_list_content.dart` | back arrow in compact header; `goInPlace` |
| Modify `lib/shared/widgets/master_detail/master_detail_scaffold.dart` | `goInPlace`; push on phones when pushed |
| Modify `lib/shared/widgets/table_mode_layout/table_mode_layout.dart` | `goInPlace` in `_openHighlightedInPane` |
| Modify seven detail pages | use `shouldRedirectToMasterDetail` |
| Modify ten "show dives" call sites | use `openDiveList` |
| Create `test/architecture/dive_filter_navigation_single_source_test.dart` | guard |

---

### Task 1: Router helpers

**Files:**
- Create: `lib/core/router/pushed_route.dart`
- Modify: `lib/core/router/section_navigation.dart`
- Test: `test/core/router/pushed_route_test.dart`
- Test: `test/core/router/section_navigation_test.dart` (append a group)

**Interfaces:**
- Produces: `bool isPushedRoute(BuildContext context)`;
  `bool shouldRedirectToMasterDetail(BuildContext context, {required bool embedded, required ListViewMode viewMode})`;
  `extension SectionNavigation on BuildContext { void goInPlace(String location); }`

- [ ] **Step 1: Write the failing tests** in `test/core/router/pushed_route_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/router/pushed_route.dart';

void main() {
  const desktop = Size(1200, 800);
  const phone = Size(400, 800);

  /// Pumps /root and /item; [probe] runs inside /item's build.
  Future<GoRouter> pump(
    WidgetTester tester, {
    required Size size,
    required String initial,
    required void Function(BuildContext) probe,
  }) async {
    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/root', builder: (_, _) => const Text('ROOT')),
        GoRoute(
          path: '/item',
          builder: (_, _) => Builder(
            builder: (context) {
              probe(context);
              return const Text('ITEM');
            },
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(size: size),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a root page is not pushed', (tester) async {
    bool? pushed;
    await pump(tester, size: desktop, initial: '/item',
        probe: (c) => pushed = isPushedRoute(c));
    expect(pushed, isFalse);
  });

  testWidgets('a page pushed over another is pushed', (tester) async {
    bool? pushed;
    final router = await pump(tester, size: desktop, initial: '/root',
        probe: (c) => pushed = isPushedRoute(c));
    router.push('/item');
    await tester.pumpAndSettle();
    expect(pushed, isTrue);
  });

  group('shouldRedirectToMasterDetail', () {
    Future<bool?> decide(
      WidgetTester tester, {
      Size size = desktop,
      bool pushedOver = false,
      bool embedded = false,
      ListViewMode mode = ListViewMode.detailed,
    }) async {
      bool? result;
      final router = await pump(tester, size: size,
          initial: pushedOver ? '/root' : '/item',
          probe: (c) => result = shouldRedirectToMasterDetail(c,
              embedded: embedded, viewMode: mode));
      if (pushedOver) {
        router.push('/item');
        await tester.pumpAndSettle();
      }
      return result;
    }

    testWidgets('root, desktop, list mode: redirect', (tester) async {
      expect(await decide(tester), isTrue);
    });
    testWidgets('pushed: no redirect', (tester) async {
      expect(await decide(tester, pushedOver: true), isFalse);
    });
    testWidgets('embedded: no redirect', (tester) async {
      expect(await decide(tester, embedded: true), isFalse);
    });
    testWidgets('phone width: no redirect', (tester) async {
      expect(await decide(tester, size: phone), isFalse);
    });
    testWidgets('table mode: no redirect', (tester) async {
      expect(await decide(tester, mode: ListViewMode.table), isFalse);
    });
  });
}
```

Append to `test/core/router/section_navigation_test.dart` a `group('goInPlace', ...)` using a fresh router with routes `/root` (button that pushes `/list`) and `/list` (shows `state.uri.toString()` and a button calling `context.goInPlace('/list?selected=d1')`):

```dart
  group('goInPlace', () {
    GoRouter build(String initial) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/root', builder: (_, _) => const Text('ROOT')),
        GoRoute(
          path: '/list',
          builder: (_, state) => Builder(
            builder: (inner) => Column(
              children: [
                Text('AT ${state.uri}'),
                TextButton(
                  onPressed: () => inner.goInPlace('/list?selected=d1'),
                  child: const Text('Select'),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    testWidgets('on a pushed page it replaces and keeps the page below',
        (tester) async {
      final router = build('/root');
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.push('/list');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(find.text('AT /list?selected=d1'), findsOneWidget);
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('ROOT'), findsOneWidget);
    });

    testWidgets('on a root page it goes', (tester) async {
      final router = build('/list');
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      expect(find.text('AT /list?selected=d1'), findsOneWidget);
      expect(router.canPop(), isFalse);
    });
  });
```

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/core/router/pushed_route_test.dart test/core/router/section_navigation_test.dart`
Expected: FAIL, `pushed_route.dart` and `goInPlace` not found.

- [ ] **Step 3: Implement** `lib/core/router/pushed_route.dart`:

```dart
import 'package:flutter/widgets.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Whether the page holding [context] has a page under it to go back to.
///
/// Page-local on purpose: the router as a whole can pop whenever anything
/// on the stack can, which says nothing about this page.
bool isPushedRoute(BuildContext context) =>
    ModalRoute.of(context)?.canPop ?? false;

/// Whether a standalone detail page should move itself into its section's
/// master-detail split (`/<section>?selected=<id>`).
///
/// Only a root page does: a deep link or a sidebar visit. A page pushed from
/// somewhere else (a dive's linked gear, a buddy's shared dive) stays put, or
/// the redirect's `go` would erase the page it came from and its back arrow
/// with it (#764, #3292). Embedded pages, phone widths and table mode (which
/// has no split to move into) never redirect.
bool shouldRedirectToMasterDetail(
  BuildContext context, {
  required bool embedded,
  required ListViewMode viewMode,
}) =>
    !embedded &&
    !isPushedRoute(context) &&
    ResponsiveBreakpoints.isMasterDetail(context) &&
    viewMode != ListViewMode.table;
```

Add to the `SectionNavigation` extension in `section_navigation.dart` (import `pushed_route.dart`):

```dart
  /// Change this page's own URL (selection, mode, view) without discarding
  /// the pages under it.
  ///
  /// On a pushed page this replaces the top page, keeping its page key and
  /// widget state; on a root page it is a plain `go`, as before (#3292).
  void goInPlace(String location) {
    if (isPushedRoute(this)) {
      GoRouter.of(this).replace<void>(location);
    } else {
      GoRouter.of(this).go(location);
    }
  }
```

- [ ] **Step 4: Run to verify they pass** (same command). Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/router/pushed_route.dart lib/core/router/section_navigation.dart test/core/router/pushed_route_test.dart test/core/router/section_navigation_test.dart
git commit -m "feat(navigation): router helpers for pushed pages"
```

### Task 2: Detail pages keep their back arrow

**Files:**
- Modify: the redirect block in each of
  `lib/features/equipment/presentation/pages/equipment_detail_page.dart`,
  `lib/features/buddies/presentation/pages/buddy_detail_page.dart`,
  `lib/features/trips/presentation/pages/trip_detail_page.dart`,
  `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart`,
  `lib/features/certifications/presentation/pages/certification_detail_page.dart`,
  `lib/features/dive_sites/presentation/pages/site_detail_page.dart`,
  `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Test: `test/core/router/linked_detail_pages_stay_pushed_test.dart`

**Interfaces:**
- Consumes: `shouldRedirectToMasterDetail` (Task 1).

- [ ] **Step 1: Write the failing test.** One table-driven file. Each case pumps the real page through a `/root` + `/item` router at desktop width, with the page's entity provider overridden to a never-completing future (the page stays in its loading state; the redirect decision is made before data arrives), plus `getBaseOverrides()` from `test/helpers/mock_providers.dart`. The router also has the section route (`/equipment` etc.) rendering `Text('SECTION')` and recording its location.

```dart
class _Case {
  final String name;
  final String section; // '/equipment'
  final Widget Function(String id) page;
  final Override Function(String id) loading;
  const _Case(this.name, this.section, this.page, this.loading);
}

final _cases = <_Case>[
  _Case('equipment', '/equipment',
      (id) => EquipmentDetailPage(equipmentId: id),
      (id) => equipmentItemProvider(id).overrideWith((ref) => Completer<EquipmentItem?>().future)),
  _Case('buddy', '/buddies',
      (id) => BuddyDetailPage(buddyId: id),
      (id) => buddyByIdProvider(id).overrideWith((ref) => Completer<Buddy?>().future)),
  _Case('trip', '/trips',
      (id) => TripDetailPage(tripId: id),
      (id) => tripWithStatsProvider(id).overrideWith((ref) => Completer<TripWithStats>().future)),
  _Case('dive center', '/dive-centers',
      (id) => DiveCenterDetailPage(centerId: id),
      (id) => diveCenterByIdProvider(id).overrideWith((ref) => Completer<DiveCenter?>().future)),
  _Case('certification', '/certifications',
      (id) => CertificationDetailPage(certificationId: id),
      (id) => certificationByIdProvider(id).overrideWith((ref) => Completer<Certification?>().future)),
];
```

Provider value types: `EquipmentItem?`, `Buddy?`, `TripWithStats` (non-nullable), `DiveCenter?`, `Certification?`; all are `FutureProvider.family<_, String>`. For every case, two tests:

```dart
    testWidgets('${c.name}: pushed at desktop width stays on the stack',
        (tester) async {
      final locations = <String>[];
      final router = await pumpCase(tester, c, initial: '/root', locations: locations);
      final pushed = router.push('/item');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(locations, isNot(contains(startsWith('${c.section}?selected='))));
      expect(router.canPop(), isTrue);
      router.pop();
      await tester.pump();
      await pushed;
      expect(find.text('ROOT'), findsOneWidget);
    });

    testWidgets('${c.name}: root at desktop width still redirects',
        (tester) async {
      final locations = <String>[];
      await pumpCase(tester, c, initial: '/item', locations: locations);
      expect(locations.last, '${c.section}?selected=x1');
    });
```

`pumpCase` follows `test/features/dive_log/presentation/pages/dive_detail_pushed_context_test.dart`: `ProviderScope(overrides: [...await getBaseOverrides(), c.loading('x1')])`, `MediaQuery(size: 1200x800)`, `MaterialApp.router` with `AppLocalizations` delegates, the `FlutterError.onError` overflow filter restored in `addTearDown`, then `pump()` and `pump(1s)`. If a page needs an extra provider in the loading state, add its override to that case only.

- [ ] **Step 2: Run to verify the pushed cases fail**

Run: `flutter test test/core/router/linked_detail_pages_stay_pushed_test.dart`
Expected: the five "pushed ... stays on the stack" tests FAIL (location `/equipment?selected=x1` recorded); the five root tests PASS.

- [ ] **Step 3: Replace each page's redirect condition.** In all seven pages, the block

```dart
    if (!widget.embedded &&
        !_hasRedirected &&
        ResponsiveBreakpoints.isMasterDetail(context)) {
      final viewMode = ref.read(<section>ListViewModeProvider);
      if (viewMode != ListViewMode.table) {
        _hasRedirected = true;
        WidgetsBinding.instance.addPostFrameCallback((_) { ... context.go(...) ... });
      }
    }
```

(site adds `!Navigator.of(context).canPop() &&`; dive detail adds `!(GoRouter.maybeOf(context)?.canPop() ?? false) &&`) becomes

```dart
    if (!_hasRedirected &&
        shouldRedirectToMasterDetail(
          context,
          embedded: widget.embedded,
          viewMode: ref.read(<section>ListViewModeProvider),
        )) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) { ... unchanged ... });
    }
```

Keep each page's existing comment, reworded to say a pushed page stays put (dive detail keeps its `#764` reference). Drop imports that become unused (`ResponsiveBreakpoints`, `ListViewMode`) only where `flutter analyze` reports them.

- [ ] **Step 4: Run the new test and the existing ones**

Run: `flutter test test/core/router/linked_detail_pages_stay_pushed_test.dart test/features/dive_log/presentation/pages/dive_detail_pushed_context_test.dart test/features/dive_sites test/features/equipment/presentation/pages test/features/buddies/presentation/pages test/features/trips/presentation/pages test/features/dive_centers/presentation/pages test/features/certifications/presentation/pages`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/{equipment,buddies,trips,dive_centers,certifications,dive_sites,dive_log}/presentation/pages/*_detail_page.dart test/core/router/linked_detail_pages_stay_pushed_test.dart
git commit -m "fix(navigation): keep pushed detail pages on the stack on desktop"
```

### Task 3: In-page URL changes keep the stack

**Files:**
- Modify: `lib/shared/widgets/master_detail/master_detail_scaffold.dart:229-303`
- Modify: `lib/shared/widgets/table_mode_layout/table_mode_layout.dart:286-296`
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart` lines 103, 125-145, 196-210, 380-408
- Modify: `lib/features/dive_log/presentation/widgets/dive_summary_widget.dart:464,489`
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart:2249`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart:280,1507,1795`
- Test: `test/shared/widgets/master_detail/master_detail_scaffold_pushed_test.dart`

**Interfaces:**
- Consumes: `goInPlace`, `isPushedRoute` (Task 1).

- [ ] **Step 1: Write the failing test.** Router: `/root` (Text) and `/list` building a `MasterDetailScaffold` (`sectionId: 'list'`, `masterBuilder` rendering two buttons `Pick a` / `Pick b` that call the `onItemSelected` callback, `detailBuilder` rendering `Text('DETAIL $id')`, `summaryBuilder` rendering `Text('SUMMARY')`), inside a `ProviderScope` at 1200x800. Look at `test/shared/widgets/master_detail/` for the existing harness and reuse its required constructor arguments.

```dart
  testWidgets('selection on a pushed master-detail page keeps the stack',
      (tester) async {
    final router = await pumpHarness(tester, initial: '/root');
    router.push('/list');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pick a'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL a'), findsOneWidget);
    expect(router.canPop(), isTrue, reason: 'selection must not go()');
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('ROOT'), findsOneWidget);
  });

  testWidgets('selection on a root master-detail page still goes',
      (tester) async {
    final router = await pumpHarness(tester, initial: '/list');
    await tester.tap(find.text('Pick a'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL a'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });
```

- [ ] **Step 2: Run to verify the pushed test fails**

Run: `flutter test test/shared/widgets/master_detail/master_detail_scaffold_pushed_test.dart`
Expected: pushed test FAILS on `canPop`.

- [ ] **Step 3: Implement.**
  - `MasterDetailScaffold`: in `_onItemSelected` (desktop branch), `_onCreate` (desktop branch), `_onSaved`, `_onCancel`, replace `router.go(x)` with `context.goInPlace(x)`. In the two phone branches (`_onItemSelected` and `_onCreate` falling back to a full page), use `isPushedRoute(context) ? router.push(route) : router.go(route)` so a pushed list opens its detail on top rather than erasing itself.
  - `TableModeLayout._openHighlightedInPane`: `context.goInPlace(...)` instead of `router.go(...)` (keep the early returns; `router` is still needed for `router.state.uri`).
  - `DiveListPage`: `_showAddDiveSheet` desktop branch, `_toggleMapView` (all four), table-mode and split-mode `onCloseEmbeddedSite` and `onDeleted`, and the split-mode map `onDetailsTap`: `context.goInPlace(...)`.
  - `DiveSummaryWidget` lines 464 and 489, `DiveListContent` line 2249: `context.goInPlace(...)`.
  - `DiveDetailPage`: `_navigateToDive` embedded branch (line 280), the embedded edit button (line 1507), the embedded site tap (line 1795): `context.goInPlace(...)`.
  - Leave `dive_summary_widget.dart` `go('/dive-computers')` and `go('/insights')`, `dive_search_header.dart`, and `main_scaffold.dart` as `go`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/shared/widgets/master_detail test/shared/widgets/table_mode_layout test/features/dive_log/presentation`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/master_detail/master_detail_scaffold.dart lib/shared/widgets/table_mode_layout/table_mode_layout.dart lib/features/dive_log/presentation/pages/dive_list_page.dart lib/features/dive_log/presentation/widgets/dive_summary_widget.dart lib/features/dive_log/presentation/widgets/dive_list_content.dart lib/features/dive_log/presentation/pages/dive_detail_page.dart test/shared/widgets/master_detail/master_detail_scaffold_pushed_test.dart
git commit -m "feat(navigation): in-page URL changes keep a pushed page's stack"
```

### Task 4: Pushed dive list: back arrow and restore

**Files:**
- Create: `lib/features/dive_log/presentation/navigation/open_dive_list.dart` (the `DiveListReturn` class only in this task)
- Modify: `lib/core/router/app_router.dart` (`/dives` route)
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (`_buildCompactAppBar`)
- Test: `test/features/dive_log/presentation/pages/dive_list_pushed_test.dart`

**Interfaces:**
- Produces: `class DiveListReturn { const DiveListReturn({required this.filter, required this.highlightedDiveId}); final DiveFilterState filter; final String? highlightedDiveId; }`;
  `DiveListPage({super.key, this.returnTo})` with `final DiveListReturn? returnTo;`

- [ ] **Step 1: Write the failing tests.** Router: `/root` (Text `ROOT`) and `/dives` building `DiveListPage(returnTo: state.extra as DiveListReturn?)`, real providers from `getBaseOverrides()` with `diveFilterProvider` and `highlightedDiveIdProvider` left as the real `StateProvider`s. Read their state through `ProviderScope.containerOf(tester.element(find.text('ROOT')))` style access, or keep a `ProviderContainer` from `UncontrolledProviderScope`.

```dart
  testWidgets('pushed list shows a back arrow that pops and restores',
      (tester) async {
    final h = await pumpHarness(tester, size: desktop, initial: '/root');
    h.container.read(diveFilterProvider.notifier).state =
        const DiveFilterState(siteId: 'mine');
    h.container.read(highlightedDiveIdProvider.notifier).state = 'orig';
    const ret = DiveListReturn(
      filter: DiveFilterState(siteId: 'mine'),
      highlightedDiveId: 'orig',
    );
    h.container.read(diveFilterProvider.notifier).state =
        const DiveFilterState(siteId: 'other');
    h.router.push('/dives', extra: ret);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BackButton), findsOneWidget);

    h.container.read(highlightedDiveIdProvider.notifier).state = 'picked';
    h.router.replace('/dives?selected=picked'); // a selection, as goInPlace does
    await tester.pump();

    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ROOT'), findsOneWidget);
    expect(h.container.read(diveFilterProvider).siteId, 'mine');
    expect(h.container.read(highlightedDiveIdProvider), 'orig');
  });

  testWidgets('top-level list has no back arrow and restores nothing',
      (tester) async {
    final h = await pumpHarness(tester, size: desktop, initial: '/dives');
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('removed by go, the previous filter is still restored',
      (tester) async {
    final h = await pumpHarness(tester, size: desktop, initial: '/root');
    h.router.push(
      '/dives',
      extra: const DiveListReturn(
        filter: DiveFilterState(siteId: 'mine'),
        highlightedDiveId: null,
      ),
    );
    await tester.pump();
    h.container.read(diveFilterProvider.notifier).state =
        const DiveFilterState(siteId: 'other');
    h.router.go('/root');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ROOT'), findsOneWidget);
    expect(h.container.read(diveFilterProvider).siteId, 'mine');
  });

  testWidgets('nested pushed lists unwind in order', (tester) async {
    final h = await pumpHarness(tester, size: desktop, initial: '/root');
    h.router.push('/dives',
        extra: const DiveListReturn(
            filter: DiveFilterState(siteId: 'a'), highlightedDiveId: null));
    await tester.pump();
    h.container.read(diveFilterProvider.notifier).state =
        const DiveFilterState(siteId: 'b');
    h.router.push('/dives',
        extra: const DiveListReturn(
            filter: DiveFilterState(siteId: 'b'), highlightedDiveId: null));
    await tester.pump();
    h.container.read(diveFilterProvider.notifier).state =
        const DiveFilterState(siteId: 'c');
    h.router.pop();
    await tester.pump();
    expect(h.container.read(diveFilterProvider).siteId, 'b');
    h.router.pop();
    await tester.pump();
    expect(h.container.read(diveFilterProvider).siteId, 'a');
  });

  testWidgets('phone width: app bar back arrow pops and restores',
      (tester) async {
    final h = await pumpHarness(tester, size: const Size(400, 800),
        initial: '/root');
    h.router.push('/dives',
        extra: const DiveListReturn(
            filter: DiveFilterState(siteId: 'mine'), highlightedDiveId: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    h.container.read(diveFilterProvider.notifier).state =
        const DiveFilterState(siteId: 'other');
    await tester.tap(find.byType(BackButton));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('ROOT'), findsOneWidget);
    expect(h.container.read(diveFilterProvider).siteId, 'mine');
  });

`pumpHarness` returns a record `({GoRouter router, ProviderContainer container})`: create `ProviderContainer(overrides: await getBaseOverrides())`, `addTearDown(container.dispose)`, and wrap the app in `UncontrolledProviderScope(container: container, ...)` with `MediaQuery(size)`, `MaterialApp.router` and the `AppLocalizations` delegates. The second test's `h` is unused apart from the pump; name it `_`.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_log/presentation/pages/dive_list_pushed_test.dart`
Expected: FAIL to compile (`DiveListReturn`, `returnTo` missing).

- [ ] **Step 3: Implement.**

`open_dive_list.dart`:

```dart
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// What a pushed dive list puts back when it goes away: the dive-list
/// filter and highlighted dive that were in place before it opened.
///
/// Carried as the `/dives` route's `extra`. The highlight matters as much as
/// the filter: it is global, and a table-mode list under the pushed one
/// replays it into its own URL once uncovered (#3292).
class DiveListReturn {
  const DiveListReturn({required this.filter, required this.highlightedDiveId});

  final DiveFilterState filter;
  final String? highlightedDiveId;
}
```

`app_router.dart` `/dives` route:

```dart
            pageBuilder: (context, state) => NoTransitionPage(
              key: state.pageKey,
              child: DiveListPage(
                returnTo: state.extra is DiveListReturn
                    ? state.extra! as DiveListReturn
                    : null,
              ),
            ),
```

`DiveListPage`:
- add `final DiveListReturn? returnTo;` and `const DiveListPage({super.key, this.returnTo});`
- in the State: `DiveListReturn? _returnTo; StateController<DiveFilterState>? _filter; StateController<String?>? _highlight; bool _restored = false;`. In `initState` capture `_returnTo = widget.returnTo` (a later `replace` rebuilds the widget without `extra`; the State keeps the first value) and, when non-null, `_filter = ref.read(diveFilterProvider.notifier); _highlight = ref.read(highlightedDiveIdProvider.notifier);`.
- `void _restore() { if (_restored || _returnTo == null) return; _restored = true; if (_filter!.mounted) _filter!.state = _returnTo!.filter; if (_highlight!.mounted) _highlight!.state = _returnTo!.highlightedDiveId; }`
- wrap the page's returned widget(s) once, in `build`, with `PopScope(canPop: true, onPopInvokedWithResult: (didPop, _) { if (didPop) _restore(); }, child: ...)` when `_returnTo != null`. Restoring at pop time runs before the uncovered page rebuilds and replays its highlight.
- `dispose`: `if (_returnTo != null && !_restored) scheduleMicrotask(_restore);` then `super.dispose()`. This is the path when a sidebar `go` replaces the stack; the microtask keeps provider writes out of tree finalisation.
- phone map view leading (`onPressed: () => context.go('/dives')`, ~line 477): `onPressed: () => isPushedRoute(context) ? context.pop() : context.go('/dives')`.

`DiveListContent._buildCompactAppBar`: first child of the `Row`, replacing the leading `SizedBox(width: 8)` when pushed:

```dart
              if (isPushedRoute(context))
                const BackButton()
              else
                const SizedBox(width: 8),
```

The phone `AppBar` (`_buildAppBar`) and both `TableModeLayout` app bars imply a `BackButton` on their own when the route can pop; the tests confirm it rather than adding one.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/presentation/pages/dive_list_pushed_test.dart test/features/dive_log/presentation test/core/router`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/navigation/open_dive_list.dart lib/core/router/app_router.dart lib/features/dive_log/presentation/pages/dive_list_page.dart lib/features/dive_log/presentation/widgets/dive_list_content.dart test/features/dive_log/presentation/pages/dive_list_pushed_test.dart
git commit -m "feat(dive-log): pushed dive list shows a back arrow and restores the filter"
```

### Task 5: `openDiveList` and the call sites

**Files:**
- Modify: `lib/features/dive_log/presentation/navigation/open_dive_list.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart:1323-1328`
- Modify: `lib/features/equipment/presentation/pages/equipment_detail_page.dart:582-585`
- Modify: `lib/features/equipment/presentation/widgets/equipment_history_card.dart:~58-61`
- Modify: `lib/features/buddies/presentation/widgets/buddy_shared_dives_section.dart:50-54`
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart:~825-829`
- Modify: `lib/features/dive_computer/presentation/pages/device_detail_page.dart:614-618`
- Modify: `lib/features/trips/presentation/pages/trip_detail_page.dart:161-165,226-230`
- Modify: `lib/features/tags/presentation/tag_dives_navigation.dart`
- Modify: `lib/features/insights/presentation/insights_place_dives.dart:36-45`
- Modify: `lib/features/connections/presentation/widgets/details/selection_actions.dart:66-70`
- Create: `test/architecture/dive_filter_navigation_single_source_test.dart`
- Test: `test/features/dive_log/presentation/navigation/open_dive_list_test.dart`

**Interfaces:**
- Consumes: `DiveListReturn`, `DiveListPage.returnTo` (Task 4).
- Produces: `void openDiveList(BuildContext context, WidgetRef ref, DiveFilterState filter, {bool map = false})`

- [ ] **Step 1: Write the failing tests.**

`open_dive_list_test.dart`: router with `/root` (a `Consumer` button calling `openDiveList(context, ref, const DiveFilterState(siteId: 's1'))`, and a second button with `map: true`) and `/dives` (records `state.uri` and `state.extra`, renders `Text('LIST')`).

```dart
  testWidgets('pushes the dive list with the new filter and a return '
      'snapshot', (tester) async {
    final h = await pumpHarness(tester);
    h.container.read(diveFilterProvider.notifier).state =
        const DiveFilterState(buddyId: 'b0');
    h.container.read(highlightedDiveIdProvider.notifier).state = 'd0';
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('LIST'), findsOneWidget);
    expect(h.router.canPop(), isTrue);
    expect(h.container.read(diveFilterProvider).siteId, 's1');
    final ret = h.extras.last as DiveListReturn;
    expect(ret.filter.buddyId, 'b0');
    expect(ret.highlightedDiveId, 'd0');
  });

  testWidgets('map: true pushes the map view', (tester) async {
    final h = await pumpHarness(tester);
    await tester.tap(find.text('Open map'));
    await tester.pumpAndSettle();
    expect(h.locations.last, '/dives?view=map');
  });
```

`dive_filter_navigation_single_source_test.dart`, modelled on `test/architecture/number_parsing_single_source_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// "Show these dives" goes through `openDiveList`, which pushes the dive
/// list so the diver can come back (#2784, #3292). Writing the global dive
/// filter and then `go('/dives')` erases the page the link was on.
void main() {
  const allowed = <String, String>{
    'lib/features/dive_log/presentation/navigation/open_dive_list.dart':
        'defines openDiveList',
    'lib/features/import_wizard/presentation/pages/unified_import_wizard.dart':
        'ends a flow; there is nothing to return to',
  };
  final write = RegExp(r'diveFilterProvider\.notifier');

  test('only openDiveList writes the dive filter from outside the dive list',
      () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path.startsWith('lib/features/dive_log/')) continue;
      if (allowed.containsKey(path)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].trimLeft().startsWith('//')) continue;
        if (write.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'open the dive list with openDiveList (lib/features/dive_log/'
            'presentation/navigation/open_dive_list.dart) so it is pushed '
            'with a back arrow and the previous filter comes back');
  });

  test('every allowlisted file exists and still writes the filter', () {
    for (final entry in allowed.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} is missing');
      expect(write.hasMatch(file.readAsStringSync()), isTrue,
          reason: '${entry.key} is allowlisted as "${entry.value}" but no '
              'longer writes the filter; remove it from the allowlist');
    }
  });
}
```

Before relying on the `lib/features/dive_log/` exemption, grep that folder for `diveFilterProvider.notifier` writes followed by `go('/dives')` and move any browse-style ones (not the dive list's own filter UI) to `openDiveList` too.

- [ ] **Step 2: Run to verify they fail**

Run: `flutter test test/features/dive_log/presentation/navigation/open_dive_list_test.dart test/architecture/dive_filter_navigation_single_source_test.dart`
Expected: the first FAILS to compile (`openDiveList` missing); the guard FAILS listing the ten call-site files.

- [ ] **Step 3: Implement.** Add to `open_dive_list.dart`:

```dart
/// Shows the dives matching [filter] on a dive list pushed over the current
/// page, so its back arrow returns here (#2784, #3292).
///
/// The filter is replaced rather than merged: a leftover date, depth or site
/// filter would hide some of the dives the link promised. The filter and
/// highlight in place before are handed to the pushed list, which puts them
/// back when it goes away. [map] opens the list's map view.
void openDiveList(
  BuildContext context,
  WidgetRef ref,
  DiveFilterState filter, {
  bool map = false,
}) {
  final ret = DiveListReturn(
    filter: ref.read(diveFilterProvider),
    highlightedDiveId: ref.read(highlightedDiveIdProvider),
  );
  ref.read(diveFilterProvider.notifier).state = filter;
  context.push(map ? '/dives?view=map' : '/dives', extra: ret);
}
```

Then each call site: replace `ref.read(diveFilterProvider.notifier).state = X; context.go('/dives');` with `openDiveList(context, ref, X);` (trip: `openDiveList(context, ref, DiveFilterState(tripId: trip.id), map: true);`). `openDivesWithTag` and `openInsightsDives` keep their names and doc comments (updated to say the list is pushed) and call `openDiveList`. Remove the `// go, not push: the dive list is a shell tab.` comment. Remove imports that become unused.

- [ ] **Step 4: Run tests**

Run: `flutter test test/features/dive_log/presentation/navigation test/architecture test/features/tags test/features/insights test/features/connections test/features/dive_sites test/features/equipment test/features/buddies test/features/dive_centers test/features/dive_computer test/features/trips`
Expected: PASS. Existing tests that asserted `go('/dives')` (a recorded location of `/dives` with `canPop` false) now see a push; update those assertions to the pushed behaviour.

- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/navigation/open_dive_list.dart lib/features/dive_sites lib/features/equipment lib/features/buddies lib/features/dive_centers lib/features/dive_computer lib/features/trips lib/features/tags lib/features/insights lib/features/connections test/features/dive_log/presentation/navigation test/architecture/dive_filter_navigation_single_source_test.dart
git commit -m "feat(navigation): show-dives links push the dive list with a way back"
```

(Stage explicit paths; check `git show --stat HEAD` for strays.)

### Task 6: Verification

- [ ] `dart format .`
- [ ] `flutter analyze` (expect no issues)
- [ ] `flutter test test/architecture test/shared test/core/router test/features/dive_log test/features/dive_sites test/features/equipment test/features/buddies test/features/trips test/features/dive_centers test/features/certifications test/features/dive_computer test/features/tags test/features/insights test/features/connections`
- [ ] After screenshots on the macOS debug app (desktop and phone width): dive details, then equipment, shows a back arrow; site, then "View all dives", shows a back arrow; back returns to the dive and the filter is the original one.
- [ ] Commit any formatting changes as `chore: format`.
