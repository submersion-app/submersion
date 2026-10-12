# Insights and Records

Insights turns your logged dives into numbers and charts: an Overview of your
whole diving career, focused dashboards for deeper analysis, observations about
how your diving is changing, and a Dive Records page for your personal bests.
Everything is computed from the dives already in your log.

> [!NOTE]
> **Where to find it:** **Insights** in the navigation. On a phone you land on
> the list of dashboards; on a tablet or desktop the list sits beside the
> selected dashboard. The trophy button in the top bar opens **Dive Records**.

<!-- screenshot: images/statistics/overview.png: insights overview -->

## Choosing which dives count

Insights covers the active diver profile's dives (see
[Diver Profile & Multi-Diver](diver-profile.md)). To narrow it down, tap
**Filter insights** and choose any of the filters the dive list offers, such as
a date range, a site, a buddy, a trip or a tag. While a filter is on, a bar at
the top shows how many dives it matches, with **Clear filter** beside it.

The Insights filter is separate from the dive list's: filtering Insights does
not change what the dive list or the Dashboard shows, and the reverse.

Two things ignore the filter:

- **Observations** always look at your whole log, because they compare recent
  dives with older ones.
- Dives you have left out of statistics (see
  [Logging Dives](dive-logging.md)) never count. The Overview says how many
  are left out.

> [!TIP]
> The more you fill in when you log a dive (depth, time, water temperature,
> visibility, gas, buddies, equipment), the more of these dashboards have
> something to show. An empty card means that detail has not been logged yet.

## Overview

The **Overview** is the first item in the list.

### Observations

At the top of the Overview, **Observations** point out what is changing or worth
noticing, for example:

- trends in your SAC, RMV, depth, dive time, weight or how often you dive
- milestones in dive count and hours
- a new deepest or longest dive, a new country, a new species
- a long gap since your last dive
- your favourite site, a regular buddy, your busiest month
- fast ascents

**See all** opens the full list. From an observation's menu you can
**Dismiss** it, or choose **Don't show this kind** to stop that kind of
observation; **Muted kinds** lists what you have turned off and lets you
**Unmute** it.

### Career totals

| Card | What it shows |
|------|---------------|
| **Total Dives** | Your dive count |
| **Total Time** | Your time underwater |
| **Max Depth** | The deepest you have been |
| **Avg Depth** | Your average maximum depth |
| **Avg Dives / Month** and **Avg Dives / Year** | How often you dive |
| **Dives This Year** | Dives since 1 January |
| **Sites Visited** | Distinct [dive sites](dive-sites.md) |
| **Avg Water Temp** | Your average water temperature |

If you entered prior experience on your
[Diver Profile](diver-profile.md), **Total Dives** and **Total Time** include
it and show the split, for example "120 logged + 380 prior". A "Diving since"
line appears when you set the year you started.

### Personal records, sites and distributions

- **Personal Records:** your first, deepest, longest, coldest and warmest dives.
  Tap one to open the dive.
- **Most Visited Sites:** your top sites by number of dives.
- **Distributions:** your dives by depth range and by dive type.

## The dashboards

Each dashboard is a set of cards, most of them interactive charts. Trend charts
plot **Every dive** or a **Weekly average** or **Monthly average**, can add a
rolling average and an overall trend line, and let you choose the range shown.

| Dashboard | What you will find |
|-----------|--------------------|
| **Connections** | A map of how your buddies, sites and gear link through your dives |
| **Air Consumption** | SAC or RMV over time, gas mixes, consumption by tank role, and your best and highest consumption |
| **Progression** | Maximum depth and bottom time over time, dives per year, dives by suit thickness, and your cumulative dive count |
| **Dive focus** | A chosen group of dives and what they have in common (see below) |
| **Conditions** | Visibility, water type, site types, entry method, and water temperature over time, by month and by band |
| **Social** | Solo versus buddy dives, your top buddies, and your top dive centers |
| **Geographic** | Dives by country, by region and by trip |
| **Species** | Species spotted, your most common sightings, and the sites with the most variety |
| **Time Patterns** | Dives by day of week, time of day and month, and your surface intervals |
| **Equipment** | Your most used gear, gear exposure, condition findings, reported issues, and your weight trend |
| **Profile Analysis** | Average ascent and descent rates, time at depth ranges, and how many of your dives needed decompression stops |

> [!NOTE]
> **SAC** (surface air consumption) and **RMV** (respiratory minute volume) both
> measure how fast you breathe, scaled to the surface so dives at different
> depths compare. SAC is in pressure per minute, RMV in volume per minute. Lower
> is more efficient. See the [Glossary](glossary.md).

<!-- screenshot: images/statistics/gas-sac.png: air consumption dashboard -->

### Connections

Connections draws how your buddies, sites, trips, gear, species and dive
centers link through the dives they share. **Map** shows a whole kind-to-kind
map; **Around** centres on one entity and what it links to.

**Views.** The view button in the top bar switches between:

- **Graph**: the map itself.
- **Pairs**: one row per connection, with the dives the two share and the
  last and first shared dive.
- **Entities**: one row per entity, with its dives, how many entities it links
  to and its strongest connection.
- **Matrix**: a grid of shared dives between every pair. On a map of two kinds
  (buddies and sites, for example) one kind runs down the side and the other
  across the top.

Tap a column heading to sort a table, and again to reverse it. Tapping a row,
a cell or a heading selects that entity or pair, just as tapping the graph does.

**Layouts.** In the Graph view, the **Display** section of the **View** tab
chooses how nodes are arranged:

| Layout | Arrangement |
|--------|-------------|
| **Web** | Linked entities pull together (Map only) |
| **Radial** | The centre in the middle, the rest in rings (Around only) |
| **Circle** | Every entity on one ring, grouped by kind |
| **Columns** | One column per kind, busiest at the top |
| **Clusters** | Each group of entities that dive together in its own cluster |
| **Timeline** | Left to right by the year of each entity's first dive, one row per kind |

**Display options.** **Labels** shows names automatically as you zoom, on
every node, or not at all. **Node size** sizes each node by its dives or draws
them all the same. **Lines** draws connections by strength, all thin, or only
for what you select. **Hide unconnected** leaves out entities with no link on
the map. **Spacing** spreads the map out or packs it tighter. Connections
remembers these on this device.

**Moving a node.** With a mouse or trackpad, press on a node and drag it. On a
touch screen, press and hold a node, then drag. A moved node stays where you
put it until the map changes; **Lay out again** puts every node back.

### Dive focus

Dive focus shows what a group of your dives has in common. Build the group as
a sentence: "Show the **10** dives with the **best** **RMV**", or "Show the
dives with **RMV** **above** **15 L/min**". Fourteen metrics are available,
grouped as Gas (RMV, SAC, gas used), Depth and time (max depth, average
depth, bottom time, surface interval), Conditions (water temp, air temp,
visibility, altitude), Exposure (CNS at end, OTU) and Kit (weight). Gas
metrics offer **best** and **worst**; the others offer **lowest** and
**highest**. A threshold starts at your average for that metric.

**What stands out** lists the strongest differences between the group and
every dive that has the value: "All 10 were boat entries (64% of all your
dives)", "Average depth 2.1 m shallower (11.3 m vs 13.4 m)". The chart
below marks the group in the accent colour and draws your threshold as a
dashed line. **Full comparison** gives every factor with the group's value,
the value across all dives and the difference; rows that say nothing fold
behind **Show more factors**. **The dives** lists the group, five at a time,
and opens any dive you tap. Dive focus needs at least three dives to compare.

### Profile Analysis

Profile Analysis and Air Consumption work best with dives downloaded from a
[dive computer](dive-computer.md): detailed depth and pressure samples give far
better ascent-rate, time-at-depth and consumption figures than hand-entered
averages. Dives with no recorded or computable deco data are left out of the
deco rate, and the card says how many.

## Dive Records

Tap the trophy button at the top of Insights to open **Dive Records**: your
personal bests, each as a card that opens the dive.

| Record | The dive with the |
|--------|-------------------|
| **Deepest Dive** | greatest maximum depth |
| **Shallowest Dive** | smallest maximum depth |
| **Longest Dive** | longest runtime |
| **Coldest Dive** | lowest water temperature |
| **Warmest Dive** | highest water temperature |

Under **Milestones** are your **First Dive** and **Most Recent Dive**. Each card
shows the site, the date and the dive number. Records follow the Insights
filter, so you can see, for example, your deepest dive on one trip. Tap
**Refresh records** to recompute them.

<!-- screenshot: images/statistics/records.png: personal records -->

## See also

- [The Dashboard](dashboard.md): your home screen and its status chips
- [Diver Profile & Multi-Diver](diver-profile.md): prior experience for complete career totals
- [Dive Profiles & Deco](dive-profiles.md): the depth data behind Profile Analysis
- [Equipment](equipment.md): exposure and condition findings
- [Glossary](glossary.md): SAC, RMV, deco and other terms
