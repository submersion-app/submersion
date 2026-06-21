# Map touchpad interaction fixes — design

- **Issue:** [#238 — \[Bug\] Map zoom issues with touchpad](https://github.com/submersion-app/submersion/issues/238)
- **Date:** 2026-06-21
- **Status:** Implemented (PR #370; plan: `docs/superpowers/plans/2026-06-21-map-touchpad-interaction.md`); device verification pending
- **Map library:** `flutter_map ^8.2.2`

## Problem

The reporter raised three distinct complaints about the interactive map:

1. **Trackpad pinch-to-zoom is not centered.** The zoom anchor lands off-screen (down and to the right), so zooming severely recenters the map. This makes the map hard to use with a laptop trackpad.
2. **Accidental rotation on touch screens.** It is too easy to rotate the map by accident while pinching. The reporter asked for a larger rotation deadband or the ability to disable rotation, and — if rotation stays — a button to reset to north-up.
3. **Interaction model preference (noted, not adopted).** The reporter would prefer click-drag to pan + two-finger-scroll to zoom. We are *keeping* pinch-to-zoom (see Decisions).

### Root causes (verified against flutter_map 8.2.2 source)

- **Off-center trackpad zoom is an upstream Flutter engine bug.** On a trackpad there are no on-screen touch points, so the gesture focal point computed by `ScaleGestureRecognizer` is synthesized from `PointerPanZoom` events, which the engine reports incorrectly on desktop (see [flutter/flutter#136029](https://github.com/flutter/flutter/issues/136029) — "focal point changes a lot and pointerCount is 1 despite using two fingers"; also [flutter_map#1227](https://github.com/fleaflet/flutter_map/issues/1227), [#1354](https://github.com/fleaflet/flutter_map/issues/1354)). flutter_map pins the zoom to that bad focal point via `_calculatePinchZoomAndMove` (`map_interactive_viewer.dart:686`), so the map flies off. **Crucially, the raw `PointerPanZoomStartEvent.localPosition` (the cursor) is reliable** — only the recognizer's *computed multi-touch focal point* is wrong. The fix exploits this distinction.
- **The rotation deadband is inert by default.** `InteractionOptions.rotationThreshold` (default 20°) only takes effect when `enableMultiFingerGestureRace == true` (`interaction.dart:26-27`; gating at `map_interactive_viewer.dart:598-612`). The default is `false`, so `_getMultiFingerGestureFlags` returns `MultiFingerGesture.all` (`:480-494`) and rotation applies simultaneously with zoom on any tiny twist — no deadband at all.
- **Config has drifted across maps.** Of 17 `FlutterMap` instances, 5 disable rotation, 2 force `InteractiveFlag.all`, and 7 omit `interactionOptions` and inherit the rotation-on default. There is no shared map wrapper, so identical gestures behave differently per screen.

## Decisions (from product review)

1. **Keep pinch-to-zoom; make trackpad/mouse zoom anchor at the cursor (zoom-to-cursor), not the map center.** Two-finger-scroll-*to-zoom* (replacing pan with zoom) is out of scope.
2. **Keep rotation on overview maps**, but with a real deadband and a reset-to-north button. **Detail maps and pickers are locked to north-up** (no rotation, no reset button).

## Core principle: key off the active pointer kind, not the platform

The trackpad-vs-touch split happens **within** a single device: a Windows/Linux 2-in-1, or an iPad with a Magic Keyboard trackpad. An iPad is `TargetPlatform.iOS` ("mobile") yet still exhibits the trackpad focal-point bug. Therefore behavior is chosen from the **active `PointerDeviceKind`** (`touch` vs `trackpad`/`mouse`), not from `defaultTargetPlatform` (which is only the initial guess before the first pointer event).

| Pointer | Zoom path | Anchor |
|---|---|---|
| Touch (finger) | flutter_map pinch (`pinchZoom`+`pinchMove`) | finger focal point (correct on touch) |
| Trackpad | **our custom handler** on `PointerPanZoom*` | cursor (`localPosition`) — reliable |
| Mouse wheel | flutter_map `scrollWheelZoom` (`_onPointerSignal`) | cursor (`localPosition`) — reliable |

## Design

New file: `lib/features/maps/presentation/widgets/map_interaction.dart` — a pure options function, a detector widget, and a reset-north control.

### Component 1a — Pure function `mapInteractionOptions`

Single source of truth for flutter_map's gesture flags. Pure and unit-testable. For **non-touch**, all multi-finger handling (and fling) is disabled because our detector takes over trackpad gestures; flutter_map keeps only mouse-wheel zoom and click-drag pan.

```dart
InteractionOptions mapInteractionOptions({
  required bool isTouch,
  required bool allowRotation,
}) {
  final gestureRotate = allowRotation && isTouch;

  final int flags;
  if (isTouch) {
    // Touch focal points are correct, so flutter_map handles pinch natively.
    flags = InteractiveFlag.drag |
        InteractiveFlag.flingAnimation |
        InteractiveFlag.pinchMove |   // keeps zoom anchored at the fingers
        InteractiveFlag.pinchZoom |
        InteractiveFlag.doubleTapZoom |
        InteractiveFlag.doubleTapDragZoom |
        InteractiveFlag.scrollWheelZoom |
        (gestureRotate ? InteractiveFlag.rotate : 0);
  } else {
    // Trackpad/mouse: MapInteractionDetector handles pinch (zoom-to-cursor) and
    // two-finger scroll (pan) itself, so flutter_map's multi-finger + fling
    // paths are disabled to avoid double-handling and the buggy focal point.
    // Mouse-wheel zoom-to-cursor (scrollWheelZoom) and click-drag pan (drag)
    // stay with flutter_map.
    flags = InteractiveFlag.drag |
        InteractiveFlag.doubleTapZoom |
        InteractiveFlag.doubleTapDragZoom |
        InteractiveFlag.scrollWheelZoom;
  }

  return InteractionOptions(
    flags: flags,
    enableMultiFingerGestureRace: gestureRotate, // required for the deadband
    rotationThreshold: 30.0,                      // wider than the 20.0 default
    cursorKeyboardRotationOptions: allowRotation
        ? const CursorKeyboardRotationOptions()   // Ctrl+drag rotate on desktop
        : CursorKeyboardRotationOptions.disabled(),
    // keyboardOptions left default: enableQERotating already defaults to false.
  );
}
```

Resulting matrix:

| Input | `pinchZoom`/`pinchMove` | `rotate` | `flingAnimation` | race | cursor-rotate |
|---|---|---|---|---|---|
| touch, rotation allowed | ✅ | ✅ | ✅ | ✅ | enabled |
| touch, rotation off | ✅ | ❌ | ✅ | ❌ | disabled |
| trackpad/mouse, rotation allowed | ❌ | ❌ | ❌ | ❌ | enabled (Ctrl+drag) |
| trackpad/mouse, rotation off | ❌ | ❌ | ❌ | ❌ | disabled |

`drag`, `doubleTapZoom`, `doubleTapDragZoom`, `scrollWheelZoom` are always enabled.

### Component 1b — `MapInteractionDetector` (pointer tracking + custom trackpad zoom)

A `StatefulWidget` that (1) tracks the active pointer kind and rebuilds its child with the right `InteractionOptions`, and (2) handles trackpad `PointerPanZoom*` events itself to give zoom-to-cursor. It needs the `MapController` to drive the camera.

```dart
class MapInteractionDetector extends StatefulWidget {
  final bool allowRotation;
  final MapController mapController;
  final Widget Function(BuildContext context, InteractionOptions options) builder;
  const MapInteractionDetector({
    super.key,
    required this.allowRotation,
    required this.mapController,
    required this.builder,
  });
}
```

**Pointer-kind tracking** (chooses flutter_map's flags):
- Initial `isTouch` guess: `true` for iOS/Android, `false` otherwise; corrected on first event.
- `Listener.onPointerDown` → `kind == touch`; `onPointerHover` → `false`; `onPointerPanZoomStart` → `false`.
- `setState` only when the kind changes. A trackpad gesture is always preceded by hover, so by the time a pinch starts `isTouch` is already `false` and flutter_map's flags already exclude `pinchZoom` — no double-handling.

**Custom trackpad handler** (`Listener.onPointerPanZoom*`; `PointerPanZoom` events are emitted only by trackpads):
- `onPointerPanZoomStart(e)`: record `startZoom = mapController.camera.zoom`, `anchor = e.localPosition`, `lastPan = Offset.zero`.
- `onPointerPanZoomUpdate(e)`:
  - **Zoom-to-cursor:** `targetZoom = camera.clampZoom(startZoom + log(e.scale) / ln2)`, then `center = camera.focusedZoomCenter(anchor, targetZoom)` (the same math the reliable scroll-wheel path uses).
  - **Pan:** apply the incremental `e.localPan - lastPan` (rotated by `camera.rotationRad`) so two-finger scroll still pans; update `lastPan`.
  - `mapController.move(center, targetZoom)`.
- `onPointerPanZoomEnd`: clear gesture state.

The detector wraps the `FlutterMap` such that the map fills the detector's box, so `localPosition` is in the map's viewport coordinate space (matching `focusedZoomCenter`'s expectation). Exact pan sign and clamping are finalized under TDD.

> Why not let flutter_map do it: flutter_map's own `Listener` does not subscribe to `onPointerPanZoom*` (only its `ScaleGestureRecognizer` does, via the gesture arena). A passive outer `Listener` therefore receives these events cleanly, and with `pinchZoom`/`pinchMove`/`rotate`/`flingAnimation` off for non-touch, the recognizer does nothing (`_handleScaleUpdate` early-outs because `hasMultiFinger` is false and `_dragMode` is false for pan/zoom pointers).

### Component 1c — `MapResetNorthButton`

A child map layer (in `FlutterMap.children`) that self-hides when north-up.

- Reads live rotation via `MapCamera.of(context).rotation` (degrees); rebuilds on camera change.
- Show/hide decision extracted to a pure helper `bool shouldShowResetNorth(double rotationDeg, {double toleranceDeg = 0.5})` for unit testing.
- When shown: a top-right `FloatingActionButton.small` with a `Transform.rotate`d compass icon reflecting the bearing; `onPressed` → `MapController.of(context).rotate(0)`. Instant reset in v1 (no animation dependency).

### Component 2 — Application policy across maps

| Category | Maps | `allowRotation` | Reset button | Detector |
|---|---|---|---|---|
| Overview / exploration | `site_map_page`, `site_map_content`, `dive_map_content`, `dive_center_map_page`, `dive_center_map_content`, `dive_activity_map_page`, `trip_voyage_map` | `true` | yes | yes |
| Detail (locked north-up) | `site_detail_page` (inline + fullscreen), `dive_center_detail_page` (inline + fullscreen), `dive_locations_map` | `false` | no | yes |
| Pickers (north-up matters) | `location_picker_map`, `match_sites_map` | `false` | no | yes |
| Already correct / unchanged | `region_picker_page`, `site_list_content` thumbnail, `trip_overview_tab` card | n/a | no | no |

Every interactive map is wrapped, passing its existing `MapController`:

```dart
MapInteractionDetector(
  allowRotation: true, // false for detail maps and pickers
  mapController: _mapController,
  builder: (context, interactionOptions) => FlutterMap(
    mapController: _mapController,
    options: MapOptions(
      // ...existing options (initialCenter, zoom, onTap, cameraConstraint)...
      interactionOptions: interactionOptions,
    ),
    children: [
      // ...existing layers...
      if (/* allowRotation */ true) const MapResetNorthButton(),
    ],
  ),
)
```

Notes:
- **Detail maps stay north-up-locked** (`allowRotation: false`) per product decision — both their inline-card and fullscreen `FlutterMap` instances. They still get the detector for trackpad zoom-to-cursor.
- `dive_locations_map` is interactive only when its `interactive` flag is `true` (passed `true` from `surface_gps_section`). The detector and shared options apply only then; when `interactive: false` it keeps `InteractiveFlag.none` and is not wrapped.
- `region_picker_page` is left unchanged: its flags are already `pinchZoom | doubleTapZoom` (no `pinchMove`), so pinch already resolves to center — no off-center bug and no rotation. Applying the shared options would wrongly enable drag/pan and conflict with its `RegionSelector` drag overlay.
- The static maps (`InteractiveFlag.none`) are untouched.

### Component 3 — End-state behavior matrix

| Pointer | Gesture | Result |
|---|---|---|
| Touch | pinch | Focal-point zoom (unchanged; what the reporter liked) |
| Touch | two-finger twist | Rotate only past a 30° deadband, overview maps only; reset button appears |
| Trackpad | pinch | **Zoom to cursor** |
| Trackpad | two-finger scroll | Pan |
| Trackpad/Mouse | click-drag | Pan |
| Mouse | scroll wheel | Zoom to cursor (unchanged) |
| Trackpad/Mouse | Ctrl+drag (overview only) | Rotate; reset button appears |

## Testing strategy (TDD)

- **Unit — `mapInteractionOptions`:** for all four `isTouch` × `allowRotation` combinations assert flag presence — `pinchZoom`/`pinchMove` iff `isTouch`; `rotate` iff `isTouch && allowRotation`; `flingAnimation` iff `isTouch`; `enableMultiFingerGestureRace` iff `isTouch && allowRotation`; `rotationThreshold == 30.0`; `scrollWheelZoom` and `drag` always present; `cursorKeyboardRotationOptions` disabled iff `!allowRotation`.
- **Unit — `shouldShowResetNorth`:** false at 0°/≈360°/within tolerance; true at 15°, 90°, 200°.
- **Widget — `MapInteractionDetector` pointer kind:** dispatch a touch `PointerDownEvent` then a mouse `PointerHoverEvent`; assert the produced options' `pinchZoom` flag flips accordingly.
- **Widget — trackpad zoom-to-cursor:** pump a real `FlutterMap` + controller inside the detector; drive a `TestPointer(kind: trackpad)` `panZoomStart`/`panZoomUpdate(scale: >1)` anchored off-center; assert `controller.camera.zoom` increased and the geographic point under the anchor stayed (approximately) under the anchor.
- **Widget — `MapResetNorthButton`:** pump inside a `FlutterMap`; absent at rotation 0; rotate via the controller → button appears; tap → rotation returns to 0.
- **Regression:** run existing map-related widget tests.

## Out of scope

- Two-finger-scroll-*to-zoom* (replacing the pan gesture with zoom).
- Animated rotation-reset (instant is sufficient for v1).
- Rotation on detail maps / pickers (locked north-up by decision).
- Changes to `region_picker_page` and the static maps.

## Risks & trade-offs

- **Custom trackpad handling adds code that cooperates with flutter_map.** Mitigated by: disabling flutter_map's multi-finger/fling paths for non-touch (so only our handler moves the camera), reusing flutter_map's own `focusedZoomCenter`/`clampZoom`/`move`, and relying on the documented fact that flutter_map's `Listener` ignores `PointerPanZoom*`.
- **One-frame edge case:** if the very first interaction is a trackpad pinch with no preceding hover, flags may lag one frame and both paths could act once. In practice a cursor hover always precedes a trackpad gesture, so `isTouch` is already `false`; the glitch self-corrects on the next frame.
- **Coordinate space:** the detector must wrap the map so the `FlutterMap` fills its box; otherwise `localPosition` would be offset. Verified per-map during implementation.
- **`MapResetNorthButton` depends on `MapController.of`/`MapCamera.of`** — both exist in 8.2.2 and resolve from child layers (the existing `HeatMapLayer` already uses `MapCamera.of`).

## Affected files

New:
- `lib/features/maps/presentation/widgets/map_interaction.dart`
- `test/features/maps/map_interaction_test.dart` (+ widget tests; location per existing test layout)

Modified (wrap in `MapInteractionDetector` passing the `MapController`, use shared options, add reset button on overview maps):
- `lib/features/dive_sites/presentation/pages/site_map_page.dart`
- `lib/features/dive_sites/presentation/widgets/site_map_content.dart`
- `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (north-up locked; both maps)
- `lib/features/dive_sites/presentation/widgets/location_picker_map.dart`
- `lib/features/dive_sites/presentation/widgets/match_sites_map.dart`
- `lib/features/dive_log/presentation/widgets/dive_map_content.dart`
- `lib/features/dive_log/presentation/widgets/dive_locations_map.dart` (only when `interactive`; north-up locked)
- `lib/features/trips/presentation/widgets/trip_voyage_map.dart`
- `lib/features/dive_centers/presentation/pages/dive_center_map_page.dart`
- `lib/features/dive_centers/presentation/widgets/dive_center_map_content.dart`
- `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart` (north-up locked; both maps)
- `lib/features/maps/presentation/pages/dive_activity_map_page.dart`

## References

- flutter/flutter#136029 — Windows trackpad pinch wrong focal point
- flutter_map#1227 — pinch zoom wrong centre focal point
- flutter_map#1354 — macOS multitouch focal-point issues
- flutter_map#2001 — request: zoom to map center instead of focal point
