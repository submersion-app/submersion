# Connections explorer phase 3: the story

Issue: #2324 (part of #2321). Builds on phase 1 and revision 2 (PR #2454),
specified in `2026-09-25-connections-explorer-design.md`. That spec's
"Insight overlays and sharing (phase 3)" section was written for lenses; this
document replaces it for the current Map and Around modes.

## Goal

The explorer already lets a diver browse who and what their dives connect.
Phase 3 makes it tell a story: a strip of standout facts over the map, three
ways to colour it, a play button that grows the map year by year, and an image
of the map to share.

## Decisions

| Question | Decision |
| --- | --- |
| Where the insight strip lives | A scrolling row of tiles over the top of the canvas, on phone and desktop |
| Summary block | Counts only; its standout rows (most connected, strongest pair, closest) move to the strip |
| Around mode | Centre-relative tiles (closest, newest, drifting apart) plus most connected and groups |
| Groups | Label propagation over every node and edge in view, whatever the kinds |
| Groups tile | Shows the count; tapping it switches the highlight mode to Groups |
| Highlight control | Segmented button in the View tab under Map/Around, remembered with the view |
| Year play control | A play pill on the canvas, plus the same button beside the Filter tab slider |
| Year play mechanism | Each beat writes the filter's end date; the graph reloads through SQL |
| Share image | Whole map, clean (no selection, zoom or pan), current highlight colours, buddy photos and labels that fit |

Rejected for year play: slicing one loaded graph on the client (edge weights
and node dive counts as of an earlier year cannot be rebuilt from an edge's
`weight`, `firstDiveAt` and `lastDiveAt`), and preloading every year (N
queries before the first frame and a cache to invalidate).

## Domain (pure Dart, no Flutter imports)

### `domain/insights/graph_insights.dart`

`GraphInsights.of(ConnectionGraph graph, {NodeRef? focus})` returns an ordered
`List<InsightTile>`. A tile with no evidence is left out; the strip never shows
"none".

```dart
enum InsightKind {
  mostConnected, strongestPair, closest, newest, driftingApart, groups,
}

class InsightTile {
  final InsightKind kind;
  final GraphSelection? target;   // null for groups
  final NodeRef? node;            // mostConnected, closest
  final ConnectionEdge? edge;     // strongestPair, closest, newest, driftingApart
  final int value;                // degree, weight or group count
}
```

Map mode (`focus == null`), in this order:

1. **Most connected:** highest weighted degree; ties to more dives, then the
   label. Left out when the best degree is 0.
2. **Strongest pair:** first edge by `GraphSummary.strongestFirst`.
3. **Newest connection:** latest `firstDiveAt`; ties by `strongestFirst`.
4. **Drifting apart:** among edges of weight 2 or more, the oldest
   `lastDiveAt`; ties to the heavier, then `strongestFirst`.
5. **Groups:** the number of communities with two or more members (below).
   Left out when there are none.

Around mode (`focus != null`), in this order:

1. **Closest:** the focus's edge first by `strongestFirst`; the tile names the
   other end.
2. **Newest connection:** the focus's edge with the latest `firstDiveAt`.
3. **Drifting apart:** the focus's edges of weight 2 or more, oldest
   `lastDiveAt`.
4. **Most connected:** as in map mode, the focus excluded.
5. **Groups:** as in map mode.

`GraphSummary` keeps its `strongestFirst` comparator and loses
`mostConnected`, `mostConnectedDegree`, `strongest`, `closest` and
`closestWeight`; the Summary block becomes counts per kind, connections, and
"entities around" in Around mode.

### `domain/insights/label_propagation.dart`

`LabelPropagation.communities(ConnectionGraph graph, {int maxRounds = 20})`
returns `GraphGroups`:

- Every node starts with its own label (its `ref.wire`).
- Each round visits nodes in `ref.wire` order and updates in place
  (asynchronous propagation, which converges on two-kind graphs where the
  synchronous form oscillates). A node takes the label with the largest summed
  edge weight among its neighbours; ties go to the smallest label; a node with
  no edges keeps its own.
- It stops after a round with no change, or after `maxRounds`, returning the
  labels it has. Never an error.
- Groups of one get no group.
- Groups are ranked by size (largest first), then by smallest member wire, and
  numbered 0..n-1 in that order.

```dart
class GraphGroups {
  final Map<NodeRef, int> groupOf;   // only nodes in groups of 2+
  final int count;
}
```

### `HighlightMode`

`enum HighlightMode { byKind, groups, recency }` becomes a field of
`ConnectionsViewState` (default `byKind`), copied by every transition, carried
in `copyWith`, in `props`, and stored in the view JSON as `highlight` (its
name). A missing or unknown value reads as `byKind`.

## Presentation

### Insight strip (`widgets/insight_strip.dart`)

- A horizontally scrolling row of compact tiles across the top of the canvas.
  The phone legend and the hidden-nodes chip move below it.
- Each tile: an icon, a title ("Strongest pair") and a value ("Ana and Bo,
  23 dives"). Dates in "Newest connection" and "Drifting apart" format through
  `UnitFormatter.formatMonthYear`.
- Tapping a tile writes its `target` to `connectionsSelectionProvider`; the
  existing flow opens the Details tab, raises the phone sheet and lights the
  node or edge. The Groups tile sets the highlight mode to Groups.
- The page computes the insights and the groups once per laid-out graph
  (identity cached like `_localize`).
- Hidden while there is no canvas (loading with nothing held, error, empty,
  Around with no centre).

### Highlight modes in `ConnectionsPainter`

New painter inputs: `HighlightMode highlight`, `Map<NodeRef, int> groupOf`,
`List<Color> groupPalette`, `Color ungroupedColor`, and `DateTime?
newestEdgeAt`. `shouldRepaint` compares them.

- **By kind:** unchanged.
- **Groups:** a node's fill is `groupPalette[group]` for groups 0..7 and
  `ungroupedColor` (a grey) for later groups and nodes in no group. The kind
  icon glyph and photos stay, so kind is still readable.
- **Recency:** each edge's alpha is multiplied by a factor from 1.0 (the
  newest `lastDiveAt` in view) down to 0.15 (the oldest), linear in time.
  Nodes keep kind colours. With one distinct date every edge is 1.0.

The group palette is eight fixed colours chosen to read on both brightnesses
and on the share image's navy, defined in
`canvas/connection_group_colors.dart`.

### Highlight control and legend

- `panel/highlight_mode_control.dart`: a `SegmentedButton<HighlightMode>` in
  the View tab under the mode switch, writing through
  `connectionsViewProvider`.
- `ConnectionsLegend` follows the mode: kind dots (by kind), "Colour: group"
  with the palette swatches (groups), or a "Recent" to "Old" edge key next to
  the kind dots (recency). The Summary block keeps its kind dots.

### Year play

`providers/year_play_controller.dart`: a Riverpod `Notifier<YearPlayState>`
with `idle` and `playing(int year)`.

- **Start** (needs a year span of two or more years): the lower year is the
  filter's start year or the span's first. If the upper year is already the
  span's last, the upper year resets to the lower year first; otherwise play
  continues from the current upper year.
- **Beat:** writes `endDate = DateTime(year + 1, 12, 31)` (and the start date
  of the lower year) into `connectionsFilterProvider`. The next beat fires only
  when 1.2 seconds have passed and the graph for the year has finished loading
  (the page tells the controller when a load settles).
- **Stop:** pause leaves the slider where it is. Reaching the span's last year
  stops play and clears the dates when the lower year is the span's first (the
  whole span is no filter, as the slider already does). Play also stops on a
  view change, on a filter change it did not write itself, on a failed load
  (the existing reload-error card shows), and when the page is disposed.
- **Motion:** Map mode warm-starts the web layout from the previous frame
  (existing behaviour), so nodes grow and new ones bloom in. Around mode morphs
  the radial layout as a refocus does. With animations disabled, beats still
  advance and the layout snaps.
- **Controls:** `widgets/year_play_pill.dart` at the bottom left of the canvas,
  above the phone sheet, with play/pause and the range ("2014 to 2019"), shown
  when the span is two or more years. `YearRangeSlider` gains the same
  play/pause button and moves with play.

### Share image

`share/connections_share_renderer.dart` and
`share/connections_share_action.dart`.

- **Trigger:** a share icon in the app bar beside re-layout or show-whole-web,
  disabled while no canvas is shown.
- **Canvas:** a `ui.PictureRecorder` at 360 x 450 logical pixels, scaled 3x,
  encoded to a 1080 x 1350 PNG.
- **Background:** fixed deep navy `0xFF0F1E37` with light ink in every app
  theme; kind colours come from the dark-brightness accent palette so they read
  on navy.
- **Map:** positions from the layout controller's current frame, fitted with
  padding into the top 390 px. Drawn with `ConnectionsPainter` in the current
  highlight mode, with the canvas's decoded buddy photos and the usual label
  collision. No selection, hover, zoom or pan.
- **Caption** (bottom 60 px): line 1 is the map name (the preset's name, the
  saved map's name, "Around <centre>", or "Custom map"); line 2 is the date
  range then the node and connection counts. The range is
  `UnitFormatter.formatDateRange` of the filter's dates, or "All dives, <first>
  to <last>" over the log's year span.
- **App mark:** `assets/icon/icon.png` at 20 px with "Submersion",
  bottom right.
- **Delivery:** `showExportDestinationSheet`, then `saveAndShareFileBytes`
  for share or `saveImageToFile` for save (null means cancelled, a no-op).
  File name `submersion-connections-<yyyyMMdd>.png`.
- Nothing is uploaded; the image holds only what is on the map.

## Error handling

- A render or save failure shows a snackbar and logs the error.
- A failed load during year play stops play; the reload-error card offers
  retry.
- Label propagation that reaches its round cap returns its current labels.

## Testing

Tests are written first, task by task.

- **GraphInsights:** each tile in both modes; ties; empty graph; the weight-2
  floor for drifting apart; tiles left out without evidence; the focus never
  "most connected".
- **LabelPropagation:** two cliques joined by a bridge give two groups; a
  buddy-site bipartite graph converges; singletons get no group; the result is
  the same for shuffled node and edge order; ranking and numbering.
- **View state:** `highlight` round-trips through JSON; old JSON without it
  reads `byKind`; every transition keeps it.
- **YearPlayController** (fake async): the start rule; a beat waits for both
  the delay and the load; it stops at the last year and clears the full span;
  an outside filter change and a view change stop it; dispose cancels the
  timer.
- **Widgets:** strip tiles select their target and the Groups tile switches
  mode; the segmented control writes the mode; the legend per mode; the play
  pill's play, pause and range text; the Summary block shows counts only; the
  share action is disabled without a canvas, a cancelled save is a no-op, a
  failure shows the snackbar.
- **Painter:** group fills and grey overflow; recency alpha via the `paints`
  matcher.
- **Renderer:** the PNG is 1080 x 1350; the caption strings are asserted as
  composed text.
- **Localisation:** new `connections_*` keys in every ARB locale; the orphan
  key and diacritics guards stay green.

## Out of scope

Animated GIF or video export, community detection beyond label propagation,
centrality metrics, and sharing a saved map's definition.
