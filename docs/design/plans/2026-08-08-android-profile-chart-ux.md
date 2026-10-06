# Android Profile Chart UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the dive profile chart usable on Android touch: one-finger pan when zoomed, reliable two-finger pinch/pan, instant (no 300 ms pause) scrubbing, event labels that stop hiding the dive tail, and a fullscreen readout card that defaults to an empty corner.

**Architecture:** Touch gestures move off Flutter's default arena racing. A translucent overlay stacked directly above the `LineChart` hosts a custom `ChartTouchClaimRecognizer` that (a) claims a second touch pointer immediately (pinch/two-finger pan always wins) and (b) claims a one-finger drag past slop when the viewport is zoomed ("drag to pan" becomes true on touch). All gesture math stays in the existing passive `Listener` (pointer map, pinch cumulative-vs-snapshot, mouse pan). The `GestureDetector` with `onScale*`/`onDoubleTap*` is deleted; double-tap-to-zoom is re-detected manually from `PointerEvent.timeStamp` (no `DoubleTapGestureRecognizer`, hence no 300 ms arena hold, no pending timers in tests). Event labels get a pure placement function (below-the-curve anchoring, edge flip, collision push-down/drop). The fullscreen `DraggableReadoutCard` default corner is chosen by a pure occupancy function over the normalized profile.

**Tech Stack:** Flutter, fl_chart 1.1.1, flutter_test. No new dependencies.

## Global Constraints

- All Dart code passes `dart format` unchanged; `flutter analyze` clean (infos are fatal in CI — whole-project analyze).
- No emojis in code/comments/docs. Immutability preferred. Many small files (200–400 lines typical).
- Unit-display code must respect active diver unit settings (not touched here; placements are pixel-space).
- Do not add new Riverpod providers consumed by the chart/legend (breaks ~all consumer tests — see memory `new-provider-dep`).
- Commit after each task (plan commits are pre-authorized). No Claude attribution in commits/PR bodies.
- Existing behavior preserved: desktop mouse pan/hover/wheel, trackpad recognizer, one-finger scrub at zoom 1, long-press scrub, tap tooltip, double-tap zoom toggle.
- Behavior deliberately removed: double-tap-and-hold pan (superseded by one-finger pan-when-zoomed; it misclassified fast tap-then-drag scrubs — the reported bug).

## Root causes being fixed (verified against code)

1. `dive_profile_chart.dart:1887-1958` — `GestureDetector.onDoubleTap` holds every tap's arena 300 ms (UI pause; delayed tooltip); `onDoubleTapDown` sets `_doubleTapHold`, so a fast tap-then-drag becomes a viewport pan (no-op at zoom 1) instead of a scrub.
2. Two-finger pinch/pan (`onScaleUpdate`) must out-race fl_chart's internal `PanGestureRecognizer` (`render_base_chart.dart:139-144`, innermost so it wins ties); loses whenever one finger moves before the second lands.
3. Zoom hint (`diveLog_profile_zoomHint`) says "drag to pan" but one-finger touch drag always scrubs.
4. Event `VerticalLineLabel`s pinned to plot top (= surface = end-of-dive tail), centered, no collision handling (`_buildEventVerticalLines`, `dive_profile_chart.dart:5051-5092`); ascent events cluster at dive end.
5. `DraggableReadoutCard.defaultFraction = Offset(1, 0)` (top-right) sits exactly on the ascent tail.

---

### Task 1: `chartDragIntent` gains `isZoomed`, loses `doubleTapHold`

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/profile_chart_viewport.dart:84-101`
- Test: `test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart`

**Interfaces:**
- Produces: `ChartDragIntent chartDragIntent({required PointerDeviceKind kind, required int pointerCount, required bool isZoomed})` — touch+1 pointer: `scrub` when not zoomed, `pan` when zoomed; any 2+ pointers: `zoomPan`; non-touch single pointer: `pan`.

- [ ] **Step 1:** Rewrite the `chartDragIntent` tests: replace every `doubleTapHold:` argument with `isZoomed:`; keep the pointer-kind matrix; add cases `touch+1+isZoomed:false => scrub`, `touch+1+isZoomed:true => pan`, `mouse+1 (either zoom) => pan`, `any kind +2 pointers => zoomPan`.
- [ ] **Step 2:** Run `flutter test test/features/dive_log/presentation/widgets/profile_chart_viewport_test.dart` — expect compile failure (named param mismatch).
- [ ] **Step 3:** Change the function:

```dart
ChartDragIntent chartDragIntent({
  required PointerDeviceKind kind,
  required int pointerCount,
  required bool isZoomed,
}) {
  if (pointerCount >= 2) return ChartDragIntent.zoomPan;
  if (kind != PointerDeviceKind.touch) return ChartDragIntent.pan;
  return isZoomed ? ChartDragIntent.pan : ChartDragIntent.scrub;
}
```

(The chart call site is fixed in Task 3; it will not compile until then — acceptable inside the same branch, but to keep every commit green, update the single call site in `dive_profile_chart.dart:1970-1975` in this task too, passing `isZoomed: _viewport.isZoomed` and adding a temporary `&& !_doubleTapHold` nothing — no: simply pass `isZoomed: _viewport.isZoomed` and leave `_doubleTapHold` unused until Task 3 removes it.)
- [ ] **Step 4:** Run the viewport test file + `flutter analyze` on the two files. Expect pass (an unused-field info for `_doubleTapHold` would be fatal — silence by keeping the field read in `onPointerUp` reset until Task 3, which it already is).
- [ ] **Step 5:** Commit: `refactor: chartDragIntent keys on viewport zoom, not double-tap hold`

### Task 2: `ChartTouchClaimRecognizer`

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/chart_touch_recognizer.dart`
- Test: `test/features/dive_log/presentation/widgets/chart_touch_recognizer_test.dart`

**Interfaces:**
- Produces: `class ChartTouchClaimRecognizer extends OneSequenceGestureRecognizer` with constructor `({required ValueGetter<bool> isZoomed, Object? debugOwner})`, settable `VoidCallback? onClaimed; VoidCallback? onReleased;`. Touch-only. Claims: 2nd pointer down → accept immediately; single pointer move past `computeHitSlop` while `isZoomed()` was true at pointer-down → accept. Rejects on up/cancel without acceptance so taps/long-presses pass through.

- [ ] **Step 1:** Write widget tests using a harness that mirrors the real stacking: a `Stack` with (bottom) a `RawGestureDetector` owning a plain `PanGestureRecognizer` counting wins (stand-in for fl_chart, deeper = registers first when hit first) and (top) a translucent `RawGestureDetector` hosting `ChartTouchClaimRecognizer`. Cases:
  1. zoomed=true, one-finger drag past slop → `onClaimed` fired, stand-in pan never started;
  2. zoomed=false, one-finger drag → stand-in pan wins, no claim;
  3. zoomed=false, two-finger down (second finger lands after first already moved 30 px) → claim fired (the async-finger case that broke on device);
  4. tap (down/up, no move) with zoomed=true → no claim; stand-in tap recognizer (add a `TapGestureRecognizer` to the bottom detector) fires;
  5. `onReleased` fires when the last pointer lifts after a claim.
- [ ] **Step 2:** Run the new test file — expect failure (class missing).
- [ ] **Step 3:** Implement (~120 lines):

```dart
class ChartTouchClaimRecognizer extends OneSequenceGestureRecognizer {
  ChartTouchClaimRecognizer({required this.isZoomed, Object? debugOwner})
      : super(debugOwner: debugOwner,
              supportedDevices: {PointerDeviceKind.touch});
  final ValueGetter<bool> isZoomed;
  VoidCallback? onClaimed;
  VoidCallback? onReleased;
  final Map<int, Offset> _downPositions = {};
  bool _claimed = false;
  bool _zoomedAtFirstDown = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    if (_downPositions.isEmpty) _zoomedAtFirstDown = isZoomed();
    _downPositions[event.pointer] = event.position;
    if (_downPositions.length == 2 && !_claimed) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent &&
        !_claimed &&
        _downPositions.length == 1 &&
        _zoomedAtFirstDown) {
      final start = _downPositions[event.pointer];
      if (start != null &&
          (event.position - start).distance >
              computeHitSlop(event.kind, gestureSettings)) {
        resolve(GestureDisposition.accepted);
      }
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (!_claimed) resolve(GestureDisposition.rejected);
      _downPositions.remove(event.pointer);
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) {
    if (!_claimed) { _claimed = true; onClaimed?.call(); }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    final wasClaimed = _claimed;
    _claimed = false;
    _downPositions.clear();
    if (wasClaimed) onReleased?.call();
  }

  @override
  String get debugDescription => 'chart touch claim';
}
```

- [ ] **Step 4:** Run test file; iterate until green.
- [ ] **Step 5:** Commit: `feat: arena-winning touch claim recognizer for the profile chart`

### Task 3: Chart integration — new touch model

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (state fields ~800-840; `_buildInteractiveChart` 1839-2059; `touchCallback` 2625; plot `Stack` 2251)
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_gestures_test.dart` (new file; keeps the giant existing test file from growing)

**Interfaces:**
- Consumes: Task 1 `chartDragIntent(isZoomed:)`, Task 2 recognizer.
- Produces: touch model — 1-finger: scrub (zoom 1) / pan (zoomed, claimed); 2-finger: pinch zoom + pan always; double-tap: zoom toggle (manual, `PointerEvent.timeStamp`-based); long-press: scrub at any zoom; tap: tooltip with no 300 ms delay. Desktop unchanged.

- [ ] **Step 1:** Write failing widget tests (new file, reuse `_buildChart`-style harness from the existing chart test: `MaterialApp > Scaffold > SizedBox(400x300) > DiveProfileChart(profile: …, onPointSelected: …)`; helper `LineChartData chartData(t)`):
  1. **fast tap-then-drag scrubs** (the reported bug): `tapAt(center)`, `pump(50ms)`, `startGesture(center)`, move +40 px in 4 steps → `onPointSelected` fired with non-null during the drag AND `chartData.minX == 0` (no pan/zoom happened);
  2. **single tap selects with no 300 ms wait**: `tapAt`, `pump()` (one frame) → selection callback observed (previously required pumping past the double-tap window);
  3. **double-tap zooms, double-tap again resets**: two `tapAt` 100 ms apart → visible X span shrinks; repeat → back to full span; no "Timer still pending" without extra pumps;
  4. **two-finger pinch always zooms**: `startGesture(p1)`, move it 30 px (fl_chart pan would have won the old race), then `startGesture(p2)`, spread both by 40 px → X span shrinks;
  5. **two-finger drag pans when zoomed**: wheel-zoom in first (existing `sendEventToBinding(PointerScrollEvent)` pattern), then two-finger parallel move → `minX` changes, zoom unchanged (within tolerance);
  6. **one-finger drag pans when zoomed**: wheel-zoom in, drag one touch pointer left → `minX` increases; `onPointSelected` NOT called with a new index during the drag;
  7. **one-finger drag still scrubs at zoom 1**: drag → selection fires, `minX` stays 0;
  8. **double-tap over the right-axis metric selector strip does not zoom**: pump chart with a right-axis metric active, double-tap inside the right 50 px strip → X span unchanged;
  9. **long-press then drag scrubs while zoomed** (no pan): zoom in, `startGesture`, `pump(600ms)` hold, then move → selection fires, `minX` unchanged.
- [ ] **Step 2:** Run new test file — failures expected on 1, 4, 5, 6, 8 (and 2's timing assert).
- [ ] **Step 3:** Implement in `dive_profile_chart.dart`:
  - Delete fields `_doubleTapHold`, `_startFocalPoint`, `_lastTapDownLocal`; add:

```dart
// All touch pointers currently down, by pointer id, in chart-local coords.
final Map<int, Offset> _touchPositions = {};
// True while ChartTouchClaimRecognizer has won the arena for a touch drag.
bool _touchDragClaimed = false;
// Two-finger gesture bookkeeping (cumulative against _gestureStartViewport).
List<int> _pinchPointers = const [];
double _pinchStartDistance = 1;
Offset _pinchStartFocal = Offset.zero;
// Manual double-tap detection off PointerEvent.timeStamp (no recognizer, so
// no 300 ms arena hold and no pending timers in tests).
Duration? _lastTapUpStamp;
Offset _lastTapUpPosition = Offset.zero;
Duration _tapDownStamp = Duration.zero;
Offset _tapDownPosition = Offset.zero;
bool _tapMoved = false;
bool _doubleTapArmed = false;
// Whether the right-axis metric selector strip is active this build; taps
// there cycle metrics and must not arm double-tap zoom.
bool _rightAxisSelectorActive = false;
```

  - Remove the `GestureDetector` wrapper (`onScaleStart/onScaleUpdate/onDoubleTapDown/onDoubleTap`) — `RawGestureDetector` (trackpad) now directly wraps the `Listener`.
  - In the plot `Stack` (2251), insert directly after `LineChart`:

```dart
Positioned.fill(
  child: RawGestureDetector(
    behavior: HitTestBehavior.translucent,
    gestures: {
      ChartTouchClaimRecognizer:
          GestureRecognizerFactoryWithHandlers<ChartTouchClaimRecognizer>(
        () => ChartTouchClaimRecognizer(
          isZoomed: () => _viewport.isZoomed,
          debugOwner: this,
        ),
        (r) => r
          ..onClaimed = (() => _touchDragClaimed = true)
          ..onReleased = (() => _touchDragClaimed = false),
      ),
    },
  ),
),
```

  (Overlay must live in `_buildChart`'s Stack, which is below the selector/gas-strip/photo overlays — they keep tap priority.)
  - `Listener.onPointerDown`: keep count/kind/lastLocal updates; for `kind == touch` add position to `_touchPositions`; on second touch pointer call `_beginPinch` (snapshot viewport, `_pinchPointers = first two ids`, start distance ≥ 1, start focal midpoint; clear selection via `widget.onPointSelected?.call(null)`; `_tapMoved = true`; `_doubleTapArmed = false`); on first pointer set `_tapDownStamp/_tapDownPosition/_tapMoved=false` and arm double-tap when `_lastTapUpStamp != null && event.timeStamp - _lastTapUpStamp! < kDoubleTapTimeout && (event.localPosition - _lastTapUpPosition).distance <= kDoubleTapSlop && !_inRightAxisSelector(event.localPosition, constraints.biggest)`.
  - `Listener.onPointerMove`: update `_touchPositions`; slop check → `_tapMoved = true; _doubleTapArmed = false`; then

```dart
final intent = chartDragIntent(
  kind: _activePointerKind,
  pointerCount: _activePointerCount,
  isZoomed: _viewport.isZoomed,
);
if (intent == ChartDragIntent.zoomPan &&
    _activePointerKind == PointerDeviceKind.touch) {
  _updatePinch(constraints, units);
  return;
}
if (intent != ChartDragIntent.pan) return;
if (_activePointerKind == PointerDeviceKind.touch && !_touchDragClaimed) {
  return; // long-press scrub owns this drag
}
// existing pan math unchanged
```

  - `_updatePinch`: recompute the two tracked pointers' distance/midpoint; `scale = dist / _pinchStartDistance`; `vp = _gestureStartViewport.zoomedAt(focal(startFocal), scale)` then `pannedBy(-(midNow - startFocal)/plot/vp.zoom)` — the exact math currently in `onScaleUpdate` (1903-1934), with `_pinchStartFocal` replacing `_startFocalPoint`.
  - `Listener.onPointerUp` (touch): remove from `_touchPositions`; if a pinch pointer lifted and ≥2 remain re-`_beginPinch` with the new pair, else clear `_pinchPointers`; single-tap bookkeeping: if `!_tapMoved`: if `_doubleTapArmed` → `_toggleDoubleTapZoom(_tapDownPosition)` (old `onDoubleTap` body, 1940-1958, with the tap position parameter) and `_lastTapUpStamp = null`; else `_lastTapUpStamp = event.timeStamp; _lastTapUpPosition = event.localPosition`. `onPointerCancel`: same cleanup, no tap logic.
  - `_inRightAxisSelector(Offset p, Size box)` → `_rightAxisSelectorActive && p.dx >= box.width - 50 && p.dy <= box.height - 30`; set `_rightAxisSelectorActive = effectiveRightAxisMetric != null` where `_buildChart` computes it.
  - `touchCallback` first line: `if (_activePointerCount >= 2) return;` (fl_chart may still own finger 1 mid-pinch; its scrub must not fight the pinch).
- [ ] **Step 4:** Run the new gesture test file, then the full existing chart test files (`dive_profile_chart_test.dart`, `dive_profile_panel_test.dart`, `fullscreen_profile_page_test.dart`, `photo_marker_overlay_test.dart`). Fix fallout (e.g. tests that pumped past the old double-tap window).
- [ ] **Step 5:** Commit: `fix: reliable touch pan/pinch and instant scrubbing on the profile chart`

### Task 4: Event label placement (pure)

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/profile_event_labels.dart`
- Test: `test/features/dive_log/presentation/widgets/profile_event_labels_test.dart`

**Interfaces:**
- Produces:

```dart
class EventLabelSpec {
  final double xPx;      // event line x within the plot rect
  final double anchorYPx;// profile depth pixel at the event time
  final double textWidth;
  final double textHeight;
  const EventLabelSpec({required this.xPx, required this.anchorYPx,
      required this.textWidth, required this.textHeight});
}

enum EventLabelAnchor { center, leftOfLine, rightOfLine }

class EventLabelPlacement {
  final bool showText;
  final double topPx;
  final EventLabelAnchor anchor;
  const EventLabelPlacement({required this.showText, required this.topPx,
      required this.anchor});
}

List<EventLabelPlacement> placeEventLabels(
  List<EventLabelSpec> specs, {
  required double plotWidth,
  required double plotHeight,
  double gap = 4,
})
```

Rules: label top = `anchorYPx + gap` clamped to `[0, plotHeight - textHeight]` (below the curve point, off the surface tail); anchor flips `leftOfLine` when the centered extent would cross `plotWidth`, `rightOfLine` when it would cross 0; greedy left-to-right collision resolution pushes an overlapping label down in `textHeight + 2` steps; if it cannot fit above `plotHeight` it also retries fully above the anchor (`anchorYPx - gap - textHeight`, stepping up); if neither fits → `showText: false` (the dashed line still marks the event).

- [ ] **Step 1:** Unit tests: single label sits at `anchorYPx + gap`; bottom clamp; near-right-edge spec flips `leftOfLine`; near-left flips `rightOfLine`; two overlapping specs → second pushed below first (no rect intersection); crowded column (5 specs same x/anchor, small plot) → later ones `showText: false`; output length always equals input length; order preserved.
- [ ] **Step 2:** Run — fails (file missing).
- [ ] **Step 3:** Implement pure function + rect helpers (no Flutter imports beyond `dart:ui` `Rect`).
- [ ] **Step 4:** Run — pass.
- [ ] **Step 5:** Commit: `feat: collision-aware dive event label placement`

### Task 5: Wire event labels into the chart

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` (`_buildEventVerticalLines` 5051-5092 and its call site ~2601)
- Test: extend `test/features/dive_log/presentation/widgets/dive_profile_chart_gestures_test.dart`? No — create `test/features/dive_log/presentation/widgets/dive_profile_chart_event_labels_test.dart`

**Interfaces:**
- Consumes: `placeEventLabels` (Task 4).
- Produces: `_buildEventVerticalLines(colorScheme, {required double availableWidth, required UnitFormatter units, required double visibleMinX, required double visibleMaxX, required double visibleMinDepth, required double visibleMaxDepth})`.

- [ ] **Step 1:** Widget tests: build a 20-min profile with three ascent-phase events in the last 90 s (classic tail cluster) on a 400×300 surface:
  1. every rendered `VerticalLineLabel` has `padding.top > 0` (no label pinned to the surface line);
  2. no two shown labels' rects intersect (recompute rects from padding/alignment + `TextPainter` width the same way the wiring does);
  3. an event 5 s before dive end gets `alignment == Alignment.topLeft` (flipped off the right edge);
  4. two events 3 s apart (sub-pixel at this width) → only the more severe one keeps `show: true`;
  5. events for a toggled-off computer still excluded (existing behavior, quick regression assert).
- [ ] **Step 2:** Run — fails.
- [ ] **Step 3:** Implement wiring: pixel-dedupe (`minSpacingPx = 24`, keep highest severity, tie → later timestamp); depth interpolation helper over `widget.profile` for `anchorYPx` (`yPx = (depth - visibleMinDepth) / (visibleMaxDepth - visibleMinDepth) * plotH`, clamped); `TextPainter` measurement at the label style (fontSize 9); map placements to `VerticalLineLabel`: `center → Alignment.topCenter, EdgeInsets.only(top: topPx)`; `leftOfLine → Alignment.topLeft, EdgeInsets.only(top: topPx, right: 4)`; `rightOfLine → Alignment.topRight, EdgeInsets.only(top: topPx, left: 4)`; `show: placement.showText`. Events outside the visible X window keep `show: false` (clipped anyway). Plot geometry from `_plotInsets(availableWidth, units)`.
- [ ] **Step 4:** Run new file + `dive_profile_chart_test.dart` event groups.
- [ ] **Step 5:** Commit: `fix: event labels no longer bury the end-of-dive profile tail`

### Task 6: Fullscreen readout card default corner

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/readout_card_placement.dart`
- Modify: `lib/features/dive_log/presentation/pages/fullscreen_profile_page.dart:423-446`, `lib/features/dive_log/presentation/widgets/draggable_readout_card.dart` (doc only)
- Test: `test/features/dive_log/presentation/widgets/readout_card_placement_test.dart`, extend `test/features/dive_log/presentation/pages/fullscreen_profile_page_test.dart`

**Interfaces:**
- Produces: `Offset leastOccupiedReadoutCorner(List<Offset> normalizedProfile)` — input points normalized to x∈[0,1] time, y∈[0,1] depth (0 = surface/top). Counts points inside four corner windows (width 0.45, height 0.4); returns the fraction offset of the emptiest corner; ties prefer top-right, then top-left, bottom-right, bottom-left (preserves today's default when all else equal).

- [ ] **Step 1:** Unit tests: empty list → `Offset(1, 0)`; a typical dive shape (fast descent, long deep bottom, ascent tail to top-right) → NOT top-right (expect bottom-right); all-shallow profile hugging the top → a bottom corner; occupancy tie → top-right.
- [ ] **Step 2:** Fullscreen page test: with no saved position and the standard test profile, the card's initial `FractionalOffset` equals `leastOccupiedReadoutCorner(...)` of that profile (assert via the card's `Align` alignment after pump); with a saved position, saved still wins (existing test keeps passing).
- [ ] **Step 3:** Run — fails.
- [ ] **Step 4:** Implement the pure function; in the fullscreen page, where `initialFraction` currently falls back to `DraggableReadoutCard.defaultFraction`, compute the fallback with `leastOccupiedReadoutCorner` from the dive profile samples (normalize by dive duration / max depth).
- [ ] **Step 5:** Run both test files.
- [ ] **Step 6:** Commit: `fix: fullscreen readout card defaults to the emptiest chart corner`

### Task 7: Whole-project verification

- [ ] `dart format .` (whole project — memory `format-all`).
- [ ] `flutter analyze` whole project; zero issues (infos fatal).
- [ ] Run the full affected test set: `flutter test test/features/dive_log/` (generous timeout; some hosts are slow — memory `timeout`).
- [ ] Commit any format fixes: `style: format`.
- [ ] Note in PR: Android on-device verification pending (gesture arena behavior is now deterministic and widget-tested, but pinch feel / hint discoverability should be confirmed on hardware).

## Self-review notes

- Spec coverage: complaint 1 → Tasks 1-3 (one-finger pan zoomed + reliable two-finger); complaint 2 → Task 3 (no arena hold, no tap-then-drag misclassification); complaint 3 → Tasks 4-6.
- Type consistency: `ChartTouchClaimRecognizer` callbacks used in Task 3 match Task 2; `EventLabelSpec/Placement` names match between Tasks 4 and 5; `chartDragIntent(isZoomed:)` matches Tasks 1 and 3.
- Known accepted trade-offs: double-tapping a photo marker now also zooms the chart (previously the marker's eager tap recognizer starved the chart's double-tap); double-tap-hold pan removed.
