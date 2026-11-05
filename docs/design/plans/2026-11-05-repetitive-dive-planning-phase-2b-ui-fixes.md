# Repetitive dive planning, phase 2b: UI fixes from review

Issue #3565, draft PR #4206. Seven issues the maintainer found trying phase
2b on 2026-11-05. Items 1 to 4 are in the planner; items 5 to 7 are in the
dive log's profile chart and are already on `main`, so they go in their own
issue and PR.

## The issues

1. After planned dives are created, the planner has no way to open them in
   the log.
2. A planned dive marked as logged still shows as a plan in the planner.
3. Such a dive can still be removed from the series.
4. A planner dive linked to a logged dive should show what was dived, its
   details and profile, with the plan overlaid.
5. A logged dive's profile shows its plan overlaid on the dive details page,
   but not in full screen.
6. The overlay's legend entry reads "Depth · 41.0m - Nov 5", which does not
   say it is the plan.
7. The chart options have no switch for the plan overlay.

## What the code does now

- **Items 2 to 4.** The series bar (`plan_series_navigator.dart`) shows a
  dive as logged, a solid diver chip opening the read-only logged-dive
  layout, only for the dives a series *follows*
  (`series.follow.loggedDives`). `viewedLoggedDiveProvider` looks only
  there. A series dive whose own link is now a dived entry is still a
  `_DiveChip`: waves, editable, and with its remove cross while selected.
  Phase 5 has this in its scope (R5: "the dive's chip becomes the solid
  diver ... opens on what happened, in the logged-dive layout ... with its
  plan ghosted"), together with R4, the carry from the actual dive into
  the next one.
- **Item 4's view exists.** The logged-dive layout's `LoggedDiveChart` is
  the dive log's `DiveProfileChartHost`, which already ghosts the linked
  plan through `plannedProfileOverlayProvider`. The results pane already
  shows "As planned" from `linkedPlanComparisonProvider`.
- **Item 1.** The only ways from the planner to an entry are the snackbar's
  View right after Create / Update, and the link badge in the saved plans
  list. The overflow menu has Link, Change and Unlink, but nothing that
  opens the linked entry.
- **Item 5.** `fullscreen_profile_page.dart` builds its overlay list from
  the source overlays only; the detail page's host adds `?plannedOverlay`
  and the full-screen page never does.
- **Item 6.** `buildPlannedOverlay` names the overlay `plan.name`, and the
  legend writes every overlay entry as `<metric> · <overlay name>`. A plan
  with no name of its own has a generated one ("41.0m - Nov 5").
- **Item 7.** The Overlays section of `chart_options_dialog.dart` lists only
  the dive's own series; the plan overlay is always drawn when a plan is
  linked.

## Proposed fixes

### Planner (phase 2b, PR #4206)

**Item 1: Open in log.** An overflow menu item next to Link / Change /
Unlink, shown when the selected dive has a log entry: "Open planned dive in
log" while the entry is still planned, "Open dive in log" once it is dived.
It pushes `/dives/<id>`, as the snackbar's View does, so the planner stays
underneath. The logged-dive view (item 4) offers it as well.

**Items 2 to 4: a dived dive of the series shows as dived.** This is phase
5's R5, pulled forward, without R4:

- A provider maps each series dive's link to its entry's state, watching
  the dive table, so Mark as logged, the edit page's switch and a download
  all show at once.
- A dive whose entry is dived gets the solid diver chip, labelled by the
  entry's name, else its number, like a followed dive's. It has no remove
  cross (item 3). Removing it would only drop the plan; the dive stays in
  the log, and its plan is what the overlay and Compare read.
- Selecting it shows the logged-dive layout from phase 2, read-only: the
  actual profile with the plan ghosted, details, tanks and "As planned"
  results. `viewedLoggedDiveProvider` widens from the followed dives to
  these as well.
- Phase 5 adds the toggle to the plan itself, the carry from the actual
  dive into the next (R4), and the series carry for "As planned". Until
  then a later dive still computes from this one's plan; the phase 5 plan
  is updated to say R5's chip and view came in 2b.

### Dive log chart (new issue, own PR off `main`)

**Item 5.** The full-screen page adds the plan overlay the way the host
does. A test opens full screen on a dive with a linked plan and finds it.

**Item 6.** The overlay is named "Plan" (localized), so the entry reads
"Depth · Plan". The plan's own name stays out of the legend: the banner
and "View in planner" already name it, and a generated name says nothing
the chart does not.

**Item 7.** A "Plan" switch in the Overlays section, shown only on a dive
with a linked plan, in the plan's purple. It sits in the legend state with
the others, on by default, and both the host and the full-screen page skip
the overlay when it is off. The planner's logged-dive view keeps it on in
its own legend override.

## Decided (2026-11-05)

- R5's chip and logged-dive view come into phase 2b, then the rest of phase
  5 as well: one PR. The backup's calculator and tests are ported onto the
  2b base; its dived-dive page, compare strip and per-dive deco providers
  are dropped, since phase 2's logged-dive layout and #4058's Compare
  columns already do that, and the series carry goes into
  `linkedPlanComparisonProvider` once.
- The overlay's legend entry reads "Depth · Plan", the plan's name left
  out.
- Items 5 to 7 get their own issue: #4215.

## Stages

Planner, each one commit, tests first:

1. The dive-state provider and the dived chip, no remove cross.
2. The dived dive in the logged-dive layout.
3. Open in log, in the menu and the logged-dive view.
4. Docs: `docs/user/planning.md`, the phase 5 plan, this plan's As built.

Dive log, on its own branch:

1. Full-screen overlay.
2. Legend name.
3. The Overlays switch.

Then l10n in all 11 locales, `dart format .`, `flutter analyze`, tests
through `scripts/run_all_tests.sh`, and screenshots before and after,
light and dark, phone and desktop.

## As built (2026-11-05)

- **Calculator.** `PlanSeriesDive.actual` and `SeriesDiveResult.actual`, as
  in the backup. One change: the carry takes the actual dive's end
  environment with its tissues (phase 2 added `initialTissueEnvironment`
  since the backup), and a dive with no profile to analyse carries its
  plan's tissues and environment.
- **Open in log** reuses "Open in dive log", one item for a planned or a
  dived entry, not the two wordings proposed above. The logged-dive view
  already had the button in its details card.
- **The carry card** names the dive after a dived dive of the series, and
  shows nothing for the last.
- **Keyboard.** Next and previous treat a dived dive as any other dive of
  the series; only a followed dive picked in the bar is left first.
- **Locked plan (found in review, 2026-11-05).** The first build locked a
  dived dive's plan by wrapping the editor in `IgnorePointer`, which also
  stopped it scrolling and left the chart editable; Save then reported
  success while keeping the stored plan. Now one `planLockedProvider` is read
  by each editing surface instead (see the spec's "Dived dives"). The chart's
  drag was never gated by its own read-only flag: a mission simply has no
  handles, so a locked plan drops them the same way. Reset Plan stays: it
  starts a new plan and leaves the saved one alone. The toggle is aligned
  to the start. A single plan linked to a dived dive hides "Create planned
  dive" (decided 2026-11-05).
- **Not done:** the range table of a later dive still starts from a fresh
  diver. No test across a daylight saving change: the chain reuses phase
  2's `fromWallClockUtc` and `endInstant`, and CI runs in UTC, where such a
  test cannot fail.
