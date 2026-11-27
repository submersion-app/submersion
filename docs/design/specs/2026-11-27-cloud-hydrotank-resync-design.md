# Hydrotank role for Shearwater Cloud dives imported before #4662

Issue #4665. Follow-up to #4657 (PR #4662).

## Intent

PR #4662 added the Hydrotank tank role for Avelo-mode dives. Downloads,
re-parse and new Shearwater Cloud imports set it. An Avelo dive imported from
Shearwater Cloud before #4662 still stores its Hydrotank as back gas, so its
SAC, gas used and statistics read water-driven pressure and the pressure
anomaly detector flags its pump-ins. "Re-parse all dives" cannot reach these
dives: Cloud imports keep no raw log on the dive's data source.

The diver should be able to give such a dive its Hydrotank role without
editing the cylinder by hand.

## What exists

Shearwater Cloud is in `resyncableImportFormats` (#478, PR #1627), so every
Cloud import stored its original database in `imported_files`, and each dive
has "Resync from original file". Resync re-reads the database with today's
parser, which tags the Hydrotank, but `DiveReimportService._carryOverTanks`
writes pressures, gas, usage and serial onto the stored cylinders and never
the role.

## Approaches

- **Chosen: resync applies the re-parse Hydrotank rule.** Resync upgrades a
  stored back gas to the Hydrotank when the file tags it, the same rule
  re-parse uses. Reuses an existing per-dive action; no new UI.
- **Resync applies every role the file gives.** Rejected: Cloud metadata
  also guesses other roles, and this would overwrite the diver's choices.
- **Fill the raw log so re-parse reaches the dive.** Rejected: a second,
  indirect path to the same result that grows every old dive.
- **Bulk resync of every Cloud dive.** Declined by the maintainer: per-dive
  resync is enough for the few affected dives.

## Design

1. **Shared rule.** The re-parse test "stored role is back gas, no stored role
   source, and the fresh parse says Hydrotank" moves out of `ReparseService`
   into one pure function that re-parse and resync both call.
2. **Resync.** `_carryOverTanks` writes `tankRole = hydrotank` on a matched
   cylinder when the rule holds. Any other stored role stays. The row is
   already marked pending for sync; derived metrics recompute from the stored
   role on demand.
3. **New cylinders.** A cylinder the file has and the dive lacks is inserted
   with the file's role, not the back-gas default.

## Known limit

A diver who sets a Hydrotank back to back gas by hand sees it upgraded again
on the next resync: nothing tells that choice from an old import's default.
Re-parse has the same limit (decided in #4662).

## Non-goals

- Bulk resync, and any change to the import wizard's duplicate actions.
- Storing the raw log on Cloud imports.
- Roles other than the Hydrotank on matched cylinders.

## Testing

- Unit test for the shared rule.
- Reimport service tests: a stored back gas becomes the Hydrotank, another
  stored role stays, a file without a Hydrotank changes nothing, and a new
  cylinder takes the file's role.
- Existing re-parse Hydrotank tests keep passing on the shared function.
