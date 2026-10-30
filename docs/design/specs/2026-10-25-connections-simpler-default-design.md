# Connections: a simpler starting view

Date: 2026-10-25. Release: v1.8.3.
Mockup: [assets/2026-10-25-connections-simpler-default-mockup.html](assets/2026-10-25-connections-simpler-default-mockup.html)
(option A, "Web", was chosen).

## Why

Opening Connections (Insights > Connections) cold shows the Dive circle
preset: every buddy, joined to every other buddy they shared a dive with,
drawn as a force-directed web. On a real log that is a large round hairball,
and nothing on the canvas says what it is or how to read it. The preset's
name lives in the panel, not on the picture.

Two failures, both to be fixed:

1. **Too much at once.** Dive circle is the densest map the feature can
   draw: a dive with six buddies alone makes 15 buddy-to-buddy lines.
2. **No orientation.** Nothing on the canvas says what is shown or what a
   line means.

Success: someone opening Connections for the first time understands what
they are looking at within a few seconds, and then chooses to go further.

## Goals

- The page opens on the **Who dives where** preset (buddies and sites,
  linked buddy to site only) in Map mode, instead of Dive circle.
- A caption on the canvas says which map this is and how to read a line.
- Everyone moves onto the new starting view once, including people who
  have opened Connections before.

## Non-goals

- **No node cap on the opening map.** It loads at the normal budget (80
  compact, 160 wide, Show all to 400) like every other map. The diver
  explicitly rejected a smaller first slice; the simplification is the
  switch to buddies and sites.
- No change to the minimum-shared-dives default (stays 1).
- No change to presets, their order, Around mode, saved maps, the panel,
  the display options or the layouts on offer.
- No new view kind, no onboarding tour, no first-run dialog.

## Anti-goals

- The caption must not crowd the canvas on a phone so much that the map
  becomes harder to read than before.
- The one-time move must not touch saved maps (synced, per diver) or any
  diver data. It only rewrites this device's remembered view.

## Design

### 1. The starting view

`ConnectionsViewState.initial` becomes Map mode with the `where` preset
(`ConnectionPresets.byId('where')`), `presetId: 'where'`. Every fallback
that lands on `initial` follows: a missing or unreadable stored view, and
the phase 1 legacy lens path when the legacy value is not a known preset
or pair.

The Map-mode layout default stays `web` (already the
`ConnectionsDisplay` default). Option A in the mockup is today's web
layout; nothing about drawing changes.

### 2. The one-time move for everyone

Connections remembers its view per device in SharedPreferences
(`connections_view_v2`) and its display in a separate key. The diver chose
that **everyone** lands on the new starting view once, after the update,
and from then on the page remembers their choices as it does today.

- On restore, if this device has not yet had the move applied, the view
  restored is the new starting view: Map mode, `where` preset, no
  `savedMapId`, no `editedFromPresetId`. Builder's call (mine): keep the
  stored Around-mode settings (`aroundKinds`, `hops`, `focus`) and
  `highlight`, so someone who tuned Around mode does not lose that; only
  what the Map mode shows is reset.
- In the same move, the display's **Map-mode layout** is reset to `web`,
  so someone who had switched to the circle layout does not open on a
  ring again. Other display settings (labels, node size, edges, hide
  unconnected, spacing, table view, Around layout) are kept. Builder's call
  (mine): reset `view` (graph/pairs/entities/matrix) to `graph` too, since
  the caption and the chosen picture only appear on the graph.
- The move is recorded so it happens once per device. How (a marker key,
  or a version field in the stored JSON) is the builder's choice. A device
  that has never opened Connections simply gets the new `initial`.
- A failed write of the marker is logged and ignored, like the view's own
  write; the worst case is the move happening again next launch.
- Deep links (Open in Connections from a detail page) still open Around
  mode on their entity; they are applied on top of the restored view as
  today.

### 3. The caption

A caption sits at the top of the canvas, above the insight strip, on the
graph view (not on the pairs, entities or matrix tables, which carry their
own headers). Two parts:

- **Title:** the map's name, one line, ellipsized if it must be.
- **Sentence:** how to read it, in plain words. It wraps to as many lines
  as it needs and is never cut short, since the "how to read it" part is
  what the caption is for. Builder's call (mine): the caption's height is
  measured, and the overlays below it and the camera fit's top inset follow
  that measured height.

| What is shown | Title | Sentence (en, draft wording) |
| --- | --- | --- |
| Preset `circle` | Dive circle | A line joins two buddies who dived together; thicker means more dives. |
| Preset `where` | Who dives where | A line means you dived there together; thicker means more dives. |
| Preset `trips` | Trips and people | A line means that buddy was on that trip; thicker means more dives. |
| Preset `life` | Sites by marine life | A line means you saw that species at that site; thicker means more dives. |
| Preset `gear` | Gear together | A line joins gear you used on the same dive; thicker means more dives. |
| Preset `centers` | Centers and people | A line means you dived with that buddy through that center; thicker means more dives. |
| Preset `travel` | Travel story | Buddies, trips and sites; a line means they share dives, thicker means more. |
| Preset `reef` | Reef life | Sites, marine life and dive types; a line means they share dives, thicker means more. |
| Preset `gearRoad` | Gear on the road | Gear, trips and centers; a line means they share dives, thicker means more. |
| Saved map | The saved map's name | Generic sentence built from its kinds (below). |
| Edited or custom map | "Custom map" | Generic sentence built from its kinds. |
| Around mode with a centre | The centre's name | Everything that shares a dive with it, up to N steps out. |

Generic sentence: lists the map's kinds by their plural names ("Buddies,
sites and trips") and ends "a line means they share dives, thicker means
more." When the edge mode is `thin`, the "thicker means more" clause is
dropped from every sentence, since lines no longer vary in width. In
`selectedOnly` mode the clause stays: the selection's lines are still drawn
weighted (`NodeMetrics.edgeWidthFor`). Builder's call (mine).

The wording above is a draft; final English is the builder's, kept short.
All strings go through ARB (`connections_caption_*`), translated into
every shipped locale like the rest of the feature.

Placement and behaviour:

- Phone: full width at the top of the canvas, in a translucent card like
  the legend, at the reader's text size. The insight strip, legend,
  hidden-nodes chip and the camera fit's top inset move down by the
  caption's height (they already move by the strip's).
- Wide: the same, over the canvas, left of the panel.
- Always shown; not dismissible (an orientation aid that hides itself after
  first use fails the next person who opens it). Builder's call (mine).
- Part of the canvas's accessible summary: the semantics label starts
  with the caption title.
- Not part of the share image (the share image already has its own title
  treatment; unchanged).
- The existing legend (kind swatches) stays as it is: on the canvas on a
  phone, in the panel on wide screens.

### 4. Divers with few or no buddies

Today the map loader keeps an entity with no surviving line as an island,
and the page shows its empty state only when the graph has no nodes. On
Who dives where that would give a solo diver a field of unlinked site dots
under a caption about lines. The diver approved this:

- **Who dives where shows only the places you dived with a buddy.** On
  that preset, a site is included only if at least one of its dives has a
  buddy (it has a buddy to site line). This is applied when the map loads,
  before the node budget, so solo-only sites never take a budget slot. It
  chooses which sites appear and nothing else: a site's dive count, size
  and first dive still cover all its dives, so they match Show dives.
  Buddies are unaffected (a buddy with dives at sites always has a line).
  It matches the diver's own description of the map: "buddies and the
  places we've dived together".
- **Scope:** the `where` preset only, unedited, and only the site side.
  Every other preset, a custom or edited map with the same kinds, saved
  maps and the "hide unconnected" display switch behave as today. How the
  loader learns it is on this preset (a flag on the spec, or a check of
  `presetId`) is the builder's choice; it must not change what a saved map
  with the same kinds shows.
- **No buddy lines at all:** when Who dives where has no buddy to site
  line, it is empty after the rule above (or holds only buddies with no
  sited dives), and the page shows the existing
  `connections_empty_buddies` message, exactly as Dive circle does today
  for a diver with no buddies. `ConnectionsEmptyState` picks that message
  for this preset as it does for Dive circle. When buddies are on dives but
  none of those dives has a site, the empty state says that instead
  (`connections_empty_whereNoSites`), since "no buddies are linked" would
  be untrue.
- A filter that leaves nothing still shows `connections_empty_filtered`,
  as today.

### 5. Buddy colour on the map

Found while capturing screenshots and approved by the diver: the app-wide
buddies accent (a muted sage) sits next to the sites green, so on Who dives
where the two kinds were hard to tell apart. Buddy nodes on the Connections
map take a Connections-only accent, `connections-buddy` (pink, the one hue
no other kind on the map uses), in both palettes. The app-wide `buddies`
accent and every buddy card are unchanged.

## Constraints

- Strings: every new string in `app_en.arb` and every shipped locale; the
  orphan-ARB-key and diacritics guards apply.
- The connections page is 612 lines; the caption goes in its own widget
  file under `presentation/widgets/`, and caption text selection in a
  small pure function that tests can call directly.
- The view state's JSON must stay readable by the previous release (sync
  does not carry it, but a downgrade on the same device must not crash);
  adding a field or a separate marker key both satisfy this.

## Left to the builder

- How the once-per-device move is recorded.
- Final English wording of the captions.
- Caption styling within the existing overlay look (card, padding,
  typography), and how it sits with the insight strip when the strip is
  empty.
- Test shape: unit tests for the caption text function and the restore
  migration; widget tests that the caption renders and the overlays move
  below it; update existing tests that pin Dive circle as the default.
