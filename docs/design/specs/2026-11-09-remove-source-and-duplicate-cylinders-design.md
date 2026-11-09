# Remove a data source, and remove duplicate cylinders in bulk

Release: v1.8.5. Issue: to be opened from this design.

## Why

A diver on ScubaBoard switched sync folders and then faced 272 data quality
findings, mostly "Conflicting sources" and "Wrong cylinder". Two things made
cleanup painful:

1. A dive can carry a data source the diver does not want (one with no data,
   or a second computer that disagrees), and there is no way to remove it. The
   per-source menu offers only "Set as primary" and "Split into separate
   dive". `DiveRepositoryImpl.deleteComputerReading` exists but nothing calls
   it, and it is not safe to call as it is: it logs no sync deletion (peers
   bring the source back) and it leaves the source's profile series behind
   with their attribution cleared.
2. When a dive has the same cylinder twice (the usual cause: two computers
   paired to one transmitter, consolidated into one dive), the "Wrong
   cylinder" twin finding offers only "Swap tank series" and "Move series to
   another tank". Neither removes the duplicate, so the diver must edit each
   dive by hand. Nothing works across many dives at once.

Success: a diver with a hundred duplicate cylinders clears them in one action
with one undo, and can remove any unwanted source from a dive.

## Goals

- **Remove source**, for one source on one dive, from the dive's Data Sources
  section and from a "Conflicting sources" finding.
- **Remove duplicate cylinder**, for one twin-cylinder finding, from its card.
- **Remove duplicate cylinders in bulk**, from the inbox's Tanks chip, for
  serial-proven twins only, with one undo for the whole batch.
- **Dismiss all shown**, for whichever findings the inbox is showing.

## Non-goals

- Bulk fixes for "Conflicting sources". Which computer was right is the
  diver's judgment, so those stay one at a time.
- Bulk removal of twins matched only by pressure curves (no serials). A real
  manifolded twinset with a transmitter on each valve, imported from a file
  without serials, matches the same way. These keep the per-card action.
- The other "Wrong cylinder" shapes (drained while idle, loop tank drained like
  a bailout). They need judgment and keep their existing actions.
- Preventing duplicates at import or consolidation time.
- The stale "older version" sync banner, which is a separate bug.

## Anti-goals

- Losing logbook data. Removing a source or a cylinder must never touch the
  dive's logbook entry (site, notes, buddies, tags, equipment, media).
- A removal that comes back. Every deleted row must be logged for sync, or
  another device brings it back on its next sync.
- An undo that only half works. Each action, and the whole bulk batch, must be
  revertible: from the snackbar right away, and later from Settings > Data >
  Change log.

## Decided

### Remove source

- **Where:** a new "Remove source" item in the per-source menu of the dive's
  Data Sources section (`data_sources_section.dart`), and a new repair on the
  "Conflicting sources" finding card that removes the source the finding names
  as disagreeing with the primary.
- **What goes:** the source row and everything that belongs to it: its
  profile rows, events, tank pressures, and the tanks it recorded along with
  those tanks' gas switches. This is the same set `DiveSplitService` moves to
  a new dive, deleted instead of moved.
- **Primary source:** another source is promoted first, and the dive starts
  over on it, as Split does when the primary leaves.
- **Only source:** the menu item is not offered, and the repair is never
  offered.
- **Confirmation:** a dialog names the source (its computer name) and says that
  its readings will be removed from this dive and that the logbook entry stays.
- **Undo:** a snackbar Undo right after, and the operation is in the change
  log.
- **Sync:** every deleted row is logged as a deletion, and every row the
  promotion rewrites is marked pending.

### Remove duplicate cylinder (one dive)

- **Where:** a new repair on the twin-cylinder finding card (both the
  serial-proven and the curve-matched kinds), next to Swap and Move.
- **Which cylinder stays:** the one recorded by the dive's primary source. If
  neither or both are, the one with more diver-entered detail (volume, working
  pressure, name, gear link) stays. A remaining tie goes to the lower id, so
  the result is predictable. Gas mix is not counted as detail: `o2Percent`
  defaults to 21, so an unset mix cannot be told from air.
- **Gas mix:** when the two cylinders' mixes differ (O2 or He), the
  confirmation shows both and the diver picks the one the kept cylinder
  carries, defaulting to the survivor's own. When they match, nothing is
  asked.
- **What carries over:** volume, working pressure, name, `equipmentId` and
  `regulatorEquipmentId` are copied from the removed cylinder where the
  survivor's are empty. The tank role stays the survivor's. The removed
  cylinder's computer joins the survivor's `sharedComputerIds`, so a later
  Split of that source still finds a cylinder to take. Gas switches and
  profile events that point at the removed cylinder are re-pointed at the
  survivor.
- **Pressure data:** if the survivor has no pressure series and the removed
  one does, the series moves to the survivor, along with the removed
  cylinder's start and end pressures. Otherwise the removed cylinder's series
  is deleted (both read the same transmitter).
- **Three or more on one serial:** one dive can raise a finding for each pair
  (A-B, A-C, B-C). The action works on the whole group sharing the serial:
  the survivor rule picks one cylinder and every other one merges into it.
- **Prior art:** `TankRoleRepairRepository.useAsBailout` already merges one
  tank into another (re-points gas switches, deletes the tank, logs the
  deletion, returns an undo record). `DiveChildRowRepository.deleteTank` shows
  the full cleanup of a tank's series, switches and events.

### Remove duplicate cylinders (bulk)

- **Where:** a toolbar action on the data quality inbox, shown only while the
  Tanks chip is selected and at least one open serial-proven twin finding is in
  scope (scope includes the page's dive filter). Label: "Remove duplicate
  cylinders (N dives)".
- **Covers:** open twin findings with `sameTransmitter: true` only, grouped
  per dive and per serial as above.
- **Gas mix clash:** a dive whose cylinders on one serial disagree on gas mix
  is skipped. Its findings stay open for the per-card action, where the diver
  chooses.
- **Confirmation:** a sheet lists each dive (its identity label, as the inbox
  group headers show it) with which cylinders go and which stays, and says
  how many dives will be skipped because their gas mixes differ.
- **Run:** every dive under one `ChangeLogScope.bulk` operation, with
  progress shown for large batches. A dive that fails is skipped and counted.
  The summary reads "Removed on N dives", plus "K skipped: gas mixes differ"
  and "M failed" when either applies.
- **Undo:** the snackbar Undo reverts the whole operation through the change
  log revert service, and the same operation can be reverted later from the
  change log.

### Dismiss all shown

- **Where:** an inbox overflow menu item, "Dismiss all shown (N)", acting on
  the open findings the current chip and dive filter show.
- **Run:** after a confirmation, it uses `QualityFindingsRepository.dismissAll`
  (it already exists and has no caller). Dismissed findings stay dismissed
  across rescans, as single dismissals already do.
- **Undo:** a snackbar Undo puts those findings back to open.

### Change log: record in-place edits to series rows

Both removals change profile and pressure series rows in place: promoting a
new primary source re-zeroes the dive's timeline (`rezeroDiveTimeline`
shifts samples) and flips `isPrimary` on the remaining series
(`promoteOwnedBy`), and merging a cylinder can move a pressure series to the
survivor. Today `dive_profile_series` and `tank_pressure_series` are
`ChangeLogClass.deleteCopyOnly` (`change_log_policy.dart`): only deletes are
recorded, so a revert would bring back deleted rows but leave these edits in
place, which is a broken dive rather than the dive as it was.

The change log is extended so these edits are recorded and reverted too:

- An update to a row of either table records a copy of the row as it was,
  in the same way a delete does, and a revert writes that copy back.
- It is recorded only inside a change log operation that asks for it (this
  feature's removals ask for it). Routine machine writes (download, re-parse,
  analysis sweeps) do not, so the log does not fill with large series rows.
  The settler, which today drops machine-row events while their owner lives,
  keeps the events of an operation that asked.
- A revert of these rows follows the existing revert rule: it is a new edit,
  marked pending under a fresh clock, so peers accept it.
- Deletes of series whose source or tank is gone are already kept
  (`changeLogMachineOwners`), so removed rows already come back on revert.

## Constraints

- Every user-visible string goes through l10n (ARB) in every locale file the
  project keeps.
- Units in confirmation text follow the active diver's settings.
- `quality_repair_executor.dart` is at 798 lines and the inbox page is at 970,
  so new logic and widgets go in new files rather than growing either.
- Tests first (project rule): domain rules, database writes with their sync
  deletions and pending marks, undo round trips, and widget tests for where
  each action appears.

## Left to the builder

- Whether removal reuses `DiveSplitService`'s ownership selection through a
  shared helper, or replaces and repairs `deleteComputerReading`. Either is
  fine provided the sync and undo rules above hold.
- How the bulk run batches its transactions (one per dive within the single
  change log operation is the expected shape).
- Exact wording beyond the labels above, icons, and the progress UI.
- How an operation asks for series updates to be recorded (a flag on the
  change log context the triggers read, a scope parameter, or similar), and
  how the trigger SQL generator emits the update-copy trigger.
- `DiveSplitService` and "Set as primary" make the same in-place series edits
  and have the same partial revert today. This work does not opt them in;
  doing so is a one-line follow-up once the mechanism exists.
- Whether a later re-parse of a removed tank's source can recreate the tank.
  Check `reparse_service.dart`'s tank matching. If it can, note it in the PR
  rather than widening this work.
