# 3D Profile Comparison — Design

- **Date:** 2026-07-12
- **Status:** Approved (design); ready for implementation planning
- **Feature area:** `lib/features/dive_3d`
- **Depends on:** the `Scene3d` renderer foundation and lighting from PR #565 (`worktree-dive-3d-view`). Implementation must be based on that branch (or land after it merges to main), since the compare scene reuses `Scene3d`, `SceneProjector`, `Dive3dInteractiveViewport`, `RibbonBuilder`, and `SceneBounds`.

## 1. Overview

Give divers a 3D view that places **multiple depth profiles on one shared time/depth scale** so they can be compared directly. Two things fill those profiles:

1. **Compare dives** — several *different* dives selected from the dives list.
2. **Compare computers** — the several *dive computers* that recorded a *single* dive (multi-source dives).

Both are the same renderable: N depth ribbons on a shared scale, each with its own identity color and a legend, under one shared time cursor, with a synchronized readout and divergence highlighting. The only thing that differs is the data adapter that produces the N profiles.

### Goals

- One shared comparison scene that scales from 2 to many profiles.
- Two layouts, toggleable: **side-by-side** (each profile in its own Z-lane, like the career terrain) and **overlay** (all profiles superimposed to expose divergence).
- Synchronized scrub readout: each profile's depth and its delta from a reference at the cursor time.
- Divergence highlighting: reference-based max-gap markers, plus an overlay gap surface for the focused profile.
- Three entry points: a "Computers" mode inside the existing 3D view, a "Compare in 3D" button on the detail-page source bar, and a "Compare in 3D" action on the dives-list multi-select bar.

### Non-goals (v1)

- No per-profile metric coloring (identity color is the point of a comparison).
- No deco/gas/marker overlays inside compare mode (kept clean; the single-dive scene keeps those).
- No alignment modes beyond start-aligned (t=0 = descent) — which is what stored `times` already are.
- No comparison of tissue/career/spatial scenes; depth-vs-time only.
- No export of the comparison.

## 2. Terminology

- **Profile** — one depth-vs-time series to be compared (a dive's primary source, or one computer-source of a dive).
- **Reference** — the profile that deltas are measured against. Defaults to the primary source (computers) or the first-selected dive (dives); user-changeable via the legend.
- **Focused profile** — the profile the user has tapped in the legend; drives the overlay gap surface.
- **Layout** — `sideBySide` or `overlay`.

## 3. Architecture

```
 entry points                     adapters (providers)                    shared core
 ─────────────                    ────────────────────                    ───────────
 dives list  ── Compare 3D ─────► diveComparisonProfilesProvider(ids) ─┐
 3D view "Computers" tab ──────┐                                        ├─► List<ComparisonProfile>
 detail source-bar button ─────┼─► computerComparisonProfilesProvider(id)┘            │
                               │                                                       ▼
                               │                                    CompareGeometryService.build(
                               │                                       profiles, layout, referenceIndex, focusedIndex)
                               │                                                       │
                               │                                                       ▼
                               └──────────────────────────────►  Scene3d ─► CompareProfile3dView
                                                                              (viewport + toggle + legend + readout)
```

The renderer, projector, interactive viewport, scrub bar, and ribbon builder are all reused unchanged from PR #565. New code is: a domain builder, a divergence builder, a resampler, two adapter providers, and a small presentation layer.

## 4. Domain (pure, isolate-friendly, unit-tested)

New directory: `lib/features/dive_3d/domain/compare/`.

### 4.1 `comparison_profile.dart`

```dart
/// One profile to compare: a labelled, colored depth-time series on the
/// shared scale. Adapter-neutral — produced identically for a dive's
/// primary source or for one computer-source of a single dive.
class ComparisonProfile {
  final String id;          // sourceId, or diveId
  final String label;       // "Perdix", "Blue Hole · 7 May"
  final Color color;        // identity color
  final List<double> times; // seconds from descent
  final List<double> depths;// meters
  final double maxDepthMeters;

  const ComparisonProfile({
    required this.id,
    required this.label,
    required this.color,
    required this.times,
    required this.depths,
    required this.maxDepthMeters,
  });
}

enum CompareLayout { sideBySide, overlay }
```

### 4.2 `compare_geometry_service.dart`

```dart
/// Generalized multi-ribbon builder: N depth ribbons on one shared
/// time/depth scale. This is the extraction of the career terrain's
/// stacking logic, plus an overlay layout and a divergence overlay.
class CompareGeometryService {
  static const double _zGap = 0.6; // matches career

  Scene3d build(
    List<ComparisonProfile> profiles, {
    CompareLayout layout = CompareLayout.sideBySide,
    int referenceIndex = 0,
    int? focusedIndex,
  });
}
```

Behavior:

- Empty / single profile → empty `Scene3d` (bounds `durationSeconds: 1, maxDepthMeters: 1`).
- Shared bounds: `durationSeconds = max(last time)`, `maxDepthMeters = max(maxDepthMeters)` across all profiles.
- `sideBySide`: profile *i* ribbon at `zCenter = -halfZ + i·_zGap`, where `halfZ = (count-1)·0.5·_zGap`; `SceneBounds.sceneMinZ/MaxZ` widened by `±(halfZ + zHalfWidth)` (identical to `CareerGeometryService`).
- `overlay`: every ribbon at `zCenter = 0`; ribbon opacity reduced (e.g. 0.55) so overlapping curves read; a thinner ribbon half-width may be used via `RibbonBuilder` (uses the shared `SceneBounds.zHalfWidth` — no change needed, translucency carries the overlap cue).
- Uniform per-profile color via `RibbonBuilder.build(sampleColors: uniform(profile.color))`.
- Scrub cursor: a **sweeping vertical time-plane** (a translucent quad spanning the full depth/Z extent at the cursor's X). The plane geometry is produced by the view at scrub time (foreground painter), NOT baked into the mesh layers — see §7.
- Divergence: appends markers from `DivergenceBuilder` (§4.3) and, when `focusedIndex != null` and `layout == overlay`, a gap surface layer.

**Constraint:** `CareerGeometryService` is refactored to delegate to `CompareGeometryService.build(..., layout: sideBySide)` (approach A). The shared builder must produce geometry identical to today's career output so the existing career tests (which assert `positions[2] == -SceneBounds.zHalfWidth` for a single dive, and per-mode colors) stay green. Career keeps its `CareerColorMode` (recency/depth) — it computes colors, then hands `ComparisonProfile`s to the shared builder.

### 4.3 `divergence_builder.dart`

```dart
/// Reference-based divergence. Resamples each profile onto a shared time
/// grid, then reports the largest depth gap vs the reference.
class DivergenceBuilder {
  /// One entry per non-reference profile: where and how big the max gap is.
  static List<DivergenceMark> maxGaps(
    List<ComparisonProfile> profiles,
    int referenceIndex,
  );

  /// Translucent surface between the focused profile and the reference,
  /// over their overlapping time range (overlay layout only).
  static MeshData gapSurface(
    ComparisonProfile focused,
    ComparisonProfile reference,
    SceneBounds bounds,
  );
}

class DivergenceMark {
  final String profileId;
  final double atTimeSeconds;
  final double gapMeters;   // signed: focused - reference
  const DivergenceMark({...});
}
```

`DivergenceMark`s become `SceneMarker`s (or a dedicated marker kind) placed on the profile ribbon at the max-gap time; the readout labels them.

### 4.4 `profile_resampler.dart`

```dart
/// Linear interpolation of a profile's depth at an arbitrary time, and
/// resampling of two profiles onto a shared time grid. Shared by the
/// scrub readout and DivergenceBuilder. Mirrors the existing
/// ProfileLookupOverPressure interpolation idiom.
class ProfileResampler {
  static double depthAt(ComparisonProfile p, double timeSeconds);
}
```

## 5. Data adapters (application)

New file: `lib/features/dive_3d/application/compare_providers.dart`.

### 5.1 Computers adapter

`computerComparisonProfilesProvider` — `FutureProvider.family<List<ComparisonProfile>, String>` (arg = diveId).

- Reads `diveDataSourcesProvider(diveId)` → `List<DiveDataSource>` (`dive_providers.dart:1002`) and `sourceProfilesProvider(diveId)` → `Map<String, SourceProfile>` (`dive_providers.dart:186`).
- For each source with a usable profile: `times`/`depths` from `SourceProfile.points` (`source_profile.dart:5`; each `DiveProfilePoint` at `dive.dart:788` has `timestamp`, `depth`). Label via `resolveSourceName(source, labels)` (`source_name_resolver.dart:27`). Color via `sourceColorAt(index)` (`source_bar.dart:16`).
- Reference = the primary source (`isPrimary`), placed at `referenceIndex`.
- Sources without profile samples are skipped (see §8).

### 5.2 Dives adapter

`diveComparisonProfilesProvider` — `FutureProvider.family<List<ComparisonProfile>, DiveIdSet>` where `DiveIdSet` is an equatable wrapper over `List<String>` (family keys must be equatable).

- For each diveId: read its primary source profile via `sourceProfilesProvider(diveId)` (primary entry) — reuse the same points extraction as the computers adapter. Label = dive site name + date (from the dive entity); color from a dive palette (reuse `sourceColorAt(index)` or a dedicated ramp).
- Reference = first selected dive.
- Dives with no usable profile (manual logs) are skipped with a note.

### 5.3 Scene provider

The page holds interactive state (layout, referenceIndex, focusedIndex) and rebuilds the scene from the resolved `List<ComparisonProfile>` via `CompareGeometryService.build(...)`. Scene building is synchronous and cheap for reasonable N; no isolate hop needed at this scale (mirrors `dive3dGeometryProvider`'s synchronous path for < 2000 samples).

## 6. Presentation

New: `lib/features/dive_3d/presentation/widgets/compare_profile_3d_view.dart` (shared body), `compare_legend.dart`, `compare_readout_panel.dart`; `lib/features/dive_3d/presentation/pages/compare_dives_3d_page.dart` (standalone dives page).

- **`CompareProfile3dView`** — takes an `AsyncValue<List<ComparisonProfile>>` and a title. Renders: the `Dive3dInteractiveViewport` (compare `Scene3d`), a **layout toggle** (`Side-by-side | Overlay`), the legend, a `TimeScrubBar`, and the readout panel. Used inline by the Dive3dPage "Computers" mode AND by `CompareDives3dPage`.
- **`CompareLegend`** — one row per profile (color swatch + label). Tap = focus (drives overlay gap surface + max-gap emphasis). A star/long-press sets the reference.
- **`CompareReadoutPanel`** — at the scrub cursor, per profile: depth + delta vs reference, e.g. `Perdix 30.2 m · Teric 30.5 m (+0.3)`. Depth uses `ProfileResampler.depthAt`. Respects the active diver's unit settings (per project rule). Also surfaces the persistent max-divergence value per profile.
- **Scrub cursor** — the interactive viewport's foreground painter draws the sweeping vertical time-plane at the cursor X (reusing the `_ScrubCursorPainter` slot that already exists in `Dive3dInteractiveViewport`), so it repaints on scrub without rebuilding the mesh.

## 7. Interaction

- **Layout toggle** flips `sideBySide ↔ overlay`; default chosen by context: overlay for computers (divergence is the point), side-by-side for dives.
- **Scrub** moves one shared normalized-time cursor (0..1); the time-plane sweeps and the readout updates for all profiles at once.
- **Focus** (tap legend row) highlights that profile and, in overlay, shades its gap vs the reference.
- **Reference** (star legend row) re-bases all deltas and max-gap marks.
- Orbit/zoom/reset are inherited from `Dive3dInteractiveViewport`.

## 8. Error / edge handling

- Profiles with no usable samples are **skipped with a note** ("2 of 3 dives have no depth profile and were skipped").
- Fewer than 2 comparable profiles → empty-state: "Need at least 2 … with profile data to compare."
- **Soft cap of 8 profiles** for legibility: render the first 8 in order (the reference is index 0, so it always survives the cap), and show "showing 8 of N" — never silently truncate (per the no-silent-caps principle).
- Mixed durations/depths are handled by the shared bounds (career already normalizes this).

## 9. Entry points & routing

- **Computers mode in `Dive3dPage`** — add a third scene segment (`Dive | Tissues | Computers`) shown only when `isMultiDataSourceDiveProvider(diveId)` (`dive_providers.dart:1010`) is true. It renders `CompareProfile3dView` with `computerComparisonProfilesProvider(diveId)`. `Dive3dPage` gains an optional `initialMode` so it can open directly in Computers mode.
- **Detail-page source-bar button** — the multi-source data-sources section (`data_sources_section.dart` / `SourceBar`) gets a "Compare in 3D" button that pushes `Dive3dPage(diveId, initialMode: computers)` via the existing `Navigator.push(MaterialPageRoute(...))` idiom at `dive_detail_page.dart:1299`.
- **Dives-list multi-select action** — add "Compare in 3D" to the selection bar in `DiveListContent` (`dive_list_content.dart:58`, alongside `_openBulkEdit` at :609). It calls `context.pushNamed('compareDives3d', extra: selectedIds)`. New go_router route `compareDives3d` in `app_router.dart` (mirroring `bulkEditDives` at :311) builds `CompareDives3dPage(diveIds: ids)`.

## 10. Testing

- **`CompareGeometryService`**: side-by-side zCenters for N; overlay all-zero Z + reduced opacity; shared bounds across mixed durations/depths; empty & single-profile → empty scene; parity with career output for the single-dive case.
- **`DivergenceBuilder`**: `maxGaps` returns correct time+magnitude on hand-built diverging curves; `gapSurface` vertex extents; reference change flips signs.
- **`ProfileResampler`**: interpolation at, before, after, and between samples.
- **Adapters**: computers adapter builds one profile per source with correct label/color and primary-as-reference; dives adapter builds one per dive; manual/no-profile skipped; soft cap applied with note.
- **Widgets**: layout toggle switches geometry; scrub readout shows per-profile depth + delta; legend focus/reference changes; `Dive3dPage` shows the Computers segment only when multi-source; dives-list Compare action navigates with the selected ids.
- **`CareerGeometryService`** existing tests remain green after the delegation refactor.

## 11. Localization

New user-facing strings (layout toggle, legend actions, readout labels, empty-states, "Compare in 3D", "showing 8 of N", skip note) go into `app_en.arb` and are translated into all 10 non-en locales, then codegen is regenerated (per project rule).

## 12. File structure

**Create:**
- `lib/features/dive_3d/domain/compare/comparison_profile.dart`
- `lib/features/dive_3d/domain/compare/compare_geometry_service.dart`
- `lib/features/dive_3d/domain/compare/divergence_builder.dart`
- `lib/features/dive_3d/domain/compare/profile_resampler.dart`
- `lib/features/dive_3d/application/compare_providers.dart`
- `lib/features/dive_3d/presentation/widgets/compare_profile_3d_view.dart`
- `lib/features/dive_3d/presentation/widgets/compare_legend.dart`
- `lib/features/dive_3d/presentation/widgets/compare_readout_panel.dart`
- `lib/features/dive_3d/presentation/pages/compare_dives_3d_page.dart`
- Tests mirroring each of the above.

**Modify:**
- `lib/features/dive_3d/domain/career/career_geometry_service.dart` — delegate to `CompareGeometryService`.
- `lib/features/dive_3d/presentation/pages/dive_3d_page.dart` — Computers segment + `initialMode`.
- `lib/features/dive_log/presentation/pages/dive_detail_page.dart` (or `data_sources_section.dart`) — "Compare in 3D" button.
- `lib/features/dive_log/presentation/widgets/dive_list_content.dart` — "Compare in 3D" selection action.
- `lib/core/router/app_router.dart` — `compareDives3d` route.
- `lib/l10n/*.arb` — new strings across all locales.

## 13. Sequencing

1. Domain: `ComparisonProfile`, `ProfileResampler`, `CompareGeometryService` (+ career refactor), `DivergenceBuilder`.
2. Adapters: computer + dives providers.
3. Shared presentation: `CompareProfile3dView`, legend, readout.
4. Entry points: Dive3dPage Computers mode → detail source-bar button → dives-list action + route.
5. l10n + polish + device walkthrough.

## 14. Open questions

None blocking. Accepted defaults: reference-based divergence, soft cap of 8, sweeping time-plane cursor.
