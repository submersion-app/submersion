# Connections explorer

Issue: #2321 (umbrella). Phases: #2322 (the graph), #2323 (breadth), #2324
(the story).

## Problem

The log stores a rich web of relationships and shows none of it as a web.
Buddies link to dives through `dive_buddies`, gear through `dive_equipment`,
species through `sightings`, tags through `dive_tags`, dive types through
`dive_dive_types`, computers through `dive_data_sources`, and sites, trips,
centers and courses through columns on `dives`. Every surface that reads these
links flattens them: the Statistics Social page ranks top buddies, the buddy
detail page lists dives together, the site page counts dives.

Rankings answer "who is top" and filters answer "which dives match". Neither
shows structure. A diver cannot see which of their buddies know each other
through diving, who bridges two groups, where they dive with whom, which sites
are alike by the life seen there, or how their circle changed over the years.
There is also no picture of a diving life that a diver would want to share.

## Decisions

| Question | Decision |
| --- | --- |
| Purpose | Browse, insight and share, all three |
| Scope | Every dive-linked kind; curated lenses first, free pair picker too |
| Form factor | Phone-first responsive canvas; desktop gets hover and a side panel |
| Home | New movable top-level destination plus deep links from detail pages |
| Rendering | Own engine: pure-Dart layout, `CustomPainter`, no graph package |
| Data engine | One co-occurrence query shape over per-kind dive membership |
| Stats scope | Always applied, never optional |
| Filter | Dedicated `connectionsFilterProvider`, not shared with Statistics |
| Node budget | Yes, adaptive to width, with a hidden count |
| Whole-web layout | Force-directed, deterministic seeding, pinning, packed islands |
| Ego layout | Radial by kind |
| Diver as a node | No; the diver is implicit in every edge |
| Conditions | Filters, never nodes |
| Photos in nodes | Yes, buddy photos when the node is drawn large enough |
| Edge selection | Yes |
| Year slider | Yes, plus year play in phase 3 |
| Highlight modes | By kind, groups, recency |
| Share image | Offscreen paint, share or save, nothing uploaded |
| Delivery | Three PRs, one per phase issue |

## Questions the graph answers

- Who is my real dive circle, and which of my buddies know each other through
  diving with me? Which groups are separate?
- Who bridges my groups?
- Which pair do I always dive with together? Who have I drifted away from?
- How did my circle change over the years?
- Who taught me? (roles on `dive_buddies`, the course kind)
- Where do I dive with whom? Who are my travel buddies and who are my local
  buddies? Who was on which trip?
- Which sites are shared ground, and where do I dive alone?
- Which sites are alike by the species seen there? Where have I seen turtles?
- What gear do I actually dive together?
- Which centers do I use where, and who did I meet through them?

Two things the graph does not claim: conditions such as visibility and
temperature are continuous and stay filters, and "who introduced whom" is an
inference from bridges and first-dive dates, never asserted.

## Architecture

### Feature layout

```
lib/features/connections/
  data/
    connections_membership_sql.dart      per-kind (dive_id, entity_id) fragments
    connections_edge_sql.dart            the co-occurrence query builder
    connections_node_sql.dart            per-kind label, subtitle and count batches
    repositories/connections_repository.dart
  domain/
    entities/connection_kind.dart
    entities/connection_node.dart        ConnectionNode, NodeRef
    entities/connection_edge.dart
    entities/connection_graph.dart       ConnectionGraph and the node budget
    entities/connection_query.dart
    lenses/connection_lens.dart          ConnectionLens and the six built-ins
    layout/layout_frame.dart
    layout/force_layout.dart
    layout/radial_layout.dart
    layout/island_packer.dart
    layout/layout_seed.dart
    insights/graph_insights.dart         phase 3
    insights/label_propagation.dart      phase 3
  presentation/
    providers/connections_providers.dart
    providers/connections_filter_provider.dart
    providers/connections_lens_provider.dart
    providers/connections_selection_provider.dart
    providers/connections_layout_controller.dart
    pages/connections_page.dart
    canvas/connections_canvas.dart       gestures and viewport
    canvas/connections_painter.dart
    canvas/connections_hit_tester.dart
    canvas/label_collision.dart
    canvas/node_glyph.dart               circle, initials, photo
    widgets/lens_chip_row.dart
    widgets/kind_pair_picker.dart        phase 2
    widgets/connections_filter_action.dart
    widgets/year_range_slider.dart
    widgets/selection_card.dart          phone
    widgets/selection_panel.dart         wide
    widgets/connections_legend.dart
    widgets/hidden_nodes_chip.dart
    widgets/trimmed_nodes_sheet.dart     phase 2
    widgets/insight_strip.dart           phase 3
    widgets/highlight_mode_control.dart  phase 3
    share/connections_share_painter.dart phase 3
    share/connections_share_action.dart  phase 3
```

Every file stays under the repository's 800-line ceiling and most under 400.
Layout, insights and the domain entities import nothing from Flutter.

### Data engine

**One idea.** Two entities are connected when they share a dive. Every
relationship in scope is therefore the same query, parameterised by the two
entity kinds.

**ConnectionKind** enumerates the dive-linked kinds. Each kind declares a
membership fragment yielding `(dive_id, entity_id)` rows, the table that holds
its label, and how its subtitle is built.

| Kind | Membership fragment | Label | Subtitle |
| --- | --- | --- | --- |
| buddy | `SELECT dive_id, buddy_id AS entity_id FROM dive_buddies` | `buddies.name` | usual role, if unanimous |
| site | `SELECT id AS dive_id, site_id AS entity_id FROM dives WHERE site_id IS NOT NULL` | `dive_sites.name` | region and country |
| trip | `dives.trip_id`, same shape | `trips.name` | date range via `UnitFormatter.formatDateRange` |
| diveCenter | `dives.dive_center_id`, same shape | `dive_centers.name` | country |
| equipment | `SELECT dive_id, equipment_id AS entity_id FROM dive_equipment` | `equipment.name` | equipment type |
| species | `SELECT dive_id, species_id AS entity_id FROM sightings` | `species.common_name` | scientific name |
| tag | `SELECT dive_id, tag_id AS entity_id FROM dive_tags` | `tags.name` | none |
| diveType | `SELECT dive_id, dive_type_id AS entity_id FROM dive_dive_types` | `dive_types.name` | none |
| diveComputer | `SELECT dive_id, computer_id AS entity_id FROM dive_data_sources` | `dive_computers.name` | manufacturer and model |
| course | `dives.course_id`, same shape | `courses.name` | none |

Built-in dive types and species already have localisation paths in their own
features; the node query reuses those lookups rather than the raw column when
one exists.

**Edge query.** For kinds A and B:

```sql
SELECT a.entity_id AS source, b.entity_id AS target,
       COUNT(DISTINCT d.id) AS weight,
       MIN(d.dive_date_time) AS first_ms,
       MAX(d.dive_date_time) AS last_ms
FROM dives d
JOIN (<membership A>) a ON a.dive_id = d.id
JOIN (<membership B>) b ON b.dive_id = d.id
WHERE d.diver_id = ?
  AND <DiveStatsScope>
  [AND d.id IN (<buildFilteredDiveIdSubquery>)]   -- only when a filter axis is set
  [AND a.entity_id < b.entity_id]                 -- self-join lenses only
  [AND a.entity_id = ?]                           -- ego mode only
GROUP BY source, target
ORDER BY weight DESC
```

- `DiveStatsScope.and(...)` is always applied, so planned dives and dives
  excluded from statistics never form an edge. `gas` scoping is not used.
- The filter subquery is `buildFilteredDiveIdSubquery` from
  `lib/features/statistics/data/dive_filter_sql.dart`, exactly as Statistics
  applies it, and only when `filter.hasActiveFilters`.
- Self-join lenses (A equals B) are undirected and deduplicated by the
  `a.entity_id < b.entity_id` guard. Mixed lenses keep source as kind A and
  target as kind B.
- `COUNT(DISTINCT d.id)` makes duplicate junction rows harmless.
- `dive_date_time` is epoch milliseconds in the wall-clock-as-UTC frame the
  rest of the app uses; the domain converts once, at the edge of the
  repository.

**Node query.** Nodes are not derived from edges. For each kind in the lens
the repository selects every entity with at least one dive in scope and
filter, with its own distinct dive count:

```sql
SELECT m.entity_id, COUNT(DISTINCT d.id) AS dive_count
FROM (<membership>) m JOIN dives d ON d.id = m.dive_id
WHERE d.diver_id = ? AND <DiveStatsScope> [AND d.id IN (<filter>)]
GROUP BY m.entity_id
```

This is what makes an isolated buddy (many dives, always one-on-one) appear
as an island instead of vanishing, and a site with no buddy edges read as
"where I dive alone". Labels, subtitles and buddy photos are then fetched in
one batch per kind with `WHERE id IN (...)`.

**Ego variant.** The same edge query with `a.entity_id = :focus`, run once per
kind B the lens or picker asks for. The focus node is always present even when
the budget trims everything else.

**Node budget.** `ConnectionGraph.trimmed(budget)` keeps the top `budget`
nodes ranked by own dive count, then weighted degree, then id, and drops
edges touching a removed node. It reports `hiddenNodeCount`. The default
budget is 80 on compact width and 160 on wide layouts; "show all" raises it
to a hard ceiling of 400 and asks first above that.

**Domain model.** Pure Dart, immutable, with `copyWith` on the entities.

```dart
enum ConnectionKind { buddy, site, trip, diveCenter, equipment, species,
                      tag, diveType, diveComputer, course }

class NodeRef { final ConnectionKind kind; final String id; }   // "buddy:abc"

class ConnectionNode {
  final NodeRef ref; final String label; final String? subtitle;
  final int diveCount; final Uint8List? photo;
}

class ConnectionEdge {
  final NodeRef source; final NodeRef target; final int weight;
  final DateTime firstDiveAt; final DateTime lastDiveAt;
}

class ConnectionGraph {
  final List<ConnectionNode> nodes; final List<ConnectionEdge> edges;
  final int hiddenNodeCount;
  ConnectionGraph trimmed(int budget);
}

class ConnectionQuery {
  final ConnectionKind kindA; final ConnectionKind kindB;
  final DiveFilterState filter; final NodeRef? focus; final int nodeBudget;
}
```

`NodeRef` is the node identity everywhere (layout, selection, deep links) so
ids from different tables can never collide.

**Repository and providers.**

- `ConnectionsRepository` in `lib/features/connections/data/repositories/`
  follows the repository convention (`DatabaseService.instance.database`,
  `customSelect`). Methods: `loadGraph(ConnectionQuery)`,
  `diveYearSpan(diverId)` for the slider, and `watchConnectionsChanges()`, a
  debounced tick over `dives`, every junction table above and every label
  table. The file joins the list in
  `test/core/database/dive_stats_scope_census_test.dart`, and every aggregate
  over `dives` in it goes through `DiveStatsScope`.
- `connectionsRepositoryProvider`.
- `connectionsFilterProvider`, a `StateProvider<DiveFilterState>` of its own,
  following the Statistics and Explore precedent so the connections filter
  never bleeds into the dive list or Statistics.
- `connectionGraphProvider`, a `FutureProvider.autoDispose.family` keyed by
  `ConnectionQuery`. It watches `currentDiverIdProvider` and calls
  `ref.invalidateSelfWhen(repo.watchConnectionsChanges())`, which the
  provider tick guard requires.
- `connectionsLensProvider` holds the active `ConnectionLens` or custom pair
  and persists it under a device-local `SharedPreferences` key
  `connections_last_lens` (values: a lens id, or `custom:<kindA>:<kindB>`).
- `connectionsSelectionProvider` holds the selected `NodeRef` or edge pair
  and the focus, as UI state.

### Layout

All layout code lives in `domain/layout/`, imports nothing from Flutter, and
exposes one contract:

```dart
class LayoutFrame {
  final Map<NodeRef, Offset> positions;   // graph space
  final Rect bounds;
  final bool settled;
}
```

The painter only reads frames and never mutates layout state.

**Force layout** (`ForceLayout`) for the whole web:

- Fruchterman-Reingold style. Pairwise repulsion between all nodes, spring
  attraction along edges, a weak pull toward the centre, and a temperature
  that cools linearly to zero. The ideal edge length shrinks with the
  logarithm of the edge weight, so buddies who dive together often sit closer.
- The simulation is stepped by `advance(int iterations)`; the presentation
  layer runs a bounded number of iterations per frame from a `Ticker` until
  `settled` (maximum displacement below an epsilon or the cooling schedule
  finished). At the 160-node budget a step is a few thousand operations, so
  it stays on the UI isolate; the API is shaped so the whole run could move to
  `compute()` later without changing callers.
- **Deterministic seeding** (`LayoutSeed`): initial positions come from a
  random generator seeded by a hash of the sorted node refs, so the same
  graph lays out the same way on every device and in every test.
- **Pinning:** a node the user drags is pinned at its new position and the
  simulation moves the rest around it. `clearPins()` backs a "re-layout"
  action.
- **Warm start:** `ForceLayout.from(previousFrame)` seeds nodes that already
  have positions from the previous frame and places new nodes at the centroid
  of their neighbours (or on the seed circle when they have none). Phase 3's
  year play relies on this.
- **Islands** (`IslandPacker`): connected components are laid out
  independently, then packed largest first into rows without overlap, so a
  one-on-one buddy appears as a small island rather than being flung away.

**Radial layout** (`RadialLayout`) for ego mode: the focus sits at the
origin; neighbours are grouped by kind into contiguous arcs sized by count,
sorted by weight within an arc, on a ring per kind; a second ring opens when
an arc would exceed its angular budget. Neighbour-to-neighbour edges are
laid out as chords and drawn faintly.

### Canvas and interaction

`ConnectionsCanvas` composes three things: a viewport transform, a gesture
layer, and `ConnectionsPainter`.

**Painting.**

- Edges first: stroke width and opacity scale with weight (clamped ranges so a
  weight-200 edge does not become a wall). Selected edges and edges of the
  selected node draw at full strength; everything else dims when a selection
  exists.
- Nodes: circles whose radius scales with `diveCount` (square-root scaling,
  clamped), filled with the kind colour. Kind colours resolve through the
  `FeatureAccentColors` theme extension using each kind's home destination
  (buddy to `buddies`, site to `sites`, trip to `trips`, diveCenter to
  `dive-centers`, equipment to `equipment`, species to `species`, course to
  `courses`, diveType to `dives`, diveComputer to `transfer`), so both
  brightnesses and every theme preset are covered without a new palette. Tag
  nodes are the one exception: each is tinted with the tag's own stored
  colour, and the legend swatch for the tag kind uses the `connections`
  accent.
- Labels: drawn when the node's screen radius exceeds a threshold; at low
  zoom only the top nodes by dive count keep labels; `LabelCollision` hides
  labels whose rectangles overlap a higher-ranked label.
- `NodeGlyph`: a buddy with a photo gets it clipped into the circle once the
  screen radius exceeds a threshold; otherwise initials; other kinds show a
  small kind icon at large radius.
- `RepaintBoundary` around the canvas; the painter's `shouldRepaint` compares
  frame identity, selection, highlight mode and viewport.

**Viewport.** Fit-to-content on the first settled frame. Pan by drag, pinch to
zoom on touch, wheel and trackpad zoom on desktop, following the recogniser
and `Listener.onPointerSignal` arrangement proven in
`dive_3d_interactive_viewport.dart`. Zoom is clamped and the graph bounds
cannot be panned fully off screen.

**Hit testing** (`ConnectionsHitTester`): tap picks the nearest node whose
drawn radius plus a touch slop contains the point; failing that, the nearest
edge within a slop; failing that, empty canvas. Long-press then drag moves and
pins a node. Double-tap focuses a node (ego mode). Tap on empty canvas clears
the selection. Hover on desktop shows a tooltip with label and weight.

**Selection.** A selected node lights its edges and neighbours and dims the
rest. Details appear in `SelectionCard` (a draggable bottom card on compact
width) or `SelectionPanel` (a fixed right panel on wide width): label,
subtitle, dive count, top connections, and three actions:

- *Open* pushes the entity's detail route.
- *Focus* switches to ego mode on that node.
- *Show dives* sets `diveFilterProvider` to `DiveFilterState(diveIds: ...)`
  and goes to `/dives`, the hand-off `BuddySharedDivesSection` uses today.
  The dive ids come from a repository call scoped exactly like the graph.

Selecting an edge shows the pair and *Show dives* lists their shared dives.

**Legend and hidden count.** `ConnectionsLegend` lists the kinds in view.
`HiddenNodesChip` shows "N more not shown" when the budget trimmed the graph
and, from phase 2, opens `TrimmedNodesSheet`, a plain list of the trimmed
entities with the same three actions.

**Accessibility.** The canvas carries a `Semantics` summary (node and edge
counts, selected node label). Everything reachable by tap is also reachable
through the selection panel, the trimmed list and the insight strip, so a
screen reader user is never stuck inside the painter.

### Page, navigation, lenses and filters

**Route and destination.** `/connections` becomes a section root with
`name: 'connections'` and a `NoTransitionPage`, accepting query parameters
`lens`, `a`, `b` and `focus` (`focus` is a `NodeRef` string such as
`buddy:<id>`). A `connections` entry joins `kNavDestinations` with
`Icons.hub_outlined` and `Icons.hub`, a label and subtitle, and it is
movable. `FeatureAccentColors` gains `connections` in both palettes (light
`0xFF00838F`, a deep cyan; the dark entry follows the file's convention). The
destination tests (`nav_destinations_test`, `rail_destination_order_test`,
`nav_customization_page_test`) and `feature_accent_colors_test` are updated
for the new count.

**Lenses.** `ConnectionLens(id, kindA, kindB, icon, label)`; the six
built-ins are:

| Lens id | Kind A | Kind B | Phase |
| --- | --- | --- | --- |
| `circle` Dive circle | buddy | buddy | 1 |
| `where` Who dives where | buddy | site | 1 |
| `trips` Trips and people | buddy | trip | 2 |
| `life` Sites by marine life | site | species | 2 |
| `gear` Gear together | equipment | equipment | 2 |
| `centers` Centers and people | diveCenter | buddy | 2 |

`LensChipRow` shows them as choice chips. From phase 2 a *Custom* chip opens
`KindPairPicker`: two slots over every `ConnectionKind` (the same kind allowed
for a self-join) and the chosen pair is remembered through
`connectionsLensProvider`. Named, saved custom lenses are out of scope.

**Layout.** On compact width: app bar, chip row, canvas filling the body,
legend and hidden-count chip overlaid in a corner, selection as a bottom card,
filters in a bottom sheet. On wide width: canvas on the left and a fixed
side panel on the right holding lens, filter summary, legend, year range and
selection details. The breakpoint is the one `MasterDetailScaffold` uses.

**Filters.** `ConnectionsFilterAction` opens the existing `DiveFilterSheet`
with `filterProvider: connectionsFilterProvider`; the sheet already takes a
provider. `StatisticsFilterBar` gains a `filterProvider` parameter defaulting
to `statisticsFilterProvider` so the chips bar is reused rather than copied.
`YearRangeSlider` spans the diver's first to last dive year from
`diveYearSpan`, is hidden when the span is one year, and writes
`startDate` (1 January of the lower year) and `endDate` (31 December of the
upper year) into `connectionsFilterProvider`, so the date range shows as a
filter chip and clears like any other axis.

**Deep links.** Detail pages get an "Open in Connections" action:

| Page | Phase | Target |
| --- | --- | --- |
| Buddy | 1 | `/connections?lens=circle&focus=buddy:<id>` |
| Site | 2 | `/connections?lens=where&focus=site:<id>` |
| Trip | 2 | `/connections?lens=trips&focus=trip:<id>` |
| Dive center | 2 | `/connections?lens=centers&focus=diveCenter:<id>` |
| Equipment | 2 | `/connections?lens=gear&focus=equipment:<id>` |
| Species | 2 | `/connections?lens=life&focus=species:<id>` |

The action is a menu item in the page's existing overflow menu. It uses
`context.push` so Back returns to the detail page; the router test covers a
pushed section root with query parameters. Landing on a `focus` opens ego
mode with that node selected.

**Empty states.** No dives in scope: the standard empty view. A lens with
nodes but no edges still draws the islands. A lens with no nodes shows a
lens-specific message naming the data that feeds it; the buddy lenses point
to Settings, Data Tools, where legacy text buddies are converted to buddy
records, because those logs otherwise look mysteriously empty.

### Insight overlays and sharing (phase 3)

All of these are pure Dart over `ConnectionGraph` and unit-tested without a
canvas.

**Insight strip** (`GraphInsights`, `InsightStrip`): five tappable tiles over
the graph in view. *Most connected* (highest weighted degree), *strongest
pair* (heaviest edge), *newest connection* (edge with the latest
`firstDiveAt`), *drifting apart* (heaviest edge with the oldest `lastDiveAt`,
among edges with weight of at least two), *groups* (connected pieces with at
least two nodes). Tapping a tile selects that node or edge. Dates format
through `UnitFormatter`.

**Highlight modes** (`HighlightModeControl`): *by kind* (default colouring),
*groups* (deterministic label propagation, `LabelPropagation`: nodes visited in
ref order, ties broken by the smallest label, at most 20 rounds; applies to
self-join lenses and tints nodes by community), *recency* (edge opacity
scaled by the age of `lastDiveAt` relative to the newest edge in view).

**Year play.** The slider gains a play button that advances the upper year
one step per beat (about 1.2 seconds). Each step reloads the graph through the
filter and warm-starts the layout from the previous frame, so nodes grow and
new ones bloom in rather than everything jumping. Pause leaves the slider
where it stopped; changing lens or filter stops play.

**Share image** (`ConnectionsSharePainter`, `ConnectionsShareAction`): paints
the current lens with `ConnectionsPainter` into a `ui.PictureRecorder` at a
fixed portrait size and a 3x pixel ratio, on the app's deep-water background,
with a caption line (lens name, date range, node and edge counts) and a small
app mark. Delivery goes through `showExportDestinationSheet` with the two
existing paths: `saveAndShareFileBytes` for the share sheet and
`saveImageToFile` for a file, where a null result means the user cancelled.
Nothing is uploaded, and the image contains only names already on screen.

## Error handling

- A failed graph load renders the standard error view with a retry that
  invalidates `connectionGraphProvider`.
- A deep link whose `focus` no longer exists opens the lens unfocused and
  shows a snackbar.
- An unknown `lens` or kind in the query string falls back to the remembered
  lens.
- A non-finite coordinate in the simulation resets that node to its seed
  position and logs once; the frame is never painted with NaN.
- A share render failure shows a snackbar; a cancelled save is a no-op.
- Above the hard ceiling of 400 nodes, "show all" asks for confirmation and
  warns that layout may be slow.

## Performance

- Edge and node queries are grouped aggregates over junction tables indexed by
  `dive_id` (`idx_dive_buddies_dive_id`, `idx_dive_equipment_dive_id`,
  `idx_dive_tags_dive_id`, `idx_dive_data_sources_dive_id`, and the site,
  trip, center and course indexes on `dives`). `sightings` has no `dive_id`
  index today; phase 2 adds `idx_sightings_dive_id` as a schema rung when the
  species lens ships.
- Labels are fetched in one batch per kind.
- Layout runs a bounded number of iterations per frame; the painter repaints
  only when a frame, the selection, the highlight mode or the viewport changes.
- A loose benchmark test (160 nodes, 600 edges, 300 iterations) guards the
  simulation against regressions.

## Testing

Tests are written first, task by task.

**Repository** (real in-memory Drift database, the existing pattern):

- Edge weights, first and last times for a seeded set of dives and buddies.
- Self-join deduplication (one edge per unordered pair).
- Mixed lens direction (source is kind A).
- Planned dives and dives excluded from statistics form no edge and add to no
  count.
- Dives of another diver are ignored.
- The filter subquery is honoured (date range, tag, site).
- Isolated entities appear as nodes; the budget trims by dive count then
  degree then id and reports the hidden count; the focus survives trimming.
- `watchConnectionsChanges` fires on writes to each contributing table
  (`repository_tick_stream_test` pattern).

**Layout** (pure Dart):

- Same input gives identical positions across runs.
- Settles within the iteration bound and never yields a non-finite value.
- Connected pairs end closer, on average, than unconnected pairs.
- Pinned nodes do not move; `clearPins` releases them.
- Islands do not overlap after packing.
- Radial rings group by kind and sort by weight; a warm start keeps existing
  nodes near their previous positions.

**Canvas and page** (widget tests):

- Nearest-node hit testing with slop; edge hit when no node is hit.
- Tap selects, double-tap focuses, tap on empty clears.
- Empty states, including the Data Tools pointer.
- Lens switching, filter chips, year slider writing the filter.
- Deep link with `focus` lands in ego mode with the node selected.
- Bottom card at 732 px and side panel at 1200 px.
- Insight tiles select their evidence; highlight modes change node colours;
  the share painter produces an image of the expected size (phase 3).

**Guards updated in the same PR:** `provider_change_tick_test`,
`dive_stats_scope_census_test` (new repository file), the four destination
tests, `feature_accent_colors_test`, `arb_parity_test`, and the French and
Portuguese plural rule (`=1{{count} ...}` interpolation). Run the whole
`test/architecture/` folder after adding any `lib/` file.

## Phases

Each phase is one PR that closes its sub-issue and references #2321.

1. **The graph (#2322).** Engine with every kind's membership fragment, domain
   model and budget, force and radial layouts, canvas with pan, zoom, tap,
   long-press drag and edge selection, selection card and panel, page and
   destination, lenses *Dive circle* and *Who dives where*, filter action,
   chips bar and year slider, buddy detail deep link, empty states, eleven
   locales.
2. **Breadth (#2323).** The other four lenses, the free pair picker, the
   trimmed-entities sheet, deep links from site, trip, center, equipment and
   species pages, hover tooltips, re-layout action, the `sightings` index.
3. **The story (#2324).** Insight strip, highlight modes, year play with warm
   start, share image.

## Localization

All strings are new keys prefixed `connections_` in `app_en.arb` and the ten
other locales, inserted next to a neighbouring key in each locale's own
order. Plurals interpolate the count in the `=1` branch for French and
Portuguese. Nothing displays a unit; dates and date ranges go through
`UnitFormatter`.

## Out of scope

- The diver as a node.
- Conditions as nodes (they are filters).
- Named, saved custom lenses.
- Community detection beyond label propagation; centrality metrics.
- Syncing the lens or filter state between devices.
- Any upload or online rendering of the graph.
