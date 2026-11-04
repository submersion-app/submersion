# Repetitive dive planning, phase 2b: a series as planned dives in the log

Issue #3565, discussion #3700. Design record:
`docs/design/specs/2026-10-27-repetitive-dive-planning-design.md`. Builds on
phase 2 (#4175), which gives each dive its start time and site. The decisions
already made for phase 2b are in
`docs/design/plans/2026-11-03-repetitive-dive-planning-phase-3.md`, "Planned
dives in the log (phase 2b, after phase 3)"; this plan does not repeat them
all.

## Background

Phase 2b was built in the closed draft PR #4080 and is on the local tag
`backup/3565-phase-2-3-5`. Phase 3 left it out because it depends on #4058's
link actions and its Convert confirmation, which merged after #4080 was
written. Convert to Dive still holds back on a series.

| Backup commit | What | Size, without l10n |
|---|---|---|
| `e29eacaecd` | Update planned dives in the log; links back from the log | ~1,050, 250 of it tests |
| `9fa0a0a60d`, `b18b267ff1` | "Create" until there are some, then "Update"; plural wording | ~80 |
| `daf00a7e01` | A planned entry matches its plan: 30-second samples, titles, download | ~300 |
| `acb27a169f` | Gas switches written, on the fly too | ~240 |
| `cdce71ef4a` (log half) | Each saved dive's state and link in the saved plans list | ~200 |

About 800 lines of code and 750 of tests: the size of phase 2 or phase 3.

## Order

1. Phase 2 (#4175), merged 2026-11-04.
2. The planner page split, done in #4175's review by the maintainer (see
   the phase 2 plan, "The planner page's size"): only the layouts moved, into
   `plan_canvas_layouts.dart`, leaving `plan_canvas_page.dart` at 779 lines.
   No separate split PR. Phase 2b moves Convert to Dive out of the page into
   `plan_log_update.dart`, as that section expects; the page must stay under
   800 lines with the new menu item. If it would not, move the menu into a
   `part` file with a mixin on the page's state, the same way.
3. Phase 2b.
4. Phase 5, which needs phase 2b's links to know a dive has been dived.

## Scope

1. **The menu item.** "Create planned dives" until the series has some, then
   "Update planned dives", with plural forms matched to the count. It
   replaces Convert to Dive and acts on the whole series. It needs a saved
   series and a start (phase 2), and asks for Dive A's start if there is
   none. The log is updated only by this action, never by Save.
2. **Each dive.**
   - No log entry: a new planned entry with its start, site, name, computed
     profile (sampled every 30 seconds), tanks and gases, and the plan's gas
     switches (on the fly as well as at stops, open circuit only).
   - A planned entry: rewritten in place, same dive id.
   - A dived entry: never touched.
   - A dive removed from the series whose planned entry is still in the log:
     offer to delete it (decided 2026-11-04). Only a planned entry; a dived
     one is never offered.
3. **Names.** An entry takes the planned dive's own name, else stays unnamed.
   `toDive()` names it from the whole plan today; it must use the dive's.
   No projected dive numbers.
4. **Links back from the log.** The plan row's `linkedDiveId` is the link;
   no new column. `planForLoggedDiveProvider(diveId)` watches the plan tables.
   - The planned dive banner gets "Open in planner".
   - A dived dive's menu gets "View in planner" while the plan exists; the
     link disappears silently once the plan is deleted.
   - Both open the series on that dive through `planner_navigation.dart`,
     which goes back to a planner already in the stack.
5. **The log entry matches its plan.** Profile and export titles read
   "Planned dive", not "Dive #0". A download clears the planned gas switches;
   undo restores them.
6. **Saved plans list.** Each dive's line shows whether it is planned, in the
   log as planned, or dived, with its link.

## Check before building

- #4058's Convert confirmation (`confirmLinkMove`) and link actions: each
  dive's link must go through them, and a dive already linked by hand to a
  logged dive must not be overwritten.
- The logged-dive layout from phase 2: a dived dive's chip opens it there,
  and its "As planned" results come from the plan phase 2b linked.
- `currentSchemaVersion` (342 on main): phase 2b needs no schema change as
  planned.
- Gas switches (#4173): `gasSwitchesEditable` keeps the dive editor off a
  planned dive's switches because "a planned dive's switches belong to the
  plan". Phase 2b keeps that: only Update planned dives writes them, and a
  download clears them. Write them through the dive log's existing switch
  storage rather than a new path.
- Rebreather start gas (#4174): a CCR dive's starting gas is its diluent.
  Phase 2b writes no switches on a CCR entry, so the entry must carry its
  diluent in a form `startingTankOf` and the gas timeline pick up.
- Start times: a series' starts are clock digits stamped UTC, with intervals
  measured between true instants (`fromWallClockUtc`), as in phase 2. Each
  entry's `diveDateTime` takes the dive's clock digits unchanged. The
  maintainer declined a migration for older plans' start column in #4175
  (nothing could set it before), so phase 2b has none to handle.

## Stages

Each one commit, tests first, analyze and tests passing, pushed when done.

1. `plan_log_update.dart`: create and update entries for the series, names,
   removed dives, with Convert to Dive's code moved out of the page.
2. The menu item, its wording and the start-time prompt; the Convert hold
   lifted for a series.
3. Profile sampling, gas switches, titles, download and undo.
4. Links back from the log: banner, dive menu, provider, navigation.
5. Saved plans list states.
6. Docs: spec, `docs/user/planning.md`.

Then l10n in all 11 locales, `dart format .`, `flutter analyze`, the full
suite with `scripts/run_all_tests.sh`, screenshots through the gist, and
`Refs #3565`.
