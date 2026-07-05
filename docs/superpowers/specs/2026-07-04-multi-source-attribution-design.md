# Multi-Source Attribution and Active-Source Model

Date: 2026-07-04
Status: Approved

## Problem

When a dive has profile data from more than one dive computer or data source
(typically after consolidation, PR #466), the dive detail page does not make
clear where its data comes from:

1. The chart's COMPUTERS legend can show "Unknown Computer" for a computer
   whose name is known and displayed correctly elsewhere on the page. Root
   cause: `getProfilesBySource` keys profile groups by raw `computerId`
   and buckets null-`computerId` rows (by convention, the primary source's
   rows) under the sentinel key `'original'`, which never matches the
   name lookup map built from `dive_data_sources`
   (`dive_repository_impl.dart:516-523`, `dive_detail_page.dart:1178`).
2. The stat chips and the chart legend resolve names through two different
   code paths (`DiveDataSource.displayName` vs `computerLabel`), so the same
   computer can render as two different strings on one page.
3. Only depth and temperature lines are per-computer on the chart. Tank
   pressure, events, and every analysis curve (ceiling, NDL, ppO2, SAC,
   ascent rate) are computed from the merged `isPrimary = true` profile with
   no attribution. Toggling a computer checkbox silently does nothing to
   most lines.
4. With multiple sources visible, overlapping unattributed dashed curves and
   unattributed pressure bands render as noise.

## Goal

At least feature parity with Subsurface's multi-computer model, plus
Submersion's overlay comparison:

- One **active source** at a time drives every line on the chart and every
  derived card on the page, always labeled.
- Other sources can be **overlaid**, color-coded, for any enabled line type.
- Per-source management: set primary and split into a separate dive.
  (During implementation the pre-existing "Unlink" action turned out to
  be a near-duplicate split; it was removed and Split absorbed its
  clone-on-demand shared-tank handling.)

## Design

### 1. Identity and naming foundation

- The canonical identity for attribution is the `dive_data_sources` row.
  Every surface (chart legend, stat chips, deco and tissue cards, sources
  bar) resolves computers through a source, never through raw `computerId`
  map keys.
- `getProfilesBySource` no longer emits the `'original'` sentinel. Profile
  rows with `computerId = null` are attributed to the dive's primary data
  source at query time (repair on read; no schema migration, nothing new
  for sync to carry). The map is keyed by data-source ID, so even a
  computer-less manual source has a stable identity, and two sources from
  the same physical computer stay distinct.
- The `'user-edited'` profile group remains, modeled as a variant of the
  primary source (label suffix "(edited)"), never a sibling source.
- One shared name resolver replaces both `DiveDataSource.displayName` and
  `computerLabel`:
  `computerName -> computerModel -> computerSerial -> source-type label`
  ("Manual Entry", "Imported File"), with "Unknown Computer" reserved for
  downloads that carry no identifying data. Names resolve at read time, so
  renaming a computer updates every dive's labels immediately.

### 2. Active source state and page scope

- New `activeDiveSourceProvider` (family, keyed by dive ID) holds the
  active source ID. Defaults to the primary source; session-only, not
  persisted; reopening a dive always starts at primary (Subsurface
  behavior).
- The whole page follows the active source: profile chart, stat chips
  (max depth, runtime, temps), Deco Status, Tissue Loading. The analysis
  provider becomes family-keyed by `(diveId, sourceId)` and computes
  ceiling, NDL, ppO2, SAC, ascent rate, and events from the active
  source's own samples. Results are cached; switching does not recompute.
- `FieldAttributionBadge` shows the active source's resolved name and
  updates on switch (`FieldAttributionService.viewedSourceId` becomes the
  live path).
- Switching the active source is pure view state. `isPrimary` in the
  database changes only via the explicit "Set primary" action.

### 3. Chart rendering and overlay

- The active source renders exactly as a single-computer chart does today:
  solid depth line with gradient fill, gas and velocity coloring,
  temperature, tank pressures, events, ceiling and NDL, and all analysis
  curves, every one computed from the active source. The current
  "two or more computers means dashed-vs-solid depth lines" branching is
  removed.
- Each source gets a stable color from the `computerColors` palette,
  assigned by source order. When a source's overlay is on, it draws its
  color-coded rendition of each line type currently enabled in the metric
  legend: depth (dashed), temperature (dashed, dimmed), tank-pressure
  traces, event markers (tinted), and computer-reported ceiling and NDL.
- The metric legend (Depth, Temp, Events, and so on) stays a global switch
  per metric; the sources bar decides whose version of those metrics
  renders. Two orthogonal controls: what, and whose.
- Tooltip leads with the active source's values and appends one line per
  overlaid source (color dot plus name), matched by timestamp using the
  existing remapping approach (`depthSpotProfileIndex`). Y-axes scale to
  fit the active source plus visible overlays. Point count, zoom, and
  Range Stats operate on the active source.

### 4. Sources bar and management actions

- `ComputerToggleBar` is replaced by a `SourceBar`: one chip per
  `dive_data_sources` row, shown only when a dive has two or more sources.
  Single-source dives are unchanged.
- Chip anatomy: color dot (the source's chart color), resolved name, and a
  badge on the primary source. Tap a chip to make it active (filled
  style); activating a chip removes it from the overlay set, and the
  previously active source does not auto-overlay. Non-active chips carry
  an eye icon that toggles that source's overlay. Each chip has an
  overflow menu: Set primary (existing handler from
  `data_sources_section.dart`) and Split into separate dive. The old
  Unlink action was removed as a duplicate of Split; its shared-tank
  clone-on-demand semantics live on in `DiveSplitService`.
- **Split** (`DiveSplitService`) is the inverse of
  `DiveConsolidationService`: in a single transaction, it creates a new
  dive, moves the source's profile rows, events, tank pressures, and tanks
  to it, recomputes both dives' summary stats, and removes the source row
  from the original. Moved rows are deleted with per-row tombstones (the
  consolidation lesson from #466) and re-inserted under the new dive ID so
  sync propagates the split as tombstones plus a new dive. Guards: cannot
  split a dive's only source; splitting out the primary promotes the
  remaining source with the earliest creation timestamp. Confirmation dialog before executing. Any
  constraint failure rolls back the whole transaction and surfaces a
  snackbar.

### 5. Edge cases

- Single-source dives: no SourceBar, no attribution badges, no behavior
  change.
- A source with no profile samples (metadata-only import) still gets a
  chip and can be activated; stats and attribution follow it and the chart
  shows the existing no-profile placeholder. Its overlay eye is disabled.
- User-edited profiles show when the primary source is active, with an
  "(edited)" chip suffix.

### 6. Testing

- Unit: name-resolver fallback chain; `getProfilesBySource` attribution of
  null-`computerId` rows to the primary source (direct regression test for
  the reported bug); per-source analysis correctness; `DiveSplitService`
  round-trip (consolidate, then split restores two equivalent dives) with
  foreign-key enforcement ON; tombstone emission on split.
- Widget: tapping a source chip swaps chart series, stat chips, and
  attribution badges together; overlay eye adds and removes exactly that
  source's lines; primary badge follows Set primary; "Unknown Computer" is
  never rendered when any identifying field exists.
- Sync: split on one device propagates as tombstones plus a new dive on
  another, covered at the service level with the existing sync test
  harness.

## Out of scope

- Persisting active-source or overlay selection across sessions.
- Overlaying the pre-edit original of an edited profile as its own entry.
- Any change to consolidation matching heuristics.
