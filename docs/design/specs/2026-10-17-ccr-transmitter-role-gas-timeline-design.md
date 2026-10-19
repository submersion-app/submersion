# Checking name-derived CCR transmitter roles against the dive's gas timeline

Issue: #3307 (the planned-gas half; the cylinder-configuration half shipped
in PR #3416). Follow-up to #2595 and #2749.

## Intent

On a Shearwater in CCR or SCR mode, libdivecomputer gives each wireless
transmitter a role from the first letter of the name the diver gave it: "O..."
becomes the oxygen supply, "D..." the diluent. A bailout named "OC" is imported
as the O2 supply. Since #2749 such tanks carry
`dive_tanks.role_source = transmitterName` and the dive shows the role as
unconfirmed. Two things can correct it today: the transmitter registry (#2749)
and an applied cylinder configuration (#3416). A diver who uses neither keeps a
wrong role with only a warning.

The issue asked for a second check against "the dive's gas plan / gas mixes".
This design keeps that goal (tell the diver when the gas information conflicts
with a name-derived role, and offer the right one) but changes the evidence.
The reason is below.

## Why gas mixes cannot be the evidence

What the code does today (`parsed_tank_resolver.dart`):

- **O-named tank:** Shearwater never lists the O2 supply in its gas list
  (DC_FIELD_GASMIX) and never links a transmitter to a mix
  (DC_GASMIX_UNKNOWN). The tank therefore always gets the importer's default,
  100% O2 (#726). Its mix says nothing.
- **D-named tank:** it takes the diluent the computer says was breathed
  (`_breathedDiluentIndex`). It agrees with its own role by construction. Only
  a dive with no gas list at all gets 21%.
- **A mix the diver entered:** the database has no marker telling an entered
  mix from a default (`o2Percent`/`hePercent` default to 21/0). PR #3416's
  `_gasDiffers` relies on "equals the default for the role", a heuristic that
  cannot confirm anything.
- **Linked plans** (`dive_plans.linked_dive_id`) carry a role and a mix per
  cylinder, but no transmitter serial. Matching a plan cylinder to a
  transmitter tank would come down to volume, which repeats the evidence
  #3416 already uses.
- **Planned dives** (`dives.is_planned`) already protect roles. A download
  merged into a planned dive keeps each matched planned tank's role and mix
  (`PlannedDiveFillService`).

## The evidence: what each cylinder did, and when

The dive stores two things that do tell the roles apart:

1. **Gas switches** (`gas_switches`, from DC_SAMPLE_GASMIX). Shearwater flags
   loop gases as diluents and open-circuit gases as unflagged. A switch to an
   open-circuit gas means the diver bailed out.
2. **A pressure series for each transmitter** (`tank_pressure_series`, one
   per transmitter tank).

The physiology is consistent:

| Role | Pressure drops while on the loop | Pressure drops while on open circuit |
| --- | --- | --- |
| O2 supply | Yes: metabolic use and manual adds | Little or none on eCCR. On mCCR the constant-mass-flow orifice keeps bleeding at the same rate |
| Diluent | Yes: descent, flushes, often wing inflation | Little: maybe wing inflation |
| Bailout | Little or none | Yes: it is being breathed |

The "OC"-named bailout leaves a recognisable trace. Its gas appears in the
computer's gas list without a transmitter, so the importer creates a separate
pressureless "sensorless" bailout cylinder that holds the real mix
(`_inferSensorlessRoles`). The switches to open circuit point at that
cylinder. The pressure drop, though, lands on the transmitter tank that was
named "O..." and imported as the O2 supply. This means a check must compare
the **timing** of the drop with the switch times, not the switch's target
tank (`TankAssignmentDetector` compares the target tank, which is the wrong
test here).

## Goals

- When a name-derived tank's pressure dropped mainly while the diver was on
  open circuit, tell the diver that it behaved like a bailout, and offer to
  make it the bailout.
- Use the open-circuit gas the diver actually breathed as the re-roled tank's
  mix, so a bailout never keeps 100% O2.
- A role the diver set (`role_source` null) is never flagged or changed.
- Let one repair fix the transmitter itself, so every past dive with it and
  every future import gets the right role and mix.

## Non-goals

- Gas-mix comparison of any kind (see above).
- Checking against linked plans. Deferred until plan cylinders can be tied to
  a transmitter.
- Confirming a role (clearing `role_source`) from the timeline. Steady loop-time
  use shows a tank was a loop gas, but cannot tell O2 from diluent. The
  registry and cylinder configurations still confirm roles. My call.
- Telling an O2 supply from a diluent apart by pressure pattern (descent
  correlation and so on). Possible later; too weak to act on now.
- Fixing `TankAssignmentDetector`'s "consumption while idle" finding, which can
  also fire on a CCR dive's O2 and diluent tanks. That is a separate bug: open
  a separate issue.

## Anti-goals

- Changing a role without the diver's say-so. Detection never writes; only the
  diver's repair does.
- A repair that puts one cylinder's history (pressures, switches) on another
  without saying so.
- A finding on a dive with too little data to support it. False alarms on CCR
  dives would teach divers to ignore the warning that matters.

## Constraints

- Only dives in CCR mode, and only tanks with
  `role_source = transmitterName` and a pressure series.
- Detectors are pure and synchronous over `DiveQualityContext`, which already
  carries `tanks` (with `roleSource`), `gasSwitches` and `pressuresByTankId`
  (`quality_context_builder.dart`).
- Finding params are numbers and ids, never prose (the `quality_findings`
  contract). Ids are deterministic (UUIDv5).
- `role_source` syncs as part of the whole `dive_tanks` row. The repair writes
  through the repository, so the existing sync paths carry it.
- The repair must survive a reparse. Reparse rewrites role and source only
  while the role is still the computer's own (`reparse_service.dart`), so a
  repaired tank keeps its new role. Any cylinder the repair removes must not be
  re-created by a reparse (see "Left to the builder").
- Reparse must not reset the repaired mix. Today it writes `o2Percent` and
  `hePercent` on every matched tank. Decided: **reparse never writes a mix the
  importer invented.** When the resolver gives a tank no gas of its own (the
  100% default for an O2 supply, or 21% when there is no gas list), reparse
  keeps the stored mix. A mix the computer actually recorded still refreshes as
  before. No schema change.

## Design

### Where it lives

A new Data Quality detector, `TransmitterRoleDetector` (category `tank`,
severity `warning`), registered in `kQualityDetectors`, plus a repair action.
The Data Quality Assistant already explains findings and offers repairs, and
`UnknownTransmitterDetector` is the closest sibling. My call, over these
alternatives:

- An automatic fix at import. Rejected because it changes a role without the
  diver's say-so.
- A check inside `CylinderConfigApplier`. Rejected because it only runs for
  divers who apply a configuration, who are exactly the ones #3416 already
  covers.

### Scope of dives

CCR dives only. SCR is left out for now. On SCR the open-circuit gases become
back gas or deco cylinders rather than a bailout (`_inferSensorlessRoles`), and
the supply gas is often the bailout as well, so "make it the bailout" is not
clearly right there. My call.

### Open-circuit time

Walk the dive's switches in time order, within the in-water part of the dive.
Clip both ends with the existing surfacing detection
(`core/profile/surfacing_pressure.dart`). Topside bleed-down after a dive that
ends on open circuit must never count (the #1092 problem).

- The dive starts on the loop. `gas_switches` does not store the starting gas,
  so if the **first** stored switch goes to a loop tank, the start is
  ambiguous: skip the dive. My call.
- A switch to a tank whose role is `diluent` or `oxygenSupply` means the diver
  is on the loop. This holds for a name-derived tank too. Only a "D"-named tank
  can be a switch target (an "O"-named tank never claims a gas), and it claims
  a gas the computer itself flagged as a diluent, so a switch to it is a loop
  switch by the computer's own account, whatever the cylinder turns out to be.
  My call.
- A switch to any other tank starts open-circuit time.

### The rule

For each name-derived tank with a pressure series:

- `loopRate` is its pressure drop per minute during loop time, and `ocRate`
  the same during open-circuit time. Count positive steps only, as in
  `TankAssignmentDetector`.
- Flag the tank when it lost more than 20 bar during open-circuit time, the
  open-circuit time is at least 2 minutes, **and** `ocRate` is at least 4 times
  `loopRate`.

The test compares rates, not each period's share of the total drop. A share
test would flag a real O2 supply on a long open-circuit deco after an early
bailout. A rate test does not. It also covers a constant-mass-flow (mCCR) unit,
whose orifice keeps bleeding O2 at the same rate on open circuit: equal rates
are never flagged. A bailout drops at about zero on the loop and fast on open
circuit. The thresholds are named constants in `QualityThresholds`, tuned
against the fixtures. My call.

The finding records `tankId`, `tankOrder`, `ocDropBar`, `loopRate`, `ocRate`
and `ocTankId`. `ocTankId` is the open-circuit target active for the largest
share of the open-circuit drop.

The diver sees something like: "Tank 2 is marked O2 supply from its
transmitter's name, but it lost 55 bar after you switched to open circuit and
almost none on the loop. It looks like your bailout." Pressures follow the
diver's unit settings.

### The repair

`UseAsBailoutRepair(tankId, ocTankId)`. The diver confirms it from the finding
and it does this:

1. Set the tank's role to `bailout` and clear `role_source`.
2. Set its mix to `ocTankId`'s mix.
3. If `ocTankId` is still exactly as the importer made it, merge it in:
   retarget its gas switches to the repaired tank and delete it, so the dive no
   longer shows two bailouts. "As the importer made it" means a computer gas
   list entry (`isComputerRecordedTank`) with no pressure series, no transmitter
   serial, no equipment link, and no size or label the diver added. That
   cylinder stands for a gas in the computer's list, not a physical cylinder, so
   merging it loses nothing anyone recorded. A diver carrying two bailouts of
   the same gas still gets just one gas list entry. If the diver has edited it,
   leave it in place. My call.

The confirmation names each change in the same "from → to" form as #3416's
dialog: role, gas mix, and "Removes the duplicate Bailout cylinder (switches
move to Tank 2)" when step 3 applies.

### Fixing the transmitter, not just the dive

Decided: the repair reaches past one dive. A diver who always carries a
bailout transmitter named "OC" would otherwise get a finding on every dive.

The confirmation offers, ticked by default, "Also register this transmitter as
a Bailout". When the tank carries a transmitter serial, accepting it:

1. Adds or updates the transmitter in the registry with role `bailout`. Future
   imports then take the role from the registry (`TransmitterRegistryMatcher`).
2. Runs the registry's existing apply-to-existing-dives
   (`TransmitterRepository`, lines 267-299), which today changes the role on
   every dive where that serial's role is still name-derived and clears the
   source. It is extended so that the mix is fixed too: a bailout must not keep
   the 100% default. For each such dive, the mix comes from, in order:
   - the same timeline evidence as the detector (that dive's `ocTankId`), with
     the same merge rule as step 3;
   - otherwise, a single as-imported sensorless bailout cylinder on that dive
     whose mix the computer recorded, merged the same way;
   - otherwise the mix stays as it is, and the confirmation result says how
     many dives kept their mix so the diver can check them. My call.

   The registry change also fixes the mix on import (`TransmitterRegistryMatcher`
   today never touches it), using the same order.
3. Leaves dives where the role is not name-derived untouched, as today.

Each of these writes goes through the repository, so sync carries it. The
detector stops firing on those dives because their roles are no longer
name-derived.

### Limits, stated in the finding's help text

- A bailout that was never breathed leaves no trace, so it is not flagged.
- If the diver bailed out without switching gases on the computer, the drop
  looks like loop time, so it is not flagged.

## Left to the builder

- The exact wording of the finding and repair strings, in every locale.
- How step 3 stays done after a reparse, whether by matching the removed
  cylinder's gas index to the repaired tank or by another route. A test must
  show that a reparse neither re-creates the duplicate nor reverts the role.
- Whether the repair is one service shared with the cylinder-config path or a
  repository method of its own.
- Fixtures: build them from the parsed shape of a real Shearwater CCR dive with
  an "OC"-named bailout transmitter, plus negative cases: a true O2 supply, an
  mCCR O2 supply on a long open-circuit deco after an early bailout, a dive
  that ends on open circuit with topside bleed-down, a diluent used for wing
  inflation during ascent, a dive with no switches, a dive whose first switch
  goes to the loop, an SCR dive, and a role the diver set.
