# Gas Calculators Split View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the six-tab `TabBar` inside Gas Calculators with a nested master-detail layout: the six calculators become a list on the left, the selected one fills the pane on the right, and the whole thing is a full-window page pushed from Planning rather than a tool loaded into Planning's detail pane.

**Architecture:** `GasCalculatorsPage` becomes a second consumer of the existing `MasterDetailScaffold`, structured exactly like `PlanningPage`: split view at >=1100px, bare list below that. The six calculator widgets and every provider in `gas_calculators_providers.dart` are untouched, because calculator state already lives in top-level `StateProvider`s rather than in the tab widgets. `PlanningTool` and `PlanningTile` are reused rather than copied, so the two lists are identical by construction; `PlanningTool` gains a `routePrefix` and a `presentation` (`PlanningToolPresentation`), which also generalizes the hardcoded dive-planner exception that exists today and carries the entry verb each presentation needs.

**Tech Stack:** Flutter, Riverpod (`StateProvider` via `package:submersion/core/providers/provider.dart`), go_router (nested `GoRoute` children), `flutter gen-l10n` (11 arb files), `flutter_test` widget tests with `testApp`/`ProviderScope` overrides.

**Spec:** `docs/superpowers/specs/2026-08-28-gas-calculators-split-view-design.md`

## Global Constraints

- Work only in the worktree. Every shell command starts with `cd /Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/gas-calculators-split-view` and every file path below is relative to that root. Read/Edit/Write tools need the absolute worktree path; the main checkout must not be touched.
- Never write an em-dash (U+2014) anywhere: code, comments, docs, arb values, commit messages. Use commas, colons, or two sentences.
- No emojis in code, comments, or documentation. No `Co-Authored-By` trailer and no session URL in commit messages.
- TDD: write the failing test, run it and see it fail, implement, run it and see it pass, commit.
- Files stay at or below 800 lines; 200 to 400 is the target. Every new file below is well under that.
- New user-facing strings get a key in all 11 arb files (`ar, de, en, es, fr, he, hu, it, nl, pt, zh`), then `flutter gen-l10n`. Check with `grep -c '"<key>"' lib/l10n/arb/app_en.arb` that a key does not already exist before adding it.
- Riverpod imports come from `package:submersion/core/providers/provider.dart`, not `flutter_riverpod` directly.
- Run `dart format .` from the worktree root before every commit. Run `flutter test <file>` directly, never piped into `grep`/`tail` (the pipe returns grep's exit code, not the suite's).
- Anything displaying a depth or a volume goes through `UnitFormatter`. This plan adds no numeric display of its own; the calculators keep their existing formatting.
- Widget tests that need the split-view branch must set a surface size at or above 1100px wide before pumping, and reset it in a tear-down.

---

## File Structure

New files (one responsibility each):

| File | Responsibility |
| --- | --- |
| `lib/features/gas_calculators/presentation/gas_calculator_tools.dart` | `gasCalculatorToolsOf(context)`: the six entries in display order |
| `lib/features/gas_calculators/presentation/widgets/gas_calculators_list_content.dart` | The master list: header, tiles, disclaimer |
| `lib/features/gas_calculators/presentation/widgets/gas_calculators_summary_widget.dart` | The empty right pane |
| `lib/features/gas_calculators/presentation/pages/gas_calculator_detail_page.dart` | Id to calculator widget, with pane or full-page chrome |
| `test/features/gas_calculators/gas_calculators_page_test.dart` | Layout and routing tests for the new page |

Modified: `gas_calculators_page.dart`, `planning_tools.dart`, `planning_list_content.dart`, `planning_tool_pane.dart`, `planning_page.dart`, `app_router.dart`, the 11 arb files, `planning_tool_embedding_test.dart`, `planning_page_test.dart`.

Deleted: nothing.

---

## Task 1: Localization keys

- [x] Confirm none of the seven keys exist yet: `grep -c '"gasCalculators_desc_mod"' lib/l10n/arb/app_en.arb` and the same for `_bestMix`, `_consumption`, `_rockBottom`, `_mnd`, `_blender`, and `gasCalculators_summary_prompt`.
- [x] Add all seven to `lib/l10n/arb/app_en.arb` with a `@key` description entry each, then translate into the other ten arb files. English values:
  - `gasCalculators_desc_mod`: "Deepest safe depth for a mix"
  - `gasCalculators_desc_bestMix`: "Richest mix for a target depth"
  - `gasCalculators_desc_consumption`: "Gas a planned dive will use"
  - `gasCalculators_desc_rockBottom`: "Reserve to bring two divers up"
  - `gasCalculators_desc_mnd`: "Narcosis depth limit for a mix"
  - `gasCalculators_desc_blender`: "Fill procedure for a target mix"
  - `gasCalculators_summary_prompt`: "Select a calculator to get started"
- [x] Run `flutter gen-l10n`.
- [x] Run `flutter test test/l10n/` (the arb parity suite) and see it pass.
- [x] Commit.

Note: the six titles reuse the existing `gasCalculators_tab_*` values. Do not add new title keys.

## Task 2: `PlanningTool` gains `routePrefix` and `presentation`

- [x] Write a test in `test/features/planning/planning_page_test.dart` asserting that a `PlanningTool` with `routePrefix: '/planning/gas-calculators'` and id `mod` produces the route `/planning/gas-calculators/mod`, and that one with a non-default `presentation` is rendered by `PlanningTile` with navigation rather than a selection callback. Run it and see it fail.
- [x] Add both fields to `PlanningTool` in `lib/features/planning/presentation/planning_tools.dart`, defaulting to `'/planning'` and `false`. Update the `route` getter to use `routePrefix`.
- [x] In `planning_list_content.dart`, have `PlanningTile` treat a non-default `tool.presentation` as "navigate, do not select" by ignoring `onToolSelected`, and pick the entry verb from it: `go` for `splitViewPage`, `push` otherwise. Document that this generalizes the `kDivePlannerToolId` exception.
- [x] Set `presentation: PlanningToolPresentation.splitViewPage` on the `gas-calculators` entry in `planningToolsOf`.
- [x] Run the test and see it pass. Run `flutter test test/features/planning/` and see it pass.
- [x] Commit.

## Task 3: `PlanningToolPane` gains a `leading` slot

- [x] Write a test in `test/features/planning/planning_tool_embedding_test.dart` asserting that a `PlanningToolPane` given a `leading` widget renders it before the title, and that omitting it changes nothing about the existing layout. Run it and see it fail.
- [x] Add the optional `leading` parameter to `PlanningToolPane`, rendered ahead of the title and replacing the current fixed `SizedBox(width: 8)` when present. Keep the title the row's only flexible child, per the existing comment.
- [x] Run the test and see it pass.
- [x] Commit.

## Task 4: The six calculator entries

- [x] Write `lib/features/gas_calculators/presentation/gas_calculator_tools.dart` with `gasCalculatorToolsOf(BuildContext)` returning six `PlanningTool`s in this order and with these ids, icons, and title keys:

  | id | icon | title key | subtitle key |
  | --- | --- | --- | --- |
  | `mod` | `Icons.arrow_downward` | `gasCalculators_tab_mod` | `gasCalculators_desc_mod` |
  | `best-mix` | `Icons.science` | `gasCalculators_tab_bestMix` | `gasCalculators_desc_bestMix` |
  | `consumption` | `Icons.local_gas_station` | `gasCalculators_tab_consumption` | `gasCalculators_desc_consumption` |
  | `rock-bottom` | `Icons.warning_amber` | `gasCalculators_tab_rockBottom` | `gasCalculators_desc_rockBottom` |
  | `mnd` | `Icons.psychology` | `gasCalculators_tab_mnd` | `gasCalculators_desc_mnd` |
  | `blender` | `Icons.gas_meter` | `gasCalculators_tab_blender` | `gasCalculators_desc_blender` |

  Every entry sets `routePrefix: '/planning/gas-calculators'`. Icons are the current tab icons, so the calculators keep the glyphs users already associate with them. Colors come from the active `ColorScheme`, following `planningToolsOf`.
- [x] Add a `kGasCalculatorIds` constant (the six ids in order) so the router, the detail page, and the tests share one source of truth.
- [x] Commit.

## Task 5: The detail page

- [x] Write a test asserting that `GasCalculatorDetailPage` renders the right calculator widget for each of the six ids, wraps it in `PlanningToolPane` when embedded and in a `Scaffold` with an `AppBar` when not, and falls back to the summary for an unknown id (ids arrive from the URL, so a stale link must land somewhere useful, matching `PlanningPage._buildTool`). Run it and see it fail.
- [x] Write `lib/features/gas_calculators/presentation/pages/gas_calculator_detail_page.dart` with an `embedded` flag, mirroring the chrome contract the other planning tools follow.
- [x] Run the test and see it pass.
- [x] Commit.

## Task 6: The list and summary

- [x] Write a test asserting `GasCalculatorsListContent` renders six tiles in the documented order, shows the safety disclaimer, renders its own `AppBar` when `showAppBar` is true, and renders a `PlanningToolPane` header with a back button and the reset action when it is false. Run it and see it fail.
- [x] Write `gas_calculators_list_content.dart` and `gas_calculators_summary_widget.dart`. The summary shows the page title, `gasCalculators_summary_prompt`, and the safety disclaimer; it deliberately carries no calculator shortcuts, since the list sits permanently to its left (the reasoning `PlanningSummaryWidget` records).
- [x] The reset action calls the existing `resetGasCalculators(ref)` and lives only in the master header, never in the detail pane, because it resets all six.
- [x] Run the test and see it pass.
- [x] Commit.

## Task 7: Rewrite `GasCalculatorsPage`

- [x] Write `test/features/gas_calculators/gas_calculators_page_test.dart`: below 1100px the page shows the six rows and no `TabBar`; at 1400px it shows the list and the summary side by side; selecting a row shows that calculator and still no `TabBar` anywhere in the tree. Run it and see it fail.
- [x] Rewrite `gas_calculators_page.dart` as a `MasterDetailScaffold` consumer with `sectionId: 'gas-calculators'`, `queryParamKey: 'calc'`, and `mobileDetailRoute: (id) => '/planning/gas-calculators/$id'`, falling back to bare `GasCalculatorsListContent` below the breakpoint. Delete the `TabController`, the `TabBar`, the `TabBarView`, and the `embedded` field.
- [x] Run the test and see it pass.
- [x] Commit.

## Task 8: Routing and the Planning hand-off

- [x] Update `test/features/planning/planning_tool_embedding_test.dart`: remove Gas Calculators from the embedded-tools table (it no longer has an embedded form) and assert instead that its Planning tile pushes. Run it and see it fail on the current code.
- [x] In `app_router.dart`, add six child `GoRoute`s under `gas-calculators`, each building `GasCalculatorDetailPage(toolId: <id>)`.
- [x] In `planning_page.dart`, delete the `gas-calculators` case from `_buildTool` and its now-unused import.
- [x] Run the updated tests and see them pass.
- [x] Commit.

## Task 9: Blender width check

- [x] Pump `GasCalculatorDetailPage(toolId: 'blender', embedded: true)` at 400px wide, the detail pane's reserved minimum (`_kDetailPaneReservedWidth`), and assert no overflow.
- [x] If it overflows, fix it in the blender's own layout and note the fix in the PR body. If it does not, say so explicitly rather than silently dropping the check.
- [x] Commit.

## Task 10: Verification

- [x] `dart format .` from the worktree root.
- [x] `flutter analyze` over the whole project, treating infos as failures (CI does).
- [x] One full `flutter test` run. Cross-check any failure against `INDEX_FLAKY_TESTS.md` before treating it as real, and rerun a suspected flake as a lone file.
- [x] Launch the macOS app and confirm by hand: Planning to Gas Calculators pushes; the six rows are there; selecting one fills the pane with no tab strip; back returns to Planning; the window narrowed below 1100px shows the list alone and a row pushes one calculator.
- [x] Open the PR. No attribution line, no session URL.

---

## Notes for the implementer

- Do not touch the six calculator widgets or `gas_calculators_providers.dart`. If a task seems to need a change there, stop: it means an assumption in the spec (F4) is wrong, and that is worth reporting rather than working around.
- `MasterDetailScaffold` selects with `router.go`, not `push`. That is correct here: `go` rebuilds the stack as `[/planning, /planning/gas-calculators]`, so the back gesture still returns to Planning.
- The schema version ladder is not involved. This change touches no database code and must not bump `schemaVersion`.

---

## As built

Three things went differently from the plan. All three are in the commits.

**Tasks 5 and 6 swapped one file.** `GasCalculatorDetailPage` falls back to
the summary for an unknown id, so `gas_calculators_summary_widget.dart` had to
exist before Task 5 could go green. It landed in Task 5's commit rather than
Task 6's.

**Tasks 7 and 8 landed as one commit.** Removing `GasCalculatorsPage.embedded`
breaks `PlanningPage._buildTool` in the same edit, so the page rewrite, the
router children, and the Planning hand-off could not be separated without a
commit that does not compile.

**Task 9 found more than the blender, and none of it was new.** The blender
fits 400px unchanged; the plan's suspicion was wrong. Three other Rows did
overflow, each the same shape (an icon and a long label with nothing
flexible): `unit_slider.dart`'s label, and the section headings on Best Mix
and Rock Bottom. Pumping the bare calculator widgets with no pane chrome at
all reproduced every one of them, and the old tabbed page sat in a pane with
the same 400px floor, so these predate the change rather than following from
it. Fixed anyway, since a detail pane is where the calculators now live, and
pinned by a test that pumps all six at 400px.

One assertion in `gas_calculators_page_test.dart` reads
`currentConfiguration.last.matchedLocation` rather than
`currentConfiguration.uri`: an imperative `push` does not move `uri`, which
still reports the last `go`. The split-view assertions use `uri` because
`MasterDetailScaffold` selects with `go`.

## Verification

- `flutter analyze` over the whole project: no issues.
- ARB parity across all eleven locales: green.
- Full `flutter test`: 21503 passing, 19 skipped, 1 failing. The failure is
  `media_share_helper_test.dart`, "iPad share popover anchor falls back to the
  calling widget rather than nothing", which is the known flake recorded as
  `share-bytes` and passes when the file is run alone. Nothing in this branch
  touches media sharing.

## Follow-up: the first-selection re-animation

Found by hand after the first implementation, and fixed before merge.

**Symptom:** tapping a calculator for the first time slid the whole Gas
Calculators page in from the right again. Every later tap was instant.

**Root cause**, from page keys dumped either side of the first selection:
`PlanningTile` entered the page with `context.push`, which go_router keys with
a generated string, while `MasterDetailScaffold._onItemSelected` selects with
`router.go`, which rebuilds the stack from the declarative match and keys the
page by its path. The first selection therefore changed the page key, and
Flutter's Navigator animated what it saw as a different page. Mid-transition
both copies of the list were mounted; afterwards the key was stable, so
nothing animated again.

**Fix:** `fullPage` became `PlanningToolPresentation`, and a `splitViewPage`
tool is entered with `go`. Verified that `go` on a nested child route still
leaves the hub on the stack, so the back button keeps working. The dive
planner keeps its `push`; it drives no URL after arrival and #647 wants it
poppable.

**Guarded by:** `planning_page_test.dart` asserts the entry verb and the
resulting declarative page key, plus that the planner still pushes;
`gas_calculators_page_test.dart` counts the mounted lists mid-transition,
which is what distinguishes the two behaviours. That assertion was confirmed
to fail against the old `push` entry before being kept.
