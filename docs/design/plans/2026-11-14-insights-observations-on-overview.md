# Observations on the Insights Overview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Overview page always leads with the observations strip, and the phone Insights landing no longer shows it.

**Architecture:** Remove the `showObservations` flag from `InsightsOverviewPage` so `_OverviewBody` always renders `ObservationsStrip` above the aggregate grid, then drop the strip from `InsightsMobileContent`. The desktop summary pane keeps its current look because it already showed the strip.

**Tech Stack:** Flutter, Riverpod, flutter_test widget tests.

**Spec:** `docs/design/specs/2026-11-14-insights-observations-on-overview-design.md`

## Global Constraints

- Desktop Insights home looks as it does today.
- No change to the category list contents, the Add shortcut picker, or the Observations page.
- `dart format .` and `flutter analyze` clean before committing.

## Review Focus

- No observations: the Overview shows no heading or gap above the grid (the strip is zero-size when empty). Pinned by "an empty strip takes no space on the Overview".
- Observations failed to load: the Overview shows the strip's error state with Retry and the rest of the page still renders. Covered by `observations_strip_test.dart`; no new test.
- Empty logbook: the Overview shows its empty state with no strip (the strip lives below the empty-state early return). Existing `insights_overview_empty_state_test.dart` covers the empty state.
- Active Insights filter: the strip's filter note shows on the Overview as it did on the landing. Covered by `observations_strip_test.dart`.
- Other Overview tests now build the strip against the test database; they must still settle. Run the whole `test/features/insights/presentation/pages/` folder.

---

### Task 1: Overview always leads with observations; phone landing drops them

**Files:**
- Modify: `lib/features/insights/presentation/pages/insights_overview_page.dart` (field and doc at lines 28-39, `_OverviewBody` at 62-120)
- Modify: `lib/features/insights/presentation/pages/insights_page.dart` (summary pane at line 48, mobile list at lines 99-103, unused import)
- Test: `test/features/insights/presentation/pages/insights_observations_placement_test.dart`

**Interfaces:**
- Produces: `InsightsOverviewPage({Key? key, bool embedded = false})`. The `showObservations` parameter no longer exists.

- [ ] **Step 1: Rewrite the placement test to the new placement**

Keep the harness (`pump`, `strip`, `stats`). Replace the groups with:

```dart
group('phone landing', () {
  testWidgets('shows no observations strip', (tester) async {
    await pump(tester, const InsightsMobileContent(),
        strip([gapObservation(lastDiveId: 'a'), categoryObservation('gas')]));
    expect(find.byType(ObservationsStrip, skipOffstage: false), findsNothing);
    expect(find.text('Observations'), findsNothing);
    expect(find.text('Overview'), findsOneWidget);
  });
});

group('Overview page', () {
  testWidgets('leads with the strip', (tester) async {
    await pump(tester, const Scaffold(body: InsightsOverviewPage(embedded: true)),
        [...stats(), ...strip([gapObservation()])]);
    final stripTop = tester.getTopLeft(find.byType(ObservationsStrip)).dy;
    expect(stripTop, lessThan(tester.getTopLeft(find.text('42')).dy));
    expect(find.text('Observations'), findsOneWidget);
  });

  testWidgets('an empty strip takes no space on the Overview', (tester) async {
    await pump(tester, const Scaffold(body: InsightsOverviewPage(embedded: true)),
        [...stats(), ...strip(const [])]);
    expect(find.text('Observations'), findsNothing);
    expect(tester.getSize(find.byType(ObservationsStrip, skipOffstage: false)).height, 0);
  });
});
```

Update the file's doc comment to: the Overview page leads with the strip on every layout (#4559), and the phone landing shows none.

- [ ] **Step 2: Run it to make sure it fails**

Run: `flutter test test/features/insights/presentation/pages/insights_observations_placement_test.dart`
Expected: FAIL. "shows no observations strip" finds the strip on the landing, and "leads with the strip" finds none.

- [ ] **Step 3: Remove the flag and the landing strip**

In `insights_overview_page.dart`, delete the `showObservations` field, its doc comment and constructor parameter, the `showObservations` field and parameter on `_OverviewBody`, and the `if (showObservations)` guard, leaving `const ObservationsStrip(padding: EdgeInsets.only(bottom: 16))` as the first column child. In `insights_page.dart`, change the summary pane to `const InsightsOverviewPage(embedded: true)`, delete the `ObservationsStrip` child and its comment from `InsightsMobileContent`, and remove the now-unused `observations_strip.dart` import.

- [ ] **Step 4: Run the Insights page tests**

Run: `flutter test test/features/insights/presentation/pages/`
Expected: all pass.

- [ ] **Step 5: Format, analyze, commit**

Run: `dart format lib/features/insights test/features/insights && flutter analyze`
Expected: no issues.

```bash
git add lib/features/insights/presentation/pages/insights_overview_page.dart lib/features/insights/presentation/pages/insights_page.dart test/features/insights/presentation/pages/insights_observations_placement_test.dart
git commit -m "feat(insights): show observations on the Overview page, not the phone landing"
```
