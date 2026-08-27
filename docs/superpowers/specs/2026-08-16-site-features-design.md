# Site Features (Annotation Backbone) - Design

**Date:** 2026-08-16
**Status:** Approved (design dialogue with Eric, 2026-08-16)
**Part of:** the seascape usefulness program, slice 2. Slice 1 (#1073) and
the batch-3 unification stack (#1076, #1082, #1083) are merged; this
slice builds the annotation backbone that slice 3 (wreck suggestions)
writes into and slice 4 (briefing tools) reads from.

## Problem

The seascape shows measured terrain but knows nothing a diver knows: where
the wreck sits, where the mooring ball is, where to get in and out, where
the swim-through starts, what to avoid, and which way the current usually
runs. Divers need to place that knowledge on the site once and see it on
both the 2D map and the 3D seascape, on every device.

## Decisions (Eric, 2026-08-16)

- Geometry: **points with optional bearing and optional depth**. No lines
  or areas this slice. Bearing renders current arrows and wreck
  orientation; depth places features in the 3D water column.
- Placement: **2D map tap; 3D is read-only**. Placement arms from the
  site detail Features section and drops a point on the fullscreen map.
- Depth: **auto-sampled from the cached bathymetry grid at the tapped
  point, manually editable or clearable** in the sheet.
- Surfaces: **site detail list + overlay toggles + 2D marker-tap
  editing**. The 3D pane gets a Features chip; the 2D map shows features
  whenever the site is selected.
- Sync model and delivery: **full LWW entity, one PR** (approach B).
- Feature types are a FIXED enum this slice: `wreck, mooring, entry,
  exit, swimThrough, hazard, current` (entry and exit are distinct
  types). Currents are annotations, never model data (honesty rule from
  the program brainstorm).

## Design

### Data model (schema v152)

New Drift table `SiteFeatures` in `lib/core/database/database.dart`,
following the mutable-entity shape (`ServiceRecords` is the reference):

| Column | Type | Notes |
| --- | --- | --- |
| `id` | TEXT PK | UUID v4 from the repository |
| `siteId` | TEXT FK | references `dive_sites(id)`, `onDelete: KeyAction.cascade` |
| `type` | TEXT | enum name string from the fixed type list |
| `name` | TEXT | default `''`; UI falls back to the localized type label |
| `latitude` | REAL | WGS84 |
| `longitude` | REAL | WGS84 |
| `bearingDeg` | REAL nullable | 0-359; current direction or wreck orientation |
| `depthMeters` | REAL nullable | stored metric; displayed in diver units |
| `notes` | TEXT | default `''` |
| `createdAt` | INT | Unix milliseconds |
| `updatedAt` | INT | Unix milliseconds |
| `hlc` | TEXT nullable | per-row clock; nullable by convention |

No `diverId`: child rows inherit ownership through the parent site, per
house convention. Migration: bump `currentSchemaVersion` to 152, append
to `migrationVersions`, add an idempotent create-table helper called from
BOTH `onUpgrade` and the `beforeOpen` backstop (parallel branches collide
on version numbers). Raw index `idx_site_features_site` on
`site_features(site_id)` in `performance_indexes.dart` (Drift
`createAll()` never builds raw-SQL indexes).

### Domain, repository, providers

- `SiteFeature` entity with `copyWith` in
  `lib/features/dive_sites/domain/entities/site_feature.dart`, plus a
  `SiteFeatureType` enum with `values.asNameMap()` decoding and an
  unknown-name fallback (a newer peer may sync a type this build does
  not know; render it as `hazard`-styled generic rather than dropping
  the row).
- `SiteFeatureRepository` in
  `lib/features/dive_sites/data/repositories/` with
  add/update/delete/getForSite. Every mutation follows the mandatory
  write ritual: write the row, `markRecordPending` for `siteFeatures`,
  bump the parent site's `updatedAt` + `markRecordPending` for the
  parent, `SyncEventBus.notifyLocalChange()`; deletes call
  `logDeletion(entityType: 'siteFeatures', recordId: id)`.
- Providers in `lib/features/dive_sites/presentation/providers/`:
  `siteFeaturesProvider = FutureProvider.family<List<SiteFeature>,
  String>` keyed by site id, and a notifier wrapping the repository
  mutations that invalidates the family entry.

### Sync (LWW)

`siteFeatures` enrolls as a conflict-capable entity:

- `sync_data_serializer.dart`: all twelve enumerated points for the
  `'siteFeatures'` key (SyncData field, ctor default, toJson, fromJson,
  `_baseTables` descriptor in toJson-key order, `_buildSyncData` wiring,
  `fetchRecord`, `upsertRecord`, `upsertRecords`, `recordIdsFor`,
  `_syncTableFor`, `deleteRecord`) plus a delta export
  `_exportSiteFeatures(String? hlcSince)` filtering on the row's OWN
  `hlc` (not a parent join; this table has its own clock).
- `sync_service.dart`: ordered merge-list entry with
  `hasUpdatedAt: true`; `entityHasUpdatedAt['siteFeatures'] = true`;
  `parentRefs['siteFeatures'] = [(field: 'siteId', parent: 'diveSites',
  nullable: false)]`.
- `sync_repository.dart`: `_hlcTargets['siteFeatures'] = (table:
  'site_features', pk: 'id')`.
- The completeness tests (`sync_parent_refs_completeness_test`,
  `sync_data_serializer_record_ids_test`, `hlc_column_test`, streaming
  parity, round-trip, batch coverage) each gain the new entity; they
  fail loudly on any missed enrollment point, which is the point.
- Backup: nothing to do (whole-file byte copy of the database).

### Site lifecycle

- Delete: nothing to add. The FK cascade removes features locally, and
  peers converge by applying the single `diveSites` tombstone (which
  cascades on their side too), backstopped by
  `repairDanglingForeignKeys()`.
- Merge: `mergeSites` gains `_relinkSiteFeatures(duplicateIds,
  survivorId, now)` inside the existing transaction, following
  `_relinkDives` (re-point `siteId`, bump `updatedAt`,
  `markRecordPending` per row). `MergeSnapshot` gains the feature rows'
  prior `siteId`s and `undoMerge` restores them. No dedupe-by-key
  merging (features have no natural unique key; duplicates are visible
  and hand-fixable).

### 2D rendering and placement

- `SiteFeatureMarkerLayer({required String? siteId})` in
  `lib/features/site_scape/presentation/`, modeled on
  `BathymetryDepthOverlayLayer`: watches `siteFeaturesProvider(siteId)`,
  renders a flutter_map `MarkerLayer`; `SizedBox.shrink()` when siteId
  is null or the list is empty. One icon per type (anchor for mooring,
  warning for hazard, boat for wreck, login/logout for entry/exit,
  U-turn for swim-through, a directional arrow for current); markers
  with a `bearingDeg` rotate their glyph by it (`Transform.rotate`).
  The layer joins all four site-selected map hosts (master-detail
  `SiteMapContent`, standalone `SiteMapPage`, site detail preview card,
  site detail fullscreen), above the depth overlay and below the site
  pin/cluster layers.
- Marker tap opens the shared edit sheet for that feature.
- Placement: the Features section's add action opens the fullscreen
  `SiteScapeView` (site detail's `_showFullscreenMap`) armed in
  placement mode: a hint banner shows, the next map tap drops the
  point, and the edit sheet opens with the coordinates fixed, depth
  pre-filled from `bathymetryGridProvider`'s cached grid at the tapped
  cell (blank when no grid; editable and clearable), a type selector, a
  name field, a 0-359 bearing field, and notes. Cancel writes nothing.
  Placement mode is host state on the fullscreen page, not part of
  `SiteScapeView` itself.

### 3D rendering (read-only)

- `SiteSeascapeInput` gains a plain sendable
  `List<SiteFeatureMarkerInput>` (type name, label, east/north offset,
  optional depth); it crosses `compute()` like everything else.
- `SiteSeascapeGeometryService` emits `SceneMarker(kind:
  SceneMarkerKind.siteFeature, refId: feature.id, label, x, z from the
  ENU offset, y from the stored depth when present, else the terrain
  surface sampled from the grid at that position)`.
- `SceneMarkerKind` gains `siteFeature`; the viewport's marker painter
  and 24 px tap hit-test gain the kind's color and gating.
- `SceneOverlay` gains `features`, default ON, with a Features chip
  joining the pane's chip row; feature markers are gated on it (the
  generic `markers` overlay keeps gating the site/nearby-site pins).
- Tapping a feature marker in 3D shows a read-only info sheet (type,
  name, depth in display units, bearing, notes).

### Site detail Features section

A new card section on the site detail page: list rows with the type
icon, name (or type label), and depth in display units; per-row edit
(opens the sheet) and delete (with the row's name in the confirmation);
the add action that launches placement. Section renders only when the
site has coordinates.

### l10n

Type labels (7), section title, add action, placement hint, sheet field
labels, delete confirmation, and the 3D chip label, in ALL 11 locales,
generated from the project root.

## Testing

- Repository: CRUD round-trips, the write ritual (pending marks for row
  AND parent, deletion log on delete), unknown-type decode fallback.
- Sync: the enforced completeness suites plus one round-trip asserting a
  feature edit exports by its own `hlc` and merges LWW.
- Merge: features re-point to the survivor, snapshots restore on undo.
- Widget: Features section CRUD; placement mode drops exactly one row
  and cancel drops none; depth pre-fill from an overridden grid; marker
  tap opens the sheet pre-filled; current-arrow rotation applied; 3D
  Features chip toggles the markers; 3D marker tap shows the info
  sheet.
- Established traps apply: bounded pumps on map hosts, settings-notifier
  mocks, locale pinned to `en` wherever finders use English strings,
  l10n keys in all 11 arb files.

## Out of scope

- Lines and areas (swim-through routes, wall lines).
- 3D placement and 3D editing.
- User-extensible feature types.
- Photos or media attached to features.
- Wreck/seamark suggestion import (slice 3; it will write into this
  table).
- Showing features for non-selected sites on the 2D map.

## File plan (indicative)

New: `site_feature.dart` (entity + type enum),
`site_feature_repository.dart`, `site_feature_providers.dart`,
`site_feature_marker_layer.dart`, `site_feature_sheet.dart` (add/edit
sheet), `site_features_section.dart` (detail card), tests for each.

Touched: `database.dart` (table + v152 migration),
`performance_indexes.dart`, `sync_data_serializer.dart`,
`sync_service.dart`, `sync_repository.dart`,
`site_repository_impl.dart` (merge relink + snapshot),
`marker_layout.dart` (+`siteFeature`), `scene_overlay.dart`
(+`features`), `site_seascape_geometry_service.dart`,
`site_seascape_providers.dart`, `site_terrain_pane.dart` (chip + tap),
`dive_3d_interactive_viewport.dart` (marker color/gating),
`site_map_content.dart`, `site_map_page.dart`, `site_detail_page.dart`
(layer, section, placement), l10n arb files, and the sync completeness
tests.
