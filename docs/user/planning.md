# Planning & Calculators

Submersion's Planning hub gathers the tools you use *before* a dive: a full
multi-level dive planner, an interactive decompression calculator, a set of gas
calculators, a weight estimator, and a surface-interval tool for repetitive
diving. Everything runs on your device with no account or connection required.

> [!NOTE]
> **Where to find it:** Open **Planning** from the navigation rail (or the
> bottom navigation bar on a phone). On a phone you land on a list of the five
> tools; on a tablet or computer the hub uses a master-detail layout, with the
> tool list on the left and the open tool filling the rest of the screen.

> [!WARNING]
> These tools are for **planning purposes only**. Always verify their numbers
> against your training and run every dive on a dive computer. The decompression
> figures come from a software model (Bühlmann ZH-L16C) and can differ from what
> your computer shows. Submersion is not a substitute for a dive computer or for
> proper training.

<!-- screenshot: images/planning/hub.png — the Planning hub listing the five tools -->

## The five planning tools

The Planning hub opens to a list of five tools. The rest of this page covers
each one in the order you meet it:

| Tool | What it answers |
|------|-----------------|
| **Dive planner** | "What does this whole dive look like — depths, gases, deco, and gas use?" |
| **Deco calculator** | "At this depth on this gas, how long is my no-stop time, and what stops do I owe?" |
| **Gas calculators** | "What's my MOD, best mix, gas use, reserve, or narcotic depth?" |
| **Weight calculator** | "Roughly how much lead should I start with for this exposure suit and tank?" |
| **Surface interval** | "How long must I wait before my next dive?" |

> [!NOTE]
> Each tool keeps the values you enter while you move between them, but those
> values are **not saved** when you leave the Planning area or close the app —
> the planning tools are live calculators, not stored records. To keep a dive in
> your log, enter it through [Dive logging](dive-logging.md) instead.

---

## Dive planner

The dive planner is the most complete tool here. You build a dive out of
segments — descent, bottom, ascent, gas switches, and stops — choose your tanks
and gas mixes, and Submersion runs the whole profile through the decompression
model to show you the stops you owe, your runtime, and how much gas each tank
will use.

It is organized into three tabs:

- **Plan** — where you set everything up.
- **Results** — the decompression schedule and gas projections, with a badge
  showing how many warnings the current plan raises.
- **Profile** — a depth-versus-time chart of the dive you have built.

<!-- screenshot: images/planning/dive-planner.png — dive planner -->

### Quick start: the Quick Plan dialog

If you just want a simple square-profile dive, tap **Quick Plan** in the top bar.
Enter a **maximum depth** (5–40 m / 16–131 ft) and a **bottom time** (5–120
minutes), and Submersion builds a complete profile for you: a descent, the
bottom segment, an ascent, and a 3-minute safety stop at 5 m (16 ft). You can
then fine-tune any of those segments on the **Plan** tab.

### Plan settings

The **Plan Settings** panel at the top of the Plan tab holds the parameters that
apply to the whole dive:

- **GF Low / GF High** — the gradient factors that set how conservative the
  decompression model is, each adjustable from 10 to 100. Gradient factors (GF)
  scale how close the model lets your tissues approach their theoretical limits:
  a *lower* number is more conservative. They start from your app settings
  (**GF 50/85** by default). See [Glossary](glossary.md) for a fuller explanation.
- **SAC rate** — your surface air consumption (SAC), the volume of gas you
  breathe per minute at the surface, adjustable from 8 to 30 L/min. This drives
  the gas-use projections.
- **Altitude** — set this above sea level for an altitude dive; the planner
  accounts for the thinner atmosphere.
- **Dive site** — optionally attach a site from your [dive sites](dive-sites.md).

> [!TIP]
> If you do not know your SAC rate, Submersion can estimate it from dives you
> have already logged — see [Statistics](statistics.md). A realistic SAC is what
> makes the gas-consumption and reserve numbers meaningful.

### Tanks and gases

In the **Tanks** list you add one or more cylinders, each with:

- a **name**,
- a **volume** in litres,
- a **starting pressure** in bar,
- a **gas mix**, set by its oxygen (O₂) and helium (He) percentages, and
- a **role** — back gas, bottom deco gas, stage deco gas, or bailout.

A new plan starts with a single aluminium-80 (≈ 11.1 L) tank filled to 200 bar
on air (21% O₂). Add a second tank with a richer mix — for example EAN50 (50%
O₂, a nitrox blend) — and you can switch to it partway through the dive to
shorten your decompression.

### Segments

A dive is a sequence of **segments**, which you add, edit, reorder, and remove
in the **Segments** list. Each segment is one of:

- **Descent** — from one depth down to a deeper one, at a chosen rate (default
  18 m/min).
- **Bottom** — time held at a fixed depth.
- **Ascent** — up to a shallower depth, at a chosen rate (default 9 m/min).
- **Deco stop** — a fixed depth held for a set time.
- **Safety stop** — typically 3 minutes at 5 m (16 ft).
- **Gas switch** — change to another tank.

Because each segment carries its own start and end depth and its own tank, you
can build true **multi-level** profiles and switch gas at any point in the dive.

### Reading the results

Open the **Results** tab to see what your plan produces. The **Decompression**
section reports:

- **Runtime** — total planned time, including stops.
- **NDL / Status** — your remaining no-decompression limit (NDL), or **DECO**
  once the plan crosses into a decompression obligation.
- **TTS** — time to surface, the minutes needed to ascend and clear all stops
  from the deepest point.
- **Ceiling** — the shallowest depth you may safely ascend to right now.
- A **Decompression Schedule** listing each stop's depth, duration, and gas.

The **Gas Consumption** section shows, per tank, how much gas the dive uses, the
pressure remaining at the end, and how much of the tank that represents. If a
tank is projected to drop below its reserve, it is flagged.

Submersion also tracks your oxygen exposure across the dive — central nervous
system toxicity (CNS, shown as a percentage of the daily limit) and oxygen
tolerance units (OTU) — and raises a **warning** for anything worth your
attention: ppO₂ (the partial pressure of oxygen) above 1.4 bar or 1.6 bar, an
exceeded NDL, high CNS or OTU, an ascent rate that is too fast, a high
equivalent narcotic depth (END), a gas dropping below its minimum reserve, or a
depth beyond a gas's maximum operating depth (MOD). The warning count appears as
a badge on the Results tab.

> [!NOTE]
> The dive planner is a live planning tool. The **Save Plan** and **Convert to
> Dive** actions in the menu are not yet wired up — selecting them only
> acknowledges the action and does not store a plan or create a logged dive.
> Treat the planner as a worktable you recalculate as you experiment, and log
> the dive you actually make through [Dive logging](dive-logging.md).

---

## Deco calculator

The deco calculator is a faster, single-screen alternative to the full planner.
It answers one question instantly: for a square dive to a given depth on a given
gas, what is your no-stop time, and what do you owe if you overstay it?

Set three things with sliders:

- **Depth** (default 18 m / 59 ft),
- **Bottom time** (default 30 minutes), and
- **Gas mix** — pick a preset (Air, EAN32, EAN36, EAN50, or pure O₂) or open the
  advanced selector for a custom blend, including trimix (a helium–oxygen–nitrogen
  mix) with O₂ from 18–100% and He from 0–65%.

As you move the sliders, the results update live: your **NDL**, **ceiling**,
**TTS**, the tissue loading across all 16 model compartments, and any deco stops.
A gas panel shows the mix's MOD and END and warns you if your chosen depth
exceeds the MOD, if ppO₂ is too high, or if the mix is hypoxic (too little oxygen
to breathe safely at the surface).

The calculator uses the gradient factors from your **app settings** (see
[Settings](settings.md)), so it reflects your personal conservatism. When a result
looks useful, tap **Add to Planner** to carry the depth, time, and gas into the
full dive planner and keep building.

> [!TIP]
> Lower oxygen lets you go deeper before hitting the MOD but shortens your
> no-stop time; richer nitrox does the opposite. The deco calculator is a quick
> way to feel that trade-off before committing to a plan.

---

## Gas calculators

The Gas Calculators screen is a set of five tabbed tools for the gas-planning
arithmetic divers do by hand or on a slate. Each tab is independent; the
**refresh** button in the top bar resets them all to their defaults.

<!-- screenshot: images/planning/gas-calculators.png — gas calculators -->

### MOD — maximum operating depth

Enter a gas's **oxygen percentage** and a **ppO₂ limit** (1.2, 1.4, or 1.6 bar),
and the calculator returns the **maximum operating depth (MOD)** — the deepest
you may breathe that gas before its oxygen partial pressure becomes unsafe. As a
reminder: a *lower* oxygen fraction gives a *deeper* MOD but a shorter no-stop
time.

### Best Mix — ideal nitrox for a depth

The inverse of MOD. Give a **target depth** and a **ppO₂ limit**, and Submersion
returns the **richest oxygen percentage** you can safely breathe there — the
nitrox blend that maximizes your no-stop time without exceeding your oxygen
limit. A reference list shows the MOD of the common mixes (Air, EAN32, EAN36,
EAN40, EAN50, and pure O₂) at your chosen limit.

### Consumption — how much gas a dive uses

Enter an **average depth**, a **dive time**, your **SAC rate**, and a **tank
size**, and the calculator estimates the total gas the dive will consume, the
pressure that represents in your tank, and what would be left over — flagging the
case where the dive would exceed the tank's capacity.

### Rock Bottom — emergency reserve

The **rock-bottom** reserve is the minimum gas you must keep in hand to get both
you and a buddy safely to the surface from depth. Enter the **depth**, an
**ascent rate**, **your SAC** and a **buddy's SAC**, the **tank size**, and
whether to include a safety stop. Submersion applies elevated (stressed)
breathing rates, assumes both divers share one tank, and returns the pressure
and volume you should treat as your turn-around point. Turn the dive *before* you
reach it.

### MND/END — narcosis for deep and trimix dives

This tab handles gas narcosis, which matters most on deep air and trimix dives.
Set the mix's **oxygen** and **helium** percentages, your **END limit** (the
deepest narcotic effect you are willing to accept, default 30 m / 98 ft), and
whether to **treat oxygen as narcotic** (on by default, which is the more
conservative assumption). The calculator returns:

- the **maximum narcotic depth (MND)** — the deepest you can go on that mix
  before narcosis exceeds your END limit, and
- the **equivalent narcotic depth (END)** at any depth you set — the air-depth
  whose narcotic effect matches your mix there.

Adding helium to a mix pushes the MND deeper, which is exactly why trimix is used
for deep diving. See [Glossary](glossary.md) for MOD, END, MND, ppO₂, and the gas
abbreviations used here.

> [!NOTE]
> The Planning hub's summary still describes "four" gas calculators from an
> earlier release; the screen itself now has the five tabs above, including
> MND/END.

---

## Weight calculator

The weight calculator gives you a **starting** estimate for how much lead to
carry, so a checkout or weight check begins in the right neighbourhood rather
than from scratch. Choose:

- an **exposure suit** — No Suit, Rashguard Only, 3 mm Shorty, 3 mm Full Wetsuit,
  5 mm Wetsuit, 7 mm Wetsuit, Semi-dry Suit, or Drysuit;
- a **tank material** — aluminium, steel, or carbon fibre (or leave unspecified);
- a **water type** — salt, fresh, or brackish (or leave unspecified); and
- optionally your **body weight**.

Submersion combines a base figure for the suit's buoyancy with adjustments for
the tank, the water, and your body weight, and shows a recommended weight in your
preferred unit (with the other unit in parentheses). A breakdown explains where
the number comes from.

> [!WARNING]
> A calculator cannot replace an in-water weight check. Use this figure as a
> starting point, then confirm your weighting in the water — neutrally buoyant at
> a safety stop with a near-empty tank — and record what actually worked on the
> dive. Your gear and exposure suit live in [Equipment](equipment.md).

---

## Surface interval

When you plan a second dive in a day, the surface-interval tool tells you how
long to wait. It models how your tissues off-gas at the surface and finds the
**minimum surface interval** that keeps your planned next dive within its
no-decompression limit.

Enter three things:

- **First dive** — the **depth**, **time**, and **gas mix** (oxygen and helium
  percentages) of the dive you just made.
- **Second dive** — the planned **depth** and **time** of your next dive (modelled
  on air).
- **Current interval** — a slider, from 0 to 4 hours, for how long you have been
  on the surface so far.

The tool then shows:

- the **minimum surface interval** required before the second dive,
- whether your **current interval** is already enough (a green "safe to dive" or a
  red "not yet safe" indicator), and
- the **NDL for the second dive** once you have waited long enough — or "in deco"
  if that depth and time would put you straight into a decompression obligation.

A **tissue recovery chart** plots all 16 model compartments off-gassing over the
four-hour window, grouped into fast, medium, and slow tissues, with the leading
(most saturated) compartment highlighted. A **NOW** marker shows your current
interval and a **MIN** marker shows the minimum required, so you can see at a
glance how much longer you have to wait.

> [!NOTE]
> Like the deco calculator, this tool uses the Bühlmann ZH-L16C model with your
> gradient-factor settings. Its results are estimates for planning and may differ
> from your dive computer, which is the device you should actually follow between
> dives.

## See also

- [Dive logging](dive-logging.md) — record the dive you actually made
- [Dive computer](dive-computer.md) — download real profiles instead of planning by hand
- [Settings](settings.md) — set the gradient factors and units these tools use
- [Glossary](glossary.md) — MOD, END, MND, GF, ppO₂, SAC, and the other terms used here
- [Safety](safety.md) — flying after diving, the post-dive review, and the emergency card
- [Weight Planner](weight-planner.md) — predicted lead and placement from your own weighting history
