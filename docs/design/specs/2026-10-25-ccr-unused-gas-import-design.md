# Leave out unused open-circuit gases on rebreather downloads

Issue: #3668. Release: v1.8.3.

## Intent

A dive computer reports every gas programmed into it, not the gases the diver
carried. On a CCR dive the importer keeps one cylinder per transmitter and then
adds a pressureless cylinder for every gas no transmitter claimed, ranked as
Bailout, Deco or Stage (#1747, #2318). A rebreather diver who leaves extra
open-circuit gases enabled on the computer, which is common because they feed
the computer's bailout deco calculation, gets cylinders they never had on every
download and deletes them by hand.

The reporter (r/submersion) downloads a CCR dive with two transmitters (O2 and
diluent) and gets four cylinders: the two transmitter cylinders with pressures,
plus "Tank 3 (O2) Deco" and "Tank 4 (Air) Bailout" with no pressures and never
breathed.

Keeping every gas stays the default, because a diver who carries a bailout
bottle without a transmitter would otherwise lose it from the log. The diver who
does not carry them turns on a setting.

## Goals

- A switch in Settings > Import, directly below "trim tank pressure at
  surfacing", off by default.
- When it is on, a dive computer download of a CCR or SCR dive creates no
  cylinder for an **unused open-circuit gas** (defined below).
- When it is on, re-parsing an existing dive removes the cylinders for unused
  open-circuit gases, except a cylinder the diver edited.

## Non-goals

- Open-circuit, gauge and freedive dives. Nothing changes for them.
- File imports (UDDF, Subsurface, Shearwater Cloud, MacDive and the rest) and
  cloud imports (Garmin, Suunto). Only libdivecomputer downloads and re-parses
  of their raw data are in scope.
- Changing the bailout and deco ranking, or the bailout transmitter claim
  (#3307). Both run exactly as today.
- Keeping the left-out gases anywhere (the user's decision). A diver who wants
  one back adds the cylinder in the dive editor, or turns the switch off and
  re-parses.

## Anti-goals

- **A bailout transmitter logged with the wrong gas.** A Shearwater never links
  a transmitter to a gas mix. When the registry says a transmitter is the
  bailout, `claimBailoutGases` gives it the mix of the dive's only pressureless
  bailout cylinder, whether or not that gas was breathed. If the unused gas were
  dropped before the claim, the bailout transmitter would keep its default mix
  (air or 100% O2) in a logbook divers plan from. The claim must always see
  every gas.
- **Deleting a cylinder the diver edited.** Re-parse already protects edited
  cylinders from the bailout claim; the same protection applies here.
- **Dropping a gas the diver breathed.** A gas the diver bailed out onto is
  never "unused", whatever else is true of it.

## Definitions

An **unused open-circuit gas** is a cylinder the resolver created for a gas
from the computer's gas list, on a dive whose mode is CCR or SCR, where all of
these hold:

1. No transmitter claimed it in the resolver (it is one of the "unclaimed"
   pressureless cylinders `_resolveCylinders` adds after the transmitter
   cylinders, or a cylinder of a tankless dive's gas list).
2. The computer did not tag the gas as oxygen, diluent or sidemount
   (`GasMix.usage` 1, 2 or 3). A diluent or oxygen gas with no transmitter is
   loop gas and is kept.
3. It was never breathed: its gas-mix index appears nowhere in
   `breathedGasSequence(parsed)`, including the first (starting) entry.
4. After the bailout transmitter claim has run, it is still a cylinder of its
   own (no transmitter claimed it).

## Decided by the user

1. **The setting:** a switch in Settings > Import beside "trim tank pressure at
   surfacing", off by default.
2. **Left-out gases are not created.** Nothing records that they existed.
3. **Re-parse honours the switch.** With it on, re-parsing an existing dive
   removes the unused-gas cylinders, but never a cylinder the diver edited.
4. **Re-parse cleans up dives downloaded before v1.8.1 too.** Before #2319
   an unused gas on a transmitter dive was stored with `_inferRole`'s role
   (back gas below 41% O2, deco at or above), and a back-gas one also got the
   default tank preset's size, working pressure, material and preset name.
   Those were the importer's guesses, not the diver's edits (see Re-parse
   rules).

## How

### Setting

A synced `diver_settings` boolean column, following
`trim_tank_pressure_at_surfacing` (v165) and `downloads_follow_computer_owner`
(v310):

- Column `omit_unused_oc_gases` (name is my call), `INTEGER NOT NULL DEFAULT 0
  CHECK (omit_unused_oc_gases IN (0, 1))`, in `diver_tables.dart`.
- Schema v315 rung in `rungs_v231_onward.dart`, column only, no backfill. A
  `beforeOpen` backstop in `before_open_settings_columns.dart` (never in
  `before_open.dart`, which is at its size limit).
- Settings state field, `copyWith`, setter, repository read and write,
  `SyncDataSerializer` field, and an entry in the settings conflict catalogue,
  the same set of touch points as v310.
- The switch in `import_preferences_group.dart`, with English strings and
  translations in every ARB file.

Wording (my call): title "Skip unused bailout gases", subtitle "On rebreather
downloads, leave out a gas with no transmitter that was never breathed".

### Marking in the resolver

`_resolveCylinders` already knows conditions 1 to 3. It marks each such cylinder
on `DownloadedTank` (a new boolean, for example `unusedOpenCircuitGas`) instead
of dropping it, and the flag travels to `TankData` through
`DiveParser.tankDataFrom`. The resolver does not read the setting: whether to
drop is the writer's decision, made after the claim.

The tank list the resolver returns is unchanged, so `resolveDiluentGas`, gas
switch derivation, the bailout ranking and every existing caller behave as
today.

### Dropping in the writers

One shared pure helper, for example
`dropUnusedOpenCircuitGases(List<TankData> tanks, {Set<int> keep})`, removes
the marked cylinders not in `keep`. Each libdivecomputer write path calls it
when the setting is on, **after** any bailout claim:

| Path | Where | `keep` |
| --- | --- | --- |
| New dive | `DiveImportService._importNewDive`, after `claimBailoutGasesInDive` and before the default tank preset | empty |
| Re-download into an existing dive | `_updateExistingDive`, on the tanks passed with `addMissingTanks: true` | empty (stored cylinders are never removed on this path; it only stops re-adding one the diver deleted) |
| Re-parse | `ReparseService._carryOverTanks`, after `claimBailoutGasesInDive`, before the insert/update loop | the indices of stored cylinders `_isDiverEdited` says the diver edited |

`attachToPlannedDive` needs nothing: it keeps the planned dive's own cylinders
and inserts none of the parsed ones.

On re-parse, a dropped cylinder's stored row is left unmatched and goes through
the existing deletion at the end of `_carryOverTanks` (row deleted and
`logDeletion` called, so peers drop it too). A stored row in `keep` stays in
the list and is updated as today. The deletion loop also keeps an unmatched
row whose `tankOrder` another parsed cylinder's index happens to equal (the
pre-v200 rule), so the dropped rows are deleted explicitly rather than left to
that rule.

### Re-parse rules (my calls, from the builder check)

- **What counts as edited.** `_isDiverEdited` was written for the bailout
  claim and misses fields a diver fills in by hand. Deleting is worse than
  claiming, so this feature's `keep` uses a wider test: `_isDiverEdited`, or
  any of start pressure, end pressure, working pressure, material, regulator,
  extra regulators, trip cylinder or passport set on the stored row. On an
  unused-gas cylinder no transmitter reads, any of those came from the diver.
  The claim's own rule is unchanged.
- **The old importer's guesses are not edits** (decision 4). On a stored row
  this test is deciding about, a role equal to `_inferRole(null, o2)` for the
  row's mix does not count as a changed role. When that role is back gas, a
  volume, working pressure, material and preset name that all equal the
  diver's current default tank preset do not count either (all four, or none
  of them is excused). Anything else set on the row still keeps it. A diver
  whose default preset changed since the download keeps those cylinders,
  which is the safe side.
- **Only a real match is dropped.** A stored row reaches a parsed index either
  by its `sourceTankIndex` or, when that is null (a cylinder added in the dive
  editor), by the pre-v200 `tankOrder` fallback. Only a row whose
  `sourceTankIndex` names the dropped index is that gas. A row that reached a
  dropped index through the order fallback is the diver's own cylinder: it is
  neither deleted nor overwritten with the dropped gas's mix, and the dropped
  indices count as taken orders so the pre-v200 deletion rule leaves it alone.
  This matters because re-adding a cylinder by hand is the recovery path, and
  the editor numbers a new cylinder with exactly the order a dropped gas held.
- **Never drop blind.** No gas is marked unused when the dive has no breathed
  gas sequence at all (a computer that reports no per-sample gas), and the
  drop is skipped when it would leave the dive with no cylinder. Either case
  would otherwise get around the #1853 guard against a re-parse deleting
  cylinders it has nothing to replace.

Which profile's setting applies: the profile the dive is filed under, read the
same way `DiveImportService` reads the default tank preset per diver (#2050 can
file a download under another profile). Re-parse reads the active profile's
setting, as it does for trim.

## Left to the builder

- The exact column, field, ARB key and helper names.
- Whether `_updateExistingDive` and `attachToPlannedDive` share the helper call
  through a small private method.
- Test fixtures: the reporter's case (two transmitters, Air diluent, O2 and Air
  OC gases, never bailed out) is the main one. Others: a bailout to the Air gas
  mid-dive (kept); a bailout transmitter registered as bailout with an unused
  Air gas (claimed, so the transmitter carries Air and no extra cylinder
  appears, switch on or off); an OC dive with the same gas list (unchanged); a
  re-parse where the diver edited the Air cylinder (kept) and one where they
  did not (deleted, deletion logged); the switch off (every path unchanged).

## Testing

TDD. Unit tests for the resolver's marking and the helper, service tests for
each write path and for re-parse, a migration test for v315, and the existing
settings sync and conflict-catalogue completeness tests.
