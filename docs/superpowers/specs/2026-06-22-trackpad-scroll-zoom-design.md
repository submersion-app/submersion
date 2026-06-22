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
- **Direction:** two-finger scroll **up zooms out**, **down zooms in** (per user
  preference, set after device testing). This is the opposite of the mouse-wheel
  path (up = zoom in), which is left unchanged; the trackpad-only flip lives in
  `trackpadScrollZoomDelta`.
- **Pointer-kind aware:** only `PointerDeviceKind.trackpad` gestures are
  re-interpreted. Touchscreen pinch / two-finger pan keep flowing through
  flutter_map and the chart's existing handlers untouched (iPad users unaffected).
- **Embedded-map scroll conflict (added):** when a map sits inside a scrollable
  page, a two-finger trackpad scroll over the map zooms the map and the page does
  NOT scroll ("map captures the gesture when hovered"); scrolling elsewhere
  scrolls the page. Trackpad pinch over the map also zooms the map.

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
/// additive zoom-level delta. Scroll up -> negative (zoom out), scroll down ->
/// positive (zoom in). Sensitivity is tuned so a normal scroll flick changes
/// zoom by roughly one level.
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

**Revised during implementation (verified by probes).** Two problems had to be
solved together:

1. *Clobber:* a passive `Listener` does not work. flutter_map's scale recognizer
   reacts to trackpad pan-zoom and (via `pinchMove`) pins the camera to the
   gesture-start position every frame, reverting any `move()` we apply.
2. *Page-scroll capture* (added requirement): over an embedded map inside a
   scrollable page, a trackpad two-finger scroll both zooms the map and scrolls
   the page. The agreed behavior is "the map captures the gesture when hovered."

Both reduce to one fix: **win the gesture arena** for trackpad pan-zoom. The
arena has one winner, so winning rejects *both* flutter_map's scale recognizer
(no clobber) *and* the enclosing scrollable (no page scroll). But a single winner
also means flutter_map can no longer drive trackpad pinch — so our winner must
itself handle pinch as well as scroll.

So `TrackpadZoomMap` is a `StatelessWidget` wrapping `child` in a
`RawGestureDetector` with a custom `_TrackpadZoomGestureRecognizer`:

```dart
TrackpadZoomMap({
  required MapController controller,
  required Widget child,
  double minZoom = 1.0,
  double maxZoom = 22.0,
})
```

`_TrackpadZoomGestureRecognizer extends OneSequenceGestureRecognizer`
(`supportedDevices: {trackpad}`):

- `addAllowedPointer` (ordinary pointers) is a **no-op**, so a trackpad
  click-drag still pans via flutter_map. Only `addAllowedPointerPanZoom` is
  claimed: it `startTrackingPointer` + `resolve(accepted)` **eagerly**, winning
  the arena before flutter_map or the scrollable can.
- On each `PointerPanZoomUpdateEvent` it reports an additive zoom-level delta =
  `trackpadScrollZoomDelta(event.panDelta.dy)` (scroll) `+ log2(scale / lastScale)`
  (pinch). The wrapper applies it: `newZoom = (camera.zoom + delta).clamp(...)`,
  then `controller.move(camera.focusedZoomCenter(event.localPosition, newZoom), newZoom)`.
- Uses **global `panDelta`** for the scroll amount and **`localPosition`** for
  the cursor — per the #372 macOS `localPan` contamination lesson.
- `MapCamera.focusedZoomCenter(cursorPos, zoom)` keeps the point under the cursor
  fixed (flutter_map built-in; accounts for map rotation).

Touch (regular pointers, not pan-zoom) and mouse wheel (pointer signal, claimed
by flutter_map's own resolver) are untouched: touch pinch/one-finger pan and
wheel-zoom keep working. No interaction-flag changes are needed, so call sites
keep their existing `MapOptions` and just wrap with `TrackpadZoomMap(controller:
..., child: FlutterMap(...))`.

Not unit-testable: that the arena win actually suppresses the parent scroll —
`flutter_test`'s `Scrollable` does not scroll on synthetic `panZoom` events
(verified). Covered by on-device verification (Task 6).

#### Roll-out to 15 files / 17 maps

Each call site wraps its `FlutterMap` in
`TrackpadZoomMap(controller: ..., child: FlutterMap(...))` — no `MapOptions`/flag
changes needed (the recognizer wins the arena instead of toggling flags).
Maps that are currently stateless and do not own a `MapController` get a minimal
`StatefulWidget` / `ConsumerStatefulWidget` conversion to create and hold one
(create as a field, no `dispose` needed for `MapController` — matches existing
repo pattern; note the repo-wide latent "MapController never disposed"
observation from #370, not introduced here).

The 15 files (two contain 2 maps each — `site_detail_page` and
`dive_center_detail_page` — for 17 maps total):

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

## Key risk — RESOLVED in implementation

The risk (flutter_map double-handling the trackpad gesture) **materialized**:
flutter_map's `ScaleGestureRecognizer` does engage on trackpad `PointerPanZoom`
and its `pinchMove` handler pins the camera to gesture-start every frame,
reverting our zoom. Verified with probes. Resolved by `TrackpadZoomMap`'s
arena-winning `TrackpadZoomGestureRecognizer` (section 3), which rejects
flutter_map's scale recognizer outright. The earlier #370 note
("no double-handling, trackpad sends no PointerDownEvent") did not hold for
flutter_map 8.2.2; `ScaleGestureRecognizer.addAllowedPointerPanZoom` accepts the
gesture without a pointer-down. Resolved by `TrackpadZoomGestureRecognizer`
eagerly winning the gesture arena (rejecting flutter_map's scale recognizer and
any enclosing scrollable) — not by a flag swap. On-device macOS confirmation is
still part of Task 6 (smooth progressive zoom).

## Testing

- **Unit** (`test/core/ui/trackpad_zoom_test.dart`): `trackpadScrollZoomDelta`
  sign (scroll down / positive dy → positive delta = zoom in), zero at dy 0,
  sensitivity scaling, symmetry (equal-and-opposite dy → equal-and-opposite
  delta).
- **Widget** (`test/features/maps/.../trackpad_zoom_map_test.dart`): synthesize
  `PointerPanZoomStart/Update/End` with `kind: trackpad` and assert the
  `MapController` zoom changes in the right direction (scroll down zooms in,
  progressively), pinch zooms, and a trackpad click-drag is not claimed by the
  recognizer.
- **Chart**: extend viewport tests for the scroll→factor mapping
  (`pow(2, trackpadScrollZoomDelta(dy))`). Note per #372 that full two-finger
  trackpad gestures aren't simulatable in `flutter_test`; the end-to-end chart
  behavior is covered by on-device verification.
- **Verification before completion**: `dart format .`, `flutter analyze` (whole
  project), the targeted test files, and on-device macOS trackpad check of the
  Key risk above.
