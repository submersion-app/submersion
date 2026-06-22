# Two-finger trackpad scroll → zoom (maps + dive profile chart)

Date: 2026-06-22
Branch: `worktree-trackpad-scroll-zoom`

## Goal

Two-finger up/down scroll on a touchpad should zoom in/out:

- on **all maps** (15 `FlutterMap` instances), and
- on the **dive profile chart**.

Zoom is **cursor-anchored** (zoom toward/away from the pointer). Panning is done
by **click-drag** (already supported everywhere); two-finger drag no longer pans,
because on a trackpad "two-finger scroll" and "two-finger drag-pan" are the same
physical gesture (Flutter delivers both as `PointerPanZoom` events with a `pan`
delta — you cannot have both).

## Decisions (settled)

- **Panning after the change:** click-drag only. Pinch still zooms. Two-finger
  vertical scroll zooms; horizontal scroll component is ignored.
- **Zoom anchor:** under the cursor.
- **Direction:** matches the existing mouse-wheel convention so wheel and trackpad
  agree on the same machine — negative `dy` (scroll up/away) → zoom in. The OS
  natural-scroll setting affects the reported sign identically for wheel and
  trackpad, so they stay consistent.
- **Pointer-kind aware:** only `PointerDeviceKind.trackpad` gestures are
  re-interpreted. Touchscreen pinch / two-finger pan keep flowing through
  flutter_map and the chart's existing handlers untouched (iPad users unaffected).

## Non-goals

- No change to mouse-wheel zoom (already works on both maps and chart).
- No change to touch (tablet) gestures.
- No rotation/north-reset work (that is the separate, unmerged #238/#370 scope).
- Not coordinating with the unmerged #238/#370 branch; this builds independently
  on `main`. A future merge of #370 will need manual reconciliation.

## Architecture

Three units, each independently understandable and testable:

### 1. Pure helper — `lib/core/ui/trackpad_zoom.dart`

Dependency-free function shared by both consumers:

```dart
/// Converts a trackpad two-finger vertical scroll delta (logical px) into an
/// additive zoom-level delta. Negative dy (scroll up/away) -> positive (zoom in),
/// matching the mouse-wheel convention. Sensitivity is tuned so a normal scroll
/// flick changes zoom by roughly one level.
double trackpadScrollZoomDelta(double scrollDy, {double sensitivity = 0.01});
```

- Returns an **additive zoom-level delta** (the natural primitive for maps, whose
  zoom is logarithmic — one level = 2x scale).
- Maps add it to `camera.zoom`.
- The chart applies `pow(2, delta)` to get a multiplicative factor for
  `ProfileChartViewport.zoomedAt`.

Keeping all sign/sensitivity logic here means one unit-tested place; neither
consumer's zoom model leaks into the other.

### 2. Profile chart — modify existing handler

File: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`,
`onPointerPanZoomUpdate` (currently translates by `event.pan` and scales by
`event.scale`).

Change: stop translating; fold vertical scroll into the cumulative zoom factor,
anchored at the cursor (`_trackpadAnchor`, already cursor-positioned at gesture
start). `PointerPanZoomUpdateEvent.pan`/`.scale` are cumulative since gesture
start, matching the existing `_gestureStartViewport` model:

```
final factor = event.scale * pow(2, trackpadScrollZoomDelta(event.pan.dy));
_viewport = _gestureStartViewport.zoomedAt(focal.fx, focal.fy, factor);
```

- Pinch (`event.scale`) still zooms.
- The mouse-wheel path (`onPointerSignal` / `PointerScrollEvent`) is unchanged.
- Click-drag panning (`Listener.onPointerMove`) is unchanged.
- Net effect removes the `vp.pannedBy(event.pan...)` call.

Use cumulative `event.pan` (not `localPan`) per the macOS contamination lesson
from #372 (the chart has no rotation/scale, so global == correct local).

### 3. Maps — new shared wrapper `TrackpadZoomMap`

File: `lib/features/maps/presentation/widgets/trackpad_zoom_map.dart`.

A `StatelessWidget` taking a required `MapController`, the `FlutterMap` `child`,
and optional `minZoom`/`maxZoom`. Wraps `child` in a passive `Listener`:

```
onPointerPanZoomUpdate: (event) {
  if (event.kind != PointerDeviceKind.trackpad) return;   // touch -> flutter_map
  final camera = controller.camera;
  final delta = trackpadScrollZoomDelta(event.panDelta.dy); // per-event delta
  if (delta == 0) return;
  final newZoom = (camera.zoom + delta).clamp(minZoom, maxZoom);
  if (newZoom == camera.zoom) return;
  controller.move(camera.focusedZoomCenter(event.localPosition, newZoom), newZoom);
}
```

- Uses **global `panDelta`** (per-event) for the scroll amount and
  **`localPosition`** for the cursor — per the #372 macOS `localPan`
  contamination lesson.
- `MapCamera.focusedZoomCenter(cursorPos, zoom)` returns the new center that keeps
  the point under the cursor fixed (flutter_map built-in; the same helper #370
  used). It already accounts for map rotation.
- `Listener` is passive (does not enter the gesture arena), so flutter_map's own
  click-drag pan, pinch zoom, and mouse-wheel zoom keep working underneath.
- `minZoom`/`maxZoom` default to flutter_map's camera limits when available;
  call sites can pass the same bounds they give `MapOptions`.

#### Roll-out to 15 maps

Each call site wraps its `FlutterMap` in `TrackpadZoomMap(controller: ..., child: FlutterMap(...))`.
Maps that are currently stateless and do not own a `MapController` get a minimal
`StatefulWidget` / `ConsumerStatefulWidget` conversion to create and hold one
(create in `initState`/field, no `dispose` needed for `MapController` — matches
existing repo pattern; note the repo-wide latent "MapController never disposed"
observation from #370, not introduced here).

The 15 sites:

- `lib/features/maps/presentation/pages/region_picker_page.dart`
- `lib/features/maps/presentation/pages/dive_activity_map_page.dart`
- `lib/features/dive_sites/presentation/pages/site_map_page.dart`
- `lib/features/dive_sites/presentation/pages/site_detail_page.dart`
- `lib/features/dive_sites/presentation/widgets/match_sites_map.dart`
- `lib/features/dive_sites/presentation/widgets/site_map_content.dart`
- `lib/features/dive_sites/presentation/widgets/location_picker_map.dart`
- `lib/features/dive_sites/presentation/widgets/site_list_content.dart`
- `lib/features/dive_log/presentation/widgets/dive_map_content.dart`
- `lib/features/dive_log/presentation/widgets/dive_locations_map.dart`
- `lib/features/trips/presentation/widgets/trip_voyage_map.dart`
- `lib/features/trips/presentation/widgets/trip_overview_tab.dart`
- `lib/features/dive_centers/presentation/pages/dive_center_map_page.dart`
- `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart`
- `lib/features/dive_centers/presentation/widgets/dive_center_map_content.dart`

## Key risk (verify on real hardware)

Whether flutter_map's internal `ScaleGestureRecognizer` *also* reacts to trackpad
pan-zoom, causing double-handling (our zoom + flutter_map's pan from the same
gesture). The #238/#370 work found it does **not** — trackpad `PointerPanZoom`
sends no `PointerDownEvent`, so flutter_map's pointer-down-based recognizer never
engages. This builds on that finding but it requires real-trackpad confirmation.

Fallback if double-handling is observed: gate flutter_map by disabling `pinchMove`
only when the active pointer is a trackpad, or interpose a custom recognizer.

## Testing

- **Unit** (`test/core/ui/trackpad_zoom_test.dart`): `trackpadScrollZoomDelta`
  sign (negative dy → positive delta), zero at dy 0, sensitivity scaling,
  symmetry (equal-and-opposite dy → equal-and-opposite delta).
- **Widget** (`test/features/maps/.../trackpad_zoom_map_test.dart`): synthesize
  `PointerPanZoomStart/Update/End` with `kind: trackpad` and assert the
  `MapController` zoom changes in the right direction and stays clamped; assert a
  `kind: touch` pan-zoom is ignored (zoom unchanged).
- **Chart**: extend viewport tests for the scroll→factor mapping
  (`pow(2, trackpadScrollZoomDelta(dy))`). Note per #372 that full two-finger
  trackpad gestures aren't simulatable in `flutter_test`; the end-to-end chart
  behavior is covered by on-device verification.
- **Verification before completion**: `dart format .`, `flutter analyze` (whole
  project), the targeted test files, and on-device macOS trackpad check of the
  Key risk above.
