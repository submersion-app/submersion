# Dive profile chart zoom & navigation — design

- **Source:** Direct user report (no tracked GitHub issue yet): "Zooming in on the dive profile chart always keeps the focus anchored in the upper-left corner. Navigating a zoomed-in chart is also tedious and unintuitive."
- **Date:** 2026-06-21
- **Status:** Implemented in PR #372 — see the implementation plan at `docs/superpowers/plans/2026-06-21-dive-profile-chart-zoom-navigation.md`; macOS device-verified.
- **Chart widget:** `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (~3,730 lines)
- **Chart library:** `fl_chart ^1.1.1` (zoom/pan is hand-rolled on top of it, not fl_chart's transform)
- **Sibling spec:** `2026-06-21-map-touchpad-interaction-design.md` — shares the "key off `PointerDeviceKind`, anchor zoom at the cursor" philosophy. Read both together.

## Problem

The interactive dive profile chart (depth-over-time, shown on the dive detail page and the master/detail panel) has two interaction defects:

1. **Zoom always anchors to the upper-left corner.** Zooming in via the legend buttons, the mouse wheel, or double-tap shrinks the visible window toward `(time = 0, surface)` instead of toward the cursor, the pinch point, or even the chart center.
2. **Navigating a zoomed-in chart is tedious and unintuitive.** Once zoomed, there is no drag-to-pan and no scrollbar; the only way to move the window is a two-finger scale gesture or a full zoom reset.

### Root causes (verified against the current code)

The chart does not use fl_chart's built-in transform. It keeps its own `_zoomLevel` + normalized `_panOffsetX/_panOffsetY` in widget `State` and, every build, computes the visible `minX/maxX/minY/maxY` window and hands it to `LineChartData` (which clips with `FlClipData.all()`).

- **Upper-left anchoring is baked into the math.** The window's edges are computed as `visibleMinX = _panOffsetX * totalMaxTime` and `visibleMinDepth = _panOffsetY * totalMaxDepth` (`dive_profile_chart.dart:1238-1246`). The button, wheel, and double-tap zoom paths change **only `_zoomLevel`** and then clamp the offsets; none of them adjusts `_panOffsetX/Y` to keep the cursor or center fixed. With the default offsets at `0`, the left/top edges stay pinned at `t = 0` / surface while the window shrinks — i.e. zoom toward the upper-left.
  - `_zoomIn()` / `_zoomOut()`: `dive_profile_chart.dart:893-905`
  - Mouse-wheel zoom (`Listener.onPointerSignal`): `:1137-1153` — `event.localPosition` is available but **unused**.
  - Double-tap (`onDoubleTap`): `:1128-1136` — jumps to `_zoomLevel = 2.0` (or resets) with no focal anchoring.
  - Pinch (`onScaleUpdate`): `:1087-1127` — folds the focal point into a pan *delta* only; the zoom itself is `_previousZoom * details.scale`, so the pinch center is not held fixed either. The pan math divides by `constraints.maxWidth/Height` (`:1112`), the **full widget box**, not the inner plot area.
- **No pan affordance when zoomed.** Single-finger / mouse drag is deliberately reserved for tooltip scrubbing (`LineTouchData.touchCallback`, `:1584-1617`); `onScaleUpdate` early-returns for `pointerCount < 2` (`:1091`). So only a multi-pointer scale gesture pans, and only when `_zoomLevel > 1.0`. On desktop there is no mouse-drag pan and no scrollbar at all.

### State today (unchanged by this design unless noted)

- Zoom is **uniform on both axes** — a single `_zoomLevel` scales time and depth together (`:1239-1240`).
- Zoom/pan is **local widget state** in `_DiveProfileChartState` (`:457-469`), not a Riverpod provider. It is per-instance and ephemeral. There are three live instances: `dive_detail_page.dart:1249` and `:4898`, and `dive_profile_panel.dart:364`.
- The depth axis is **inverted** by negating values (`minY: -visibleMaxDepth`, `maxY: -visibleMinDepth`, `:1313-1316`).
- Tick intervals adapt to the visible range via `_calculateTimeInterval` / `_calculateDepthInterval` (`:2811-2824`), keyed off `visibleRangeX/Y` — they keep working unchanged once those values come from the new viewport.
- A shared scrub index lives in `profileTrackingIndexProvider` (`StateProvider.family<int?, String>` keyed by dive ID); a "zoom hint" string shows while `_zoomLevel > 1.0` (`:1052-1063`).

## Decisions (from product review)

1. **Keep the uniform 2-D zoom model** (time and depth scale together), but make zoom **anchor under the cursor** (mouse/trackpad) or **under the pinch focal point** (touch), never the corner. Switching to time-only/X-axis zoom was considered and explicitly rejected.
2. **Add intuitive navigation** for a zoomed-in chart, resolving the long-standing collision between "drag to pan" and "drag to scrub the tooltip" by **branching on the active pointer kind** and reserving one-finger touch drag for scrubbing.
3. **Implementation follows the map sibling spec's house pattern**: branch on `PointerDeviceKind`, take trackpad/wheel zoom through a passive `Listener` keyed to the reliable cursor `localPosition`, and lift the zoom/pan/anchor math into a small, immutable, unit-tested value object.

## Core principle: key off the active pointer kind, not the platform

The same single device can be both "touch" and "trackpad" — an iPad with a Magic Keyboard trackpad is `TargetPlatform.iOS` yet needs cursor/hover behavior. So a single-pointer drag means **pan** when the live pointer is a mouse and **scrub** when it is a finger. Behavior is chosen from the **active `PointerDeviceKind`**, corrected on the first real pointer event, not from `defaultTargetPlatform`.

## Interaction model (end state)

**Desktop (mouse / trackpad):**

| Input | Action | Anchor |
|---|---|---|
| Hover | Move tooltip (read depth/time/values) | cursor |
| Click-drag | Pan (2-D) | — |
| Mouse wheel | Zoom | **cursor** (`localPosition`) |
| Trackpad pinch | Zoom | **cursor** (`localPosition`) |
| Trackpad two-finger scroll | Pan | — |

**Touch:**

| Input | Action | Anchor |
|---|---|---|
| One-finger drag | Scrub tooltip (**unchanged from today**) | — |
| Two-finger pinch | Zoom | pinch focal point |
| Two-finger drag | Pan | — |
| Double-tap-and-**hold**, then drag | Pan | — |
| Double-tap (quick, no hold) | Zoom toggle (in / reset) | **tap point** |

A quick double-tap and a double-tap-with-hold are distinguishable because the held variant is followed by movement while the finger stays down.

## Design

New file: `lib/features/dive_log/presentation/widgets/profile_chart_viewport.dart` — a pure immutable value object plus two pure helpers. All gesture handling in `dive_profile_chart.dart` is rewritten to map an old viewport to a new one.

### Component 1 — `ProfileChartViewport` (immutable value object)

Models the visible window as normalized fractions `[0,1]` of the total data range, independent of pixel size and of the data totals. It is the single place anchoring can be right or wrong.

```dart
@immutable
class ProfileChartViewport {
  final double zoom;     // >= 1.0
  final double offsetX;  // normalized left edge, in [0, 1 - 1/zoom]
  final double offsetY;  // normalized top edge (0 = surface), in [0, 1 - 1/zoom]
  const ProfileChartViewport({this.zoom = 1, this.offsetX = 0, this.offsetY = 0});

  static const double minZoom = 1.0, maxZoom = 10.0;
  static const ProfileChartViewport reset = ProfileChartViewport();
  bool get isZoomed => zoom > 1.0;

  double get visibleWidth  => 1.0 / zoom; // fraction of total time range
  double get visibleHeight => 1.0 / zoom; // fraction of total depth range

  /// Zoom by [factor] (>1 = in) keeping the data point under the focal point fixed.
  /// focalX/focalY are fractions (0..1) of the VISIBLE PLOT AREA under the cursor/pinch
  /// (0 = left / top edge).
  ProfileChartViewport zoomedAt(double focalX, double focalY, double factor) {
    final newZoom = (zoom * factor).clamp(minZoom, maxZoom);
    if (newZoom == zoom) return this;
    final anchorX = offsetX + focalX / zoom; // data fraction under focus, before zoom
    final anchorY = offsetY + focalY / zoom;
    return ProfileChartViewport(
      zoom: newZoom,
      offsetX: anchorX - focalX / newZoom,   // keep it under focus, after zoom
      offsetY: anchorY - focalY / newZoom,
    )._clamped();
  }

  /// Pan by a normalized delta (fractions of the TOTAL range).
  ProfileChartViewport pannedBy(double dx, double dy) =>
      ProfileChartViewport(zoom: zoom, offsetX: offsetX + dx, offsetY: offsetY + dy)._clamped();

  ProfileChartViewport _clamped() {
    final maxOff = 1.0 - 1.0 / zoom;
    return ProfileChartViewport(
      zoom: zoom,
      offsetX: offsetX.clamp(0.0, maxOff),
      offsetY: offsetY.clamp(0.0, maxOff),
    );
  }
}
```

Derivation of the anchor term: the visible window in normalized data coords is `[offsetX, offsetX + 1/zoom]`. The data fraction under a focal at `focalX` of the visible width is `a = offsetX + focalX/zoom`. To keep `a` at the same fraction after zooming to `newZoom`, solve `a = offsetX' + focalX/newZoom`, giving `offsetX' = a - focalX/newZoom`. The whole upper-left bug is the absence of this `- focalX/newZoom` term today.

The widget keeps one field, `ProfileChartViewport _viewport = ProfileChartViewport.reset`, and re-sources the existing window computation (`dive_profile_chart.dart:1238-1246`) from it:

```dart
final visibleMinX     = _viewport.offsetX * totalMaxTime;
final visibleMaxX     = (_viewport.offsetX + _viewport.visibleWidth)  * totalMaxTime;
final visibleMinDepth = _viewport.offsetY * totalMaxDepth;
final visibleMaxDepth = (_viewport.offsetY + _viewport.visibleHeight) * totalMaxDepth;
// existing axis inversion (negation) at :1313-1316 is unchanged.
```

The viewport works purely in normalized "fraction of total, 0 = surface" space; the depth-axis inversion remains a later, untouched step.

### Component 2 — pure helpers (focal mapping + drag intent)

Both live in `profile_chart_viewport.dart`, pure and unit-testable.

**Plot-rect focal mapping.** fl_chart reserves gutters for axis titles (left depth labels, bottom time labels, optional right-axis metric). A gesture's `localPosition` is in the full widget box, but the data window maps only to the inner plot rect, so the focal fraction must be computed against the plot rect — this is the accuracy fix that makes zoom land exactly under the cursor:

```dart
({double fx, double fy}) chartFocalFraction(
  Offset localPos, Size box,
  {required double left, required double right, required double top, required double bottom}) {
  final plotW = box.width  - left - right;
  final plotH = box.height - top  - bottom;
  return (
    fx: ((localPos.dx - left) / plotW).clamp(0.0, 1.0),
    fy: ((localPos.dy - top)  / plotH).clamp(0.0, 1.0),
  );
}
```

The reserved extents are the values we already pass to `SideTitles.reservedSize` / axis-title configs, so the plot rect is derived each build and recomputed if a toggle (e.g. the right-axis metric) changes a gutter.

**Drag intent.** A single pure decision function replaces the scattered `pointerCount`/platform checks:

```dart
enum ChartDragIntent { pan, scrub, zoomPan, none }

ChartDragIntent chartDragIntent({
  required PointerDeviceKind kind,
  required int pointerCount,
  required bool doubleTapHold,
}) {
  if (pointerCount >= 2) return ChartDragIntent.zoomPan;          // pinch + pan together
  if (doubleTapHold)     return ChartDragIntent.pan;              // double-tap-hold drag
  return kind == PointerDeviceKind.touch
      ? ChartDragIntent.scrub                                      // one-finger touch = scrub
      : ChartDragIntent.pan;                                       // mouse click-drag = pan
}
```

### Component 3 — input routing in `dive_profile_chart.dart`

A passive outer `Listener` (which never competes in the gesture arena) handles the desktop/trackpad paths reliably; an inner `GestureDetector` (`onScale*`, `onDoubleTapDown`, `onDoubleTap`) handles touch and mouse-drag. Active pointer kind is tracked exactly like the map spec: an initial platform guess, corrected on the first `onPointerHover` / `onPointerDown` / `onPointerPanZoomStart`, with `setState` only when the kind changes.

| Source | Handler | Viewport op |
|---|---|---|
| Mouse wheel | `Listener.onPointerSignal` (`PointerScrollEvent`) | `zoomedAt(focalFromCursor, up ? 1.1 : 1/1.1)` |
| Trackpad pinch | `Listener.onPointerPanZoomUpdate` (`e.scale`) | `zoomedAt(focalFromCursor, scaleDelta)` |
| Trackpad two-finger scroll | same event (`e.localPan`) | `pannedBy(panDelta)` — one event does both |
| Mouse hover / exit | `Listener.onPointerHover` / `onExit` | set / clear tooltip tracking index (no viewport change) |
| Mouse click-drag | `GestureDetector.onScaleUpdate`, `pointerCount==1`, kind != touch | `pannedBy(focalPointDelta)` |
| Touch one-finger drag | `onScaleUpdate`, `pointerCount==1`, kind == touch | none — fall through to fl_chart scrub (unchanged) |
| Touch pinch + two-finger drag | `onScaleUpdate`, `pointerCount>=2` | `zoomedAt(focal, e.scale)` **and** `pannedBy(focalDelta)` |
| Touch double-tap (quick) | `onDoubleTap` | zoom toggle, anchored at the tap point via `zoomedAt` |
| Touch double-tap-hold + drag | `_doubleTapHold` flag + `onScaleUpdate` | `pannedBy(focalDelta)` |

Why trackpad zoom goes through the passive `Listener`, not `onScaleUpdate`: a trackpad pinch is delivered as `PointerPanZoom*` events whose **`localPosition` (the cursor) is reliable**, whereas `ScaleGestureRecognizer`'s synthesized multi-touch focal point is buggy on desktop (the basis the map spec relies on). fl_chart's own recognizers ignore `PointerPanZoom*`, so a passive outer `Listener` receives them cleanly without stealing gestures the chart needs.

Pixel-to-normalized conversions live in the widget (they need plot dimensions); the viewport stays dimensionless. For a content drag of `dpx` pixels, the normalized pan is `-dpx / plotW / zoom` (drag content right → window moves left).

Continuous gestures (touch pinch/pan via `onScaleUpdate`, trackpad pinch/scroll via `onPointerPanZoomUpdate`) report **cumulative** `scale`/`pan` measured from gesture start, so their handlers snapshot the gesture-start `ProfileChartViewport` (the way today's code records `_previousZoom`/`_previousPan` at `onScaleStart`, `:1087-1090`) and apply the cumulative `scale`/`pan` against that snapshot on each update — not against the live viewport, which would compound. The discrete mouse-wheel path instead applies its `1.1` step incrementally per event. Exact pan sign per source (mouse drag vs two-finger scroll) and the slop/timeout thresholds for double-tap-hold are finalized under TDD.

### Component 4 — coexistence, edges, and "free" wins

- **Tooltip coexistence.** Desktop hover maps cursor-X → nearest sample and feeds the *existing* tooltip path (`profileTrackingIndexProvider` + fl_chart's showing-indicator), so hover renders identically to today's touch scrub; `onExit` clears it. Touch one-finger scrub is untouched. Panning uses a different gesture from the tooltip on every device (desktop: a drag has no hover; touch: two-finger / double-tap-hold vs one-finger), so the tooltip never fights the pan.
- **Double-tap state machine.** `onDoubleTapDown` records the point and sets `_doubleTapHold`; a quick `onDoubleTap` toggles zoom **anchored at the tapped point** (`zoomedAt(tapFocal, …)`) instead of the corner; if movement begins while `_doubleTapHold` is set, the single-pointer touch drag routes to `pannedBy` instead of scrub; the flag clears on pointer-up or once the tap resolves.
- **Buttons zoom about center (free win).** The legend's `_zoomIn`/`_zoomOut` (`:893-905`) have no cursor, so they call `zoomedAt(0.5, 0.5, 1.5)` / `(…, 1/1.5)`. Today they collapse toward the top-left; routing them through the same `zoomedAt` fixes the buttons with no bespoke code.
- **Edge behavior & reset.** `_clamped()` hard-stops at the data edges (no rubber-band in v1). The legend reset button and double-tap-when-zoomed set `_viewport = ProfileChartViewport.reset`. The zoom-hint text (`:1052-1063`) now keys off `_viewport.isZoomed`.
- **Scope of state.** Zoom stays local per `_DiveProfileChartState`, so the three chart instances keep independent, ephemeral zoom exactly as today. No new provider.

## Testing strategy (TDD)

The payoff of the pure viewport and helpers is that the hard logic tests without pumping widgets.

- **Unit — `ProfileChartViewport`:**
  - **Anchor invariant (proves the bug dead):** for random `(focalX, focalY, factor, startViewport)`, the data fraction under the focal point is unchanged after `zoomedAt` (within ε).
  - `zoomedAt(0.5, 0.5, 2)` from reset → `zoom == 2`, `offsetX == offsetY == 0.25` (center held).
  - Focal at a corner pins that corner: `zoomedAt(0, 0, 2)` keeps offsets `0`; `zoomedAt(1, 1, 2)` → offsets `0.5`.
  - `pannedBy` clamps to `[0, 1 - 1/zoom]` (cannot pan past edges).
  - Zoom clamps to `[1, 10]`; `zoomedAt` beyond a rail is a no-op returning `this`.
  - Zoom-in then zoom-out at one focal round-trips to (approximately) the start.
- **Unit — `chartFocalFraction`:** cursor at the left gutter → `fx == 0`; at the right edge → `fx == 1`; a mid pixel maps to the expected fraction given reserved sizes; out-of-plot positions clamp to `[0,1]`.
- **Unit — `chartDragIntent`:** full matrix — `(mouse, 1, false) → pan`; `(touch, 1, false) → scrub`; `(touch, 1, true) → pan`; `(any, 2, _) → zoomPan`.
- **Widget:**
  - Mouse wheel up over an off-center point raises zoom **and keeps the data point under the cursor** (assert the resulting visible window).
  - `TestPointer(kind: trackpad)` `panZoomStart` / `panZoomUpdate(scale > 1)` anchored off-center → zoom increases, anchor approximately fixed; `localPan` pans.
  - Mouse hover sets the tracking index for the sample under the cursor; `onExit` clears it.
  - **Mouse click-drag pans, but a touch one-finger drag does NOT pan (still scrubs)** — the regression guard for the collision.
  - Legend zoom-in / zoom-out buttons zoom about the center.
  - Double-tap (quick) toggles zoom about the tapped point. (Double-tap-hold-drag pan may be the one behavior finalized purely under TDD.)
- **Regression:** existing `dive_profile_chart` widget tests stay green.

## Out of scope

- Switching to X-only / time-axis zoom (uniform 2-D kept by decision).
- Rubber-band / elastic over-pan and pan inertia / fling (instant follow in v1).
- Scrollbars or an overview minimap (gesture-based navigation chosen).
- Cross-instance or persisted zoom state (stays local and ephemeral).
- The other profile charts (`profile_editor_chart.dart`, `dive_planner/.../plan_profile_chart.dart`, `core/.../overlaid_profile_chart.dart`) — they have no zoom/pan and are untouched.
- Any change to series, decompression overlays, units, or tooltip *content*.

## Risks & trade-offs

- **Plot-rect accuracy.** Anchoring exactly under the cursor needs the true plot rect minus axis gutters; if a reserved gutter changes dynamically (e.g. toggling the right-axis metric), it is recomputed each build from the configured reserved sizes.
- **Double-tap-hold gesture** is the fiddly part (timing/slop); finalized under TDD. If it proves flaky it is not load-bearing — two-finger drag still provides touch panning.
- **Gesture-arena cooperation.** The passive `Listener` must not claim gestures fl_chart or the `GestureDetector` need; safe because fl_chart's recognizers ignore `PointerPanZoom*`, and the single-pointer touch branch returns early so fl_chart keeps the scrub.
- **Hover vs touch tooltip.** Hover must feed the same tooltip path as the touch scrub so the two never double-render; on touch nothing changes.

## Affected files

New:
- `lib/features/dive_log/presentation/widgets/profile_chart_viewport.dart` (immutable `ProfileChartViewport` + pure `chartFocalFraction` and `chartDragIntent`)
- `test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart` (+ widget tests; location per existing test layout)

Modified:
- `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` — replace the three zoom/pan doubles (`:457-469`) with one `_viewport`; add `Listener.onPointerPanZoom*` + `onPointerHover`/`onExit` + pointer-kind tracking; rework `onScaleStart/Update` (`:1087-1127`) and `onPointerSignal` (`:1137-1153`) to branch on `chartDragIntent` and anchor via `zoomedAt`; re-source the window computation (`:1238-1246`) from the viewport; route `_zoomIn`/`_zoomOut` (`:893-905`) and double-tap (`:1128-1136`) through `zoomedAt`; key the zoom hint (`:1052-1063`) off `_viewport.isZoomed`.

Unchanged:
- `dive_profile_legend.dart` — same `onZoomIn`/`onZoomOut`/`onResetZoom` callbacks; no transform logic there.
- `profile_tracking_provider.dart` / `profile_legend_provider.dart` / `profile_range_provider.dart` — series visibility, scrub index, and range-selection are orthogonal to the viewport.

## References

- Sibling spec: `docs/superpowers/specs/2026-06-21-map-touchpad-interaction-design.md` (same `PointerDeviceKind` / zoom-to-cursor philosophy)
- flutter/flutter#136029 — desktop trackpad pinch wrong focal point (why trackpad zoom keys off the raw cursor `localPosition`)
- `dive_profile_chart.dart` current zoom/pan: state `:457-469`, reset `:507-513`, buttons `:893-912`, hint `:1052-1063`, gestures `:1081-1153`, window `:1238-1246`, chart/clip `:1311-1318`, scrub callback `:1584-1617`, tick intervals `:2811-2824`
