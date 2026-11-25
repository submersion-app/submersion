# Weights and buoyancy: one card on the dive page

Status: approved 2026-11-25. Release: v1.8.6.

## Why

The dive page shows a Weights card and a Buoyancy card side by side (stacked
on a phone). The pair wastes space: the Weights card is a short list beside a
tall chart card, so the row is mostly blank on one side. The two also say the
same thing twice, because the Buoyancy card's "Lead for next time" block
already shows the lead the diver carried. They should be one card.

## Goals

- One card that holds the weights list and the buoyancy model.
- Less vertical and horizontal space than the two cards take today.
- Every case either card handles today still works: no model, no lead,
  model loading, editing.

## Non-goals

- No change to what the buoyancy model computes or how its sections read.
- No change to the weights editor.

## Anti-goals

- A diver who logs weights on a dive the model cannot run (gauge, apnea, no
  cylinders) must not lose the weights list.
- No empty card flashing while the model loads.

## Approaches considered

- **A. Weights become the Lead section.** The itemized list sits inside
  "Lead for next time", ending in the carried total beside the model's
  suggestion. Shows the carried lead once, but reworks the Lead block.
- **B. Weights list on top, Buoyancy below.** The weights list leads the
  card, then the Buoyancy content as it is today. Cheapest; the carried total
  appears in the list and again in "You carried".
- **C. Weights behind an expander.** The Lead block stays; the itemized list
  opens from an "N weights" link under the carried figure. Most compact, but
  the breakdown is hidden by default.

**Chosen: B** (Eric's pick).

## Design

### The card

- Title "Weights and buoyancy" (new string, all locales), waves icon. The
  header keeps the Buoyancy card's What if? button and info button, and gains
  the edit pencil while the dive is unlocked (it is a `RecordCardHeader`
  inside the `weights` edit card's frame).
- Top: the weights list exactly as the Weights card draws it today: typed
  weight entries, the legacy single weight when there are no typed entries,
  then lead carried as weights gear, marked "From equipment". A Total row
  follows only when there are two or more entries (builder's call: with one
  entry the row is the total).
- A divider, then the Buoyancy content unchanged: readout and chart (synced
  with the profile cursor), term breakdown, Lead for next time, safety rows,
  hints.

### Cases

| Weights recorded | Model has an outcome | Card shows |
| --- | --- | --- |
| yes | yes | list, divider, model |
| yes | no (cannot run, or loading) | list only |
| no | yes | model only (its "no lead recorded" hint explains) |
| no | no | nothing; the Add strip offers the card while unlocked |

While the model loads the list shows at once and the model part joins it when
the outcome lands.

### Editing

The card is the `weights` edit card. Unlocked, it no longer fades (the
`buoyancy` fade reason goes with the section). Opening it swaps the whole card
for the existing weights editor; Done returns to the read card, with the model
recomputed from the saved weights.

### Layout

The Weights + Buoyancy entry leaves `kDiveDetailSectionPairs`. The merged card
renders full width at every pane width.

### Settings

- `DiveDetailSectionId.weights` stays and is renamed "Weights and buoyancy"
  (name and description) in the dive-details sections settings.
- `DiveDetailSectionId.buoyancy` is removed. `sectionsFromJson` drops a saved
  `buoyancy` entry the way it drops the retired `reefHealth` id.
- A diver who had hidden Weights keeps the merged card hidden; a diver who had
  hidden only Buoyancy sees the model again inside the merged card. No stored
  settings are rewritten.

## Left to the builder

- Test updates: section counts, pair table and paired-layout tests, Buoyancy
  card tests, settings parsing of the retired id.
- The CLAUDE.md range checks: few and many weights, long weight and gear
  names, phone and desktop widths.
