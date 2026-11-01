# Compare: plan against dive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task, inline. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put the plan beside the dive and its what-ifs on dive detail and the Compare page, join a saved plan to a logged dive by hand from either side, and let a download fill a planned dive from the day before.

**Architecture:** A pure domain layer turns each line (plan, dive, what-if) into one `CompareColumn` with shared definitions. Providers assemble columns per dive. A new `CompareSection` replaces `DiveLabSection`, and `DiveLabPage` gains the Planned line, table, schedule and link actions. Links live in `DivePlans.linkedDiveId` and go through two new repository methods.

**Tech Stack:** Flutter, Riverpod, Drift, fl_chart via `DiveProfileChart`, ARB l10n in 11 locales.

**Spec:** `docs/design/specs/2026-10-31-compare-plan-vs-dive-design.md` (issue #4003). Read "Settled while building" first; it overrides anything earlier in the document.

## Global Constraints

- No schema change, no new table, no new column. No em-dashes anywhere, including ARB strings and docs.
- Code identifiers stay: `dive_lab`, `diveLab_`, `whatIf`, `DiveDetailSectionId.diveLab`, `openWhatIf`.
- New l10n keys are added to all 11 ARB files, feature-grouped, anchored on a neighbouring key of the same group, then `flutter gen-l10n`.
- Every displayed depth goes through `UnitFormatter`; no literal units. Times use `formatLabTime` and `formatLabMinutes`.
- Every SnackBar with an action states `persist`.
- Paths in tests use `p.join` and `Directory.systemTemp`; a test that replaces global state restores it.
- `lib/` files stay under 800 lines. New files go in the feature that owns them.
- Before each commit: `dart format .`, `flutter analyze` over the whole repo, the affected tests, and `test/architecture/` plus `test/shared/` when a `lib/` file was added. Multi-file runs log to the scratchpad. Stage explicit paths.
- Commits are scoped `feat(dive-lab)`, `feat(planner)` or `feat(dive-import)`. No attribution trailers.

## Review Focus

1. A plan open in the planner while its link changes from the dive side: a later Save must not write the stale link back. Test in Task 2.
2. The plan or the dive deleted while the section is on screen: the Planned chip and column leave live, with no error. Test in Task 6.
3. A linked plan with no segments, or one the engine cannot compute: the Planned column is blank, never zeros, and the chart draws no line. Test in Task 4.
4. A dive with withheld tissue loading, or no profile: `ndlCurve` and `decoStatuses` are empty, so those cells are blank and nothing indexes past the end. Test in Task 4.
5. Five columns on a 360 px phone in German: the table scrolls sideways and nothing overflows. Test in Task 6.

---

### Task 1: Planned pass window

**Files:**
- Modify: `lib/features/dive_computer/domain/services/planned_dive_matcher.dart`
- Modify: `lib/features/import_wizard/data/adapters/dive_computer_adapter.dart:746` (comment)
- Modify: `lib/features/dive_import/domain/services/dive_matcher.dart:130` (comment)
- Test: `test/features/dive_computer/domain/services/planned_dive_matcher_test.dart`

**Interfaces:**
- Produces: `PlannedDiveMatcher.pair` keeps its signature and return type.

- [ ] **Step 1: Write the failing tests**

Change `a download after midnight leaves the previous evening's plan` to expect `{0: 'p'}` and rename it `a download after midnight fills the previous evening's plan`. Add:

```dart
test('rejects a plan two days before the download', () {
  final pairs = matcher.pair(
    incomingStarts: [DateTime.utc(2026, 9, 16, 9)],
    plannedDives: [planned('p', DateTime.utc(2026, 9, 14, 23))],
  );
  expect(pairs, isEmpty);
});

test('rejects a plan on the day after the download', () {
  final pairs = matcher.pair(
    incomingStarts: [DateTime.utc(2026, 9, 14, 23)],
    plannedDives: [planned('p', DateTime.utc(2026, 9, 15, 1))],
  );
  expect(pairs, isEmpty);
});

test('after midnight the previous night beats the next morning', () {
  final pairs = matcher.pair(
    incomingStarts: [DateTime.utc(2026, 9, 15, 0, 30)],
    plannedDives: [
      planned('night', DateTime.utc(2026, 9, 14, 23)),
      planned('morning', DateTime.utc(2026, 9, 15, 9)),
    ],
  );
  expect(pairs, {0: 'night'});
});

test('a day-old plan loses to the same day plan closer in time', () {
  final pairs = matcher.pair(
    incomingStarts: [DateTime.utc(2026, 9, 15, 9)],
    plannedDives: [
      planned('sat', DateTime.utc(2026, 9, 14, 11)),
      planned('sun', DateTime.utc(2026, 9, 15, 8)),
    ],
  );
  expect(pairs, {0: 'sun'});
});

test('a window across a DST change still means one calendar day', () {
  // Clocks change on 2026-03-08 in US zones, 2026-03-29 in the EU.
  for (final day in [8, 29]) {
    final pairs = matcher.pair(
      incomingStarts: [DateTime.utc(2026, 3, day + 1, 1)],
      plannedDives: [planned('p', DateTime.utc(2026, 3, day, 23))],
    );
    expect(pairs, {0: 'p'});
  }
});
```

- [ ] **Step 2: Run them and confirm the new ones fail**

Run: `flutter test test/features/dive_computer/domain/services/planned_dive_matcher_test.dart`
Expected: the renamed test and the night-beats-morning test fail.

- [ ] **Step 3: Implement**

Build every (download, plan) pair whose plan day is the download's day or `DateTime(y, m, d - 1)` of it, sort by absolute start-time gap (ties: earlier download, then earlier plan), and take each pair whose download and plan are both free. Keep `_day`. Update the class doc: the rule, the wall-clock note, and that a day-before plan fits. Update the two comments that say "same local day".

- [ ] **Step 4: Run the tests, including the fill suites**

Run: `flutter test test/features/dive_computer/domain/services/planned_dive_matcher_test.dart`, then `test/features/import_wizard/data/adapters/dive_computer_adapter_fill_planned_test.dart`, then `test/features/import_wizard/presentation/providers/import_wizard_fill_planned_test.dart`, one run each.
Expected: PASS.

- [ ] **Step 5: Commit** `feat(dive-import): fill a planned dive from the day before`

### Task 2: Link and unlink in the repository and the planner state

**Files:**
- Modify: `lib/features/planner/data/repositories/dive_plan_repository.dart`
- Modify: `lib/features/planner/domain/entities/dive_plan.dart` (`DivePlanSummary`)
- Modify: `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart`
- Test: `test/features/planner/dive_plan_link_test.dart` (new)
- Test: `test/features/dive_planner/presentation/providers/dive_plan_notifier_link_test.dart` (new)

**Interfaces:**
- Produces:
  - `Future<PlanLinkResult> DivePlanRepository.linkPlanToDive(String planId, String diveId)`, with `class PlanLinkResult { final String? previousDiveId; final List<String> displacedPlanIds; }`, in one transaction: clears `linkedDiveId` on every other plan naming `diveId`, sets it on `planId`, stamps `updatedAt`, records a sync change for each row touched. Throws `ArgumentError` when the dive does not exist.
  - `Future<void> DivePlanRepository.unlinkPlan(String planId)`.
  - `DivePlanSummary` gains `linkedDiveId`, `linkedDiveNumber` (`int?`), `linkedDiveIsPlanned` (`bool`, default false), `linkedDiveDate` (`DateTime?`), all in `props`. `getAllPlanSummaries` fills them with a left outer join on `dives`.
  - `void DivePlanNotifier.adoptLink(String planId, String? diveId)`: when `planId` is the plan being edited, updates `linkedDiveId` on `state` and on `_loaded` without marking dirty; otherwise does nothing.

- [ ] **Step 1: Write the failing repository tests**

Follow `test/features/planner/dive_plan_save_deleted_dive_links_test.dart` for setup. Tests: `link then unlink round-trips and writes a sync record`; `linking a plan linked elsewhere moves the link and reports previousDiveId`; `linking a dive held by another plan clears that plan and reports it in displacedPlanIds`; `unlinking the new plan leaves the dive with no plan`; `getPlanByLinkedDiveId still picks the newest when a sync duplicate exists`; `linking a missing dive throws and changes nothing`; `getAllPlanSummaries carries the linked dive's number, planned flag and date`.

- [ ] **Step 2: Write the failing notifier tests**

`adoptLink updates the open plan without dirtying it`; `a save after adoptLink keeps the new link` (load plan, repository link, adoptLink, edit, save, read back); `adoptLink for another plan changes nothing`.

- [ ] **Step 3: Run both and confirm they fail to compile or fail**

Run each file alone.

- [ ] **Step 4: Implement**

Write through the same sync path `savePlan` uses (read how it records the change before writing). Do not route through `savePlan`: it rewrites children. Do not bump anything on the dive.

- [ ] **Step 5: Run the two files and `test/features/planner/`**

Expected: PASS.

- [ ] **Step 6: Commit** `feat(planner): link and unlink a saved plan and a dive`

### Task 3: Link from the planner

**Files:**
- Create: `lib/features/planner/presentation/plan_link_actions.dart`
- Create: `lib/features/planner/presentation/widgets/link_dive_sheet.dart`
- Modify: `lib/features/planner/presentation/widgets/saved_plans_sheet.dart`
- Modify: `lib/features/planner/presentation/pages/plan_canvas_page.dart` (menu, `_onMenu`)
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/planner/presentation/widgets/link_dive_sheet_test.dart`, `test/features/planner/presentation/widgets/saved_plans_sheet_link_test.dart`, `test/features/planner/presentation/plan_link_actions_test.dart`

**Interfaces:**
- Consumes: Task 2.
- Produces, in `plan_link_actions.dart`:
  - `Future<bool> linkPlanWithConfirm(BuildContext context, WidgetRef ref, {required String planId, required String diveId})`: looks up whether the plan is linked elsewhere and whether the dive holds another plan, shows one confirm dialog if either, calls the repository, calls `adoptLink` for the plan and each displaced plan, returns true when linked.
  - `Future<bool> unlinkPlanWithConfirm(BuildContext context, WidgetRef ref, {required String planId})`: asks first.
  - `String? planLinkBadge(AppLocalizations l10n, DivePlanSummary summary, UnitFormatter units)`: "Dived as #N"; a linked planned dive reads the waiting string; an unnumbered dive reads "Dived {date}"; null when unlinked.
- `Future<String?> showLinkDiveSheet(BuildContext context, {DateTime? planDay, String? currentDiveId})` returns a dive id. Lists `divesProvider`, planned dives excluded, newest first, dives on `planDay` first when given. Built like `follow_dive_sheet.dart`.
- l10n keys: `plannerCanvas_link_action`, `plannerCanvas_link_title`, `plannerCanvas_link_empty`, `plannerCanvas_link_changeAction`, `plannerCanvas_unlink_action`, `plannerCanvas_link_badge(number)`, `plannerCanvas_link_badgeDate(date)`, `plannerCanvas_link_badgeWaiting`, `plannerCanvas_link_saveFirst`, `diveLab_link_unlinkTitle`, `diveLab_link_unlinkBody`, `diveLab_link_moveTitle`, `diveLab_link_moveBody(plan)`, `diveLab_link_replaceTitle`, `diveLab_link_replaceBody(plan)`.

- [ ] **Step 1: Write the failing tests**

`link sheet lists the plan's day first then newest`; `link sheet leaves out planned dives`; `saved plans row offers Link to a logged dive when unlinked`; `saved plans row offers Change and Unlink when linked`; `badge reads Dived as #12`; `moving a link asks first and cancelling changes nothing` (dismiss before asserting, per the modal-dialog trap); `replacing a dive's plan names the plan it clears`; `unlink asks first`.

- [ ] **Step 2: Run them and confirm they fail**

- [ ] **Step 3: Add the ARB keys and run `flutter gen-l10n`**

- [ ] **Step 4: Implement the actions, the sheet, the saved plans row and the plan menu**

In the canvas menu: **Link to a logged dive**, or **Change linked dive** and **Unlink dive** with a "Dived as #N" subtitle when linked. Add an optional `subtitle` to `_menuItem`. The entries are disabled with the `saveFirst` tooltip until `isPersisted`. The badge shows under the subtitle of the saved plans row.

- [ ] **Step 5: Run the tests and `test/features/planner/`, `test/architecture/`, `test/shared/`**

Expected: PASS.

- [ ] **Step 6: Commit** `feat(planner): link a plan to a logged dive from the planner`

### Task 4: Compare columns (pure)

**Files:**
- Create: `lib/features/dive_lab/domain/entities/compare_column.dart`
- Create: `lib/features/dive_lab/domain/services/compare_columns.dart`
- Test: `test/features/dive_lab/domain/services/compare_columns_test.dart`

**Interfaces:**
- Produces:

```dart
enum CompareLineKind { planned, asDived, whatIf }

sealed class CompareNdl extends Equatable {}
class CompareNdlLeft extends CompareNdl { final int seconds; }
class CompareDecoAt extends CompareNdl { final int runtimeSeconds; }

class CompareColumn extends Equatable {
  final String id;              // 'planned', 'dived', or the scenario id
  final CompareLineKind kind;
  final String? title;          // the scenario name on a what-if
  final double? maxDepthMeters;
  final int? bottomTimeSeconds;
  final CompareNdl? ndl;
  final int? decoRequiredSeconds;
  final int? decoDoneSeconds;
  final int? runtimeSeconds;
  final double? surfaceGf;
  final int? decoStartSeconds;  // the chart's NDL marker
}

const double kCompareDeepPhaseFraction = 0.85;

CompareColumn? plannedColumn({
  required PlanOutcome outcome,
  required List<({int timestamp, double depth})> samples,
  required double surfacePressureBar,
});
CompareColumn divedColumn({
  required Dive dive,
  required List<DiveProfilePoint> profile,
  required ProfileAnalysis? analysis,
});
CompareColumn whatIfColumn({required DiveScenario scenario, required ScenarioOutcome outcome});

/// Whether [dived] overshoots [planned] on one row, past the tolerance.
bool overshootsPlan(CompareRow row, CompareColumn planned, CompareColumn dived);
enum CompareRow { maxDepth, bottomTime, ndl, deco, runtime, surfaceGf }
```

`plannedColumn` returns null when `outcome.schedule` is empty. The spec's "Settled while building" fixes every definition.

- [ ] **Step 1: Write the failing tests**

Build analyses with `ProfileAnalysisService` over hand-written samples so `ndlCurve` and `decoStatuses` are real (see `test/features/dive_lab/domain/services/` for the helper). Tests with computed vectors, not guessed ones:

- `a no-deco plan shows minutes left`; `a deco plan shows Deco at the first ceiling sample`
- `the deep phase ends at the last sample at 85 percent of max depth` (a 40 m dive that spends 10 minutes at 20 m reads NDL at the end of 40 m, not at 13 m)
- `a dive that hit deco reads Deco at its first negative NDL sample`
- `deco required sums the stops at the deep phase end`; `deco done counts obligation time after it`
- `a plan with no schedule has no column`; `a plan has no deco done`
- `a dive with no profile keeps max depth, bottom time and runtime and blanks the rest`
- `withheld tissue loading blanks NDL, deco and surface GF` (empty `ndlCurve`, empty `decoStatuses`)
- `a what-if branching after the bottom repeats the dive's bottom time and NDL`
- `plan surface GF reads the surfaced compartments at the plan's surface pressure`
- `overshoot ignores 0.4 m and flags 0.6 m`, likewise 29 and 31 seconds, 0.9 and 1.1 GF

- [ ] **Step 2: Run and confirm they fail**

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run and confirm they pass**

- [ ] **Step 5: Commit** `feat(dive-lab): one definition for every compare column`

### Task 5: Compare providers

**Files:**
- Create: `lib/features/dive_lab/presentation/providers/compare_providers.dart`
- Modify: `lib/features/planner/presentation/providers/plan_overlay_provider.dart`
- Test: `test/features/dive_lab/presentation/providers/compare_providers_test.dart`

**Interfaces:**
- Consumes: Task 2, Task 4, `savedScenarioOutcomeProvider`, `profileAnalysisProvider`, `diveProfileProvider`.
- Produces:

```dart
class LinkedPlanComparison {
  final domain.DivePlan plan;
  final PlanOutcome outcome;
  final ChartSourceOverlay overlay;
  final CompareColumn? column;
}
final linkedPlanComparisonProvider =
    FutureProvider.family<LinkedPlanComparison?, String>(...); // diveId
final compareLinesProvider =
    StateProvider.autoDispose.family<Map<String, bool>, String>(...); // overrides by line id
bool compareLineOn(Map<String, bool> overrides, CompareColumn column, {required bool newest});
final compareSectionVisibleProvider = Provider.family<bool, Dive>(...);
final divedColumnProvider = FutureProvider.autoDispose.family<CompareColumn, String>(...);
const List<Color> kCompareWhatIfColors = [Colors.teal, Colors.orange, Colors.pink, Colors.indigo];
```

`linkedPlanComparisonProvider` runs `PlanEngine` the way `plannedProfileOverlayProvider` does, over `getPlanByLinkedDiveId`, invalidated by `watchPlanChanges()`. `plannedProfileOverlayProvider` reads its `overlay`, so the ghost line and the column can never disagree. Default on: Planned, As dived, the newest what-if (`diveScenariosForDiveProvider` is newest first).

- [ ] **Step 1: Write the failing tests**

`no link gives null`; `a link gives the column and the overlay`; `a plan change refreshes it`; `defaults turn on Planned, As dived and the newest what-if only`; `an override wins over the default`; `the overlay provider returns the same overlay`.

- [ ] **Step 2: Run and confirm they fail**

- [ ] **Step 3: Implement**

- [ ] **Step 4: Run them, then `test/features/planner/` overlay tests**

- [ ] **Step 5: Commit** `feat(dive-lab): assemble compare lines for a dive`

### Task 6: Compare section on dive detail

**Files:**
- Create: `lib/features/dive_lab/presentation/widgets/compare_section.dart`
- Create: `lib/features/dive_lab/presentation/widgets/compare_chips.dart`
- Create: `lib/features/dive_lab/presentation/widgets/compare_table.dart`
- Create: `lib/features/dive_lab/presentation/widgets/compare_chart.dart`
- Create: `lib/features/dive_lab/presentation/widgets/link_plan_sheet.dart`
- Delete: `lib/features/dive_lab/presentation/widgets/dive_lab_section.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_detail/dive_detail_section_list.dart:293`
- Modify: `lib/features/dive_lab/presentation/what_if_entry.dart`
- Modify: `lib/features/dive_lab/presentation/lab_format.dart` (row labels, NDL text, overshoot colour)
- Modify: all 11 ARB files
- Test: `test/features/dive_lab/presentation/widgets/compare_section_test.dart`, `compare_table_test.dart`, `link_plan_sheet_test.dart`, `test/features/dive_lab/presentation/what_if_entry_test.dart`; remove `dive_lab_section_test.dart` after moving what still applies

**Interfaces:**
- Consumes: Tasks 3 to 5.
- Produces:
  - `CompareSection({required String diveId})`
  - `CompareTable({required List<CompareColumn> columns, required UnitFormatter units, void Function(CompareColumn)? onOpenColumn})`, also used by the page.
  - `Future<void> showLinkPlanSheet(BuildContext context, {required String diveId})`
  - `Future<void> openWhatIf(BuildContext context, Dive dive)` keeps its signature; it reads the linked plan and routes to the page for an eligible dive or a dive with a link, else the rebuild sheet.
- l10n keys: `diveLab_compare_line_planned`, `diveLab_compare_line_asDived`, `diveLab_compare_addWhatIf`, `diveLab_compare_row_maxDepth`, `diveLab_compare_row_bottomTime`, `diveLab_compare_row_ndl`, `diveLab_compare_row_deco`, `diveLab_compare_row_runtime`, `diveLab_compare_row_surfaceGf`, `diveLab_compare_ndlLeft(minutes)`, `diveLab_compare_decoAt(time)`, `diveLab_compare_decoDone(required, done)`, `diveLab_compare_empty` ("Nothing to compare yet"), `diveLab_compare_askWhatIf` ("Ask a what-if"), `diveLab_compare_linkPlan` ("Link a plan"), `diveLab_compare_unlinkPlan` ("Unlink plan"), `diveLab_compare_waiting` ("Waiting for the dive"), `diveLab_compare_linkPlan_title`, `diveLab_compare_linkPlan_empty`.

Section behaviour, from the spec: chips across the top; chart then table, side by side from 720 px; tapping the title or chart opens the page. The chart is `DiveProfileChart` with overlays, wrapped in `IgnorePointer` under a tap target, `highlightedTimestamp` set to the dive's `decoStartSeconds`. Check how `LabChart`'s ghost is dashed and pass the plan the same way; if overlays carry no dash setting, add `dashed` to `ChartSourceOverlay`, defaulting to the current behaviour. Past three columns the table scrolls sideways with the row labels fixed.

`dive_detail_section_list.dart` shows the section for an eligible dive or a dive with a link: add `DiveDetailSectionId.diveLab` to `_selfSpacingSections` and pass the gap through, because the link arrives after build. A planned dive shows the waiting line alone.

- [ ] **Step 1: Write the failing tests**

`Planned chip shows only with a link`; `section appears for a profile-less dive with a link`; `section stays away from an ineligible dive with no link`; `chips toggle their column`; `opens with Planned, As dived and the newest what-if`; `blank cell where a column has no value`; `empty state offers Ask a what-if and Link a plan`; `planned dive reads Waiting for the dive with no what-if controls`; `tapping a what-if header opens it on the page`; `tapping the title opens the page`; `the Planned column leaves when the plan is deleted`; `the Planned column leaves when the link is cleared`; `overshoot tints the dived cell`; `imperial units in the table`; `five columns at 360 px in German scroll and do not overflow` (measure, per the overflow trap); `Link a plan lists unlinked first, newest first, then linked greyed`; `picking a linked plan confirms the move`; `openWhatIf routes a linked gauge dive to the page`.

- [ ] **Step 2: Run them one file at a time and confirm they fail**

- [ ] **Step 3: Add the ARB keys and run `flutter gen-l10n`**

- [ ] **Step 4: Implement the table and chips, then the chart, then the section and sheet, then routing**

- [ ] **Step 5: Run the tests, `test/features/dive_log/presentation/widgets/dive_detail/`, `test/architecture/`, `test/shared/`**

Expected: PASS. The sections tripwire still keeps `dataSources` last.

- [ ] **Step 6: Commit** `feat(dive-lab): compare plan, dive and what-ifs on dive detail`

### Task 7: Compare page

**Files:**
- Modify: `lib/features/dive_lab/presentation/pages/dive_lab_page.dart`
- Modify: `lib/features/dive_lab/presentation/widgets/lab_chart.dart`
- Modify: `lib/features/dive_lab/presentation/widgets/lab_delta_panel.dart`
- Create: `lib/features/dive_lab/presentation/widgets/compare_plan_only_body.dart`
- Modify: all 11 ARB files
- Test: `test/features/dive_lab/presentation/pages/dive_lab_page_compare_test.dart`, `test/features/dive_lab/presentation/widgets/lab_delta_panel_test.dart`

**Interfaces:**
- Consumes: Tasks 3, 5, 6.
- Produces: `LabChart` gains `ChartSourceOverlay? planOverlay`. `LabDeltaPanel` gains `List<CompareColumn> planColumns` (shown as the Planned table above the delta header) and `PlanOutcome? plannedOutcome` (a second runtime table under `diveLab_compare_plannedSchedule`). `CompareChips` is reused with the Planned chip alone.
- l10n keys: `diveLab_compare_plannedSchedule`, `diveLab_compare_planTable`.

Page behaviour, from the spec: the overflow gains **Link a plan** and **Unlink plan** above the share actions, and they work with no draft seeded. Save, Saved and the share and planner entries are hidden on a plan-only page. `DiveLabPage` picks its body: `dive.isPlanned` shows the waiting line; `inputs == null` with a link shows `ComparePlanOnlyBody` (chart when the dive has a profile, Planned table with As dived, planned schedule); `inputs == null` with no link keeps `diveLab_empty_ineligible`; otherwise `_LabBody`. Every existing page test gets the plan repository overridden; a new provider dependency is what breaks them.

- [ ] **Step 1: Write the failing tests**

`Planned chip and line appear with a link`; `chip hides the line and the table`; `Planned table sits above the delta table with Planned, As dived and What-if`; `planned schedule shows beside the runtime table`; `Link a plan and Unlink plan sit above the share actions`; `Unlink asks first` (dismiss before asserting); `a linked gauge dive opens with what-if controls hidden`; `a profile-less linked dive shows the plan`; `a planned dive reads Waiting for the dive`.

- [ ] **Step 2: Run and confirm they fail**

- [ ] **Step 3: Add the ARB keys, run `flutter gen-l10n`, implement**

- [ ] **Step 4: Run `test/features/dive_lab/` and `test/architecture/`**

Expected: PASS.

- [ ] **Step 5: Commit** `feat(dive-lab): show the plan on the Compare page`

### Task 8: Docs and demo data

**Files:**
- Create: `docs/user/compare.md`
- Modify: `docs/user/_sidebar.md`, `docs/user/planning.md`, `docs/user/import-export.md` (where it describes the fill)
- Modify: `tool/demo_data/src/seeders/planning_seeder.dart`
- Modify: `tool/demo_data/src/checks/coverage_check.dart` if it enumerates plan states
- Modify: `docs/design/specs/2026-10-31-compare-plan-vs-dive-design.md` (status line: "Implemented in #4003's PR")
- Test: the demo builder's existing checks; `scripts/check_docs_links.py`

- [ ] **Step 1: Write the Compare guide**: what each line and row means, linking from both sides, how a planned dive fills, what happens to a plan edited after linking. Written for divers; no em-dashes.

- [ ] **Step 2: Seed one plan linked to a filled dive and one unfilled planned dive with its plan linked**

- [ ] **Step 3: Run `python3.14 scripts/check_docs_links.py` and the demo tests under `test/tool/` or `tool/`**

Expected: PASS, coverage check green.

- [ ] **Step 4: Commit** `docs(dive-lab): guide for Compare and seeded demo links`
