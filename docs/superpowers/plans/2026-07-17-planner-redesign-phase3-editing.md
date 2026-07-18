# Planner Redesign Phase 3: On-Chart Editing - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Subsurface-parity profile editing (G16): drag waypoints, double-click to add one, right-click/long-press to switch gas, keyboard nudges, with selection shared between chart and segment list.

**Architecture:** Vertices are segment boundaries. A pure `PlanChartEditController` maps gestures to segment mutations (waypoint semantics: moving a boundary retypes the adjacent segments); `PlanProfileChart` becomes stateful to run a drag session and host focus/keyboard; the overlay painter draws handles; every mutation flows through the existing `DivePlanNotifier` so live recompute and dirty-state stay uniform. Spec section 6.3.

**Tech Stack:** Phase 1 chart family, Riverpod 3. No new dependencies, no schema change.

## Global Constraints

Same as phases 1-2 (no emojis, theme-derived colors only, `dart format .` clean, analyzer clean, 11-locale l10n for new strings - none expected this phase, conventional commits without attribution, targeted tests, units via UnitFormatter).

## Verified facts

- `PlanSegment` (plan_segment.dart): `id/type/startDepth/endDepth/durationSeconds/tankId/gasMix/rate/switchToTankId/order`, `copyWith`, types `{descent, bottom, ascent, decoStop, gasSwitch, safetyStop}`. Flat types: bottom/decoStop/safetyStop/gasSwitch.
- Notifier mutations: `addSegment(PlanSegment)`, `updateSegment(String id, PlanSegment)`, `removeSegment(String id)`, `reorderSegments(int, int)`; `_updateSegmentOrders` renumbers. No insert/replace-in-place - Task 2 adds `replaceSegment`.
- `selectedSegmentIdProvider` (dive_planner_providers.dart:615) is write-only today; this phase makes SegmentList read it.
- Chart: `PlanChartGeometry.timeAtDx`, `toPixel`, `depthUnitScale`; overlay painter `PlanChartOverlayPainter(geometry, palette, scrubX)`; gestures currently: MouseRegion hover scrub, tap select, horizontal-drag scrub.
- `DivePlanState.tanks` is `List<DiveTank>` (id, gasMix, ...) - the gas menu lists these.

## Semantics (the contract Task 1 implements)

- `planVertices(ordered)`: one vertex per user segment i at (cumulative end time, endDepth). Gas-switch segments are skipped as drag targets (their depth is bound to neighbors) but still count toward cumulative time.
- `dragVertex(ordered, vertexIndex, newDepthMeters, newTimeSeconds, depthUnitScale)`:
  - snap depth to whole display units (`(d * scale).round() / scale`), clamp 0..330m; snap the segment's new duration to whole minutes (`>= 60s`), from `newTimeSeconds - segmentStartTime`.
  - returns updates: segment i gets endDepth + duration + retype; segment i+1 (if any) gets startDepth + retype. Retype rule: start == end -> keep old type if flat else `bottom`; start < end -> `descent`; start > end -> `ascent`; rate cleared (null) on retyped travel segments. Never retype gasSwitch segments (their depths follow but type stays).
- `splitSegmentAt(ordered, timeSeconds, depthMeters, scale, idGen)`:
  - inside user span: covering segment splits at snapped whole-minute boundary (each half `>= 60s`, else return null); first half keeps the original id (selection stability), second half gets `idGen()`; both retyped against the snapped vertex depth.
  - beyond user span: returns a single appended travel segment from last endDepth to snapped depth, duration `newTime - totalTime` snapped (`>= 60s`), retyped, using the last segment's tank/gas.
- Gas switch at vertex i applies to the FOLLOWING segment (i+1), falling back to segment i when the vertex is last: `copyWith(gasMix: tank.gasMix, tankId: tank.id)`.
- Keyboard on selected segment: ArrowUp/Down = endDepth minus/plus one display unit (via dragVertex depth path), ArrowLeft/Right = duration -/+ 60s (floor 60), Delete/Backspace = removeSegment. Depth axis grows downward, so ArrowDown = deeper.

---

### Task 1: PlanChartEditController (pure)

**Files:**
- Create: `lib/features/planner/presentation/chart/plan_chart_edit_controller.dart`
- Test: `test/features/planner/chart/plan_chart_edit_controller_test.dart`

**Interfaces (produced):**

```dart
class PlanVertex {
  final int segmentIndex;
  final String segmentId;
  final double timeSeconds; // cumulative end time
  final double depth;       // segment endDepth (meters)
  final bool draggable;     // false for gasSwitch segments
}

List<PlanVertex> planVertices(List<PlanSegment> segments); // sorts by order

int? hitTestVertex({
  required List<PlanVertex> vertices,
  required PlanChartGeometry geometry,
  required Offset position,
  double radius = 16,
}); // nearest draggable vertex within radius, else null

class VertexDragResult {
  final List<(String, PlanSegment)> updates; // (id, updated segment)
}

VertexDragResult dragVertex({
  required List<PlanSegment> ordered,
  required int vertexIndex,
  required double newDepthMeters,
  required double newTimeSeconds,
  required double depthUnitScale,
});

/// Split-or-append for double-click. Returns null when the click cannot
/// produce a valid edit (halves under 60s).
({String replaceId, List<PlanSegment> replacements})? splitSegmentAt({
  required List<PlanSegment> ordered,
  required double timeSeconds,
  required double depthMeters,
  required double depthUnitScale,
  required String Function() idGen,
});
```

Steps: failing tests first covering - vertex list skips gasSwitch as draggable and accumulates time; hit test radius; drag snaps depth to display units (test with scale 3.2808 for feet) and duration to whole minutes with 60s floor; retype descent->bottom->ascent transitions including next-segment startDepth follow and flat-type preservation; split inside span keeps original id on the first half and produces two >= 60s halves (null when too tight); append past span creates a travel segment with the last tank/gas; then implementation, format, commit `feat(planner): pure edit controller for on-chart waypoint editing`.

### Task 2: `replaceSegment` notifier mutation

**Files:**
- Modify: `lib/features/dive_planner/presentation/providers/dive_planner_providers.dart` (next to `updateSegment`, ~line 154)
- Test: extend `test/features/planner/chart/plan_chart_edit_controller_test.dart` group or the existing notifier test file if one exists (check `test/features/dive_planner/` for a providers test; else add cases to a new small file `test/features/dive_planner/presentation/providers/dive_plan_notifier_replace_test.dart`)

**Interfaces (produced):**

```dart
/// Replace one segment with one or more segments in place (used by the
/// chart's split gesture). Orders are renumbered.
void replaceSegment(String id, List<PlanSegment> replacements) {
  final segments = List<PlanSegment>.from(state.segments);
  final index = segments.indexWhere((s) => s.id == id);
  if (index < 0) return;
  segments
    ..removeAt(index)
    ..insertAll(index, replacements);
  _updateSegmentOrders(segments);
  state = state.copyWith(segments: segments, isDirty: true);
}
```

TDD: test that replacing the middle segment of three yields renumbered orders and dirty state; commit `feat(planner): replaceSegment mutation for chart splits`.

### Task 3: Handles on the overlay painter

**Files:**
- Modify: `lib/features/planner/presentation/chart/plan_profile_chart.dart` (`PlanChartOverlayPainter`)
- Test: extend `test/features/planner/chart/plan_profile_chart_test.dart`

`PlanChartOverlayPainter` gains `required List<Offset> handles`, `required int? activeHandle` (hover/drag target), `required int? selectedHandle`. Paint after the scrub line: for each handle a 4.5px-radius circle, `palette.backdrop` fill + 1.6px `palette.profileLine` stroke; active handle radius 6.5; selected handle filled with `palette.profileLine`. `shouldRepaint` covers the new fields (listEquals on handles). The widget computes handle offsets from `planVertices` x geometry each build and passes selected index from `selectedSegmentIdProvider`. Golden regen (`flutter test test/features/planner/chart/ --update-goldens`) - handles now appear on goldens; inspect, commit `feat(planner): waypoint handles on the chart overlay`.

### Task 4: Gestures, keyboard, and gas menu in PlanProfileChart

**Files:**
- Modify: `lib/features/planner/presentation/chart/plan_profile_chart.dart`
- Test: extend `test/features/planner/chart/plan_profile_chart_test.dart`

Widget becomes `ConsumerStatefulWidget` with local fields `int? _dragVertex`, `FocusNode _focusNode`. Gesture changes inside the LayoutBuilder:

- `onPanDown` replaces onTapDown for scrub start; `onPanStart`: hit-test vertices - hit -> `_dragVertex = index` (no scrub), miss -> scrub as today.
- `onPanUpdate`: dragging a vertex -> `dragVertex(...)` with `geometry.timeAtDx(dx)` and depth from `geometry` inverse (`depthAtDy` - ADD this inverse to `PlanChartGeometry` mirroring `timeAtDx`, clamped 0..maxDepth*1.1, plus a unit test); apply `result.updates` via `updateSegment`. Not dragging -> scrub.
- `onPanEnd`: clear `_dragVertex`, clear scrub, request focus.
- `onTapUp`: unchanged select behavior, plus `_focusNode.requestFocus()`.
- `onDoubleTapDown`: `splitSegmentAt`; single append -> `addSegment`, split -> `replaceSegment`.
- `onSecondaryTapDown` (desktop) and `onLongPressStart` (touch): hit-test vertex; on hit show `showMenu` at the pointer with one `PopupMenuItem` per `state.tanks` entry labeled `'${tank.name ?? tank.gasMix.name} · ${tank.gasMix.name}'` (check DiveTank for a name field; fall back to gasMix.name only); selection applies the gas-switch rule from the semantics section via `updateSegment`.
- Wrap the chart in `Focus(focusNode: _focusNode, onKeyEvent: ...)` implementing the keyboard contract (KeyDownEvent + repeats; `LogicalKeyboardKey.arrowUp/arrowDown/arrowLeft/arrowRight/delete/backspace`); only handled when `selectedSegmentIdProvider` is non-null and the segment still exists; return `KeyEventResult.handled` for consumed keys.

Widget tests (extend the existing file): drag a handle vertically changes the bottom segment depth (start a gesture ON the handle offset - compute it from the seeded plan's vertex via the same helpers); double-tap in the tail appends a segment; keyboard ArrowDown deepens the selected segment by 1m and Delete removes it; secondary-tap on a handle shows a menu listing tank gas names. Commit `feat(planner): drag, double-click, gas menu, and keyboard editing on the chart`.

### Task 5: Selection in SegmentList

**Files:**
- Modify: `lib/features/dive_planner/presentation/widgets/segment_list.dart`
- Test: extend `test/features/planner/chart/plan_profile_chart_test.dart` (chart tap highlights list) or `plan_setup_sections_test.dart` sibling - place in `test/features/dive_planner/presentation/widgets/segment_list_selection_test.dart`

`SegmentList` watches `selectedSegmentIdProvider`; `_SegmentTile` gains `selected` + `onSelect`: `ListTile(selected: selected, selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.35), onTap: onSelect)` - tap now SELECTS (single tap) and the edit pencil remains the edit affordance (tap-to-edit from phase 2 becomes tap-to-select; double-tap opens editor via `onLongPress`? No - keep simple: tap selects, pencil edits). Test: two segments, set provider -> tile shows selected color; tap other tile -> provider updates. Commit `feat(planner): segment list reflects and drives chart selection`.

### Task 6: Phase gate

`dart format .`, `flutter analyze`, `flutter test test/features/planner/ test/features/dive_planner/`, golden verification, `flutter run -d macos` walkthrough (drag a vertex, double-click add, right-click gas switch, arrow keys, delete, selection sync both directions), clean tree. No push until asked.

## Self-Review

- G16 coverage: drag (T1/T4), double-click add with snapping (T1/T4), right-click gas menu (T4), keyboard incl. Delete (T4), selection shared (T5). Zoom/pan from Subsurface's list intentionally deferred (not in spec G16).
- Type consistency: `planVertices`/`hitTestVertex`/`dragVertex`/`splitSegmentAt`/`replaceSegment` names match across tasks; `depthAtDy` added to geometry in T4 with test.
- No placeholders; semantics section is the single source for edit rules.
