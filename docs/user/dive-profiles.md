# Dive Profiles & Decompression

Every dive that has sampled depth data, whether downloaded from a dive computer
or imported from a file, gets a **dive profile**: an interactive
graph of your depth over time, plus a stack of optional overlays and a full
decompression analysis the app recomputes from the samples. This page covers
reading the profile, the overlays and event markers available, the
decompression model behind the numbers, and how to handle dives with more than
one computer.

> [!NOTE]
> **Where to find it:** Open any dive from the [Dashboard](dashboard.md) or
> [Dive Logging](dive-logging.md) list to reach its detail page. The profile chart
> sits near the top, under the dive's summary. The Dashboard's **Recent dives**
> card also previews the latest dive's profile.

<!-- screenshot: images/dive-profiles/profile-overlays.png: profile with overlays -->

## Reading the profile

The chart plots **depth on the vertical axis** (deepest at the bottom, surface
at the top) against **elapsed time on the horizontal axis**, in minutes. The
depth line is the heart of the profile; everything else layers on top of it.

The chart is fully interactive:

- **Touch or hover** anywhere on the curve to drop a read-out. A tooltip shows
  the values at that instant: time, depth, and whichever overlays you have
  switched on. The same point is highlighted
  across the tissue views and the decompression panels below, so you can read
  one moment of the dive from every angle at once.
- **Zoom** with a pinch gesture, the mouse scroll wheel, or the **Zoom in** and
  **Zoom out** buttons. Zoom runs from 1&times; (the whole dive) up to 10&times;.
- **Pan** by dragging once you are zoomed in.
- **Reset zoom** returns to the whole dive.

If a dive has no sampled data (for example, a dive you logged by hand with only
a maximum depth and a duration), the chart area shows a short "no
profile data" message instead. You can draw a profile for such a dive in the
[profile editor](#editing-a-profile).

## Overlays

Beyond the depth curve, the profile can display a large set of overlays. Which
ones are offered depends on what data the dive actually contains: an overlay
only appears as an option when the underlying data (or the analysis derived from
it) exists for that dive.

The row above the chart is a **legend**: it lists, read-only, every metric
currently drawn, each with its line colour. To switch overlays on or off, tap
**More chart options** (the sliders button at the end of the legend). Its badge
counts the drawn metrics that did not fit in the legend row. The options are
grouped into sections:

### Overlays section

| Overlay | What it shows |
|---------|---------------|
| **Temp** | Water temperature. |
| **Pressure** | Tank pressure (on a multi-tank dive, choose tanks under **Tank Pressures**). |
| **Events** | Event markers (see [Event markers](#event-markers)); **Computed events** adds the ones Submersion detected itself. |
| **Heart Rate** | Beats per minute, when your computer recorded a heart-rate belt. |
| **Consumption** | Your gas consumption normalised to the surface (SAC), derived from tank-pressure change. Always shown as pressure per minute (bar/min or psi/min). See [Glossary](glossary.md). |
| **Ascent Rate** | Colours the depth line by how fast you were ascending: green within limits, orange at the warning threshold, red past the critical threshold. See [Ascent-rate thresholds](#ascent-rate-thresholds) below. **Ascent Rate Line** draws the rate as its own curve instead. |
| **Gases** | A thin **gas timeline** strip drawn between the plot and the time axis, coloured by the gas in use (air, nitrox, oxygen, trimix) across the dive. |

### Markers section

| Marker | What it shows |
|--------|---------------|
| **Max Depth** | A marker at the deepest point of the dive. |
| **Pressure Thresholds** | Markers where tank pressure crossed configured thresholds (for example, turn or reserve pressure). |
| **Gas Switches** | Markers at each point where you switched to a different tank or gas. |
| **Late gas switches** | Shades deco gas switches that came late or were missed. |
| **Photos** | Markers where photos and videos from the dive were taken. |

### Decompression section

| Overlay | What it shows |
|---------|---------------|
| **Deco stops** | The modelled decompression stops. |
| **Ceiling** | The current decompression ceiling: the shallowest depth you may safely ascend to. Zero (no ceiling) for a no-stop dive. |
| **NDL** | No-Decompression Limit: how long you could remain at the current depth before incurring a mandatory stop. Reads `DECO` once you are in obligation. |
| **TTS** | Time To Surface: the mandatory time to the surface, your ascent plus any required decompression stops. The recommended safety stop is not included. |
| **GTR** | Gas Time Remaining: how long you could stay at the current depth, at your recent consumption, before a direct ascent would leave only your reserve pressure. Blank while you have a deco ceiling. |
| **CNS%** | Cumulative Central Nervous System oxygen-toxicity percentage, including any residual carried from earlier dives. |
| **OTU** | Cumulative Oxygen Tolerance Units accrued during the dive (pulmonary oxygen exposure). |

### Gas Analysis section

| Overlay | What it shows |
|---------|---------------|
| **ppO2** | Partial pressure of oxygen, in bar. |
| **ppN2** | Partial pressure of nitrogen, in bar. |
| **ppHe** | Partial pressure of helium, in bar. Offered only on trimix dives. |
| **MOD** | Maximum Operating Depth for the current gas. |
| **Gas Density** | Breathing-gas density, in grams per litre. |

### Other section

| Overlay | What it shows |
|---------|---------------|
| **GF%** | The current gradient-factor value at depth (see below). |
| **Surface GF** | The gradient factor your tissues would be at if you surfaced right now: a running "how close to the limit am I" reading. |
| **Mean Depth** | The running average depth of the dive so far. |

**Tank Pressures** lists one pressure curve per tank on a multi-tank dive, and
**Display** holds two viewing options: **Keep overlays in view** and **Tooltip
follows cursor**.

Each abbreviation (NDL, TTS, GTR, CNS, OTU, GF, ppO2, ppN2, ppHe, MOD, SAC) is
defined in the [Glossary](glossary.md).

> [!TIP]
> You can set which overlays are visible by default for every dive under
> [Settings](settings.md).

### Computer figures vs. calculated figures

For the decompression figures, the toggle includes a small **DC** / **Calc**
switch. Many dive computers record their own ceiling, NDL, TTS,
and CNS values sample by sample during the dive; Submersion stores those
alongside the figures it calculates itself from the depth samples. The switch
lets you compare the two:

- **DC** (the default) shows the values your dive computer recorded, and falls
  back to Submersion's calculation where the computer recorded none.
- **Calc** shows Submersion's own Bühlmann calculation.

The two can differ: your computer may use a different algorithm, conservatism
setting, or gas assumption than Submersion does. Seeing them side by side is
informative, not a sign that either is wrong. Which one each figure starts on
is set under **Data Source Preferences** in [Settings](settings.md) (NDL, TTS,
CNS, Deco Stop and GTR source).

## Event markers

Switching on **Events** draws vertical markers at notable moments, each with an
icon and a severity colour. Some events come straight from your dive computer or
the imported file; others Submersion detects itself by analysing the profile;
and a few you add by hand. Touch a marker's time to read its label and any
associated value in the tooltip.

The event types Submersion recognises are:

- **Ascent Start**: the start of the final ascent.
- **Safety Stop Start** / **Safety Stop End**: entry into and exit from the safety-stop zone.
- **Deco Stop Start** / **Deco Stop End**: entry into and exit from a decompression stop.
- **Decompression Dive**: the dive went into decompression obligation.
- **Low No-Deco Time**: the no-decompression time ran low.
- **Gas Switch**: a change of tank or gas (carries the gas name).
- **Max Depth**: the deepest point of the dive.
- **Ascent Rate Warning** / **Ascent Rate Critical**: the ascent exceeded the
  warning or critical rate (carries the rate in metres per minute).
- **Deco Violation**: the ceiling was breached.
- **Missed Deco Stop**: a required stop was skipped.
- **Low Gas Warning**: tank pressure fell below a low-gas threshold.
- **CNS Warning** / **CNS Critical**: oxygen CNS load passed a threshold (carries the %).
- **High ppO2** / **Low ppO2**: oxygen partial pressure went too high, or too
  low (a hypoxia risk, mainly relevant to rebreather diving). Carries the ppO2 in bar.
- **Setpoint Change**: a closed-circuit rebreather setpoint change (carries
  the setpoint in bar).
- **Bookmark** and **Note**: points and notes you add yourself.
- **Alert**: a generic computer alert.

Each event carries a severity of **info**, **warning**, or **alert**, which sets
its colour, and a source of **imported** (from a file or computer download),
**computed** (auto-detected by the app), or **user** (added by you).

<!-- screenshot: images/dive-profiles/profile-events.png: event markers -->

## Decompression model

Submersion computes its own decompression analysis for every sampled dive using
the **Bühlmann ZH-L16C** algorithm with **gradient factors**, the same family
of model used by most modern dive computers and by desktop tools such as
Subsurface. This is what drives the calculated ceiling, NDL, TTS, gradient-factor
and tissue overlays, and the decompression panels below the chart.

How it works, in brief:

- **Sixteen tissue compartments.** The model tracks inert-gas loading in 16
  theoretical tissue compartments, each with its own nitrogen and helium
  half-time (nitrogen half-times run from 4 minutes in compartment 1 to 635
  minutes in compartment 16).
  Gas loading and off-gassing in each compartment is computed with the
  **Schreiner equation** as you move through the depth samples, gas switches and
  all.
- **Gradient factors (GF Low / GF High).** Gradient factors add conservatism on
  top of the raw Bühlmann limits. **GF Low** governs the first (deepest) stop and
  **GF High** governs the surfacing margin; the effective gradient factor is
  interpolated between them as you ascend. The app's default is **GF 50/85**;
  you can change both values under [Settings](settings.md), or pick a preset
  there: High 50/75, Medium 50/85 or Low 50/95. A lower pair is more
  conservative.
- **Ceiling, NDL and TTS.** The **ceiling** is the shallowest depth at which no
  compartment exceeds its gradient-factor-adjusted limit. The **NDL** is found
  by simulating continued time at the current depth until a stop would become
  required (using the GF-High surfacing target). **TTS** sums the modelled
  ascent and any required stop times to the surface. It is the mandatory time
  only: the recommended safety stop is reported separately, so TTS never drops
  as a dive moves into decompression.
- **Decompression stops.** When you are in obligation, the model builds a stop
  schedule at the configured increment (default 3&nbsp;m steps to a 3&nbsp;m last
  stop) and reports it in the decompression panel.

> [!WARNING]
> Submersion is a **logging and analysis** tool, not a dive computer or a dive
> planner. Its decompression figures are reconstructed *after* the dive from the
> recorded samples and your gradient-factor settings, and they may differ from
> what your computer showed you in the water. Never rely on these numbers to plan
> or conduct a dive; always dive your own computer and training.

### Ascent-rate thresholds

The **Ascent Rate** overlay colours the depth line against two thresholds,
applied to a short smoothed window of the ascent so brief blips do not dominate:

- At or below the **warning** rate (**9&nbsp;m/min**, ~30&nbsp;ft/min):
  green.
- Above warning up to the **critical** rate (**12&nbsp;m/min**,
  ~40&nbsp;ft/min): orange.
- Above critical: red.

Sustained stretches above the warning rate are also flagged as ascent-rate
**events**.

## Tissue loading

Below the chart, the decompression panels visualise inert-gas loading across all
16 compartments. Two views share the same data and stay in sync with the chart's
read-out cursor:

- **Tissue heat map**: a grid with one row per compartment (fastest at the
  top, slowest at the bottom) and time running left to right. Each cell's colour
  encodes that compartment's loading relative to ambient pressure at that moment,
  so you can watch on-gassing and off-gassing sweep across the tissues over the
  whole dive.
- **Stacked area chart**: the loading drawn as curves instead of a grid.
  In its compact form it shows the **leading** (most-loaded) compartment; expanded,
  it draws all 16 compartments at once with the leading one emphasised, against an
  M-value reference line.

A small grid / area-chart control switches between the two views. Hovering or
tapping either one shows a tooltip for the compartment under the cursor (its
number, percent loading, gradient factor at depth, nitrogen and helium tension,
and half-time) and moves the matching crosshair on the depth
profile. A separate **tissue saturation** bar view shows every compartment's
pressures for a single selected instant of the dive.

> [!TIP]
> The heat map offers two colour schemes: **Classic**, a Subsurface-style palette
> familiar to users of that desktop tool, and **Thermal**, a cool-to-warm gradient
> that emphasises how close each tissue is to its limit. Choose one in
> [Settings](settings.md).

<!-- screenshot: images/dive-profiles/tissue-heatmap.png: tissue loading heatmap -->

### Stepping through the dive

The dive detail page also offers a **playback** mode that walks a cursor through
the dive over time, updating the depth read-out, the decompression panels, and a
compact tissue view as it goes: a quick way to replay how loading built up
and cleared across the dive.

## Multiple profiles per dive

If you record one dive on **more than one device** (say a primary computer and a
backup, or a computer plus a bottom timer), Submersion keeps each device's
profile and draws them together on the same chart so you can compare them. Each
computer's trace gets its own colour, and the **SOURCES** bar above the chart
lets you overlay or hide each one. Hiding a computer also hides its temperature,
events and pressure curves.

One profile is the **primary**: drawn as a solid line (the others are dashed),
and the one used for the dive's headline depth, duration, and the decompression
analysis. The first profile attached to a dive becomes primary automatically.

The dive's **Data Sources** section compares the computers side by side in a
grid: **Max Depth**, **Avg Depth**, **Duration**, **Water Temp**, **CNS**,
**OTU**, **Deco Algorithm** and **GF**. Each source's menu offers:

- **Set as primary** to make that computer's profile the main one.
- **Split into separate dive** to move a profile that belongs to a different
  dive out into its own dive.
- **Separate combined dives** to undo a [combine](dive-computer.md).
- **Compare in 3D** to view the profiles in three dimensions.

To share a profile, use **Export Profile Image** on the dive: you can share it,
save it to Photos, or save it to Files.

## Editing a profile

Submersion includes a dedicated **profile editor** for cleaning up a recorded
profile or drawing one from scratch. Editing is **non-destructive**: every save
is kept as a **profile revision**, labelled with how it was made (**Computer
Import**, **Edit**, **Create**) and what changed (for example **Smooth entire
profile** or **Remove all outliers**). You can switch the dive back to any
revision, including the original download, at any time.

Open the editor with the **Edit Profile** button while editing a dive. It opens
as a full-screen page with a simplified chart and no overlays, and offers five
tools:

- **Select**: pick a time range, then shift its depth or time, delete it, or
  smooth just that segment.
- **Smooth**: apply **Light**, **Medium** or **Heavy** smoothing to flatten
  sensor jitter, to the whole profile or a selection.
- **Outlier**: **Detect** spurious spikes and remove them. Outliers can also be
  surfaced as a suggestion on the dive detail page for you to apply on demand.
- **Draw**: tap the chart to place waypoints, then **Generate Profile** to draw
  a depth profile by hand for a dive logged without a computer.
- **Trim**: trim the profile's endpoints, such as zero-depth samples recorded
  at the end.

**Undo** steps back through your changes before you save. Because all the
decompression and overlay figures are derived from the samples, they are
recomputed from whichever revision is current.

> [!TIP]
> Use **Draw** to give a hand-logged dive a believable shape, or **Outlier** and
> **Smooth** to tidy a noisy trace from an older computer. The original download
> is always kept as its own revision.

## See also

- [Dive Logging](dive-logging.md): recording and editing the dives that own these profiles.
- [Dive Computer](dive-computer.md): downloading dives and their sampled data.
- [Import / Export](import-export.md): importing dives with profile samples from files.
- [Settings](settings.md): gradient factors, ppO2 limits, data sources, default overlays, and tissue colours.
- [Glossary](glossary.md): definitions of NDL, TTS, CNS, OTU, GF, ppO2, SAC, and more.
- [Safety](safety.md): the post-dive safety review built on this profile analysis.
