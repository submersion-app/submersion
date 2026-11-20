# Home as a Technical Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline in one session. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Home page with a dense panel dashboard: a slim header bar, 22 panels plus a first-dive panel, rows that always fill the width, and four layout presets the diver can customise.

**Architecture:** One ordered list of `HomePanelType` drives every width. A pure function packs the visible panels into full-width rows for a width tier; `DashboardGrid` stays a lazy sliver that renders those rows at fixed heights. Presets are named panel lists; the diver's layout is an order plus a hidden set in SharedPreferences under new keys. The gauge strip's chip logic becomes a list of status-light models shown in a pinned header.

**Tech Stack:** Flutter, Riverpod 3, Drift (read-only queries), fl_chart and custom painters, go_router, ARB localisation (11 locales).

**Spec:** `docs/design/specs/2026-11-20-home-technical-dashboard-design.md`

## Global Constraints

- No database schema change. No new package dependency.
- Home providers call repositories with `currentDiverIdProvider` and no filter. They never watch a provider from `insights_providers.dart`.
- Repositories return metric values; every displayed value is formatted through `unitFormatterProvider`.
- No panel hard-codes a colour; use the theme's colour scheme. Status is never shown by colour alone.
- Old settings keys `home_card_order` and `hidden_home_cards` are never written.
- The three safety lights (overdue gear, expired insurance on a real policy, closed or conflicting flight window) cannot be hidden.
- A hidden panel's provider is not watched (issue #4251).
- Every new user-visible string is in all 11 ARB files. No emojis. No em-dashes anywhere.
- Paths in tests use `p.join`; a test that replaces process-wide state restores it in `addTearDown`.
- Files stay under 800 lines; one panel per file.
- Run only the test files written or changed, by path. Never a folder or the whole suite.
- Commit after each task with the message given. No tool attribution in any commit.

## Review Focus

1. **Text scale 2.0 on a phone:** every panel must stay inside its fixed row height with no overflow; rows elide or drop lines instead. (Task 9, Task 14)
2. **Very long names** (site, gear item, trip, buddy, a 40-character diver name in the switcher pill): one line, elided, never pushing the value off the panel or the bar. (Task 7, Task 10, Task 11)
3. **A diver with exactly one dive, or dives but no SAC, no profile samples, no GPS:** trend lines with one point, "vs average" with nothing to compare, an empty profile. Each shows a quiet empty state inside the box, not an error and not a blank box. (Task 10, Task 11, Task 12)
4. **Width just either side of 800 and 1200, and a 320-wide phone:** no row overflows and every row still sums to 12 units. (Task 2, Task 14)
5. **Corrupt or foreign values in the new preference keys** (unknown panel names, duplicates, a non-list type): Home falls back to Balanced and never throws. (Task 3, Task 4)

---

## File Structure

Under `lib/features/dashboard/presentation/`:

| File | Responsibility |
| --- | --- |
| `home_panels.dart` (new, replaces `home_cards.dart`) | `HomePanelType`, `HomeKeyNumber`, size classes, `homePanelSpec` |
| `home_layout.dart` (rewritten) | `HomeWidthTier`, `HomeRow`, `packHomeRows` |
| `home_presets.dart` (new) | `HomeLayoutPreset`, preset lists, `resolveHomeLayout`, `matchingPreset` |
| `providers/home_panel_providers.dart` (new) | Providers for the new panel data |
| `providers/home_status_lights.dart` (new) | `HomeStatusLight` model and `buildHomeStatusLights` |
| `widgets/dashboard_grid.dart` (rewritten) | Lazy sliver of `HomeRow`s at fixed heights |
| `widgets/home_header_bar.dart` (new) | The pinned bar, the phone strip, the More menu, the switcher pill |
| `widgets/home_panel.dart` (new) | The panel frame: title, trailing text, tap target, semantics, states |
| `widgets/home_charts.dart` (new) | Small painters: sparkline, bars, day grid, labelled bar row |
| `panels/<name>_panel.dart` (new, one per panel) | One panel each |
| `pages/dashboard_page.dart` (rewritten) | Wires settings, layout, header and grid |

Elsewhere:

| File | Change |
| --- | --- |
| `lib/features/insights/data/repositories/insights_repository_home.dart` (new part or extension, following `insights_repository_calendar_days.dart`) | New read queries |
| `lib/features/settings/presentation/providers/settings_providers.dart` | New keys, fields, setters; old card setters removed |
| `lib/features/settings/presentation/pages/home_appearance_page.dart` | Layout picker, panel list |
| `lib/features/settings/presentation/pages/home_key_numbers_page.dart` (new) | Tile switches |
| `lib/core/router/app_router.dart` | Route `/settings/appearance/home/key-numbers` |
| `lib/l10n/arb/app_*.arb` (11 files) | New strings; strings left without a user removed |

Deleted at the end: `home_cards.dart`, `widgets/hero_header.dart`, `widgets/hero_diver_avatar.dart`, `widgets/gauge_strip.dart`, `widgets/quick_actions_card.dart`, `widgets/milestones_card.dart`, `widgets/year_in_review_card.dart`, `providers/milestone_providers.dart`, and their tests.

Tests mirror the source path under `test/features/...`.

---

### Task 1: Panel catalogue

**Files:**
- Create: `lib/features/dashboard/presentation/home_panels.dart`
- Test: `test/features/dashboard/presentation/home_panels_test.dart`

**Interfaces:**
- Produces:
  - `enum HomePanelType { keyNumbers, waitingForDownload, preDive, activeCourses, activityCalendar, gearService, comingDue, nextTrip, latestProfile, latestVsAverage, recentDives, sacTrend, depthMix, divesPerMonth, gasMix, diveTypes, topSites, topBuddies, speciesSeen, photoRibbon, recentSitesMap, onThisDay }`. The seven names shared with the old `HomeCardType` (`waitingForDownload`, `preDive`, `activeCourses`, `recentDives`, `photoRibbon`, `recentSitesMap`, `onThisDay`) are kept exactly, because the upgrade reads the old hidden set by name.
  - `enum HomeKeyNumber { dives, timeUnder, lastDive, avgSac, deepestThisYear, nextTrip, avgDepth, species }`
  - `enum HomePanelWidth { sChart, sList, m, l, xl }`, `enum HomePanelHeight { short, medium, tall }`
  - `class HomePanelSpec { final HomePanelWidth width; final HomePanelHeight height; final bool conditional; }`
  - `HomePanelSpec homePanelSpec(HomePanelType type)` with the widths, heights and conditional flags from the spec's panel table (with Recent photos as S list, see the amendments; S chart: depthMix, divesPerMonth, gasMix, diveTypes; conditional: waitingForDownload, preDive, activeCourses, nextTrip, speciesSeen, photoRibbon, recentSitesMap, onThisDay).
  - `const Set<HomeKeyNumber> defaultHiddenKeyNumbers = {avgDepth, species}`

- [ ] **Step 1: Write the failing tests**

```dart
test('every panel has a spec', () {
  for (final t in HomePanelType.values) {
    expect(() => homePanelSpec(t), returnsNormally);
  }
});
test('names shared with the old card enum are unchanged', () {
  expect(
    HomePanelType.values.map((t) => t.name),
    containsAll(['waitingForDownload', 'preDive', 'activeCourses',
      'recentDives', 'photoRibbon', 'recentSitesMap', 'onThisDay']),
  );
});
test('key numbers is the only XL short panel', () {
  final xl = HomePanelType.values
      .where((t) => homePanelSpec(t).width == HomePanelWidth.xl);
  expect(xl, [HomePanelType.keyNumbers]);
});
test('only the four chart panels are S chart', () { /* depthMix, divesPerMonth, gasMix, diveTypes */ });
```

- [ ] **Step 2: Run** `flutter test test/features/dashboard/presentation/home_panels_test.dart`. Expected: FAIL, file not found.
- [ ] **Step 3: Implement `home_panels.dart`** as above.
- [ ] **Step 4: Run the test.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dashboard): home panel catalogue`

### Task 2: Row packing

**Files:**
- Rewrite: `lib/features/dashboard/presentation/home_layout.dart`
- Rewrite: `test/features/dashboard/presentation/home_layout_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `enum HomeWidthTier { phone, tablet, desktop }` and `HomeWidthTier homeWidthTierOf(BuildContext)` (phone under `ResponsiveBreakpoints.desktop`, desktop at `desktopExtended` and up).
  - `int homePanelUnits(HomePanelWidth width, HomeWidthTier tier)` from the spec's tier table.
  - `class HomeRow { final List<HomePanelType> panels; final List<int> units; final HomePanelHeight height; }` where `height` is the tallest class in the row.
  - `List<HomeRow> packHomeRows(List<HomePanelType> visible, HomeWidthTier tier, {bool firstDive = false})`. `firstDive` is not a panel type; the grid handles it (Task 14).

Algorithm (the tests do not fully determine it):

```
row = []; used = 0
for panel in visible:
  u = units(panel); c = conditional(panel)
  breakBefore = row not empty and (used + u > 12 or c != conditional(row.last))
  if breakBefore: close(row); row = []; used = 0
  row.add(panel); used += u
close(row)
```

`units` in a `HomeRow` are the raw units; the grid uses them as flex weights, which stretches every row to the full width.

- [ ] **Step 1: Write the failing tests**

```dart
test('desktop Balanced rows', () {
  final rows = packHomeRows(balancedPanels, HomeWidthTier.desktop);
  expect(rows.map((r) => r.panels), [
    [keyNumbers],
    [waitingForDownload, preDive, activeCourses],
    [activityCalendar, gearService],
    [latestProfile, recentDives],
    [depthMix, divesPerMonth, gasMix],
    [photoRibbon, recentSitesMap, onThisDay],
  ]);
});
test('a row never exceeds 12 units, at any tier, for any order', () {
  final random = Random(1);
  for (var i = 0; i < 500; i++) {
    final panels = [...HomePanelType.values]..shuffle(random);
    final subset = panels.take(random.nextInt(panels.length) + 1).toList();
    for (final tier in HomeWidthTier.values) {
      final rows = packHomeRows(subset, tier);
      expect(rows.expand((r) => r.panels), subset); // order kept, none lost
      for (final r in rows) {
        expect(r.units.reduce((a, b) => a + b), lessThanOrEqualTo(12));
        expect(r.panels, isNotEmpty);
      }
    }
  }
});
test('conditional panels never share a row with others', () { /* every row is all-conditional or none */ });
test('one conditional present changes only its own row', () {
  final all = packHomeRows(balancedPanels, HomeWidthTier.desktop);
  final one = packHomeRows(
    balancedPanels.where((p) => p != preDive && p != activeCourses).toList(),
    HomeWidthTier.desktop);
  expect(one.where((r) => !r.panels.contains(waitingForDownload)).map((r) => r.panels),
      all.where((r) => !r.panels.contains(waitingForDownload)).map((r) => r.panels));
});
test('phone: S chart panels pair, S list panels take a row', () { /* depthMix+divesPerMonth share; gearService alone */ });
test('empty list gives no rows', () {});
```

- [ ] **Step 2: Run** the test file. Expected: FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run.** Expected: PASS.
- [ ] **Step 5: Commit** `feat(dashboard): pack home panels into full rows`

### Task 3: Presets and layout resolution

**Files:**
- Create: `lib/features/dashboard/presentation/home_presets.dart`
- Test: `test/features/dashboard/presentation/home_presets_test.dart`

**Interfaces:**
- Consumes: Task 1.
- Produces:
  - `enum HomeLayoutPreset { balanced, ready, trends, logbook }`
  - `List<HomePanelType> homePresetPanels(HomeLayoutPreset preset)` with the four lists from the spec, in order.
  - `class HomeLayout { final List<HomePanelType> order; final Set<HomePanelType> hidden; List<HomePanelType> get visible; }`. `order` always contains every panel exactly once.
  - `HomeLayout homeLayoutForPreset(HomeLayoutPreset preset)`: the preset's panels first, then every other panel in enum order, those others hidden.
  - `HomeLayout resolveHomeLayout({required List<String>? storedOrder, required Set<String>? storedHidden, required Set<String> legacyHiddenCards})`:
    - both stored values null: Balanced, plus every Balanced panel whose name is in `legacyHiddenCards` hidden;
    - otherwise: stored order with unknown names dropped, duplicates collapsed to the first, and missing panels inserted after their nearest preceding enum neighbour (the rule `reconcileHomeCardOrder` uses today); stored hidden with unknown names dropped. A panel missing from a stored order (added in a later version) is hidden.
  - `HomeLayoutPreset? matchingPreset(HomeLayout layout)`: the preset whose panel list equals `layout.visible`, else null (Custom). The preset is derived, never stored.

- [ ] **Step 1: Write the failing tests**

```dart
test('each preset lists known panels once, key numbers first', () {
  for (final p in HomeLayoutPreset.values) {
    final panels = homePresetPanels(p);
    expect(panels.toSet().length, panels.length);
    expect(panels.first, HomePanelType.keyNumbers);
  }
});
test('nothing stored resolves to Balanced', () {
  final l = resolveHomeLayout(storedOrder: null, storedHidden: null, legacyHiddenCards: {});
  expect(l.visible, homePresetPanels(HomeLayoutPreset.balanced));
  expect(matchingPreset(l), HomeLayoutPreset.balanced);
});
test('a card hidden before the upgrade stays hidden', () {
  final l = resolveHomeLayout(storedOrder: null, storedHidden: null,
      legacyHiddenCards: {'photoRibbon', 'hero', 'milestones'});
  expect(l.visible, isNot(contains(HomePanelType.photoRibbon)));
  expect(matchingPreset(l), isNull);
});
test('unknown and duplicate names are dropped, missing panels slotted hidden', () {
  final l = resolveHomeLayout(
    storedOrder: ['recentDives', 'bogus', 'recentDives', 'keyNumbers'],
    storedHidden: {'bogus'}, legacyHiddenCards: {});
  expect(l.order.toSet().length, HomePanelType.values.length);
  expect(l.visible, [HomePanelType.recentDives, HomePanelType.keyNumbers]);
});
test('every order has every panel exactly once', () {});
test('matchingPreset finds each preset from homeLayoutForPreset', () {});
```

- [ ] **Steps 2-4:** run to fail, implement, run to pass.
- [ ] **Step 5: Commit** `feat(dashboard): home layout presets and resolution`

### Task 4: Settings storage

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (keys near line 172; fields near 793; `copyWith`; `_withDeviceLocalPrefs` near 1838; load near 1884; save near 2077; setters near 2719)
- Modify: `test/helpers/mock_providers.dart` and the local settings mocks in `test/features/settings/presentation/pages/settings_page_test.dart`, `settings_page_shared_data_test.dart`, `test/features/insights/presentation/pages/records_page_test.dart`
- Rewrite: `test/features/settings/presentation/providers/home_card_settings_test.dart` as `home_panel_settings_test.dart`
- Check: `every_setter_waits_for_load_test.dart`, `settings_setters_wait_for_load_test.dart`, `settings_notifier_real_test.dart` (they enumerate setters)

**Interfaces:**
- Produces, on `SettingsKeys`: `homePanelOrder = 'home_panel_order'`, `hiddenHomePanels = 'hidden_home_panels'`, `hiddenHomeKeyNumbers = 'hidden_home_key_numbers'`.
- Produces, on `AppSettings`: `List<String>? homePanelOrder`, `Set<String>? hiddenHomePanels` (null means never set), `Set<String>? hiddenHomeKeyNumbers` (null means the default hidden set). `hiddenHomeCards` stays, read-only, as the legacy input. `homeCardOrder` is removed.
- Produces, on the notifier: `Future<void> setHomePanelLayout({required List<String> order, required Set<String> hidden})`, `Future<void> setHomeKeyNumberEnabled(String id, bool enabled, {required Set<String> currentHidden})`. Removed: `setHomeCardEnabled`, `setHomeCardOrder`, `resetHomeCards`.
- `copyWith` cannot set a nullable field back to null; nothing needs to (reset writes Balanced explicitly).

- [ ] **Step 1: Write the failing tests** (real notifier over `SharedPreferences.setMockInitialValues`)

```dart
test('new keys absent load as null', () {});
test('setHomePanelLayout persists both lists and survives a reload', () {});
test('the old keys are never written', () async {
  SharedPreferences.setMockInitialValues({
    'home_card_order': ['hero'], 'hidden_home_cards': ['photoRibbon']});
  // load, setHomePanelLayout(...), then:
  expect(prefs.getStringList('home_card_order'), ['hero']);
  expect(prefs.getStringList('hidden_home_cards'), ['photoRibbon']);
});
test('a wrong-typed value in a new key loads as null, not a throw', () async {
  SharedPreferences.setMockInitialValues({'home_panel_order': 42});
});
test('legacy hidden cards are still readable', () {});
```

- [ ] **Steps 2-4:** run to fail, implement (wrap the three new reads in the existing try/catch), update the four mocks, run the changed test files to pass.
- [ ] **Step 5: Commit** `feat(settings): store the home panel layout under new keys`

### Task 5: Repository queries for Home

**Files:**
- Create: `lib/features/insights/data/repositories/insights_repository_home.dart`, in the same form as `insights_repository_calendar_days.dart`
- Modify: `insights_repository.dart` only to attach the part or extension and to add `avgMaxDepth` to `YearStats` and `getYearStats`
- Test: `test/features/insights/data/repositories/insights_repository_home_test.dart` (in-memory Drift database, as the neighbouring repository tests set one up)

**Interfaces:**
- Produces:
  - `Future<Map<DateTime, int>> getDailyDiveCounts({String? diverId, required DateTime from, required DateTime to})`: keys are local calendar days at midnight; days with no dives are absent. Read how `getCalendarDayMatrix` turns `dive_date_time` (wall clock stored as UTC epoch milliseconds) into a calendar day and do the same.
  - `Future<List<TrendDataPoint>> getRecentSacPerDive({String? diverId, required int limit})`: the newest `limit` dives that have a SAC, oldest first, using the same SAC definition as `getSacVolumePerDive`.
  - `Future<HomeAverages> getAveragesSince({String? diverId, required DateTime since})` with `class HomeAverages { final double? maxDepth; final int? runtimeSeconds; final double? sac; final int diveCount; }`. Runtime is the measured runtime, never bottom time.
  - `Future<int> getSpeciesFirstSeenSince({String? diverId, required DateTime since})`.
  - `Future<List<SpeciesSighting>> getRecentSpeciesSightings({String? diverId, required int recentDives, required int limit})` with `class SpeciesSighting { final String name; final int diveCount; }`.
  - `YearStats.avgMaxDepth` (`double?`).
- All queries are parameterised and filter on the diver id like their neighbours.

- [ ] **Step 1: Write the failing tests**: seed dives across two divers and assert: daily counts group two dives on one day into 2 and skip another diver's dives; a dive at 23:30 local stays on its own day; SAC series returns at most `limit`, oldest first; averages ignore dives before `since` and return nulls with no dives; species counts are distinct.
- [ ] **Steps 2-4:** run to fail, implement, run to pass. Run the test once more with `TZ=Australia/Sydney` (CI's zone).
- [ ] **Step 5: Commit** `feat(insights): read queries for the home panels`

### Task 6: Home panel providers and pure helpers

**Files:**
- Create: `lib/features/dashboard/presentation/providers/home_panel_providers.dart`
- Test: `test/features/dashboard/presentation/providers/home_panel_providers_test.dart`

**Interfaces:**
- Consumes: Task 5; `diveStatisticsProvider`, `careerTotalsProvider`, `yearInReviewProvider`, `recentDivesProvider`, `activeEquipmentClocksProvider`, `dashboardGaugesProvider`, `dashboardQuickStatsProvider`, `homeTripChecklistProvider`.
- Produces (each a `FutureProvider`, watching `currentDiverIdProvider` and `repository.watchInsightsChanges()` like `yearInReviewProvider`):
  - `homeActivityDaysProvider` → `Map<DateTime, int>` for the last 12 months
  - `homeMonthlyDivesProvider` → `List<MonthCount>` (`{int year, int month, int count}`), exactly 12 entries, zero-filled, oldest first
  - `homeSacSeriesProvider` → `List<TrendDataPoint>` (limit 30)
  - `homeAveragesProvider` → `HomeAverages` over the last 12 months
  - `homeGasMixProvider`, `homeDiveTypesProvider`, `homeTopBuddiesProvider`, `homeRecentSpeciesProvider`, `homeLatestProfileProvider` (the newest dive's samples, read off the UI isolate as `RecentDiveProfilePreview` does today, downsampled to at most 120 points)
  - `homeKeyNumbersProvider` → `HomeKeyNumbers`, one nullable entry per `HomeKeyNumber`, each `{double value, String? comparison data, List<double>? series}`; a null entry means "leave the tile out"
- Pure functions, tested directly:
  - `List<MonthCount> zeroFilledMonths(List<MonthlyDiveCount> raw, DateTime now)`
  - `List<GearServiceBar> gearServiceBars(List<EquipmentClocks> clocks, {int max = 5})` with `class GearServiceBar { final String itemId; final String itemName; final ServiceClockStatus status; final double fraction; }`. `fraction` is clamped to 0..1 and is the largest of the clock's time fraction `(now - anchor) / (dueDate - anchor)` and its usage fractions `since / interval`; overdue is 1. Sorted overdue first, then by fraction descending.
  - `List<ComingDueItem> comingDueItems(...)`: gear due clocks, the insurance expiry, certification expiries and expiring documents, soonest first, at most 5. Take each source from the same provider its status chip uses in `dashboardGaugesProvider`; read that provider before writing this.
  - `List<double> downsample(List<double> values, int max)`

- [ ] **Step 1: Write the failing tests** for the pure functions: `zeroFilledMonths` returns 12 entries across a year boundary with zeros; `gearServiceBars` orders overdue first, clamps, caps at 5, handles a clock with no due date and no usage (fraction 0); `downsample` keeps first and last and never returns more than `max`; a provider test proving `homeKeyNumbersProvider` yields a null `avgSac` when the series is empty and a null `nextTrip` with no trip.
- [ ] **Steps 2-4:** run to fail, implement, run to pass.
- [ ] **Step 5: Commit** `feat(dashboard): providers for the home panels`

### Task 7: Status lights

**Files:**
- Create: `lib/features/dashboard/presentation/providers/home_status_lights.dart`
- Test: `test/features/dashboard/presentation/providers/home_status_lights_test.dart`
- Read first: `widgets/gauge_strip.dart` in full (621 lines); every chip's condition, label, tone and destination moves here unchanged.

**Interfaces:**
- Produces:
  - `enum HomeLightTone { neutral, ok, warn, alert }`
  - `class HomeStatusLight { final HomeChipType type; final HomeLightTone tone; final String label; final IconData icon; final bool safety; final void Function(BuildContext context, WidgetRef ref) onTap; final VoidCallback? onLongPress; }`. `onTap` is non-nullable by type.
  - `List<HomeStatusLight> buildHomeStatusLights({required AppLocalizations l10n, required UnitFormatter units, required DashboardGauges gauges, required Set<String> hidden, ...})`: one entry per chip the strip renders today, with the same hide rule (`safety` lights ignore `hidden`), sorted alert, warn, then the rest in today's order. Add parameters for whatever else `GaugeStrip._buildStrip` reads.
  - `({List<HomeStatusLight> attention, int clear}) splitForPhone(List<HomeStatusLight> lights)`: attention is every warn or alert light.

- [ ] **Step 1: Port the tests.** Move each behavioural case from `gauge_strip_test.dart` to assert on the returned list: which lights exist for a given `DashboardGauges`, their tone and label, that hiding a chip removes it, that the three safety lights survive being hidden, and the sort order. Add: `splitForPhone` with all-clear lights gives an empty `attention`.
- [ ] **Steps 2-4:** run to fail, implement by moving the logic out of `GaugeStrip`, run to pass. `GaugeStrip` itself stays compiling until Task 15.
- [ ] **Step 5: Commit** `refactor(dashboard): gauge chips as status-light models`

### Task 8: Header bar

**Files:**
- Create: `lib/features/dashboard/presentation/widgets/home_header_bar.dart`
- Test: `test/features/dashboard/presentation/widgets/home_header_bar_test.dart`
- Modify: `test/core/router/app_router_test.dart` (rename the group "home gauge-strip chip destinations resolve" to status lights; keep the full path list; add the More menu's `/settings/diver-profile/emergency-card` and `/planning/dive-planner`)

**Interfaces:**
- Consumes: Task 7; `diverCountProvider`, `dashboardDiverProvider`, `showDiverSwitcherSheet`, `showAddDiveBottomSheet`, `SwapWithBuddyActionButton`'s availability rule, `dashboardGaugesProvider`.
- Produces: `class HomeHeaderBar extends ConsumerWidget` with `static const double barHeight = 36`, and `class HomeStatusStrip extends ConsumerWidget` (phone only). `HomeHeaderBar` lays out by `homeWidthTierOf(context)`.
- Behaviour, from the spec's Header bar and Status lights sections. Details the spec leaves open:
  - Log dive opens `showAddDiveBottomSheet` with the same two callbacks `QuickActionsCard` passes today; Plan pushes `/planning/dive-planner`; all navigation uses `context.push`.
  - The switcher uses `ref.watch(dashboardDiverProvider).value` (not the `valueOrNull` polyfill), so the avatar does not blank during a switch. Absent when the count is under 2; unknown count is treated as 1.
  - The gauges' loading state shows a quiet placeholder in the lights area; the error state shows one retry light that invalidates `dashboardGaugesProvider`.
  - The phone count pill opens a modal sheet listing every light.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('no switcher with one diver; a switcher with two', ...);
testWidgets('every light is tappable', (tester) async {
  // pump with gauges that produce several lights
  for (final w in tester.widgetList<InkWell>(find.descendant(
      of: find.byType(HomeHeaderBar), matching: find.byType(InkWell)))) {
    expect(w.onTap, isNotNull);
  }
});
testWidgets('phone: an amber light is named and the rest are counted', ...);
testWidgets('phone: nothing amber or red shows one All clear pill', ...);
testWidgets('More menu holds Emergency card, and Plan on a phone', ...);
testWidgets('a 40-character diver name does not overflow the bar at 800 wide', ...);
testWidgets('gauges error shows a retry that refetches', ...);
testWidgets('every control has a 44 by 44 hit area on a phone', ...);
```

- [ ] **Steps 2-4:** run to fail, implement, run to pass (both test files).
- [ ] **Step 5: Commit** `feat(dashboard): slim home header with status lights and diver switcher`

### Task 9: Panel frame and small charts

**Files:**
- Create: `lib/features/dashboard/presentation/widgets/home_panel.dart`, `widgets/home_charts.dart`
- Test: `test/features/dashboard/presentation/widgets/home_panel_test.dart`, `home_charts_test.dart`

**Interfaces:**
- Produces:
  - `class HomePanel extends StatelessWidget { const HomePanel({required String title, String? trailing, required String semanticsValue, VoidCallback? onTap, required Widget child}); }`: bordered box (theme outline colour, small radius), small-capital title, trailing text right-aligned and elided, the whole box one `InkWell`. Semantics label is `"$title, $semanticsValue"`. The child is laid out in the remaining height and clipped.
  - `class HomePanelAsync<T>`: wraps an `AsyncValue<T>`; loading shows a quiet placeholder, error shows a one-line message, empty (a caller-supplied `isEmpty`) shows a one-line empty text, data builds the child. Used by the always-on panels.
  - `double homeRowHeight(HomePanelHeight height, BuildContext context)`: 96, 180, 260 multiplied by `MediaQuery.textScalerOf(context).scale(1)` clamped to 1.0..1.6.
  - In `home_charts.dart`: `HomeSparkline(values)`, `HomeBars(values, labels)`, `HomeDayGrid(counts, from, to)` (weeks as columns, 7 rows, opacity by count, each cell at least 6 logical pixels or the range is shortened from the old end), `HomeBarRow(label, value, fraction, {tone})`. All are `CustomPaint` or plain widgets with no fl_chart dependency, take colours from the theme, and handle an empty list and a single value.

- [ ] **Step 1: Write the failing tests**: `HomePanel` exposes the combined semantics label; trailing text elides at 120 wide without overflow; `HomePanelAsync` shows each of the four states; `homeRowHeight` at scale 2.0 is 96 × 1.6; each chart pumps without exception for an empty list, one value, and all-zero values; `HomeDayGrid` paints 53 columns for a full year at 600 wide.
- [ ] **Steps 2-4:** run to fail, implement, run to pass.
- [ ] **Step 5: Commit** `feat(dashboard): panel frame and small charts`

### Task 10: Key numbers panel

**Files:**
- Create: `lib/features/dashboard/presentation/panels/key_numbers_panel.dart`
- Test: `test/features/dashboard/presentation/panels/key_numbers_panel_test.dart`

**Interfaces:**
- Consumes: `homeKeyNumbersProvider`, `hiddenHomeKeyNumbers` (null means `defaultHiddenKeyNumbers`), Task 9.
- Produces: `class KeyNumbersPanel extends ConsumerWidget`; `static int tilesPerRow(HomeWidthTier tier, int tileCount)` (desktop: all in one row; tablet: 4 when more than 4 tiles, else all; phone: 2); `static double heightFor(BuildContext, HomeWidthTier, int tileCount)` = tile rows × `homeRowHeight(short)` plus gaps. The grid asks this panel for its height (Task 14).
- Each tile is its own tap target: dives and time under → `/dives`; last dive, deepest → that dive; average SAC, average depth → Insights; next trip → the trip; species → marine life. Confirm each route exists in `app_router.dart` before using it and add it to the router test list in Task 8's file.
- While loading: one placeholder per enabled tile.

- [ ] **Step 1: Write the failing tests**: six default tiles on desktop in one row; a null entry drops its tile and the rest fill the row; phone shows two per row; imperial units show feet and the diver's SAC unit; with zero dives the panel shows zeros for dives and time under and omits the rest; text scale 2.0 at 390 wide has no overflow.
- [ ] **Steps 2-4:** run to fail, implement, run to pass.
- [ ] **Step 5: Commit** `feat(dashboard): key numbers panel`

### Task 11: Trend and readiness panels

**Files (create, one widget each, under `panels/`):** `activity_calendar_panel.dart`, `dives_per_month_panel.dart`, `sac_trend_panel.dart`, `depth_mix_panel.dart`, `gas_mix_panel.dart`, `dive_types_panel.dart`, `top_sites_panel.dart`, `top_buddies_panel.dart`, `gear_service_panel.dart`, `coming_due_panel.dart`, `next_trip_panel.dart`
- Test: `test/features/dashboard/presentation/panels/trend_panels_test.dart`, `readiness_panels_test.dart`

**Interfaces:**
- Consumes: Tasks 6 and 9. Each panel is a `ConsumerWidget` with a const constructor and no parameters, wraps `HomePanel`, and opens the destination in the spec's table with `context.push`.
- Fixed details:
  - Activity calendar: 12 months at tablet and desktop, 6 months on a phone; trailing text is total dives and dive days for the range shown.
  - Depth mix: all dives (not this year; the data is career-wide and the spec is amended), bands from `DiveStatistics.depthDistribution` with empty deep bands trimmed and labels from `depthBucketLabel`.
  - Dives per month: month initials from `DateFormat.MMM(locale)`, first letter.
  - Gas mix, dive types, top sites, top buddies: top 3 as `HomeBarRow`s.
  - Gear service: up to 5 bars on desktop and tablet, 3 on a phone; amber for due soon, error colour for overdue, each with its remaining time or dives as text; with no gear, an empty state that opens `/equipment/new`.
  - Next trip is conditional: it builds nothing when there is no upcoming trip.

- [ ] **Step 1: Write the failing tests**: for each panel, a data case asserting its headline text, an empty case, and a tap that reaches its route through a stub router. Shared cases: imperial units on depth mix; a 60-character site, buddy and gear name each stay on one line at phone width; SAC trend with one point renders without exception.
- [ ] **Steps 2-4:** run to fail, implement, run to pass.
- [ ] **Step 5: Commit** `feat(dashboard): trend and readiness panels`

### Task 12: Logbook and conditional panels

**Files (create under `panels/`):** `latest_profile_panel.dart`, `latest_vs_average_panel.dart`, `recent_dives_panel.dart`, `species_seen_panel.dart`, `first_dive_panel.dart`
**Files (modify, re-frame in `HomePanel`, keep behaviour):** `widgets/media_ribbon_card.dart`, `widgets/recent_sites_map_card.dart`, `widgets/on_this_day_card.dart`, `widgets/active_course_progress_card.dart`, `widgets/waiting_for_download_card.dart`, `lib/features/pre_dive/presentation/widgets/pre_dive_dashboard_card.dart`
- Delete: `widgets/recent_dives_card.dart`, `widgets/recent_dive_profile_preview.dart` and their tests, once the new panels cover them
- Test: `test/features/dashboard/presentation/panels/logbook_panels_test.dart`; update the existing tests of the six re-framed widgets

**Interfaces:**
- Consumes: Tasks 6 and 9.
- Fixed details:
  - Recent dives: a table of up to 4 rows (3 on a phone, and the phone drops the date and SAC columns); each row opens its dive; columns align on tabular figures.
  - Latest profile: a static depth-against-time area chart from `homeLatestProfileProvider`; a dive with no samples shows the estimated-profile empty text; opens the dive.
  - Latest vs average: three `HomeBarRow`s; a row with no average shows the value alone.
  - The six re-framed widgets must fill a fixed height: the media ribbon shows as many whole rows of tiles as fit; the map fills the box. Keep the map's key (`Object.hashAllUnordered(points)`) and its `DeferUntilPainted` wrapper. Pre-dive keeps both of its rows when both apply, in a short panel, by using one line each.
  - First dive: title and two buttons, Log a dive (the add-dive sheet) and Import (the existing import entry route).

- [ ] **Step 1: Write the failing tests**: recent dives shows 4 rows on desktop, 3 columns on a phone, and a row tap opens `/dives/<id>`; latest profile with empty samples shows the empty text; latest vs average with null averages; each re-framed widget pumps inside a 180-high box without overflow; the first dive panel offers both actions.
- [ ] **Steps 2-4:** run to fail, implement, run to pass.
- [ ] **Step 5: Commit** `feat(dashboard): logbook and conditional panels`

### Task 13: Grid

**Files:**
- Rewrite: `lib/features/dashboard/presentation/widgets/dashboard_grid.dart`
- Rewrite: `test/features/dashboard/presentation/widgets/dashboard_grid_test.dart`

**Interfaces:**
- Consumes: Tasks 2, 9, 10.
- Produces: `class DashboardGrid extends StatelessWidget { const DashboardGrid({required List<HomeRow> rows, required Widget Function(HomePanelType) panelBuilder, required double Function(HomeRow) rowHeight, Widget? leading, double spacing = 8}); }` returning a `SliverList`. `leading` is the first-dive panel, rendered as its own row after the first row.
- Each row is a `SizedBox(height: rowHeight(row))` holding a `Row` with `crossAxisAlignment: CrossAxisAlignment.stretch` and one `Expanded(flex: units)` per panel. No `IntrinsicHeight`.
- Rows keep the existing `_GridRow` (keep-alive, gap below the row) and are keyed by their first panel: `ValueKey<HomePanelType>(row.panels.first)`.

- [ ] **Step 1: Write the failing tests**: at 1280 wide every row's children span the full width (sum of child widths plus gaps equals the sliver's width); two panels in a row have equal heights; a row added above does not dispose the state of a stateful panel below (the existing keep-alive test, adapted); `leading` renders second; an empty row list renders nothing.
- [ ] **Steps 2-4:** run to fail, implement, run to pass.
- [ ] **Step 5: Commit** `feat(dashboard): fixed-height lazy rows`

### Task 14: The page

**Files:**
- Rewrite: `lib/features/dashboard/presentation/pages/dashboard_page.dart`
- Rewrite: `test/features/dashboard/presentation/pages/dashboard_page_test.dart`

**Interfaces:**
- Consumes: everything above.
- Behaviour:
  - Read `homePanelOrder`, `hiddenHomePanels`, `hiddenHomeCards` with `settingsProvider.select`, and call `resolveHomeLayout`.
  - For each conditional panel that is not hidden, watch its provider and include the panel only once it resolves to content (keep the `show` and `watchUnlessHidden` helpers and the "map waits for the first photo result" rule). A hidden panel's provider is not watched.
  - `packHomeRows(visible, homeWidthTierOf(context))`; row height is `KeyNumbersPanel.heightFor` for the key numbers row and `homeRowHeight(row.height)` otherwise.
  - Slivers, in order: `DemoModeDashboardCard`; a pinned `SliverPersistentHeader` holding `HomeHeaderBar` (and `HomeStatusStrip` on a phone); then the grid in 12 pixels of padding, or the existing all-hidden message when no panel is visible.
  - The first-dive panel is passed as `leading` when `diveStatisticsProvider` resolves to zero dives.
  - Pull to refresh invalidates every provider Home reads, including all of Task 6's.
  - `_hasSafetyAlert` and the forced gauge strip are removed; the header is always present.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('nothing stored shows the Balanced panels in order', ...);
testWidgets('a hidden panel's provider is never built', ...); // counter pattern from the current test
testWidgets('conditional panels with no content are absent', ...);
testWidgets('zero dives shows the first-dive panel under key numbers', ...);
testWidgets('all panels hidden shows the header and the customise link', ...);
testWidgets('pull to refresh refetches', ...);
testWidgets('no layout errors at 320, 390, 799, 800, 1199, 1200 and 1600 wide', (tester) async {
  for (final w in [320.0, 390.0, 799.0, 800.0, 1199.0, 1200.0, 1600.0]) {
    // set view size, pump with every panel visible and populated
    expect(tester.takeException(), isNull, reason: 'width $w');
  }
});
testWidgets('no overflow at text scale 2.0 on a phone with every panel on', ...);
testWidgets('switching diver refetches the panels', ...);
```

Lazy rows: find panels below the fold with `skipOffstage: false` or a tall `tester.view.physicalSize`.

- [ ] **Steps 2-4:** run to fail, implement, run to pass.
- [ ] **Step 5: Commit** `feat(dashboard): Home as a technical dashboard`

### Task 15: Settings page, key numbers page, removal of the old Home

**Files:**
- Modify: `lib/features/settings/presentation/pages/home_appearance_page.dart`; its test
- Create: `lib/features/settings/presentation/pages/home_key_numbers_page.dart`; its test
- Modify: `lib/core/router/app_router.dart` (child route `key-numbers` under `/settings/appearance/home`; check the desktop `_sectionHubEntries` special case for Home still reaches the page) and `test/core/router/app_router_test.dart`
- Delete: the files listed under "Deleted at the end" and their tests; fix every remaining import

**Interfaces:**
- Consumes: Tasks 3 and 4.
- Behaviour, from the spec's Presets and customisation section. Details left open there:
  - The picker is four tiles in a row (two by two under 360 wide). Each thumbnail is painted from `packHomeRows(homePresetPanels(p), HomeWidthTier.desktop)`, first four rows.
  - The highlighted tile is `matchingPreset(layout)`.
  - Choosing a preset when the layout is Custom asks first (title, message, Cancel, Replace); otherwise it applies at once. Applying calls `setHomePanelLayout` with `homeLayoutForPreset`.
  - The list shows the layout's `order`; the switch is on when the panel is not hidden; a reorder or toggle calls `setHomePanelLayout` with the whole new order and hidden set. Use `onReorderItem` (not the deprecated `onReorder`).
  - Conditional panels keep the "shows only when there is something to show" subtitle.
  - Key numbers is a row whose trailing chevron opens the sub-page; the sub-page is a list of `SwitchListTile`s, one per `HomeKeyNumber`.
  - Reset to default applies Balanced, behind the existing confirm dialog.
  - Safety chips in the status-light section are shown as always on and disabled.

- [ ] **Step 1: Write the failing tests**: Balanced is highlighted on a fresh install; toggling a panel off clears the highlight and persists; picking Trends from a Custom layout asks, and Cancel changes nothing; picking Trends from Balanced applies without asking; reordering persists the new order; the key numbers sub-page toggles a tile; the three safety switches are disabled; the page scrolls to its last section at 800 by 600 (`scrollUntilVisible`).
- [ ] **Steps 2-4:** run to fail, implement, delete the old files, run `flutter analyze` (whole repo) to zero issues, run the changed test files to pass.
- [ ] **Step 5: Commit** `feat(settings): home layout presets, panel list and key numbers`

### Task 16: Strings in all locales

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the 10 other ARB files; regenerate

Read the project's localisation notes (`docs/` and the l10n memory index) before starting; the pre-push hook checks generated l10n is not stale.

- [ ] **Step 1:** Collect every string added in Tasks 7 to 15 (they were added to `app_en.arb` as each task needed them) and remove every `dashboard_*` and `settings_homeCards_*` key that no longer has a user. Confirm with a search of `lib/` for each removed key.
- [ ] **Step 2:** Add the new keys, translated, to the other 10 ARB files, keeping placeholders and plural forms intact. Preset names: Balanced, Ready, Trends, Logbook.
- [ ] **Step 3:** Run `flutter gen-l10n`, then `flutter analyze`. Expected: zero issues and no untranslated-message warnings.
- [ ] **Step 4:** Run the locale-sensitive tests changed in this branch once more.
- [ ] **Step 5: Commit** `feat(l10n): strings for the new Home in all locales`

### Task 17: Finish

- [ ] **Step 1:** Search `docs/` for descriptions of Home (cards, the gauge strip, quick actions, the Home settings page) and update them to match.
- [ ] **Step 2:** `dart format .`, `flutter analyze`, and every test file created or changed in this branch, by path.
- [ ] **Step 3:** Walk the spec section by section and confirm each requirement has a test or a visible result; fix any gap.
- [ ] **Step 4:** Capture the after screenshots with the headless harness used for the before set (desktop light and dark, phone; plus the Settings page), using seeded data.
- [ ] **Step 5: Commit** `docs: describe the new Home`

---

## Spec amendments made while planning

- Depth mix covers all dives, not this year: the depth bands the app already computes are career-wide.
- The selected preset is derived by comparing the visible panels with each preset, not stored; a stored name could go stale when a preset changes in a later version.
- Recent photos is an S list panel, not M, so photos, sites and on this day share one desktop row as in the approved mockup (at M the three would need 14 units).
