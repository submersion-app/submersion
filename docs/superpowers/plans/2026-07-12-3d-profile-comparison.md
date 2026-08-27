# 3D Profile Comparison Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render N depth profiles on one shared 3D time/depth scale so a diver can compare several dives, or the several dive-computers that recorded one dive, side-by-side or overlaid, with a synchronized scrub readout and divergence highlighting.

**Architecture:** A neutral `ComparisonProfile` list feeds a generalized `CompareGeometryService` (the extraction of the career terrain's ribbon-stacking, plus an overlay layout and a divergence surface) that emits the existing `Scene3d`. Two Riverpod adapters produce the list — one from a dive's computer-sources, one from a set of dives — and a shared `CompareProfile3dView` renders it. Three entry points launch it.

**Tech Stack:** Flutter 3.44, Riverpod, Drift, go_router, Material 3, `Canvas.drawVertices` renderer (from PR #565).

## Global Constraints

- Depends on PR #565's `Scene3d`, `SceneBounds`, `RibbonBuilder`, `SceneProjector`, `Dive3dInteractiveViewport`, `TimeScrubBar`, `Dive3dScenePainter`. Base this work on `worktree-dive-3d-view` (or main after #565 merges).
- All Dart must pass `dart format .` with no changes and `flutter analyze` with no issues.
- Any displayed unit respects the active diver's settings — use `UnitFormatter(ref.watch(settingsProvider))`.
- New user-facing strings go into `lib/l10n/app_en.arb` AND all 10 non-en locale arbs, then `flutter gen-l10n` (Task 15). Interim tasks may use `context.l10n.<key>` before Task 15 adds the key ONLY if that task's `flutter analyze` step is run after adding the key to `app_en.arb` in the same task; to keep tasks independent, each UI task adds its own keys to `app_en.arb` and Task 15 back-fills the other locales.
- No emojis in code/comments. Immutability. Files 200-400 lines typical.
- Commit per task. Use `git add <explicit paths>` (never `git add -A` — it can record a stale submodule gitlink). Plain commit messages, no co-author/attribution trailers.
- Soft cap constant: `const int kMaxComparisonProfiles = 8;`.

## Canonical signatures (used across tasks)

```dart
// domain/compare/comparison_profile.dart
class ComparisonProfile {
  final String id;            // sourceId or diveId
  final String label;         // "Perdix", "Blue Hole - 7 May"
  final Color color;          // identity color
  final List<double> times;   // seconds from descent, ascending
  final List<double> depths;  // meters, same length as times
  final double maxDepthMeters;
  const ComparisonProfile({required this.id, required this.label,
    required this.color, required this.times, required this.depths,
    required this.maxDepthMeters});
}
enum CompareLayout { sideBySide, overlay }
const int kMaxComparisonProfiles = 8;

// domain/compare/profile_resampler.dart
double ProfileResampler.depthAt(ComparisonProfile p, double timeSeconds);

// domain/compare/compare_geometry_service.dart
Scene3d CompareGeometryService().build(
  List<ComparisonProfile> profiles, {
  CompareLayout layout = CompareLayout.sideBySide,
  int referenceIndex = 0,
  int? focusedIndex,
});

// domain/compare/divergence_builder.dart
class DivergenceMark {
  final String profileId; final double atTimeSeconds; final double gapMeters;
  const DivergenceMark({required this.profileId, required this.atTimeSeconds,
    required this.gapMeters});
}
List<DivergenceMark> DivergenceBuilder.maxGaps(List<ComparisonProfile>, int referenceIndex);
MeshData DivergenceBuilder.gapSurface(ComparisonProfile focused, ComparisonProfile reference, SceneBounds bounds);

// application/compare_providers.dart
final computerComparisonProfilesProvider =
  FutureProvider.family<List<ComparisonProfile>, String>(...);   // arg = diveId
class DiveIdSet { final List<String> ids; const DiveIdSet(this.ids); /* == over ids */ }
final diveComparisonProfilesProvider =
  FutureProvider.family<List<ComparisonProfile>, DiveIdSet>(...);

// presentation
class CompareProfile3dView extends ConsumerStatefulWidget {  // shared body
  final AsyncValue<List<ComparisonProfile>> profiles;
  final String title; final CompareLayout initialLayout; final Widget? leading;
}
class CompareLegend { List<ComparisonProfile> profiles; int referenceIndex;
  int? focusedIndex; void Function(int) onFocus; void Function(int) onSetReference;
  List<DivergenceMark> maxGaps; }
class CompareReadoutPanel { List<ComparisonProfile> profiles; int referenceIndex;
  ValueListenable<double> position; double durationSeconds; }
enum SceneKind { dive, tissue, computers }   // dive_3d_page.dart, computers added
class Dive3dPage { String diveId; SceneKind initialMode = SceneKind.dive; }
class CompareDives3dPage { List<String> diveIds; }
```

---

### Task 1: Comparison primitives (`ComparisonProfile`, `CompareLayout`, `ProfileResampler`)

**Files:**
- Create: `lib/features/dive_3d/domain/compare/comparison_profile.dart`
- Create: `lib/features/dive_3d/domain/compare/profile_resampler.dart`
- Test: `test/features/dive_3d/domain/compare/profile_resampler_test.dart`

**Interfaces:**
- Produces: `ComparisonProfile`, `CompareLayout`, `kMaxComparisonProfiles`, `ProfileResampler.depthAt`.

- [ ] **Step 1: Write the entity file**

```dart
// comparison_profile.dart
import 'dart:ui';

/// One labelled, colored depth-time series to compare on the shared scale.
/// Adapter-neutral: produced identically for a dive's primary source or a
/// single computer-source of one dive.
class ComparisonProfile {
  final String id;
  final String label;
  final Color color;
  final List<double> times; // seconds from descent, ascending
  final List<double> depths; // meters, same length as times
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

/// How the profiles are arranged in the scene.
enum CompareLayout { sideBySide, overlay }

/// Max profiles rendered at once, for legibility. Beyond this the caller
/// keeps the first [kMaxComparisonProfiles] and shows a "showing N of M" note.
const int kMaxComparisonProfiles = 8;
```

- [ ] **Step 2: Write the failing resampler test**

```dart
// profile_resampler_test.dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/compare/profile_resampler.dart';

ComparisonProfile p(List<double> t, List<double> d) => ComparisonProfile(
  id: 'a', label: 'A', color: const Color(0xFF00D4FF),
  times: t, depths: d, maxDepthMeters: d.fold(0.0, (a, b) => b > a ? b : a),
);

void main() {
  final prof = p(const [0, 60, 120], const [0, 30, 10]);

  test('interpolates between samples', () {
    expect(ProfileResampler.depthAt(prof, 30), closeTo(15, 1e-9));
    expect(ProfileResampler.depthAt(prof, 90), closeTo(20, 1e-9));
  });
  test('clamps before first and after last sample', () {
    expect(ProfileResampler.depthAt(prof, -10), 0);
    expect(ProfileResampler.depthAt(prof, 999), 10);
  });
  test('returns exact sample values on the knots', () {
    expect(ProfileResampler.depthAt(prof, 60), 30);
  });
  test('empty profile yields 0', () {
    expect(ProfileResampler.depthAt(p(const [], const []), 5), 0);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/compare/profile_resampler_test.dart`
Expected: FAIL (`profile_resampler.dart` / `ProfileResampler` not found).

- [ ] **Step 4: Write the resampler**

```dart
// profile_resampler.dart
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';

/// Linear interpolation of a profile's depth at an arbitrary time. Shared by
/// the scrub readout and DivergenceBuilder. Mirrors the interpolation idiom
/// in ProfileLookupOverPressure (scene_geometry_service.dart).
class ProfileResampler {
  static double depthAt(ComparisonProfile p, double timeSeconds) {
    final t = p.times;
    if (t.isEmpty) return 0;
    if (timeSeconds <= t.first) return p.depths.first;
    if (timeSeconds >= t.last) return p.depths.last;
    var lo = 0, hi = t.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (t[mid] <= timeSeconds) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = t[hi] - t[lo];
    if (span <= 0) return p.depths[lo];
    final f = (timeSeconds - t[lo]) / span;
    return p.depths[lo] + (p.depths[hi] - p.depths[lo]) * f;
  }
}
```

- [ ] **Step 5: Run tests, format, commit**

Run: `flutter test test/features/dive_3d/domain/compare/profile_resampler_test.dart` (expect PASS), then `dart format lib/features/dive_3d/domain/compare test/features/dive_3d/domain/compare`.

```bash
git add lib/features/dive_3d/domain/compare/comparison_profile.dart \
        lib/features/dive_3d/domain/compare/profile_resampler.dart \
        test/features/dive_3d/domain/compare/profile_resampler_test.dart
git commit -m "feat(dive_3d): comparison profile primitives + resampler"
```

---

### Task 2: Add opacity to `RibbonBuilder.build`

The overlay layout needs translucent ribbons; `RibbonBuilder.build` currently hardcodes opacity 1.0. Add an optional, backward-compatible param.

**Files:**
- Modify: `lib/features/dive_3d/domain/geometry/ribbon_builder.dart`
- Test: `test/features/dive_3d/domain/geometry/ribbon_builder_test.dart` (existing — add one case)

**Interfaces:**
- Produces: `RibbonBuilder.build(..., double opacity = 1.0)`.

- [ ] **Step 1: Add the failing test case** (append inside the existing `main()`):

```dart
  test('build applies the opacity argument to the mesh', () {
    final mesh = RibbonBuilder.build(
      times: const [0, 60], depths: const [0, 10],
      sampleColors: Float32List.fromList(const [1, 0, 0, 1, 0, 0]),
      bounds: const SceneBounds(durationSeconds: 60, maxDepthMeters: 10),
      opacity: 0.55,
    );
    expect(mesh.opacity, closeTo(0.55, 1e-9));
  });
```

(Ensure `import 'dart:typed_data';` is present in the test.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_3d/domain/geometry/ribbon_builder_test.dart`
Expected: FAIL (`opacity` is not a named parameter).

- [ ] **Step 3: Add the param** — in `ribbon_builder.dart`, change `build`'s signature and the returned `MeshData`:

```dart
  static MeshData build({
    required List<double> times,
    required List<double> depths,
    required Float32List sampleColors,
    required SceneBounds bounds,
    double zCenter = 0,
    double opacity = 1.0,
  }) {
    // ... unchanged body ...
    return MeshData(
      positions: positions,
      indices: _stripIndices(n),
      colors: colors,
      opacity: opacity,
    );
  }
```

- [ ] **Step 4: Run tests** — `flutter test test/features/dive_3d/domain/geometry/ribbon_builder_test.dart` (expect PASS).

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_3d/domain/geometry/ribbon_builder.dart test/features/dive_3d/domain/geometry/ribbon_builder_test.dart
git add lib/features/dive_3d/domain/geometry/ribbon_builder.dart test/features/dive_3d/domain/geometry/ribbon_builder_test.dart
git commit -m "feat(dive_3d): optional opacity on RibbonBuilder.build"
```

---

### Task 3: `CompareGeometryService` (side-by-side + overlay)

**Files:**
- Create: `lib/features/dive_3d/domain/compare/compare_geometry_service.dart`
- Test: `test/features/dive_3d/domain/compare/compare_geometry_service_test.dart`

**Interfaces:**
- Consumes: `ComparisonProfile`, `CompareLayout`, `RibbonBuilder.build(..., zCenter, opacity)`, `SceneBounds`, `Scene3d`, `SceneLayer`, `ScrubPath`.
- Produces: `CompareGeometryService().build(profiles, {layout, referenceIndex, focusedIndex}) -> Scene3d`.

Behavior locked so career (Task 4) stays byte-identical: `_zGap = 0.6`; `halfZ = count<=1 ? 0 : (count-1)*0.5*_zGap`; side-by-side `zCenter = count<=1 ? 0 : -halfZ + i*_zGap`; bounds `sceneMinZ/MaxZ = -/+ (halfZ + SceneBounds.zHalfWidth)`; shared `durationSeconds = max(last time)`, `maxDepthMeters = max(maxDepthMeters)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/compare/compare_geometry_service.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

ComparisonProfile prof(String id, List<double> t, List<double> d) =>
    ComparisonProfile(id: id, label: id, color: const Color(0xFF00D4FF),
        times: t, depths: d, maxDepthMeters: d.reduce((a, b) => a > b ? a : b));

void main() {
  final a = prof('a', const [0, 60, 120], const [0, 30, 0]);
  final b = prof('b', const [0, 60, 180], const [0, 20, 0]);
  const svc = CompareGeometryService();

  test('empty input yields an empty scene', () {
    expect(svc.build(const []).layers, isEmpty);
  });

  test('a single profile renders one lane at z=0', () {
    // Career renders a single dive; the compare UI enforces >= 2 upstream.
    final scene = svc.build([a]);
    expect(scene.layers, hasLength(1));
    expect(scene.layers[0].mesh.positions[2],
        closeTo(-SceneBounds.zHalfWidth, 1e-6)); // zCenter 0
  });

  test('side-by-side lays each ribbon in its own Z lane', () {
    final scene = svc.build([a, b], layout: CompareLayout.sideBySide);
    expect(scene.layers.length, 2);
    // First ribbon's first vertex z = zCenter - zHalfWidth, zCenter = -halfZ.
    const halfZ = 0.5 * 0.6; // (2-1)*0.5*0.6
    expect(scene.layers[0].mesh.positions[2],
        closeTo(-halfZ - SceneBounds.zHalfWidth, 1e-6));
    expect(scene.layers[1].mesh.positions[2],
        closeTo(halfZ - SceneBounds.zHalfWidth, 1e-6));
  });

  test('shared bounds span the deepest, longest profile', () {
    final scene = svc.build([a, b]);
    expect(scene.bounds.durationSeconds, 180);
    expect(scene.bounds.maxDepthMeters, 30);
  });

  test('overlay places every ribbon at z=0 and reduces opacity', () {
    final scene = svc.build([a, b], layout: CompareLayout.overlay);
    expect(scene.layers[0].mesh.positions[2],
        closeTo(-SceneBounds.zHalfWidth, 1e-6)); // zCenter 0
    expect(scene.layers[1].mesh.positions[2],
        closeTo(-SceneBounds.zHalfWidth, 1e-6));
    expect(scene.layers[0].mesh.opacity, lessThan(1.0));
  });

  test('scrub path rides the reference profile', () {
    final scene = svc.build([a, b], referenceIndex: 1);
    expect(scene.scrubPath, isNotNull);
    // reference b is 180 s long -> last normalized time is 1.0
    expect(scene.scrubPath!.normalizedTimes.last, closeTo(1.0, 1e-9));
  });
}
```

- [ ] **Step 2: Run to verify failure** — `flutter test test/features/dive_3d/domain/compare/compare_geometry_service_test.dart` → FAIL (service missing).

- [ ] **Step 3: Implement the service**

```dart
// compare_geometry_service.dart
import 'dart:typed_data';

import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/compare/divergence_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/ribbon_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';

/// Generalized multi-ribbon builder: N depth ribbons on one shared
/// time/depth scale, side-by-side (each in its own Z lane) or overlaid
/// (all at z=0, translucent). The extraction of the career terrain's
/// stacking logic, plus overlay + an optional divergence surface.
class CompareGeometryService {
  static const double _zGap = 0.6;
  static const double _overlayOpacity = 0.55;

  const CompareGeometryService();

  Scene3d build(
    List<ComparisonProfile> profiles, {
    CompareLayout layout = CompareLayout.sideBySide,
    int referenceIndex = 0,
    int? focusedIndex,
  }) {
    if (profiles.isEmpty) {
      return const Scene3d(
        layers: [],
        markers: [],
        bounds: SceneBounds(durationSeconds: 1, maxDepthMeters: 1),
      );
    }
    // count == 1 renders one lane (career's single-dive case); the compare
    // providers/UI enforce the >= 2 minimum for the comparison feature.

    var maxDuration = 1.0;
    var maxDepth = 1.0;
    for (final p in profiles) {
      if (p.times.isNotEmpty && p.times.last > maxDuration) {
        maxDuration = p.times.last;
      }
      if (p.maxDepthMeters > maxDepth) maxDepth = p.maxDepthMeters;
    }

    final count = profiles.length;
    final halfZ = count <= 1 ? 0.0 : (count - 1) * 0.5 * _zGap;
    final side = layout == CompareLayout.sideBySide;
    final bounds = SceneBounds(
      durationSeconds: maxDuration,
      maxDepthMeters: maxDepth,
      sceneMinZ: side ? -halfZ - SceneBounds.zHalfWidth : -SceneBounds.zHalfWidth,
      sceneMaxZ: side ? halfZ + SceneBounds.zHalfWidth : SceneBounds.zHalfWidth,
    );

    double zCenterOf(int i) =>
        side ? (count <= 1 ? 0.0 : -halfZ + i * _zGap) : 0.0;

    final layers = <SceneLayer>[
      for (var i = 0; i < count; i++)
        SceneLayer(
          RibbonBuilder.build(
            times: profiles[i].times,
            depths: profiles[i].depths,
            sampleColors: _uniform(profiles[i].color, profiles[i].times.length),
            bounds: bounds,
            zCenter: zCenterOf(i),
            opacity: side ? 1.0 : _overlayOpacity,
          ),
        ),
      if (!side && focusedIndex != null && focusedIndex != referenceIndex)
        SceneLayer(
          DivergenceBuilder.gapSurface(
            profiles[focusedIndex],
            profiles[referenceIndex],
            bounds,
          ),
        ),
    ];

    final ref = profiles[referenceIndex];
    final refZ = zCenterOf(referenceIndex);
    return Scene3d(
      layers: layers,
      markers: const [],
      bounds: bounds,
      scrubPath: ScrubPath(
        normalizedTimes: [for (final t in ref.times) t / maxDuration],
        xs: [for (final t in ref.times) bounds.xOf(t)],
        ys: [for (final d in ref.depths) bounds.yOf(d)],
        zs: [for (final _ in ref.times) refZ],
      ),
    );
  }

  Float32List _uniform(color, int n) {
    final out = Float32List(n * 3);
    for (var i = 0; i < n; i++) {
      out[i * 3] = color.r;
      out[i * 3 + 1] = color.g;
      out[i * 3 + 2] = color.b;
    }
    return out;
  }
}
```

Note: this imports `divergence_builder.dart` (Task 4). Implement Task 4 before running this task's tests, OR temporarily stub `gapSurface`. Recommended order: do Task 4's file first, then this. (The two are co-dependent; treat Tasks 3+4 as one review gate if executing strictly TDD.)

- [ ] **Step 4: Run tests** — `flutter test test/features/dive_3d/domain/compare/compare_geometry_service_test.dart` (expect PASS after Task 4 exists).

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_3d/domain/compare test/features/dive_3d/domain/compare
git add lib/features/dive_3d/domain/compare/compare_geometry_service.dart \
        test/features/dive_3d/domain/compare/compare_geometry_service_test.dart
git commit -m "feat(dive_3d): CompareGeometryService (side-by-side + overlay)"
```

---

### Task 4: `DivergenceBuilder`

**Files:**
- Create: `lib/features/dive_3d/domain/compare/divergence_builder.dart`
- Test: `test/features/dive_3d/domain/compare/divergence_builder_test.dart`

**Interfaces:**
- Consumes: `ComparisonProfile`, `ProfileResampler.depthAt`, `SceneBounds`, `MeshData`.
- Produces: `DivergenceMark`, `DivergenceBuilder.maxGaps(...)`, `DivergenceBuilder.gapSurface(...)`.

Approach: resample both profiles onto the reference's time knots (within their overlapping range) and find the largest `|depth - refDepth|`. `gapSurface` is a translucent triangle strip between the two curves over the reference's knots.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/compare/divergence_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

ComparisonProfile prof(String id, List<double> d) => ComparisonProfile(
  id: id, label: id, color: const Color(0xFF00D4FF),
  times: const [0, 60, 120], depths: d,
  maxDepthMeters: d.reduce((a, b) => a > b ? a : b));

void main() {
  final ref = prof('ref', const [0, 30, 0]);
  final other = prof('b', const [0, 34, 0]); // +4 m at t=60

  test('maxGaps finds the largest signed gap vs reference', () {
    final marks = DivergenceBuilder.maxGaps([ref, other], 0);
    expect(marks, hasLength(1)); // one per non-reference profile
    expect(marks.single.profileId, 'b');
    expect(marks.single.atTimeSeconds, 60);
    expect(marks.single.gapMeters, closeTo(4, 1e-9));
  });

  test('reference change flips the sign', () {
    final marks = DivergenceBuilder.maxGaps([ref, other], 1);
    expect(marks.single.gapMeters, closeTo(-4, 1e-9));
  });

  test('gapSurface produces a non-empty translucent mesh', () {
    final mesh = DivergenceBuilder.gapSurface(other, ref,
        const SceneBounds(durationSeconds: 120, maxDepthMeters: 34));
    expect(mesh.vertexCount, greaterThan(0));
    expect(mesh.opacity, lessThan(1.0));
  });
}
```

- [ ] **Step 2: Run to verify failure** — FAIL (builder missing).

- [ ] **Step 3: Implement**

```dart
// divergence_builder.dart
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_3d/domain/compare/profile_resampler.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

/// Where and how far a profile diverges from the reference.
class DivergenceMark {
  final String profileId;
  final double atTimeSeconds;
  final double gapMeters; // signed: profile depth - reference depth
  const DivergenceMark({
    required this.profileId,
    required this.atTimeSeconds,
    required this.gapMeters,
  });
}

/// Reference-based divergence: the largest depth gap of each other profile
/// vs the reference, and a translucent surface between one focused profile
/// and the reference (overlay layout).
class DivergenceBuilder {
  static const Color _gapColor = Color(0xFFFFC857);
  static const double _gapOpacity = 0.22;

  static List<DivergenceMark> maxGaps(
    List<ComparisonProfile> profiles,
    int referenceIndex,
  ) {
    if (profiles.length < 2) return const [];
    final ref = profiles[referenceIndex];
    final marks = <DivergenceMark>[];
    for (var i = 0; i < profiles.length; i++) {
      if (i == referenceIndex) continue;
      final p = profiles[i];
      var bestAbs = -1.0;
      var bestGap = 0.0;
      var bestT = 0.0;
      for (final t in ref.times) {
        if (t < p.times.first || t > p.times.last) continue;
        final gap = ProfileResampler.depthAt(p, t) - ProfileResampler.depthAt(ref, t);
        if (gap.abs() > bestAbs) {
          bestAbs = gap.abs();
          bestGap = gap;
          bestT = t;
        }
      }
      marks.add(DivergenceMark(
        profileId: p.id,
        atTimeSeconds: bestT,
        gapMeters: bestGap,
      ));
    }
    return marks;
  }

  static MeshData gapSurface(
    ComparisonProfile focused,
    ComparisonProfile reference,
    SceneBounds bounds,
  ) {
    // Triangle strip between the two curves over the reference's knots that
    // fall inside the focused profile's time range.
    final knots = [
      for (final t in reference.times)
        if (t >= focused.times.first && t <= focused.times.last) t,
    ];
    if (knots.length < 2) {
      return MeshData(
        positions: Float32List(0),
        indices: Uint32List(0),
        colors: Float32List(0),
        opacity: _gapOpacity,
      );
    }
    final n = knots.length;
    final positions = Float32List(n * 6);
    final colors = Float32List(n * 6);
    for (var i = 0; i < n; i++) {
      final t = knots[i];
      final x = bounds.xOf(t);
      final yF = bounds.yOf(ProfileResampler.depthAt(focused, t));
      final yR = bounds.yOf(ProfileResampler.depthAt(reference, t));
      final p = i * 6;
      positions[p] = x;
      positions[p + 1] = yF;
      positions[p + 2] = 0;
      positions[p + 3] = x;
      positions[p + 4] = yR;
      positions[p + 5] = 0;
      for (var k = 0; k < 2; k++) {
        colors[p + k * 3] = _gapColor.r;
        colors[p + k * 3 + 1] = _gapColor.g;
        colors[p + k * 3 + 2] = _gapColor.b;
      }
    }
    final indices = Uint32List((n - 1) * 6);
    var j = 0;
    for (var i = 0; i < n - 1; i++) {
      final a = i * 2, b = i * 2 + 1, c = i * 2 + 2, d = i * 2 + 3;
      indices[j++] = a;
      indices[j++] = b;
      indices[j++] = c;
      indices[j++] = b;
      indices[j++] = d;
      indices[j++] = c;
    }
    return MeshData(
      positions: positions,
      indices: indices,
      colors: colors,
      opacity: _gapOpacity,
    );
  }
}
```

- [ ] **Step 4: Run tests** — both `divergence_builder_test.dart` and `compare_geometry_service_test.dart` PASS.

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_3d/domain/compare test/features/dive_3d/domain/compare
git add lib/features/dive_3d/domain/compare/divergence_builder.dart \
        test/features/dive_3d/domain/compare/divergence_builder_test.dart
git commit -m "feat(dive_3d): reference-based DivergenceBuilder"
```

---

### Task 5: Refactor `CareerGeometryService` to delegate

Make career a caller of `CompareGeometryService` (approach A). Its existing tests must stay green unchanged.

**Files:**
- Modify: `lib/features/dive_3d/domain/career/career_geometry_service.dart`
- Test: `test/features/dive_3d/domain/career/career_geometry_service_test.dart` (existing — must pass unchanged)

- [ ] **Step 1: Run existing career tests to capture the green baseline**

Run: `flutter test test/features/dive_3d/domain/career/career_geometry_service_test.dart`
Expected: PASS (baseline before refactor).

- [ ] **Step 2: Refactor `build` to delegate** — keep `CareerColorMode` and color math; map each `CareerDiveInput` to a `ComparisonProfile`, then call the shared builder:

```dart
  Scene3d build(
    CareerSceneData data, {
    CareerColorMode colorMode = CareerColorMode.recency,
  }) {
    final dives = data.dives;
    if (dives.isEmpty) {
      return const Scene3d(
        layers: [],
        markers: [],
        bounds: SceneBounds(durationSeconds: 1, maxDepthMeters: 1),
      );
    }
    var maxDepth = 1.0;
    for (final d in dives) {
      if (d.maxDepthMeters > maxDepth) maxDepth = d.maxDepthMeters;
    }
    final count = dives.length;
    final profiles = [
      for (final dive in dives)
        ComparisonProfile(
          id: '${dive.index}',
          label: '',
          color: _colorFor(dive, count, maxDepth, colorMode),
          times: dive.times,
          depths: dive.depths,
          maxDepthMeters: dive.maxDepthMeters,
        ),
    ];
    return const CompareGeometryService()
        .build(profiles, layout: CompareLayout.sideBySide);
  }
```

Remove the now-unused `_uniformColor` helper. Keep `_colorFor`. Add imports for `ComparisonProfile`, `CompareLayout`, `CompareGeometryService`.

Note: `CompareGeometryService` already renders a single profile as one lane at z=0 (Task 3's guard is `profiles.isEmpty`, and `count == 1` gives `halfZ = 0`, `zCenter = 0`). So career's single-dive scene is byte-identical to before, and its existing "single dive centers at z=0" test (`positions[2] == -SceneBounds.zHalfWidth`) stays green. The `>= 2` minimum for the comparison feature is enforced upstream in the adapters/UI (Tasks 6-7, 11).

- [ ] **Step 3: Run career tests** — `flutter test test/features/dive_3d/domain/career/career_geometry_service_test.dart` (expect PASS unchanged).

- [ ] **Step 4: Run the compare geometry test** — `flutter test test/features/dive_3d/domain/compare/compare_geometry_service_test.dart` (expect PASS; the single-profile assertion now expects one lane at z=0).

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_3d/domain/career test/features/dive_3d/domain/compare
git add lib/features/dive_3d/domain/career/career_geometry_service.dart \
        lib/features/dive_3d/domain/compare/compare_geometry_service.dart \
        test/features/dive_3d/domain/compare/compare_geometry_service_test.dart
git commit -m "refactor(dive_3d): career terrain delegates to CompareGeometryService"
```

---

### Task 6: Computers adapter provider

**Files:**
- Create: `lib/features/dive_3d/application/compare_providers.dart`
- Test: `test/features/dive_3d/application/compare_providers_test.dart`

**Interfaces:**
- Consumes: `diveDataSourcesProvider(diveId) -> List<DiveDataSource>` (`dive_providers.dart`), `sourceProfilesProvider(diveId) -> Map<String, SourceProfile>` (`dive_providers.dart`), `resolveSourceName`, `SourceNameLabels`, `sourceColorAt` (`source_bar.dart`), `ComparisonProfile`, `kMaxComparisonProfiles`.
- Produces: `computerComparisonProfilesProvider` (`FutureProvider.family<List<ComparisonProfile>, String>`).

Note: `resolveSourceName` needs `SourceNameLabels` (localized). Providers cannot read `context.l10n`. Pass a non-localized fallback in the provider using the source's own `computerModel`/`computerSerial`; only fall back to a generic label when those are null. Use a module-level `SourceNameLabels` built from constants (`unknownComputer: 'Computer'`, `manualEntry: 'Manual', importedFile: 'File', editedSuffix: ' (edited)'`). The UI already localizes source names elsewhere; comparison labels favor the model/serial, which are language-neutral, so this is acceptable. (Documented deviation.)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/dive_3d/application/compare_providers.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'; // DiveProfilePoint
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

// DiveProfilePoint requires only timestamp (int) + depth (double); rest optional.
DiveProfilePoint pt(int t, double d) => DiveProfilePoint(timestamp: t, depth: d);

void main() {
  test('builds one profile per source, primary as reference index 0', () async {
    final container = ProviderContainer(overrides: [
      diveDataSourcesProvider('d1').overrideWith((ref) async => [
            // construct two DiveDataSource rows: primary "Perdix", secondary "Teric"
          ]),
      sourceProfilesProvider('d1').overrideWith((ref) async => {
            'srcPrimary': SourceProfile(sourceId: 'srcPrimary', computerId: null,
                isEdited: false, points: [pt(0, 0), pt(60, 30), pt(120, 0)]),
            'srcSecondary': SourceProfile(sourceId: 'srcSecondary', computerId: null,
                isEdited: false, points: [pt(0, 0), pt(60, 31), pt(120, 0)]),
          }),
    ]);
    addTearDown(container.dispose);
    final profiles =
        await container.read(computerComparisonProfilesProvider('d1').future);
    expect(profiles, hasLength(2));
    expect(profiles.first.id, 'srcPrimary'); // primary first = reference
    expect(profiles.first.times, [0, 60, 120]);
  });
}
```

(For the `DiveDataSource` fixtures, construct rows with at least `id`, `diveId`, `isPrimary`, and `computerModel` — read `dive_data_source.dart` for its exact constructor. `resolveSourceName` favors `computerModel`, so set it to get readable labels like "Perdix".)

- [ ] **Step 2: Run to verify failure** — FAIL (provider missing).

- [ ] **Step 3: Implement the provider**

```dart
// compare_providers.dart (computers section)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/dive_3d/domain/compare/comparison_profile.dart';
import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/source_bar.dart';

const _neutralLabels = SourceNameLabels(
  unknownComputer: 'Computer',
  manualEntry: 'Manual entry',
  importedFile: 'Imported file',
  editedSuffix: ' (edited)',
);

final computerComparisonProfilesProvider =
    FutureProvider.family<List<ComparisonProfile>, String>((ref, diveId) async {
  final sources = await ref.watch(diveDataSourcesProvider(diveId).future);
  final profilesBySource = await ref.watch(sourceProfilesProvider(diveId).future);

  // Primary first (reference index 0), then the rest in source order.
  final ordered = [...sources]
    ..sort((a, b) => (b.isPrimary ? 1 : 0) - (a.isPrimary ? 1 : 0));

  final out = <ComparisonProfile>[];
  for (final source in ordered) {
    final sp = profilesBySource[source.id];
    if (sp == null || sp.points.length < 2) continue; // skip metadata-only
    final times = [for (final p in sp.points) p.timestamp.toDouble()];
    final depths = [for (final p in sp.points) p.depth];
    out.add(ComparisonProfile(
      id: source.id,
      label: resolveSourceName(source, _neutralLabels, edited: sp.isEdited),
      color: sourceColorAt(out.length),
      times: times,
      depths: depths,
      maxDepthMeters: depths.fold(0.0, (a, b) => b > a ? b : a),
    ));
  }
  return out.length > kMaxComparisonProfiles
      ? out.sublist(0, kMaxComparisonProfiles)
      : out;
});
```

- [ ] **Step 4: Run tests** — PASS.

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_3d/application/compare_providers.dart test/features/dive_3d/application/compare_providers_test.dart
git add lib/features/dive_3d/application/compare_providers.dart test/features/dive_3d/application/compare_providers_test.dart
git commit -m "feat(dive_3d): computer-source comparison adapter"
```

---

### Task 7: Dives adapter provider (`DiveIdSet` + `diveComparisonProfilesProvider`)

**Files:**
- Modify: `lib/features/dive_3d/application/compare_providers.dart`
- Modify: `test/features/dive_3d/application/compare_providers_test.dart`

**Interfaces:**
- Consumes: `sourceProfilesProvider(diveId)` (primary entry), `diveProvider(diveId)` (`FutureProvider.family<Dive?, String>`, dive_providers.dart:163) for the label via `dive?.site?.name`, `sourceColorAt`.
- Produces: `class DiveIdSet` (equatable), `diveComparisonProfilesProvider` (`FutureProvider.family<List<ComparisonProfile>, DiveIdSet>`).

- [ ] **Step 1: Write the failing test** — override `sourceProfilesProvider` for two diveIds and a dive-label provider; assert two profiles, reference index 0 = first id, capped at `kMaxComparisonProfiles`, dives with `< 2` points skipped. Also test `DiveIdSet` equality: `DiveIdSet(['a','b']) == DiveIdSet(['a','b'])`.

- [ ] **Step 2: Run to verify failure** — FAIL.

- [ ] **Step 3: Implement**

```dart
// compare_providers.dart (dives section, appended)
class DiveIdSet {
  final List<String> ids;
  const DiveIdSet(this.ids);
  @override
  bool operator ==(Object other) =>
      other is DiveIdSet &&
      other.ids.length == ids.length &&
      _eq(other.ids, ids);
  @override
  int get hashCode => Object.hashAll(ids);
  static bool _eq(List<String> a, List<String> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

final diveComparisonProfilesProvider =
    FutureProvider.family<List<ComparisonProfile>, DiveIdSet>((ref, key) async {
  final out = <ComparisonProfile>[];
  for (final diveId in key.ids) {
    if (out.length >= kMaxComparisonProfiles) break;
    final profilesBySource = await ref.watch(sourceProfilesProvider(diveId).future);
    final sp = profilesBySource.values.firstOrNull; // primary is first
    if (sp == null || sp.points.length < 2) continue;
    final dive = await ref.watch(diveProvider(diveId).future); // Dive?
    final times = [for (final p in sp.points) p.timestamp.toDouble()];
    final depths = [for (final p in sp.points) p.depth];
    out.add(ComparisonProfile(
      id: diveId,
      label: dive?.site?.name ?? 'Dive',
      color: sourceColorAt(out.length),
      times: times,
      depths: depths,
      maxDepthMeters: depths.fold(0.0, (a, b) => b > a ? b : a),
    ));
  }
  return out;
});
```

(`diveProvider` and `sourceProfilesProvider` both live in `dive_providers.dart`; import it. `Dive.site?.name` is the site label, matching how `DiveSummary.siteName` is built at dive_summary.dart:79.)

- [ ] **Step 4: Run tests** — PASS.

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_3d/application/compare_providers.dart test/features/dive_3d/application/compare_providers_test.dart
git add lib/features/dive_3d/application/compare_providers.dart test/features/dive_3d/application/compare_providers_test.dart
git commit -m "feat(dive_3d): multi-dive comparison adapter"
```

---

### Task 8: `CompareLegend` widget

**Files:**
- Create: `lib/features/dive_3d/presentation/widgets/compare_legend.dart`
- Test: `test/features/dive_3d/presentation/widgets/compare_legend_test.dart`

**Interfaces:**
- Consumes: `ComparisonProfile`, `DivergenceMark`.
- Produces: `CompareLegend({required List<ComparisonProfile> profiles, required int referenceIndex, int? focusedIndex, required void Function(int) onFocus, required void Function(int) onSetReference, List<DivergenceMark> maxGaps = const []})`.

- [ ] **Step 1: Write the failing widget test** — pump `CompareLegend` with 2 profiles; expect 2 labels; tapping a row calls `onFocus(index)`; the reference row shows a star; a row with a matching `DivergenceMark` shows its formatted max delta text.

- [ ] **Step 2: Run to verify failure** — FAIL.

- [ ] **Step 3: Implement** — a `Column` of rows: color swatch + label + (star if `i == referenceIndex`) + max-delta text if a mark matches `profile.id`. `InkWell` per row → `onFocus(i)`; a star `IconButton` → `onSetReference(i)`. Focused row gets a subtle highlight. Keep it a plain `StatelessWidget`.

- [ ] **Step 4: Run tests** — PASS.

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_3d/presentation/widgets/compare_legend.dart test/features/dive_3d/presentation/widgets/compare_legend_test.dart
git add lib/features/dive_3d/presentation/widgets/compare_legend.dart test/features/dive_3d/presentation/widgets/compare_legend_test.dart
git commit -m "feat(dive_3d): compare legend (focus + reference + max delta)"
```

---

### Task 9: `CompareReadoutPanel` widget

**Files:**
- Create: `lib/features/dive_3d/presentation/widgets/compare_readout_panel.dart`
- Test: `test/features/dive_3d/presentation/widgets/compare_readout_panel_test.dart`

**Interfaces:**
- Consumes: `ComparisonProfile`, `ProfileResampler.depthAt`, `UnitFormatter`, `settingsProvider`.
- Produces: `CompareReadoutPanel({required List<ComparisonProfile> profiles, required int referenceIndex, required ValueListenable<double> position, required double durationSeconds})`.

Mirror `SceneReadoutPanel`: a `ConsumerWidget` wrapping a `ValueListenableBuilder<double>` on `position` (so playback does not rebuild the tree above). At `t = value * durationSeconds`, show each profile's depth via `ProfileResampler.depthAt` and its delta vs the reference profile.

- [ ] **Step 1: Write the failing widget test** — pump with 2 profiles + a `ValueNotifier(0.5)`; expect the reference depth text and a signed delta (e.g. `+0.3`) for the other profile. Use a `ProviderScope` with `settingsProvider` overridden to a metric settings fixture (reuse existing test helpers, e.g. `getBaseOverrides()`).

- [ ] **Step 2: Run to verify failure** — FAIL.

- [ ] **Step 3: Implement** — for each profile compute `depth = ProfileResampler.depthAt(p, t)`; `delta = depth - refDepth`; render one line per profile: `units.formatDepth(depth)` + (non-reference) ` (${delta >= 0 ? '+' : ''}${units.formatDepth(delta)})`. Colored swatch per profile. Wrap in the same translucent `DecoratedBox` styling as `SceneReadoutPanel`.

- [ ] **Step 4: Run tests** — PASS.

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_3d/presentation/widgets/compare_readout_panel.dart test/features/dive_3d/presentation/widgets/compare_readout_panel_test.dart
git add lib/features/dive_3d/presentation/widgets/compare_readout_panel.dart test/features/dive_3d/presentation/widgets/compare_readout_panel_test.dart
git commit -m "feat(dive_3d): compare readout (per-profile depth + delta)"
```

---

### Task 10: Time-plane scrub cursor in the viewport

Add an optional cursor style to `Dive3dInteractiveViewport` so compare mode can sweep a vertical time-plane. Default keeps the existing dot (existing tests unaffected).

**Files:**
- Modify: `lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart`
- Test: `test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart` (add a case)

**Interfaces:**
- Produces: `enum ScrubCursorStyle { dot, timePlane }`; `Dive3dInteractiveViewport(..., ScrubCursorStyle scrubCursor = ScrubCursorStyle.dot)`.

- [ ] **Step 1: Add a failing test** — pump the viewport with `scrubCursor: ScrubCursorStyle.timePlane` and a compare scene; assert it builds and the foreground painter is present (no throw). Reuse the existing `buildScene()`/`pumpViewport` helpers; add an optional `scrubCursor` param to `pumpViewport`.

- [ ] **Step 2: Run to verify failure** — FAIL (`scrubCursor` not a param).

- [ ] **Step 3: Implement** — add the enum + field; thread it into `_ScrubCursorPainter`. In `paint`, when `style == timePlane`, additionally draw a translucent vertical quad at the cursor's world X across the scene's Y and Z extent:

```dart
if (style == ScrubCursorStyle.timePlane) {
  final x = scenePoint.x;
  final b = scene.bounds;
  final corners = [
    projector.project(x, b.sceneMaxY, b.sceneMinZ),
    projector.project(x, b.sceneMaxY, b.sceneMaxZ),
    projector.project(x, b.sceneMinY, b.sceneMaxZ),
    projector.project(x, b.sceneMinY, b.sceneMinZ),
  ];
  final path = Path()..addPolygon(corners, true);
  canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.10));
  canvas.drawPath(path, Paint()
    ..color = Colors.white.withValues(alpha: 0.5)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0);
}
```

Keep the existing dot draw for `dot`. Add `style` to `shouldRepaint`.

- [ ] **Step 4: Run tests** — `flutter test test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart` (all PASS, including the 4 existing).

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart
git add lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart
git commit -m "feat(dive_3d): optional time-plane scrub cursor"
```

---

### Task 11: `CompareProfile3dView` (shared body)

**Files:**
- Create: `lib/features/dive_3d/presentation/widgets/compare_profile_3d_view.dart`
- Create: `lib/l10n/app_en.arb` entries (see below; other locales in Task 15)
- Test: `test/features/dive_3d/presentation/widgets/compare_profile_3d_view_test.dart`

**Interfaces:**
- Consumes: `CompareGeometryService`, `DivergenceBuilder.maxGaps`, `Dive3dInteractiveViewport` (timePlane), `TimeScrubBar`, `CompareLegend`, `CompareReadoutPanel`, `ComparisonProfile`, `CompareLayout`.
- Produces: `CompareProfile3dView({required AsyncValue<List<ComparisonProfile>> profiles, required String title, CompareLayout initialLayout = CompareLayout.sideBySide, Widget? leading})`.

Self-contained: owns a `ValueNotifier<double> _position`, an `AnimationController _player` (like `Dive3dPage`), and state `_layout`, `_referenceIndex`, `_focusedIndex`. Rebuilds the scene via `CompareGeometryService().build(profiles, layout: _layout, referenceIndex: _referenceIndex, focusedIndex: _focusedIndex)`.

l10n keys to add to `app_en.arb` this task:
```json
"dive3d_compare_layout_sideBySide": "Side by side",
"dive3d_compare_layout_overlay": "Overlay",
"dive3d_compare_empty": "Need at least 2 profiles with depth data to compare",
"dive3d_compare_showing": "Showing {shown} of {total}",
"@dive3d_compare_showing": { "placeholders": { "shown": {}, "total": {} } }
```

- [ ] **Step 1: Write the failing widget test** — pump with `AsyncValue.data([profA, profB])`; expect a `Dive3dInteractiveViewport`, a `CompareLegend`, a `CompareReadoutPanel`, and a layout toggle; tapping "Overlay" switches `_layout` (assert the viewport's scene changed — e.g. a second pump shows the toggle selected). Pump with `AsyncValue.data([single])` → expect the empty-state text `dive3d_compare_empty`. Use bounded pumps (no `pumpAndSettle`; the player animates). Unmount at end.

- [ ] **Step 2: Run to verify failure** — FAIL.

- [ ] **Step 3: Implement** — layout: `Column(children:[Expanded(Stack([viewport, top controls (leading + layout SegmentedButton), corner legend, bottom readout])), TimeScrubBar])`. Handle `profiles.when(loading/error/data)`; on data with `< 2` show the empty state; if the adapter capped, show `dive3d_compare_showing`. Dispose the notifier/controller.

- [ ] **Step 4: Run tests** — PASS. Also run `flutter gen-l10n` so `app_en.arb` keys resolve, then `flutter analyze lib/features/dive_3d`.

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_3d/presentation/widgets/compare_profile_3d_view.dart test/features/dive_3d/presentation/widgets/compare_profile_3d_view_test.dart
git add lib/features/dive_3d/presentation/widgets/compare_profile_3d_view.dart \
        test/features/dive_3d/presentation/widgets/compare_profile_3d_view_test.dart \
        lib/l10n/app_en.arb
git commit -m "feat(dive_3d): shared CompareProfile3dView"
```

---

### Task 12: `Dive3dPage` Computers mode + `initialMode`

**Files:**
- Modify: `lib/features/dive_3d/presentation/pages/dive_3d_page.dart`
- Modify: `lib/l10n/app_en.arb` (`dive3d_scene_computers`)
- Test: `test/features/dive_3d/presentation/pages/dive_3d_page_test.dart` (add cases)

**Interfaces:**
- Consumes: `isMultiDataSourceDiveProvider(diveId)`, `computerComparisonProfilesProvider(diveId)`, `CompareProfile3dView`.
- Produces: `enum SceneKind { dive, tissue, computers }`, `Dive3dPage(diveId, {SceneKind initialMode = SceneKind.dive})`.

- [ ] **Step 1: Add failing tests** — (a) with `isMultiDataSourceDiveProvider('d1')` overridden `false`, the "Computers" segment is absent; (b) overridden `true`, the segment shows and tapping it renders a `CompareProfile3dView`; (c) `Dive3dPage(diveId, initialMode: SceneKind.computers)` starts on that mode. Override `computerComparisonProfilesProvider('d1')` with two fixture profiles.

- [ ] **Step 2: Run to verify failure** — FAIL.

- [ ] **Step 3: Implement** — add `computers` to `SceneKind`; add `initialMode` field, set `_sceneKind = widget.initialMode` in `initState`; in `_sceneSwitcher`, conditionally append the Computers `ButtonSegment` when `ref.watch(isMultiDataSourceDiveProvider(diveId)).valueOrNull == true`; add `_buildComputersBody()` returning `CompareProfile3dView(profiles: ref.watch(computerComparisonProfilesProvider(widget.diveId)), title: ..., initialLayout: CompareLayout.overlay, leading: _sceneSwitcher())`; route `build` to it when `_sceneKind == SceneKind.computers`. Add `dive3d_scene_computers` to `app_en.arb`.

- [ ] **Step 4: Run tests + gen-l10n + analyze** — `flutter gen-l10n`; `flutter test test/features/dive_3d/presentation/pages/dive_3d_page_test.dart`; `flutter analyze lib/features/dive_3d`.

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_3d/presentation/pages/dive_3d_page.dart test/features/dive_3d/presentation/pages/dive_3d_page_test.dart
git add lib/features/dive_3d/presentation/pages/dive_3d_page.dart \
        test/features/dive_3d/presentation/pages/dive_3d_page_test.dart lib/l10n/app_en.arb
git commit -m "feat(dive_3d): Computers comparison mode in the 3D view"
```

---

### Task 13: `CompareDives3dPage` + `compareDives3d` route

**Files:**
- Create: `lib/features/dive_3d/presentation/pages/compare_dives_3d_page.dart`
- Modify: `lib/core/router/app_router.dart`
- Test: `test/features/dive_3d/presentation/pages/compare_dives_3d_page_test.dart`

**Interfaces:**
- Consumes: `diveComparisonProfilesProvider(DiveIdSet)`, `CompareProfile3dView`, `DiveIdSet`.
- Produces: `CompareDives3dPage({required List<String> diveIds})`; route name `compareDives3d`.

- [ ] **Step 1: Write the failing page test** — pump `CompareDives3dPage(diveIds: ['a','b'])` inside a `ProviderScope` overriding `diveComparisonProfilesProvider(DiveIdSet(['a','b']))` with two fixture profiles; expect a `CompareProfile3dView`. Bounded pumps; unmount at end.

- [ ] **Step 2: Run to verify failure** — FAIL.

- [ ] **Step 3: Implement the page + route** — page:

```dart
class CompareDives3dPage extends ConsumerWidget {
  final List<String> diveIds;
  const CompareDives3dPage({super.key, required this.diveIds});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(diveComparisonProfilesProvider(DiveIdSet(diveIds)));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dive3d_compare_dives_title)),
      body: CompareProfile3dView(
        profiles: profiles,
        title: context.l10n.dive3d_compare_dives_title,
        initialLayout: CompareLayout.sideBySide,
      ),
    );
  }
}
```

Route (in `app_router.dart`, sibling of `bulkEditDives`):

```dart
GoRoute(
  path: 'compare-3d',
  name: 'compareDives3d',
  redirect: (context, state) {
    final ids = (state.extra as List<dynamic>?)?.cast<String>();
    return (ids == null || ids.length < 2) ? '/dives' : null;
  },
  builder: (context, state) {
    final ids = (state.extra as List<dynamic>?)?.cast<String>() ?? const <String>[];
    return CompareDives3dPage(diveIds: ids);
  },
),
```

Add `dive3d_compare_dives_title` ("Compare dives") to `app_en.arb`.

- [ ] **Step 4: Run tests + gen-l10n + analyze**.

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_3d/presentation/pages/compare_dives_3d_page.dart lib/core/router/app_router.dart test/features/dive_3d/presentation/pages/compare_dives_3d_page_test.dart
git add lib/features/dive_3d/presentation/pages/compare_dives_3d_page.dart \
        lib/core/router/app_router.dart \
        test/features/dive_3d/presentation/pages/compare_dives_3d_page_test.dart lib/l10n/app_en.arb
git commit -m "feat(dive_3d): compare-dives page + route"
```

---

### Task 14: Dives-list "Compare in 3D" selection action

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
- Modify: `lib/l10n/app_en.arb` (`diveLog_selection_tooltip_compare3d`)
- Test: `test/features/dive_log/presentation/widgets/dive_list_content_test.dart` (add a case, or the nearest existing selection test)

**Interfaces:**
- Consumes: `_selectedIds`, `context.pushNamed('compareDives3d', extra: ids)`.

- [ ] **Step 1: Add a failing test** — enter selection mode, select 2 dives, expect a `compare3d` tooltip/icon present; selecting 1 hides it. (Follow the existing selection-mode test setup in the file's test.)

- [ ] **Step 2: Run to verify failure** — FAIL.

- [ ] **Step 3: Implement** — add:

```dart
Future<void> _compareIn3d() async {
  final ids = _selectedIds.toList();
  if (ids.length < 2) return;
  await context.pushNamed('compareDives3d', extra: ids);
  if (mounted) _exitSelectionMode();
}
```

and, in BOTH `_buildSelectionAppBar` and `_buildSelectionBar`, add after the `call_merge` action:

```dart
if (_selectedIds.length >= 2)
  IconButton(
    icon: const Icon(Icons.view_in_ar), // (size: 20 in _buildSelectionBar)
    tooltip: context.l10n.diveLog_selection_tooltip_compare3d,
    onPressed: _compareIn3d,
  ),
```

Add `diveLog_selection_tooltip_compare3d` ("Compare in 3D") to `app_en.arb`.

- [ ] **Step 4: Run tests + gen-l10n + analyze**.

- [ ] **Step 5: Format + commit**

```bash
dart format lib/features/dive_log/presentation/widgets/dive_list_content.dart test/features/dive_log/presentation/widgets/dive_list_content_test.dart
git add lib/features/dive_log/presentation/widgets/dive_list_content.dart \
        test/features/dive_log/presentation/widgets/dive_list_content_test.dart lib/l10n/app_en.arb
git commit -m "feat(dive_log): Compare in 3D action on the dives selection bar"
```

---

### Task 15: Detail-page source-section "Compare in 3D" + l10n backfill

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/data_sources_section.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`
- Modify: all `lib/l10n/app_*.arb` (10 non-en locales) + `app_en.arb` audit
- Test: `test/features/dive_log/presentation/widgets/data_sources_section_test.dart` (add a case)

**Interfaces:**
- Produces: optional `void Function()? onCompareIn3d` on `DataSourcesSection`, rendered as a button when non-null and `dataSources.length >= 2`. Detail page passes a callback that pushes `Dive3dPage(diveId: dive.id, initialMode: SceneKind.computers)` via the existing `Navigator.push(MaterialPageRoute(...))` idiom (dive_detail_page.dart:1299).

- [ ] **Step 1: Add a failing test** — pump `DataSourcesSection` with two sources and a non-null `onCompareIn3d`; expect a "Compare in 3D" button that fires the callback; with one source it is absent.

- [ ] **Step 2: Run to verify failure** — FAIL.

- [ ] **Step 3: Implement** — add the optional field to `DataSourcesSection`; render a `TextButton.icon(Icons.view_in_ar, ...)` in the section header when `widget.onCompareIn3d != null && widget.dataSources.length >= 2`. In `dive_detail_page.dart` where `DataSourcesSection(...)` is built (~line 409), pass:

```dart
onCompareIn3d: () => Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => Dive3dPage(diveId: dive.id, initialMode: SceneKind.computers),
  ),
),
```

Add `import '.../dive_3d/presentation/pages/dive_3d_page.dart';` to the detail page if not present. Add `diveLog_sources_compareIn3d` ("Compare in 3D") to `app_en.arb`.

- [ ] **Step 4: Backfill all locales** — for every new key added across Tasks 11-15 (`dive3d_compare_layout_sideBySide`, `dive3d_compare_layout_overlay`, `dive3d_compare_empty`, `dive3d_compare_showing`, `dive3d_scene_computers`, `dive3d_compare_dives_title`, `diveLog_selection_tooltip_compare3d`, `diveLog_sources_compareIn3d`), add a translated entry to each of the 10 non-en arb files (match each locale's existing conventions), then run `flutter gen-l10n`. Verify with `flutter analyze` (missing-translation warnings must be clean).

- [ ] **Step 5: Run full dive_3d + touched dive_log tests, format, commit**

Run: `flutter test test/features/dive_3d test/features/dive_log/presentation/widgets/data_sources_section_test.dart`; `flutter analyze` (whole project).

```bash
dart format .
git add lib/features/dive_log/presentation/widgets/data_sources_section.dart \
        lib/features/dive_log/presentation/pages/dive_detail_page.dart \
        test/features/dive_log/presentation/widgets/data_sources_section_test.dart lib/l10n/
git commit -m "feat(dive_log): Compare in 3D from the detail source section + l10n"
```

---

## Sequencing note

Tasks 3 and 4 are co-dependent (`CompareGeometryService` imports `DivergenceBuilder`); implement Task 4's file before running Task 3's tests, and treat them as one review gate. Task 5 (career refactor) must follow both. Everything else is linear.

## Post-implementation

- Device walkthrough on macOS/iOS/Android (orbit, layout toggle, scrub, reference change, both entry points).
- The feature depends on PR #565; ensure that has merged (or rebase) before opening this feature's PR.
