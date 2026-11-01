# Gas Switch Editing

Target release: v1.8.4. Issues #32 and #3058.

## Why

A dive downloaded from a computer carries the gas switches the computer
logged. When the diver forgot to tell the computer about a switch (#3058, a
Mares Quad Ci deco dive breathed on nitrox the computer never heard of), or
the computer logged a switch to the wrong cylinder (#32, a 6 m switch recorded
onto back gas instead of oxygen), the logbook has no way to put it right. The
dive's deco schedule, tissue loading, CNS and OTU, per-cylinder SAC and
consumption segments all read the switches, and so do the residual loadings of
the dives that follow, so one missing switch skews everything downstream.

The maintainer's decision on #3058: the log records what happened on the dive,
the computer is an input to that record, and nothing the diver changes
destroys the raw computer data, which stays on the dive.

## Goals

- Let the diver add, change and remove gas switches on a logged dive, from the
  dive edit page, for imported and hand-entered dives alike.
- Everything derived from switches follows the edit, on this dive and on the
  dives after it, with no extra action.
- Switches the diver has set survive "Reparse raw data" and "Resync imported
  file", the same way an edited profile already does.
- Re-parse keeps every cylinder the diver added by hand, on every dive. Today
  it deletes one the parse does not account for, which would take a switch
  with it.

## Non-goals

- No assignment of transmitters to cylinders; the Cylinders card on the dive
  detail page has that since #1314.
- No editing of switches from the profile chart, the dive detail page or the
  bulk edit page. One entry point.
- No new recompute machinery. Deco, tissue, exposure, SAC and the following
  dives' residuals already re-run when switches change; the work there is to
  prove it, not build it.
- No changes to how the planner, Compare or imports handle switches.

## Anti-goals

- A re-parse or a file resync that silently throws away a switch the diver
  entered. That would undo the one thing this feature exists for.
- A switch pointing at a cylinder that is not on the dive, or at a time
  outside the dive. Analysis already ignores switches to unknown cylinders,
  so such a row would be a silent no-op the diver cannot see.
- A second copy of the computer's switch appearing beside the diver's
  correction after a re-parse.

## Constraints

- Gas switch rows already exist (`gas_switches`: time from dive start in
  seconds, cylinder, optional depth, optional computer id). A null computer id
  already means "applies to every computer on the dive", which is what a
  diver-entered switch is. The row shape does not change.
- Re-parse (`ReparseService`) and resync (`DiveReimportService`) each delete
  every switch on a single-computer dive and rewrite them from the file.
  Re-parse already keeps a diver-edited profile (`hasLiveEdit`), and keeps
  the diver's own fields on a cylinder it matched; but a cylinder the diver
  added by hand that the parse did not match is deleted by the position rule
  in `_carryOverTanks`, and a test pins that ("handles new/removed tanks").
- A dive's stored safety review is served while its inputs hash matches, and
  that hash does not include the dive's own switches. Re-parse and profile
  edits clear the review (`clearReviewForDive`); a switch save must too. The
  Explore derived metrics do go stale on the dive's updated time.
- On a dive logged by more than one computer, each computer's switches carry
  its id and name that computer's own cylinder rows; analysis reads one
  computer's switches at a time (`GasSwitch.appliesTo`). Re-parse and resync
  already leave switches alone on such dives.
- The edit page's duration fields hold whole minutes; a minutes-and-seconds
  input is new work.
- The dive edit page holds the loaded dive, including its profile samples, and
  saves cylinders through the dive entity; switches save beside them.
- Switches sync as parent-gated children with their own clock; every write
  goes through the dive repository so it is staged for sync and captured by
  the change log.
- Paths platform-agnostic, units through the active diver's settings, tests
  first, no file over 800 lines (the edit page is already far over; nothing
  new lands in it that can live in its own file).

## The design

### Where

A **Gas switches** list on the dive edit page, inside the gas and gear group,
directly under the cylinder rows and above the add-cylinder row. It is shown
when the dive has two or more cylinders and is not a gauge dive; with one
cylinder there is nothing to switch to. It is hidden on a planned dive, whose
switches belong to the plan.

### What the diver sees

- A first line, not a row, naming the cylinder the dive starts on, worked out
  the way analysis already does it (a switch in the dive's first moments names
  it, else the SAC reference cylinder: the back gas, else the first). It
  updates as rows change. To start on another cylinder, the diver adds a
  switch at 0:00.
- One row per switch, in time order, each with:
  - **Time** from the start of the dive, minutes and seconds.
  - **Cylinder** switched to: a picker over the dive's cylinders as they are
    in the editor at that moment, labelled the way cylinder rows label them
    (role and gas).
  - **Depth**, in the diver's depth unit. Filled in from the profile at that
    time when the dive has a profile, and refilled when the time changes
    unless the diver has typed a depth. Editable, and may be empty.
  - A remove control.
- An **Add switch** control. A new row starts with its time after the last
  switch and its cylinder as the first cylinder not currently being breathed.
- Rows that came from the computer and rows the diver entered look the same.
  The dive's change history shows what the computer said.

### Dives logged by two computers

The editor shows the switches that apply to the dive's primary computer: its
own, plus any that carry no computer. The other computers' switches are left
untouched and are not shown. A computer-logged switch the diver changes keeps
its computer tag as well as its row id; a switch the diver adds carries none.
The same-second rule below applies to the visible list only.

### Rules

- A switch must name a cylinder on the dive. Removing a cylinder in the editor
  removes its switches; the list says so where the rows were, until the next
  edit.
- Time is within the dive's runtime: 0 up to and including the runtime. With a
  profile that is the profile's last sample; without one it is the runtime
  field's current value, else the bottom time, else exit minus entry, else
  there is no upper bound. Out of range marks the row and blocks Save, like
  other field errors on the page.
- Two switches at the same second are refused the same way.
- A switch the diver adds carries no computer id. A switch the diver changes
  keeps its row id, so sync sees an edit, not a delete and an add.
- Changes save with the dive. Cancel discards them.

### Ownership of the switch list

Once the diver has saved any change to a dive's switches (an add, a change or
a removal), the dive's switch list is the diver's. From then on:

- **Reparse raw data** rewrites the dive's events, cylinders and pressure
  series as it does today, but leaves every gas switch row alone.
- **Resync imported file** does the same.
- A cylinder that any switch names counts as diver-edited for re-parse's
  unused-gas cleanup, so the cleanup cannot drop a cylinder out from under a
  switch (the row would cascade away with it).

A dive the diver has never touched behaves exactly as today, except for the
cylinder rule below. There is no control to hand the list back to the
computer; the change history already lets the diver revert a save.

### Re-parse keeps hand-added cylinders

On every dive, edited or not, **Reparse raw data** keeps a cylinder the diver
added by hand. Today a stored cylinder the parse did not match, sitting at a
position the parse does not report, is deleted; a deco cylinder added by hand
to a dive whose computer logged one gas (the #3058 case) is exactly such a
row, and the switch to it cascades away with it. The maintainer chose the
wide rule over keeping only the cylinders a switch names: nothing the diver
entered is destroyed by a re-parse. A cylinder the parse matches, by its
source index or by position, keeps today's behaviour: the computer's values
are overlaid and the diver's own fields are kept.

### What follows from a save

The save clears the dive's stored safety review, as re-parse and a profile
edit do, so the review is rebuilt from the new switches. Everything else is
already in place: the gas switch provider refreshes on the analysis-input
tick, and the Explore derived metrics go stale on the dive's updated time,
which every switch write already bumps. The build proves, with tests, that
after a saved switch change the following all reflect it: the safety review,
deco status and tissue loading, CNS and OTU, per-cylinder SAC and consumption
segments, and the surface interval and residual loading of the next dive.

## Builder's calls

These are mine, made so the builder can plan; they do not change what the
diver sees.

- **The marker** is a new column on `dives`, `gas_switches_edited`, integer
  0/1 defaulting to 0, in `lib/core/database/tables/dive_tables.dart`, with a
  rung in `rungs_v231_onward.dart` taking the schema to v333. It syncs with
  the dive row (dives export through the generated `toJson`, so no serializer
  change). It is set by the repository write that saves the diver's switch
  changes, on the same `dives` update that bumps `updated_at`.
- **Repository:** add `updateGasSwitch` beside `createGasSwitch` and
  `deleteGasSwitch`, and one `saveDiverGasSwitches(diveId, switches)` that
  diffs the stored list against the edited one inside a transaction, applies
  creates, updates and deletes (a delete tombstones the row, which the FK
  cascade on a removed cylinder does not), stages each for sync, bumps the
  dive, sets the marker and clears the stored safety review. The edit page
  calls that once on Save, after the dive and its cylinders are written, so
  the cylinder ids it names exist. On a multi-computer dive the diff covers
  only the switches the editor showed.
- **Re-parse** gates the switch delete and re-insert (and the matching
  staging) on the marker being unset, beside the existing `rewritesTanks`
  guard. **Resync** returns early from `_replaceGasSwitches` when it is set.
- **Hand-added cylinders:** in `_carryOverTanks` the position-rule deletion
  skips a stored row with no source index (hand-added, or a pre-v200 row the
  parse never matched, which cannot be told apart and is kept on the safe
  side). Such a row that the position fallback matched is unaffected. The
  unused-gas cleanup's keep set gains every cylinder a switch on the dive
  names. The pinned expectation in the re-parse test flips to "kept".
- **The editor state** lives in its own file under
  `presentation/widgets/edit_sections/` (a `GasSwitchRow` and the list), with
  the page holding the list of switches and the ids of the ones it loaded, the
  way it holds cylinders. Depth lookup interpolates the loaded dive's profile
  at the row's time.
- **Time entry** is a small `mm:ss` field in the same file as the row.
- **Strings** go through the l10n process the repo uses for new strings.

## Left to the builder

- Exact row layout at phone and desktop widths, within the page's existing
  cylinder-row style.
- How the removed-cylinder notice is worded and when it clears.
- Test placement, following the repo's layers (repository, re-parse, resync,
  tank usage, widget test of the section, architecture guards).
- Whether the save diff treats a row whose only change is a refilled depth as
  an edit (it should, it is a stored value).

## Screenshots

The dive edit page, gas and gear group, before and after, on a dive with two
cylinders: phone width and desktop width, since a new section changes the
layout. Light only unless a new colour is introduced.
