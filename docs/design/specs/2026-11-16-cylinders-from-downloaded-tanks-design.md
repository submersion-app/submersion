# Cylinders from a downloaded dive's tanks

Issue: #4494. Related: #800 (tanks, equipment cylinders and tank presets
workflow).

## Intent

A downloaded dive records its tanks, but nothing puts those cylinders into
Equipment. A diver who owns their cylinders has to type each one in by hand
before it can collect dives, service dates or fills. The request (alt_F4,
Sidemount-Forum #148) is to offer to create the cylinder items from the
dive's tanks, prefilled, linked to the tanks, and never as a duplicate of a
cylinder the diver already owns.

## Goals

- After a dive computer download, offer to create a cylinder item for each
  new dive's tank that no cylinder the diver owns matches.
- From any dive's Tanks card, offer the same for one tank, and offer to link
  that tank to a cylinder the diver already owns.
- A created or linked cylinder is linked to the tank
  (`dive_tanks.equipment_id`) and joins the dive's gear (`dive_equipment`),
  so its dive count, service clocks and the tank's check-in chip work.

## Non-goals

- Linking a download's tanks to an owned cylinder automatically. A rental
  AL80 would be credited to the diver's own AL80 (wrong dive count and
  service clock).
- Back-filling older dives in bulk, or a data-quality finding for tanks
  without a cylinder.
- Unifying tank presets with equipment (#800 gap 2) or changing the tank
  editor (its "My cylinders" pick keeps copying specs without linking).

## Anti-goals

- A prompt that a rental diver cannot get away from: no modal, no
  persistent finding, nothing that blocks finishing the download.
- Presenting a guessed spec as fact. A computer almost never reports a
  cylinder size; when it reports none, `applyDefaultPresetToTanks` fills the
  back-gas tank's volume, working pressure, material and preset name from
  the diver's default preset. So the diver must see and be able to edit the
  spec before anything is created.
- Offering the same cylinder once per dive. A trip of dives on one cylinder
  is one cylinder.

## Decided with the user

1. **Both entry points** (option 3): a card on the download summary, and a
   per-tank action on the dive's Tanks card.
2. **When an owned cylinder already matches, the summary stays quiet**
   (option 1): no card for that tank and no link written. Linking stays
   available from the per-tank action. Each owned cylinder covers one tank
   per dive (see Matching), so a second tank of the same spec is offered.
3. **Approach A** (below): a live check on the summary over the import's new
   dive ids, like "Match sites".
4. **Group by spec across the download.** One sheet row per distinct spec,
   not per tank per dive. The number of cylinders a row offers is the most
   tanks of that spec on any single dive (two sidemount AL80s on one dive
   offer two). A created cylinder is linked to every tank of that spec in the
   group and joins each of those dives' gear, so its dive count starts at the
   number of dives. The row says how many dives it covers, so a diver who
   rented on some of them can see it before confirming.
5. **A corrected spec is written back to the dive tanks.** When the diver
   edits volume, working pressure or material in the sheet, every tank that
   row covers takes the corrected values too, so SAC is right and the next
   download's matching works against the real cylinder. Tanks carrying the
   default-preset guess are listed, prefilled with that guess.

## Approaches

- **A. Live check on the summary (chosen).** A provider over the import's
  new dive ids returns the tanks no owned cylinder covers; the summary card
  and the per-tank action open one review sheet. Costs one query when the
  summary renders, which is small at download sizes. Stays correct if the
  diver adds a cylinder elsewhere before tapping.
- **B. Work it out during the import and add an Import note.** Import notes
  are fixed text plus a route, so they cannot host the editable sheet, and
  they go stale. Rejected.
- **C. A data-quality finding across all dives.** Stays open on every rental
  dive forever. Rejected for the anti-goal.

## Design

### Matching ("an owned cylinder matches this tank")

An owned cylinder is an equipment item of type `tank` for the active diver
(the same gear list the tank editor reads, shared gear included), with
status other than retired, sold or lost. Spares count here, unlike in the
pickers: a spare AL80 is still a cylinder the diver owns, and counting it
avoids a duplicate. Suit-inflation cylinders do not count.

A cylinder matches a tank when:

- both have a volume and they differ by less than 0.2 L (the tolerance
  `TankPresets` uses), and
- when both have a working pressure, they differ by less than 2 bar, and
- when both have a material, it is the same.

Special cases (builder's calls, marked as such):

- *Suit inflation.* A tank whose role is suit inflation matches only
  suit-inflation cylinders, and every other tank matches only cylinders that
  are not. A cylinder created from a suit-inflation tank gets
  `cylinder_use = suit_inflation`.
- *Twin sets.* An owned twin pair counts as a match for a tank whose volume
  is the pair's combined volume (the existing twin-pair volume rule, #4242),
  so a logged 24 L double is not offered as a new 24 L cylinder. Created
  items are always single cylinders.
- *One tank per dive.* An owned cylinder covers at most one tank on a dive,
  and a twin set covers one tank with both its cylinders, so one owned AL80
  on a sidemount dive with two AL80s leaves the second offered (decided
  2026-11-16 during review). A cylinder a tank of the dive is already linked
  to is in use on it. Cylinders are assigned as a maximum matching, so one
  recording no material does not take the tank a stricter one fits, and a
  twin set takes a leftover tank whenever the single cylinders can spare its
  two (a spare takes the stage, the set takes the doubles).

A tank with no volume matches nothing and is not listed on the summary card
(there is nothing to prefill). The per-tank action still works on it.

A tank that already has `equipment_id` is never listed and never offered
"Add to my gear".

### Download summary card

- Shown on `ImportSummaryStep` for a dive computer download, beside the
  existing nudges (Match sites, data-quality review), when at least one tank
  on the import's new dives (`UnifiedImportResult.importedDiveIds`) is
  unlinked and unmatched. Not for updated or consolidated dives, and not
  when the download went to another profile.
- Wording: "2 tanks aren't in your gear" with a Review button. One tank:
  "1 tank isn't in your gear".
- Passive: no dismissal state is stored. A rental diver sees it on each
  download that has unmatched tanks and can ignore it.

### Review sheet

One sheet serves both entry points.

```
 Add cylinders to your gear
 ----------------------------------------------
 [x] AL80 x2                 on 10 dives
     Name      [ AL80                ]
     Volume    [ 11.1 L ]  Working pressure [ 207 bar ]
     Material  [ Aluminum v ]
 [x] AL40                    on 3 dives
     Name      [ AL40                ]
     ...
 ----------------------------------------------
                    [ Cancel ]  [ Add 3 cylinders ]
```

- One row per group: the listed tanks of one spec (and one suit-inflation
  kind), with an include tick (default on), a name field, and editable
  volume, working pressure and material. It shows how many dives it covers
  and, when more than one, how many cylinders it makes ("x2"). Values are
  shown and entered in the active diver's units (volume in L or cu ft,
  pressure in bar or psi) and stored metric.
- Grouping key: volume rounded to 0.1 L, working pressure rounded to the
  nearest bar (or absent), material (or absent), and whether the tank is
  suit inflation. Builder's call.
- Prefill: the group's volume, working pressure and material. Name: the
  first tank's `tankName` if set; otherwise the preset matched by specs (its
  display name, for example "AL80"); otherwise a description such as
  "11.1 L steel". With several cylinders in a row, they are named
  "AL80 1", "AL80 2" and so on (builder's call).
- Several cylinders in one row: on each dive, the dive's tanks of that spec
  are linked in tank order to cylinder 1, 2 and so on.
- Confirming creates the ticked rows' items; the button says how many.
- From the per-tank action the sheet has one row with one tank on one dive.

### Per-tank action on the Tanks card

On each tank row of `CylindersCard`, an action opens a small menu. Like the
card's Assign button, it shows only when the dive is not offered for
unlock-to-edit, or is unlocked with nothing unsaved (#4527); it writes at
once, as Assign does. Builder's call, following the card's own rule.

For a tank without `equipment_id`:

- **Add to my gear**: the review sheet with that one tank.
- **Link to a cylinder I own**: the own-cylinder picker, with spares shown
  (matching counts spares, so the diver must be able to link to one) and a
  hint saying it links the tank rather than copying specs. Picking writes
  the link and the gear row. It does not change the tank's recorded specs.

For a tank with `equipment_id` (builder's call, so a wrong link can be
undone without deleting the cylinder):

- **Unlink cylinder**: clears `equipment_id` on that tank. The item stays
  in the dive's gear; the diver removes it there if it was not used.

The tank editor's "My cylinders" pick is unchanged (it copies specs and adds
gear, and does not link).

### What creating or linking writes

In one transaction, for each confirmed row:

1. Create the row's equipment items (create only): type `tank`, the active
   diver, the name, curated attributes `volume_l`, `working_pressure_bar`
   and `tank_material` (and `cylinder_use` for suit inflation), status
   active.
2. For every tank the row covers: set `dive_tanks.equipment_id` to its
   cylinder, and write the row's volume, working pressure and material onto
   the tank when the diver changed them in the sheet (decision 5), through
   a repository method that records the change for sync like any other tank
   edit. `updateDive` deliberately leaves `equipment_id` alone, so it needs
   its own write.
3. Add each item to the gear (`dive_equipment`) of every dive it was linked
   on, if it is not there.

Then one sync notification. Re-parse already keeps a set `equipment_id`
(`Value.absentIfNull` in `reparse_service.dart`), so the link survives a
re-download.

The attribute-building code in `PassportAdoptionService._specAttributes` is
moved somewhere both services can share it.

## Constraints

- Every displayed volume and pressure follows the active diver's unit
  settings.
- All new user-visible strings go through the ARB files.
- New tables or rungs: none expected. `dive_tanks.equipment_id` already
  exists with ON DELETE SET NULL.

## Left to the builder

- Names and locations of the provider, the service and the sheet widget.
- Exactly where the summary card sits among the existing nudges, and the
  per-tank action's affordance (icon button or overflow), following the
  card's existing styling.
- Whether the sheet reuses the tank editor's unit-aware fields or its own.
- Whether the summary card hides after the sheet completes (it should
  re-evaluate and disappear once nothing is left).
