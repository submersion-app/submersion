# Map Touchpad Interaction Fixes — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix issue #238 — trackpad pinch zoom flies off-screen, and the map rotates too easily — by giving trackpad/mouse zoom-to-cursor, adding a real rotation deadband with a reset-to-north button, and making interaction consistent across all maps.

**Architecture:** A single shared module (`map_interaction.dart`) provides (1) a pure `mapInteractionOptions()` that picks flutter_map gesture flags from the *active pointer kind*, (2) a `MapInteractionDetector` wrapper that tracks pointer kind and handles trackpad `PointerPanZoom` events itself for reliable zoom-to-cursor, and (3) a self-hiding `MapResetNorthButton` child layer. Each interactive map is wrapped with the detector; overview maps additionally allow rotation (deadband) and show the reset button.

**Tech Stack:** Flutter, `flutter_map ^8.2.2`, `latlong2`, Riverpod (existing), Dart l10n (ARB).

**Spec:** `docs/superpowers/specs/2026-06-21-map-touchpad-interaction-design.md`

## Global Constraints

- `flutter_map` version: `8.2.2` (use only APIs verified in the spec: `InteractiveFlag`, `InteractionOptions`, `CursorKeyboardRotationOptions.disabled()`, `MapCamera.of`, `MapController.of`, `camera.focusedZoomCenter`, `camera.clampZoom`, `camera.projectAtZoom`/`unprojectAtZoom`, `MapController.rotate`/`move`/`camera`).
- All Dart code MUST pass `dart format .` with no changes.
- No emojis in code, comments, or docs.
- New user-facing strings MUST be added to all 11 ARB files (`app_en.arb` + `ar, de, es, fr, he, hu, it, nl, pt, zh`) and regenerated with `flutter gen-l10n` — no English fallbacks left in non-en locales.
- Dart package name is `submersion`; test imports use `package:submersion/...`.
- `context.l10n` is available via `import 'package:submersion/l10n/l10n_extension.dart';`.
- Run tests by specific file path (not whole directories) to avoid timeouts.
- Commit after each task (plan-approval + subagent execution pre-authorizes per-task commits). Do NOT add `Co-Authored-By` lines.

## File Structure

- **Create** `lib/features/maps/presentation/widgets/map_interaction.dart` — pure options function, `shouldShowResetNorth` helper, `MapInteractionDetector`, `MapResetNorthButton`. One responsibility: shared map interaction behavior.
- **Create** `test/features/maps/map_interaction_test.dart` — unit + widget tests for the module.
- **Modify** `lib/l10n/arb/app_*.arb` (11 files) — add `maps_resetNorth_tooltip`.
- **Modify** 12 map widget files (Tasks 7-12) — wrap in `MapInteractionDetector`, use shared options, add reset button on overview maps.

## Application Recipe (referenced by Tasks 7-12)

All map-application tasks use one of these two patterns. The maps differ only in: file, the `FlutterMap(...)` location, the `MapController` variable, `allowRotation`, and whether the reset button is added.

**Overview Pattern** (rotation enabled + reset button):

```dart
// BEFORE:
FlutterMap(
  mapController: _mapController,
  options: MapOptions(
    initialCenter: center,
    initialZoom: zoom,
    // ...other existing options (onTap, cameraConstraint, min/maxZoom)...
  ),
  children: [
    TileLayer(/* ...existing... */),
    // ...existing layers...
  ],
)

// AFTER:
MapInteractionDetector(
  allowRotation: true,
  mapController: _mapController,
  builder: (context, interactionOptions) => FlutterMap(
    mapController: _mapController,
    options: MapOptions(
      initialCenter: center,
      initialZoom: zoom,
      interactionOptions: interactionOptions, // ADD (replace any existing interactionOptions)
      // ...other existing options unchanged...
    ),
    children: [
      TileLayer(/* ...existing... */),
      // ...existing layers...
      const MapResetNorthButton(), // ADD as last child
    ],
  ),
)
```

**Locked Pattern** (north-up, no rotation, no reset button) — identical but `allowRotation: false` and do **not** add `MapResetNorthButton`:

```dart
MapInteractionDetector(
  allowRotation: false,
  mapController: _mapController,
  builder: (context, interactionOptions) => FlutterMap(
    mapController: _mapController,
    options: MapOptions(
      // ...existing options...
      interactionOptions: interactionOptions, // ADD/REPLACE
    ),
    children: [ /* ...existing layers, no reset button... */ ],
  ),
)
```

Add this import to each modified map file:
```dart
import 'package:submersion/features/maps/presentation/widgets/map_interaction.dart';
```

Per-task verification (all application tasks): `flutter analyze` (exit 0), the listed existing widget tests pass, `dart format .` clean.

---

### Task 1: Pure function `mapInteractionOptions`

**Files:**
- Create: `lib/features/maps/presentation/widgets/map_interaction.dart`
- Test: `test/features/maps/map_interaction_test.dart`

**Interfaces:**
- Produces: `InteractionOptions mapInteractionOptions({required bool isTouch, required bool allowRotation})`

- [ ] **Step 1: Write the failing test**

Create `test/features/maps/map_interaction_test.dart`:

```dart
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/maps/presentation/widgets/map_interaction.dart';

void main() {
  group('mapInteractionOptions', () {
    test('touch enables pinch zoom, pinch move and fling', () {
      final o = mapInteractionOptions(isTouch: true, allowRotation: false);
      expect(InteractiveFlag.hasPinchZoom(o.flags), isTrue);
      expect(InteractiveFlag.hasPinchMove(o.flags), isTrue);
      expect(InteractiveFlag.hasFlingAnimation(o.flags), isTrue);
    });

    test('non-touch disables pinch zoom, pinch move and fling', () {
      final o = mapInteractionOptions(isTouch: false, allowRotation: true);
      expect(InteractiveFlag.hasPinchZoom(o.flags), isFalse);
      expect(InteractiveFlag.hasPinchMove(o.flags), isFalse);
      expect(InteractiveFlag.hasFlingAnimation(o.flags), isFalse);
    });

    test('rotate gesture only for touch with rotation allowed', () {
      expect(
        InteractiveFlag.hasRotate(
          mapInteractionOptions(isTouch: true, allowRotation: true).flags,
        ),
        isTrue,
      );
      expect(
        InteractiveFlag.hasRotate(
          mapInteractionOptions(isTouch: true, allowRotation: false).flags,
        ),
        isFalse,
      );
      expect(
        InteractiveFlag.hasRotate(
          mapInteractionOptions(isTouch: false, allowRotation: true).flags,
        ),
        isFalse,
      );
    });

    test('gesture race enabled only when rotating by touch', () {
      expect(
        mapInteractionOptions(isTouch: true, allowRotation: true)
            .enableMultiFingerGestureRace,
        isTrue,
      );
      expect(
        mapInteractionOptions(isTouch: false, allowRotation: true)
            .enableMultiFingerGestureRace,
        isFalse,
      );
    });

    test('rotation threshold widened to 30 degrees', () {
      expect(
        mapInteractionOptions(isTouch: true, allowRotation: true)
            .rotationThreshold,
        30.0,
      );
    });

    test('scroll-wheel zoom and drag always enabled', () {
      for (final isTouch in [true, false]) {
        for (final allowRotation in [true, false]) {
          final o = mapInteractionOptions(
            isTouch: isTouch,
            allowRotation: allowRotation,
          );
          expect(InteractiveFlag.hasScrollWheelZoom(o.flags), isTrue);
          expect(InteractiveFlag.hasDrag(o.flags), isTrue);
        }
      }
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/maps/map_interaction_test.dart`
Expected: FAIL — `map_interaction.dart` / `mapInteractionOptions` not found (compile error).

- [ ] **Step 3: Write minimal implementation**

Create `lib/features/maps/presentation/widgets/map_interaction.dart`:

```dart
import 'package:flutter_map/flutter_map.dart';

/// Builds flutter_map [InteractionOptions] from the active pointer kind.
///
/// Touch keeps flutter_map's native pinch (focal-point zoom). Trackpad/mouse
/// drop the multi-finger and fling paths because [MapInteractionDetector]
/// drives trackpad zoom-to-cursor itself; mouse-wheel zoom and click-drag pan
/// stay with flutter_map.
InteractionOptions mapInteractionOptions({
  required bool isTouch,
  required bool allowRotation,
}) {
  final gestureRotate = allowRotation && isTouch;

  final int flags;
  if (isTouch) {
    flags = InteractiveFlag.drag |
        InteractiveFlag.flingAnimation |
        InteractiveFlag.pinchMove |
        InteractiveFlag.pinchZoom |
        InteractiveFlag.doubleTapZoom |
        InteractiveFlag.doubleTapDragZoom |
        InteractiveFlag.scrollWheelZoom |
        (gestureRotate ? InteractiveFlag.rotate : 0);
  } else {
    flags = InteractiveFlag.drag |
        InteractiveFlag.doubleTapZoom |
        InteractiveFlag.doubleTapDragZoom |
        InteractiveFlag.scrollWheelZoom;
  }

  return InteractionOptions(
    flags: flags,
    enableMultiFingerGestureRace: gestureRotate,
    rotationThreshold: 30.0,
    cursorKeyboardRotationOptions: allowRotation
        ? const CursorKeyboardRotationOptions()
        : CursorKeyboardRotationOptions.disabled(),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/maps/map_interaction_test.dart`
Expected: PASS (all `mapInteractionOptions` tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/maps/presentation/widgets/map_interaction.dart test/features/maps/map_interaction_test.dart
git commit -m "feat(maps): add pointer-kind-aware interaction options (#238)"
```

---

### Task 2: Pure helper `shouldShowResetNorth`

**Files:**
- Modify: `lib/features/maps/presentation/widgets/map_interaction.dart`
- Test: `test/features/maps/map_interaction_test.dart`

**Interfaces:**
- Produces: `bool shouldShowResetNorth(double rotationDeg, {double toleranceDeg = 0.5})`

- [ ] **Step 1: Write the failing test**

Add this group inside `main()` in `test/features/maps/map_interaction_test.dart`:

```dart
  group('shouldShowResetNorth', () {
    test('hidden at or near north', () {
      expect(shouldShowResetNorth(0), isFalse);
      expect(shouldShowResetNorth(0.3), isFalse);
      expect(shouldShowResetNorth(359.8), isFalse);
      expect(shouldShowResetNorth(360), isFalse);
    });

    test('shown when meaningfully rotated', () {
      expect(shouldShowResetNorth(15), isTrue);
      expect(shouldShowResetNorth(90), isTrue);
      expect(shouldShowResetNorth(200), isTrue);
      expect(shouldShowResetNorth(-15), isTrue);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/maps/map_interaction_test.dart`
Expected: FAIL — `shouldShowResetNorth` not defined.

- [ ] **Step 3: Write minimal implementation**

Add to the top of `lib/features/maps/presentation/widgets/map_interaction.dart` (after the import, before `mapInteractionOptions`), and add `import 'dart:math' as math;` at the very top:

```dart
import 'dart:math' as math;

/// Whether the reset-to-north control should be visible for [rotationDeg]
/// (degrees). Hidden within [toleranceDeg] of north (0/360).
bool shouldShowResetNorth(double rotationDeg, {double toleranceDeg = 0.5}) {
  final normalized = rotationDeg % 360; // Dart % yields [0, 360)
  final fromNorth = math.min(normalized, 360 - normalized);
  return fromNorth > toleranceDeg;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/maps/map_interaction_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/maps/presentation/widgets/map_interaction.dart test/features/maps/map_interaction_test.dart
git commit -m "feat(maps): add shouldShowResetNorth helper (#238)"
```

---

### Task 3: Localized reset-to-north tooltip string

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the 10 locale ARBs (`app_ar, app_de, app_es, app_fr, app_he, app_hu, app_it, app_nl, app_pt, app_zh`)

**Interfaces:**
- Produces: `context.l10n.maps_resetNorth_tooltip` (String)

- [ ] **Step 1: Add the English key + metadata**

In `lib/l10n/arb/app_en.arb`, add (keep file alphabetically grouped near other `maps_`/`map` keys; include the `@` metadata entry):

```json
  "maps_resetNorth_tooltip": "Reset map to north",
  "@maps_resetNorth_tooltip": {
    "description": "Tooltip and accessibility label for the button that resets map rotation to north-up"
  },
```

- [ ] **Step 2: Add the key to every locale ARB**

Add `"maps_resetNorth_tooltip": "<translation>",` to each file:

```
app_ar.arb: "maps_resetNorth_tooltip": "إعادة الخريطة إلى الشمال",
app_de.arb: "maps_resetNorth_tooltip": "Karte nach Norden ausrichten",
app_es.arb: "maps_resetNorth_tooltip": "Restablecer el mapa al norte",
app_fr.arb: "maps_resetNorth_tooltip": "Réinitialiser la carte vers le nord",
app_he.arb: "maps_resetNorth_tooltip": "אפס את המפה לצפון",
app_hu.arb: "maps_resetNorth_tooltip": "Térkép visszaállítása északra",
app_it.arb: "maps_resetNorth_tooltip": "Reimposta la mappa a nord",
app_nl.arb: "maps_resetNorth_tooltip": "Kaart op het noorden zetten",
app_pt.arb: "maps_resetNorth_tooltip": "Redefinir o mapa para o norte",
app_zh.arb: "maps_resetNorth_tooltip": "将地图重置为正北",
```

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/arb/app_localizations*.dart` with no errors.

- [ ] **Step 4: Verify it compiles and the getter exists**

Run: `flutter analyze lib/l10n`
Expected: exit 0, no issues. Confirm `AppLocalizations` now exposes `maps_resetNorth_tooltip`.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/arb
git commit -m "i18n(maps): add reset-to-north tooltip string in all locales (#238)"
```

---

### Task 4: `MapResetNorthButton` widget

**Files:**
- Modify: `lib/features/maps/presentation/widgets/map_interaction.dart`
- Test: `test/features/maps/map_interaction_test.dart`

**Interfaces:**
- Consumes: `shouldShowResetNorth` (Task 2), `context.l10n.maps_resetNorth_tooltip` (Task 3)
- Produces: `class MapResetNorthButton extends StatelessWidget` (const constructor, no required args)

- [ ] **Step 1: Write the failing widget test**

Add to `test/features/maps/map_interaction_test.dart` (add imports `package:flutter/material.dart`, `package:flutter_map/flutter_map.dart`, `package:latlong2/latlong.dart`, `package:flutter_localizations/flutter_localizations.dart`, `package:submersion/l10n/arb/app_localizations.dart`):

```dart
  group('MapResetNorthButton', () {
    Widget harness(MapController controller) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: FlutterMap(
                mapController: controller,
                options: const MapOptions(
                  initialCenter: LatLng(0, 0),
                  initialZoom: 3,
                ),
                children: const [MapResetNorthButton()],
              ),
            ),
          ),
        );

    testWidgets('hidden at north, shown when rotated, resets on tap',
        (tester) async {
      final controller = MapController();
      await tester.pumpWidget(harness(controller));
      await tester.pump();

      expect(find.byType(FloatingActionButton), findsNothing);

      controller.rotate(45);
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(controller.camera.rotation.abs() < 0.01, isTrue);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/maps/map_interaction_test.dart -n "MapResetNorthButton"`
Expected: FAIL — `MapResetNorthButton` not defined.

- [ ] **Step 3: Implement the widget**

Add to `lib/features/maps/presentation/widgets/map_interaction.dart` (add imports `package:flutter/material.dart`, `package:submersion/l10n/l10n_extension.dart`):

```dart
/// A self-hiding control that resets map rotation to north-up.
///
/// Placed inside [FlutterMap.children]. Reads live rotation via
/// [MapCamera.of] and resets via [MapController.of].
class MapResetNorthButton extends StatelessWidget {
  const MapResetNorthButton({super.key});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    if (!shouldShowResetNorth(camera.rotation)) {
      return const SizedBox.shrink();
    }
    final label = context.l10n.maps_resetNorth_tooltip;
    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: FloatingActionButton.small(
          heroTag: null,
          tooltip: label,
          onPressed: () => MapController.of(context).rotate(0),
          child: Transform.rotate(
            angle: camera.rotation * math.pi / 180,
            child: Semantics(
              label: label,
              child: const Icon(Icons.navigation),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/maps/map_interaction_test.dart -n "MapResetNorthButton"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/maps/presentation/widgets/map_interaction.dart test/features/maps/map_interaction_test.dart
git commit -m "feat(maps): add self-hiding reset-to-north button (#238)"
```

---

### Task 5: `MapInteractionDetector` — pointer-kind tracking

**Files:**
- Modify: `lib/features/maps/presentation/widgets/map_interaction.dart`
- Test: `test/features/maps/map_interaction_test.dart`

**Interfaces:**
- Consumes: `mapInteractionOptions` (Task 1)
- Produces: `class MapInteractionDetector extends StatefulWidget` with
  `MapInteractionDetector({required bool allowRotation, required MapController mapController, required Widget Function(BuildContext, InteractionOptions) builder})`

- [ ] **Step 1: Write the failing widget test**

Add to `test/features/maps/map_interaction_test.dart`:

```dart
  group('MapInteractionDetector pointer kind', () {
    testWidgets('flags reflect touch vs mouse pointer', (tester) async {
      late InteractionOptions latest;
      final controller = MapController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapInteractionDetector(
              allowRotation: true,
              mapController: controller,
              builder: (context, options) {
                latest = options;
                return const SizedBox(width: 400, height: 400);
              },
            ),
          ),
        ),
      );

      // Touch down -> pinch zoom enabled.
      final touch = await tester.startGesture(
        const Offset(200, 200),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();
      expect(InteractiveFlag.hasPinchZoom(latest.flags), isTrue);
      await touch.up();

      // Mouse hover -> pinch zoom disabled (trackpad/mouse path).
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(200, 200));
      await mouse.moveTo(const Offset(210, 210));
      await tester.pump();
      expect(InteractiveFlag.hasPinchZoom(latest.flags), isFalse);
      await mouse.removePointer();
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/maps/map_interaction_test.dart -n "pointer kind"`
Expected: FAIL — `MapInteractionDetector` not defined.

- [ ] **Step 3: Implement the widget (pointer tracking only)**

Add to `lib/features/maps/presentation/widgets/map_interaction.dart` (add imports `package:flutter/foundation.dart`, `package:flutter/gestures.dart`):

```dart
/// Wraps a [FlutterMap] to (1) choose [InteractionOptions] from the active
/// pointer kind and (2) drive trackpad zoom-to-cursor (added in the trackpad
/// handler). The map built by [builder] must fill this widget's box so that
/// pointer `localPosition` is in the map viewport coordinate space.
class MapInteractionDetector extends StatefulWidget {
  const MapInteractionDetector({
    super.key,
    required this.allowRotation,
    required this.mapController,
    required this.builder,
  });

  final bool allowRotation;
  final MapController mapController;
  final Widget Function(BuildContext context, InteractionOptions options)
      builder;

  @override
  State<MapInteractionDetector> createState() => _MapInteractionDetectorState();
}

class _MapInteractionDetectorState extends State<MapInteractionDetector> {
  late bool _isTouch = _defaultIsTouch();

  bool _defaultIsTouch() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
        return true;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  void _setTouch(bool value) {
    if (_isTouch != value) {
      setState(() => _isTouch = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = mapInteractionOptions(
      isTouch: _isTouch,
      allowRotation: widget.allowRotation,
    );
    return Listener(
      onPointerDown: (e) => _setTouch(e.kind == PointerDeviceKind.touch),
      onPointerHover: (e) => _setTouch(e.kind == PointerDeviceKind.touch),
      onPointerPanZoomStart: (e) => _setTouch(false),
      child: widget.builder(context, options),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/maps/map_interaction_test.dart -n "pointer kind"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/maps/presentation/widgets/map_interaction.dart test/features/maps/map_interaction_test.dart
git commit -m "feat(maps): add MapInteractionDetector pointer-kind tracking (#238)"
```

---

### Task 6: `MapInteractionDetector` — trackpad zoom-to-cursor + pan

**Files:**
- Modify: `lib/features/maps/presentation/widgets/map_interaction.dart`
- Test: `test/features/maps/map_interaction_test.dart`

**Interfaces:**
- Consumes: `widget.mapController` (`camera`, `move`, `camera.focusedZoomCenter`, `camera.clampZoom`, `camera.projectAtZoom`/`unprojectAtZoom`)
- Produces: trackpad `PointerPanZoom*` handling inside `MapInteractionDetector`

- [ ] **Step 1: Write the failing widget test**

Add to `test/features/maps/map_interaction_test.dart`:

```dart
  group('MapInteractionDetector trackpad zoom', () {
    testWidgets('pinch zooms in and keeps the anchor point fixed',
        (tester) async {
      final controller = MapController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: MapInteractionDetector(
                allowRotation: false,
                mapController: controller,
                builder: (context, options) => FlutterMap(
                  mapController: controller,
                  options: MapOptions(
                    initialCenter: const LatLng(0, 0),
                    initialZoom: 3,
                    interactionOptions: options,
                  ),
                  children: const [],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      const anchor = Offset(300, 120); // off-center
      final latLngUnderAnchorBefore =
          controller.camera.offsetToCrs(anchor);
      final zoomBefore = controller.camera.zoom;

      final pointer = TestPointer(1, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pointer.panZoomStart(anchor));
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(anchor, scale: 2.0),
      );
      await tester.pump();
      await tester.sendEventToBinding(pointer.panZoomEnd());
      await tester.pump();

      expect(controller.camera.zoom, greaterThan(zoomBefore));
      final latLngUnderAnchorAfter = controller.camera.offsetToCrs(anchor);
      expect(
        (latLngUnderAnchorAfter.latitude - latLngUnderAnchorBefore.latitude)
            .abs(),
        lessThan(0.5),
      );
      expect(
        (latLngUnderAnchorAfter.longitude - latLngUnderAnchorBefore.longitude)
            .abs(),
        lessThan(0.5),
      );
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/maps/map_interaction_test.dart -n "trackpad zoom"`
Expected: FAIL — zoom unchanged (no trackpad handler yet), so `greaterThan(zoomBefore)` fails.

- [ ] **Step 3: Implement the trackpad handler**

In `_MapInteractionDetectorState`, add gesture state fields and handlers, and wire the `Listener`'s pan/zoom callbacks:

```dart
  double _gestureStartZoom = 0;
  Offset _gestureAnchor = Offset.zero;
  Offset _lastPan = Offset.zero;

  static Offset _rotateOffset(Offset offset, double radians) {
    if (radians == 0) return offset;
    final cos = math.cos(radians);
    final sin = math.sin(radians);
    return Offset(
      cos * offset.dx + sin * offset.dy,
      cos * offset.dy - sin * offset.dx,
    );
  }

  void _onPanZoomStart(PointerPanZoomStartEvent e) {
    _setTouch(false);
    _gestureStartZoom = widget.mapController.camera.zoom;
    _gestureAnchor = e.localPosition;
    _lastPan = Offset.zero;
  }

  void _onPanZoomUpdate(PointerPanZoomUpdateEvent e) {
    final cam = widget.mapController.camera;
    final targetZoom =
        cam.clampZoom(_gestureStartZoom + math.log(e.scale) / math.ln2);
    var center = cam.focusedZoomCenter(_gestureAnchor, targetZoom);

    final panDelta = e.localPan - _lastPan;
    _lastPan = e.localPan;
    if (panDelta != Offset.zero) {
      final projected = cam.projectAtZoom(center, targetZoom);
      center = cam.unprojectAtZoom(
        projected - _rotateOffset(panDelta, cam.rotationRad),
        targetZoom,
      );
    }
    widget.mapController.move(center, targetZoom);
  }
```

Update the `Listener` in `build`:

```dart
    return Listener(
      onPointerDown: (e) => _setTouch(e.kind == PointerDeviceKind.touch),
      onPointerHover: (e) => _setTouch(e.kind == PointerDeviceKind.touch),
      onPointerPanZoomStart: _onPanZoomStart,
      onPointerPanZoomUpdate: _onPanZoomUpdate,
      child: widget.builder(context, options),
    );
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/maps/map_interaction_test.dart`
Expected: PASS (all groups, including trackpad zoom).

- [ ] **Step 5: Verify pan direction manually note + format**

Run: `dart format lib/features/maps/presentation/widgets/map_interaction.dart`
Expected: no changes (already formatted). The two-finger-scroll pan sign is confirmed during the Task 13 manual checklist; if scrolling pans the wrong way, negate `panDelta` in `_onPanZoomUpdate`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/maps/presentation/widgets/map_interaction.dart test/features/maps/map_interaction_test.dart
git commit -m "feat(maps): trackpad zoom-to-cursor and pan in MapInteractionDetector (#238)"
```

---

### Task 7: Apply to dive_sites overview maps

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_map_page.dart` (FlutterMap ~line 221; controller `_mapController`)
- Modify: `lib/features/dive_sites/presentation/widgets/site_map_content.dart` (FlutterMap ~line 245; controller `_mapController`)

Apply the **Overview Pattern** (`allowRotation: true`, add `MapResetNorthButton`) to both. Add the `map_interaction.dart` import to each.

- [ ] **Step 1:** Wrap `site_map_page.dart`'s `FlutterMap` per the Overview Pattern; set `interactionOptions: interactionOptions`; add `const MapResetNorthButton()` as the last child.
- [ ] **Step 2:** Wrap `site_map_content.dart`'s `FlutterMap` the same way.
- [ ] **Step 3:** Run: `flutter analyze lib/features/dive_sites` → expect exit 0, no issues.
- [ ] **Step 4:** Run: `dart format lib/features/dive_sites/presentation/pages/site_map_page.dart lib/features/dive_sites/presentation/widgets/site_map_content.dart` → no changes.
- [ ] **Step 5: Commit**

```bash
git add lib/features/dive_sites/presentation/pages/site_map_page.dart lib/features/dive_sites/presentation/widgets/site_map_content.dart
git commit -m "feat(maps): apply interaction detector to dive-site overview maps (#238)"
```

---

### Task 8: Apply to dive_sites locked maps (north-up)

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (two FlutterMaps: inline ~line 387, fullscreen ~line 487; controller is that page's `MapController`)
- Modify: `lib/features/dive_sites/presentation/widgets/location_picker_map.dart` (FlutterMap ~line 159; controller `_mapController`)
- Modify: `lib/features/dive_sites/presentation/widgets/match_sites_map.dart` (FlutterMap ~line 55; controller `_mapController`)

Apply the **Locked Pattern** (`allowRotation: false`, NO reset button) to all four `FlutterMap` instances. These currently set `flags: InteractiveFlag.all & ~InteractiveFlag.rotate` or `InteractiveFlag.all` — replace that `interactionOptions` with the detector-provided one. Add the import to each file.

- [ ] **Step 1:** Wrap both `FlutterMap`s in `site_detail_page.dart` (Locked Pattern). Use the page's existing `MapController` for each; if the inline and fullscreen maps share one controller that is fine.
- [ ] **Step 2:** Wrap `location_picker_map.dart`'s `FlutterMap` (Locked Pattern), removing its `flags: InteractiveFlag.all & ~InteractiveFlag.rotate`.
- [ ] **Step 3:** Wrap `match_sites_map.dart`'s `FlutterMap` (Locked Pattern), removing its `flags: InteractiveFlag.all`.
- [ ] **Step 4:** Run: `flutter analyze lib/features/dive_sites` → exit 0.
- [ ] **Step 5:** Run: `flutter test test/features/dive_sites/presentation/widgets/match_sites_map_test.dart` → PASS.
- [ ] **Step 6:** Run: `dart format` on the three files → no changes.
- [ ] **Step 7: Commit**

```bash
git add lib/features/dive_sites/presentation/pages/site_detail_page.dart lib/features/dive_sites/presentation/widgets/location_picker_map.dart lib/features/dive_sites/presentation/widgets/match_sites_map.dart
git commit -m "feat(maps): lock dive-site detail and picker maps to north-up (#238)"
```

---

### Task 9: Apply to dive_log maps

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_map_content.dart` (FlutterMap ~line 289; controller `_mapController`) — **Overview Pattern**
- Modify: `lib/features/dive_log/presentation/widgets/dive_locations_map.dart` (FlutterMap ~line 132; controller is the nullable `controller` param) — **Locked Pattern, only when interactive**

`dive_locations_map.dart` currently uses `flags: interactive ? InteractiveFlag.all : InteractiveFlag.none`. Only wrap with the detector when `interactive == true`; when `interactive == false`, keep `InteractiveFlag.none` and do NOT wrap. Its controller field is `MapController? controller`; the detector needs a non-null controller — pass `controller ?? _fallbackController`, creating a `late final MapController _fallbackController = MapController();` in state if the widget does not already own one.

- [ ] **Step 1:** Wrap `dive_map_content.dart`'s `FlutterMap` (Overview Pattern + reset button).
- [ ] **Step 2:** In `dive_locations_map.dart`, build the map two ways: when `interactive` is true, wrap in `MapInteractionDetector` (Locked Pattern, `allowRotation: false`, no reset button) passing the effective controller and `interactionOptions`; when false, render `FlutterMap` with `interactionOptions: const InteractionOptions(flags: InteractiveFlag.none)` (unchanged behavior).
- [ ] **Step 3:** Run: `flutter analyze lib/features/dive_log` → exit 0.
- [ ] **Step 4:** Run: `flutter test test/features/dive_log/presentation/widgets/dive_locations_map_test.dart test/features/dive_log/presentation/pages/dive_locations_map_page_test.dart` → PASS.
- [ ] **Step 5:** `dart format` the two files → no changes.
- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/dive_map_content.dart lib/features/dive_log/presentation/widgets/dive_locations_map.dart
git commit -m "feat(maps): apply interaction detector to dive-log maps (#238)"
```

---

### Task 10: Apply to trips map

**Files:**
- Modify: `lib/features/trips/presentation/widgets/trip_voyage_map.dart` (FlutterMap ~line 60; controller — add one if absent)

Apply the **Overview Pattern** (`allowRotation: true` + reset button). `trip_voyage_map.dart` currently has only `initialCenter`/`initialZoom` and no explicit controller; if there is no `MapController` field, add `final MapController _mapController = MapController();` (or `late final` in a State) and pass it to both the detector and `FlutterMap`.

- [ ] **Step 1:** Add a `MapController` if missing; wrap the `FlutterMap` (Overview Pattern + reset button).
- [ ] **Step 2:** Run: `flutter analyze lib/features/trips` → exit 0.
- [ ] **Step 3:** `dart format lib/features/trips/presentation/widgets/trip_voyage_map.dart` → no changes.
- [ ] **Step 4: Commit**

```bash
git add lib/features/trips/presentation/widgets/trip_voyage_map.dart
git commit -m "feat(maps): apply interaction detector to trip voyage map (#238)"
```

---

### Task 11: Apply to dive_centers maps

**Files:**
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_map_page.dart` (FlutterMap ~line 205; controller `_mapController`) — **Overview Pattern**
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_map_content.dart` (FlutterMap ~line 198; controller `_mapController`) — **Overview Pattern**
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart` (two FlutterMaps: inline ~line 595, fullscreen ~line 690) — **Locked Pattern**

The two detail maps currently set `flags: InteractiveFlag.all & ~InteractiveFlag.rotate` — replace with detector-provided options, `allowRotation: false`, no reset button.

- [ ] **Step 1:** Wrap `dive_center_map_page.dart` (Overview Pattern + reset).
- [ ] **Step 2:** Wrap `dive_center_map_content.dart` (Overview Pattern + reset).
- [ ] **Step 3:** Wrap both `FlutterMap`s in `dive_center_detail_page.dart` (Locked Pattern).
- [ ] **Step 4:** Run: `flutter analyze lib/features/dive_centers` → exit 0.
- [ ] **Step 5:** `dart format` the three files → no changes.
- [ ] **Step 6: Commit**

```bash
git add lib/features/dive_centers/presentation/pages/dive_center_map_page.dart lib/features/dive_centers/presentation/widgets/dive_center_map_content.dart lib/features/dive_centers/presentation/pages/dive_center_detail_page.dart
git commit -m "feat(maps): apply interaction detector to dive-center maps (#238)"
```

---

### Task 12: Apply to dive activity map

**Files:**
- Modify: `lib/features/maps/presentation/pages/dive_activity_map_page.dart` (FlutterMap ~line 256; controller `_mapController`)

Apply the **Overview Pattern** (`allowRotation: true` + reset button).

- [ ] **Step 1:** Wrap the `FlutterMap` (Overview Pattern + reset button).
- [ ] **Step 2:** Run: `flutter analyze lib/features/maps` → exit 0.
- [ ] **Step 3:** `dart format lib/features/maps/presentation/pages/dive_activity_map_page.dart` → no changes.
- [ ] **Step 4: Commit**

```bash
git add lib/features/maps/presentation/pages/dive_activity_map_page.dart
git commit -m "feat(maps): apply interaction detector to dive activity map (#238)"
```

---

### Task 13: Full verification and manual gesture checklist

**Files:** none (verification only)

- [ ] **Step 1: Whole-project analyze**

Run: `flutter analyze`
Expected: exit 0, "No issues found!". (Do not pipe through `tail` — capture the real exit code.)

- [ ] **Step 2: Format check**

Run: `dart format --set-exit-if-changed lib/ test/`
Expected: exit 0 (no files changed).

- [ ] **Step 3: Run the new + impacted tests**

Run:
```bash
flutter test test/features/maps/map_interaction_test.dart \
  test/features/dive_sites/presentation/widgets/match_sites_map_test.dart \
  test/features/dive_log/presentation/widgets/dive_locations_map_test.dart \
  test/features/dive_log/presentation/pages/dive_locations_map_page_test.dart
```
Expected: all PASS.

- [ ] **Step 4: Manual gesture checklist** (run `flutter run -d macos`, and on a touch device if available)

Verify and record results for:
1. Trackpad pinch on an overview map zooms toward the cursor (not flying off-screen).
2. Two-finger trackpad scroll pans the map in the natural direction (if reversed, negate `panDelta` in `_onPanZoomUpdate` from Task 6 and re-run Step 3).
3. Mouse scroll wheel zooms toward the cursor.
4. Click-drag pans.
5. On an overview map, a deliberate two-finger twist past ~30 degrees rotates; small twists do not; the reset-to-north button appears and returns the map to north when tapped.
6. On a detail map and a picker, the map cannot be rotated and no reset button appears.

- [ ] **Step 5: Final commit (if Step 2/4 required any tweak)**

```bash
git add -A
git commit -m "fix(maps): finalize touchpad interaction behavior (#238)"
```

---

## Self-Review

- **Spec coverage:** zoom-to-cursor (Tasks 5-6, 7-12), rotation deadband (Task 1 flags + race, applied Tasks 7-12), reset-to-north (Tasks 3-4, overview maps), pointer-kind detection (Task 5), per-map policy incl. north-up-locked detail/pickers and untouched region/static maps (Tasks 7-12), tests (Tasks 1-6 + 13). All spec sections map to tasks.
- **Placeholders:** none — every code step contains full code; per-file application tasks give exact files, controllers, pattern, and flags.
- **Type consistency:** `mapInteractionOptions({isTouch, allowRotation})`, `shouldShowResetNorth(double, {toleranceDeg})`, `MapInteractionDetector({allowRotation, mapController, builder})`, `MapResetNorthButton()` are used identically across tasks.
