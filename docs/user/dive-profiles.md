# Dive Profiles & Decompression

Every dive that has sampled depth data &mdash; whether downloaded from a dive
computer or imported from a file &mdash; gets a **dive profile**: an interactive
graph of your depth over time, plus a stack of optional overlays and a full
decompression analysis the app recomputes from the samples. This page covers
reading the profile, the overlays and event markers available, the
decompression model behind the numbers, and how to handle dives with more than
one computer.

> [!NOTE]
> **Where to find it:** Open any dive from the [Dashboard](dashboard.md) or
> [Dive Logging](dive-logging.md) list to reach its detail page. The profile chart
> sits near the top, under the dive's summary. On the Dashboard, selecting a
> dive also shows a compact profile preview in the side panel.

<!-- screenshot: images/dive-profiles/profile-overlays.png — profile with overlays -->

## Reading the profile

The chart plots **depth on the vertical axis** (deepest at the bottom, surface
at the top) against **elapsed time on the horizontal axis**, in minutes. The
depth line is the heart of the profile; everything else layers on top of it.

The chart is fully interactive:

- **Touch or hover** anywhere on the curve to drop a read-out. A tooltip appears
  just below the chart showing the values at that instant &mdash; time, depth,
  and whichever overlays you have switched on. The same point is highlighted
  across the tissue views and the decompression panels below, so you can read
  one moment of the dive from every angle at once.
- **Zoom** with a pinch gesture, the mouse scroll wheel, or the **+** / **&minus;**
  buttons. Zoom runs from 1&times; (the whole dive) up to 10&times;. A small
  indicator shows the current zoom level.
- **Pan** by dragging once you are zoomed in.
- **Double-tap** to jump to 2&times; zoom, or to snap back to the full dive when
  already zoomed. The **fit-screen** button also resets the view.

If a dive has no sampled data &mdash; for example, a dive you logged by hand with
only a maximum depth and a duration &mdash; the chart area shows a short "no
profile data" message instead. You can draw a profile for such a dive in the
[profile editor](#editing-a-profile).

## Overlays

Beyond the depth curve, the profile can display a large set of overlays. Which
ones are offered depends entirely on what data the dive actually contains: an
overlay only appears as an option when the underlying data (or the analysis
derived from it) exists for that dive. A few common overlays sit inline above
the chart as quick toggles; the rest live behind the **tune** (sliders) button,
grouped into collapsible sections.

The inline quick toggles are **Depth** (always shown, as a reference), **Temp**,
**Pressure** (for a single-tank dive), and **Events**. Opening the tune menu
reveals the full set:

### Overlays section

| Overlay | What it shows |
|---------|---------------|
| **Heart Rate** | Beats per minute, when your computer recorded a heart-rate belt. |
| **SAC Rate** | Surface Air Consumption &mdash; your breathing rate normalised to the surface, derived from tank-pressure change. Shown in pressure-per-minute or volume-per-minute depending on your [SAC unit setting](settings.md). See [Glossary](glossary.md). |
| **Ascent Rate** | Colours the depth line by how fast you were ascending: green within limits, orange at the warning threshold, red past the critical threshold. See [Decompression model](#decompression-model) below for the thresholds. |
| **Gases** | A thin **gas timeline** strip drawn between the plot and the time axis, coloured by the gas in use (air, nitrox, oxygen, trimix) across the dive. |

### Markers section

| Marker | What it shows |
|--------|---------------|
| **Max Depth** | A marker at the deepest point of the dive. |
| **Pressure Thresholds** | Markers where tank pressure crossed configured thresholds (for example, turn or reserve pressure). |
| **Gas Switches** | Markers at each point where you switched to a different tank or gas. |

### Decompression section

| Overlay | What it shows |
|---------|---------------|
| **Ceiling** | The current decompression ceiling &mdash; the shallowest depth you may safely ascend to. Zero (no ceiling) for a no-stop dive. |
| **NDL** | No-Decompression Limit &mdash; how long you could remain at the current depth before incurring a mandatory stop. Reads `DECO` once you are in obligation. |
| **TTS** | Time To Surface &mdash; the modelled time to surface including any required decompression (and the recommended safety stop on a no-stop dive). |
| **CNS%** | Cumulative Central Nervous System oxygen-toxicity percentage, including any residual carried from earlier dives. |
| **OTU** | Cumulative Oxygen Tolerance Units accrued during the dive (pulmonary oxygen exposure). |

### Gas Analysis section

| Overlay | What it shows |
|---------|---------------|
| **ppO2** | Partial pressure of oxygen, in bar. |
| **ppN2** | Partial pressure of nitrogen, in bar. |
| **ppHe** | Partial pressure of helium, in bar &mdash; offered only on trimix dives. |
| **MOD** | Maximum Operating Depth for the current gas. |
| **Gas Density** | Breathing-gas density, in grams per litre. |

### Other section

| Overlay | What it shows |
|---------|---------------|
| **GF%** | The current gradient-factor value at depth (see below). |
| **Surface GF** | The gradient factor your tissues would be at if you surfaced right now &mdash; a running "how close to the limit am I" reading. |
| **Mean Depth** | The running average depth of the dive so far. |

Each abbreviation &mdash; NDL, TTS, CNS, OTU, GF, ppO2, ppN2, ppHe, MOD, SAC, MOD
&mdash; is defined in the [Glossary](glossary.md).

> [!TIP]
> The badge on the tune button counts how many optional overlays are currently
> on, so you can tell at a glance that extra curves are active even when the
> menu is closed. You can set which overlays are visible by default for every
> dive under [Settings](settings.md).

### Computer figures vs. calculated figures

For **Ceiling**, **NDL**, **TTS**, and **CNS%**, the toggle includes a small
**DC / Calc** switch. Many dive computers record their own ceiling, NDL, TTS,
and CNS values sample by sample during the dive; Submersion stores those
alongside the figures it calculates itself from the depth samples. The switch
lets you compare the two:

- **Calc** (the default) shows Submersion's own Bühlmann calculation.
- **DC** shows the values your dive computer recorded, when present.

The two can differ &mdash; your computer may use a different algorithm,
conservatism setting, or gas assumption than Submersion does. Seeing them side
by side is informative, not a sign that either is wrong.

## Event markers

Switching on **Events** draws vertical markers at notable moments, each with an
icon and a severity colour. Some events come straight from your dive computer or
the imported file; others Submersion detects itself by analysing the profile;
and a few you add by hand. Touch a marker's time to read its label and any
associated value in the tooltip.

The event types Submersion recognises are:

- **Ascent start** &mdash; the start of the final ascent.
- **Safety stop start / end** &mdash; entry into and exit from the safety-stop zone.
- **Deco stop start / end** &mdash; entry into and exit from a decompression stop.
- **Gas switch** &mdash; a change of tank or gas (carries the gas name).
- **Max depth** &mdash; the deepest point of the dive.
- **Ascent rate warning / critical** &mdash; the ascent exceeded the warning or
  critical rate (carries the rate in metres/min).
- **Deco violation** &mdash; the ceiling was breached.
- **Missed deco stop** &mdash; a required stop was skipped.
- **Low gas warning** &mdash; tank pressure fell below a low-gas threshold.
- **CNS warning / critical** &mdash; oxygen CNS load passed a threshold (carries the %).
- **High ppO2 / Low ppO2** &mdash; oxygen partial pressure went too high, or too
  low (a hypoxia risk, mainly relevant to rebreather diving). Carries the ppO2 in bar.
- **Setpoint change** &mdash; a closed-circuit rebreather setpoint change (carries
  the setpoint in bar).
- **Bookmark** and **Note** &mdash; points and notes you add yourself.
- **Alert** &mdash; a generic computer alert.

Each event carries a severity of **info**, **warning**, or **alert**, which sets
its colour, and a source of **imported** (from a file or computer download),
**computed** (auto-detected by the app), or **user** (added by you).

<!-- screenshot: images/dive-profiles/profile-events.png — event markers -->

## Decompression model

Submersion computes its own decompression analysis for every sampled dive using
the **Bühlmann ZH-L16C** algorithm with **gradient factors** &mdash; the same
family of model used by most modern dive computers and by desktop tools such as
Subsurface. This is what drives the calculated ceiling, NDL, TTS, gradient-factor
and tissue overlays, and the decompression panels below the chart.

How it works, in brief:

- **Sixteen tissue compartments.** The model tracks inert-gas loading in 16
  theoretical tissue compartments, each with its own nitrogen and helium
  half-time (from the fastest, a few minutes, to the slowest, several hours).
  Gas loading and off-gassing in each compartment is computed with the
  **Schreiner equation** as you move through the depth samples, gas switches and
  all.
- **Gradient factors (GF Low / GF High).** Gradient factors add conservatism on
  top of the raw Bühlmann limits. **GF Low** governs the first (deepest) stop and
  **GF High** governs the surfacing margin; the effective gradient factor is
  interpolated between them as you ascend. The app's default is **GF 50/85**;
  you can change both values under [Settings](settings.md). A lower pair is more
  conservative.
- **Ceiling, NDL and TTS.** The **ceiling** is the shallowest depth at which no
  compartment exceeds its gradient-factor-adjusted limit. The **NDL** is found
  by simulating continued time at the current depth until a stop would become
  required (using the GF-High surfacing target). **TTS** sums the modelled
  ascent and any required stop times to the surface; on a no-stop dive it still
  includes the recommended 3-minute safety stop at 5&nbsp;m (15&nbsp;ft) so the
  figure stays realistic.
- **Decompression stops.** When you are in obligation, the model builds a stop
  schedule at the configured increment (default 3&nbsp;m steps to a 3&nbsp;m last
  stop) and reports it in the decompression panel.

> [!WARNING]
> Submersion is a **logging and analysis** tool, not a dive computer or a dive
> planner. Its decompression figures are reconstructed *after* the dive from the
> recorded samples and your gradient-factor settings, and they may differ from
> what your computer showed you in the water. Never rely on these numbers to plan
> or conduct a dive &mdash; always dive your own computer and training.

### Ascent-rate thresholds

The **Ascent Rate** overlay colours the depth line against two thresholds,
applied to a short smoothed window of the ascent so brief blips do not dominate:

- At or below the **warning** rate (default **9&nbsp;m/min**, ~30&nbsp;ft/min):
  green.
- Above warning up to the **critical** rate (default **12&nbsp;m/min**,
  ~40&nbsp;ft/min): orange.
- Above critical: red.

Sustained stretches above the warning rate are also flagged as ascent-rate
**events**. Both thresholds are adjustable in [Settings](settings.md).

## Tissue loading

Below the chart, the decompression panels visualise inert-gas loading across all
16 compartments. Two views share the same data and stay in sync with the chart's
read-out cursor:

- **Tissue heat map** &mdash; a grid with one row per compartment (fastest at the
  top, slowest at the bottom) and time running left to right. Each cell's colour
  encodes that compartment's loading relative to ambient pressure at that moment,
  so you can watch on-gassing and off-gassing sweep across the tissues over the
  whole dive.
- **Stacked area chart** &mdash; the loading drawn as curves instead of a grid.
  In its compact form it shows the **leading** (most-loaded) compartment; expanded,
  it draws all 16 compartments at once with the leading one emphasised, against an
  M-value reference line.

A small grid / area-chart control switches between the two views. Hovering or
tapping either one shows a tooltip for the compartment under the cursor &mdash;
its number, percent loading, gradient factor at depth, nitrogen (and helium)
tension, and half-time &mdash; and moves the matching crosshair on the depth
profile. A separate **tissue saturation** bar view shows every compartment's
pressures for a single selected instant of the dive.

> [!TIP]
> The heat map offers two colour schemes &mdash; **Default**, a Subsurface-style
> palette familiar to users of that desktop tool, and **Thermal**, a cool-to-warm
> gradient that emphasises how close each tissue is to its limit. Choose one in
> [Settings](settings.md).

<!-- screenshot: images/dive-profiles/tissue-heatmap.png — tissue loading heatmap -->

### Stepping through the dive

The dive detail page also offers a **playback** mode that walks a cursor through
the dive over time, updating the depth read-out, the decompression panels, and a
compact tissue view as it goes &mdash; a quick way to replay how loading built up
and cleared across the dive.

## Multiple profiles per dive

If you record one dive on **more than one device** &mdash; say a primary computer
and a backup, or a computer plus a bottom timer &mdash; Submersion keeps each
device's profile and draws them together on the same chart so you can compare
them. Each computer's trace gets its own colour, and a toggle bar lets you show
or hide individual computers.

One profile is the **primary**. It is marked with a **Primary** badge, drawn as a
solid line (the others are dashed), and it is the profile used for the dive's
headline depth, duration, and the decompression analysis. The first profile
attached to a dive becomes primary automatically; you can promote a different
recorded profile to primary from the dive's data-source controls on the detail
page.

## Editing a profile

Submersion includes a dedicated **profile editor** for cleaning up a recorded
profile or drawing one from scratch. Editing is **non-destructive**: the original
samples are always preserved, and the edited version is stored as a separate,
primary profile that you can revert at any time.

Open the editor with the **Edit Profile** button while editing a dive (from the
dive's edit page). It opens as a full-screen page with a simplified chart and no
overlays, and offers four tools:

- **Select** &mdash; pick a time range to operate on (shift its depth, shift its
  time, delete it, or smooth just that segment).
- **Smooth** &mdash; apply a moving-average smoothing to flatten sensor jitter.
- **Outlier** &mdash; detect and remove spurious spikes. Outliers can also be
  surfaced as a suggestion on the dive detail page for you to apply on demand.
- **Draw** &mdash; place waypoints to draw a depth profile by hand, for dives
  logged without a computer.

A session **undo** stack lets you step back through your changes, and **restore
original** discards all edits and brings back the untouched recorded profile.
Because all the decompression and overlay figures are derived from the samples,
they are recomputed from whichever profile is current after an edit.

> [!TIP]
> Use **Draw** to give a hand-logged dive a believable shape, or **Outlier** and
> **Smooth** to tidy a noisy trace from an older computer &mdash; the original is
> always one tap away under **restore original**.

## See also

- [Dive Logging](dive-logging.md) &mdash; recording and editing the dives that own these profiles.
- [Dive Computer](dive-computer.md) &mdash; downloading dives and their sampled data.
- [Import / Export](import-export.md) &mdash; importing dives with profile samples from files.
- [Settings](settings.md) &mdash; gradient factors, ascent-rate and ppO2 thresholds, default overlays, and tissue colours.
- [Glossary](glossary.md) &mdash; definitions of NDL, TTS, CNS, OTU, GF, ppO2, SAC, and more.
- [Safety](safety.md) &mdash; the post-dive safety review built on this profile analysis.
