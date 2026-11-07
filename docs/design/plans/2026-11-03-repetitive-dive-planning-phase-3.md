# Repetitive dive planning, phase 3: saving a series

Issue #3565, discussion #3700. Design record:
`docs/design/specs/2026-10-27-repetitive-dive-planning-design.md`.

## Background

Phases 2, 3 and 5 were first built together in draft PR #4080, which is now
closed. That work overlapped #4058 (comparing a plan with its dive), which
merged first. The feature is being rebuilt on current `main` in smaller PRs.
Where it overlaps #4058, #4058's approach is kept and this work adds only what
a series needs. Phase 3 comes first because it closes the saving gap: a plan
that follows a logged dive, or a series of several dives, cannot be saved
today. `planSaveAllowedProvider` holds Save back (commit `a967056df`), because
a saved followed plan would reopen without its tissues, CNS and OTU.

### The reference copy

The earlier work is on the fork branch
`feature-request-3565-repetitive-dive-planning-phase-2-3-5`, and on the local
tag `backup/3565-phase-2-3-5` (`acb27a169f`). Read files from it with
`git show backup/3565-phase-2-3-5:<path>`. Copy what fits, but strip anything
belonging to phases 2 or 5 (see "Out of scope"). The phase 3 commits there
are:

| Commit | What |
|---|---|
| `a6a57bf9e6` | Store the series: table, columns, migration, sync, conflicts, diver-owned rows, dive links |
| `e38a542954` | Save and reopen a series: `StoredSeries`, `DivePlanSeriesRepository`, `plan_series_store.dart` |
| `32319f7752` | Saved plans list with a line per dive |
| `f39a91e8c6` | Keep a series' follow and owner across diver profiles |
| `60e052b37c` | Sync tests through the save path and across devices |
| `d7d0473224` | Share (`.subplan` v4), duplicate, and leaving a series safely |
| `4f63746db7` | Ask before opening a plan over unsaved changes |

Those commits also carry phase 2 fields: `fixedStart`, `settingOverrides`,
`PlanSettingGroup`, start times and site. Leave them out.

## What main already has

- `PlanSeries` (`dives`, `selectedIndex`, `follow`) and `PlanSeriesDive`
  (`state`, `sourceTankIds`, `pinnedTankIds`, `name`), held in memory only.
- Following logged dives (phase 4), with `SeriesFollow`.
- `planSaveAllowedProvider`: false for a series or a followed plan.
- #4058: `linkPlanToDive`, `unlinkPlan`, `DivePlanNotifier.adoptLink`, the
  Link, Change and Unlink sheets, the "Dived as #N" badge, and
  `linkedPlanComparisonProvider`.
- #3888: `SavedPlanTile`, and plan search scoped by `diver_id`.
- Schema v337 when this was written. Phase 3 takes the next free version;
  check `currentSchemaVersion` before starting and again before the PR.

## Scope

1. **Schema (next free version, v338 today).**
   - New synced table `dive_plan_series`: `id`, `diverId` (FK, nullable),
     `name`, `followedDiveId` (FK to dives, nullable), `createdAt`,
     `updatedAt`, `hlc`.
   - `dive_plans`: `seriesId` (FK, nullable), `seriesIndex`, `diveName`.
   - `dive_plan_tanks`: `sourceTankId` (no FK, it names a tank in the
     previous plan), `startPressurePinned` (default false).
   - No backfill. A plan with no series is a one-dive series.
   - Migration helper creates the table unconditionally (a partial fixture
     in an older migration test lacked it), plus a beforeOpen backstop.
2. **Sync and integrity.** Serializer, merge series before plans,
   `parentRefs`, `repairDanglingForeignKeys`, change log policy, conflict
   catalogue and labels, `diver_owned_rows`, demo data coverage check and
   seeder. Deleting a followed dive clears `followed_dive_id`
   (`dive_plan_dive_links`); the series then reopens clean.
3. **Save and reopen.**
   - `StoredSeries` and `StoredSeriesDive`; `DivePlanSeriesRepository` with
     `saveSeries`, `getSeries`, `seriesIdForPlan`, `deleteSeries`,
     `renameSeries`, `duplicateSeries`.
   - `plan_series_store.dart`: `saveCurrentSeries`, `openSavedPlan`,
     `seriesFromStored`.
   - Reopening a followed series reads the followed dive from the log and
     recomputes the carry, so it plans with the same tissues, CNS and OTU.
     This replaces the Save hold: `planSaveAllowedProvider` lets a series and
     a followed plan save.
   - The series owner is the diver who first saves it. A series following
     another diver's dive still finds that dive.
4. **Links stay with #4058.** Saving a series never writes a plan's link to
   its dive. Only #4058's Link, Change and Unlink actions (and, later, Create
   or Update planned dives) change a link. This removes the stale-link problem
   found in #4080.
5. **Saved plans list.** One row per series, built from `SavedPlanTile`, with a
   line per dive. Each dive's line carries its own "Dived as #N" badge and its
   own Link and Unlink. Rename, Duplicate, Share and Delete act on the whole
   series. Opening a search result from #3888 opens its whole series.
6. **`.subplan` version 4** holds a series, with tank carry stored by position.
   The followed dive is left out (it is in this device's log, not the
   recipient's). Single plans still write versions 2 or 3.
7. **Unsaved changes.** Leaving the planner with unsaved series changes, or
   opening a different plan over them, asks Save, Discard or Cancel
   (`showUnsavedPlanDialog(context, isSeries:)`).

## Out of scope for phase 3

- **Phase 2:** shared settings and their groups, start time and site, series
  warnings, the tank carry rule changes.
- **Create or Update planned dives** (writing the series to the log,
  phase 2b). It depends on #4058's link actions and its Convert
  confirmation, so it gets its own PR after this one. Convert to Dive keeps
  its current hold for a series.
- **Phase 5:** a dived dive replacing its plan in the chain (R4), and plan
  against actual (R5).
- Diver scoping of single saved plans (#4074).

## Stages

Each stage is one commit that passes analyze and its tests. TDD: tests first.

1. Schema, migration, sync and integrity (scope items 1 and 2), with the
   migration test, sync round trip, parent refs completeness and dive link
   tests.
2. Save and reopen, and lifting the Save hold (items 3 and 4).
3. Saved plans list on `SavedPlanTile` (item 5).
4. Share and duplicate (item 6), and the unsaved changes prompts (item 7).
5. Docs: update the spec's persistence section, `docs/user/planning.md`.

Then: l10n in all 11 locales (en, de, es, fr, it, nl, pt, hu, he, ar, zh),
`dart format .`, `flutter analyze`, and the full suite with
`TEST_CONCURRENCY=22 scripts/run_all_tests.sh`.

## Decisions made so far

These cover the whole feature, so later phases can use them too.

### Process

- Rebuild on `main` in smaller PRs; #4080 is closed. Where this work overlaps
  #4058, #4058's approach is kept.
- No push, `pub get` or codegen unless asked. Whole-suite or multi-folder runs
  use `scripts/run_all_tests.sh`; plain `flutter test` only for a few files.
- Nothing in the repo or on GitHub mentions the tool used to write it.
- PR description: `Refs #3565`, and screenshots through the secret gist
  `PR screenshots: submersion-app/submersion`.

### Saving (phase 3)

- The first saver owns a series. A plan with no series is a one-dive series,
  with no backfill.
- Saving never writes links (see scope item 4).
- `.subplan` v4 leaves out the followed dive and start times.

### Series settings and tanks (phase 2)

- The first dive's settings are the series'. A later dive takes them until a
  group is changed (deco, rates, gas, environment, contingencies, tanks), with
  Reset to series and Apply to all dives. No "This dive / All dives" question
  while editing.
- A later dive takes the series' tanks and gases unless it has its own.
- A tank carries its pressure from the previous planned dive only if it is the
  same tank, size and gas. A different tank, including one changed on Dive A,
  starts full. Logged dives and planned dives are not to be confused here.
- Start time and site go in Dive details. Start and surface interval set each
  other; the one typed last holds. Site is used only when the plan goes to the
  log.
- Following a dive that ended less than an hour ago defaults the surface
  interval to one hour, with the start set from it. Otherwise the start
  defaults to now. This is a default only, never a limit.
- Follow lists every logged dive, even one over 48 hours old. Left for
  feedback.
- Series warnings: surface interval under 10 minutes, a start before the
  previous dive ends, starting with a deco obligation, and a reverse profile
  more than 12 m deeper than the dive before.
- No series summary card and no no-fly time in the planner.
- Alt+Left and Alt+Right move between dives. No Alt+N (it beeped on Windows
  and is not a convention in the app).

### Planned dives in the log (phase 2b, after phase 3)

- The menu item reads "Create planned dives" until there are some, then
  "Update planned dives", with plural forms matched to the count.
- A planned entry keeps the planned dive's name. No projected dive numbers.
  A chip shows a dive's name first, its number only if it has no name.
- A planned entry's banner links to the planner; a dived dive's menu has
  "View in planner" while the plan still exists, and the link disappears
  silently once the plan is deleted.
- A planned entry's profile is sampled every 30 seconds, and the plan's gas
  switches (on the fly as well as at stops) are written to it, open circuit
  only. A download clears them; undo restores them.
- Profile and export titles read "Planned dive", not "Dive #0".
- A dive removed from the series offers to delete its log entry.
- Check against #4058's Convert confirmation before building.

### Dived dives (phase 5)

- A dived dive replaces its plan in the chain, carrying its logged tissues,
  CNS, OTU and tank pressures from its real end time. No looking for a
  matching dive: following covers that.
- The original plan is kept. Rebuild on #4058's Compare page and
  `compare_columns`: the planner shows a light summary with a link to Compare,
  and can switch to the read-only plan. `linkedPlanComparisonProvider` needs
  the series carry for later dives.
- Open question: a dive marked as logged with no download carries its planned
  values into the next dive. Left as is; raise it in the PR.

### Not in this feature

- Gas switch markers on the planner profile (#4078).
- No calculated safety stop on a logged deco dive (#4079).
- Diver scoping of saved plans (#4074).
