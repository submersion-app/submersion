# 3D Flythrough PR 2: Path Reconstruction + Flythrough Scene - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reconstruct the dive's real-world 3D path from GPS anchors + heading + surface tracks, and render it as a spatial flythrough scene (follow-cam, orbit, presets, stat lanes, ceiling sheet) built on the dive_3d feature from PR #565.

**Architecture:** A pure `DivePathReconstructor` (dive_log domain) turns anchors/heading/surface-fixes/profile into a `ReconstructedPath` in local meters with a `PathFidelity` tag. A new spatial geometry layer inside `lib/features/dive_3d/` (path frames + path-ribbon/lane/ceiling builders) emits the same `MeshData`/`Dive3dGeometry` shapes #565's renderers already consume, so `SceneViewport` (GL), `SceneProjector`/`Dive3dPreviewPainter` (software fallback), and `ThreeAdapter` are reused unchanged except for an added follow-cam mode. The flythrough page follows `Dive3dPage`'s local-`ValueNotifier` scrub pattern.

**Tech Stack:** three_js_core/three_js_math/three_js_angle_renderer (via the submersion-app/flutter_angle fork override, already wired by #565), Riverpod, existing Buhlmann analysis pipeline.

**Spec:** `docs/superpowers/specs/2026-07-11-3d-flythrough-design.md` (see the PR-2 addendum section added 2026-07-11).

## Global Constraints

- HARD GATE: this plan executes only after PR #563 (heading pipeline, v105) AND PR #565 (dive_3d + flutter_angle fork override) are merged to main. Task 0 verifies both.
- Do NOT modify `SceneBounds`, `RibbonBuilder`, `CeilingBuilder`, `GridBuilder`, `StrataBuilder`, or `MarkerLayout` time-axis behavior - the analytical scene keeps working exactly as #565 shipped it. Spatial geometry lives in NEW files.
- Engine imports (`three_js_*`) are allowed ONLY in `three_adapter.dart` and `scene_viewport.dart` (both exist). New geometry code must be pure Dart emitting `MeshData`.
- Timestamp conventions (from gps_log): track POINTS are wall-clock-as-UTC epoch SECONDS; track startTime/endTime are epoch MILLISECONDS; dive times are wall-clock-as-UTC. Use `toWallClockEpochSeconds` from `track_point_codec.dart`; never mix units.
- Dive-level GPS anchors are `Dive.entryLocation` / `Dive.exitLocation` (`GeoPoint?`), per-source values are `DiveDataSource.entryLatitude` (`double?`) etc., site fallback is `dive.site?.location`.
- TTS series comes from `profileAnalysisProvider(diveId)` -> `analysis.decoStatuses[i].ttsSeconds`; NDL from `dive_profiles.ndl` with `analysis.ndlCurve` fallback. No new deco code.
- Out-and-back defaults (spec): bearing = first heading sample else due north; speed 12 m/min; cap 250 m out.
- All user-visible strings via l10n keys added to `app_en.arb` AND all 10 non-en locales (`ar de es fr he hu it nl pt zh`), then `flutter gen-l10n`.
- Every value shown with units respects the active diver's unit settings (`UnitFormatter`, as `scene_readout_panel.dart` does).
- `dart format .` before every commit; whole-project `flutter analyze` unpiped; run test DIRECTORIES not the whole suite.
- Worktree rules: init with submodules + pub get + build_runner; worktree-absolute paths in edits; `git push --no-verify`; no bare `git stash`.
- No emojis. No PR attribution/session URL. Schema: NO new migration in this PR.

---

### Task 0: Merge gate + worktree

**Files:** none (environment only)

- [ ] **Step 1: Verify the gate**

```bash
cd /Users/ericgriffin/repos/submersion-app/submersion
git fetch origin main
git log origin/main --oneline | head -30
```

Confirm BOTH are present in origin/main history: the #563 heading commits (look for "feat(db): add dive_profiles.heading column") and the #565 merge (look for dive_3d / "3D" merge commit). If either is missing, STOP - report that the gate is not met.

- [ ] **Step 2: Create and initialize the worktree**

```bash
git worktree add .claude/worktrees/flythrough-pr2 -b worktree-flythrough-pr2 origin/main
cd .claude/worktrees/flythrough-pr2
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Expected: all succeed. `grep -n "flutter_angle" pubspec.yaml` shows the git-fork dependency_overrides stanza (came in with #565).

---

### Task 1: `ReconstructedPath` entity + local ENU projection

**Files:**
- Create: `lib/features/dive_log/domain/entities/reconstructed_path.dart`
- Test: `test/features/dive_log/domain/entities/reconstructed_path_test.dart`

**Interfaces:**
- Produces:
  - `enum PathFidelity { headingTrack, anchored, outAndBack }`
  - `class PathPoint { final int timestamp; final double east; final double north; final double depth; }` (meters, local frame centered on the entry anchor)
  - `class ReconstructedPath { final List<PathPoint> points; final PathFidelity fidelity; final bool lowConfidence; double get horizontalExtentMeters; }`
  - `class LocalEnuProjector { LocalEnuProjector(GeoPoint origin); ({double east, double north}) project(double latitude, double longitude); }`

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_log/domain/entities/reconstructed_path_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/reconstructed_path.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  test('LocalEnuProjector maps origin to (0,0) and is locally linear', () {
    const origin = GeoPoint(20.0, -87.0);
    final proj = LocalEnuProjector(origin);

    final o = proj.project(20.0, -87.0);
    expect(o.east, closeTo(0, 1e-9));
    expect(o.north, closeTo(0, 1e-9));

    // 0.001 deg latitude ~ 111.32 m north.
    final n = proj.project(20.001, -87.0);
    expect(n.north, closeTo(111.32, 0.5));
    expect(n.east, closeTo(0, 1e-6));

    // 0.001 deg longitude at lat 20 ~ 111.32 * cos(20 deg) ~ 104.61 m east.
    final e = proj.project(20.0, -86.999);
    expect(e.east, closeTo(104.61, 0.5));
    expect(e.north, closeTo(0, 1e-6));
  });

  test('ReconstructedPath exposes horizontal extent', () {
    const points = [
      PathPoint(timestamp: 0, east: 0, north: 0, depth: 0),
      PathPoint(timestamp: 60, east: 30, north: 40, depth: 18),
      PathPoint(timestamp: 120, east: 0, north: 80, depth: 5),
    ];
    const path = ReconstructedPath(
      points: points,
      fidelity: PathFidelity.anchored,
    );
    expect(path.horizontalExtentMeters, closeTo(80.0, 1e-9));
    expect(path.lowConfidence, isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/domain/entities/reconstructed_path_test.dart`
Expected: FAIL (file does not exist / compile error).

- [ ] **Step 3: Implement the entity**

Create `lib/features/dive_log/domain/entities/reconstructed_path.dart`:

```dart
import 'dart:math' as math;

import 'package:equatable/equatable.dart';

import '../../../dive_sites/domain/entities/dive_site.dart';

/// How much of the reconstructed horizontal shape is backed by real data.
/// Depth is always real; only the horizontal component is estimated.
enum PathFidelity {
  /// Compass-integrated shape, closure-corrected onto GPS anchors.
  headingTrack,

  /// Time-proportional interpolation between two or more GPS fixes.
  anchored,

  /// Single anchor only: synthetic out-and-back leg.
  outAndBack,
}

/// One reconstructed sample in the local east/north/depth frame (meters),
/// centered on the entry anchor.
class PathPoint extends Equatable {
  final int timestamp; // seconds from dive start
  final double east;
  final double north;
  final double depth; // meters, positive down (matches DiveProfilePoint)

  const PathPoint({
    required this.timestamp,
    required this.east,
    required this.north,
    required this.depth,
  });

  @override
  List<Object?> get props => [timestamp, east, north, depth];
}

class ReconstructedPath extends Equatable {
  final List<PathPoint> points;
  final PathFidelity fidelity;

  /// Set when inputs were degenerate (e.g. anchors implausibly far apart)
  /// and the result was clamped; the UI badge notes low confidence.
  final bool lowConfidence;

  const ReconstructedPath({
    required this.points,
    required this.fidelity,
    this.lowConfidence = false,
  });

  /// Largest horizontal distance from the entry anchor, in meters.
  double get horizontalExtentMeters {
    var maxSq = 0.0;
    for (final p in points) {
      final d = p.east * p.east + p.north * p.north;
      if (d > maxSq) maxSq = d;
    }
    return math.sqrt(maxSq);
  }

  @override
  List<Object?> get props => [points, fidelity, lowConfidence];
}

/// Equirectangular projection into a local east/north meters frame.
/// Exact enough at dive scale (hundreds of meters).
class LocalEnuProjector {
  static const double _metersPerDegLat = 111320.0;
  final GeoPoint origin;
  final double _metersPerDegLon;

  LocalEnuProjector(this.origin)
    : _metersPerDegLon =
          _metersPerDegLat * math.cos(origin.latitude * math.pi / 180.0);

  ({double east, double north}) project(double latitude, double longitude) {
    return (
      east: (longitude - origin.longitude) * _metersPerDegLon,
      north: (latitude - origin.latitude) * _metersPerDegLat,
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_log/domain/entities/reconstructed_path_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A && git commit -m "feat(flythrough): add ReconstructedPath entity and local ENU projector"
```

---

### Task 2: `DivePathReconstructor` - the three tiers

**Files:**
- Create: `lib/features/dive_log/domain/services/dive_path_reconstructor.dart`
- Test: `test/features/dive_log/domain/services/dive_path_reconstructor_test.dart`

**Interfaces:**
- Consumes: `ReconstructedPath`/`PathPoint`/`PathFidelity`/`LocalEnuProjector` (Task 1), `DiveProfilePoint` (has `heading double?` since #563), `GeoPoint`.
- Produces:

```dart
class SurfaceFix {
  final int timestamp; // seconds from dive start
  final GeoPoint position;
}

class DivePathReconstructor {
  const DivePathReconstructor();
  /// Total: never throws. Returns null ONLY when there is no position data
  /// at any tier (no anchors and no fixes) or fewer than 2 profile points.
  ReconstructedPath? reconstruct({
    required List<DiveProfilePoint> profile,
    GeoPoint? entryAnchor,
    GeoPoint? exitAnchor,
    List<SurfaceFix> surfaceFixes = const [],
  });
}
```

Constants (match spec): `assumedSpeedMetersPerMin = 12.0`, `outAndBackCapMeters = 250.0`, `implausibleAnchorSpanMeters = 5000.0` (beyond this: clamp to 5 km direction-preserving and set `lowConfidence`).

Algorithm (implement exactly):

1. Guard: `profile.length < 2` -> null. No entry, no exit, no fixes -> null. Sort profile by timestamp.
2. Resolve the frame origin: `entryAnchor ?? exitAnchor ?? surfaceFixes.first.position`. Build `LocalEnuProjector(origin)`.
3. Build the fix list in local meters: entry anchor at `t = profile.first.timestamp`, each surface fix at its timestamp (clamped into the profile range, deduplicated by timestamp), exit anchor at `t = profile.last.timestamp`. Single-anchor case: only one fix total.
4. Tier selection:
   - `>= 2` distinct fixes AND `>= 50%` of profile samples have non-null heading -> heading tier.
   - `>= 2` distinct fixes -> anchored tier.
   - exactly 1 fix -> out-and-back tier.
5. **Anchored tier:** for each profile sample, find its bracketing fixes; horizontal position = linear interpolation between the two fixes weighted by elapsed time within the bracket. Samples before the first / after the last fix clamp to it.
6. **Heading tier:** integrate a unit step per sample interval: `dx += sin(headingRad) * dt`, `dz += cos(headingRad) * dt` (carry the last non-null heading forward across null samples). Then per fix-bracketed SEGMENT apply the affine closure correction: solve the similarity transform (rotate theta, scale s, translate) mapping the raw integrated positions at the segment's endpoint times onto the segment's two fixes: with raw segment vector `v` and target vector `w`, `s = |w|/|v|` (if `|v| < 1e-6`, fall back to anchored interpolation for that segment), `theta = atan2(w) - atan2(v)`; apply to every point in the segment, then translate so the segment start lands on its fix. If `s` would exceed 50 (compass shape near-degenerate), fall back to anchored for that segment.
7. **Out-and-back tier:** bearing = first non-null heading in profile, else 0.0 (north). Out distance = `min(assumedSpeedMetersPerMin * (duration/60) / 2, outAndBackCapMeters)`. Position advances linearly out along the bearing until half-time, then back, landing exactly on the anchor at the end.
8. Post-check: if the distance between any two fixes exceeds `implausibleAnchorSpanMeters`, scale ALL horizontal coordinates by `implausibleAnchorSpanMeters / span` and set `lowConfidence = true`.
9. Depth passthrough: every `PathPoint.depth = sample.depth`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_log/domain/services/dive_path_reconstructor_test.dart` with these cases (write them ALL before implementing; use a `profile(n, {headings})` helper building `DiveProfilePoint`s at 60 s spacing):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/reconstructed_path.dart';
import 'package:submersion/features/dive_log/domain/services/dive_path_reconstructor.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

List<DiveProfilePoint> profile(int n, {double? Function(int i)? heading}) {
  return List.generate(
    n,
    (i) => DiveProfilePoint(
      timestamp: i * 60,
      depth: 10.0,
      heading: heading?.call(i),
    ),
  );
}

void main() {
  const r = DivePathReconstructor();
  const entry = GeoPoint(20.0, -87.0);
  // ~104.6 m east of entry at this latitude.
  const exit = GeoPoint(20.0, -86.999);

  test('returns null with no position data', () {
    expect(r.reconstruct(profile: profile(10)), isNull);
  });

  test('returns null with fewer than 2 profile points', () {
    expect(
      r.reconstruct(profile: profile(1), entryAnchor: entry),
      isNull,
    );
  });

  test('anchored: endpoints land exactly on the anchors', () {
    final path = r.reconstruct(
      profile: profile(11),
      entryAnchor: entry,
      exitAnchor: exit,
    )!;
    expect(path.fidelity, PathFidelity.anchored);
    expect(path.points.first.east, closeTo(0, 1e-6));
    expect(path.points.first.north, closeTo(0, 1e-6));
    expect(path.points.last.east, closeTo(104.61, 0.5));
    expect(path.points.last.north, closeTo(0, 1e-6));
    // Time-proportional: midpoint sample sits halfway.
    expect(path.points[5].east, closeTo(path.points.last.east / 2, 0.5));
  });

  test('heading tier selected when >=50% samples have heading, '
      'closure lands on both anchors', () {
    // Constant heading 90 (due east) - shape is a straight east line,
    // which the closure maps exactly onto the entry->exit vector.
    final path = r.reconstruct(
      profile: profile(11, heading: (_) => 90.0),
      entryAnchor: entry,
      exitAnchor: exit,
    )!;
    expect(path.fidelity, PathFidelity.headingTrack);
    expect(path.points.first.east, closeTo(0, 1e-6));
    expect(path.points.last.east, closeTo(104.61, 0.5));
    expect(path.points.last.north, closeTo(0, 0.5));
  });

  test('heading tier: turning shape is preserved (not straight-lined)', () {
    // 90 deg for the first half, 0 deg (north) for the second half:
    // the mid-path sample must deviate from the straight entry->exit chord.
    final path = r.reconstruct(
      profile: profile(21, heading: (i) => i < 10 ? 90.0 : 0.0),
      entryAnchor: entry,
      exitAnchor: exit,
    )!;
    expect(path.fidelity, PathFidelity.headingTrack);
    final mid = path.points[10];
    // On the chord, north would be ~0 at every point.
    expect(mid.north.abs(), greaterThan(5.0));
    expect(path.points.last.east, closeTo(104.61, 0.5));
  });

  test('out-and-back: single anchor, returns to anchor, capped extent', () {
    final path = r.reconstruct(
      profile: profile(61), // 1 hour
      entryAnchor: entry,
    )!;
    expect(path.fidelity, PathFidelity.outAndBack);
    expect(path.points.first.east, closeTo(0, 1e-6));
    expect(path.points.last.east, closeTo(0, 1e-6));
    expect(path.points.last.north, closeTo(0, 1e-6));
    // 12 m/min * 30 min out = 360 -> capped at 250.
    expect(path.horizontalExtentMeters, closeTo(250.0, 1.0));
  });

  test('surface fixes become interior anchors', () {
    final path = r.reconstruct(
      profile: profile(11),
      entryAnchor: entry,
      exitAnchor: entry, // same point in and out
      surfaceFixes: const [
        SurfaceFix(timestamp: 300, position: GeoPoint(20.0, -86.999)),
      ],
    )!;
    expect(path.fidelity, PathFidelity.anchored);
    // The t=300 sample sits on the interior fix, ~104.6 m east.
    expect(path.points[5].east, closeTo(104.61, 0.5));
    expect(path.points.last.east, closeTo(0, 1e-6));
  });

  test('implausible anchor span clamps and flags low confidence', () {
    final path = r.reconstruct(
      profile: profile(11),
      entryAnchor: entry,
      exitAnchor: const GeoPoint(21.0, -87.0), // ~111 km away
    )!;
    expect(path.lowConfidence, isTrue);
    expect(path.horizontalExtentMeters, lessThanOrEqualTo(5000.0 + 1.0));
  });

  test('never throws on degenerate zero-duration profile', () {
    final twoSame = [
      const DiveProfilePoint(timestamp: 0, depth: 5.0),
      const DiveProfilePoint(timestamp: 0, depth: 5.0),
    ];
    final path = r.reconstruct(
      profile: twoSame,
      entryAnchor: entry,
      exitAnchor: exit,
    );
    expect(path, isNotNull); // clamped, not thrown
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/domain/services/dive_path_reconstructor_test.dart`
Expected: FAIL (service missing).

- [ ] **Step 3: Implement `DivePathReconstructor`**

Create `lib/features/dive_log/domain/services/dive_path_reconstructor.dart` implementing the algorithm above exactly (tiers, closure correction with the degenerate-|v| and s>50 fallbacks, out-and-back, clamp). Keep it a single pure file, no imports outside `dart:math`, the two entity files, and `dive.dart`. `SurfaceFix` is a small const class in this file:

```dart
class SurfaceFix {
  final int timestamp; // seconds from dive start
  final GeoPoint position;
  const SurfaceFix({required this.timestamp, required this.position});
}
```

- [ ] **Step 4: Run tests until green**

Run: `flutter test test/features/dive_log/domain/services/dive_path_reconstructor_test.dart`
Expected: all 9 PASS. Iterate on the implementation, not the tests (the tests encode the spec).

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A && git commit -m "feat(flythrough): tiered dive path reconstruction service"
```

---

### Task 3: Spatial geometry - path frames + flythrough builders

**Files:**
- Create: `lib/features/dive_3d/domain/geometry/path_frame.dart`
- Create: `lib/features/dive_3d/domain/geometry/path_ribbon_builder.dart`
- Create: `lib/features/dive_3d/domain/flythrough_scene_service.dart`
- Test: `test/features/dive_3d/domain/geometry/path_frame_test.dart`
- Test: `test/features/dive_3d/domain/flythrough_scene_service_test.dart`

**Interfaces:**
- Consumes: `ReconstructedPath` (Task 1), `Dive3dSceneData`, `MeshData`, `Dive3dGeometry`, `SceneMarker`/`MarkerLayout` kinds, `MetricPalette.colorsFor`, `decimateSeriesIndices` (all from #565, unchanged).
- Produces:

```dart
/// Scene-space centerline with per-sample lateral direction for lane offsets.
class PathFrames {
  final List<double> xs, ys, zs;          // scene units, per decimated sample
  final List<double> sideX, sideZ;        // unit horizontal normal per sample
  final List<double> times;               // seconds, same indexing
  final double sceneSpan;                 // normalization used (for grid/camera)
  ({double x, double y, double z}) positionAt(double t); // interpolated
}

class PathFrameBuilder {
  static PathFrames build({required ReconstructedPath path, double sceneSpan = 10.0, double ySpan = 6.0, required double maxDepthMeters});
}

class PathRibbonBuilder {
  static MeshData tube({required PathFrames frames, required Float32List sampleColors, double halfWidth = 0.12});
  static MeshData lane({required PathFrames frames, required List<double?> values, required Float32List sampleColors, required double lateralOffset, double laneHeightSpan = 1.2});
  static MeshData? ceilingSheet({required PathFrames frames, required List<double?> ceilings, required double maxDepthMeters, required double ySpan});
  static MeshData waterSurface({required PathFrames frames});
}

class FlythroughGeometry {
  final Dive3dGeometry base;       // ribbon=tube, ceilingSurface=sheet, grid=waterSurface reuse slots
  final PathFrames frames;
  final List<LaneSpec> lanes;      // (metric label key, MeshData)
}

class FlythroughSceneService {
  const FlythroughSceneService();
  FlythroughGeometry build({required Dive3dSceneData data, required ReconstructedPath path, required Set<FlythroughLane> lanes, List<int?>? ttsSeries});
}

enum FlythroughLane { temperature, ascentRate, tankPressure, ndl, tts }
```

Normalization: horizontal scene coords = `east/north * (sceneSpan / max(horizontalExtentMeters, 1.0))` centered on the bounding box midpoint; `y = -(depth / maxDepthMeters) * ySpan` (same convention as `SceneBounds.yOf`). `sideX/sideZ` = unit vector perpendicular (in the horizontal plane) to the central-difference tangent; where the tangent is degenerate reuse the previous side vector (start with (1,0)). Lanes are ribbons offset `lateralOffset` along the side vector, with height = min-max normalized value scaled to `laneHeightSpan`, base at the path's y. Lane colors come from `MetricPalette.colorsFor` for metrics it knows; NDL and TTS use the continuous ramp on min-max normalized seconds (add a small private helper - do NOT modify MetricPalette). The tube reuses per-sample colors exactly like #565's ribbon (depth metric colors by default). `waterSurface` is a translucent quad at y=0 spanning the path bounding box + 20% margin (color 0xFF0077B6, opacity 0.12). Marker layout: reuse `SceneMarker` kinds but anchor x/z from `frames.positionAt(timestamp)` (write a small `_layoutMarkers` inside the service; the #565 `MarkerLayout` stays time-based and untouched).

- [ ] **Step 1: Write failing tests** - `path_frame_test.dart`: frames from a straight east path have `sideZ ~ +-1, sideX ~ 0`; positionAt interpolates; normalization puts extent at sceneSpan/2 from center. `flythrough_scene_service_test.dart`: build with 2 lanes returns tube + 2 lane meshes with `vertexCount == 2 * decimatedSamples`, ceiling sheet null when all ceilings null, waterSurface non-null, markers anchored within scene bounds. Follow the assertion style of #565's `test/features/dive_3d/domain/geometry/ceiling_builder_test.dart` (read it first for helpers).

- [ ] **Step 2: Run to verify failure** - `flutter test test/features/dive_3d/domain/`. Expected: new files FAIL, existing dive_3d tests PASS (untouched).

- [ ] **Step 3: Implement the three files** per the interfaces above. Pure Dart; `Float32List`/`Uint32List` via `dart:typed_data`; triangle-strip indexing identical to #565's `RibbonBuilder._stripIndices` pattern (2 vertices per sample, 6 indices per segment).

- [ ] **Step 4: Run until green** - `flutter test test/features/dive_3d/domain/`. All PASS including pre-existing.

- [ ] **Step 5: Commit** - `dart format . && git add -A && git commit -m "feat(flythrough): spatial path frames, lane builders, and scene service"`

---

### Task 4: Follow-cam in `SceneViewport` (pure logic + thin wiring)

**Files:**
- Create: `lib/features/dive_3d/presentation/renderer/follow_camera.dart`
- Modify: `lib/features/dive_3d/presentation/widgets/scene_viewport.dart` (#565 file - additive only)
- Test: `test/features/dive_3d/presentation/renderer/follow_camera_test.dart`

**Interfaces:**
- Produces:

```dart
enum CameraPreset { overview, topDown, sideProfile }

/// Pure spring-follow camera state; testable without GL.
class FollowCamera {
  FollowCamera({double stiffness = 4.0, double trailDistance = 2.5, double heightOffset = 1.2});
  /// Advance toward the target derived from the path position/tangent.
  /// Returns (eye, lookAt) in scene units.
  ({({double x, double y, double z}) eye, ({double x, double y, double z}) target})
      update({required PathFrames frames, required double scrub01, required double dtSeconds});
}
```

- `SceneViewport` gains OPTIONAL parameters (defaults preserve #565 behavior exactly):
  `final PathFrames? followFrames;` `final ValueListenable<bool>? followMode;` `final void Function()? onUserOrbit;`
  In the existing `addAnimationEvent` callback: if `followMode?.value == true && followFrames != null`, call `_followCamera.update(...)` and set `camera.position`/`lookAt` from it (bypassing `_applyCamera`). In `onPanUpdate`, when follow is active call `onUserOrbit?.call()` first (the page flips follow off) before applying orbit deltas. Preset support: a public method is NOT possible on the private state, so add `final ValueListenable<CameraPreset?>? presetRequest;` - viewport listens and animates `_yaw/_pitch/_radius` to preset values (overview: 0.55/0.35/14; topDown: yaw unchanged/pitch 1.35/radius 18; sideProfile: yaw 0/pitch 0.05/radius 14), clearing follow.

- [ ] **Step 1: Failing test for FollowCamera** - straight east path, scrub 0.5, several `update` calls with dt=0.016: eye converges behind the current position (eye.x < target.x for eastward travel), y above path, target ahead of position (look-ahead), spring converges monotonically (distance to steady-state strictly decreases across iterations).
- [ ] **Step 2: Verify failure**, then **Step 3: implement `follow_camera.dart`** (exponential spring: `pos += (goal - pos) * (1 - exp(-stiffness*dt))`; goal eye = position - tangent*trailDistance + (0, heightOffset, 0); goal target = position + tangent*lookAhead where lookAhead=1.0).
- [ ] **Step 4: Wire `scene_viewport.dart`** per the interface above. Guard every addition behind null checks so `Dive3dPage`'s existing usage compiles UNCHANGED (no call-site edits in dive_3d_page.dart).
- [ ] **Step 5: Green + regression** - `flutter test test/features/dive_3d/` (existing viewport-adjacent tests must still pass; the GL widget itself stays coverage-excluded).
- [ ] **Step 6: Commit** - `git commit -m "feat(flythrough): follow camera with orbit handoff and presets"`

---

### Task 5: Providers + flythrough page + entry point + l10n

**Files:**
- Create: `lib/features/dive_3d/application/flythrough_providers.dart`
- Create: `lib/features/dive_3d/presentation/pages/dive_flythrough_page.dart`
- Modify: `lib/features/dive_3d/presentation/pages/dive_3d_page.dart` (AppBar action)
- Modify: `lib/l10n/arb/app_en.arb` + 10 locale files
- Test: `test/features/dive_3d/application/flythrough_providers_test.dart`, `test/features/dive_3d/presentation/pages/dive_flythrough_page_test.dart`

**Interfaces:**

```dart
/// null = no position data at any tier -> all flythrough entry points hide.
final flythroughPathProvider = FutureProvider.family<ReconstructedPath?, String>(...);

typedef FlythroughGeometryKey = ({String diveId, String lanesKey});
final flythroughGeometryProvider = FutureProvider.family<FlythroughGeometry?, FlythroughGeometryKey>(...);
```

`flythroughPathProvider` composes: `diveProvider(diveId)` (anchors: `dive.entryLocation` -> per-source `DiveDataSource` doubles via `sourceProfilesProvider` -> `dive.site?.location`), `diveProfileProvider(diveId)` (profile with heading), and surface fixes: `gpsTrackRepository.getCompletedTracks(includePoints: true)` -> `GpsTrackMatcher.trackCovering(tracks, diveWallClockMs)` -> sample fixes at 60 s intervals inside the dive window via `positionAt` (convert with `toWallClockEpochSeconds`; REMEMBER: points are epoch seconds, track times are ms). Then `DivePathReconstructor().reconstruct(...)`. `flythroughGeometryProvider` mirrors `dive3dGeometryProvider`'s pattern including the <2000-samples synchronous rule and `compute()` offload above it, and pulls the TTS series from `profileAnalysisProvider(diveId)` (`decoStatuses[i].ttsSeconds`, resampled onto profile timestamps with `ProfileLookup`).

Page (`DiveFlythroughPage`): clone `Dive3dPage`'s structure - local `ValueNotifier<double> _position`, `AnimationController` player, `TimeScrubBar` reuse, `SceneReadoutPanel` reuse - plus: `ValueNotifier<bool> _followMode` (default true), camera preset buttons, lane FilterChips (`FlythroughLane` set, persisted via `SharedPreferences` key `flythrough_lanes` - device-local UI pref per the settings convention), and the fidelity badge: a small `Chip` whose label is the l10n string for `path.fidelity` with an info tooltip; add `lowConfidence` suffix when set. GL-failure fallback: reuse `Dive3dPreviewPainter` on `FlythroughGeometry.base` exactly like `Dive3dPage` does.

Entry point: in `dive_3d_page.dart`'s AppBar, add an action visible only when `ref.watch(flythroughPathProvider(diveId)).valueOrNull != null`:

```dart
IconButton(
  icon: const Icon(Icons.flight_takeoff),
  tooltip: context.l10n.flythrough_open_tooltip,
  onPressed: () => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => DiveFlythroughPage(diveId: widget.diveId),
    ),
  ),
),
```

l10n keys (add to `app_en.arb`, translate into all 10 locales, run `flutter gen-l10n`):
`flythrough_open_tooltip` "3D flythrough", `flythrough_title` "Flythrough", `flythrough_follow` "Follow", `flythrough_fidelity_headingTrack` "Compass track", `flythrough_fidelity_anchored` "GPS anchored", `flythrough_fidelity_outAndBack` "Estimated path", `flythrough_fidelity_lowConfidence` "low confidence", `flythrough_fidelity_tooltip` "Depth is measured. The horizontal shape is reconstructed from available GPS and compass data.", `flythrough_lane_temperature` "Temperature", `flythrough_lane_ascentRate` "Ascent rate", `flythrough_lane_tankPressure` "Tank pressure", `flythrough_lane_ndl` "NDL", `flythrough_lane_tts` "TTS", `flythrough_preset_overview` "Overview", `flythrough_preset_topDown` "Top-down", `flythrough_preset_side` "Side".

- [ ] **Step 1: Failing provider test** - with a fake dive (entry+exit anchors) and profile, `flythroughPathProvider` yields an anchored path; with no GPS anywhere it yields null. Model the harness on #565's `test/features/dive_3d/application/providers_test.dart` (read it first - it shows how upstream providers are overridden).
- [ ] **Step 2: Implement providers**, run until green.
- [ ] **Step 3: Failing page test** - `DiveFlythroughPage` renders scrub bar + fidelity chip with overridden providers; use BOUNDED pumps (never `pumpAndSettle` - the ThreeJS frame loop never settles) and expect the GL viewport to fail-fallback under flutter_test (the `onInitFailure` path), asserting the software-preview fallback appears. Wrap post-pump async in `tester.runAsync` where drift is touched.
- [ ] **Step 4: Implement page + AppBar action + l10n keys** (en first, then the 10 locales, then `flutter gen-l10n`), run until green.
- [ ] **Step 5: Full dive_3d + dive_log test dirs** - `flutter test test/features/dive_3d/ test/features/dive_log/`. PASS.
- [ ] **Step 6: Commit** - `git commit -m "feat(flythrough): flythrough page, providers, lanes, and fidelity badge"`

---

### Task 6: Verification sweep + PR

- [ ] **Step 1:** `dart format .` then `flutter analyze` (unpiped). Expected: no changes, no issues.
- [ ] **Step 2:** `flutter test test/features/dive_3d/ test/features/dive_log/ test/core/deco/` - all PASS.
- [ ] **Step 3:** `flutter build macos --debug` and check the REAL exit code (`echo $?` - do not pipe the build through tail/grep). Expected 0.
- [ ] **Step 4:** Manual macOS pass: open a dive with GPS (or site pin), open 3D page -> flythrough action -> verify follow-cam plays, drag breaks to orbit, presets animate, lanes toggle, fidelity chip correct; re-enter twice (dispose safety).
- [ ] **Step 5:** Push (`git push --no-verify -u origin worktree-flythrough-pr2`) and open the PR: title "Add GPS dive path reconstruction and 3D flythrough". Body: reconstruction tiers + fidelity, what is reused from #565 vs new, l10n, pending device smoke. No attribution, no session URL. Watch ALL CI jobs including Build Linux and Build Android (flutter_angle fork must keep them green).

---

## Deferred to PR 3 (unchanged from spec)

Preview-card surface for the flythrough in dive detail, remaining lane polish, and any importer-sourced heading. The dive-detail 3D entry already exists via #565's `Dive3dPreviewCard`; PR 3 decides whether the flythrough gets its own card or a mode toggle on the existing one - coordinate with the dive-3d-view owner.
