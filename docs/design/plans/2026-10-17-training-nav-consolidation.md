# Training Nav Consolidation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Certifications and Courses nav entries with one Training entry whose screen hosts both as swipeable tabs that keep their place.

**Architecture:** `/certifications` and `/courses` both build the same `TrainingPage` host under one constant page key, so the Navigator updates the host in place when the address changes and both tabs stay mounted. The host drives a `TabController` + `TabBarView` (swipe on phone only), keeps the address in step with the tab, and scopes each tab's `MasterDetailScaffold` to its own path so a hidden tab ignores the other tab's `?selected=`. The header switch is Equipment's title switch, generalized into a shared widget.

**Tech Stack:** Flutter, go_router 17.5, Riverpod, ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-10-17-training-nav-consolidation-design.md` (issue #3437)

## Global Constraints

- Nav label "Training"; More-sheet subtitle "Certifications and courses"; placed where Certifications is now (after Dive Centers); the Courses entry after Documents is removed.
- Nav entry: id `training`, icon `Icons.school_outlined` / `Icons.school`, accent `certifications`.
- `/certifications/...` and `/courses/...` addresses unchanged; `/training` opens the Certifications tab.
- Saved orders: `certifications` and `courses` both read as `training`; the save writes only `certifications` after `training`.
- Training opens on Certifications from the nav; it never remembers the last tab across visits.
- Swipe between tabs on phone layouts only; desktop switches by click.
- Courses tab is built on first visit, then kept alive.
- A tab switch replaces the current page (`goInPlace`); back never goes to the other tab.
- Each tab header keeps its own accent icon (certifications: `Icons.card_membership`, courses: `Icons.school`).
- New strings in all 11 ARB files (`lib/l10n/arb/app_*.arb`), then `flutter gen-l10n`. `nav_coursesSubtitle` removed from all 11.
- Repo rules: no em dashes anywhere, no AI attribution, `dart format .`, `flutter analyze`, files under 800 lines where new, `p.join` for paths, tests restore global state.

## Review Focus

1. **Large text on a phone:** at text scale 1.5 the phone app bar with the switch must not overflow or clip the names (test in Task 5).
2. **Desktop edit in progress, then switch tabs and back:** the half-filled form is still there with its text (test in Task 6).
3. **Arriving from Home's attention chip** (`context.push('/certifications')`), switching to Courses, then back: lands on Home, not Certifications (test in Task 6).
4. **Deep link straight to `/courses?selected=<id>` on desktop:** opens on the Courses tab with that course in the detail pane, and the hidden Certifications tab shows its summary, not a lookup of a course id (test in Task 6).
5. **A list root pushed while a Training host is on the stack** would give the Navigator two pages with the same key. Today the only root push is Home's attention chip (`certification_attention_navigation.dart`), which cannot sit above Training. Pin that with a source scan so a new root push fails a test instead of crashing (test in Task 1).

---

### Task 1: Training locations and the stay-mounted host page

**Files:**
- Create: `lib/core/router/training_locations.dart`
- Test: `test/core/router/training_locations_test.dart`

**Interfaces:**
- Produces:
  - `const String kTrainingLocation = '/training';`
  - `enum TrainingTab { certifications('/certifications', 'certifications'), courses('/courses', 'courses'); final String path; final String featureId; }`
  - `TrainingTab? trainingTabForPath(String path)`: the tab whose `path` equals `path` exactly, else null.
  - `const ValueKey<String> kTrainingHostPageKey = ValueKey('training-host');`
  - `Page<void> trainingHostPage(Widget child)`: `NoTransitionPage<void>(key: kTrainingHostPageKey, child: child)`.

- [ ] **Step 1: Write the failing tests**

In a test `GoRouter` with `/certifications` and `/courses` both returning `trainingHostPage(_Probe(tab))` (a `StatefulWidget` whose `State` records `initState` calls in a list and shows `widget.tab.name`), plus a child route `/certifications/:id` returning a plain page:

```dart
testWidgets('go between tabs keeps the host State', ...) // go('/courses'): initStateCalls == 1, text 'courses'
testWidgets('replace between tabs on a pushed host keeps the State', ...) // initial '/home', push('/certifications'), replace('/courses'): initStateCalls == 1; pop() lands on '/home'
testWidgets('pushing a detail and popping keeps the host State', ...) // push('/certifications/x'), pop(): initStateCalls == 1
test('trainingTabForPath matches list roots only', () {
  expect(trainingTabForPath('/certifications'), TrainingTab.certifications);
  expect(trainingTabForPath('/courses'), TrainingTab.courses);
  expect(trainingTabForPath('/certifications/abc'), isNull);
  expect(trainingTabForPath('/training'), isNull);
});
test('no code pushes a Training list root except the Home attention chip', ...)
```

The last test scans `lib/` (use `p.join`) for `push(` calls whose string argument is exactly `'/certifications'`, `'/courses'` or either followed by `?`, and expects the only hit to be `lib/features/certifications/presentation/certification_attention_navigation.dart`. Its failure message explains the duplicate page key.

- [ ] **Step 2: Run, expect FAIL** (`flutter test test/core/router/training_locations_test.dart`: file does not compile).
- [ ] **Step 3: Implement `training_locations.dart`** with the doc comment on `kTrainingHostPageKey` explaining why one key serves both addresses (the Navigator updates a page with an equal key in place, so the host's State survives).
- [ ] **Step 4: Run, expect PASS.** If the replace test fails, stop and rethink the mechanism before any other task (the spec calls this the risky part).
- [ ] **Step 5: Commit** `feat(training): host page key that survives a switch between tab addresses`

### Task 2: Nav entry, id migration and header icons

**Files:**
- Modify: `lib/shared/widgets/nav/nav_destinations.dart` (replace the `certifications` entry at its position with `training`, delete the `courses` entry)
- Modify: `lib/shared/widgets/nav/nav_id_aliases.dart`
- Modify: `lib/shared/widgets/feature_accent.dart:123-128` (`_navDestination` lookup)
- Modify: `lib/core/router/app_router.dart` (add the `/training` redirect)
- Modify: all 11 `lib/l10n/arb/app_*.arb`, then regenerate
- Test: `test/shared/widgets/nav/nav_id_alias_test.dart`, `nav_normalize_test.dart`, `nav_selection_test.dart`, `nav_destinations_test.dart`, `rail_destination_order_test.dart`, `test/shared/widgets/feature_accent_test.dart` (create if absent)

**Interfaces:**
- Consumes: `kTrainingLocation`, `TrainingTab.path` (Task 1).
- Produces: nav id `training`; l10n getters `nav_training`, `nav_trainingSubtitle`; `kRenamedNavIds` entries `'certifications': 'training'`, `'courses': 'training'` (in that order).

- [ ] **Step 1: Write the failing tests**

```dart
// nav_normalize_test
expect(normalizeNavOrder(stored: ['dives', 'courses', 'sites'], movableIds: movableNavIds).take(3), ['dives', 'training', 'sites']);
expect(normalizeNavOrder(stored: ['certifications', 'dives', 'courses'], ...).take(2), ['training', 'dives']); // courses dropped as duplicate
expect(normalizeNavOrder(stored: ['courses', 'certifications'], ...).first, 'training');
// nav_id_alias_test
expect(withLegacyNavIds(['dives', 'training']), ['dives', 'training', 'certifications']);
expect(withLegacyNavIds(['tracks']), ['tracks', 'gps-log']); // unchanged behaviour
// nav_selection_test: Training is the best match for each of
// '/training', '/certifications', '/certifications/wallet', '/certifications/abc/edit', '/courses', '/courses/abc'
// nav_destinations_test / rail_destination_order_test: canonical order has 'training' where
// 'certifications' was, and neither 'certifications' nor 'courses' is an id
// feature_accent_test: with section-header accents on, FeatureAppBarTitle(featureId: 'courses')
// shows Icons.school and featureId: 'certifications' shows Icons.card_membership
```

- [ ] **Step 2: Run the five nav test files and the accent test, expect FAIL.**
- [ ] **Step 3: Implement**
  - `training` destination: `route: kTrainingLocation`, `extraMatchPaths: [TrainingTab.certifications.path, TrainingTab.courses.path]`, `accent: 'certifications'`, icons and l10n per Global Constraints. Add a top-level `GoRoute(path: kTrainingLocation, redirect: (_, _) => TrainingTab.certifications.path)` in `lib/core/router/app_router.dart` so tapping the entry opens Certifications from this commit on.
  - `withLegacyNavIds`: build `legacyFor` with `putIfAbsent`, so the first old id listed for a new id is the one written back; update the doc comments on both declarations to cover a merge as well as a rename.
  - `FeatureAppBarTitle`: look up the nav destination first, then a `const Map<String, IconData> _kRetiredSectionIcons = {'certifications': Icons.card_membership, 'courses': Icons.school}` for sections that kept their headers but lost their own nav entry.
  - ARB: add `nav_training` ("Training") and `nav_trainingSubtitle` ("Certifications and courses") with `@` descriptions in `app_en.arb`; translate into ar, de, es, fr, he, hu, it, nl, pt, zh; delete `nav_coursesSubtitle` and its `@` entry from all 11. Run `flutter gen-l10n`.
- [ ] **Step 4: Run the tests, expect PASS.** Then run `flutter test test/shared/widgets/nav test/shared/widgets/main_scaffold* test/features/settings` and update any expectation that named the old ids or the old labels as nav entries.
- [ ] **Step 5: Commit** `feat(nav): one Training entry replaces Certifications and Courses`

### Task 3: Shared section title switch

**Files:**
- Create: `lib/shared/widgets/section_title_toggle.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_section_toggle.dart` (becomes a wrapper)
- Test: `test/shared/widgets/section_title_toggle_test.dart`; existing `test/features/equipment/presentation/**` must stay green unchanged

**Interfaces:**
- Produces:
  - `SectionTitleToggle({Key? key, required TabController controller, required String featureId, required List<String> labels, double tabHeight = defaultTabHeight, Key? tabBarKey})`
  - Statics moved from `EquipmentSectionToggle` with labels and feature id as parameters: `defaultTabHeight`, `compactTabHeight`, `indicatorWeight`, `pillHeight`, `labelPadding`, `heightFor(double)`, `textInset({required bool withAccentIcon})`, `showsAccentIcon(BuildContext, WidgetRef, {required String featureId})`, `naturalWidth(BuildContext, TextStyle, {required List<String> labels, required bool withAccentIcon})`, `fittedTabHeight(BuildContext, TextStyle, {required List<String> labels, required double minHeight, TextScaler? textScaler})`.
  - `EquipmentSectionToggle` keeps its exact public API (constructor, statics, the `ValueKey('equipment_section_toggle')` on its TabBar) and delegates every member to `SectionTitleToggle` with featureId `'equipment'` and its two labels.

- [ ] **Step 1: Write the failing test**: `SectionTitleToggle(featureId: 'courses', labels: ['A', 'B'], controller: c)` renders two `Tab`s with texts A and B; tapping B sets `c.index == 1`; the TabBar carries `tabBarKey`; `naturalWidth` grows when a label grows.
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Move the implementation** (colours still come from `EquipmentSectionColors`; it is already used outside Equipment). Keep the existing doc comments on the moved members.
- [ ] **Step 4: Run** the new test and `flutter test test/features/equipment test/shared/widgets/app_bar_tab_metrics_test.dart`; expect PASS with no Equipment test edited.
- [ ] **Step 5: Commit** `refactor(equipment): share the section title switch`

### Task 4: Scope a master-detail pane to its own path

**Files:**
- Create: `lib/shared/widgets/master_detail/master_detail_route_scope.dart`
- Modify: `lib/shared/widgets/master_detail/master_detail_scaffold.dart:205-228` (`_selectedId`, `_mode`, `_isMapView`)
- Test: `test/shared/widgets/master_detail/master_detail_route_scope_test.dart`

**Interfaces:**
- Produces: `class MasterDetailRouteScope extends InheritedWidget { const MasterDetailRouteScope({Key? key, required String path, required Widget child}); final String path; static String? pathOf(BuildContext context); }`
- Behaviour: with no scope, `MasterDetailScaffold` is unchanged. With a scope, the scaffold reads query parameters from the URL only while `uri.path == path`, remembers them, and keeps using the remembered ones while the URL is elsewhere. `TableModeLayout` builds a `MasterDetailScaffold`, so it inherits this with no change.

- [ ] **Step 1: Write the failing tests** (test `GoRouter` with `/a` and `/b`, a scaffold under `MasterDetailRouteScope(path: '/a')`, desktop size):
  - At `/a?selected=1` the detail builder gets `'1'`; after `go('/b?selected=2')` it still shows `'1'` and was never asked for `'2'`.
  - At `/a?selected=1&mode=edit` then `/b`, the edit builder is still shown for `'1'`.
  - Without a scope, `go('/b?selected=2')` shows `'2'` (unchanged behaviour).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** a `_query` getter in the scaffold state that applies the rule above and replaces the three direct `state.uri.queryParameters` reads.
- [ ] **Step 4: Run** the new test and `flutter test test/shared/widgets/master_detail test/shared/widgets/table_mode_layout`; expect PASS.
- [ ] **Step 5: Commit** `feat(master-detail): pane scoped to its own path keeps its selection`

### Task 5: Header title hook on both list screens

**Files:**
- Create: `lib/shared/widgets/section_header_title.dart`
- Modify: `lib/features/certifications/presentation/widgets/certification_list_content.dart` (phone `AppBar` title near line 268, `_buildCompactAppBar` near line 515)
- Modify: `lib/features/courses/presentation/widgets/course_list_content.dart` (phone `AppBar` title near line 204, `_buildCompactAppBar`)
- Modify: `lib/features/certifications/presentation/pages/certification_list_page.dart`, `lib/features/courses/presentation/pages/course_list_page.dart` (forward the hook to the list content in all three layouts)
- Modify: `lib/shared/widgets/table_mode_layout/table_mode_layout.dart` (lines 228 and 516 render `Text(appBarTitle)`)
- Test: `test/features/certifications/presentation/pages/certification_list_page_test.dart`, `test/features/courses/presentation/pages/course_list_page_test.dart`, `test/shared/widgets/table_mode_layout/table_mode_layout_title_test.dart`

**Interfaces:**
- Produces:
  - `enum SectionHeaderSlot { appBar, pane, table }`
  - `class SectionHeaderTitle { const SectionHeaderTitle({required this.build, required this.appBarHeight}); final Widget Function(BuildContext context, SectionHeaderSlot slot, SubtitleText? subtitle) build; final double Function(BuildContext context, SubtitleText? subtitle) appBarHeight; }`
  - New optional param `SectionHeaderTitle? headerTitle` on `CertificationListContent`, `CourseListContent`, `CertificationListPage`, `CourseListPage`.
  - New optional param `Widget? appBarTitleWidget` on `TableModeLayout`, used in place of `Text(appBarTitle)` in both places when set (`appBarTitle` stays required for semantics and tests).
- Behaviour when `headerTitle` is set:
  - Phone app bar: title is `headerTitle.build(context, SectionHeaderSlot.appBar, countSubtitle)`, `toolbarHeight: headerTitle.appBarHeight(context, countSubtitle)`, and the actions move to a second row under the title (`AppBar.bottom`, a `kMinInteractiveDimension` row, actions right-aligned) because five actions and two section names do not fit one phone row.
  - Desktop pane bar: title is `build(context, SectionHeaderSlot.pane, countSubtitle)`; the icons move to a second row under it for the same reason.
  - Table mode: the page passes `appBarTitleWidget: headerTitle.build(context, SectionHeaderSlot.table, null)`; one row (the table header is wide).
  - When `headerTitle` is null, every header is exactly as today.

- [ ] **Step 1: Write the failing tests**: for each list page, with a `headerTitle` whose `build` returns `Text('HEADER-<slot.name>')`, the phone layout shows `HEADER-appBar`, the desktop layout (`tester.view.physicalSize` set to a master-detail width, restored in `addTearDown`) shows `HEADER-pane`, table mode shows `HEADER-table`, and the wallet and search actions are still findable in each. With `headerTitle` null the existing title text still shows. At text scale 1.5 on a 360px phone, no overflow exception (Review Focus 1).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** `certification_list_content.dart` is already 1041 lines: put the two-row header assembly in a new shared widget `lib/shared/widgets/section_header_rows.dart` (`SectionHeaderRows({required Widget title, required List<Widget> actions})` for the pane bar, plus a helper returning the `AppBar` `bottom`) so each list content gains only the branch that calls it.
- [ ] **Step 4: Run** both list page tests, the table title test, and `flutter test test/features/certifications test/features/courses`; expect PASS.
- [ ] **Step 5: Commit** `feat(certifications): list headers accept a section title`

### Task 6: The Training host page and its routes

**Files:**
- Create: `lib/features/training/presentation/pages/training_page.dart`
- Create: `lib/features/training/presentation/widgets/training_section_toggle.dart`
- Modify: `lib/core/router/app_router.dart:829-835` and `:917-923` (list roots)
- Test: `test/features/training/presentation/pages/training_page_test.dart`, `test/core/router/training_routes_test.dart`

**Interfaces:**
- Consumes: Task 1 (`TrainingTab`, `trainingTabForPath`, `trainingHostPage`, `kTrainingLocation`), Task 3 (`SectionTitleToggle`), Task 4 (`MasterDetailRouteScope`), Task 5 (`SectionHeaderTitle`, `headerTitle`), `goInPlace` from `lib/core/router/section_navigation.dart`.
- Produces:
  - `typedef TrainingTabBodyBuilder = Widget Function(BuildContext context, TrainingTab tab, SectionHeaderTitle headerTitle);`
  - `TrainingPage({Key? key, required TrainingTab tab, TrainingTabBodyBuilder? tabBodyBuilder})`. The default body builder returns `CertificationListPage(headerTitle: ...)` / `CourseListPage(headerTitle: ...)`.
  - `TrainingSectionToggle({Key? key, required TabController controller, required TrainingTab tab, double tabHeight})`: a `SectionTitleToggle` with labels `[l10n.nav_certifications, l10n.nav_courses]`, `featureId: tab.featureId`, `tabBarKey: ValueKey('training_section_toggle')`.
- Behaviour:
  - Routes: `/certifications` and `/courses` list roots use `pageBuilder: (c, s) => trainingHostPage(TrainingPage(tab: ...))`; their child routes are untouched. (`/training` already redirects, from Task 2.)
  - `TabController(length: 2, initialIndex: widget.tab.index)`. `didUpdateWidget` with a new `tab` animates the controller there (an address change, such as a deep link or the nav, selects the tab).
  - A controller change that did not come from `didUpdateWidget` (a tap or a swipe) calls `context.goInPlace(tab.path + remembered query)`. The host remembers each tab's last query string from `GoRouterState.of(context).uri` whenever the path equals that tab's path.
  - `TabBarView` children: each tab body is wrapped in a keep-alive widget and a `MasterDetailRouteScope(path: tab.path)`. Physics: `NeverScrollableScrollPhysics` when `ResponsiveBreakpoints.isMasterDetail(context)`, default otherwise. The Courses body is a `SizedBox.shrink()` until the Courses tab has been shown once.
  - The header title passed to each body builds a `TrainingSectionToggle` (`compactTabHeight` in the `appBar` slot, default height elsewhere) inside `TitleWithSubtitle` with `subtitleIndent: SectionTitleToggle.textInset(...)`; `appBarHeight` returns `max(kToolbarHeight, toggle height + subtitle line height)` measured at the app bar's clamped text scale, as `equipment_list_page.dart` `_phoneToolbarHeight` does.

- [ ] **Step 1: Write the failing tests** (`training_page_test.dart` uses a test `GoRouter` built with `trainingHostPage` and a `tabBodyBuilder` that returns a 100-item `ListView` per tab with a `TextField` and a `Text('built-<tab>')` counter):
  - Opens on Certifications; `built-courses` is absent until Courses is shown.
  - Tapping "Courses" changes the location to `/courses`; tapping "Certifications" goes back to `/certifications`.
  - Phone: a horizontal fling switches to Courses and the location follows. Desktop: the same fling leaves the tab unchanged.
  - Scroll Certifications to item 60, type "abc" in its field, switch to Courses and back: item 60 still visible, field still "abc".
  - `go('/courses')` from outside selects the Courses tab.
  - Desktop: `/certifications?selected=1`, switch to Courses, switch back: location is `/certifications?selected=1` again.
  - Review Focus 3: start at `/home`, `push('/certifications')`, tap Courses, `pop()`: location `/home`.
  - `training_routes_test.dart`, using the real `appRouter` routes with the providers mocked the way `certification_list_page_test.dart` and `course_list_page_test.dart` mock them: `/training` lands on `/certifications` with the toggle present; Review Focus 4 (`/courses?selected=<id>` on desktop opens the Courses tab with that course's detail, and the Certifications pane shows its summary); Review Focus 2 (desktop: open a certification's edit form, type into its name field, switch to Courses and back, the typed text is still there).
- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** `training_section_toggle.dart`, then `training_page.dart` (aim under 300 lines), then the router change.
- [ ] **Step 4: Run** both new test files, then `flutter test test/core/router test/features/certifications test/features/courses test/shared`; expect PASS. Run `test/architecture/` (new files under `lib/`).
- [ ] **Step 5: Commit** `feat(training): Certifications and Courses as swipeable tabs that keep their place`

### Task 7: Whole-branch checks and screenshots

- [ ] **Step 1:** `dart format .`, `flutter analyze` (zero issues), `flutter test test/architecture test/shared test/core test/features/certifications test/features/courses test/features/equipment test/features/settings` with output logged to the scratchpad.
- [ ] **Step 2:** Grep the diff for em dashes and for any AI-tool mention; expect none.
- [ ] **Step 3:** Launch the app (run skill) and capture after screenshots matching the before set: nav rail (desktop, light and dark), More sheet with the Training subtitle (phone), Certifications tab and Courses tab (phone and desktop), table mode with the switch (desktop).
