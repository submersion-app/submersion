# Planning & Calculators

Submersion's Planning area gathers the tools you use before a dive: a full dive
planner with saved plans, a quick decompression calculator, seven gas
calculators, a weight calculator, a surface-interval tool, and two live clocks
for flying after diving and your current oxygen load. Everything runs on your
device with no account or connection.

> [!NOTE]
> **Where to find it:** **Planning** in the navigation. The list starts with the
> **Dive Planner** and your three most recent saved plans, then the **Tools**.
> On a tablet or computer, tools open beside the list; the Dive Planner and Gas
> Calculators take the whole window.

> [!WARNING]
> These tools are for planning purposes only. Always verify their numbers
> against your training and dive on a dive computer. The decompression figures
> come from a software model (Bühlmann ZH-L16C with gradient factors) and can
> differ from what your computer shows.

<!-- screenshot: images/planning/hub.png: the Planning list with the dive planner, saved plans and tools -->

| Tool | What it answers |
|------|-----------------|
| **Dive Planner** | What does this whole dive look like: depths, gases, deco, gas use, and what if it goes wrong? |
| **Deco Calculator** | At this depth on this gas, how long is my no-stop time, and what do I owe if I stay? |
| **Gas Calculators** | What is my MOD, best mix, gas use, reserve, narcotic depth or gas density, and how do I blend trimix? |
| **Weight Calculator** | How much lead should I carry, and where? |
| **Surface Interval** | How long must I wait before my next dive? |
| **Flying after diving** | When can I fly? |
| **Current CNS/OTU load** | How much oxygen exposure am I still carrying? |

---

## Dive Planner

The dive planner builds a whole dive: you set the depths and times you intend,
choose your cylinders, and Submersion computes the ascent and every
decompression stop, then shows your runtime, gas use, oxygen exposure, and
what happens if the dive goes deeper, longer, or loses a gas.

<!-- screenshot: images/planning/dive-planner.png: dive planner with editor, chart and results -->

### Layout

On a wide screen the planner shows three panes side by side: the editor on the
left, the profile chart in the middle, and the results on the right. Either side
pane can be collapsed. On a phone the chart sits on top, with **Tanks**,
**Plan**, **Setup** and **Results** below it, and a button to view the chart full
screen.

The top bar shows the plan's name (tap it to rename) and a mode chip. Tap the
chip to switch between open circuit (OC), closed-circuit rebreather (CCR), and
semi-closed rebreathers (SCR and pSCR). On wider screens, chips for the gradient
factors and altitude jump straight to the matching settings.

### Tanks

Under **Tanks**, **Add Tank** opens a tank with a **Name**, **Volume (L)**,
**Start (bar)**, **O₂ %** and **He %**. Switch on **Also used as travel gas** for
a cylinder you breathe on the way down, and on a rebreather plan mark
**Bailout gas**. You do not pick a role: the planner works out back gas, deco and
stage cylinders from the gas and how it is used. **Saved tanks** keeps tanks you
reuse from plan to plan.

A new plan starts with one 11.1 L tank at 200 bar on air.

### Building the profile

Under **Dive Segments**, each segment is a point you want to reach: a
**Depth (m)**, a **Duration (min)**, and the **Tank / Gas** you breathe there. The
planner shows whether each one is a descent, a level stretch or an ascent, and
you can drag segments into a new order. You only describe the part of the dive
you choose; the ascent and the decompression stops are always computed.

You can also edit on the chart: drag a point to move it, double-tap to add one,
and right-click (or long press) for a gas menu. With a point selected, the arrow
keys change its depth (up and down) or its time by a minute (left and right),
and Delete removes it.

For a quick start, choose **Quick Plan** from the menu: give a depth (5 to
40 m, default 18) and a time (5 to 120 minutes, default 45), and it replaces the
segments with a simple square dive. **Plan as DPV mission** instead builds the
profile from a scooter route.

### Plan settings

**Plan Settings** (the **Setup** tab on a phone) holds the settings for the whole
dive:

| Group | Settings |
|-------|----------|
| **Decompression** | **GF Low** and **GF High** (10 to 100; a new plan starts from your settings, 50/85 by default), the **Last stop** depth (3, 4, 5 or 6 m), and **Air breaks** for long oxygen stops |
| **Rates** | **Descent rate** 18 m/min, **Ascent rate** 9 m/min, slower rates between and at shallow stops, and a **Final ascent rate (last 3 m)** of 1 m/min |
| **Gas** | **Bottom RMV** (15 L/min, with an offer to use your logged average), **Reserve** (50 bar, or 500 psi), and **Gas options**: deco RMV, a stress factor and problem-solving time for minimum-gas sums, the ppO₂ limits, and whether to treat oxygen as narcotic for this plan |
| **Environment** | Altitude, **Water type** (salt, fresh, or a custom salinity), and **Treat O₂ as narcotic**, which here changes your setting for every plan and calculator (the switch under **Gas options** applies to this plan only) |
| **CCR** | Low and high setpoints (0.7 and 1.3 bar from your settings) and the depth to switch between them (10 m) |
| **pSCR** | The pSCR ratio |
| **Contingencies** | **Extra depth** (5 m), **Extra minutes** (5), and a **Turn pressure rule**: none, all usable, halves, thirds or custom |
| **Gear & Weights** | The gear for the dive and a predicted lead weight; see [Weight Planner](weight-planner.md) |

> [!NOTE]
> A lower gradient factor is more conservative. See the [Glossary](glossary.md)
> for gradient factors, RMV, ppO₂ and the other terms used here.

### Reading the results

The results pane leads with **Runtime**, **NDL** (or **TTS** once the dive needs
decompression), **CNS** and the number of **Warnings**, and the same figures sit
as chips under the chart. The chart draws the ceiling, gas switches and stops.

- **Decompression Schedule** lists each stop's depth, duration, runtime and gas,
  or "No decompression required". Tap a stop to set a minimum time for it.
- **Gas Consumption** shows, for each tank, the gas used, the pressure left at
  the end, the turn pressure and the minimum gas.
- **Bailout (open circuit)**, on a CCR plan, works out the worst-case bailout:
  when it happens, how long the ascent takes, and whether your bailout gas
  covers it.
- **Contingencies** recompute the dive deeper, longer, and both, and with each
  deco or stage gas lost. Select one to preview it on the chart; every headline
  figure switches to it.
- **Range table** shows the time to surface if you go 3 or 6 m deeper or
  shallower, or 5 or 10 minutes longer or shorter. Red cells are dives you could
  not do as planned.

The planner warns about:

| Warning | When |
|---------|------|
| ppO₂ | Above your working limit (1.4 bar), or critical above your deco limit (1.6 bar) |
| Hypoxic gas | Breathing a gas whose oxygen partial pressure is below 0.16 bar at that depth |
| END | Above your END limit (30 m by default) |
| Gas density | Above 5.2 g/L, or critical above 6.2 g/L |
| CNS | At 80%, or critical at 100% |
| OTU | Above 300 for the dive |
| Gas supply | A tank running empty, a reserve broken, or a tank ending below its minimum gas |
| Missing gas | An open-circuit deco dive with no deco gas, or a CCR deco dive with no bailout gas |
| Diluent MOD | A diluent breathed deeper than its maximum operating depth |

### Saving, sharing and comparing plans

Tap the save button to keep a plan. The first save asks you to
**Name your plan**, suggesting a name from the site, depth and date. **Saved plans** (in the
menu, and on the Planning list) lets you open, rename, duplicate, share, import
and delete plans. A deleted plan can be restored with **Undo** for a few
seconds.

In **Saved plans**, **Compare** puts two or three plans side by side: their
profiles overlaid on one chart, with depth, runtime, TTS, deco and gas use for
each.

From the menu you can also:

- **Export slate (PDF):** a printable slate with the runtime table, gas plan,
  contingencies, range table and bailout.
- **Share plan file:** a `.subplan` file another Submersion user can import.
- **Reset Plan** or **Delete plan**.

### Plans and logged dives

- **Follow a dive** plans a repetitive dive: pick one of your last 30 dives, and
  the planner starts from the tissue loading that dive left, with the surface
  interval set to the time since it ended. The dive needs a recorded profile.
- **Replan this dive**, in a logged dive's menu, opens that dive in the planner.
  The results then compare the plan with what you actually did, and can show the
  original on the chart. A replan is discarded when you leave unless you save
  it.
- **Convert to Dive** turns the plan into a planned dive in your log, with its
  full computed profile, linked back to the plan. It is not offered for a plan
  with no segments or with critical warnings.

Your current plan stays as you left it while you move around the app.

---

## Deco Calculator

The deco calculator is a quick, single-screen alternative to the planner for a
square dive. Set the **Depth** (0 to 60 m, default 18), the **Bottom Time** (0 to
120 minutes, default 30), and the **Gas Mix**: Air, EAN32, EAN36, EAN50,
Tx 21/35 or Tx 18/45, or a custom trimix with 18 to 100% oxygen and up to 65%
helium. You can also set the altitude and water type.

The results update as you move the sliders: NDL, ceiling, TTS, GF99, surfacing
GF, any deco stops, and the loading of all 16 tissue compartments. A gas panel
shows the mix's MOD (at a ppO₂ of 1.4) and END, and warns when the depth is past
the MOD, the ppO₂ is too high, the END is too deep, or the mix is hypoxic.

The calculator uses the gradient factors from your settings (see
[Settings](settings.md)). **Add to Planner** carries the depth, time and gas to
the dive planner.

> [!WARNING]
> **Add to Planner** replaces the current plan's segments and its first tank's
> gas. Save the plan first if you want to keep it.

---

## Gas Calculators

Seven calculators for the gas arithmetic divers do by hand or on a slate.

<!-- screenshot: images/planning/gas-calculators.png: gas calculators -->

| Calculator | What it does |
|------------|--------------|
| **MOD** | The maximum operating depth of a mix for a ppO₂ limit, in three modes: recreational nitrox, open-circuit technical (including the minimum depth for a hypoxic mix), and CCR. Remembers your last inputs. |
| **Best Mix** | The richest nitrox you can breathe at a target depth for a ppO₂ limit of 1.2, 1.4 or 1.6, with the MOD of common mixes for reference |
| **Consumption** | The gas a dive at an average depth and time uses at your RMV, and what that leaves in your tank |
| **Rock Bottom** | The minimum gas to get you and a buddy to the surface from depth, using stressed breathing rates, a problem-solving time, and an optional safety stop. Turn the dive before you reach it. |
| **MND/END** | The maximum narcotic depth of a mix for your END limit, and its equivalent narcotic depth at any depth |
| **Gas Density** | The density of a mix at depth, open circuit or CCR, against the recommended limits |
| **Trimix blender** | The fill procedure for a trimix blend, with billing and a record of past fills |

The END limit and whether oxygen counts as narcotic come from your settings.
Adding helium pushes the MND deeper, which is why trimix is used for deep diving.

---

## Weight Calculator

The weight calculator predicts how much lead your rig needs and where to put it,
from your own weighting history, your gear and the physics of your tanks. It has
its own page: see [Weight Planner](weight-planner.md).

---

## Surface Interval

When you plan a second dive in a day, the surface-interval tool tells you how
long to wait. It models how your tissues off-gas at the surface and finds the
shortest surface interval that keeps the next dive within its no-decompression
limit.

Enter:

- **First Dive:** the depth (6 to 60 m), time (5 to 120 minutes) and gas of the
  dive you made.
- **Second Dive:** the depth, time and gas of the dive you plan.
- Your current surface interval, with the slider under the tissue chart (up to 4
  hours).

The tool shows the **Minimum Surface Interval**, whether your current interval
is already enough, and the **NDL for 2nd Dive** once you have waited. If no
wait of up to six hours makes the second dive a no-stop dive, it says so.

The **Tissue Recovery** chart plots all 16 compartments off-gassing, grouped into
fast, medium and slow tissues, with markers for now and for the minimum
interval.

> [!NOTE]
> This tool uses the Bühlmann ZH-L16C model with your gradient-factor settings.
> Its results are planning estimates and may differ from your dive computer,
> which is what you should follow between dives.

---

## Flying after diving

A countdown to when you can fly, from the DAN/UHMS guideline intervals for your
dives of the last 48 hours: 12, 18 or 24 hours after a single no-deco dive,
repetitive dives, or a deco dive (or 18, 24 or 48 hours with the Strict
setting). See [Safety](safety.md#flying-after-diving).

## Current CNS/OTU load

Your oxygen exposure right now. CNS decays with a 90-minute half-time and the
page updates every minute. OTU is shown against the daily limit of 300 and the
weekly limit of 850. When everything has cleared, it reads "No active load".

---

Your entries in the deco calculator, the gas calculators and the
surface-interval tool are kept while the app is open and reset when you restart
it, with two exceptions: the MOD calculator remembers its inputs, and the
Trimix blender keeps its fill gases, conditions and billing defaults (also in
**Settings > Manage > Trimix Mixer**). The
weight calculator starts fresh each time.
To keep a dive, save the plan or log it.

## See also

- [Logging Dives](dive-logging.md): record the dive you actually made
- [Dive Computers](dive-computer.md): download real profiles instead of planning by hand
- [Settings](settings.md): the gradient factors, ppO₂ limits and units these tools use
- [Glossary](glossary.md): MOD, END, MND, GF, ppO₂, RMV and the other terms used here
- [Safety](safety.md): flying after diving, the post-dive review, and the emergency card
- [Weight Planner](weight-planner.md): predicted lead and placement from your own weighting history
