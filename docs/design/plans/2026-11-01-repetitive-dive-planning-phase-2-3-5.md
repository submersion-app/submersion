# Repetitive dive planning: phases 2, 3 and 5 (one PR)

Issue: #3565. Design: discussion #3700, spec
`docs/design/specs/2026-10-27-repetitive-dive-planning-design.md`.
Built so far: phase 1 (#3739, merged), phase 4 (#3759, waiting to merge).

One branch off `main`, made once #3759 has merged:
`feature-request-3565-repetitive-dive-planning-phase-2-3-5`. It is one PR,
built as the stages below. Each stage is a run of reviewable commits, test
first, and the suite stays green at every stage.

## New requirements folded in (2026-11-01)

| # | Requirement | Where |
| --- | --- | --- |
| R1 | An optional start time and site in Dive details. Start time and surface interval derive each other. The site is used only on conversion. | Stage 1 |
| R2 | A saved, converted series renames its chips to the logbook numbers and keeps the outlined icon until the dive is done. | Stage 5 |
| R3 | The saved plans screen lists every dive of each plan, with a link to the actual dive. | Stages 2 and 7 |
| R4 | A completed dive replaces the planned one in the chain (its profile and times), and the dives after it recalculate. | Stage 6 |
| R5 | Keep the original plan, and switch between viewing the plan and the actual dive. | Stage 6 |

## Dive states

A series dive goes through three states. The chip shows which:

| State | Chip | Label | Source of the carry into the next dive |
| --- | --- | --- | --- |
| Planned | outlined diver | letter or name | the planned outcome |
| Converted (a planned entry in the log, not yet dived) | outlined diver | letter or name, unchanged | the planned outcome |
| Completed (the log entry is actual) | solid diver | the logged dive's name, else `#214` | the logged dive's analysis |

- A planned entry in the log has no dive number until it is dived, so a
  converted dive keeps its letter or name. No projected numbers (decided
  2026-11-01).
- **Completed and followed dives use the same label rule:** name first, the
  number only when there is no name, and the date when there is neither.
  This is phase 4's `seriesLoggedDiveLabel`, reused unchanged (decided
  2026-11-01). The letter stays in the tooltip.
- **Names flow one way while a dive is planned, and the other way once it is
  completed:**
  - Planned and converted: the chip shows the planned dive's own name
    (`diveName`), else its letter.
  - Completed: the chip reads the logged dive's name live, so a rename in
    the log shows in the planner.

- A dive becomes completed when its linked dive's `isPlanned` turns false.
  `convertPlanToActualDive` does that through Mark as logged, the edit page's
  Planned switch, or a dive computer download fill. The id stays the same,
  so `linkedDiveId` stays valid.
- Undoing a download fill makes the dive planned again, and the chip goes
  back to converted.

## Stage 0: bring #3759's base up to main

- **Mostly done on #3759 already.** Eric merged main and added `c5f8a0884`:
  `SeriesLoggedDive.endInstant` and `diveEndInstant`. The follow interval
  and the prompt's "ago" now use real elapsed time. Left as is:
  `followSuggestionProvider`'s 48-hour window still compares wall clock
  digits. That is at most an hour out at the window's edge, which doesn't
  matter there. Stage 0 now only checks this landed on main as expected.
- The rest of the #3995 notes below apply to the new code: stage 1's
  timeline and stage 6's actual times must use `diveEndInstant`.
- **#3995's rule** measures the time since a dive in real instants:
  `fromWallClockUtc(stored)` against `clock.now()`. Phase 4 still compares
  wall clock digits through `NoFlyService.wallClockNowUtc()`, which is an
  hour out across a daylight-saving change. The places to change:
  - `plan_follow_providers.dart`: `followSurfaceInterval`'s `now` and
    `followSuggestionProvider`.
  - `plan_follow_prompt.dart`: "ended 2:05 ago".
  - Tests: a follow across a DST change.
- **Pin down the time frame of plan times** before stage 1 builds on them.
  - `DivePlans.startDateTime` is stored as epoch seconds and read back with
    `DateTime.fromMillisecondsSinceEpoch`, which gives local time.
  - Logged dives store wall clock digits as UTC.
  - `toDive()` writes `state.startDateTime` straight into `Dive.dateTime`.
  - Decide on one frame for plan times (recommended: wall clock as UTC, like
    dives) and convert at the boundaries. Otherwise start times derived from
    a logged dive's exit, and converted log dates, can be off by the UTC
    offset.

## Stage 1: timing and site in Dive details (R1, in memory)

### Timing model

- Each dive stores one **timing anchor**: either its surface interval or its
  start time. The other is derived:
  - start = the previous dive's end + the interval
  - interval = start - the previous dive's end
- The previous dive's end is its start plus its runtime. For a followed or
  completed dive, it is the logged exit time.
- The chain needs a start somewhere. It comes from Dive A's typed start, or
  from the followed dive's exit. Without one, later dives show their
  interval only, and their start field is greyed out. Tooltip: "Set Dive A's
  start time first".
- **Dive A, not following:** start time optional, interval greyed out (as
  now).
- **Dive A, following:** typing a start derives the interval, and typing an
  interval derives the start. This is the requirement as stated.
- **Later dives:** the same pairing against the previous dive's end.
- **Which value holds when an earlier dive changes:**
  - An interval anchor keeps the interval, so the start moves when an
    earlier dive's runtime changes.
  - A start anchor keeps the start, so the interval shrinks. If the interval
    goes negative, show an error ("starts before Dive B ends"). Under 10
    minutes it gets the stage 4 warning.
  - The field the diver typed in last becomes the anchor. A small icon shows
    which value is fixed.
- **Domain:** a pure `seriesTimeline(series, results)` returns each dive's
  start, end and interval. The navigator, the summary, conversion and the
  saved list all read it.
- **Today every dive copies Dive A's `startDateTime`** (`appendDive`).
  The timeline replaces that: a dive's stored start is only its anchor.

### Site

- A site picker per dive, reusing the dive log's site picker.
  `DivePlanState.siteId` and `updateSite` already exist but have no editor
  UI.
- A new dive copies the previous dive's site.
- The site is used only when converting, and in the default plan name.

### UI

- The Dive details card holds: name, start (date and time), surface
  interval, and site.
- Phone: the card stays at the top of the Tanks tab, with two rows.
- Desktop: the editor pane.
- Times follow the diver's date and time format settings.

## Stage 2: persistence (phase 3)

### Schema: one rung, the next free number (v333 unless #4028 takes it)

- New synced table **`dive_plan_series`**:
  - `id`, `diverId`, `name`
  - `followedDiveId` (FK to `dives`, nullable)
  - `sharedSettingsJson` (used in stage 3)
  - `createdAt`, `updatedAt`, `hlc`
- **`DivePlans`** gains:
  - `seriesId`, `seriesIndex`
  - `diveName` (nullable, the per-dive name). `name` stays NOT NULL and keeps
    holding the series name on every dive, so older peers still read a
    title.
  - `timingAnchor` (`interval` or `start`)
  - `settingOverrides` (text, used in stage 3)
  - `siteId`, `startDateTime`, `surfaceIntervalSeconds` and `linkedDiveId`
    already exist.
- **`DivePlanTanks`** gains:
  - `sourceTankId`: plain text, no FK. Dive A's source can be a logged
    `dive_tanks` row.
  - `startPressurePinned`.
- **No backfill.** A plan with a null `seriesId` is a one-dive series.
  Backfilling would mint a different series id on each device and sync
  duplicate series.
- Carried tissues, CNS, OTU and start pressures stay derived.

### Sync wiring

Copy `dive_scenarios` (`cfbf933e9` + `110d8b672`):

- **Schema:** the table, `database.dart`, the rung, the helper, the
  backstop, and the index.
- **Sync:** `sync_repository`, `sync_data_serializer` (every switch), and
  `sync_service`. Merge the series before `divePlans`. Add a plan-to-series
  `parentRefs` entry.
- **Change log and conflicts:** `change_log_policy` (tracked), the conflict
  reference and labels, and the field catalogue.
- **Deletes:**
  - `diver_owned_rows`
  - `dive_plan_dive_links`: also null `followed_dive_id`, or deleting a dive
    fails with FK error 787.
- **Demo data:** a seeded three-dive series, with one dive converted and one
  completed, so stages 5 to 7 have demo coverage.
- **Tests:**
  - `migration_v333`
  - a sync round trip
  - `sync_parent_refs_completeness_test`
  - `change_log_every_table_test`

### Repository and flow

- **Repository:**
  - `saveSeries` saves the series row and each dive with `savePlan`, in one
    transaction. It writes `seriesIndex`, the anchor and the timeline start,
    and tombstones removed dives.
  - Also add `getSeries`, `deleteSeries` and `getSeriesForLinkedDive`.
  - Write `diverId` on plans and series. It is never written today.
- **Load:** add `PlanSeriesNotifier.loadSeries`, pushed through `_push` so it
  isn't read as an outside load. Opening any dive opens its series with that
  dive selected.
- **Follow:** rebuild it from `followedDiveId` through
  `seriesFollowProvider`. Don't re-run `followDive`. This closes Eric's gap:
  carried tissues, CNS and OTU come back on reopen.
- **Save:**
  - Saves the whole series. Lift both gates in `planSaveAllowedProvider`:
    - the multi-dive gate
    - the follow gate, which #3759 added in `a967056df`
  - Replace the gate with a test: a saved followed plan, once reopened,
    computes the same schedule, CNS and OTU as before the save. This is the
    test that shows Eric's gap is closed.
  - Update `docs/user/planning.md`, which `a967056df` also changed.
  - The list summary is for the whole series.
  - Leaving the planner with unsaved series changes asks to save, in a
    dialog with its own wording.
- **Delete** deletes the series after confirming.

### Saved plans list, first pass (R3)

- One card per series: its name, its dive count, and total runtime.
- Under it, one line per dive:
  - the letter or name
  - start time, when the chain has an anchor
  - depth and runtime
- Tapping a line opens the series on that dive.
- Build on #3888's `SavedPlanTile` if it has landed.
- Converted dives and links come in stage 7.

### Other

- **`.subplan` v4** gets a `series` block. Single-dive plans keep writing
  v2/v3. The followed dive and the sites are not exported, since they're
  local references.
- **Shortcuts:**
  - `Alt+Left` and `Alt+Right` select the previous and next dive. (`Alt+N`
    was tried and removed: Windows beeps at Alt+letter, and it added little.)
  - Register them in `ShortcutCatalog` and wrap them in
    `NotWhileTypingActivator`.

## Stage 3: shared settings (phase 2)

- **Keep effective values.** Per-dive setting columns keep their complete
  values. Nulls already mean "diver default", and every "off" flag stays.
  Added on top:
  - `settingOverrides`: the groups this dive owns.
  - `sharedSettingsJson`: the series value of each group. It survives even
    when every dive overrides a group.
- **Why:** older peers, the engine, `resolvedFor` and every setup section keep
  reading complete per-dive values.
- **Groups**, from the Setup accordion:
  - Deco: GF, air breaks
  - Rates: rates, last stop
  - Gas: SAC, reserve, gas options, ppO2 bands
  - Environment: altitude, water, salinity
  - Contingencies
- **Excluded:**
  - mode and setpoints, stop minimums, gear and weights, the DPV mission, and
    the site (R1 makes it per dive)
  - the pSCR ratio, which stays a diver setting
- **Editing:**
  - Editing a group on a dive that doesn't override it writes the series
    value and every non-overriding dive.
  - Editing it on an overriding dive changes that dive only.
  - Each group header has a "Series" or "This dive" chip. Its first edit on
    a later dive asks "This dive / All dives".
  - **Reset to series** copies the series value back.
- **Code:**
  - Add `plan_setting_groups.dart` with an extract and apply function per
    group. `editorChanged` then diffs groups instead of about 40 fields.
  - Writing rates to another dive goes through `_withMissionSegments`.
  - The environment snapshot (`adoptPlannerWaterIfPristine`) applies to the
    series value.
  - Add the shared settings to `_chainInputs`.

## Stage 4: series warnings and summary (phase 2)

### New issue types

Each new type gets an entry in `plan_issue_text.dart`. They merge into the
dive's issues, so the dot, the markers and the warnings section show them.

- Surface interval under 10 minutes (warning).
- A negative interval from a start anchor (critical).
- Starting with a deco obligation: `surfaceCeilingMeters > 0` on the
  carried, off-gassed tissues (critical).
- Reverse profile: deeper than the previous dive by more than a margin
  (warning).

### CNS and OTU

- The engine already flags these across the series, because it starts from
  the carried exposure. Don't add duplicates.
- Say in the existing messages that the figures include earlier dives.
- `otuLimit` is hard-coded at 300. Decide whether it becomes a daily limit.

### Series summary card

Built and removed (2026-11-01): it took space above the deco schedule, which
matters more. No no-fly time in the planner either.

## Stage 5: update planned dives in the log, and links back (R2)

- **The menu entry "Convert to Dive" becomes "Update planned dives"**
  (`divePlanner_action_convertToDive`; the key is renamed in all 11
  locales). The same action creates entries the first time and updates them
  afterwards. Nothing is rewritten on save: updating the log is always this
  explicit action.
- It runs on the whole series. It needs a saved
  series and a chain anchor, and prompts for Dive A's start time if there is
  none.
- Each dive becomes a planned log entry with:
  - its timeline start
  - its site
  - its computed profile, tanks and gases
  - `linkedDiveId` set on its plan row
- **How it treats each dive:**
  - A dive with no log entry yet gets a new planned entry.
  - A dive whose entry is still planned has that entry rewritten with its
    current time, site, profile and tanks, keeping the same dive id.
  - A completed dive is never touched.
  - A dive removed from the series whose planned entry is still in the log:
    offer to delete that entry. Leaving it keeps a planned entry with no
    plan, so it loses its "Open in planner" link. (Decided 2026-11-01.)
    Removing the dive must keep its log entry's id until the update runs.
    The series still has to know which entries it owns. Keep removed dives'
    `linkedDiveId`s on the series until "Update planned dives" settles them.
- **Log entry names:**
  - A planned entry takes the planned dive's own name, and stays unnamed
    when the dive has none. There is no "<series> · Dive B" fallback, which
    would have hidden the number on the completed chip.
  - Each update rewrites the name while the entry is still planned, so a
    rename made in the log to a planned entry is overwritten.
  - Once the dive is completed, the log owns the name.
- **Fix:** `toDive()` names the entry from `state.name`, the whole plan's name
  (`dive_planner_providers.dart:1226`). It must use the series dive's name
  instead. Test: converting a three-dive series gives three differently
  named entries, or unnamed ones.
- **The chip doesn't change on conversion.** It keeps its letter or name
  and the outlined icon. A deleted log entry clears the link
  (`dive_plan_dive_links`), and the dive goes back to plain planned.

### Links from the dive log back to the planner

- **Finding the plan.** The link is the plan row's `linkedDiveId`, so a dive
  needs no new column.
  - Add `getSeriesForLinkedDive(diveId)`, which returns the series id and
    the dive's index.
  - Add `planForLoggedDiveProvider(diveId)`, which watches the plan tables
    so the links stay current.
- **Planned entry:** `PlannedDiveBanner` gets an "Open in planner" button
  next to Mark as logged. It is shown only when a plan links to the dive.
- **Completed dive:** the dive detail ⋮ menu gets **View in planner**,
  placed with Replan / Compare / Plan repetitive dive. It is shown only when
  the dive came from a plan that still exists.
- **Silent removal.** Deleting the plan removes its row, and with it the
  `linkedDiveId`. The lookup then returns nothing, so the button and the
  menu entry disappear. Nothing to clean up, and no message.
- **Where it opens.** The series, with that dive selected. For a completed
  dive it opens on the actual view (stage 6). Use `planner_navigation.dart`,
  which goes back to a planner already in the stack rather than pushing a
  second one.
- **Several plans.** `getPlanByLinkedDiveId` takes the newest when several
  plans link to one dive. With series, each dive row is linked from one plan
  row. Keep "newest wins" for older data.

## Stage 6: completed dives replace the plan (R4, R5)

### Calculator (R4)

- `PlanSeriesDive` gains an `actual` slot, filled from the linked dive when
  that dive is completed. It holds the logged profile, entry and exit, the
  end tanks, and the analysis (end tissues, CNS, OTU).
- `carriedState` takes the next dive's carry from the actual dive. It reads
  the same analysis path as a follow, through `seriesFollowProvider`'s
  loader, generalised to any dive id.
- The timeline uses the actual entry and exit:
  - A later dive with an interval anchor moves with them.
  - A later dive with a start anchor keeps its start, and its interval
    changes.
- `_carriedOtu` counts the actual OTU at the real end time.
- Letters and positions don't change: the dive stays in `series.dives`.
- **Out of order:** if Dive B is completed while A is not, B's actual carry
  still applies from B onwards.
- **The original plan is kept untouched** in its `dive_plans` row. The
  actual data is read live from `dives` and never copied into the plan.

### Plan / actual view (R5)

Pick one, or A plus B together.

**A. Plan | Actual toggle.**
- A segmented control in the profile header, only on completed dives. It
  defaults to Actual.
- **Actual:** the read-only logged view (the chart, Open in dive log, and the
  carry facts), as for a followed dive.
- **Plan:** the original plan in the normal editor, read-only, with a
  banner: "Planned. Completed as Dive #214."
- **Pros:** simple, and each view is a screen that already exists.
- **Con:** comparing means flipping between the two.

**B. Actual with a plan ghost.**
- The actual profile is the main line. The plan is drawn as a dashed ghost,
  using the replan overlay (`sourceDiveOverlaySeriesProvider`, generalised
  from `sourceDiveId` to any dive id).
- A compare strip shows planned against actual for runtime, max depth, TTS,
  deco time, CNS and gas used. It reuses `PlanSourceDiveCompareStrip`.
- A legend toggle hides the ghost.
- **Pros:** you see the difference at a glance, and it matches the dive
  log's planned-profile overlay.
- **Con:** two profiles on a phone chart get busy.

**C. The navigator decides** (optional, on top of A or B).
- A completed chip gets a small menu: "Carry on from: actual / plan".
- "Plan" recalculates the later dives as if the dive had gone as planned:
  "what if I'd stuck to the plan".
- **Pro:** it answers a real question for the next dive.
- **Con:** it is another state to explain, and the default must stay actual.

**Decided (2026-11-01):** B is the default view. A toggle in the header
switches to A, the full read-only plan, and back. C is left out.

**Dive log side.** `plannedProfileOverlayProvider` recomputes a linked plan
without residual load. For series dives after A, compute it through the
series (`seriesId`, `seriesIndex`), or the purple ghost shows a fresh-diver
schedule.

## Stage 7: saved plans list, full (R3)

- A dive line gets its state icon (outlined or solid) and the same label as
  its chip.
- Converted and completed lines carry an "Open in dive log" link to the
  linked dive. A completed line shows the actual depth and runtime, with the
  planned figures under them.
- The series card shows "2 of 3 dived".
- Global search (#3888) opens the series on the matching dive.

## Spec updates in the same PR

Add to `docs/design/specs/2026-10-27-repetitive-dive-planning-design.md`:

- the timing model and anchor rules
- the three dive states
- the storage decisions: no backfill, `diveName`, `sourceTankId` without an
  FK, settings stored as effective values plus overrides
- conversion and numbering
- actual replacement, and the chosen plan/actual view

Save this plan as
`docs/design/plans/2026-11-01-repetitive-dive-planning-phase-2-3-5.md`.

## Conflicts with open PRs (checked 2026-11-01)

| PR | Overlap | Effect |
| --- | --- | --- |
| #3759 | Base. Shows as conflicting with main (`follow_dive_sheet.dart`, #3995). | Stage 0. |
| #4028 (draft) | Schema v333, migration ladder, `database.dart`, `app_router.dart`. | Rung number and step-count test. Whoever merges second renumbers. |
| #3888 (draft, Eric) | `SavedPlanTile` in `saved_plans_list.dart`. A plan query entity scoped by `diver_id`. | Stages 2 and 7 restructure the list and start writing `diver_id`. Coordinate with Eric. |
| #4033 | `plan_calculator_service.dart`, planner engine tests. | Low. |
| #4039 | `sync_data_serializer.dart`. | Textual conflicts likely, since stage 2 edits about 12 switches there. |
| #4038, #4037, #4004, #3791 | `app_en.arb`. | Mechanical. |
| others | none | none |

## Decisions (2026-11-01)

1. No projected dive numbers. A converted dive keeps its name or letter.
   Planned log entries get "Open in planner". Completed dives get "View in
   planner" in the ⋮ menu, shown only while the plan exists.
2. The plan/actual view is B, with a toggle to A.
3. No matching of dives logged without a conversion. Following covers that
   case.
4. "Convert to Dive" becomes "Update planned dives". The log is updated only
   by that action.

5. Chip labels: name first, the number only when there is no name. This
   applies to followed and completed dives alike.

## Still open

- When a dive removed from the series still has a planned entry in the log,
  "Update planned dives" asks whether to delete it: confirm.

## Open issues to raise with the PR

- **A dive marked as logged with no download carries planned values.** Mark as
  logged makes a planned entry a dive, so the next dive carries that entry's
  analysis: the plan's own profile and gas switches, with no end tank pressures.
  It counts as if it went exactly to plan. Left as it is for now (decided
  2026-11-01); say so in the PR description.
