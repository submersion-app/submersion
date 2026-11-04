# Repetitive dive planning, phase 2: timing, warnings and shared settings

Issue #3565, discussion #3700. Design record:
`docs/design/specs/2026-10-27-repetitive-dive-planning-design.md`. Phase 3
(saving a series, #4147) is merged; its plan,
`docs/design/plans/2026-11-03-repetitive-dive-planning-phase-3.md`, holds the
decisions for the whole feature that this plan builds on.

## Background

Phase 2 was first built in the closed draft PR #4080, together with phases 3
and 5. The work is on the local tag `backup/3565-phase-2-3-5`. Phase 3 has
been rebuilt on `main` without the phase 2 fields, so phase 2 now adds them
to what main stores. It goes in one PR, on branch
`feature-request-3565-repetitive-dive-planning-phase-2`, in two parts:

- **Part A:** start time and site, series warnings, moving between dives
  from the keyboard.
- **Part B:** settings shared across a series, and tanks shared across it.

| Backup commit | What | Part |
|---|---|---|
| `1fb123f197` | Start time and site per dive | A |
| `dcb6622bd7` (part) | Follow default interval: an hour, or the time since | A |
| `035a8777db`, `7915f689c3` (part) | Alt+Left and Alt+Right | A |
| `89e50d32f3`, `e907849eef`, `a058b585b0` | Series warnings, without the summary card | A |
| `5a1f67b239` | Shared settings and their groups | B |
| `dcb6622bd7` | Shared tanks and the carry rule | B |

Left out: Alt+N, and the Windows runner change (`6344d82fbd`) that tried to
stop its beep. Alt+Left and Alt+Right do not beep.

## Part A: timing, warnings and shortcuts

### Start time and site

- Dive details holds the dive name, its start, the surface interval and its
  site. Start and site are optional.
- Start and interval set each other; the one typed last holds
  (`PlanSeriesDive.fixedStart`). See the spec's "Start time and site".
- Following a dive that ended less than an hour ago defaults the interval to
  an hour; otherwise to the time since, rounded up to the minute, so the
  plan starts now. The Follow prompt rounds the same way.
- Times are clock digits stamped UTC, like the dive log's. Convert to Dive
  writes the plan's start, or the clock time now, in that form.

### Saving and sharing the start

- **Schema v342:** `dive_plans.fixed_start` (bool, default false, no
  backfill). `start_date_time` and `site_id` already exist. Conflict
  catalogue entry and label; the migration test; the beforeOpen backstop.
- `StoredSeriesDive.fixedStart`, written and read by
  `DivePlanSeriesRepository`, carried by duplicate, cleared when a series
  is reduced to a lone plan.
- **`.subplan`:** a plan's optional `startDateTime`, as clock digits with no
  offset, in every version, and a series dive's optional `fixedStart`. No
  version bump: both are optional, so an older install opens the file
  without its times. This reverses phase 3's decision to leave the start
  out of the file (asked for on 2026-11-03).
- The site stays out of the file: it names a site in the sender's log.

### Series warnings

Each a new issue type in `plan_issue_text.dart`, merged into the dive's
issues, so the dot, the chart markers and the warnings section show them:

- Surface interval under 10 minutes (warning).
- A start before the previous dive ends (critical).
- Starting with a deco obligation: a surface ceiling on the carried,
  off-gassed tissues (critical).
- Reverse profile: more than 12 m deeper than the dive before (warning).

No series summary card and no no-fly time in the planner. CNS and OTU need
no warning of their own: the engine starts each dive from the carried
exposure, so its existing warnings already count earlier dives.

### Shortcuts

Alt+Left and Alt+Right select the previous and next dive, registered in
`ShortcutCatalog` and wrapped in `NotWhileTypingActivator`.

## Part B: shared settings and tanks

### Settings

- The first dive's settings are the series'. A later dive takes them until
  one of its groups is changed. Groups, from the Setup accordion: deco (GF,
  last stop, air breaks), rates (rates), gas (SAC, reserve, gas options,
  ppO2 bands), environment (altitude, water, salinity), contingencies.
- Not shared: mode and setpoints, stop minimums, gear and weights, the DPV
  mission, the site, the pSCR ratio.
- Each group header shows "Series" or "This dive", with Reset to series and
  Apply to all dives. No "This dive / All dives" question while editing.
- Stored as effective values: each dive's setting columns stay complete, so
  older peers and the engine read them as before. Added on top:
  `dive_plans.setting_overrides`, the groups a dive owns, in the next
  schema version. The series' value of a group is the first dive's, so
  nothing else is stored.

### Tanks

- A later dive takes the series' tanks and gases unless it has its own.
- A tank carries its pressure from the previous planned dive only if it is
  the same tank, size and gas. A different tank, including one changed on
  Dive A, starts full. Logged dives and planned dives are not to be
  confused here.

## Process

- Each feature is one commit, tests first, passing analyze and its tests,
  and is pushed to the fork when done.
- l10n in all 11 locales, `dart format .`, `flutter analyze`, and the full
  suite with `scripts/run_all_tests.sh` before the PR.
- PR descriptions: `Refs #3565`, screenshots through the secret gist.
- Check `currentSchemaVersion` against `main` again before the PR.

## Known issue to raise in the PR

`lib/features/planner/presentation/pages/plan_canvas_page.dart` is 1,102
lines, over the 800-line limit. It was already 1,044 before phase 2; the
logged-dive layout added about 60. The PR description must say so, and that
it will likely need resolving before the PR is merged. The proposed fix, as
its own small PR with its own issue: move the menu, the layouts and the
actions into three `part` files, each a mixin on the page's state, as
`plan_canvas_series_flows.dart` already is. That is a move, not a rewrite,
and leaves the page at about 350 lines. Convert to Dive stays put until the
"Create / Update planned dives" work rewrites it.
