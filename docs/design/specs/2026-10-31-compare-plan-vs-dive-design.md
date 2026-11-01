# Compare: plan, dive and what-ifs on one dive

Date: 2026-10-31
Status: Implemented for #4003 (plan: `docs/design/plans/2026-10-31-compare-plan-vs-dive.md`)
Branch / worktree: `ericgriffin/counterfactual-dive-lab-rethink-f2b015` at
`.claude/worktrees/counterfactual-dive-lab-rethink-f2b015`, PR #2407
Amends: `2026-09-25-counterfactual-dive-lab-rethink-design.md` (the Lab
rethink; still the reference for the engine, the scenario model, persistence
and the planner hand-off) and the plan-vs-actual item of
`2026-07-05-dive-planner-redesign-design.md`

## Why

Two things came up while walking PR #2407 on macOS.

1. **The Dive Lab reads as a second planner.** Both take a profile, let you
   change gradient factors or gas, and show a deco schedule. The difference
   (the Lab starts from a dive you did and asks "what if this had been
   different"; the planner starts from nothing and asks "what should I do
   next time") lives in the spec, not on the screen. The name "Dive Lab" says
   nothing about which one it is.
2. **Plan, dive, compare.** The maintainer planned a wreck dive to learn how
   long they could stay at depth, dived it, and then wanted the plan and the
   dive side by side: depth, time, NDL and deco. The pieces that join a plan
   to a dive exist (see below), but the comparison itself is one ghosted
   line on the profile chart, and a plan can only be joined to a dive by
   converting it first. There is no way to join them afterwards.

The two problems share an answer. A dive has three kinds of profile: as
planned, as dived, and as it might have gone. One place on the dive shows all
three, and that place is what the Lab already nearly is. Give it the plan,
call it what it does, and the planner stays the one place that builds plans.

## Decisions

| Question | Decision |
| --- | --- |
| Where do plan, dive and what-ifs meet? | On the logged dive, in one **Compare** section on dive detail and one full-screen **Compare** page. Not in the planner |
| Does the Lab page survive? | Yes. It becomes the Compare page: the same chart, chips, intervention sheet, delta panel and runtime table, plus the planned line and a Planned table |
| Name | **Compare**, on the page, the section and the menu entry. "Dive Lab" and "What if" go from every user-visible string. "Debrief" was considered and set aside: it promises notes and lessons the page does not hold |
| Section layout | Layout A: one chart with the plan dashed and the dive solid, a Planned / Dived table under it, chips for each line above it, "+ What if" to add a line |
| What the table compares | Max depth, bottom time, NDL left on leaving the bottom (or when deco began), deco required and done, runtime, surface GF |
| How a dive gets its plan | The flows that exist: **Convert to dive** puts a planned dive in the log with the plan linked, and the import wizard's planned pass fills it from the download (issue #2002). The pass's window widens to the planned day or the day after. A by-hand link is added from both sides for everything the pass misses |
| A waiting state on the plan without a planned dive in the log? | No. Considered and dropped: it would be a second, invisible way of saying what the planned dive already says, with its own matcher and a schema rung |
| Where the link is stored | Where it already is: `DivePlans.linkedDiveId`. No new column anywhere |
| Relation to #3565 (repetitive planning, schtibal) | Independent, dive-side work. Their phases keep the planner. Their phase 5 (Convert to dive swaps a planned chip for the logged dive) sets the same `linkedDiveId` |
| How it ships | Two PRs. PR 1 renames inside #2407 before it merges. PR 2, under its own issue, adds the comparison, the by-hand link and the window change. Neither changes the schema |

## What exists today

- `DivePlans.linkedDiveId` ("executed dive this plan is linked to"), written
  in exactly one place: Convert to dive
  (`plan_canvas_page.dart`, `notifier.setLinkedDive(created.id)`) after it
  creates a planned, unnumbered dive (`Dive.isPlanned`) carrying the plan's
  sketched profile. Read by `DivePlanRepository.getPlanByLinkedDiveId`
  (newest plan wins when a duplicate shares the link). Synced as a nullable
  parent reference to `dives`.
- The import wizard's **planned pass** (`dive_matcher.dart`, issue #2002):
  an otherwise unmatched download that falls on the same local day as an
  unfilled planned dive is offered as **Fill planned dive**, the default for
  such a row. `PlannedDiveFillService` and `attachToPlannedDive` fill the
  planned dive in place, keeping its id, so the plan's link survives. The
  summary step lists the fills and offers undo. Every dive computer download
  and cloud adapter saves through this wizard; the only other way a dive is
  created is the manual save.
- `plannedProfileOverlayProvider(diveId)` in
  `lib/features/planner/presentation/providers/plan_overlay_provider.dart`:
  runs `PlanEngine` on the linked plan and returns a `ChartSourceOverlay`
  (purple, not tinted by metric) that `dive_profile_chart_host.dart` appends
  to the dive detail chart. This ghost line is the whole of plan-vs-actual as
  shipped.
- `PlanOutcome` carries what the Planned column needs: `maxDepth`,
  `runtimeSeconds`, `ndlAtBottom`, `ttsAtBottom`, `stops`, `schedule`,
  `cnsEnd`, `endTissue`.
- The Lab module under `lib/features/dive_lab/`: `DiveLabPage` (pushed on the
  root navigator), `DiveLabSection` (a card on dive detail with a hint, the
  saved scenarios as rows and one button; no chart, no table), the
  intervention sheet, branch controls, chart (`lab_chart.dart`, built on
  `DiveProfileChart` with `ChartSourceOverlay`s), delta panel (actual,
  what-if and delta over branch-relative metrics), runtime table, mode toggle
  and saved scenarios sheet. `isDiveLabEligible` (a primary profile of at
  least two samples on an OC, CCR or SCR dive) gates all of it. The dive
  detail menus' "What if..." item opens the page for an eligible dive and
  today's rebuild sheet otherwise. The page's overflow holds share actions,
  Open in planner and Rebuild in planner. `savedScenarioOutcomeProvider`
  already runs the engine once per saved scenario for the row summaries.
- `DiveDetailSectionId.diveLab`, labelled "What if", before `dataSources`.
- `DivePlanState` lives in `lib/features/dive_planner/domain/entities/
  plan_result.dart`; `dive_plan_state_mapper.dart` bridges it to
  `domain.DivePlan`. The saved plans list's row menu (rename, duplicate,
  share) is `_PlanTile` in `saved_plans_sheet.dart`; `DivePlanSummary` does
  not yet carry `linkedDiveId`.
- 163 l10n entries whose key begins `diveLab_` or names `whatIf`, in eleven
  locales, and the demo logbook's three saved what-ifs
  (`tool/demo_data/src/seeders/lab_seeder.dart`). No user guide page
  describes the Lab (`docs/user/` has no "Dive Lab"; its only "what if" is
  the planner's), so the Compare guide is a new page, written in PR 2.
- PR #3739 (phase 1 of #3565) and the draft #3759 (phase 4) touch
  `dive_detail_page.dart` next to the `whatIf` case and `what_if_sheet.dart`.
  Phase 4 moves "follow" out of `sourceDiveId` so that field belongs to
  replans alone. Neither touches `linkedDiveId`.

## Product surface

### Names

| Today | After |
| --- | --- |
| Dive Lab (page title, docs, demo notes) | Compare |
| "What if..." (both dive detail menus) | "Compare..." |
| "What if" (section label, `DiveDetailSectionId.diveLab`) | "Compare" |
| "New scenario" | unchanged in meaning; wording is the builder's, "Ask a what-if" preferred |
| Saved scenarios, interventions, modes, share actions | unchanged |

The word "what-if" survives inside Compare for the things it names well: the
chips, the intervention sheet's title, the saved list. It stops being the
name of the feature.

Code names are not user-visible. The `dive_lab` folder, the `diveLab_` key
prefix, `DiveDetailSectionId.diveLab` and the `whatIf` menu value stay in
PR 1 so the diff is the strings and nothing else (my call; a mechanical
rename can follow once the page has settled).

### The Compare section (dive detail)

A new widget in the slot `DiveLabSection` holds today, replacing it. Shown
when the dive is Lab-eligible or has a linked plan (my call: a hand-logged
dive with no profile but a linked plan still has a plan to show).

- **Chips** across the top, one per line: **Planned** (dashed outline,
  present only when a plan is linked), **As dived** (always on), one per
  saved what-if, and **+ What if** (only on an eligible dive). Tapping a chip
  toggles its line and its column.
- **Chart**: the dive's profile over time, the plan dashed in the planner's
  overlay colour, each enabled what-if in its own colour, a marker where the
  dive ran out of NDL if it did. Same time axis for every line, zero at the
  dive's start. Built on `DiveProfileChart` with `ChartSourceOverlay`s, the
  way `lab_chart.dart` and `plan_overlay_provider.dart` already do.
- **Table**: one row per measure, a column per enabled line, Planned first,
  As dived second, what-ifs after. Rows: max depth; bottom time; NDL on
  leaving the bottom, shown as "n min left" or "Deco at m:ss" once the dive
  went into deco; deco, as the stops required (and for the dive, the stops
  done); runtime; surface GF. A cell a column cannot supply is blank: a dive
  with no profile has no NDL, deco-done or surface GF; a what-if that
  branches after the bottom repeats the dive's bottom time and NDL, since
  they are the dive's own up to the branch. A dived value that overshoots
  the plan is tinted the way the Lab's delta panel tints today. Units follow
  the active diver's settings.
- **Empty state**, when no plan is linked and no what-if is saved: one line
  ("Nothing to compare yet") and two actions, **Ask a what-if** (eligible
  dives) and **Link a plan**. Not hidden: hiding it would hide the only way
  in for a diver who has never linked a plan (my call).
- Tapping the chart or the section title opens the Compare page.

The dive detail chart's existing plan ghost line stays as it is; the section
has its own chart because the chips and the table need to sit with it (my
call).

### The Compare page (the Lab page, renamed)

Everything the Lab page does today, plus:

- The **Planned** line and chip, when a plan is linked, drawn from
  `plannedProfileOverlayProvider` or an equivalent run of `PlanEngine`.
- A **Planned table**: the section's six rows as Planned, As dived and the
  current what-if, added to the delta panel above the existing branch-relative
  delta table, which is unchanged (my call: a plan has no branch, so most of
  the delta table's rows have no Planned value, and forcing a column onto it
  would be mostly blanks).
- The plan's `schedule` beside the dive's in the runtime table (second table
  or second column: builder's call).
- **Link a plan** and **Unlink plan** in the overflow menu, above the share
  actions. Unlink asks first.
- The replay / re-plan modes, the branch controls, interventions, saving and
  the two planner actions are unchanged. A what-if still branches from the
  dive, never from the plan. The page opens for a dive with a linked plan
  even when the dive is not Lab-eligible; the what-if controls are then
  hidden and the page shows the plan against whatever the dive has.

### Linking a dive to its plan

Two routes exist and one is added. All end with `linkedDiveId` set on one
plan, and a plan links to one dive.

1. **Before the dive: Convert to dive.** Unchanged in behaviour: a planned
   dive appears in the log, linked, and shows the plan's sketched profile
   until it is filled. Its label in the planner may say what it is for
   ("Convert to dive" stays; the builder may add a one-line hint that the
   dive will be filled by the next download). A planned dive has a Compare
   section comparing the plan with its own sketch, which is honest but
   dull; the section's empty-state line on a planned dive reads "Waiting for
   the dive" instead (my call).
2. **When the download arrives: the planned pass.** Unchanged, except the
   window: a download fits an unfilled planned dive whose planned day is the
   download's local day or the day before (so a dive pushed to the next day,
   or a night dive logged after midnight, still fills). Among several fits
   the smallest start-time gap wins, which replaces today's rule of pairing
   each day's earliest download with its earliest plan: without it a
   just-after-midnight download would take the next morning's plan rather
   than the previous night's. Dates are compared as local calendar days,
   built with `DateTime(y, m, d + n)` so a DST change does not move them.
3. **By hand, from either side.** From the dive: **Link a plan** on the
   Compare section and page lists saved plans that are not yet linked,
   newest first, then linked ones greyed with the dive they belong to;
   picking an unlinked one sets `linkedDiveId`. From the plan: **Link to a
   logged dive** in the saved plans row menu and the plan menu lists logged
   dives newest first (dives from the plan's day first when it has a
   `startDateTime`); picking one sets `linkedDiveId`, after confirming when
   the plan was linked to another dive. **Unlink plan** on the Compare page
   and **Unlink dive** on the plan clear it. Neither creates or deletes a
   dive. Linking a plan by hand to a dive that was itself created by
   Convert to dive from another plan is allowed after confirming, and the
   displaced plan loses its link and its badge, so one dive has one plan and
   unlinking never brings an older plan back. `getPlanByLinkedDiveId` keeps
   newest-wins for duplicates that already exist or arrive by sync.

### The plan after it is linked

The Planned column reads the plan as it is saved now. Editing a linked plan in
the planner changes the comparison; the planner shows a "Dived as #N" badge
on such a plan so the diver knows. No snapshot is taken (my call: a plan kept
for next time should be duplicated, and the badge says why).

### Series plans (#3565)

A `DivePlans` row is one planned dive; after their phase 3 it is one dive of a
series. The link names that row, so a dive compares against the one planned
dive it matches. Their phase 5, where Convert to dive turns a planned chip into
the logged dive and recalculates the dives after it, sets `linkedDiveId` the
way Convert to dive does today and needs nothing from this design. The
maintainer tells schtibal on #3565 that `linkedDiveId` is now read by Compare
and written by the by-hand link, so phase 5 keeps using it; this document is
the reference.

### Menu order on dive detail

Compare..., then (when #3759 lands) Plan repetitive dive. There is no
separate "Replan this dive" entry: that name is the rebuild sheet's title, and
the sheet is reached from Compare's overflow ("Rebuild in planner...") or
directly from the Compare... entry on a dive that is neither eligible nor
linked. The entry keeps the Lab's routing otherwise: the page for an eligible
dive or a dive with a linked plan.

## Storage and sync

No change. `linkedDiveId` and its sync registration already exist. The
by-hand link goes through `DivePlanRepository` so the plan's `updatedAt` and
sync record move as they do for any plan edit.

## Delivery

### PR 1: rename inside #2407 (before it merges)

- Every user-visible "Dive Lab" and "What if" string per the Names table, in
  all eleven ARB files, then `flutter gen-l10n`.
- `DiveDetailSectionId.diveLab`'s label.
- No user guide or demo note changes: no guide page describes the Lab, and the
  demo's three scenario notes never said "Lab".
- The PR title, body and screenshots re-taken for the renamed screens.
- No schema change, no behaviour change. #2407 still `Closes #2405`.

### PR 2: the comparison and the by-hand link (own issue, after #2407 merges)

1. Planned pass window: the day-or-day-before rule in `dive_matcher.dart`,
   unit-tested around midnight and across a DST change.
2. Repository and domain: `linkPlanToDive(planId, diveId)` and
   `unlinkPlan(planId)` on `DivePlanRepository`; `linkedDiveId` on
   `DivePlanSummary` so the saved plans list can badge and offer the right
   entries.
3. Planner side: **Link to a logged dive**, **Unlink dive**, the "Dived as
   #N" badge, in `saved_plans_sheet.dart` and the plan menu.
4. Compare section: the new widget, chips, chart lines, table, empty states,
   **Link a plan**.
5. Compare page: Planned line, Planned table, planned schedule, Link and
   Unlink.
6. Docs: user guide for linking and comparing; this document's status line.
7. Screenshots: section with plan and without, a planned dive's section, the
   page with Planned on, the plan menu entries, the saved plans badge; phone
   and desktop, light and dark.

Steps 1 to 3 can land as one PR and 4 to 6 as another if the first grows past
review size; the issue stays open until both merge.

## Testing

- Pure Dart: the planned pass window (same day, day before, two days
  before rejected, DST, several planned dives, smallest gap wins).
- Repository: link and unlink round-trip and write a sync record;
  `getPlanByLinkedDiveId` still picks the newest on a duplicate; linking a
  plan already linked elsewhere moves the link.
- Widget: the section shows Planned only with a link; appears for a
  profile-less dive with a link; chips toggle columns; blank cells where a
  column has no value; the empty state's actions; the planned dive's
  "Waiting for the dive" line; the page's Unlink asks first; Link a plan
  lists unlinked plans first; the plan menu's Link to a logged dive confirms
  when moving a link; the saved plans badge.
- Guards: `test/architecture/` and `test/shared/` after every new `lib/`
  file; the dive detail sections tripwire keeps `dataSources` last.
- Demo logbook: one linked plan on a filled dive and one unfilled planned
  dive seeded so the demo shows both states; coverage check stays green.

## Settled while building (#4003, 2026-10-31)

Decided by the maintainer:

- One PR, closing #4003, rather than the two the delivery section allows.
- The section opens with Planned, As dived and the newest what-if on. Other
  saved what-ifs start off and turn on from their chips; past three columns
  the table scrolls sideways on a phone.
- A by-hand link clears any other plan's link to that dive, after confirming.

Builder's calls (the section below left these open):

- Every value in a column comes from one definition. Bottom time is
  `BottomTimeCalculator` over that line's samples, or `Dive.bottomTime` for a
  dive with no profile.
- "Leaving the bottom" for the NDL and deco rows is the last sample at 85% or
  more of that line's max depth, not the end of bottom time. Bottom time's
  threshold can sit a third of the way down the dive, past the deep stops,
  where NDL reads far longer than it did at depth. 85% matches
  `PlanOutcome.ndlAtBottom`, which is taken at the deepest authored leg.
- Deco required is the stops the model asks for at that moment: the sum of
  `decoStops` on the dive and on a what-if, `totalDecoSeconds` on the plan.
  Deco done is the time after that moment with an obligation in force, the
  Lab's own deco time; the plan has no done value.
- "Deco at m:ss" is the first sample with NDL below zero; on the plan it is
  the first `ceilingTrace` sample above the clear-ceiling epsilon, so it reads
  in 30-second steps.
- Surface GF on the plan is taken from `surfacedTissue` at the surface
  pressure of the plan's altitude, matching the last sample of the dive's
  curve.
- A fill that crosses a day moves the dive to the day it was dived, and
  undoing the fill puts the date back. Same-day fills keep the planned date, as
  #2002 had it.
- Converting a plan that is already linked confirms first, because the new dive
  takes the link.
- A dived value overshoots the plan past a tolerance of 0.5 m, 30 seconds or
  1 GF point, so a rounding difference never reads as an error.
- A planned dive shows only "Waiting for the dive", with no what-if controls,
  on the section and the page, plus Link a plan if it has no link.
- Tapping a what-if's column header opens it on the Compare page; chips toggle,
  so this replaces the saved scenario rows' route in.
- Greyed plans in Link a plan stay tappable and confirm before moving the link.
- Dives with no section (a gauge dive, or no profile and no link) are linked
  from the planner side.
- Compare page's planned schedule is a second table; the section's table sits
  beside the chart at 720 px and wider.

## Left to the builder

- Exact wording of every new string, within the Names table.
- Chart colours for what-if lines beyond the plan's purple; the NDL marker's
  shape.
- How surface GF and "deco required" are derived for the plan from
  `PlanOutcome`, and for the dive from the existing dive analysis, so both
  columns use the same definitions.
- Desktop layout of the section (the table may sit beside the chart).
- Whether the Compare page's planned schedule is a second column in the
  existing runtime table or a second table.
- The pickers' look (sheet or page) for Link a plan and Link to a logged
  dive, following the planner's existing Follow a dive sheet.

## Out of scope

- A waiting state on plans, or any new matcher beyond the window change.
- A snapshot of the plan at link time.
- Linking one dive to several plans, or one plan to several dives.
- What-ifs that branch from the plan rather than the dive.
- Any change to the planner's series bar, follow logic or `sourceDiveId`
  (schtibal's program).
- Renaming code identifiers (`dive_lab`, `diveLab_`, `whatIf`).
- Everything the Lab rethink listed as out of scope.

## Amendments to earlier documents

- Lab rethink, "Front door": the menu entry is "Compare...", same routing,
  plus a dive with a linked plan opens the page.
- Lab rethink, "Teaser card": superseded by the Compare section above.
- Lab rethink, "Lab app bar": the overflow gains Link a plan and Unlink plan
  above the share actions.
- Planner redesign, phase 6 "Plan-vs-actual": the "show plan toggle" became
  the ghost overlay; the comparison itself is this document.
