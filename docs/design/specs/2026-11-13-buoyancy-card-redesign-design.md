# Make the Buoyancy card explain the dive and the lead

Date: 2026-11-13. Release: v1.8.5. Size: small change (one card, no model or
database change).

## Intent

The Buoyancy card on the dive details page is drab and hard to learn from. It
is a sentence, a single-colour line chart, a collapsed list and six grey
number tiles. A diver opening it wants two things:

1. **What did my buoyancy do during the dive, and why?**
2. **How much lead should I take next time?**

The model already computes the answers. Each sample carries the suit and tank
contributions separately, and `TwinOutputs.idealLeadKg` is the lead the model
would have had the diver carry. Neither is shown in a way a diver can read.

## Goals

- One section that shows net buoyancy through the dive and, for any moment
  under the cursor, the parts pulling the diver down and holding them up.
- A plain lead answer: what was carried, what the model suggests.
- Every figure appears once on the card.
- Works at half width (the card pairs with Weights on wide panes, which is
  about phone width) and in every theme preset, light and dark.

## Non-goals

- No change to the buoyancy model, the analyzer, the database or sync.
- No change to the Dive Planner, the Weight Planner or the Adjust (what-if)
  sheet. They keep `TwinSummaryRows` and their own verdict sentences.
- No new dive detail section. It stays one card, in the same slot and pair.

## Anti-goals

- The card must not state the same number in two places, or two numbers that
  should match but differ by rounding.
- The lead figure must not read as an instruction. It is what a model
  suggests, and the wording says so.

## Approaches considered

All three led with the lead answer and differed in how the dive is explained.

- **A. Annotated chart.** Today's chart with start, deepest point and final
  stop marked, plus two notes naming the causes (suit compression, gas
  breathed). Tells the story at rest and fits a narrow card. Least novel.
- **B. Three moments.** Lift and weight bars side by side for start, deepest
  and final stop. Easy to read, but three columns are cramped at half width
  and compete with the chart.
- **C. Live balance.** One bar, sinking parts on the left and lifting parts
  on the right, following the profile cursor. Most engaging and shows every
  part, but at rest it shows a single moment.

**Chosen: A and C, merged into one section**, with the lead answer after it
rather than before. The balance bar sits directly under the chart so the
cursor on the chart and the bar read as one instrument. B was dropped.

## Design

The card keeps its header (icon, title, Adjust, info button). Below it, in
order:

### 1. Through the dive (readout, chart, balance bar)

**Readout**, above the chart. A title-sized figure and a quieter qualifier
(the figure started as a 24-point headline, which outweighed the rest of the
card):

| State | Figure | Qualifier |
| --- | --- | --- |
| At rest | "1.2 kg heavy" | "at your final stop, about 5 m" |
| At rest, no profile | as above | "estimated at the 5 m safety-stop convention" |
| Scrubbing | "5.6 kg heavy" | "at 28 m, 12:40" |

"heavy" when net is below -0.5 kg, "buoyant" above +0.5 kg, otherwise "Close
to neutral" (the existing threshold). At rest the figure is
`verdict.netKg`, so it and the lead suggestion below can never disagree.

**Chart**, as today (both axes, tick labels, axis titles in the diver's weight
unit, dashed neutral line, buoyant and heavy tints, cursor sync with the
profile both ways), with these changes:

- Three marked points, labelled by name only: **Start** (first in-water
  sample), **Deepest** (greatest depth), **Final stop** (the verdict anchor;
  omitted when the anchor is the no-profile convention). Each is a dot on the
  line with a thin dashed rule up to its label at the top of the plot. If the
  Deepest label would collide with another label it is dropped and its dot
  stays.
- The heavy region is shaded in the tertiary hue and the buoyant region in
  the primary hue, matching the balance bar below. It was the theme's error
  red, which read as a fault and went brown on dark cards.
- The touch tooltip is removed. The readout and the bar now say what it said,
  without covering the line.
- With no cursor, the cursor line rests on the final stop.

**Balance bar**, directly under the chart. Captions "Pulling you down" (left)
and "Holding you up" (right) over a bar split at a centre line. The parts:

| Part | From |
| --- | --- |
| Lead | `input.leadKg` |
| Tanks | sum of the tank terms at that moment |
| Suit | suit term at that moment |
| Gear | static terms that are gear items |
| Body | static terms `personal`, `water` and the body-composition term |

- Each part sits on the side of its sign, so a near-empty aluminium tank can
  cross from down to up. A part within 0.05 kg of zero is not drawn.
- The scale is fixed for the whole dive (the largest side total across all
  samples), so only the parts that really change move while scrubbing.
- A segment shows "Name value" when it fits, the name alone when only that
  fits, and nothing when it is narrower still. Any part not shown in full is
  listed in a legend line under the bar, in the bar's own left-to-right
  order. Each segment has a tooltip and a semantic label.
- From the centre outward the order is lead, body, gear, suit, tanks: the
  constant parts first, so the parts that change never push them sideways.
- At rest it draws the verdict's terms. While scrubbing it draws that
  sample's `suitKg` and `tanksKg` with the constant parts.
- With fewer than two plottable samples there is no chart; the readout and
  the bar still show the rest state.

**Cause notes**, two quiet lines under the bar:

- "Suit squeeze cost {x} of lift at {depth}": suit lift at Start minus suit
  lift at Deepest. Wetsuits only; omitted when under 0.05 kg.
- "Gas breathed left the tanks {x} lighter": tank term at the last sample
  minus the first. Omitted when under 0.05 kg (no tanks, or closed circuit).

**Term breakdown** stays as the collapsed list it is today, under the notes.
It is the only place that shows each tank separately and where each figure
came from.

### 2. Lead for next time

- Title "Lead for next time" with a chip: "Well weighted" (net within
  0.5 kg), "Overweighted" (heavy), "Underweighted" (buoyant).
- Two figures with an arrow between: "You carried" (`input.leadKg`) and
  "Model suggests" (`idealLeadKg`).
- When no lead was recorded: "You carried" reads "Not recorded", the chip is
  hidden, and the existing no-lead hint stays.
- The weighting history strip moves here: its paired bars, legend and
  one-line summary, without its own title. Beside the figures when there is
  room, below them when there is not. Still hidden when there is no history.

### 3. Safety rows

Replaces the six tiles. Each row is an icon, a figure and a short qualifier.

| Row | Pass | Warn | Neutral |
| --- | --- | --- | --- |
| Peak lift needed | within the wing's rated lift | exceeds it | no wing lift recorded |
| Min ditchable weight | droppable lead covers it | it does not | n/a |
| Drysuit gas added | n/a | n/a | shown when above zero |

With no lead recorded, the ditchable row is neutral and gives its figure
alone. "You can ditch nothing" would be a warning about missing data, and the
no-lead hint already says what is missing.

Start, End and Swing tiles are gone: the chart and the gas note cover them.

### 4. Hints

Unchanged, at the bottom of the card.

## Other changes that follow

- The card's info sheet drops the swing term and its how-to-use line mentions
  scrubbing, within the sentence caps the info-sheet test enforces.
- The section's description in the dive detail layout settings changes from
  "Buoyancy through the dive, swing, ditchable weight" to name the lead
  answer instead of swing.
- New strings go into all eleven ARB files. The verdict sentences stay; the
  Weight Planner and the Adjust sheet still use them. Two strings retire with
  the code that used them: the hard-coded "5 m" convention line (its
  replacement takes the depth from the diver's units) and the tooltip's
  "Rig + lead" label.
- The Weight Planner user guide's "After the Dive" section describes the new
  card.

## Units

Every figure goes through `UnitFormatter`: weight, depth, volume. Labels that
carry a unit build it from the formatter's symbol.

## Left to the builder (my calls, open to correction)

- **Colours.** Sinking parts use the tertiary container pair and lifting
  parts the primary container pair, so the lifting side matches the chart's
  buoyant tint. Check on two surfaces and in light and dark screenshots.
- **Chip colours.** "Well weighted" uses the primary container; the other two
  use the tertiary container. Neither state is an error.
- **Structure.** `buoyancy_section.dart` is split: a pure helper in
  `lib/core/buoyancy/` that turns a result plus a moment into balance parts,
  and widgets for the through-the-dive section, the balance bar, the lead
  block and the safety rows. The chart, readout and bar share one cursor
  consumer so a scrub does not rebuild the lead block or the history.
- **Local cursor.** When the card has no dive to sync with, the section keeps
  the chart's own touch position so the readout and bar still follow it.
- **Testing.** Unit tests for the balance helper (sign sides, fixed scale,
  rest state equals the verdict). Widget tests for the rest and scrub
  readouts, the no-lead and no-profile states, the safety row states, and a
  732 px wide layout with no overflow.
