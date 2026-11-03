# Repetitive dive planning, R2: a series as planned dives in the log

Issue #3565, discussion #3700. Design record:
`docs/design/specs/2026-10-27-repetitive-dive-planning-design.md`. Builds on
phase 2 (#4175), which gives each dive its start time and site. The decisions
already made for R2 are in
`docs/design/plans/2026-11-03-repetitive-dive-planning-phase-3.md`, "Planned
dives in the log (R2, after phase 3)"; this plan does not repeat them all.

## Background

R2 was built in the closed draft PR #4080 and is on the local tag
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

1. Phase 2 (#4175) merged.
2. The planner page split (`plan_canvas_page.dart` over 800 lines; see the
   phase 2 plan, "Known issue to raise in the PR"). R2 then moves Convert to
   Dive out of the page into `plan_log_update.dart`, shrinking it further.
3. R2.
4. Phase 5, which needs R2's links to know a dive has been dived.

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
     offer to delete it. **Open:** confirm this, or leave the entry.
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
  and its "As planned" results come from the plan R2 linked.
- `currentSchemaVersion`: R2 needs no schema change as planned.

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
