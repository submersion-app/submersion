# Planner: compute secondary results off the UI isolate

Issue: #3825. Target release: v1.8.4.

## Why

Every plan edit (a waypoint drag, a typed figure) re-runs the plan engine many
times on the UI isolate. The results sheet watches the range table at its top
level, so the 25-variant table is computed even when it is scrolled out of view.
Issue #3825 measured this on a simple air plan. Measured on three plan shapes
(medians, debug `flutter test` on an Apple M5 Pro, plain tissues):

| Plan | Main schedule | Bailout | Range table | Per edit |
| --- | --- | --- | --- | --- |
| Ordinary OC, 40 m / 20 min, air | 1.7 ms | n/a | 22 ms | 23 ms |
| Long deco, 90 m / 30 min, trimix + 3 deco gases | 3.8 ms | n/a | 95 ms | 99 ms |
| CCR 80 m / 40 min + 2 bailout tanks | 6.6 ms | 39 ms | 148 ms | 194 ms |

An expanded Contingencies section adds a further 6 to 29 ms per edit. A
background isolate added no measurable cost over running the table in place.
These are relative costs: release builds are faster and phones are slower, and
no release timing has been taken yet.

The diver feels this as a chart that lags behind the finger on exactly the plans
that most need a planner.

## Decided by the maintainer

- The range table, the bailout picture and the expanded contingency tables all
  move off the UI isolate. Moving the range table alone was rejected because it
  leaves a CCR plan spending about 45 ms per edit on the UI isolate.
- The results keep their current shape: no fewer cells, no reduced accuracy, no
  collapsed-by-default range table.

## Goals

- A continuous drag or a run of keystrokes performs no secondary engine work on
  the UI isolate, and no secondary work at all until the edit settles.
- The chart, headline stats, status chips and issue list stay in lockstep with
  the edit, on every frame.
- A figure on screen that does not describe the current plan is always marked
  as such.

## Non-goals

- Changing `PlanEngine`, `BailoutSolver`, `ContingencyService` or
  `RangeTableService`, apart from the shared bailout gate below.
- Moving the main schedule off the UI isolate.
- Scroll-visibility tracking. The settle already removes the work during a drag,
  and the phone layout builds the whole sheet because it is shrink-wrapped.
- Changing how `missionOutcomeProvider` works.

## Anti-goals

Any of these would make the change a failure even if it is faster:

- An unmarked stale bailout verdict. "Sufficient" for a plan that has since
  changed is a safety problem.
- A slate PDF or logged dive built from figures for an older revision.
- Another plan's figures shown as if they belonged to the plan now open.
- Dropping the repetitive-dive tissue seed from any variant.

## What stays synchronous

`planOutcomeProvider`, `planIsValidProvider`, `activePlanOutcomeProvider`,
`selectedContingencyProvider` and `planBestMixProvider` do not change. The main
schedule fits inside a frame on all three plans, the chart joins it to the
live segments, and save, convert and export read it directly. A previewed
contingency is one engine run, the same order of cost as the main schedule, and
it drives the headline stats, so it stays in step too.

## The background pattern

Four providers become `FutureProvider`s following `missionOutcomeProvider`:
`planRangeTableProvider`, `planBailoutProvider`, `planDeviationsProvider` and
`planLostGasProvider`.

Each one:

1. Watches only the inputs the engine reads, through a `select` that strips the
   plan's name, notes and timestamps (the mission provider's `_missionInputs`
   rule) and includes the raw tissue-seed fields of `DivePlanState`.
   `BuhlmannState` has no value equality, so the seed itself must not be the
   selected value: select the state fields and derive the seed afterwards with
   `startStateForPlan`.
2. Watches `planEngineConfigProvider`.
3. Waits for a settle delay, 150 ms, on a timer a newer edit cancels, so a
   superseded computation goes no further.
4. Runs the existing pure service through an injectable runner whose default is
   `Isolate.run`. The closure captures plain values only, never `ref`.
5. Sets `retry: (_, _) => null`, as the mission provider does.

The contingency providers keep their gate: while
`contingenciesExpandedProvider` is false they return an empty list at once,
with no settle and no isolate.

Riverpod drops the result of a computation that a newer edit superseded, which
is the existing protection against stale delivery.

### Revision tag

Each result is wrapped with the id of the plan it was computed for. `AsyncValue`
keeps its previous value through a reload, which is what we want across edits to
one plan and what the anti-goals forbid across plans. A consumer treats a
previous value whose plan id differs from the open plan as no value at all, so
opening another plan shows "calculating", not the last plan's table.

## What the diver sees

Each of the three sections (bailout, contingencies, range table) has the same
four states:

| State | Shows |
| --- | --- |
| First result pending | Section header and a one-line "calculating" message |
| Newer result pending | Last figures dimmed, with a text line above them saying they are updating |
| Failed, no value | Section header and a one-line "could not be calculated" message |
| Failed, older value | Last figures dimmed, with the failure line above them |

The status is always text, so it reaches a screen reader and does not rely on
dimming alone. The state goes pending on the same frame as the edit, because the
provider rebuilds as soon as the plan changes, not when the settle ends.

Section visibility no longer depends on the result. A section's header is shown
from a synchronous check, so the sheet does not jump as results land:

- Range table: the plan has segments.
- Bailout: the shared gate below.
- Contingencies: as today.

Three strings are added to all 11 ARB files: "calculating", "updating" and
"could not be calculated". The mission section's strings name the mission and
cannot be reused.

## The chart

### Mode toggle

`ChartModeToggle` is currently gated on the bailout result. Gated on an async
value it would flicker during edits, so it gets a synchronous gate. The solver's
first three early returns (an open-circuit plan, no bailout-role tank after
`TankRoleResolver`, no segments) move into one shared function that both the
solver and the toggle call, so they cannot drift.

The gate means "this plan may have a bailout picture", not "it has one". The
solver has a fourth null return after its tissue walk (`points.isEmpty`), reached
by a degenerate loop plan that never leaves the surface, and predicting that needs
the walk itself. So the rule is one way: when the gate is false the solver returns
null. When the gate is true and the finished result is null, the section header
and the chip hide, as they do today for a null result. Only that degenerate plan
can see this. It has no figures to keep through an edit, so each edit shows the
calculating state again until its result lands.

### Bailout view during an edit

The status belongs on the chart, not on the toggle: the fullscreen chart has no
toggle, the phone toggle can be scrolled out of its strip, and a toggle that hides
cannot mark anything. A small text label is drawn on the chart whenever Bailout
view is selected and the gate is true, and the picture is not current:

| Bailout state | Chart draws | Label |
| --- | --- | --- |
| Current result | Bailout picture | None |
| Newer result pending, older value | Last bailout picture | Updating |
| First result pending | Live plan | Calculating |
| Failed, with or without an older value | Live plan | Could not be calculated |
| Finished, null result | Live plan | None |
| Gate false (say, the last bailout tank was removed) | Live plan | None |

A failed result does not keep the old line, unlike the sheet's dimmed figures. A
pending state clears in moments, but nothing replaces a failed result until the
next edit, and a full bailout curve reads as current in a way dimmed text does
not. `planChartBailoutProvider` reads the gate first, so removing the last
bailout tank drops the old line on that same frame.

The waypoint handles follow the finger throughout, as they do now.

## Export and convert

### Slate export

`planSlateExport` is already asynchronous. It awaits the `.future` of each of the
four providers, so a slate always carries results for the current plan. It listens
to all four for as long as it waits, because an edit to a provider nothing is
listening to drops the running build and starts no new one, which would leave the
await pending forever. It goes round again if the plan, the settings or the
Contingencies section changed during the wait, so one slate never mixes revisions.
The collapsed-contingencies behaviour is unchanged: the slate carries contingency
tables only when the section is expanded. If a result fails, the export fails
through its existing error path and never produces a slate with a section
silently missing. If another plan takes this one's place during the wait, which
is what leaving a replan does, no file is delivered: the providers only answer
for the open plan, so the slate that was asked for is out of reach.

### Convert to dive (bug fix in scope)

Convert reads `planCanvasSeriesProvider`, which returns the bailout picture when
the chart is in Bailout view. A loop plan converted from that view today logs the
bailout profile as the dive, alongside the live plan's runtime and depth. Making
bailout asynchronous would add staleness to that mistake. A new provider holds the
live series regardless of chart mode, `planCanvasSeriesProvider` chooses between
it and the bailout picture, and convert reads the live one.

## Accuracy

The services are called with the same inputs as today, so results must be equal,
not close. Tests prove it by comparing the background path against a direct call
for all three plan shapes, with a seeded repetitive-dive start state included.

## Validation

Automated:

- Every result type crosses a real `Isolate.run`. A closure or unsendable field
  fails at runtime, so at least one test per provider must use a real isolate.
- Equality against a direct call, as above.
- A simulated drag of many edits runs no service until the settle ends, then
  exactly one run per provider.
- A superseded slow run never reaches the screen.
- A rename runs nothing.
- Opening another plan never shows the previous plan's figures.
- The four display states, for each section.
- The toggle does not flicker through an edit, and the solver returns null for
  every plan the gate rejects.
- Each row of the chart's Bailout state table, in both the inline chart and the
  fullscreen chart.
- Converting from Bailout view logs the live profile.
- Exporting straight after an edit carries the new figures.

Measured and reported in the PR: engine invocation counts per edit before and
after, for the three plan shapes, with results visible and scrolled away, and
frame durations of a real drag in a profile build on macOS. If a profile run is
not possible, the PR says so plainly. No release target is set in advance.

## Left to the builder

- The runner's shape and where the shared pieces live (the file must stay inside
  the repo's size guidance, and `plan_canvas_providers.dart` is already 660
  lines).
- The revision wrapper's name and shape.
- Whether the settle delay shares a provider with the mission or has its own.
- The dim level and the wording of the three strings.
- Where the chart's label sits. It must stay readable on a phone, where chips
  overlay the top of the chart, and must not sit under the scrub readout.
- How the 17 test files that mention these providers or mount the sheet get
  their overrides. A real isolate never completes under `FakeAsync`, and an
  unzeroed settle leaves a pending timer, so a shared test helper is the likely
  shape.
