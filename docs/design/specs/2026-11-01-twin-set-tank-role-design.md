# Twin set as a tank role

Issue #3374. Release v1.8.4.

## Intent

A diver on backmount doubles has no way to say so. The tank role list has
Back Gas, Stage, Deco, Bailout, Sidemount Left and Right, Pony, Diluent and
O2 Supply, and nothing for a manifolded twin set. The Insights Gas page
counts "twin backmount" dives anyway, by guessing from cylinder names
("twin", "double", "doppel", "D12", "2x12"), from size (20 L or more) and
from two Back Gas cylinders on the same gas.

The guessing is wrong in both directions, and nobody can override it. In the
Sidemount-Forum thread about Submersion (posts 112 to 116, 31 Oct to
1 Nov 2026) one diver who has never dived doubles sees twin dives on the Gas
page, most likely because "Doppelventil" (a twin-outlet valve on a single
cylinder) in a cylinder or preset name matches the "doppel" rule. Another, a
sidemount diver, sees 108 twin dives and asks where they come from: his
downloaded sidemount dives carry two Back Gas cylinders on the same gas,
which the matched-pair rule reads as doubles.

This feature makes the twin set explicit, with its own icon, stops the
guessing, and gives divers who logged doubles under the old rules a one-tap
way to re-role them.

## Goals

- A diver can mark a cylinder as a twin set when logging or editing a dive,
  and sees a glyph that reads as doubles wherever the role's icon shows.
- The Gas page's Tank configuration card, and the dive list's tank
  configuration filter, count a dive as twin backmount only when a cylinder
  carries the Twin Set role.
- Consumption and SAC treat a twin set correctly: one row with the combined
  volume is one big cylinder; two rows both marked Twin Set are a matched
  pair, as two sidemount rows are today.
- Divers whose older dives would have counted as twins under the name or
  size rules can find those dives and re-role them in one tap, or review
  them first.

## Non-goals

- No built-in twin presets. A diver who wants "Twin 12L" as a preset makes
  a custom one; presets carry no role.
- No change to how sidemount dives are detected or re-roled. A sidemount
  diver whose downloads tag both cylinders Back Gas still sets Left and
  Right by hand or by transmitter registration. The matched-pair guess goes
  away, so those dives count as single backmount until then, which is
  honest.
- No data quality detector for twin-looking cylinders. The finder lives on
  the Gas page card only, as a migration aid.
- No change to the planner's role resolver, which derives roles for plan
  cylinders from gas; a plan never produces a Twin Set role.

## Anti-goals

- A dive must never become a twin set without the diver choosing it. No
  migration rewrites roles, and the one-tap action runs only when the diver
  taps it and confirms.
- The one-tap action must never touch a stage, deco, bailout, pony or
  sidemount cylinder on a candidate dive, and never a cylinder on a dive
  that is not a candidate.

## The role

`TankRole.twinSet`, display name "Twin Set", stored by name in
`dive_tanks.tank_role` like every other role. No schema change: the column
is text and older peers that receive an unknown role name already fall back
to Back Gas when reading it, which is the right degradation.

Placement in the role picker: directly after Back Gas, before Stage, since
it is the other way to carry the primary gas on the back. The enum
declaration order drives the dropdown, so the enum gains the value in that
position.

Localized name in all eleven ARB locales, key `enum_tankRole_twinSet`,
alongside the other role names. English: "Twin Set". German: "Doppelgerät",
which is the word the forum thread and the existing German Gas page label
use.

### Semantics

A twin set is the diver's primary back-mounted gas. Everywhere the code
asks "is this the back gas" to mean "is this the primary cylinder worn on
the back", Twin Set answers yes. Those places exist today as
`role == TankRole.backGas` checks and as `'backGas'` literals in SQL; the
builder introduces one shared set, `backmountRoles = {backGas, twinSet}`
next to `sidemountRoles`, and uses it at each of them. Sites found by a
search for `TankRole.backGas` and for the `'backGas'` literal, which the
builder repeats before planning:

- `sacReferenceTankOf` (the cylinder a SAC is referenced to) and its SQL
  mirror in `multi_cylinder_sac_sql.dart`
- `tank_usage_range.dart` (the primary gas spans a dive with no switches)
- `profile_analysis_provider.dart` (the SAC reference, and the ascent gas
  set: a twin set is carried gas, never dropped from it)
- the tank configuration classifier (below)
- `tank_mod.dart` `usesDecoLimit` and `modLimitClassFor` (a twin set uses
  the bottom ppO2 limit, like Back Gas)
- `figure_composer.dart` (below)
- Compare and the dive lab: `tank_schedule.dart`, `scenario_engine.dart`,
  `lab_delta_panel.dart` (the back-gas tank id)
- `downloaded_tank_defaults.dart`, `unused_oc_gas_cleanup.dart`,
  `transmitter_auto_registrar.dart` (download-time defaults and cleanup
  that single out Back Gas)
- export, documents and import mappings that translate roles by name keep
  working unchanged since they go through the enum's `name` or
  `displayName`.

Three sites look like the same question and are not:

- **Cylinders card and the detailed PDF template** hide the role row when
  a dive's only cylinder is Back Gas, because the role is then the obvious
  one. A lone Twin Set shows its row and glyph: that is the whole point of
  the role, and the most common twin-set dive. These sites keep comparing
  to Back Gas alone.
- **CCR gas schedule.** `ccrCylinderRole` reinterprets an untagged Back Gas
  cylinder on a rebreather dive as diluent or O2 supply, because a file
  import tags what it does not know as Back Gas. A Twin Set is a role the
  diver chose, so it is explicit open-circuit gas on a CCR dive (the
  bailout doubles of a CCR diver), takes the default branch, and stays in
  the bailout gas set.
- **Equipment figure.** `_mergeDoubles` draws the doubles artwork only when
  two cylinders land in the back zone. One Twin Set row draws the doubles
  artwork on its own, since this feature asks divers to log a twin set as
  one row. Two Twin Set rows still merge into the same artwork.

The six exhaustive `switch`es on `TankRole` (`tank_mod.dart`,
`ccr_gas_schedule.dart`, `tank_enum_display.dart` twice,
`plan_tank_list.dart`, `figure_composer.dart`) are compile errors until the
value is handled. They are not a safety net for the `==` checks above, which
the compiler ignores, so the search is part of the plan, not optional.

### Matched pairs

`isMatchedPair` today: both sidemount, or both Back Gas on the same gas.
It becomes: both sidemount, or both Twin Set, or both Back Gas on the same
gas. The Back Gas clause stays because consumption still needs two
transmitters on one manifold to share a window; only the Insights
classifier stops reading it as "twin backmount". Two Twin Set rows need no
gas check, since the diver said what they are.

`multi_cylinder_sac_sql.dart` mirrors `isMatchedPair` and the SAC
reference choice as literal SQL for the Insights SAC and RMV charts, the
SAC by role card and the query language, with parity tests in
`insights_repository_multi_cylinder_sac_test.dart`. The mirror gains the
Twin Set pair clause and lets the reference be a Twin Set, and the parity
tests gain twin-set cases. Routing the pair rule through a registered
function is a larger refactor than this feature needs.

### Icon

A new glyph, `SubmersionIcons.tankTwinSet`, drawn in
`tool/equipment_glyphs.py` and compiled into the equipment font by
`tool/build_equipment_icon_font.py`, appended at the end of the glyph list
so existing code points keep their numbers. Two upright cylinders side by
side, both solid, joined across the top by a manifold bar with a valve
handwheel at each outer side. Both solid tells it apart from the sidemount
pair, where one cylinder is solid and the other outlined. Before committing
the font, the builder looks at the glyph: `python3 tool/equipment_glyphs.py`
prints every glyph's path data on a 24 by 24 grid, so one throwaway SVG
placing the new path at 24 px and at about 96 px with
`fill-rule="nonzero"` (the font fills with nonzero winding), rasterized
with `qlmanage -t`, shows whether it reads beside the sidemount pair. The
`--verify` flag of the font builder only checks bounds.

`TankRole.icon` maps `twinSet` to the new glyph.

## The classifier stops guessing

`classifyTankConfiguration` base rules become, in order:

1. rebreather: dive mode CCR or SCR, or any diluent or O2 supply cylinder
2. noTanks: no cylinders
3. sidemount: any sidemount cylinder
4. twinBackmount: any Twin Set cylinder
5. other: no Back Gas and no Twin Set cylinder
6. singleBackmount: otherwise

`looksLikeTwinSet`, `twinSetMinVolumeLiters` and the three regexes leave the
classifier. The matched-pair check leaves the classifier too. The extras
(stages, deco gas, multi-gas) are unchanged.

The SQL functions in `tank_configuration_sql.dart` call the same Dart
classifier, so the Gas page card, the tank configuration filter and the
query language all change together with no SQL edit.

The card's note (`insights_gas_tankConfig_note`) becomes: "A dive counts as
twin backmount when a cylinder's role is Twin Set, and as sidemount when
its cylinders are Sidemount Left and Right." In every locale.

Existing tests that assert the guessing (classifier tests for names, sizes
and matched pairs) are rewritten to assert the role rule and that names and
sizes no longer matter.

## The finder and the re-role

### Candidates

A candidate cylinder is a `dive_tanks` row with role Back Gas whose name or
preset name matches the old name rule, or whose volume is 20 L or more.
That is exactly `looksLikeTwinSet` as it exists today, moved out of the
classifier into `lib/features/insights/domain/tank_configuration/twin_set_candidates.dart`
and documented as the migration finder, not a classification rule. The
matched-pair rule is not a candidate rule: for a sidemount diver those
pairs are the wrong answer, and the diver can find them with the filter
"Single backmount" if they want.

Candidates are found by one SQL query over `dive_tanks` joined to the
active diver's dives, through a registered SQL function
`twin_set_candidate(tank_role, tank_name, preset_name, volume)` so the Dart
rule stays the single source of truth, as the classifier already does. The
query yields the candidate tank ids and the distinct dive ids they belong
to.

### The note on the Gas page

Below the bars on the Tank configuration card, when the active diver has at
least one candidate and has not dismissed the note on this device:

> **14 dives have a cylinder that looks like a twin set.** Their names or
> sizes say twin, double, D12, 2x12, or 20 L and up, but their role is Back
> Gas, so they count as single backmount.
>
> [Mark as twin sets]  [Review dives]  [Dismiss]

The count is the number of distinct dives. The sentence uses an ICU plural.

- **Mark as twin sets** opens a confirmation dialog: "Set the role of 15
  cylinders on 14 dives to Twin Set? Other cylinders on those dives are left
  alone." (plurals for both numbers). Confirming writes the role on the
  candidate rows only, clears `role_source` on them (a role the diver set is
  no longer the transmitter name's, as the bulk editor does), marks those
  rows pending for sync and bumps their parent dives the way
  `bulkUpdateTankSpecs` does, and shows a SnackBar "15 cylinders set to
  Twin Set". The card re-queries and the note disappears because no
  candidates remain. The write goes through `DiveRepository`, as one new
  method `setTankRoles(List<String> tankIds, TankRole role)` that does for
  a list of tank ids what the bulk tank spec edit does per dive, in its own
  transaction and with its own change notification, since the bulk method
  leaves both to its caller. It is not undoable from the SnackBar; a diver who
  changes their mind uses bulk edit or the tank editor, and the
  confirmation names the count.
- **Review dives** opens the dive list filtered to the candidate dives, the
  way tapping a bar on the card opens the dives it counted (the existing
  `openChartDives` path). From there the diver can open each dive or select
  some and bulk edit their role. The filter is a dive id list, not a new
  filter axis, so nothing is added to the filter state or the query
  language.
- **Dismiss** hides the note on this device for the active diver, in
  SharedPreferences under a key that includes the diver id. It does not
  sync, by design: the note is a migration aid, and the Dismiss is for a
  diver who looked and disagrees with the finder. Insights observations
  keep their dismissals in a synced table; the note is not an observation
  and does not join that engine, so a reviewer asking why should be
  pointed here. The note also hides itself, without a dismissal, whenever
  the candidate count is zero.

The note's provider depends on the same tables the card's stats depend on,
so a re-role, a bulk edit or a sync refreshes it.

### Why not a per-dive checklist

The candidate rule is the one that produced the counts divers already saw
on the card, so "Mark as twin sets" gives them the same dives back, now as
explicit roles. A diver who wants to pick and choose has Review dives, the
existing bulk editor and the tank editor. A checklist would be a third
selection surface for a one-time event.

## Where the diver sees it

- Dive editor, tank row, role dropdown: new entry with the new glyph.
- Dive detail, cylinders card: the glyph beside a twin set.
- Cylinder configs editor and the transmitter edit page: the role lists
  there iterate `TankRole.values`, so they gain the entry too. A
  transmitter can be registered as a twin set, and downloads then tag the
  cylinder Twin Set, which is right for a diver with one transmitter on
  their doubles.
- Insights, Gas page, Tank configuration card: counts by role; new note
  with three actions when candidates exist.
- Insights, Gas page, SAC by role card: Twin Set is its own row, labelled
  with a new `insights_gas_tankRole_twinSet` string, not folded into Back
  Gas.
- Dive detail and equipment pages, the equipment figure: one Twin Set row
  draws the doubles artwork.
- Dive list, Refine, Gas and equipment: "Twin backmount" filter now means
  the role.
- Query language: `tankConfiguration` enum values unchanged; semantics
  follow the classifier.

## Constraints

- No schema bump. A role is stored by name.
- Anything displaying volume respects the diver's unit settings. The
  note's "20 L" goes through `formatTankVolume`, the way the app labels
  cylinders everywhere else, so an imperial diver reads a rated capacity
  (about 141 cu ft), not a water volume of 0.7 cu ft that means nothing to
  them.
- The Dart rule for candidates and the classifier each reach SQL through
  a registered function, never a SQL translation that could drift. The
  consumption SQL mirror is the existing exception, kept honest by its
  parity tests.
- Tests first. Classifier tests, candidate finder tests, repository test
  for `setTankRoles` (only the named rows change, pressures survive,
  `role_source` clears, sync stamp bumps), widget test for the note
  (hidden with zero candidates, hidden after Dismiss, count and plural,
  confirmation text), and the existing `test/architecture/` and
  `test/shared/` guards after adding files under `lib/`.
- Every ARB locale gets the new strings: role name, card note, finder
  sentence, three button labels, confirmation title and body, SnackBar.
- Screenshots for the PR: role dropdown before and after, Gas page card
  before and after (with the note showing), light and dark since a glyph is
  added.

## Left to the builder

- Exact glyph geometry, within the description above.
- The SharedPreferences key name and where the dismissal provider lives
  (an Insights provider next to the card's stats provider is the obvious
  place).
- Whether `setTankRoles` reuses `_tankSpecsCompanion` with a role-only field
  mask or writes its own companion; either is fine as long as only
  `tank_role`, `role_source` and the sync columns change.
- Test fixtures.

## Calls made in this design, for the reader to check

- English name "Twin Set", not "Doubles": it matches the existing
  "Twin backmount" label on the Gas page and the issue's title.
- Placement after Back Gas in the role list.
- No built-in twin presets.
- Dismissal is per device, not synced.
- The matched-pair rule stays for consumption and leaves the classifier.
- "Mark as twin sets" is confirmed, not undoable.
- A Twin Set on a CCR dive is explicit open-circuit gas (bailout doubles),
  not reinterpreted as diluent the way an untagged Back Gas cylinder is.
- A dive whose only cylinder is a Twin Set shows the role and glyph on the
  cylinders card and in the detailed PDF, unlike a lone Back Gas.
- One Twin Set row draws the doubles artwork on the equipment figure.
- The consumption SQL mirror is extended with twin-set clauses and parity
  tests rather than refactored onto a registered function.
- The note writes the size threshold with `formatTankVolume` (rated
  capacity in imperial).
- Twin Set is its own row on the SAC by role card.
