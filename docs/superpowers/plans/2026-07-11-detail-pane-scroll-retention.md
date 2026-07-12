# Detail Pane Scroll Retention Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the wide-screen master-detail detail pane scrolled to the same place when the user selects a different item, so they can compare a section across dives/sites/etc. without re-scrolling.

**Architecture:** Flutter `Scrollable` auto-saves/restores its offset to the nearest ancestor `PageStorageBucket` when it carries a `PageStorageKey`. Every routed page already provides a bucket, and the per-id `ValueKey('detail_$id')` on the detail pane is *not* a `PageStorageKey`, so all items of a section share one storage slot. The entire fix is therefore adding a stable `PageStorageKey` to each in-scope detail page's scroll view (verified by spike, 2026-07-11 — no scaffold bucket needed).

**Tech Stack:** Flutter (Material 3), Riverpod, go_router, `flutter_test`.

## Global Constraints

- All Dart must pass `dart format .` with no changes (run it before every commit).
- All Dart must pass `flutter analyze` with no new issues.
- No emojis in code/comments. Immutability; small focused changes.
- Do NOT add a scaffold-owned `PageStorageBucket` — the spike proved it redundant. The change is keys-only plus one comment.
- `PageStorageKey` strings must be unique per page (values below), so sections never collide even under a shared bucket.
- `PageStorageKey` and `PageStorage` are exported by `package:flutter/material.dart`, already imported in every target file — no new imports.
- Worktree hygiene (from project memory): never `git add -A` here (it can record a stale submodule gitlink); `git add` explicit paths only. The pre-push hook runs against the main tree — if pushing, use `--no-verify`. Do not push unless asked.

---

### Task 1: Retention contract test + scaffold breadcrumb comment

Locks in the retention behavior at the scaffold level using a dummy detail builder (no real pages / DB), and drops a comment so future maintainers know the `ValueKey` deliberately does not defeat `PageStorage`.

**Files:**
- Create: `test/shared/widgets/master_detail/master_detail_scaffold_scroll_test.dart`
- Modify: `lib/shared/widgets/master_detail/master_detail_scaffold.dart` (comment only, near the `ValueKey('detail_$selectedId')` at ~line 452)

**Interfaces:**
- Consumes: `MasterDetailScaffold` public API (`sectionId`, `masterBuilder`, `detailBuilder`, `summaryBuilder`).
- Produces: nothing consumed by later tasks. This test is the regression guard for the mechanism all later tasks rely on.

> **Note on TDD color:** The mechanism already works in the test harness via the ambient route bucket (proven by spike), so this test passes as soon as it is written — it is a *characterization / contract* test, not a red→green driver. That is expected and correct; its job is to fail if someone later breaks retention (e.g. introduces a `PageStorage` boundary or makes the detail `ValueKey` a `PageStorageKey`). Do not contrive an artificial failure.

- [ ] **Step 1: Write the contract test**

Create `test/shared/widgets/master_detail/master_detail_scaffold_scroll_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';

/// Builds a [MasterDetailScaffold] inside a router at desktop width (>=800) so
/// the split layout renders. The master pane exposes two buttons that call
/// [onItemSelected] to drive selection changes via query params.
///
/// [detailHeight] returns the content height for a given item id, so tests can
/// make item 2 shorter than item 1 to exercise clamping. When [tagKey] is
/// false the detail scroll view carries no [PageStorageKey] (opt-out case).
Widget _app({
  required double Function(String id) detailHeight,
  bool tagKey = true,
}) {
  final router = GoRouter(
    initialLocation: '/test?selected=1',
    routes: [
      GoRoute(
        path: '/test',
        builder: (context, state) => MediaQuery(
          data: const MediaQueryData(size: Size(1200, 800)),
          child: MasterDetailScaffold(
            sectionId: 'test',
            masterBuilder: (context, onSelect, selectedId) => Column(
              children: [
                TextButton(
                  onPressed: () => onSelect('1'),
                  child: const Text('select-1'),
                ),
                TextButton(
                  onPressed: () => onSelect('2'),
                  child: const Text('select-2'),
                ),
              ],
            ),
            detailBuilder: (_, id) => SingleChildScrollView(
              key: tagKey ? const PageStorageKey('testDetailScroll') : null,
              child: SizedBox(
                height: detailHeight(id),
                child: Text('Detail $id'),
              ),
            ),
            summaryBuilder: (_) => const Text('Summary'),
          ),
        ),
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

/// The (single, post-settle) detail scroll view's scroll state.
ScrollableState _detailScrollable(WidgetTester tester) {
  return tester.state<ScrollableState>(
    find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    ),
  );
}

void main() {
  group('MasterDetailScaffold detail scroll retention', () {
    testWidgets('retains offset when switching to another item', (tester) async {
      await tester.pumpWidget(_app(detailHeight: (_) => 3000));
      await tester.pumpAndSettle();

      _detailScrollable(tester).position.jumpTo(800);
      await tester.pump();
      expect(_detailScrollable(tester).position.pixels, 800);

      await tester.tap(find.text('select-2'));
      await tester.pumpAndSettle();

      expect(find.text('Detail 2'), findsOneWidget);
      expect(_detailScrollable(tester).position.pixels, 800);
    });

    testWidgets('clamps retained offset to the new item extent', (tester) async {
      // Item 1 is tall (scrollable); item 2 is only slightly taller than the
      // ~800px viewport, so its maxScrollExtent is small and 800 must clamp.
      await tester.pumpWidget(
        _app(detailHeight: (id) => id == '2' ? 900 : 3000),
      );
      await tester.pumpAndSettle();

      _detailScrollable(tester).position.jumpTo(800);
      await tester.pump();

      await tester.tap(find.text('select-2'));
      await tester.pumpAndSettle();

      final position = _detailScrollable(tester).position;
      expect(position.pixels, position.maxScrollExtent);
      expect(position.pixels, lessThan(800));
    });

    testWidgets('without a PageStorageKey the offset resets to top',
        (tester) async {
      await tester.pumpWidget(_app(detailHeight: (_) => 3000, tagKey: false));
      await tester.pumpAndSettle();

      _detailScrollable(tester).position.jumpTo(800);
      await tester.pump();

      await tester.tap(find.text('select-2'));
      await tester.pumpAndSettle();

      expect(_detailScrollable(tester).position.pixels, 0);
    });
  });
}
```

- [ ] **Step 2: Run the test**

Run: `flutter test test/shared/widgets/master_detail/master_detail_scaffold_scroll_test.dart`
Expected: PASS (3 tests). This confirms the mechanism the page tasks depend on. If the first two FAIL, stop — the environment differs from the spike and later tasks would be built on a false premise.

- [ ] **Step 3: Add the breadcrumb comment in the scaffold**

In `lib/shared/widgets/master_detail/master_detail_scaffold.dart`, find the view-mode branch in `_DetailPane._buildContent`:

```dart
    // View mode with selected item
    if (selectedId != null) {
      return KeyedSubtree(
        key: ValueKey('detail_$selectedId'),
        child: detailBuilder(context, selectedId!),
      );
    }
```

Replace it with (comment added; behavior unchanged):

```dart
    // View mode with selected item.
    //
    // This ValueKey deliberately rebuilds the detail subtree per item so each
    // item gets fresh local state. It is NOT a PageStorageKey, so it does not
    // participate in PageStorage's storage path: a detail page whose scroll
    // view carries a stable PageStorageKey therefore retains its scroll offset
    // across selections (compare a section across items without re-scrolling).
    // See docs/superpowers/specs/2026-07-11-detail-pane-scroll-retention-design.md.
    if (selectedId != null) {
      return KeyedSubtree(
        key: ValueKey('detail_$selectedId'),
        child: detailBuilder(context, selectedId!),
      );
    }
```

- [ ] **Step 4: Format, analyze, re-run the test**

Run:
```bash
dart format lib/shared/widgets/master_detail/master_detail_scaffold.dart test/shared/widgets/master_detail/master_detail_scaffold_scroll_test.dart
flutter analyze lib/shared/widgets/master_detail/master_detail_scaffold.dart test/shared/widgets/master_detail/master_detail_scaffold_scroll_test.dart
flutter test test/shared/widgets/master_detail/master_detail_scaffold_scroll_test.dart
```
Expected: format makes no changes (or reformats cleanly), analyze reports no issues, test PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/master_detail/master_detail_scaffold.dart test/shared/widgets/master_detail/master_detail_scaffold_scroll_test.dart
git commit -m "test(master-detail): lock in detail-pane scroll retention contract"
```

---

### Task 2: Add PageStorageKeys to the seven single-scroll detail pages

Each of these pages builds `final body = SingleChildScrollView(...)`. Add a unique `PageStorageKey` as the first argument. This is the load-bearing change for dives, sites, courses, certifications, dive centers, equipment, and buddies.

**Files (all Modify):**
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (~line 449)
- `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (~line 145)
- `lib/features/courses/presentation/pages/course_detail_page.dart` (~line 53)
- `lib/features/certifications/presentation/pages/certification_detail_page.dart` (~line 120)
- `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart` (~line 94)
- `lib/features/equipment/presentation/pages/equipment_detail_page.dart` (~line 129)
- `lib/features/buddies/presentation/pages/buddy_detail_page.dart` (~line 119)

**Interfaces:**
- Consumes: the retention mechanism validated in Task 1.
- Produces: user-visible scroll retention for these seven sections. Key strings: `diveDetailScroll`, `siteDetailScroll`, `courseDetailScroll`, `certificationDetailScroll`, `diveCenterDetailScroll`, `equipmentDetailScroll`, `buddyDetailScroll`.

- [ ] **Step 1: Edit the six `padding`-first pages**

For each file below, the current opening (4-space `final body`, 6-space first arg) is:

```dart
    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
```

Change it to insert the key line (exact key per file):

```dart
    final body = SingleChildScrollView(
      key: const PageStorageKey('<KEY>'),
      padding: const EdgeInsets.all(16),
```

Apply with these `<KEY>` values:
- `dive_detail_page.dart` -> `diveDetailScroll`
- `site_detail_page.dart` -> `siteDetailScroll`
- `course_detail_page.dart` -> `courseDetailScroll`
- `certification_detail_page.dart` -> `certificationDetailScroll`
- `equipment_detail_page.dart` -> `equipmentDetailScroll`
- `buddy_detail_page.dart` -> `buddyDetailScroll`

- [ ] **Step 2: Edit the dive-center page (deeper indent, `child`-first)**

In `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart`, the current opening (8-space `final body`, 10-space first arg) is:

```dart
        final body = SingleChildScrollView(
          child: Column(
```

Change it to:

```dart
        final body = SingleChildScrollView(
          key: const PageStorageKey('diveCenterDetailScroll'),
          child: Column(
```

- [ ] **Step 3: Format and analyze all seven files**

Run:
```bash
dart format \
  lib/features/dive_log/presentation/pages/dive_detail_page.dart \
  lib/features/dive_sites/presentation/pages/site_detail_page.dart \
  lib/features/courses/presentation/pages/course_detail_page.dart \
  lib/features/certifications/presentation/pages/certification_detail_page.dart \
  lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart \
  lib/features/equipment/presentation/pages/equipment_detail_page.dart \
  lib/features/buddies/presentation/pages/buddy_detail_page.dart
flutter analyze \
  lib/features/dive_log/presentation/pages/dive_detail_page.dart \
  lib/features/dive_sites/presentation/pages/site_detail_page.dart \
  lib/features/courses/presentation/pages/course_detail_page.dart \
  lib/features/certifications/presentation/pages/certification_detail_page.dart \
  lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart \
  lib/features/equipment/presentation/pages/equipment_detail_page.dart \
  lib/features/buddies/presentation/pages/buddy_detail_page.dart
```
Expected: no formatting changes needed, analyze reports no issues.

- [ ] **Step 4: Sanity-run existing detail-page tests (regression guard)**

Run any existing tests for these pages so the key additions don't break current expectations:
```bash
flutter test test/features/dive_log test/features/dive_sites test/features/courses test/features/certifications test/features/dive_centers test/features/equipment test/features/buddies 2>&1 | tail -20
```
Expected: all pass (or the same pass/skip set as before your change — if a suite was already failing on `main`, note it and continue; do not fix unrelated pre-existing failures here).

- [ ] **Step 5: Commit**

```bash
git add \
  lib/features/dive_log/presentation/pages/dive_detail_page.dart \
  lib/features/dive_sites/presentation/pages/site_detail_page.dart \
  lib/features/courses/presentation/pages/course_detail_page.dart \
  lib/features/certifications/presentation/pages/certification_detail_page.dart \
  lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart \
  lib/features/equipment/presentation/pages/equipment_detail_page.dart \
  lib/features/buddies/presentation/pages/buddy_detail_page.dart
git commit -m "feat(master-detail): retain scroll on dive/site/course/cert/center/equipment/buddy detail"
```

---

### Task 3: Add PageStorageKeys across the trips detail (tabbed)

Trips has a standard layout (`body = TripOverviewTab(...)`) and a 5-tab liveaboard `TabBarView`. Its scroll views live across three files. Tag each so both standard trips and each liveaboard tab retain scroll across trip selection.

**Files (all Modify):**
- `lib/features/trips/presentation/widgets/trip_overview_tab.dart` (~line 63) — Overview tab / standard-layout body
- `lib/features/trips/presentation/widgets/trip_itinerary_tab.dart` (~line 78) — Itinerary tab
- `lib/features/trips/presentation/pages/trip_detail_page.dart` (~lines 161, 218, 240) — checklist, photos, dives tabs

**Interfaces:**
- Consumes: the retention mechanism validated in Task 1.
- Produces: scroll retention for trips. Key strings: `tripOverviewScroll`, `tripItineraryScroll`, `tripPhotosScroll`, `tripDivesScroll`, `tripChecklistScroll`.

- [ ] **Step 1: Tag the Overview tab scroll view**

In `lib/features/trips/presentation/widgets/trip_overview_tab.dart`, current (4-space `return`, 6-space first arg):

```dart
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
```

Change to:

```dart
    return SingleChildScrollView(
      key: const PageStorageKey('tripOverviewScroll'),
      padding: const EdgeInsets.all(16),
```

- [ ] **Step 2: Tag the Itinerary tab list**

In `lib/features/trips/presentation/widgets/trip_itinerary_tab.dart`, current:

```dart
    return ListView.builder(
      padding: const EdgeInsets.all(16),
```

Change to:

```dart
    return ListView.builder(
      key: const PageStorageKey('tripItineraryScroll'),
      padding: const EdgeInsets.all(16),
```

- [ ] **Step 3: Tag the three in-page tabs in `trip_detail_page.dart`**

(a) Checklist tab (inline in the `TabBarView`, 16-space `SingleChildScrollView`, 18-space first arg):

```dart
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: TripChecklistSection(trip: tripWithStats.trip),
                ),
```

Change to:

```dart
                SingleChildScrollView(
                  key: const PageStorageKey('tripChecklistScroll'),
                  padding: const EdgeInsets.all(16),
                  child: TripChecklistSection(trip: tripWithStats.trip),
                ),
```

(b) Photos tab in `_buildPhotosTab` (4-space `return`, 6-space first arg):

```dart
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: TripPhotoSection(tripId: trip.id),
    );
```

Change to:

```dart
    return SingleChildScrollView(
      key: const PageStorageKey('tripPhotosScroll'),
      padding: const EdgeInsets.all(16),
      child: TripPhotoSection(tripId: trip.id),
    );
```

(c) Dives tab list in `_buildDivesTab` (8-space `return ListView.builder(`, 10-space first arg):

```dart
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDives.length,
```

Change to:

```dart
        return ListView.builder(
          key: const PageStorageKey('tripDivesScroll'),
          padding: const EdgeInsets.all(16),
          itemCount: sortedDives.length,
```

- [ ] **Step 4: Format and analyze the trips files**

Run:
```bash
dart format \
  lib/features/trips/presentation/widgets/trip_overview_tab.dart \
  lib/features/trips/presentation/widgets/trip_itinerary_tab.dart \
  lib/features/trips/presentation/pages/trip_detail_page.dart
flutter analyze \
  lib/features/trips/presentation/widgets/trip_overview_tab.dart \
  lib/features/trips/presentation/widgets/trip_itinerary_tab.dart \
  lib/features/trips/presentation/pages/trip_detail_page.dart
```
Expected: no formatting changes needed, analyze reports no issues.

- [ ] **Step 5: Sanity-run existing trips tests**

Run:
```bash
flutter test test/features/trips 2>&1 | tail -20
```
Expected: all pass (or same pass/skip set as before; note but do not fix unrelated pre-existing failures).

- [ ] **Step 6: Commit**

```bash
git add \
  lib/features/trips/presentation/widgets/trip_overview_tab.dart \
  lib/features/trips/presentation/widgets/trip_itinerary_tab.dart \
  lib/features/trips/presentation/pages/trip_detail_page.dart
git commit -m "feat(trips): retain scroll per trip and per liveaboard tab in detail pane"
```

---

### Task 4: Whole-project verification + manual macOS check

Confirms the change is clean project-wide and actually behaves in the running app.

**Files:** none (verification only).

- [ ] **Step 1: Whole-project format and analyze**

Run (per project memory: format and analyze the WHOLE project, never `| tail` the analyze that hides failures):
```bash
dart format .
flutter analyze
```
Expected: `dart format .` reports no changes; `flutter analyze` reports "No issues found!". If format changed anything, review and commit the reformat.

- [ ] **Step 2: Run the master-detail + touched-feature test suites**

Run:
```bash
flutter test test/shared/widgets/master_detail
```
Expected: PASS, including the Task 1 contract test.

- [ ] **Step 3: Manual verification via the run skill (macOS)**

Launch the app (`flutter run -d macos`, honoring the single-instance rule from project memory — check for an existing session first). Then, in a wide window:
1. Open **Dives**, select a dive, scroll the detail pane down to a lower section (e.g. Marine Life or Cylinders).
2. Click a different dive in the list. Confirm the detail pane **stays scrolled** to roughly that section (does not jump to the header).
3. Select a much shorter dive and confirm it lands at its own bottom (clamped), not an error.
4. Repeat step 1-2 for **Sites** to confirm a second section works.
5. Open **Settings** (excluded), navigate between sections, and confirm it still starts at the top (no accidental retention).

- [ ] **Step 4: Final commit (only if format/step-1 produced changes)**

```bash
git add -- <only the specific reformatted files>
git commit -m "style: dart format after scroll-retention changes"
```

If no changes were produced by Step 1, skip this step.

---

## Notes for the executor

- The behavior is pixel-offset retention, clamped by `Scrollable` to the new item's extent. Shorter items landing at their own bottom is correct, not a bug.
- Do not add a `PageStorageBucket` anywhere — the ambient route bucket is sufficient (spike-verified). Adding one is redundant scope.
- If any edit's "current code" block does not match (line numbers may drift), locate the `SingleChildScrollView` / `ListView.builder` named `body` (or the specified tab builder) in that file and insert the `key:` as the first argument with matching indentation.
