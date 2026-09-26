# Connections explorer

Issue: #2321 (umbrella). Phases: #2322 (phase 1, revised: the whole
explorer), #2324 (phase 2, the story). #2323 was absorbed into #2322 by
Revision 2.

Revision 2 (below the original decisions) supersedes the pair-based lenses,
the page layout and the phase list.

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
| Delivery | Two PRs (revised by Revision 2) |

## Revision 2 (2026-09-25)

Phase 1 shipped on its branch as designed above, and a desktop review showed
three gaps. The side panel clipped its own controls and left most of its
height empty. Only two lenses existed. Every view joined exactly two kinds,
so "everything connected to this buddy" was impossible even in ego mode,
which the original design promised across several kinds and the phase 1 plan
had narrowed to one. This revision replaces the pair model with sets of
kinds, adds a second mode, rebuilds the panel, and folds the old phase 2 into
phase 1. Where it conflicts with the sections above, this revision wins; the
engine's SQL fragments, the stats scope, the filter, the force layout, the
hit testing and the error handling carry over unchanged unless named here.

On 2026-09-26 `main` renamed the Statistics section to Insights (#2385) and
moved its schema to version 231, so the rung here is 232 (the next free one
at the time of writing; the plan renumbers if `main` moves again), and
references to Statistics code below read as the Insights equivalents.

### Decisions (revision 2)

| Question | Decision |
| --- | --- |
| Kinds on one canvas | Any set, not a pair |
| Modes | *Around one entity* and *Whole map* |
| Around one entity | All kinds, 1 to 3 hops (default 1), kinds toggleable |
| Choosing the centre | Search across every kind, plus double-tap or *Centre here*, plus deep links |
| Whole map | Pick kinds and links; minimum-shared-dives slider (1 to 10) |
| Link default | Ticking a kind links it to the kinds already on; same-kind links stay off |
| Presets | Nine built-in presets; editing one makes a custom map |
| Saved maps | Named, synced per diver (`connection_maps`, schema rung 232) |
| Desktop panel | Layout A: one right panel with View, Filter and Details tabs |
| Phone | The same three tabs in a draggable bottom sheet |
| Canvas | Label-aware fit that follows the settling layout, label halos, islands gathered below, kinds seeded in sectors, kind icons, rings by hop |
| Refocus | 450 ms camera glide plus node morph; gestures cancel; reduce-motion snaps |
| Deep links | Every entity detail page that has one opens Around mode on it |
| Also in | Summary block, `sightings(dive_id)` index, the deferred review minors |
| Phasing | Phase 1 is this whole revision (#2322); the old phase 2 (#2323) is absorbed; the story phase (#2324) is phase 2 |

### Views

```dart
sealed class ConnectionView {}

/// Whole map: every entity of the chosen kinds, joined by the chosen links.
class MapView extends ConnectionView {
  final MapSpec spec;
}

/// Around one entity: everything within [hops] shared-dive steps of [focus],
/// limited to [kinds].
class AroundView extends ConnectionView {
  final NodeRef focus;
  final Set<ConnectionKind> kinds;
  final int hops; // 1..3
}

class KindLink { // unordered: KindLink(a, b) == KindLink(b, a)
  final ConnectionKind a;
  final ConnectionKind b;
  bool get isSameKind => a == b;
}

class MapSpec {
  final Set<ConnectionKind> kinds;
  final Set<KindLink> links; // every link's kinds are in [kinds]
  final int minSharedDives; // 1..10
}
```

`ConnectionQuery`, `ConnectionLens` and `LensSelection` are replaced by these
types. The active view is persisted device-local as JSON (the successor of
`connections_last_lens`), together with the Around kinds and hops so a
switch between modes restores each side. A persisted value that fails to
parse falls back to the *Dive circle* preset.

**Default Around kinds.** Buddies, sites, trips, species, equipment and dive
centers are on; tags, dive types, dive computers and courses are off. The
chips in the View tab change this.

### Data engine changes

- **Map load.** One node query per kind in `spec.kinds` (unchanged builder),
  and one edge query per link. A same-kind link keeps the
  `a.entity_id < b.entity_id` guard. The minimum becomes
  `HAVING COUNT(DISTINCT d.id) >= ?` on the edge query when it is above 1.
  Nodes with no surviving link are kept; they become islands.
- **Around load.** Breadth-first over hops:
  1. Hop 1: for each kind in `kinds`, the edge query from the focus's kind to
     that kind with side A pinned to the focus id.
  2. Hop n (2, 3): for each frontier kind F and each kind K in `kinds`, the
     edge query from F to K with side A restricted to the frontier ids of
     kind F and side B excluding ids already placed.
  3. Chords: for each pair of enabled kinds (same-kind included), the edge
     query with both sides restricted to the placed ids of their kind.
  4. Nodes: one node query per kind, restricted to the placed ids.
- **Builder change.** `buildEdgeSql` replaces the single `restrictTo` list
  with `restrictA`, `restrictB` and `excludeB`, each an optional id list,
  and gains `minShared`. Empty restriction lists still match nothing.
- **Hop distance.** `ConnectionNode` gains `hop` (0 for the focus, 1 to 3
  for others, null in map mode). The budget ranks by hop first, then dive
  count, then weighted degree, then id, so a hop-3 entity never displaces a
  direct neighbour. The focus is always kept.
- **One transaction.** A map or around load runs inside one Drift read
  transaction, so a sync commit cannot land between its queries.
- **Scope.** Every query keeps the diver clause, `DiveStatsScope` and the
  page's filter through `diveScopeSql`. The minimum-shared-dives slider
  applies to map mode only.
- **Index.** Rung 232 adds `idx_sightings_dive_id` on `sightings(dive_id)`,
  the one junction the species queries join that has no `dive_id` index.

### Presets

| Preset | Kinds | Links |
| --- | --- | --- |
| Dive circle | buddy | buddy with buddy |
| Who dives where | buddy, site | buddy with site |
| Trips and people | buddy, trip | buddy with trip |
| Sites by marine life | site, species | site with species |
| Gear together | equipment | equipment with equipment |
| Centers and people | dive center, buddy | dive center with buddy |
| Travel story | buddy, trip, site | buddy with trip, trip with site, buddy with site |
| Reef life | site, species, dive type | site with species, species with dive type, site with dive type |
| Gear on the road | equipment, trip, dive center | equipment with trip, trip with dive center, equipment with dive center |

Every preset starts with a minimum of 1. Editing the kinds, links or minimum
of an applied preset makes the view a custom map: no preset card is
selected, and the card it came from shows an "edited" mark until another
card is chosen.

### Saved maps

- **Table.** `ConnectionMaps` in `database.dart`: `id` (uuid primary key),
  `diverId` (not null, references `Divers`, cascade on delete), `name`,
  `spec` (the `MapSpec` as JSON text), `sortOrder`, `createdAt`,
  `updatedAt`, `hlc`. Rung 232 creates it; a guarded `beforeOpen` backstop
  creates it and the sightings index when missing, for rung collisions
  between parallel branches.
- **Sync.** Registered as a diver-owned entity everywhere sync enumerates
  tables: the payload, the serializers, `mergeOrder`, the updated-at flag,
  parent references, the `hlc` targets and the deletion log. A round-trip
  sync test covers create, rename and delete.
- **Repository.** `ConnectionMapRepository` with `getAll(diverId)`,
  `create`, `rename`, `updateSpec`, `delete` and `watchConnectionMapsChanges`;
  its provider subscribes to that tick.
- **Parsing.** A stored spec that does not parse (a kind this build does not
  know) is skipped in the list and never deleted.
- **UI.** *Save as map* in the editor asks for a name. Saved maps appear as
  cards after the presets with a bookmark mark. Each card's overflow menu
  offers Rename, Update from current, and Delete with an undo snackbar.
- **Export.** UDDF and CSV do not carry saved maps; the `.db` backup does.

### Panel (layout A)

The desktop page is the canvas on the left and one 340 px panel on the
right with three tabs. On compact width the same tabs live in a draggable
bottom sheet over a full-height canvas. Every row in the panel wraps; nothing
scrolls sideways.

- **View tab.**
  - The mode switch: *Around one entity* and *Whole map*.
  - Whole map: the nine presets and the saved maps as a two-column card
    grid, each card with a coloured dot per kind; then a collapsible
    *Custom map* editor (kind chips, one checkbox per possible link among the
    ticked kinds, the minimum slider, *Save as map*).
  - Around one entity: a search field that matches every kind by name and
    lists results with their kind dot and dive count; the centred entity; a
    1, 2, 3 hop stepper; kind chips carrying their counts in the current
    result.
  - Summary at the foot: counts per kind, connections, most connected
    (highest weighted degree) and strongest pair (heaviest edge), or, in
    Around mode, the entity count and the closest neighbour.
- **Filter tab.** The year slider, removable chips for the active filter
  axes, *All filters...* (the existing `DiveFilterSheet` bound to
  `connectionsFilterProvider`) and *Clear*. The tab label carries the count
  of active axes.
- **Details tab.** The selection: name, subtitle, dive count, top
  connections with kind dots, then *Open*, *Centre here* (formerly *Focus*)
  and *Show dives*. Selecting a node or edge switches to this tab; tapping
  empty canvas returns to the tab that was open before.

The old chip row, filter bar and overlay legend on wide layouts are removed.
The compact overlay legend stays on phones.

### Canvas changes

- **Fit.** The fit target solves for the scale at which every node's
  position, plus its screen-space radius and label box, fits the canvas with
  a 24 px margin. While the force layout settles, the camera eases toward the
  current target each frame instead of snapping; once settled, auto-fit
  stops. Any pan, pinch, wheel, trackpad or drag gesture ends auto-fit until
  the next view or graph change.
- **Labels.** Each visible label is painted over a rounded halo in the
  canvas background colour at 85 % opacity. The collision pass treats node
  discs as occupied space, so a label never covers another node. A hidden
  label shows on hover, and returns when zooming makes room.
- **Islands.** Nodes with no edge are gathered into a grid below the linked
  components, ordered by dive count then label.
- **Kind sectors.** Initial force-layout positions place each kind in its own
  angular sector of the seed ring, deterministically, so kinds start grouped.
- **Kind icons.** At a drawn radius of 18 px or more, a node without a photo
  shows its kind icon (the icon of the kind's home destination) instead of
  initials when the kind is not buddy.
- **Rings by hop.** The radial layout places hop 1 on the inner rings and hop
  2 and 3 outside them; within a ring, kinds keep contiguous arcs.
- **Refocus animation.** The page reads the graph with
  `skipLoadingOnReload: true`, so the canvas stays mounted while a new view
  loads, with a thin progress bar over it. When the new graph arrives:
  - the camera glides from its current viewport to the new fit over 450 ms,
    `easeInOutCubic`, blending scale in log space and moving the graph point
    at the screen centre;
  - nodes present before and after slide from their old positions to their
    new ones over the same curve; new nodes start at the focus node's
    previous position (or its new one when it is itself new) and grow from
    zero radius; nodes that leave simply disappear;
  - `LayoutFrame` gains an `appear` factor per node (0 to 1, default 1) that
    the painter multiplies into radius and label opacity;
  - any gesture cancels the camera glide; the node morph finishes.
  With `MediaQuery.disableAnimationsOf(context)` true, both snap. The first
  load of the page snaps.

### Routes and deep links

`/connections` accepts `mode` (`around` or `map`), `preset` (a preset id),
`focus` (a `NodeRef` wire string) and `hops`. The phase 1 `lens`, `a` and
`b` parameters remain accepted: `lens` maps to its preset, `a` and `b` to a
two-kind custom map. *Open in Connections* appears on the buddy, site, trip,
dive center, equipment, species and course detail pages and pushes
`/connections?mode=around&focus=<kind>:<id>`.

### Carried-in fixes from the phase 1 review

- A vanished focus always resets; only the snackbar is guarded.
- *Show all* asks only when the total exceeds 400 and is hidden once the
  budget is at the ceiling.
- The exit-focus action gets its own tooltip key.
- The canvas semantics summary names the selected node.
- Buddy photos decode at a 96 px target width.
- `ConnectionNode` equality compares photos by identity.
- The last-view preference write is awaited and its failure logged.
- The hover tooltip clamp tolerates a canvas narrower than 160 px.
- Tests render the selection card at 732 px and reload a graph while the
  layout animates.

### Testing (revision 2)

Tests are written first.

- Repository, on a real in-memory database: map loads with three kinds and
  chosen links, same-kind links, the minimum, islands; around loads at hops
  1 to 3, frontier restriction, exclusion of placed ids, chords, hop-ranked
  trimming that keeps the focus; one transaction per load.
- Pure Dart: `KindLink` equality, `MapSpec` link defaults when a kind is
  ticked, spec JSON round trip and tolerant parsing, preset table, kind-sector
  seeding determinism, island grid, rings by hop, the morph and camera
  interpolation endpoints and midpoints, the label-aware fit.
- Saved maps: repository CRUD, the change tick, migration rung 232 (table
  and index), the backstop, the sync round trip.
- Widgets, at 732 and 1280 px: each tab, the editor's link defaults, search
  results across kinds, the hop stepper, selection switching to Details and
  back, the phone sheet, the refocus animation's mid-transition scale, a
  gesture cancelling it, reduce-motion snapping, every deep link.
- A loose benchmark for an Around load at 3 hops with every kind on over a
  seeded database.
- Guards: provider change tick, build smoke, stats-scope census, repository
  tick streams, destinations, ARB parity and the plural rules, and the sync
  table-coverage tests.

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
  `lib/features/insights/data/dive_filter_sql.dart`, exactly as Statistics
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

*Superseded in part by Revision 2: the lens chips, the pair picker, the
wide-layout panel and the route parameters. The destination, accent colour
and filter provider stand.*

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

Each phase is one PR that closes its issue and references #2321.

1. **The explorer (#2322).** Phase 1 as built plus all of Revision 2: map and
   around views, nine presets and the editor, saved maps (rung 232 with the
   sightings index), layout A and the phone sheet, the canvas changes and
   the refocus animation, deep links from every detail page, the summary,
   and the carried-in review fixes. The old phase 2 (#2323) is absorbed.
2. **The story (#2324).** Insight strip, highlight modes, year play with warm
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
- Carrying saved maps in UDDF or CSV exports.
- More than 3 hops; the minimum-shared-dives slider in Around mode.
- Colouring edges by kind pair.
- Community detection beyond label propagation; centrality metrics.
- Syncing the lens or filter state between devices.
- Any upload or online rendering of the graph.
