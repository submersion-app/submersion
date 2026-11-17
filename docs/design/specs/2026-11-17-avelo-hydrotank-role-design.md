# Avelo mode support: the Hydrotank tank role

Date: 2026-11-17
Release: v1.8.5

## Intent

Shearwater computers (Tern TX, Teric, Peregrine TX, Perdix 2 with a Swift
transmitter) have a paid "Avelo mode" for the Avelo Dive System. Its cylinder,
the Hydrotank, takes water in and out for buoyancy. Pumping water in squeezes
the gas above it, so the transmitter's pressure rises as the diver gets
heavier. Shearwater's own manual says cylinder pressure cannot be used
directly as a measure of remaining gas in this mode; the computer shows gas
remaining as a percentage instead.

Submersion already imports Avelo dives with a correct depth profile: the
libdivecomputer fork includes upstream commit b09c8d9 ("Add basic support for
the avelo mode", November 2025), which reads the Avelo sample record (`0x03`)
and reports Avelo mode (`M_AVELO`, 12) as plain open circuit. Two things are
still wrong:

1. Nothing marks the dive or the cylinder as Avelo. The import cannot tell an
   Avelo dive from any other open-circuit dive.
2. The Hydrotank pressure is stored as an ordinary tank pressure, so SAC, gas
   used, gas time remaining, reserve checks and the totals built on them all
   treat a water-driven pressure as gas consumption. Water left in the tank at
   the end inflates the end pressure, so SAC reads low.

This is a gap the maintainer spotted, not a user report. No Avelo log is
publicly available (the one behind Subsurface issue #4623 was emailed
privately to the libdivecomputer maintainer), so this design covers only what
can be built and tested without one.

## Goals

- An Avelo-mode dive downloaded, re-parsed or imported from Shearwater Cloud
  marks its Hydrotank cylinder with a new tank role, **Hydrotank**.
- A Hydrotank keeps its pressure trace and start and end pressures, shown and
  labelled as Hydrotank pressure, so the diver can still see the pumping.
- Every calculation that reads cylinder pressure as gas consumed treats a
  Hydrotank's pressure as not measured.
- Every calculation that needs to know what gas the diver breathed keeps a
  Hydrotank in (deco, oxygen exposure, gas switches, gas density, planner gas
  lists).
- A diver can choose the Hydrotank role by hand, for manually logged Avelo
  dives and for dives imported from sources that do not report the mode.

## Non-goals

- Decoding the Avelo-specific sample bytes (the repurposed second-tank and
  rebreather fields: likely water volume, buoyancy or gas remaining). That
  needs a real log; it is a later piece of work if one turns up.
- Reproducing Shearwater's gas-remaining percentage.
- Hydrotank presets (8 L and 10 L) in the tank preset list. Possible later,
  not needed for correct numbers.
- A new dive mode. Avelo dives stay open circuit (`DiveMode.oc`).
- Changing any other vendor's import.

## Anti-goals

- A Hydrotank must never disappear from deco, CNS/OTU or gas-switch handling.
  Dropping it there would make the dive's deco and oxygen numbers wrong, which
  is worse than the problem being fixed.
- A role the diver set by hand must never be overwritten by a re-parse.
- No schema change and no migration rung for this. `dive_tanks.tank_role` is
  already free text.

## Approaches considered

- **A. A Hydrotank tank role (chosen).** Marks exactly the cylinder whose
  pressure misleads, follows the path the suit-inflation role (issue #4243)
  already proved, and the diver can correct it. Cost: a tank holds one role,
  so places that look for the main cylinder by `backGas` must accept a
  Hydrotank as the main cylinder too.
- **B. A new `DiveMode.avelo`.** Visible at dive level, but every branch on
  dive mode would need to learn that Avelo means open circuit, and it does not
  say which cylinder is the Hydrotank: an Avelo diver's pony or stage on a
  normal transmitter would lose good SAC data.
- **C. A yes/no "Avelo dive" column plus "the first transmitter's tank is the
  Hydrotank".** A schema change whose meaning depends on a guess nobody can
  correct by hand.

The maintainer chose A on 2026-11-17.

## Design

### 1. libdivecomputer fork patch: a Hydrotank usage

In Avelo mode the Shearwater parser reads only transmitter slot 0 (T1) from
the Avelo sample record (`count = 1` at both sample-loop sites); slots T3 and
T4 still arrive through the extended record `0xE1`. So in Avelo mode the
Hydrotank is the tank fed by T1.

Add a fork-only value to `dc_usage_t` in
`include/libdivecomputer/parser.h`, appended after `DC_USAGE_SIDEMOUNT`:

```c
/* Submersion patch (Avelo Hydrotank): ... */
DC_USAGE_HYDROTANK,
```

In `shearwater_predator_parser.c`, the tag is set on the cache pass, on
`tank[0]` (transmitter slot T1) once the dive mode is known to be `M_AVELO`,
before the tank list is compacted. `DC_FIELD_TANK` cannot do it: its index
points into the compacted list, where the original slot is gone. The same
cache pass can already tag slot 0 as `DC_USAGE_SIDEMOUNT` from the GTR mode
byte; in Avelo mode the Hydrotank tag wins (builder's call, settled here:
Avelo is a single backmounted Hydrotank system). Every other tank, and every
tank in every other mode, is unchanged. The value is appended, so existing
numeric values (0 none, 1 oxygen, 2 diluent, 3 sidemount) keep their
meaning.

Assumption: the Hydrotank is always on T1 in Avelo mode. No public source
says so outright; it rests on the Avelo sample record carrying only the T1
pressure. If a real log ever shows otherwise, the diver can still correct the
role by hand.

This lands the way every fork patch does: a topic branch and PR on the fork
based on `submersion-patches`, merged with a merge commit (never squash or
rebase, so the pinned SHA stays reachable), a `patches/0010-...patch` file in
`packages/libdivecomputer_plugin/patches/`, and a gitlink bump in this PR.
The fork PR merges before this one. A native test with a hand-built Avelo
log (mode byte 12 in opening record 4, a few `0x03` samples with a T1
pressure) checks the usage, alongside the existing
`test_tank_transmitter_serial.c` style tests in
`packages/libdivecomputer_plugin/test/native/`.

The native glue already copies `tk.usage` into the dive and every platform
binding already passes it to Dart as `TankInfo.usage`; check each binding
passes the new value through unfiltered.

### 2. Import: usage 4 becomes the Hydrotank role

`_inferRole` in `lib/features/dive_computer/data/services/parsed_tank_resolver.dart`
gains `case 4: // DC_USAGE_HYDROTANK` returning `TankRole.hydrotank.name`.
Download and re-parse go through this.

**Re-parse of existing dives (maintainer's decision, 2026-11-17):** an Avelo
dive's T1 cylinder stored as back gas becomes a Hydrotank on "Re-parse all
dives". Today's re-parse keeps every stored role except one read off a
transmitter name (`reparse_service.dart`, `roleIsComputers`), and nothing
stored tells the importer's back-gas default from a diver's choice, so this
needs a new rule: a parsed Hydrotank replaces a stored `backGas`. Any other
stored role (a diver who set pony, stage and so on) is kept.

Known limit (maintainer's decision, 2026-11-17): a diver who sets a Hydrotank
back to back gas by hand has it turned into a Hydrotank again by the next
re-parse. Once edited, that row is indistinguishable from an old import (back
gas, no role source), and the change log is per device and pruned, so it
cannot tell them apart. On an Avelo-mode dive the T1 cylinder is the
Hydrotank by definition, so there is almost no reason to undo it; any role
other than back gas still sticks.

**Transmitter registry (settled here):** the registry
(`applyTransmitterRegistry`, `transmitterFillFor`) sets a role per
transmitter, while the Hydrotank tag is a fact about this one dive. The
computer's Hydrotank tag wins over the registry's role on that dive, and a
registry fill never replaces a Hydrotank. A diver who uses the same Swift
transmitter on a normal cylinder in open-circuit mode still gets the
registry's role on those dives.

**Shearwater Cloud import (maintainer's decision, in scope):** Cloud import
builds its cylinders from Shearwater's own data
(`shearwater_dive_mapper.dart`, `mapTanks`) and only borrows transmitter
serials from libdivecomputer's parse of the raw log (`mergeWithParsedDive`).
The Hydrotank tag rides on that same pairing: a Cloud cylinder paired with a
parsed tank whose usage is 4 takes the Hydrotank role. Where the existing
pairing leaves a cylinder unpaired because it is unsure, the cylinder keeps
its Cloud role.

### 3. The role and its rule

`TankRole` in `lib/core/constants/app_enums.dart` gains `hydrotank`, display
name "Hydrotank", localised in every ARB file.

A new getter on `TankRole`, named by the builder (for example
`pressureTracksGasUse`), is false for `hydrotank` and `suitInflation` and true
for every other role. It sits beside `isBreathingGas`:

| Role | `isBreathingGas` | pressure tracks gas use |
| --- | --- | --- |
| suitInflation | false | false |
| hydrotank | **true** | **false** |
| every other role | true | true |

**How consumption treats a Hydrotank (settled here):** for anything that
reads pressure as gas used, a Hydrotank's pressures count as **not
measured**, exactly like a cylinder with no gauge readings today. It is not
dropped from the dive. So:

- It stays the dive's main (SAC reference) cylinder wherever a back-gas
  cylinder would be. With an unmeasured reference, the whole-dive SAC is
  blank. Dropping it instead would let a pony become the reference, and the
  pony's small drop over the whole dive time would show a SAC far too low.
- A pony or stage on a normal transmitter keeps its own per-cylinder SAC and
  gas used.
- Gas-used totals (dive, trip, statistics) count only the measured cylinders,
  as they do today when a cylinder has no pressures. An Avelo dive whose only
  cylinder is the Hydrotank drops out of SAC statistics.
- The SQL SAC path (`multi_cylinder_sac_sql.dart`) mirrors this.

Every place that checks for a suit inflation bottle today is sorted into one
of two kinds, and the builder lists the sort in the plan. That is 41
`isBreathingGas` call sites across 30 files, plus the checks that bypass it:
the SQL literal in `multi_cylinder_sac_sql.dart`, `role_consumption.dart` and
`tank_mod.dart`.

- **Reads pressure as gas consumed** (SAC whole-dive and per cylinder, the SQL
  SAC paths, gas used, trip and statistics consumption totals, gas time
  remaining, estimated pressure synthesis, reserve and end-pressure checks in
  safety review and data quality, pressure-rate detectors): switch to the new
  rule, so a Hydrotank is left out.
- **Needs to know what was breathed** (deco, CNS/OTU, gas switches, gas
  density, MOD checks, planner and dive lab gas lists, tank configuration
  classification): keep `isBreathingGas`, so a Hydrotank stays in.

Places that pick "the main cylinder" by `backGas` treat a Hydrotank as one.

Older peers on sync read an unknown role as back gas (`TankRole.fromName`), so
on an older build an Avelo dive looks exactly as it does today. No sync
change is needed. Known limit, shared with the suit-inflation role (#4243):
editing such a dive on an older build writes back gas, and sync carries that
to newer devices. Accepted.

**The computer's own gas time remaining (settled here):** the parser still
reports the computer's logged GTR (`DC_SAMPLE_RBT`, byte 21) for Avelo
samples, and the app shows it as the computer logged it. This design leaves
it alone: it is the computer's own record, and without a real log there is
no evidence that byte means something else in Avelo mode. Revisit when a log
turns up.

### 4. What the diver sees

- The tank editor's role picker lists Hydrotank, like any other role.
- On the dive page the cylinder shows its role as Hydrotank, with its start
  and end pressure, and no SAC or gas-used figure for that cylinder. The
  whole-dive SAC is blank rather than a wrong number. A short line says why
  ("Hydrotank pressure does not measure gas used"); the builder picks where
  it reads best.
- The profile keeps the Hydrotank pressure line, labelled with the tank's
  Hydrotank role wherever pressure lines are named.
- Units follow the active diver's pressure unit, as every pressure does.

Rough sketch of the cylinders card:

```
Cylinders
  Hydrotank · 10 L · Air        200 → 185 bar
    Hydrotank pressure does not measure gas used
  Pony      · 3 L  · Air        200 → 170 bar   SAC 14 L/min
```

## Constraints

- No em-dashes anywhere, and no AI tool attribution, per the repo's rules.
- New ARB keys go in every locale file; the l10n staleness check runs before
  push.
- `test/architecture/` and `test/shared/` guards run after adding any file
  under `lib/`.
- Only the test files being worked on run locally; the pre-push hook and CI
  cover the rest.

## Left to the builder

- The getter's name and the exact sort of every `isBreathingGas` call site,
  listed in the plan.
- The wording and placement of the "does not measure gas used" line, and
  whether the stats pages need their own note when a dive is left out.
- The fork patch's exact code and the native fixture's bytes.
- Which existing tests to extend versus new test files.
