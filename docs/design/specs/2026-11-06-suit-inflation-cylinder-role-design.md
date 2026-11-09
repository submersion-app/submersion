# Suit Inflation cylinder role

Issue: #4243

## Intent

Drysuit divers carry a small bottle that only inflates the suit, often filled
with argon. Submersion has no way to say so. Logged as a pony or a stage, the
bottle is counted as breathing gas: its pressure drop feeds SAC and RMV, its
mix feeds deco, oxygen exposure and the gas statistics, and the planner treats
it as an ascent or bailout gas. Argon is not breathable, so those numbers are
wrong in the direction that matters for safety (more gas, more bailout, a
richer ascent than the diver actually has).

The feature adds a Suit Inflation classification that a diver can put on a
dive's cylinder and on the cylinder's equipment record, and keeps every
cylinder so classified out of every breathing gas calculation while still
showing it on the dive.

## Goals

1. A **Suit Inflation** tank role (`TankRole.suitInflation`, display name
   "Suit Inflation") pickable wherever a role is picked today: the dive's tank
   editor, cylinder configurations, and the transmitter registry. All three
   iterate `TankRole.values`, so the value appears without extra picker work.
2. A suit inflation cylinder **is not breathing gas** and is left out of:
   SAC and RMV (per dive, per range, per cylinder, records, insights), gas
   used, the gas mix statistics, the planner and the What-if conversion,
   deco, ceiling, TTS and NDL, the ascent gas set, CNS and OTU, ppO2 and MOD,
   gas switches, CCR diluent and bailout logic, the Dive Lab scenario engine,
   the insights tank configuration classifier, the data quality gas checks,
   the query language gas words, and the export "gas consumed" field.
3. It still shows in the dive's cylinder list with its role chip, volume,
   working pressure and start and end pressure if logged.
4. The equipment record of a tank can be marked as a suit inflation bottle,
   so the equipment list can be filtered to those bottles, and picking or
   scanning that bottle into a dive's tank sets the tank's role to Suit
   Inflation.
5. A dive downloaded from a computer gets the role automatically when the
   bottle's transmitter is registered with the Suit Inflation role (existing
   transmitter registry behaviour, which also back-fills existing dives).

## Non-goals

- **Argon as a gas.** `GasMix` holds only O2 and He. Storing argon needs a
  schema change and touches every gas display. The suit cylinder keeps its
  O2/He fields (some divers fill the suit bottle with air); the role, not the
  mix, is what marks it. Nothing reads that mix once the role is set.
- **Suit gas accounting** (how much argon a dive used, a suit gas SAC). Not
  asked for; the pressures are shown, nothing is computed from them.
- **A data quality finding** for a suit bottle that looks breathed (a gas
  switch to it, say). The switch is ignored by the calculations; flagging it
  is a later idea.
- **Fixing older app builds.** An older peer that syncs a dive with this role
  reads it as Back Gas (its own fallback) and, if the diver edits that dive
  there, saves Back Gas back. Nothing in this build can prevent that; the
  release notes say so.

## Anti-goals

- A suit cylinder must never be the SAC reference tank, the starting gas, an
  ascent or deco gas, the diluent, a bailout, or the "bailout carried" that
  satisfies a planner check. Any of those is a safety bug, not a cosmetic one.
- A dive with only a suit cylinder must not read as a dive with gas: it has no
  breathing gas, so it behaves like a dive with no tanks for every calculation
  (no SAC, no gas class, tank configuration "no tanks"), while the cylinder
  list still shows the suit bottle.

## Design

### The rule, in one place

Add to `TankRole` an `isBreathingGas` getter that is false only for
`suitInflation`, and a `breathingTanks` helper beside `backmountRoles` in
`lib/features/dive_log/domain/services/multi_cylinder_consumption.dart` that
returns the tanks whose role is breathing gas, in order. `Dive` gets a
`breathingTanks` getter over it. SQL gets one shared predicate in
`lib/features/dive_log/data/sql/multi_cylinder_sac_sql.dart`,
`breathingTankSql(alias)`, giving
`(<alias>.tank_role IS NULL OR <alias>.tank_role <> 'suitInflation')`.

Every calculation listed below switches from "all tanks" to "breathing tanks"
at its entry point rather than leaf by leaf, so a later calculation that starts
from `Dive.breathingTanks` is correct by default.

The list is the known set, not a closed one. Any other site found during the
build that reads tanks for gas follows the same rule: if it computes breathed
gas or physiology (consumption, mixes breathed, deco, oxygen exposure,
reserves), it uses breathing tanks only; if it deals with the physical
cylinder (weight, fills, inventory, service), it keeps the suit cylinder. Each
such site is listed in the PR. (Builder's call.)

### Gas switches to a suit cylinder

A downloaded computer can attach a switch to the suit cylinder when its gas
list holds the bottle's mix, which in practice is air, the same as the back
gas. Dropping that switch would leave the diver on the previous gas (say a
deco mix), understating deco, which is the unsafe direction. So at the same
entry point a switch whose tank is a suit cylinder is **re-targeted** to the
first breathing tank with the same O2/He mix, preferring the SAC reference
tank when it matches. Only when no breathing tank shares the mix is the switch
dropped. The stored switch is not rewritten; this is a read-time rule. (My
call.)

### Calculations that change

Each needs a test showing a suit cylinder, listed first and with a pressure
drop, changes nothing compared with the same dive without it.

- **Consumption helpers** (`multi_cylinder_consumption.dart`):
  `sacReferenceTankOf`, `referencePressureDrop`; `Dive.rmvFor`, `Dive.sac`,
  `sacReferenceTank`, `sacReferenceVolume`; `range_gas_consumption.dart`;
  `gas_usage_segments_service.dart`; `tank_usage_range.dart`
  (`startingTankOf`, `tankUsageWindows`, `activeTankAt`).
- **SQL consumption**: `diveSacPressureSql` (both the breathed set and the
  reference cylinder) and every insights query that joins `dive_tanks` for
  gas: SAC volume and pressure per dive and records, SAC by tank role (no
  `suitInflation` bucket), gas used per dive, gas mix distribution, the focus
  `gas_class` and `first_tank_volume`, the chart drill-down gas type, and the
  tank configuration SQL inputs. Also the dive list's `max_o2`/`max_he`.
- **Profile analysis** (`profile_analysis_provider.dart`): the combined
  pressure curve, the OC primary tank, `buildProfileGasSegments`, the CCR
  diluent resolution, loop gas, active gas usage segments, `buildAvailableGases`
  (ascent gas set), the isolate's starting fractions (`tanks.first` becomes the
  first breathing tank), and `scopedGasSwitches`.
- **Per-cylinder SAC and segments** (`gas_analysis_service.dart`,
  `gas_analysis_service_ccr.dart`): no SAC row for a suit cylinder; the
  fallback tank for an unknown switch is the first breathing tank.
- **CCR** (`ccr_gas_schedule.dart`, `ccr_cylinder_use.dart`,
  `ccr_bailout_timeline.dart`): a suit cylinder is never diluent use, never an
  open-circuit bailout target, and `openCircuitTargetRole` does not map it to
  bailout.
- **Planner** (`lib/features/planner/`, `lib/features/dive_planner/`): a
  plan never holds a suit cylinder. A plan is breathing gas only, and keeping
  the role out of plans also means no plan synced from this build can crash an
  older build (`dive_plan_repository.dart` parses plan tank roles with
  `byName`). Every way into a plan strips suit cylinders: the What-if
  conversion (`dive_to_plan_converter`), adding a saved cylinder or a cylinder
  configuration (`plan_saved_tanks_bar.dart` and any other add path found),
  and a plan file import. A saved cylinder whose role is Suit Inflation is not
  offered in the planner's saved-tank bar. Applying a configuration that holds
  one adds the rest and says in a SnackBar that the suit cylinder was left
  out. Because plans never hold one, the plan engine, its screens and
  `TankRoleResolver` need no other change. (My call.)
- **MOD**: `tank_mod.dart` `usesDecoLimit` gets a `false` arm, and the
  logged-tank MOD (`logged_tank_mod.dart`) returns no MOD for a suit cylinder,
  so the cylinders card and tank editor show none.
- **Trips** (`trip_gas_record_builder.dart`, `fill_forecast.dart`): a suit
  cylinder linked to a trip cylinder slot adds nothing to the trip's breathed
  litres or gas totals, but it still counts for fills, because the bottle
  really is filled. (My call.)
- **Dive Lab** (`lib/features/dive_lab/`): `TankSchedule.fromDive` and the
  scenario engine start from breathing tanks, so the primary, best tank for
  depth, lost-tank pool, consumption pass and counterfactual mix matching never
  include it.
- **Insights tank configuration classifier**: computed from breathing tanks,
  so a suit cylinder never adds `multiGas` and a dive with only one is "no
  tanks".
- **Derived metrics** (`derived_metrics_repository.dart`, SAC drift for
  Explore): the reference tank comes from breathing tanks.
- **Data quality**: `gas_mod_detector.dart` takes its starting gas from
  breathing tanks; `gas_switch_time_suggestions.dart` `hasBreathingStarts`
  excludes suit cylinders; the bailout, tank assignment and transmitter role
  detectors treat a suit cylinder as neither loop gas nor open-circuit gas.
- **Download cleanup** (`bailout_gas_claim.dart`, `unused_oc_gas_cleanup.dart`,
  `bailout_mix_fixer.dart`): a suit cylinder is never claimed as bailout,
  removed as an unused OC gas, or given a bailout mix.
- **Export and field extraction** (`dive_field_extractor.dart`): the gas,
  start and end pressure columns come from the first breathing tank, and gas
  consumed sums breathing tanks.
- **Query language**: the air/nitrox/trimix/EANxx words and the O2 filter
  match breathing tanks only.
- **Split-dive merge** (`sequential_tank_merge.dart`): a suit cylinder only
  merges with a suit cylinder, never with breathing gas of the same mix.
- **Estimated pressure synthesizer**: no straight-line estimated series for a
  suit cylinder (it would draw a breathed-looking curve). Logged pressures
  still draw.

Unchanged on purpose: buoyancy and gas weight (`buoyancy_twin_assembler.dart`)
keep the suit cylinder, because its weight is real; equipment O2 exposure
filters on diluent and O2 supply and is unaffected.

### What the diver sees

- **Tank editor**: Suit Inflation in the role dropdown, with the existing pony
  glyph (the role icons show how a cylinder is carried, and a suit bottle rides
  the way a pony does; the label tells them apart). The mix fields stay. No MOD
  is shown for a suit cylinder.
- **Gas switch editor**: suit cylinders are not offered as a switch target.
- **Cylinders card**: the suit cylinder is listed with a Suit Inflation role
  chip and its pressures; it has no SAC, no MOD and no gas-used figure.
- **Insights**: the SAC by role card has no suit bucket and its role label
  switch gets a proper arm.
- **Equipment record**: a new tank choice attribute, **Cylinder use**, with
  choices **Breathing gas** and **Suit inflation**; unset means breathing gas.
  As a choice attribute it appears in the tank's edit form and detail page and
  in the equipment filter sheet's Tank choices (#1805) with no extra wiring.
- **Own cylinder into a dive**: when the cylinder picked from "My cylinders"
  or scanned by tag is marked Suit inflation, the tank's role becomes Suit
  Inflation.
- **Transmitter registry**: when the diver links a cylinder marked Suit
  inflation to a transmitter on the transmitter edit page (`_applyGear`), the
  role field is set to Suit Inflation, ahead of the role suggested from
  history. Saving the entry then runs the registry's existing back-fill of
  that transmitter's dives.
- **The attribute is a default, not the source of truth.** It sets the role
  at the moment a bottle is picked or linked. Marking an existing bottle as
  Suit inflation does not rewrite dives or transmitter entries already saved;
  the dive and the transmitter entry keep the role they hold, and the diver
  changes those where they are. No back-fill, so no sync rewrite. (My call.)

### Import and export

- **UDDF** round-trips the role by name already.
- **Subsurface XML** import maps `use="not used"` (Subsurface's value for a
  non-breathing cylinder) to Suit Inflation; it currently falls to Back Gas.
- **Sync** sends the role as a string, so it reaches peers on this build
  unchanged. Older peers: see Non-goals.
- **Saved plans**: plans never hold the role (see Planner). Separately,
  `dive_plan_repository.dart` parses plan tank roles with `byName`, which
  throws on an unknown name; make it tolerant (unknown name becomes Back Gas)
  so a role added by a later build can never crash this one.

### Localization

New keys in all 11 ARB files: `enum_tankRole_suitInflation`,
`insights_gas_tankRole_suitInflation`, and the attribute label and choices
for `cylinder_use`. The enum's English `displayName` stays "Suit Inflation"
for interchange formats and joins `test/l10n/kept_english_values.dart` if that
test requires it.

## Constraints

- No schema change: the role is stored by name in `dive_tanks.tank_role`,
  `cylinder_config_items`, transmitter entries and plan tanks; the equipment
  attribute uses the existing `equipment_attributes` table.
- Every unit shown follows the active diver's unit settings (existing
  widgets).
- Tests first, per the repo's TDD rule; the architecture and adoption guards
  under `test/architecture/` and `test/shared/` must stay green.

## Left to the builder

- The exact shape of the entry-point filtering (a parameter, a getter, or a
  filtered list passed down), provided each listed calculation is covered by a
  test.
- Whether a site in the agent-map list above turns out not to read tanks for
  gas after all; such a site needs no change, only a note in the plan.
- Test fixture shape and file layout, within the 800-line file limit.
