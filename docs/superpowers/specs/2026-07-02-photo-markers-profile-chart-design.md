# Photo Markers on Dive Profile Chart — Design

**Issue:** [#162](https://github.com/submersion-app/submersion/issues/162)
**Date:** 2026-07-02
**Status:** Approved

## Summary

Display camera-icon markers on the main dive profile chart at the time and depth
each photo was taken. Tapping a marker shows a floating thumbnail card; tapping
the card opens the full photo viewer. Markers that would overlap at the current
zoom level cluster into a single icon with a count badge. A legend toggle and a
persistent settings default (on by default) control visibility.

## Background

The data pipeline for this feature already exists:

- `MediaEnrichment` (entity in `lib/features/media/domain/entities/media_item.dart`,
  table in `lib/core/database/database.dart`) stores `elapsedSeconds`,
  `depthMeters`, `temperatureCelsius`, and `matchConfidence` per photo, computed
  at import time by `EnrichmentService.calculateEnrichment`
  (`lib/features/media/data/services/enrichment_service.dart`).
- `mediaForDiveProvider` (`lib/features/media/presentation/providers/media_providers.dart`)
  returns `MediaItem`s with enrichment pre-joined and self-refreshes on dive
  detail changes.
- `MiniDiveProfileOverlay`
  (`lib/features/media/presentation/widgets/mini_dive_profile_overlay.dart`)
  already renders a photo marker on a mini profile chart in the photo viewer,
  including the data-to-pixel mapping and out-of-range clamping this design reuses.

This feature surfaces that existing data on the main `DiveProfileChart`
(`lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`). No new
database tables or enrichment computation are required.

## Decisions

| Decision | Choice |
| --- | --- |
| Marker appearance | Camera-icon chip placed on the depth line at `(elapsedSeconds, depth)` |
| Tap action | Floating thumbnail card near the marker; tapping the card opens `PhotoViewerPage` |
| Crowding | Zoom-aware clustering: overlapping markers collapse into one chip with a count badge; tapping a cluster shows a horizontal thumbnail strip |
| Visibility | On by default; live legend toggle plus persistent settings default (the #242 Ascent Rate template) |
| Rendering approach | Widget overlay in the chart's `Stack` (Approach A), not a native fl_chart layer |

### Why a widget overlay instead of fl_chart internals

The thumbnail popup must be a widget positioned at pixel coordinates regardless
of approach, so the data-to-pixel transform is needed either way. Keeping the
markers as widgets also keeps their tap handling out of fl_chart's touch arena,
which is already claimed by the cursor/tooltip system and has caused gesture
conflicts before (#238, #372). The mini overlay proves the pattern.

## Design

### 1. Data flow

- New value type `PhotoChartMarker` (new file under
  `lib/features/dive_log/presentation/widgets/`): `elapsedSeconds`,
  `depthMeters`, and the source `MediaItem`, so the popup card reuses the
  existing thumbnail resolution widgets (`MediaItemView` pipeline) unchanged.
- The dive detail page (`dive_detail_page.dart`), which constructs the main
  profile chart and its fullscreen variant, watches
  `mediaForDiveProvider(dive.id)`, filters to photos where `enrichment` is
  non-null, `enrichment.elapsedSeconds` and `depthMeters` are non-null, and
  `matchConfidence != MatchConfidence.noProfile`, maps them to
  `PhotoChartMarker`s, and passes the list to `DiveProfileChart` alongside the
  existing events and markers. The dive-list side panel
  (`dive_profile_panel.dart`) is intentionally excluded (out of scope).
- Because `mediaForDiveProvider` self-refreshes on dive detail changes, markers
  stay in sync when photos are imported, reassigned, or deleted.

### 2. Rendering and clustering

- New widget `PhotoMarkerOverlay` (own file, target 200-400 lines) placed in the
  chart's existing `Stack`, above the `LineChart`, below the tooltip layer.
- Inputs: marker list, current viewport bounds (visible min/max X and Y from the
  zoom system in `profile_chart_viewport.dart`), chart edge insets, and the
  `showPhotoMarkers` flag.
- Position mapping: linear transform from `(elapsedSeconds, -depth)` to pixels,
  the same math as `MiniDiveProfileOverlay`. Markers outside the visible time
  range are not built.
- Clustering: on each viewport change, sort markers by time and run a single
  greedy pass merging any that would land within ~24 px of each other on screen.
  A cluster renders at the mean position of its members as one chip with a count
  badge. Zooming in naturally splits clusters. Clustering and pixel mapping are
  extracted as pure functions for unit testing.
- Chip visual: small circular chip with a camera icon on a `colorScheme`-derived
  background; drawn small but with a ~32 px tap target.

### 3. Interaction

- Tap chip: a floating card appears anchored above the marker, auto-flipping
  below or inward near chart edges. Card content: photo thumbnail plus a caption
  with depth (formatted through the units service, respecting diver unit
  settings) and runtime as `mm:ss`.
- Tap card: opens the existing `PhotoViewerPage` for that photo.
- Cluster tap: the card is a horizontal thumbnail strip; tapping a thumbnail
  opens the viewer on that photo.
- Dismissal: tapping elsewhere, panning, or zooming dismisses the card.
- All gestures live in the overlay's own `GestureDetector`s; fl_chart's touch
  handling (cursor, tooltip, zoom) is unchanged.

### 4. Toggle and settings

Follows the #242 Ascent Rate template:

- `ProfileLegendState` (`profile_legend_provider.dart`): add `showPhotoMarkers`
  plus a `hasPhotoMarkers` availability flag so the legend row
  (`dive_profile_legend.dart`) only appears when the dive has positioned photos.
- `AppSettings` (`settings_providers.dart`): add `defaultShowPhotoMarkers`,
  default `true`, persisted through `diver_settings_repository.dart` like
  `defaultShowEvents`, with a Settings page row in the profile chart defaults
  section.
- The settings-notifier test mocks (4 files) are updated with the new member.
- New user-facing strings are added to the en ARB and translated into all 10
  non-English locales, then l10n is regenerated.

### 5. Edge cases

- Photos with no enrichment, `matchConfidence == noProfile`, or null
  `elapsedSeconds` are excluded; they have no chart position.
- Positions slightly outside the profile time range (entry/exit clock skew)
  clamp to the range, matching `MiniDiveProfileOverlay`.
- Missing thumbnail files fall back to the existing media resolution
  placeholder path.
- Dives with no photos: no legend row, no overlay, chart unchanged.

## Testing

TDD throughout:

- Unit tests for the clustering pass and the data-to-pixel mapping (pure
  functions).
- Widget tests: markers render at expected positions; toggle hides/shows the
  overlay; legend row appears only when positioned photos exist; tap shows the
  card; cluster tap shows the strip; excluded photos (no enrichment/noProfile)
  render no marker.
- Settings round-trip test for `defaultShowPhotoMarkers`.

## Out of scope

- Recomputing or backfilling enrichment for existing photos (the import
  pipeline owns that).
- Markers for videos or media without timestamps.
- Showing photo markers on charts outside the dive detail profile chart
  (e.g., mini charts elsewhere).
