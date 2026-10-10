# Connections: display options, alternative views and node dragging

Issue: #3223 (part of #2321). Builds on the shipped Connections explorer (PRs #2454, #3006),
specified in `2026-09-25-connections-explorer-design.md` and
`2026-10-05-connections-explorer-story-design.md`.

## Goal

The explorer shows every map one way: a force-directed web in Map mode and a
radial layout in Around mode. Dense maps become a hairball, a pair map such
as "Who dives where" has no tidy arrangement, and there is no way to read the
numbers behind the picture. Dragging a node exists, but only behind a
long-press, only in Map mode, and nothing tells the diver it is there.

This change gives the diver:

1. Free node dragging that is discoverable with a mouse and works in both
   modes.
2. Four alternative layouts: Circle, Columns by kind, Clusters, Timeline.
3. Styling options: labels, node size, edges, hiding unconnected nodes.
4. A spacing control that spreads a map out or packs it tighter.
5. Three non-graph views of the same map: a Pairs table, an Entities table and
   a Matrix.

Everything ships in one pull request.

## Decisions

| Question | Decision |
| --- | --- |
| Scope | One PR: drag, layouts, styling, spacing, tables and matrix |
| How a drag starts | Mouse, trackpad and stylus: press on a node and drag. Touch: long-press, as today |
| How long a pin lasts | Until the map changes (graph, layout or spacing change, or Re-layout). Nothing is stored |
| Layouts offered | Map: Web (default), Circle, Columns, Clusters, Timeline. Around: Radial (default) plus the same four |
| Layout memory | A separate choice per mode |
| Styling options | Labels auto / all / off; node size by dives / uniform; edges weighted / thin / selected only; hide unconnected |
| Non-graph views | Pairs table, Entities table, Matrix |
| View switch | An app bar button with a menu: Graph, Pairs, Entities, Matrix |
| Where display settings live | A new Display section in the View tab, Graph view only |
| Persistence | Device only, with the last view; not inside saved maps or presets |
| Architecture | A separate `ConnectionsDisplay` state beside the view state (approach A) |

Rejected:

- Storing display settings inside saved maps. Saved maps and presets describe
  what is shown; display settings describe how. Keeping them apart means
  switching maps keeps the diver's display choices, and a display tweak never
  marks a preset as edited.
- Extending `ConnectionsViewState` with the display fields. Every constructor
  path in it (`applyPreset`, `applySavedMap`, `showMap`, `editMap`,
  `withSavedMaps`) would have to carry nine more fields, and every display
  tweak would rebuild everything that watches the view.
- A third-party graph layout package. The explorer's first spec chose its own
  engine; packages do not paint through our `CustomPainter` and none offer
  Columns by kind or Timeline in the form wanted here.
- Moving the highlight mode into the new display state. It already persists in
  the stored view JSON; moving it would need a migration of stored views for
  no user-visible gain.

## 1. Dragging

### Starting a drag

The canvas gains a drag recognizer limited to mouse, trackpad and stylus
pointers. It claims the gesture only when the press lands on a node, hit
tested with the existing `ConnectionsHitTester`; on empty canvas it declines,
so a press-drag there still pans. Touch keeps the existing long-press pickup,
so a finger landing on a node to pan the map still pans.

The mouse cursor shows `SystemMouseCursors.grab` over a node and
`SystemMouseCursors.grabbing` while dragging.

### While dragging

Picking a node up selects it, as long-press does today. The node follows the
pointer in graph space.

- In the Web layout its neighbours keep simulating around it (today's
  behaviour through `ForceLayout.pin`).
- In every other layout (Radial, Circle, Columns, Clusters, Timeline) nothing
  else moves. The node goes where it is dropped and its edges follow.

### After the drop

The node stays pinned until any of these release every pin:

- a new graph (kinds, filters, year, budget, mode or centre change),
- a layout switch,
- a spacing change,
- the Re-layout button.

Nothing is stored.

### Around mode

Dragging works in Around mode; today `ConnectionsLayoutController.moveNode`
silently does nothing there. The app bar's Re-layout button, which today only
shows in Map mode, also shows in Around mode while at least one node is pinned,
so the diver can undo an arrangement.

### Accessibility

Dragging is spatial only. The canvas Semantics label already names the
selection; it does not change.

## 2. Layouts

`ConnectionsLayout` enum: `web`, `radial`, `circle`, `columns`, `clusters`,
`timeline`.

| Mode | Offered | Default |
| --- | --- | --- |
| Map | web, circle, columns, clusters, timeline | web |
| Around | radial, circle, columns, clusters, timeline | radial |

Each static layout is a pure, deterministic Dart function in its own file
under `domain/layout/`, taking the nodes, edges, an optional focus and the
spacing multiplier, and returning a settled `LayoutFrame`.

### Circle

All nodes evenly spaced on one ring, ordered by kind (enum order), then dive
count descending, then label, so each kind forms a contiguous arc. The radius
grows with the node count so that adjacent nodes at the maximum node radius
never overlap. In Around mode the focus node sits at the centre of the ring
and the rest go on the ring.

### Columns by kind

One column per kind present, left to right in kind order. Within a column,
nodes run top to bottom by dive count, then label. A column with more than 25
nodes wraps into sub-columns of at most 25 so it stays on screen. In Around
mode the focus node's kind column comes first and the focus node tops it.

### Clusters

Groups come from the existing label propagation (`label_propagation.dart`),
the same groups the Groups highlight colours. Each group of two or more nodes
gets its own `ForceLayout` run to rest, and groups are packed side by side by
the existing `IslandPacker`, biggest first. Ungrouped nodes go in the grid
below, as the Web layout does today. Choosing Clusters does not switch the
highlight to Groups. Like Web, Clusters is a live layout: the group
simulations advance a bounded number of iterations per frame
(`WholeWebLayout` with the groups as its islands), so a 400-node map never
blocks a frame, and a dragged node's group re-settles around it. (Running
the simulations to rest in one pass measured up to 258 ms per graph change
at 400 nodes, which stalled year play.)

### Timeline

- X: the year of the node's first dive in the current scope. One band per
  year, from the earliest to the latest year present; empty years keep their
  band so distance reads as time.
- Y: one horizontal lane per kind present, in kind order.
- Within a year and lane cell, nodes stack by dive count, then label.
- In Around mode the focus node takes its place like any other node.
- Year labels along the top and kind lane labels on the left are painted in
  graph space, so they pan and zoom with the nodes. The layout returns their
  positions alongside the node positions (a `TimelineGuides` value carried on
  the frame), and the painter draws them only when the layout is Timeline.

This needs the node's first dive date. `ConnectionNode` gains
`firstDiveAt` (`DateTime?`, null only for nodes built outside the node SQL,
such as test fixtures; the timeline puts those in the earliest band). The
node SQL already groups member dives per entity; it adds
`MIN(d.dive_date_time) AS first_ms` beside `COUNT(DISTINCT d.id)`, decoded the
same way the edge SQL decodes `first_ms`. No new query, no schema change.

### Switching

Changing the layout morphs nodes from their current positions to the new
ones over the existing `kRefocusDuration` (450 ms) using `LayoutMorph`, and the
camera fits the result. A graph change while a static layout is showing
recomputes that layout and morphs to it too, so nodes glide rather than jump.

Year play keeps working in every layout: in a static layout each played year
recomputes the layout and morphs to it.

The share image paints whatever frame is showing, so it uses the current
layout and styling.

## 3. Styling and spacing

A new Display section in the View tab, below the highlight control, shown
only while the Graph view is active:

| Control | Options | Behaviour |
| --- | --- | --- |
| Layout | Choice chips, the current mode's options | Section 2 |
| Labels | Auto / All / Off | Auto is today's zoom threshold, low-zoom cap and collision thinning. All labels every node at any zoom with thinning off, accepting overlap. Off labels none except the selected and hovered node |
| Node size | By dives / Uniform | Uniform draws every node at 14 px radius, large enough for photos and initials; hit testing uses the same radius through `NodeMetrics` |
| Edges | Weighted / Thin / Selected only | Weighted is today's. Thin draws every edge 1 px at one opacity. Selected only draws an edge when it touches the selected node, is the selected edge, or (on desktop) touches the hovered node |
| Hide unconnected | Switch | Removes nodes with no edge on this map from the canvas. The summary block and insight strip still count the whole map |
| Spacing | Slider, Tight (0.6x) to Spread (2.0x), default 1.0x | One multiplier for every layout: force spring length, radial ring gap, circle radius, column and row gaps, timeline cell size, cluster gaps. Relayouts on release, not on each tick, and releases pins |

All of these persist on the device and apply to the share image. They affect
the Graph view only: the Pairs, Entities and Matrix views always list every
node and edge on the map, unconnected nodes included.

## 4. Pairs, Entities and Matrix views

The app bar gets a view button whose icon reflects the current view, opening a
menu: Graph, Pairs, Entities, Matrix. All four read the same loaded
`ConnectionGraph`, so mode, kinds, filters, the year slider, year play and the
node budget apply identically. All four share `connectionsSelectionProvider`:
selecting a row or cell fills the Details tab exactly as tapping the graph
does, and the selection survives switching views.

### Pairs table

One row per edge: A and B (each with its kind colour dot and icon), shared
dives, last shared dive. Wide layouts add the first shared dive. Default sort
is shared dives descending; tapping a column header sorts by that column, and
tapping it again reverses. Tapping a row selects that edge. Dates use the
diver's date format setting.

### Entities table

One row per node: name with its kind colour dot, dives, connections (degree on
this map). Wide layouts add the kind name, the strongest connection and the
first dive in scope (`firstDiveAt`). Default sort is dives descending;
sortable like the Pairs table. Tapping a row selects the node.

Both tables are virtualised lists with a sticky header row, so a 400-node map
scrolls smoothly on a phone.

### Matrix

- Axes: when the map has exactly two kinds and one link between them, rows are
  one kind and columns the other, with the kind that has more nodes as rows.
  Otherwise rows and columns are every node, ordered by kind, then dive count,
  then label: a symmetric grid with a blank diagonal.
- Cells show the shared dive count, shaded by strength, and are blank at zero.
- Row and column headers stay frozen while the grid scrolls both ways.
- A `CustomPainter` draws only the visible cells, so large maps stay fast.
- Tapping a non-empty cell selects that edge; tapping a header selects that
  node. The selected node's row and column are tinted.
- Screen readers get a summary label on the matrix (rows, columns, links); the
  tables are the accessible route to the individual numbers.

### Graph-only chrome

In the Pairs, Entities and Matrix views:

- the insight strip and legend overlays are hidden,
- the Share and Re-layout app bar buttons are hidden,
- the View tab's Display section is hidden,
- the year play pill stays,
- the hidden-node count and its Show all button move into a one-line header
  above the table or matrix,
- the existing empty states apply unchanged.

## 5. State, files and testing

### State

`ConnectionsDisplay` (`domain/views/connections_display.dart`), immutable,
Equatable, with `copyWith`:

| Field | Type | Default |
| --- | --- | --- |
| `view` | `ConnectionsViewKind` (graph, pairs, entities, matrix) | graph |
| `mapLayout` | `ConnectionsLayout` | web |
| `aroundLayout` | `ConnectionsLayout` | radial |
| `labels` | `LabelMode` (auto, all, off) | auto |
| `nodeSize` | `NodeSizeMode` (byDives, uniform) | byDives |
| `edges` | `EdgeMode` (weighted, thin, selectedOnly) | weighted |
| `hideUnconnected` | `bool` | false |
| `spacing` | `double`, clamped 0.6 to 2.0 | 1.0 |

`toJson` and `fromJson` fall back field by field to the defaults: an unknown
or missing value never fails the whole restore, the same rule
`ConnectionsViewState.fromJson` follows. A `mapLayout` of `radial` or an
`aroundLayout` of `web` (not offered in that mode) falls back to that mode's
default.

`connectionsDisplayProvider` is a notifier that restores from its own
SharedPreferences key, `connections_display`, and writes on every change,
with an injectable writer like the view notifier's.

Pins live only in `ConnectionsLayoutController`, in memory.

### Code changes

- `domain/layout/`: `circle_layout.dart`, `columns_layout.dart`,
  `cluster_layout.dart`, `timeline_layout.dart`, and `pinned_frame.dart`
  (applies pin overrides to a static frame). `ForceLayout`, `WholeWebLayout`
  and `RadialLayout` take the spacing multiplier.
- `ConnectionsLayoutController`: dispatches on the layout, morphs on a layout
  change, supports `moveNode` in static and radial layouts, exposes `hasPins`.
- Canvas: the mouse and stylus node-drag recognizer, the grab cursors, painter
  parameters for labels, node size and edges, and the timeline guides.
- Node SQL and `ConnectionNode`: `firstDiveAt`.
- New presentation files: `panel/display_section.dart`,
  `views/pairs_table.dart`, `views/entities_table.dart`,
  `views/connections_matrix.dart` with its painter,
  `views/view_mode_button.dart`, `views/table_header_bar.dart`.
- `connections_page.dart` (601 lines) has its graph-area builder split into
  its own file so the page stays well under the 800-line cap.
- ARB: new `connections_*` strings in English and all ten other locales (ar, de, es, fr, he, hu, it, nl, pt, zh).
- User docs: a Connections section in `docs/user/statistics.md` covering the
  views, layouts, display options and dragging.

### Testing (TDD)

- Unit tests per layout: deterministic positions, kind ordering, column wrap,
  Around focus placement, spacing scales distances, no NaN on 0, 1 or 2 nodes,
  timeline bands for gap years.
- `ConnectionsDisplay` JSON round trip and per-field fallback, including a
  layout not offered in its mode.
- Controller tests: morph on a layout change, `moveNode` in static and radial
  layouts, `hasPins`, every pin-release trigger.
- Widget tests: a mouse drag on a node moves it while a drag on empty canvas
  pans; a touch long-press drag still moves a node; Display section controls
  update the provider; the view menu switches views; table sorting and row tap
  selection; matrix cell and header taps select; graph-only chrome hidden in
  the non-graph views.
- Painter tests: labels Off and All, uniform node size, selected-only edges,
  timeline guides.
- SQL test: `firstDiveAt` respects the diver scope and the filters. The
  dive-stats scope census already covers the node SQL file.
- PR screenshots through throwaway goldens (launching the app from this
  harness hits the macOS TCC crash): before and after, light and dark, phone
  and desktop.
