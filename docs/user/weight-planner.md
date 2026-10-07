# Weight Planner

Most weighting advice is a table: so many kilos for a 5 mm wetsuit, add some for
an aluminium tank, add a bit more for salt water. It gets you in the water, and
then you spend the first ten minutes of the dive fixing it.

Submersion's **Weight Planner** starts from that table and then learns. Compose
the rig you plan to dive &mdash; gear, tanks, water type &mdash; and it predicts
how much lead you will need *and where to put it*, based on what you have
actually carried on your own dives.

> [!TIP]
> <strong>Find it under Planning &rarr; Weight Calculator.</strong> It is also
> built into the dive planner as the <strong>Gear &amp; Weights</strong> card, so
> a plan carries its own weighting.

## Composing a Rig

The **rig composer** is the top half of the tool:

- **Gear** &mdash; add individual equipment items, or tap **Use set** to pull in a
  whole [equipment set](equipment.md) at once. Your exposure suit is the single
  biggest term, so start there.
- **Tanks** &mdash; add one or more tanks from your presets. Material and size
  matter: an aluminium cylinder is meaningfully buoyant when it is nearly empty,
  and that is exactly when you need to hold a stop.
- **Water type** &mdash; salt or fresh.
- **Body weight** (optional) &mdash; improves the prediction and is required for
  the highest confidence rating. **Save weight to profile** records it as a dated
  entry, so your weighting history stays meaningful as your body weight changes.

Every change updates the prediction immediately, and a chip shows what that
change cost you &mdash; *+0.5 kg vs previous rig* when you swap a 3 mm suit for a
5 mm one. Swapping gear to see the delta is the fastest way to use this tool.

## Reading the Prediction

The card at the top shows four things:

| Element | Meaning |
|---------|---------|
| **Predicted weight** | Total lead for this rig |
| **Confidence** | How much the prediction rests on your data rather than on defaults |
| **Based on N logged dives** | How many of your dives informed it |
| **Suggested placement** | How to split the total across belt, integrated pockets, trim, and backplate |

### Confidence

| Rating | Roughly means |
|--------|---------------|
| **High confidence** | At least 10 supporting dives, most of the rig's items seen before, your body weight known, and your history is consistent |
| **Medium confidence** | At least 3 supporting dives covering about half the rig |
| **Low confidence &ndash; estimate** | Not enough history yet; this is essentially the classic table |

Low confidence is not a failure &mdash; it is what a new logbook looks like. It
climbs as you log dives with weights recorded.

### Placement

Placement is predicted from how you have habitually distributed weight on recent
dives with the same exposure suit, then rounded to whole increments of your unit
(0.5 kg or 1 lb) so the suggestion is something you can actually assemble from
real weights.

### How this was calculated

Expand the breakdown to see each term and where its number came from:

| Source | Meaning |
|--------|---------|
| **measured from your dives** | Learned from your own weighting history |
| **from your gear specs** | The buoyancy you entered on that equipment item |
| **default estimate** | A type-based default, because nothing better is known yet |
| **physics** | Computed &mdash; tank buoyancy when near-empty, the salt/fresh water shift |

This breakdown is the honest part of the feature: it shows you exactly which
numbers are yours and which are guesses.

## How It Learns

The engine is a hybrid, not a lookup table and not pure statistics:

1. **Physics is computed, not learned.** Tank near-empty buoyancy and the
   water-density shift are calculated from cylinder specs and displaced mass.
2. **Those physics terms are subtracted from your history first.** What remains
   is what physics cannot explain &mdash; your body, your suit's real buoyancy,
   your habits.
3. **The remainder is fitted** across your dives, pulled toward sensible priors
   so that a single unusual dive cannot swing the answer.

Two consequences worth knowing:

- **A salt-only history still predicts fresh water sensibly**, because the water
  term is physics rather than something that had to be observed.
- **Recent dives count for more.** Older observations fade with a half-life of
  roughly two years, so a change in fitness, suit, or technique works its way in
  rather than being outvoted by a decade of old dives.

## Teaching It

Three things you record elsewhere make the prediction better:

### 1. Post-dive weighting feedback

At the bottom of a dive's weights section, **How was your weighting?** offers
**Felt right**, **Overweighted**, or **Underweighted** &mdash; and if you pick one
of the last two, *by about how much*.

> [!TIP]
> <strong>This is the single highest-value thing you can log.</strong> Without it,
> the model can only learn what you <em>carried</em>, not what you <em>needed</em>
> &mdash; and if you were consistently 2 kg heavy, it will faithfully learn to keep
> you 2 kg heavy. One tap after the dive fixes that.

### 2. Recording weight by type

Logging weights as typed entries (belt, integrated, trim, backplate, ankle)
rather than a single total is what makes placement prediction possible. A total
alone still trains the amount.

### 3. Equipment attributes

Buoyancy figures and attributes on your gear &mdash; a suit's thickness and style,
a BCD's type and rated lift, an item's measured buoyancy &mdash; feed the priors.
An explicitly entered buoyancy value outranks anything derived, which in turn
outranks a flat default.

This matters most when you have *no* history: a brand-new logbook or a
just-bought drysuit is predicted entirely from these attributes.

## Through the Dive

Below the prediction, **Through the dive** simulates net buoyancy over a square
profile you shape with two sliders (max depth and bottom time). It answers a
different question from "how much lead": *will this rig actually be holdable?*

| Readout | Tells you |
|---------|-----------|
| **Verdict** | Whether you would be buoyant, heavy, or neutral at the final stop &mdash; the moment that matters, with a near-empty tank |
| **Start of dive / End of dive** | Net buoyancy at both ends |
| **Buoyancy swing** | How much you change across the dive as gas leaves the cylinder |
| **Peak lift needed** | The most your BCD has to hold, flagged if it exceeds your wing's rated lift |
| **Min ditchable weight** | Whether you could still get positive by dumping what is actually droppable |

> [!TIP]
> <strong>Fixed weight is not ditchable weight.</strong> Backplate and trim weights
> are excluded from the "you can ditch" figure, because you cannot ditch them in an
> emergency. That distinction is the whole point of the min-ditchable check.

## In the Dive Planner

The **Gear & Weights** card in a dive plan runs the same prediction against the
gear and tanks attached to that plan, and shows the same through-the-dive
summary. **Use as planned weight** snapshots the predicted figure onto the plan,
so the plan carries its weighting alongside its depths and gases.

> [!WARNING]
> <strong>Plans assume salt water.</strong> A dive plan has no water-type field, so
> the Gear &amp; Weights prediction uses the salt-water baseline. For a fresh-water
> dive, use the standalone Weight Planner, where water type is an explicit control.

## After the Dive

A logged dive with a recorded profile gets a **Buoyancy** section in its detail
page: the same simulation run against what actually happened, including a
comparison of what you carried against what the model would have suggested, and a
what-if sheet for re-running the dive with different lead. That is where "why was
the last stop so hard to hold" gets answered.

## Limits

> [!WARNING]
> <strong>Always do a buoyancy check.</strong> This is a prediction from your
> history and from physics, not a measurement of you on the day. Wetsuits compress
> with age, weight belts get borrowed, and how you breathe on a given dive matters
> more than any model. Get in the water, hold a normal breath, and verify.

- Predictions need **recorded weights** on past dives. Dives logged without
  weights teach it nothing.
- Gear it has never seen is predicted from attributes and defaults; the first few
  dives with a new suit will move the number.
- The through-the-dive simulation uses a **square profile** you set with the
  sliders &mdash; a planning approximation, not your actual dive.

## See also

- [Equipment](equipment.md) &mdash; equipment items, sets, and the attributes that feed the priors
- [Planning & Calculators](planning.md) &mdash; the other planning tools, and the dive planner
- [Dive Logging](dive-logging.md) &mdash; recording weights and post-dive weighting feedback
- [Dive Profiles & Deco](dive-profiles.md) &mdash; the profile analysis the after-the-dive view builds on
- [Diver Profile & Multi-Diver](diver-profile.md) &mdash; body weight entries
