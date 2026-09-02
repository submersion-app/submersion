# Gas Calculators as its own split view: Design

**Status:** design approved in chat 2026-08-28; spec awaiting review
**Branch:** `worktree-gas-calculators-split-view`
**Baseline:** `origin/main` at ae5fd016999

## Problem

Gas Calculators packs six calculators into a `TabBar` inside the Planning
detail pane. Two things go wrong at once.

The tab strip is crowded. Six icon-and-text tabs share whatever width the
detail pane has left after the 440px master pane, so on a typical desktop
window the labels sit shoulder to shoulder and, below 500px, the strip becomes
horizontally scrollable and some calculators are off screen entirely.

The tab strip also eats vertical space in the pane that is already the most
vertically hungry surface in Planning. An icon-and-text `TabBar` is roughly
72px, and it sits below the `PlanningToolPane` header, so every calculator
starts about 112px down a pane that already has to fit sliders, unit toggles,
and result cards.

The rest of Planning does not have this problem, because Planning already
solved it: a list of tools on the left, the selected tool on the right. Gas
Calculators should use the same shape one level down, with its six calculators
as the list.

## Findings

Every claim below was verified against `origin/main` at ae5fd016999.

**F1. The split-view machinery is already generic.** `MasterDetailScaffold`
(`lib/shared/widgets/master_detail/master_detail_scaffold.dart`) takes a
`masterBuilder`, a `detailBuilder`, and a `summaryBuilder`, and drives
selection through a URL query parameter named by `queryParamKey`. It reads and
writes the *current* path (`state.uri.path`), so it works unchanged on a nested
route such as `/planning/gas-calculators`. Nothing in it assumes a top-level
nav destination.

**F2. Planning is a 67-line consumer of it.** `PlanningPage`
(`lib/features/planning/presentation/pages/planning_page.dart`) renders
`MasterDetailScaffold` at >=1100px and bare `PlanningListContent` below that.
Gas Calculators becomes a second consumer of the same widget with the same
two-branch structure.

**F3. The dive planner is the precedent for a full-window push.**
`kDivePlannerToolId` in `planning_tools.dart` is documented as the one tool
that never opens in the detail pane, because its own multi-pane layout cannot
be squeezed into what is left beside a 440px master pane. A nested split view
is the same situation, so Gas Calculators joins it. Today the exception is
expressed by rendering the planner from a separate `_PlannerSection` with
`onToolSelected: null` hardcoded; there is no general way to mark a tool as
full-page.

**F4. Calculator state is already independent of the tab widget.** Every input
lives in a top-level `StateProvider` in `gas_calculators_providers.dart`
(`modO2Provider`, `bestMixDepthProvider`, `consumptionDepthProvider`, and so
on), never in widget state. Switching calculators through a list therefore
preserves typed values exactly as `TabBarView` did, and
`resetGasCalculators(WidgetRef)` (line 142) keeps working untouched. The six
calculator widgets need no changes.

**F5. `PlanningToolPane` exists for exactly this.** Its doc comment records
that `MasterDetailScaffold` renders `detailBuilder` output with no app bar, so
a tool in the pane has nowhere to put its title and actions, and that its
header deliberately matches the compact bar the entity list panes use. The new
gas-calculator detail pane reuses it verbatim. It has no `leading` slot today.

**F6. `_MasterPane` adds no chrome.** It is a bare `Stack` holding the master
content plus an optional FAB, so the master pane's app bar, if any, comes from
the master content itself. `PlanningPage` passes `showAppBar: false` because
the nav rail supplies context for a top-level destination. A *pushed* page has
no nav-rail highlight and needs its own back affordance.

**F7. Gas Calculators has exactly two entry points.** `app_router.dart:276`
(`/planning/gas-calculators`) and `planning_page.dart:56` (the embedded form).
No dashboard shortcut, no deep link elsewhere.

**F8. Generated localizations cover 11 locales.** `lib/l10n/arb/` holds
`app_en.arb` plus ten translations (ar, de, es, fr, he, hu, it, nl, pt, zh).
Every new key has to land in all eleven.

## Design

### Navigation and routing

Gas Calculators stays a row in the Planning tools list and keeps the route
`/planning/gas-calculators`, so existing links and the back-to-Planning
gesture are unchanged. What changes is that the row pushes a full-window page
instead of loading the Planning detail pane, exactly as the dive planner
already does.

| Width | What renders | URL |
| --- | --- | --- |
| >=1100px | Split view: calculator list left, calculator right | `/planning/gas-calculators?calc=mod` |
| <1100px | Calculator list only; a row pushes one calculator | `/planning/gas-calculators/mod` |

`calc` is the `queryParamKey`, chosen over the default `selected` for the same
reason Planning chose `tool`: the URL stays self-describing. There is no
collision risk (the path differs from Planning's), so this is readability
only.

The six ids are `mod`, `best-mix`, `consumption`, `rock-bottom`, `mnd`, and
`blender`, matching the existing `gasCalculators_tab_*` string suffixes.

`/planning/gas-calculators` with no selection lands on a summary pane rather
than auto-selecting a calculator, matching every other split view in the app.

### Pane chrome

The pushed page needs a back affordance that Planning's split view does not.
Rather than nest a 56px `AppBar` inside the 440px master pane and leave the
detail pane headerless, both panes get the same compact header:

- **Master pane:** `PlanningToolPane` with a back `IconButton` as `leading`,
  the title `gasCalculators_title`, and the existing reset action.
- **Detail pane:** `PlanningToolPane` with the selected calculator's title and
  no actions (reset is global and lives once, in the master header).

This requires one additive change to `PlanningToolPane`: an optional `leading`
widget. Matching headers keep the two halves reading as one surface, which is
the stated intent of that widget's design.

Below 1100px the list is an ordinary page and uses a normal `Scaffold` and
`AppBar` with the automatic back button, so `GasCalculatorsListContent` takes
a `showAppBar` flag exactly as `PlanningListContent` does.

### Marking a tool as full-page

`PlanningTool` gains two optional fields:

- `routePrefix`, defaulting to `/planning`, so a nested tool can build
  `/planning/gas-calculators/mod` from the same `route` getter.
- `presentation`, a `PlanningToolPresentation` defaulting to `detailPane`.
  `PlanningTile` passes `null` for `onToolSelected` for any value other than
  the default, which is already the tile's "navigate, do not select" path.

This generalizes the hardcoded planner exception in F3 rather than adding a
second special case beside it.

The enum has three values rather than a `fullPage` boolean, because the cases
differ in navigation verb as well as layout:

| Value | Layout | Verb |
| --- | --- | --- |
| `detailPane` | Planning's detail pane | `push` below the breakpoint |
| `pushedPage` | Whole window | `push` (the dive planner) |
| `splitViewPage` | Whole window, hosts its own split view | `go` (Gas Calculators) |

The verb on the third row is load-bearing. A `MasterDetailScaffold` selects by
calling `go`, which rebuilds the stack from the declarative route match and
keys the page by its path. Entering on a `push` leaves the route carrying a
generated page key, so the first selection swaps one page for another and
Flutter animates the whole page in from the right a second time, once, before
settling. `go` on a nested child route still leaves the hub beneath it, so the
tool stays poppable either way. This was found by hand after the first
implementation shipped a `fullPage` boolean that could not express the
difference.

### Reuse over duplication

The new list reuses `PlanningTool` and `PlanningTile` directly instead of
copying their styling. The two lists are then identical by construction, which
is the point of the change: Gas Calculators should look like Planning, not
merely resemble it. `gas_calculators_page.dart` already imports
`PlanningToolPane` across the feature boundary, so the direction of that
dependency is established.

### Components

New, all under `lib/features/gas_calculators/presentation/`:

| File | Purpose |
| --- | --- |
| `gas_calculator_tools.dart` | The six entries (id, icon, color, title, subtitle) in display order, mirroring `planning_tools.dart` |
| `widgets/gas_calculators_list_content.dart` | The master list: header, tiles, safety disclaimer |
| `widgets/gas_calculators_summary_widget.dart` | The empty right pane: title, prompt, disclaimer |
| `pages/gas_calculator_detail_page.dart` | Maps an id to its calculator widget with the right chrome for pane or full page |

Changed:

| File | Change |
| --- | --- |
| `pages/gas_calculators_page.dart` | Rewritten as a `MasterDetailScaffold` consumer; `TabController`, `TabBar`, `TabBarView`, and the `embedded` flag all removed |
| `planning/presentation/planning_tools.dart` | `PlanningToolPresentation`, plus `routePrefix` and `presentation` fields; Gas Calculators sets both |
| `planning/presentation/widgets/planning_list_content.dart` | `PlanningTile` honours `presentation`, for both the pane-vs-page choice and the entry verb |
| `planning/presentation/widgets/planning_tool_pane.dart` | Optional `leading` |
| `planning/presentation/pages/planning_page.dart` | Drop the `gas-calculators` case from `_buildTool` |
| `core/router/app_router.dart` | Six child routes under `gas-calculators` |

Unchanged: all six calculator widgets, and every provider in
`gas_calculators_providers.dart`.

### Localization

Seven new keys across eleven locales:

- `gasCalculators_desc_mod`, `_bestMix`, `_consumption`, `_rockBottom`,
  `_mnd`, `_blender`: one-line subtitles for the tiles.
- `gasCalculators_summary_prompt`: the empty-pane hint.

Titles reuse the existing `gasCalculators_tab_*` values, so the calculators
keep the names divers already know them by.

## Testing

- `test/features/planning/planning_tool_embedding_test.dart`: Gas Calculators
  leaves the embedded-tools table, because it no longer has an embedded form.
  Replaced by an assertion that its Planning tile pushes rather than selecting.
- New `test/features/gas_calculators/gas_calculators_page_test.dart`: six rows
  render below 1100px; at >=1100px the list and summary render together, and
  selecting a row shows that calculator with no `TabBar` anywhere in the tree.
- `test/features/planning/planning_page_test.dart`: update the tool-id
  expectations for the routing change.
- The six existing calculator widget tests pump the calculator widgets
  directly and are untouched, which is the evidence for F4.

## Risks

**The blender at minimum pane width.** The five simple calculators are
single-column forms and gain height in the pane. The blender is the one with a
wide multi-column layout, and the detail pane's reserved minimum is 400px
(`_kDetailPaneReservedWidth`). It will be checked at that width during
implementation and reported if it needs a responsive tweak; no fix is assumed
here.

**Deep-link behaviour changes shape.** `/planning/gas-calculators` used to
open on MOD, because a `TabController` starts at index 0. It now opens on the
summary. This is the app-wide split-view convention and is treated as correct
rather than as a regression.

## Out of scope

Moving Gas Calculators to a top-level nav destination; changing any
calculation; restyling the calculators themselves; giving the other Planning
tools the same treatment.
