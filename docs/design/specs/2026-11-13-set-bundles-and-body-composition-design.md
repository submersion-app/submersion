# Equipment sets that carry weights and tanks, and body composition inputs

Date: 2026-11-13. Release: v1.8.5. Size: project (two parts, one PR).

## Intent

A diver wrote in after a trip on a new backplate rig with a new housed camera.
They had built an equipment set for the gear and a weight preset for the lead,
and had to pick both on every dive. They want one pick that sets up a whole
dive, with a second variant for the camera (same gear, the camera, less lead).
They also asked for an optional body fat percentage on the diver profile, which
the app would estimate and the diver could override, to sharpen the weight
prediction.

Today an equipment set holds gear only. Weight presets and cylinder
configurations are separate entities, each applied by its own control in the
dive editor, and neither is ever applied automatically. The weight prediction
guesses body composition from height and weight alone.

## Goals

Part 1, set bundles:

- An equipment set can also carry other sets, weight presets and cylinder
  configurations. Its own gear list is the "extra gear" on top of the sets it
  includes.
- Wherever a set is applied today, the whole bundle is applied: the dive
  editor, bulk edit, rule actions, every import path, the dive planner, the
  pre-dive checklist and trip gear.
- The three automatic triggers that sets already have (default set, location
  match, auto-apply on dive computer import) apply the whole bundle.
- A set with no gear, holding only weights and tanks, is usable (for example
  by a diver who rents gear).
- A dive shows one chip for a picked set, even when that set includes others.

Part 2, body composition:

- The diver can record body fat percentage with each dated body-weight entry.
- The diver profile gains two optional fields, sex and birth year, so the app
  can show a proper estimate of body fat and use it in the weight prediction.
- A typed body fat percentage overrides the estimate.

## Non-goals

- No separate "configuration" entity (considered, see Approaches).
- No link from a dive's weights or tanks back to the set. They are copies.
  Editing a weight preset or a cylinder configuration never rewrites past
  dives, and a dive shows no chip for a set that brought no gear.
- The weight planner stays gear-only for sets (it predicts lead and has its
  own tank list). It does get the gear of included sets.
- "Save as set" in the dive editor keeps capturing gear only.
- No rule conditions on which set a dive carries.
- Sets nested more than one level deep.
- Merging the two ways of recording lead (weights as equipment items, and the
  dive's Weights section). That is issue #4442; this work relates to it and
  does not resolve it.
- Sex and birth year are not written to UDDF or shown on the buddy card.

## Anti-goals

- An unattended path (bulk edit, a rule, an import) must never replace or add
  to weights a diver logged, or change a cylinder's size, gas or pressure that
  a diver or a dive computer recorded.
- Applying the same set twice, or re-importing a dive, must not duplicate
  gear, weights or cylinders.
- A set and a set it includes landing on the same dive must not count the
  inner set's lead or cylinders twice.
- A diver who fills in none of the new body fields must get exactly the
  predictions they get today.
- The app must not show a body fat estimate it cannot stand behind: no number
  unless weight, height, sex and birth year are all known.
- Undoing a bulk edit or a rule run must restore weights and tanks exactly,
  not only gear.

## Constraints

- Every displayed weight, volume and pressure respects the active diver's unit
  settings.
- Schema changes follow the split layout: table classes in
  `lib/core/database/tables/`, a helper in `migrations/helpers/`, a rung in
  `migrations/ladder/rungs_v340_onward.dart`, and backstops in a part file
  (`before_open.dart` is at the 800-line guard). `database.dart` only
  registers tables. One schema bump (v364 at the time of writing) covers both
  parts.
- New synced tables and columns join sync, the conflict catalogue, the change
  log policy and the agent-access documents, as the precedents do (v196 weight
  presets for parent-gated children, v341 for a full file list).
- Every new string is translated in all ARB files.

## Approaches considered

- **A. A set links one weight preset.** Smallest. Rejected early: one preset
  and no tanks was too narrow.
- **B. A separate "dive configuration" entity** bundling sets, extra gear,
  weight presets and cylinder configurations. First choice, until it had to
  work everywhere sets do. Sets are offered in nine places, have three
  triggers threaded through six import seams, and are wired into sync, UDDF,
  PDF, search, rules and bulk edit. A parallel entity repeats all of it
  (estimated 80 to 120 files) and needs a rule for which wins when a set and
  a configuration both match a trigger.
- **C. A set is the configuration.** Chosen. A set gains three optional lists.
  Every existing picker, trigger, rule and bulk action already takes a set, so
  each applies the bundle with no new entry point. Roughly a third of the work
  of B. The cost is conceptual: sets are no longer gear-only.

## Part 1: set bundles

### Data model

Three junction tables, each a parent-gated child of `equipment_sets` shaped
like `weight_preset_entries`: an `id` primary key, a unique pair, a
`sort_order`, `created_at`, its own `hlc`, and a cascade from both parents.
They do not copy `equipment_set_items`' composite key, whose sync path has
spots no test guards. The order of presets and configurations is meaningful,
so it is stored; a set's own gear keeps having no stored order.

| Table | Columns |
| --- | --- |
| `equipment_set_includes` | `id`, `set_id`, `included_set_id`, `sort_order` |
| `equipment_set_weight_presets` | `id`, `set_id`, `preset_id`, `sort_order` |
| `equipment_set_cylinder_configs` | `id`, `set_id`, `config_id`, `sort_order` |

`EquipmentSet` gains `includedSetIds`, `weightPresetIds` and
`cylinderConfigIds` (ordered), with `copyWith`.

Rules:

- One level of nesting. A set that includes other sets cannot be included, a
  set that is included cannot gain includes, and a set cannot include itself.
  The repository refuses a write that breaks this and the picker hides
  ineligible sets.
- Included sets belong to the same diver as the set.
- Two devices can each make a valid edit that together break the rule. Reading
  is therefore tolerant: expansion goes exactly one level and ignores anything
  deeper, so it cannot loop.
- Deleting a set, a weight preset or a cylinder configuration removes it from
  every set that referenced it. Nothing else about those sets changes.

### The bundle

A pure domain service resolves a set into its bundle. Everything adds up:

- **Gear:** the gear of each included set, then the set's own gear, with
  duplicates removed ("effective gear").
- **Weights:** the entries of each included set's presets, in order, then the
  entries of the set's own presets. Each entry keeps its type and name. Every
  reference counts, so a preset reached twice contributes twice.
- **Tanks:** the cylinders of each included set's configurations, in order,
  then those of the set's own configurations. The joined list is renumbered
  before it reaches `CylinderConfigApplier`, which sorts by each cylinder's
  own position and would otherwise interleave them.

Because lead adds up, a variant that needs less lead than its base is built by
keeping the lead out of the base:

```
BP rig            gear: backplate, wing, reg, computer, fins, boots, SMB
                  tanks: AL80 EAN32
BP, no camera     includes BP rig;  weights: pockets 6 lb, belt 8 lb
BP + camera       includes BP rig;  gear: camera housing
                                    weights: pockets 6 lb, belt 6 lb
```

A set is offered and auto-applied when its bundle holds anything at all: gear,
weights or tanks.

### One set absorbs the sets it includes

Whenever a set and a set it includes would both land on a dive, the outer set
absorbs the inner one: the dive carries the outer set only, and the inner
set's lead and cylinders count once, as part of the outer bundle.

- In one unattended pass (an import, a bulk edit, a rule run), a set that is
  included by another set landing in the same pass contributes nothing on its
  own, and its gear is tagged with the outer set.
- In the dive editor, picking a set that includes a set already on the dive
  re-tags that set's gear to the picked set. If the dive's weights are still
  exactly what the absorbed set filled in, they are replaced by the picked
  set's without a question.
- An unattended pass does not re-tag gear that an earlier pass put on an
  existing dive. The same holds for tags a dive arrives with: a file import
  writes the sets the dive was logged with, and only the sets the import
  itself applies (the default or location set, the computer's sets) are
  folded into one.

### What applying a set does

Gear. Effective gear is added and tagged with the set that was applied
(`viaSetId`), including gear that came through an included set. Gear already
on the dive under an unrelated set keeps its tag, as today. The sharing rule
(a member no longer shared with the diver is skipped, #2046) applies to
effective gear.

Weights and tanks are applied by the state of the dive, not by whether the
set is new to it, so every path is repeatable.

| Where | Weights | Tanks |
| --- | --- | --- |
| Dive editor: picking a set, accepting a location suggestion | Empty Weights section: filled. Otherwise, when the set carries weights, the diver chooses Add, Replace or Keep. | Merged through `DiveTankConfigAdapter.apply`. A change to an existing cylinder goes through the existing confirmation; declining it skips the tanks only. |
| Dive editor: default or location match on a new dive | Filled (the dive has none). | As above, without overwrites. |
| Unattended: bulk edit, rule actions, imports (computer, file, Apple Health, GPS re-match) | Only when the dive had no weights at the start of the pass. Then the weights of every set landing in the pass are combined. | Dive has no tanks: the cylinders of every set landing in the pass are inserted. Dive has tanks: gaps are filled (`FillTank`), nothing is inserted and nothing is overwritten. |

"No weights" means no weight rows and no legacy scalar weight on the dive.

Order when several sets land in one pass: the location or default set first,
then computer-linked sets by name; in a bulk edit or rule, the order listed.

**Starter tank.** A new dive in the editor is seeded with one starter tank
(default size, air). While that tank is the only one and has not been edited,
a set's cylinders replace it, gas included, on a pick and on the default or
location match, provided the set brings a main supply: back gas, a twin set,
a sidemount pair, or a rebreather's diluent and oxygen. The starter stands in
for the diver's main gas, so a set that carries only a stage, deco, bailout
or pony cylinder leaves it where it is and adds its own beside it. A set with
no cylinders leaves it alone. The same holds for a new plan that still holds
only its default plan tank.

Removing a set from a dive removes or keeps its gear, exactly as today.
Weights and tanks stay.

Details by path:

- **Dive computer download.** Sets are applied at dive creation
  (`dive_computer_repository_impl.dart`, around line 1802), before the
  computer's tanks are inserted (around line 2088). Gear stays at that seam,
  because the defaulter must run before the computer-gear linker. The weights
  and tanks of the sets that landed are applied in one step after the tanks
  are written. The second seam that re-links computer sets on an existing
  dive (around line 2457) applies weights and tanks by the same state rules.
- **File, UDDF and Apple Health imports** already run the set seams after the
  dive and its tanks exist; the bundle step follows the computer-set linker.
- **Computer-linked auto-apply.** A set counts as containing the computer when
  the computer is in its effective gear.
- **GPS re-match replacing the default set** (`replaceSetEquipment`, #3704).
  Gear is swapped as today. If the dive's weights are still exactly what the
  old set filled in, they are replaced by the new set's (removed when the new
  set has none); otherwise they are left alone. Cylinders the old set inserted
  stay, and the new set's go through the unattended tank rule. A set with no
  gear leaves no tag, so re-matching cannot see or replace it.
- **Bulk edit and rules.** A dive whose weights or tanks changed counts as
  changed, even when its gear did not. Undo must restore the weights and tanks
  a set wrote. Bulk edit already snapshots both for its own weights and tanks
  operations; rule runs record equipment changes only today and need the same
  coverage.
- **Update past dives when a set changes** (#4283). The diff is taken over
  effective gear. Editing a set that other sets include also offers the dives
  that carry those outer sets, since they hold the outer set's tag. Changing
  the list of included sets is a gear change. Changing a set's weight presets
  or cylinder configurations offers nothing: those are copies. Applying the
  set again fills dives that have no weights.

### Other places that take a set

- **Dive planner.** Gear as today, plus the bundle's cylinders added to the
  plan's tank list with `tankFromItem` (the planner's existing
  add-one-saved-cylinder path, which carries the gas). A cylinder is skipped
  when the plan already has one with the same role, size and mix, and the
  untouched default plan tank is replaced as described above. Segments
  already written on that tank (a quick plan's) move to the set's main
  cylinder, as they move to a fallback when a tank is removed. The planner's
  `addTank` drops non-breathing roles; that stays. Plan results recompute on
  every change, so nothing more is needed. Weights are not applied: the plan
  has its own prediction.
- **Pre-dive checklist.** A session started from a set gets one check per item
  of effective gear (as today, now with included sets), then one check for the
  lead ("Weights: 12 lb", with the breakdown) and one per cylinder (its label,
  or size and mix). These are plain checks whose text is fixed when the
  session starts.
- **Trip gear.** Adding a set packs its effective gear and slots tank items as
  today, slots the bundle's cylinders as spec-only cylinder slots (label,
  size, pressure, material; with no owned tank behind them the board shows
  them as rentals), and adds a "Lead: 12 lb" item to the trip's
  checklist. Cylinders and a lead item already present are not added again.
  With no checklist on the trip the lead item is skipped and the confirmation
  says so; with several, the diver picks one. The confirmation's count takes
  in the lead item with the gear and slots, so a set that carries only lead
  reports the one item it added.
- **Weight planner.** Effective gear only; a set with no gear is not offered.

### Set pages

The edit page gains three sections below the gear list. Each has an add
action, remove, and reorder.

```
Edit set: BP + camera
  Name, description, default, auto-apply on import, geofences   (as today)
  Gear             Camera housing                    [+ add gear]
  Included sets    BP rig                            [+ add set]
  Weights          Pockets 6 lb, Belt 6 lb           [+ add preset]   total 12 lb
  Tanks            (none of its own)                 [+ add configuration]
  Applies in total: 8 items, 12 lb, 1 cylinder
```

The detail page shows the same sections read-only (included sets link to
their own page), says what comes from included sets, and gives the bundle's
totals. The diver figure draws effective gear. The set tile shows the
effective item count, plus the lead total and cylinder count when present.
Cloning a set copies all three lists. A dive shows one chip per set whose gear
it carries.

### Plumbing

- Sync: the three tables follow `equipment_set_items` through the serializer,
  apply order (after sets, weight presets and cylinder configurations),
  parent references, conflict references and the change log policy (root
  `equipment_sets`), with `sort_order` as an extra field.
- UDDF: the custom set element carries included-set references, since the sets
  are in the same file. Weight presets and cylinder configurations are not in
  UDDF today, so those two lists are not exported. Import restores included
  sets.
- Agent access: the set document and the set write family gain the three
  lists, with the nesting rule enforced on write.

## Part 2: body composition

### Data model

- `diver_weight_entries.body_fat_percent` (real, nullable).
- `divers.sex` (text, nullable: `female` or `male`) and `divers.birth_year`
  (integer, nullable).

All three sync with their rows and appear in the conflict catalogue and the
agent-access documents. The entities gain the fields and `copyWith`.

A typed body fat value carries forward the way height does: the newest entry
that has one is the diver's current value, so a later weigh-in without the
field does not drop back to the estimate.

### Model

`BodyComposition` today adds lead in proportion to how far the diver's BMI is
from the BMI of the same mass at 175 cm, using only the slope of the
Deurenberg formula (1.2 points of body fat per BMI unit). The change makes the
fat percentage explicit:

- Estimated fat % = `1.20 * BMI + 0.23 * age - 10.8 * sexTerm - 5.4`
  (Deurenberg et al., 1991), with `sexTerm` 1 for male, 0 for female. An
  unknown age uses 40 and an unknown sex uses 0.5.
- Reference fat % = the same formula at 175 cm with the neutral age and sex.
- Lead term = `mass * 0.2 * (fat - reference) / 100`, where `fat` is the typed
  value when there is one, else the estimate (which needs a plausible height).
  With neither a typed value nor a height the term is zero.

With no typed value, no sex and no birth year this reduces to today's term
exactly. That identity is a required test, across the plausible range of mass
and height, and the term is not clamped so the identity holds at the extremes.

The engine keeps treating the term like physics: subtracted before the
regression and added back by `predict`, with the fitted model remembering what
it subtracted (today a height; now the full set of body inputs) so predict
never adds a term the fit did not remove. Age is taken at the same date each
caller already uses to choose the body weight. An age under 16 is treated as
unknown, since the formula is for adults; so is one over 120, which can only
be a mistyped year.

When the term comes from a typed value, the breakdown row reads "Body fat
(measured)" and drops the "estimated from BMI" source the estimated row keeps.

### Screens

- **Add body weight dialog** and the **weight planner's** body inputs: an
  optional body fat % field (3 to 60). Under it, when weight, height, sex and
  birth year are all known, "Estimated: about 24%" (whole percent, clamped to
  the same range). A height left blank in the dialog falls back to the last
  one recorded. The dialog's field says it is optional, and when sex or birth
  year is missing a line under it says where to add them; the planner shows
  the estimate or nothing. The body weight list shows the value on entries
  that have one. The planner prefills the last recorded body fat and can save
  a typed one back to the profile with the weight.
- **Diver profile, Personal info page:** optional Sex (Female, Male, not set)
  and Birth year, with a line saying they are used only to estimate body
  composition for weight prediction. (The profile is a hub of sub-pages;
  there is no single edit page.)

## Build order

1. Schema, tables, entities, repositories, sync for both parts.
2. Bundle resolver and the set edit and detail pages.
3. Dive editor apply paths, then the unattended paths (bulk, rules, imports)
   with undo.
4. Dive planner, pre-dive checklist, trip gear.
5. Body composition model, then its screens.

## Calls made in writing this up

These were not decided in conversation and are open to correction:

1. Unattended paths never insert a cylinder into a dive that already has
   tanks; they only fill gaps. (The merge matches by role, and an imported
   tank with no inferred role is back gas, so inserting would add a duplicate
   deco cylinder beside the computer's own.)
2. Weights and tanks apply by the state of the dive on every apply, not only
   the first time a set lands. Re-applying a set fills a dive that has no
   weights.
3. A set absorbs a set it includes (the section above), and in the editor
   that replaces untouched weights without asking.
4. With weights already on the dive, the editor asks Add, Replace or Keep.
5. Nesting is limited to one level.
6. Bundle order is included sets first, then the set's own lists.
7. Dive planner cylinders are add-only, skipping an exact match.
8. Trip lead goes to the checklist the diver picks when there are several, and
   is skipped with a message when there is none.
9. A GPS re-match swaps weights only when they still equal what the old set
   filled in, and leaves the old set's cylinders in place.
10. A legacy scalar weight counts as the dive having weights.
11. The body fat estimate is shown only with all four inputs; an age under 16
    or over 120 counts as unknown; a typed value carries forward like height.
12. UDDF carries included-set references only; sex and birth year stay out of
    UDDF.
13. Computer-linked auto-apply counts gear that arrives through an included
    set.
14. Sex offers Female, Male and not set.

## Left to the builder

- Names of the resolver, tables' Dart classes and helper files.
- How rule runs record weight and tank changes for undo, following the shape
  `rule_run_changes` already has.
- The repository-level write for an unattended tank merge (the adapter is
  pure; today only the dive editor calls it).
- How the editor knows the starter tank is untouched, and the equivalent test
  for a plan's default tank.
- Picker details: filtering the set picker to eligible sets, and a picker for
  cylinder configurations if the existing menu cannot be reused.
- Exact wording of every new string, and where the Sex and Birth year fields
  sit on the profile page.
- Screens to capture before and after: set edit, set detail, set list tile,
  the dive editor's weights question, add body weight dialog, weight planner
  body inputs, diver profile edit, a pre-dive session started from a set, and
  trip gear after adding a set.
