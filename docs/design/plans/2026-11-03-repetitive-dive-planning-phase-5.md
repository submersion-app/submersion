# Repetitive dive planning, phase 5: a dived dive replaces its plan

Issue #3565, discussion #3700. Design record:
`docs/design/specs/2026-10-27-repetitive-dive-planning-design.md`. Needs
phase 2b
(`docs/design/plans/2026-11-03-repetitive-dive-planning-phase-2b-planned-dives.md`),
whose links tell the series that one of its dives has been dived. The
decisions already made are in
`docs/design/plans/2026-11-03-repetitive-dive-planning-phase-3.md`, "Dived
dives (phase 5)". This is the last phase, so its PR can close #3565.

## Background

Built in the closed draft PR #4080; on the local tag
`backup/3565-phase-2-3-5`:

| Backup commit | What | Size, without l10n |
|---|---|---|
| `11686ad95d` | Use what really happened on a dive that has been dived | ~1,170, 530 of it tests |
| `cdce71ef4a` (state half) | The dived state on each dive's line in the saved plans list | ~100 |

The backup's view of a dived dive was its own page (`plan_logged_dive_view`).
Phase 2 (#4175, merged 2026-11-04) replaced that page with the logged dive
shown in the planner's own layout, so phase 5 builds on that instead. That
layout now lives in `plan_canvas_layouts.dart`, a `part` file of the planner
page, after the maintainer's split in review; the dived view goes there,
not back into `plan_canvas_page.dart` (779 lines).

## Scope

1. **A dived dive replaces its plan in the chain (R4).** Once its log entry
   is no longer planned (Mark as logged, the edit page's switch, or a
   download), the dive after it carries the logged end tissues, CNS, OTU and
   tank pressures from the logged exit time, and every later dive
   recalculates.
   - `PlanSeriesDive` gains an `actual` slot, read live from the log and
     never stored: the plan's own row stays the original plan.
   - The timeline uses the actual entry and exit: a later dive led by its
     interval moves with them; one with a fixed start keeps it. Intervals
     are measured between true instants, never by subtracting clock digits:
     the maintainer settled this for logged dives in #4175 (967c578,
     `loggedSurfaceInterval` reads the start through `fromWallClockUtc`
     against the end instant). Use that helper or the same rule, with a
     test across a daylight saving change.
   - Anything that shows an interval or a carry from the dived dive reads
     it as the series settles it (`planSeriesResultsProvider`), not from a
     dive's stored state, as the logged-dive carry card does since 967c578.
     A stored interval is stale after the actual times arrive until the dive
     is next selected.
   - An undone download takes the dive back to its plan.
   - Out of order: if Dive B is dived and A is not, B's actual still carries
     from B on.
   - No looking for a matching dive: following covers dives logged without a
     plan.
2. **Plan and actual (R5).** The dive's chip becomes the solid diver with the
   logged dive's name, else its number. It opens on what happened, in the
   logged-dive layout from phase 2, with its plan ghosted on the chart and
   its results "as planned". A toggle switches to the plan itself, read-only,
   in the normal planner. Compare stays the place for planned against actual
   in detail (#4058's `compare_columns`).
3. **The series carry for "as planned".** Phase 2's "As planned" results,
   Compare and the dive log's planned overlay all compute a plan from a fresh
   diver. For a later dive of a series they must start from what the dives
   before it were planned to leave: `linkedPlanComparisonProvider` takes the
   series carry for dives after the first, through `seriesId` and
   `seriesIndex`.
4. **Saved plans list.** Each dived dive's line shows it, and the series
   shows "2 of 3 dived".

## Open question, to raise in the PR

A dive marked as logged with no download carries its planned values into the
next dive: Mark as logged makes the planned entry a dive, whose analysis is
the plan's own profile and gas switches with no end tank pressures, so it
counts as if it went exactly to plan. Left as it is for now (decided
2026-11-01).

## Stages

Each one commit, tests first, analyze and tests passing, pushed when done.

1. Calculator: the `actual` slot, the carry from it, the timeline from the
   actual entry and exit; out-of-order and undo cases.
2. The series carry into `linkedPlanComparisonProvider` and the dive log's
   planned overlay.
3. The chip, and the dived dive in the logged-dive layout with the toggle to
   its plan.
4. Saved plans list states.
5. Docs: spec, `docs/user/planning.md`.

Then l10n in all 11 locales, `dart format .`, `flutter analyze`, the full
suite with `scripts/run_all_tests.sh`, screenshots through the gist, and
`Closes #3565` if nothing of the issue is left.
