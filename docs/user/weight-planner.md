# Weight Planner

Most weighting advice is a table: so many kilos for a 5 mm wetsuit, add some for
an aluminium tank, add a bit more for salt water. It gets you in the water, and
then you spend the first ten minutes of the dive fixing it.

Submersion's weight planner starts from that table and then learns. Compose the
rig you plan to dive (gear, tanks, water type) and it predicts how much lead you
will need and where to put it, based on what you have actually carried on your
own dives.

> [!TIP]
> **Find it under Planning > Weight Calculator.** It is also built into the
> dive planner as the **Gear & Weights** card, so a plan carries its own
> weighting.

## Composing a Rig

The rig composer is the top half of the tool:

- **Equipment:** tap **Add gear** for individual items, or **Use set** to pull
  in a whole [equipment set](equipment.md#equipment-sets) at once. Your exposure suit is the
  single biggest term, so start there.
- **Tanks:** tap **Add tank** for one or more tanks from your presets. Material
  and size matter: an aluminium cylinder is noticeably buoyant when it is nearly
  empty, and that is exactly when you need to hold a stop.
- **Water Type:** salt, fresh or brackish.
- **Body Weight (optional):** improves the prediction and is required for the
  highest confidence rating. **Save weight to profile** records it as a dated
  entry, so your weighting history stays meaningful as your body weight changes.
- **Height (optional):** with your body weight, gives your BMI. A higher BMI
  usually means more buoyant tissue and a little more lead, and the breakdown
  shows that term as **Body composition**.

Every change updates the prediction immediately, and a chip shows what that
change cost you, for example "+0.5 kg vs previous rig" when you swap a 3 mm
suit for a 5 mm one. Swapping gear to see the difference is the fastest way to
use this tool.

## Reading the Prediction

The card at the top shows four things:

| Element | Meaning |
|---------|---------|
| **Predicted weight** | Total lead for this rig |
| Confidence | How much the prediction rests on your data rather than on defaults |
| "Based on N logged dives" | How many of your dives informed it |
| **Suggested placement** | How to split the total across belt, integrated pockets, trim and backplate |

### Confidence

| Rating | Roughly means |
|--------|---------------|
| **High confidence** | At least 10 supporting dives, at least three quarters of the rig known from your history or gear specs, your body weight known, and your past dives agreeing with the model to within about 1.5 kg |
| **Medium confidence** | At least 3 supporting dives covering about half the rig |
| **Low confidence - estimate** | Not enough history yet; this is essentially the classic table |

Low confidence is not a failure; it is what a new logbook looks like. It climbs
as you log dives with weights recorded.

### Placement

Placement is predicted from how you have usually distributed weight on recent
dives with the same exposure suit, then rounded to whole steps of your unit
(0.5 kg or 1 lb) so the suggestion is something you can assemble from real
weights.

### How this was calculated

Expand **How this was calculated** to see each term and where its number came
from:

| Source | Meaning |
|--------|---------|
| **measured from your dives** | Learned from your own weighting history |
| **from your gear specs** | The buoyancy you entered on that equipment item |
| **default estimate** | A type-based default, because nothing better is known yet |
| **physics** | Computed: tank buoyancy when nearly empty, and the salt or fresh water shift |
| **estimated from BMI** | From your body weight and height |

This breakdown is the honest part of the feature: it shows exactly which numbers
are yours and which are guesses.

## How It Learns

The engine is a hybrid, neither a lookup table nor pure statistics:

1. **Physics is computed, not learned.** Tank buoyancy when nearly empty and the
   water-density shift are calculated from cylinder specs and displaced mass.
2. **Those physics terms are subtracted from your history first.** What remains
   is what physics cannot explain: your body, your suit's real buoyancy, your
   habits.
3. **The remainder is fitted** across your dives, pulled toward sensible priors
   so that a single unusual dive cannot swing the answer.

Two consequences worth knowing:

- **A salt-only history still predicts fresh water sensibly**, because the water
  term is physics rather than something that had to be observed.
- **Recent dives count for more.** Older dives fade with a half-life of about
  two years, so a change in fitness, suit or technique works its way in rather
  than being outvoted by a decade of old dives.

## Teaching It

Three things you record elsewhere make the prediction better.

### 1. Post-dive weighting feedback

At the bottom of a dive's weights section, **How was your weighting?** offers
**Felt right**, **Overweighted** or **Underweighted**, and if you pick one of
the last two, by about how much.

> [!TIP]
> **This is the single most useful thing you can log.** Without it, the model
> can only learn what you carried, not what you needed. If you were always 2 kg
> heavy, it will faithfully learn to keep you 2 kg heavy. One tap after the dive
> fixes that.

### 2. Recording weight by type

Logging weights as typed entries (**Weight Belt**, **Integrated Weights**,
**Trim Weights**, **Backplate Weights**, **Ankle Weights**) rather than a single
total is what makes placement prediction possible. A total alone still trains
the amount.

### 3. Equipment attributes

Buoyancy figures and attributes on your gear (a suit's thickness and style, a
BCD's type and rated lift, an item's measured buoyancy) feed the priors. An
explicitly entered buoyancy value outranks anything derived, which in turn
outranks a flat default.

This matters most when you have no history: a brand-new logbook or a just-bought
drysuit is predicted entirely from these attributes.

## Through the Dive

Below the prediction, **Through the dive** simulates your net buoyancy over a
square profile that you shape with two sliders, **Max Depth** and **Bottom
Time**. It answers a different question from "how much lead": will this rig be
holdable?

| Readout | Tells you |
|---------|-----------|
| Verdict | Whether you would be buoyant, heavy or neutral at the final stop, the moment that matters, with a nearly empty tank |
| **Start of dive** / **End of dive** | Net buoyancy at both ends |
| **Buoyancy swing** | How much you change across the dive as gas leaves the cylinder |
| **Peak lift needed** | The most your BCD has to hold, flagged if it exceeds your wing's rated lift |
| **Min ditchable weight** | Whether you could still get positive by dropping what is actually droppable |

> [!TIP]
> **Fixed weight is not ditchable weight.** Backplate and trim weights are left
> out of the ditchable figure, because you cannot drop them in an emergency.
> That distinction is the whole point of the check.

## In the Dive Planner

The **Gear & Weights** card in a dive plan runs the same prediction against the
gear and tanks attached to that plan, and shows the same through-the-dive
summary. **Use as planned weight** copies the predicted figure onto the plan, so
the plan carries its weighting alongside its depths and gases.

> [!WARNING]
> **The planned weight assumes salt water.** The through-the-dive summary follows
> the plan's water type, but the **Predicted weight** on the Gear & Weights card
> always uses the salt-water baseline. For a fresh-water dive, check the figure in
> the standalone Weight Calculator, where water type is an explicit control.

## After the Dive

A logged dive with a recorded profile gets a **Buoyancy** section in its
details: the same simulation run against what actually happened. **Weighting
history** compares what you carried with what the model would have suggested,
and **Adjust** re-runs the dive with different lead. That is where "why was the
last stop so hard to hold" gets answered.

## Limits

> [!WARNING]
> **Always do a buoyancy check.** This is a prediction from your history and from
> physics, not a measurement of you on the day. Wetsuits compress with age,
> weight belts get borrowed, and how you breathe on a given dive matters more
> than any model. Get in the water, hold a normal breath, and check.

- Predictions need recorded weights on past dives. Dives logged without weights
  teach it nothing.
- Gear it has never seen is predicted from attributes and defaults; the first
  few dives with a new suit will move the number.
- The through-the-dive simulation uses a square profile you set with the
  sliders: a planning approximation, not your actual dive.

## See also

- [Equipment](equipment.md): equipment items, sets, and the attributes that feed the priors
- [Planning & Calculators](planning.md): the other planning tools, and the dive planner
- [Logging Dives](dive-logging.md): recording weights and post-dive weighting feedback
- [Dive Profiles & Deco](dive-profiles.md): the profile analysis the after-the-dive view builds on
- [Diver Profile & Multi-Diver](diver-profile.md): body weight entries
