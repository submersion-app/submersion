# Seascape Contours and Chart Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the 3D seascape readable and briefing-grade: unit-aware contour lines with labels, a north-up chart mode, a depth legend, steep-wall highlighting, terrain appearance controls, and a sites-map entry point.

**Architecture:** Pure-domain builders (marching squares, wall slope, ribbon meshes) feed the existing `Scene3d` layer/overlay pipeline; user knobs live in a `SeascapeAppearance` value object persisted device-locally through `AppSettings`; chart mode is a camera pose (yaw 180 / pitch 90 / mirrorX) plus chrome changes on the existing pages.

**Tech Stack:** Flutter, Riverpod (StateNotifier settings + FutureProvider.family geometry), CustomPainter rendering (no GL), SharedPreferences, flutter gen-l10n.

**Spec:** `docs/superpowers/specs/2026-08-15-seascape-contours-chart-mode-design.md`

## Global Constraints

- Working tree: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/seascape-contours`. Run every command from there. NEVER touch the main checkout at `/Users/ericgriffin/repos/submersion-app/submersion` (a Read/Edit with a main-tree absolute path silently edits main).
- NEVER use the em-dash character (U+2014) in any output: code, comments, docs, commit messages. No `--` or spaced-hyphen prose punctuation either.
- No emojis anywhere. Immutability always. Files max 800 lines.
- Every new l10n key goes into ALL 11 arb files: `app_en.arb`, `app_ar.arb`, `app_de.arb`, `app_es.arb`, `app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`, `app_pt.arb`, `app_zh.arb` (all under `lib/l10n/arb/`). Run `flutter gen-l10n` from the PROJECT ROOT (it fails from subdirectories), then commit the regenerated `lib/l10n/arb/app_localizations*.dart` files together with the arb changes.
- Run `dart format .` before every commit. Commit messages: conventional style (`feat(seascape): ...`), NO `Co-Authored-By:` trailer.
- Widget tests: never `pumpAndSettle` on pages that host maps or looping animations; use bounded pumps (`await tester.pump()` twice). Pages that watch `settingsProvider` need the `_TestSettingsNotifier` override pattern (see `test/features/dive_3d/presentation/site_seascape_page_test.dart:14`).
- Depth convention: meters positive DOWN; negative = land elevation; null = nodata (`BathymetryGrid`).
- Scene convention: X = east, Z = north, Y = -depth (0 at waterline, -6 at scene max depth). `SceneBounds.xSpan = 10`, `ySpan = 6`.
- Engine trap: positive pitch tips scene-north toward screen BOTTOM at yaw 0. Chart pose derivations must be verified by unit test via `compassNeedleAngle`, never assumed.

## File Structure

New files:

| File | Responsibility |
| --- | --- |
| `lib/features/dive_3d/domain/spatial/seascape_appearance.dart` | `SeascapeAppearance` value object + JSON codec + `SeascapeContourMode`/`SeascapeContourLevel` |
| `lib/features/dive_3d/domain/spatial/contour_builder.dart` | Level resolution, marching squares, polyline joining, ribbon meshes, label anchors |
| `lib/features/dive_3d/domain/spatial/wall_highlight_builder.dart` | Per-cell slope + steep-wall highlight mesh |
| `lib/features/dive_3d/presentation/widgets/seascape_depth_legend.dart` | Depth legend chip (ramp bar, ticks, land swatch) |
| `lib/features/dive_3d/presentation/widgets/terrain_appearance_sheet.dart` | Bottom sheet editing `SeascapeAppearance` via `SettingsNotifier` |

Modified files: `scene_overlay.dart`, `dive_3d_page.dart` (overlay menu), `bathymetry_terrain_builder.dart` (ramp options), `site_seascape_geometry_service.dart`, `spatial_geometry_service.dart`, `site_seascape_providers.dart`, `spatial_providers.dart`, `scene_projector.dart` (mirrorX), `preview_painter.dart` (mirrorX), `tissue_chrome_painters.dart` (contour labels + mirrorX), `dive_3d_interactive_viewport.dart` (chartMode + passthrough), `site_seascape_page.dart`, `spatial_site_page.dart`, `settings_providers.dart` (AppSettings field + device-local persistence), `map_info_card.dart` (trailing slot), `site_map_content.dart` (terrain button), all 11 arb files.

---

### Task 1: Worktree init + SeascapeAppearance value object

**Files:**
- Create: `lib/features/dive_3d/domain/spatial/seascape_appearance.dart`
- Test: `test/features/dive_3d/domain/spatial/seascape_appearance_test.dart`

**Interfaces:**
- Consumes: nothing (leaf value object). `package:equatable` is already a dependency.
- Produces: `SeascapeAppearance` (fields `double? rampMaxDepthMeters`, `bool rampBanded`, `SeascapeContourMode contourMode`, `List<SeascapeContourLevel> customLevels`, `double contourThickness`, `double wallAngleDeg`; methods `encode()`, `SeascapeAppearance.decode(String?)`, `copyWith(...)` with `clearRampMax`), `SeascapeContourMode { auto, custom }`, `SeascapeContourLevel { double depthMeters; int? colorArgb; }`. Every later task uses these exact names.

- [ ] **Step 1: Initialize the worktree toolchain**

Run (from the worktree root):
```bash
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```
Expected: all three succeed. The codegen step is REQUIRED before any test runs in a fresh worktree.

- [ ] **Step 2: Write the failing test**

Create `test/features/dive_3d/domain/spatial/seascape_appearance_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';

void main() {
  test('defaults are the spec defaults', () {
    const a = SeascapeAppearance();
    expect(a.rampMaxDepthMeters, isNull);
    expect(a.rampBanded, isFalse);
    expect(a.contourMode, SeascapeContourMode.auto);
    expect(a.customLevels, isEmpty);
    expect(a.contourThickness, 1.0);
    expect(a.wallAngleDeg, 22.0);
  });

  test('encode/decode round-trips every field', () {
    const a = SeascapeAppearance(
      rampMaxDepthMeters: 40.0,
      rampBanded: true,
      contourMode: SeascapeContourMode.custom,
      customLevels: [
        SeascapeContourLevel(depthMeters: 10.0),
        SeascapeContourLevel(depthMeters: 20.0, colorArgb: 0xFFEF4444),
      ],
      contourThickness: 1.5,
      wallAngleDeg: 30.0,
    );
    final decoded = SeascapeAppearance.decode(a.encode());
    expect(decoded, a);
    expect(decoded.customLevels[1].colorArgb, 0xFFEF4444);
  });

  test('decode of null, garbage, or wrong shapes yields defaults', () {
    expect(SeascapeAppearance.decode(null), const SeascapeAppearance());
    expect(SeascapeAppearance.decode('not json'), const SeascapeAppearance());
    expect(SeascapeAppearance.decode('[1,2]'), const SeascapeAppearance());
    expect(SeascapeAppearance.decode('{"wallAngleDeg":"x"}'),
        const SeascapeAppearance());
  });

  test('copyWith clearRampMax clears the nullable field', () {
    const a = SeascapeAppearance(rampMaxDepthMeters: 40.0);
    expect(a.copyWith(clearRampMax: true).rampMaxDepthMeters, isNull);
    expect(a.copyWith(wallAngleDeg: 35.0).rampMaxDepthMeters, 40.0);
  });

  test('value equality via Equatable', () {
    expect(const SeascapeAppearance(rampBanded: true),
        const SeascapeAppearance(rampBanded: true));
    expect(const SeascapeAppearance(),
        isNot(const SeascapeAppearance(rampBanded: true)));
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/spatial/seascape_appearance_test.dart`
Expected: FAIL (file `seascape_appearance.dart` does not exist).

- [ ] **Step 4: Write the implementation**

Create `lib/features/dive_3d/domain/spatial/seascape_appearance.dart`:

```dart
import 'dart:convert';

import 'package:equatable/equatable.dart';

/// How contour levels are chosen: nice unit-aware steps, or a user list.
enum SeascapeContourMode { auto, custom }

/// One user-defined contour level. Depth is stored in METERS regardless of
/// the display unit; [colorArgb] null means the standard contour ink.
class SeascapeContourLevel extends Equatable {
  final double depthMeters;
  final int? colorArgb;

  const SeascapeContourLevel({required this.depthMeters, this.colorArgb});

  Map<String, dynamic> toJson() => {
    'depthMeters': depthMeters,
    if (colorArgb != null) 'colorArgb': colorArgb,
  };

  static SeascapeContourLevel? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final depth = json['depthMeters'];
    if (depth is! num || !depth.isFinite || depth <= 0) return null;
    final color = json['colorArgb'];
    return SeascapeContourLevel(
      depthMeters: depth.toDouble(),
      colorArgb: color is int ? color : null,
    );
  }

  @override
  List<Object?> get props => [depthMeters, colorArgb];
}

/// The seascape terrain-appearance knobs (issue #1065): device-local view
/// preferences carried on AppSettings and threaded into the geometry
/// builders as plain data (crosses compute() isolates).
class SeascapeAppearance extends Equatable {
  /// Null = ramp spans the terrain's own depth range (legacy behavior).
  final double? rampMaxDepthMeters;
  final bool rampBanded;
  final SeascapeContourMode contourMode;
  final List<SeascapeContourLevel> customLevels;

  /// Multiplier on contour ribbon width, slider range 0.5 to 3.0.
  final double contourThickness;

  /// Cells steeper than this highlight as walls, slider range 5 to 90.
  final double wallAngleDeg;

  const SeascapeAppearance({
    this.rampMaxDepthMeters,
    this.rampBanded = false,
    this.contourMode = SeascapeContourMode.auto,
    this.customLevels = const [],
    this.contourThickness = 1.0,
    this.wallAngleDeg = 22.0,
  });

  SeascapeAppearance copyWith({
    double? rampMaxDepthMeters,
    bool clearRampMax = false,
    bool? rampBanded,
    SeascapeContourMode? contourMode,
    List<SeascapeContourLevel>? customLevels,
    double? contourThickness,
    double? wallAngleDeg,
  }) => SeascapeAppearance(
    rampMaxDepthMeters: clearRampMax
        ? null
        : (rampMaxDepthMeters ?? this.rampMaxDepthMeters),
    rampBanded: rampBanded ?? this.rampBanded,
    contourMode: contourMode ?? this.contourMode,
    customLevels: customLevels ?? this.customLevels,
    contourThickness: contourThickness ?? this.contourThickness,
    wallAngleDeg: wallAngleDeg ?? this.wallAngleDeg,
  );

  String encode() => jsonEncode({
    if (rampMaxDepthMeters != null) 'rampMaxDepthMeters': rampMaxDepthMeters,
    'rampBanded': rampBanded,
    'contourMode': contourMode.name,
    'customLevels': [for (final l in customLevels) l.toJson()],
    'contourThickness': contourThickness,
    'wallAngleDeg': wallAngleDeg,
  });

  /// Defensive decode: any missing or malformed field falls back to its
  /// default so a corrupt pref can never break the seascape.
  factory SeascapeAppearance.decode(String? raw) {
    if (raw == null || raw.isEmpty) return const SeascapeAppearance();
    Object? parsed;
    try {
      parsed = jsonDecode(raw);
    } on FormatException {
      return const SeascapeAppearance();
    }
    if (parsed is! Map<String, dynamic>) return const SeascapeAppearance();
    const defaults = SeascapeAppearance();
    final ramp = parsed['rampMaxDepthMeters'];
    final banded = parsed['rampBanded'];
    final mode = parsed['contourMode'];
    final levels = parsed['customLevels'];
    final thickness = parsed['contourThickness'];
    final wall = parsed['wallAngleDeg'];
    return SeascapeAppearance(
      rampMaxDepthMeters: (ramp is num && ramp.isFinite && ramp > 0)
          ? ramp.toDouble()
          : null,
      rampBanded: banded is bool ? banded : defaults.rampBanded,
      contourMode: mode == SeascapeContourMode.custom.name
          ? SeascapeContourMode.custom
          : SeascapeContourMode.auto,
      customLevels: levels is List
          ? [
              for (final e in levels)
                if (SeascapeContourLevel.fromJson(e) != null)
                  SeascapeContourLevel.fromJson(e)!,
            ]
          : defaults.customLevels,
      contourThickness: (thickness is num && thickness.isFinite)
          ? thickness.toDouble().clamp(0.5, 3.0)
          : defaults.contourThickness,
      wallAngleDeg: (wall is num && wall.isFinite)
          ? wall.toDouble().clamp(5.0, 90.0)
          : defaults.wallAngleDeg,
    );
  }

  @override
  List<Object?> get props => [
    rampMaxDepthMeters,
    rampBanded,
    contourMode,
    customLevels,
    contourThickness,
    wallAngleDeg,
  ];
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/dive_3d/domain/spatial/seascape_appearance_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/dive_3d/domain/spatial/seascape_appearance.dart test/features/dive_3d/domain/spatial/seascape_appearance_test.dart
git commit -m "feat(seascape): SeascapeAppearance value object with JSON codec"
```

### Task 2: AppSettings field + device-local persistence + setter

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (four spots: `SettingsKeys` at `:48`, `AppSettings` fields near `:430`, constructor defaults near `:559`, `copyWith` near `:716`, `_loadSettings` device-local block near `:1036`, `_saveSettings` near `:1134`, plus a new setter near `setTissueColorScheme` at `:1581`)
- Test: `test/features/settings/seascape_appearance_setting_test.dart`

**Interfaces:**
- Consumes: `SeascapeAppearance` from Task 1.
- Produces: `AppSettings.seascapeAppearance` (type `SeascapeAppearance`, default `const SeascapeAppearance()`), `SettingsNotifier.setSeascapeAppearance(SeascapeAppearance)` (async, persists), `SettingsKeys.seascapeAppearance = 'seascape_appearance'`. Later tasks watch `settingsProvider.select((s) => s.seascapeAppearance)`.

**Persistence lane decision (spec correction, planning time):** this field is DEVICE-LOCAL, persisted as one JSON string in SharedPreferences, exactly like `profileMetricsFollowViewport`. It does NOT go into the per-diver `diver_settings` Drift table because that would require a main-DB schema migration plus sync surface, which the spec scopes out. Task 17 amends the spec text.

- [ ] **Step 1: Write the failing test**

Create `test/features/settings/seascape_appearance_setting_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads seascape appearance from SharedPreferences with no diver', () async {
    const stored = SeascapeAppearance(rampBanded: true, wallAngleDeg: 30.0);
    SharedPreferences.setMockInitialValues({
      SettingsKeys.seascapeAppearance: stored.encode(),
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    container.read(settingsProvider);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(settingsProvider).seascapeAppearance, stored);
  });

  test('setSeascapeAppearance updates state and persists to prefs', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    container.read(settingsProvider);
    await Future<void>.delayed(Duration.zero);

    const next = SeascapeAppearance(
      rampMaxDepthMeters: 40.0,
      contourMode: SeascapeContourMode.custom,
      customLevels: [SeascapeContourLevel(depthMeters: 10.0)],
    );
    await container.read(settingsProvider.notifier).setSeascapeAppearance(next);

    expect(container.read(settingsProvider).seascapeAppearance, next);
    expect(
      SeascapeAppearance.decode(
        prefs.getString(SettingsKeys.seascapeAppearance),
      ),
      next,
    );
  });
}
```

Note: with no `currentDiverIdKey` seeded, the notifier takes the defaults-plus-device-local path and never touches the database (see `_loadSettings` `:1044`), so no test database is needed.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/settings/seascape_appearance_setting_test.dart`
Expected: FAIL (`SettingsKeys.seascapeAppearance` and the field do not exist).

- [ ] **Step 3: Implement the settings plumbing**

In `settings_providers.dart`, make these five edits:

1. Add to `SettingsKeys` (after `perdixOverlayY`):
```dart
  // Seascape terrain appearance (device-local, stored directly in
  // SharedPreferences rather than per-diver in the DB). One JSON blob.
  static const String seascapeAppearance = 'seascape_appearance';
```

2. Add the import at the top (grouped with the other package:submersion imports):
```dart
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
```

3. Add the field to `AppSettings` next to `profileMetricsFollowViewport` (`:430`), the constructor default next to `:559`, and the `copyWith` pair next to `:716`/`:872`:
```dart
  final SeascapeAppearance seascapeAppearance;
```
```dart
    this.seascapeAppearance = const SeascapeAppearance(),
```
```dart
    SeascapeAppearance? seascapeAppearance,
```
```dart
      seascapeAppearance: seascapeAppearance ?? this.seascapeAppearance,
```

4. In `_loadSettings`, in the device-local block (after `perdixOverlayY` is read, `:1041`):
```dart
      final seascapeAppearance = SeascapeAppearance.decode(
        prefs.getString(SettingsKeys.seascapeAppearance),
      );
```
and pass `seascapeAppearance: seascapeAppearance,` in BOTH the no-diver `AppSettings(...)` construction (`:1046`) and the `settings.copyWith(...)` call (`:1070`).

5. In `_saveSettings` (after the perdix block, `:1150`) and as a new setter next to `setTissueColorScheme` (`:1581`):
```dart
    await prefs.setString(
      SettingsKeys.seascapeAppearance,
      state.seascapeAppearance.encode(),
    );
```
```dart
  Future<void> setSeascapeAppearance(SeascapeAppearance appearance) async {
    state = state.copyWith(seascapeAppearance: appearance);
    await _saveSettings();
  }
```

- [ ] **Step 4: Run the test and the existing settings suite**

Run: `flutter test test/features/settings/seascape_appearance_setting_test.dart test/features/settings/deco_stop_settings_notifier_test.dart`
Expected: PASS (the second file proves the per-diver lane still works).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/settings/presentation/providers/settings_providers.dart test/features/settings/seascape_appearance_setting_test.dart
git commit -m "feat(seascape): device-local seascapeAppearance setting"
```

---

### Task 3: Contour level resolution (auto nice steps + custom)

**Files:**
- Create: `lib/features/dive_3d/domain/spatial/contour_builder.dart` (level-resolution half)
- Test: `test/features/dive_3d/domain/spatial/contour_builder_test.dart`

**Interfaces:**
- Consumes: `niceStep` from `seascape_axes.dart`, `SeascapeAppearance` from Task 1.
- Produces: `ResolvedContourLevel { double depthMeters; bool isMajor; String label; int? colorArgb; }` and
  `List<ResolvedContourLevel> resolvedContourLevels({required double maxDepthMeters, required double displayUnitInMeters, required String depthSymbol, required SeascapeAppearance appearance})`.
  Tasks 4, 5, 11 use these exact names.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_3d/domain/spatial/contour_builder_test.dart`. Hand-computed vectors (spell them out in comments exactly like this):

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/spatial/contour_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';

void main() {
  group('resolvedContourLevels auto mode', () {
    test('meters diver, 35 m site: 5 m steps, majors every 5th', () {
      // span = 35 display units; niceStep(35 / 15) = niceStep(2.33) = 5.
      // Levels: 5,10,15,20,25,30,35 (7 levels). Major at k % 5 == 0: 25.
      final levels = resolvedContourLevels(
        maxDepthMeters: 35,
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
        appearance: const SeascapeAppearance(),
      );
      expect(levels.map((l) => l.depthMeters).toList(),
          [5, 10, 15, 20, 25, 30, 35]);
      expect(levels.map((l) => l.isMajor).toList(),
          [false, false, false, false, true, false, false]);
      expect(levels.first.label, '5 m');
      expect(levels.every((l) => l.colorArgb == null), isTrue);
    });

    test('feet diver, 35 m site: nice steps in feet, meters underneath', () {
      // 35 m = 114.83 ft; niceStep(114.83 / 15) = niceStep(7.66) = 10 ft.
      // Levels 10..110 ft (11 levels), majors at 50 and 100 ft.
      final levels = resolvedContourLevels(
        maxDepthMeters: 35,
        displayUnitInMeters: 0.3048,
        depthSymbol: 'ft',
        appearance: const SeascapeAppearance(),
      );
      expect(levels, hasLength(11));
      expect(levels.first.depthMeters, closeTo(3.048, 1e-9));
      expect(levels.first.label, '10 ft');
      expect(levels[4].isMajor, isTrue); // 50 ft
      expect(levels[9].isMajor, isTrue); // 100 ft
    });

    test('flat-site guard: fewer than 2 fitting levels means none', () {
      // The step has a floor of 1 display unit (no centimeter contours), so
      // span 1.9 m at unit 1.0: step = max(niceStep(1.9/15), 1) = 1;
      // count = floor(1.9 / 1) = 1 < 2: guard fires, no contours.
      expect(
        resolvedContourLevels(
          maxDepthMeters: 1.9,
          displayUnitInMeters: 1.0,
          depthSymbol: 'm',
          appearance: const SeascapeAppearance(),
        ),
        isEmpty,
      );
      expect(
        resolvedContourLevels(
          maxDepthMeters: 0,
          displayUnitInMeters: 1.0,
          depthSymbol: 'm',
          appearance: const SeascapeAppearance(),
        ),
        isEmpty,
      );
      // span 2.5 m: step 1, levels 1 m and 2 m: just past the guard.
      expect(
        resolvedContourLevels(
          maxDepthMeters: 2.5,
          displayUnitInMeters: 1.0,
          depthSymbol: 'm',
          appearance: const SeascapeAppearance(),
        ).map((l) => l.depthMeters).toList(),
        [1.0, 2.0],
      );
    });
  });

  group('resolvedContourLevels custom mode', () {
    test('custom levels sorted, all labeled major, colors carried', () {
      final levels = resolvedContourLevels(
        maxDepthMeters: 50,
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
        appearance: const SeascapeAppearance(
          contourMode: SeascapeContourMode.custom,
          customLevels: [
            SeascapeContourLevel(depthMeters: 20.0, colorArgb: 0xFF10B981),
            SeascapeContourLevel(depthMeters: 10.0),
          ],
        ),
      );
      expect(levels.map((l) => l.depthMeters).toList(), [10.0, 20.0]);
      expect(levels.every((l) => l.isMajor), isTrue);
      expect(levels[1].colorArgb, 0xFF10B981);
      expect(levels[0].label, '10 m');
    });

    test('empty custom list falls back to auto', () {
      final levels = resolvedContourLevels(
        maxDepthMeters: 35,
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
        appearance: const SeascapeAppearance(
          contourMode: SeascapeContourMode.custom,
        ),
      );
      expect(levels, hasLength(7)); // same as the auto 35 m case
    });

    test('custom level deeper than terrain is kept (yields no line later)',
        () {
      final levels = resolvedContourLevels(
        maxDepthMeters: 15,
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
        appearance: const SeascapeAppearance(
          contourMode: SeascapeContourMode.custom,
          customLevels: [SeascapeContourLevel(depthMeters: 40.0)],
        ),
      );
      expect(levels.single.depthMeters, 40.0);
    });
  });
}
```

Before finalizing the first test's expectations, verify the arithmetic against `niceStep` (`seascape_axes.dart:31`): `niceStep(t)` returns the smallest of 1/2/5 x 10^n that is >= t. Compute each expectation by hand in the comment.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/spatial/contour_builder_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement level resolution**

Create `lib/features/dive_3d/domain/spatial/contour_builder.dart` (the marching-squares half arrives in Task 4):

```dart
import 'dart:math' as math;

import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_axes.dart';

/// One contour level ready to march: meters for geometry, a display-unit
/// label for chrome, and an optional user color (custom mode).
class ResolvedContourLevel {
  final double depthMeters;
  final bool isMajor;
  final String label;
  final int? colorArgb;

  const ResolvedContourLevel({
    required this.depthMeters,
    required this.isMajor,
    required this.label,
    this.colorArgb,
  });
}

String _formatLevel(double displayValue, String depthSymbol) {
  final text = displayValue % 1 == 0
      ? displayValue.toStringAsFixed(0)
      : displayValue.toStringAsFixed(1);
  return '$text $depthSymbol';
}

/// Resolves the contour levels for a terrain of [maxDepthMeters]. Auto mode
/// picks the smallest nice step (1/2/5 x 10^n, in the DIVER'S display unit)
/// that yields at most 15 levels, floored at 1 display unit so flat sites
/// never get centimeter contours; majors every 5th; fewer than 2 fitting
/// levels means none (flat-site guard). Custom mode uses the user's list
/// (sorted, every level labeled and treated as major); an empty list falls
/// back to auto.
List<ResolvedContourLevel> resolvedContourLevels({
  required double maxDepthMeters,
  required double displayUnitInMeters,
  required String depthSymbol,
  required SeascapeAppearance appearance,
}) {
  if (appearance.contourMode == SeascapeContourMode.custom &&
      appearance.customLevels.isNotEmpty) {
    final sorted = [...appearance.customLevels]
      ..sort((a, b) => a.depthMeters.compareTo(b.depthMeters));
    return [
      for (final l in sorted)
        ResolvedContourLevel(
          depthMeters: l.depthMeters,
          isMajor: true,
          label: _formatLevel(l.depthMeters / displayUnitInMeters, depthSymbol),
          colorArgb: l.colorArgb,
        ),
    ];
  }

  if (maxDepthMeters <= 0 || displayUnitInMeters <= 0) return const [];
  final spanDisplay = maxDepthMeters / displayUnitInMeters;
  final step = math.max(niceStep(spanDisplay / 15), 1.0);
  if (step <= 0) return const [];
  final count = (spanDisplay / step + 1e-9).floor();
  if (count < 2) return const [];
  return [
    for (var k = 1; k <= count; k++)
      ResolvedContourLevel(
        depthMeters: k * step * displayUnitInMeters,
        isMajor: k % 5 == 0,
        label: _formatLevel(k * step, depthSymbol),
      ),
  ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_3d/domain/spatial/contour_builder_test.dart`
Expected: PASS. If an auto-mode expectation fails, recompute the hand vector against `niceStep` and fix the TEST only if the hand math was wrong; fix the implementation if the rule (smallest nice step, at most 15 levels, majors every 5th) was violated.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_3d/domain/spatial/contour_builder.dart test/features/dive_3d/domain/spatial/contour_builder_test.dart
git commit -m "feat(seascape): unit-aware contour level resolution"
```

### Task 4: Marching squares + polyline joining

**Files:**
- Modify: `lib/features/dive_3d/domain/spatial/contour_builder.dart`
- Modify: `lib/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart:25` (make `_metersPerDegLat` public)
- Test: `test/features/dive_3d/domain/spatial/contour_builder_test.dart` (extend)

**Interfaces:**
- Consumes: `BathymetryGrid` (`depthAt(row, col)`, rows south to north, cols west to east), `ResolvedContourLevel` from Task 3.
- Produces: `class ContourPolyline { final List<double> pointsEastNorth; }` (flat east,north pairs in meters) and
  `List<ContourPolyline> marchGrid({required int rows, required int cols, required double? Function(int r, int c) depthAt, required double Function(int c) eastOf, required double Function(int r) northOf, required double levelMeters})`.
  Also renames `BathymetryTerrainBuilder._metersPerDegLat` to a public `static const double metersPerDegLat = 110540.0;` (update its two uses in that file). Task 5 and 6 consume both.

- [ ] **Step 1: Write the failing tests**

Append to `contour_builder_test.dart` (import `dart:math` is not needed; keep grid spacing at 100 m so crossings are hand-computable):

```dart
  group('marchGrid', () {
    double eastOf(int c) => c * 100.0;
    double northOf(int r) => r * 100.0;

    test('single cell, vertical isobath at the midpoint', () {
      // Corners: sw=5 se=15 nw=5 ne=15, level 10. Inside (>=10) = se+ne,
      // marching-squares case S-N: crossings at S edge t=(10-5)/(15-5)=0.5
      // -> (50, 0), and N edge t=0.5 -> (50, 100).
      final grid = [
        [5.0, 15.0], // r=0 (south)
        [5.0, 15.0], // r=1 (north)
      ];
      final lines = marchGrid(
        rows: 2,
        cols: 2,
        depthAt: (r, c) => grid[r][c],
        eastOf: eastOf,
        northOf: northOf,
        levelMeters: 10,
      );
      expect(lines, hasLength(1));
      final pts = lines.single.pointsEastNorth;
      expect(pts, hasLength(4));
      // Accept either direction along the line.
      final ends = {(pts[0], pts[1]), (pts[2], pts[3])};
      expect(ends, {(50.0, 0.0), (50.0, 100.0)});
    });

    test('segments across neighboring cells join into one polyline', () {
      // 2 rows x 3 cols: south row all 5, north row all 15, level 10.
      // Each cell crosses W (t=0.5) and E (t=0.5): a horizontal line at
      // north=50 spanning east 0..200, joined into a single 3-point line.
      final grid = [
        [5.0, 5.0, 5.0],
        [15.0, 15.0, 15.0],
      ];
      final lines = marchGrid(
        rows: 2,
        cols: 3,
        depthAt: (r, c) => grid[r][c],
        eastOf: eastOf,
        northOf: northOf,
        levelMeters: 10,
      );
      expect(lines, hasLength(1));
      final pts = lines.single.pointsEastNorth;
      expect(pts, hasLength(6));
      expect(pts[1], 50.0);
      expect(pts[3], 50.0);
      expect(pts[5], 50.0);
      final easts = {pts[0], pts[2], pts[4]};
      expect(easts, {0.0, 100.0, 200.0});
    });

    test('cells touching a null or land corner are skipped', () {
      // Same as the joining test, but the NE corner is null: the right cell
      // must be skipped, leaving only the left cell's segment.
      final grid = [
        [5.0, 5.0, 5.0],
        [15.0, 15.0, null],
      ];
      final lines = marchGrid(
        rows: 2,
        cols: 3,
        depthAt: (r, c) => grid[r][c],
        eastOf: eastOf,
        northOf: northOf,
        levelMeters: 10,
      );
      expect(lines, hasLength(1));
      expect(lines.single.pointsEastNorth, hasLength(4));
      // Land corners (depth <= 0) are skipped the same way.
      final landGrid = [
        [5.0, -2.0],
        [15.0, 15.0],
      ];
      expect(
        marchGrid(
          rows: 2,
          cols: 2,
          depthAt: (r, c) => landGrid[r][c],
          eastOf: eastOf,
          northOf: northOf,
          levelMeters: 10,
        ),
        isEmpty,
      );
    });

    test('level outside the cell range yields nothing', () {
      final grid = [
        [5.0, 6.0],
        [7.0, 8.0],
      ];
      expect(
        marchGrid(
          rows: 2,
          cols: 2,
          depthAt: (r, c) => grid[r][c],
          eastOf: eastOf,
          northOf: northOf,
          levelMeters: 40,
        ),
        isEmpty,
      );
    });
  });
```

- [ ] **Step 2: Run tests to verify the new group fails**

Run: `flutter test test/features/dive_3d/domain/spatial/contour_builder_test.dart`
Expected: compile FAIL (`marchGrid` undefined); Task 3 tests untouched.

- [ ] **Step 3: Implement marching squares + joining**

Append to `contour_builder.dart`:

```dart
/// A joined isobath polyline in local east/north METERS (flat pairs).
class ContourPolyline {
  final List<double> pointsEastNorth;
  const ContourPolyline(this.pointsEastNorth);
}

/// Marching squares over a callback grid. A cell is skipped when ANY of its
/// four corners is null (nodata) or <= 0 (land): contours stop at the edge
/// of known wet data instead of interpolating fiction. Inside = depth >=
/// level. Ambiguous saddle cases (5, 10) are resolved by the cell-center
/// average. Segments are then chained into polylines by shared endpoints.
List<ContourPolyline> marchGrid({
  required int rows,
  required int cols,
  required double? Function(int r, int c) depthAt,
  required double Function(int c) eastOf,
  required double Function(int r) northOf,
  required double levelMeters,
}) {
  final segments = <List<double>>[]; // [e1, n1, e2, n2]

  for (var r = 0; r < rows - 1; r++) {
    for (var c = 0; c < cols - 1; c++) {
      final sw = depthAt(r, c);
      final se = depthAt(r, c + 1);
      final nw = depthAt(r + 1, c);
      final ne = depthAt(r + 1, c + 1);
      if (sw == null || se == null || nw == null || ne == null) continue;
      if (sw <= 0 || se <= 0 || nw <= 0 || ne <= 0) continue;

      final e0 = eastOf(c), e1 = eastOf(c + 1);
      final n0 = northOf(r), n1 = northOf(r + 1);
      final l = levelMeters;

      var idx = 0;
      if (sw >= l) idx |= 1;
      if (se >= l) idx |= 2;
      if (ne >= l) idx |= 4;
      if (nw >= l) idx |= 8;
      if (idx == 0 || idx == 15) continue;

      double frac(double a, double b) => (l - a) / (b - a);
      // Crossing points on the four cell edges.
      List<double> south() => [e0 + (e1 - e0) * frac(sw, se), n0];
      List<double> east() => [e1, n0 + (n1 - n0) * frac(se, ne)];
      List<double> north() => [e0 + (e1 - e0) * frac(nw, ne), n1];
      List<double> west() => [e0, n0 + (n1 - n0) * frac(sw, nw)];

      void seg(List<double> a, List<double> b) =>
          segments.add([a[0], a[1], b[0], b[1]]);

      switch (idx) {
        case 1 || 14:
          seg(west(), south());
        case 2 || 13:
          seg(south(), east());
        case 3 || 12:
          seg(west(), east());
        case 4 || 11:
          seg(east(), north());
        case 6 || 9:
          seg(south(), north());
        case 7 || 8:
          seg(west(), north());
        case 5:
          final centerInside = (sw + se + ne + nw) / 4 >= l;
          if (centerInside) {
            seg(west(), north());
            seg(south(), east());
          } else {
            seg(west(), south());
            seg(east(), north());
          }
        case 10:
          final centerInside = (sw + se + ne + nw) / 4 >= l;
          if (centerInside) {
            seg(south(), west());
            seg(north(), east());
          } else {
            seg(south(), east());
            seg(north(), west());
          }
      }
    }
  }
  return _joinSegments(segments);
}

/// Chains raw segments into polylines by matching endpoints (quantized to
/// a fine key so float noise never breaks a chain).
List<ContourPolyline> _joinSegments(List<List<double>> segments) {
  String key(double e, double n) =>
      '${(e * 1e6).round()}:${(n * 1e6).round()}';

  final unused = List<bool>.filled(segments.length, true);
  final byEndpoint = <String, List<int>>{};
  for (var i = 0; i < segments.length; i++) {
    final s = segments[i];
    byEndpoint.putIfAbsent(key(s[0], s[1]), () => []).add(i);
    byEndpoint.putIfAbsent(key(s[2], s[3]), () => []).add(i);
  }

  int? takeAt(double e, double n) {
    final list = byEndpoint[key(e, n)];
    if (list == null) return null;
    for (final i in list) {
      if (unused[i]) return i;
    }
    return null;
  }

  final polylines = <ContourPolyline>[];
  for (var start = 0; start < segments.length; start++) {
    if (!unused[start]) continue;
    unused[start] = false;
    final s = segments[start];
    final pts = <double>[s[0], s[1], s[2], s[3]];
    // Extend forward from the tail.
    var extended = true;
    while (extended) {
      extended = false;
      final i = takeAt(pts[pts.length - 2], pts[pts.length - 1]);
      if (i != null) {
        unused[i] = false;
        final t = segments[i];
        final matchesHead =
            key(t[0], t[1]) ==
            key(pts[pts.length - 2], pts[pts.length - 1]);
        pts.addAll(matchesHead ? [t[2], t[3]] : [t[0], t[1]]);
        extended = true;
      }
    }
    // Extend backward from the head.
    extended = true;
    while (extended) {
      extended = false;
      final i = takeAt(pts[0], pts[1]);
      if (i != null) {
        unused[i] = false;
        final t = segments[i];
        final matchesHead = key(t[0], t[1]) == key(pts[0], pts[1]);
        pts.insertAll(0, matchesHead ? [t[2], t[3]] : [t[0], t[1]]);
        extended = true;
      }
    }
    polylines.add(ContourPolyline(pts));
  }
  return polylines;
}
```

Also in `bathymetry_terrain_builder.dart`: rename `_metersPerDegLat` (`:25`) to `metersPerDegLat` (public, same value `110540.0`) and update its two uses in `enuBounds` (`:37`, `:39`) and the row loop (`:65`).

- [ ] **Step 4: Run tests + the terrain builder suite**

Run: `flutter test test/features/dive_3d/domain/spatial/contour_builder_test.dart test/features/dive_3d/domain/spatial/bathymetry_terrain_builder_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_3d/domain/spatial/contour_builder.dart lib/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart test/features/dive_3d/domain/spatial/contour_builder_test.dart
git commit -m "feat(seascape): marching-squares isobath extraction"
```

---

### Task 5: Contour ribbons, label anchors, and the assembled build

**Files:**
- Modify: `lib/features/dive_3d/domain/spatial/contour_builder.dart`
- Test: `test/features/dive_3d/domain/spatial/contour_builder_test.dart` (extend)

**Interfaces:**
- Consumes: `marchGrid`, `resolvedContourLevels`, `SpatialProjection` (`xOf`/`yOf`/`zOf`), `MeshData`, `SceneLayer`, `SceneOverlay.contours` (Task 8 adds the enum value; USE IT NOW and let this task's code compile only after Task 8 if executed out of order; in-order execution is Task 4 then 8 then 5 is NOT required because Task 8 only adds enum members: to keep this task self-contained, Task 5 includes the enum addition if it is not already present, see Step 3a).
- Produces:
  - `class ContourLabelSpec { final String text; final List<double> anchorsXyz; }` (flat xyz triplets, scene space)
  - `class ContourBuildResult { final List<SceneLayer> layers; final List<ContourLabelSpec> labels; static const empty = ...; }`
  - `ContourBuildResult buildContourLayers({required BathymetryGrid grid, required GeoPoint center, required SpatialProjection projection, required SeascapeAppearance appearance, required double displayUnitInMeters, required String depthSymbol})`
  - const `contourLiftSceneUnits = 0.03`
  Tasks 9, 10, 11 consume these exact names.

- [ ] **Step 3a: Enum prerequisite check**

If `SceneOverlay` (`lib/features/dive_3d/presentation/scene_overlay.dart`) does not yet contain `contours`, `water`, and `steepWalls`, apply Task 8 Step 3 (enum + `dive_3d_page.dart` switch arms + filter) FIRST, then continue here. Exhaustive switches over this enum exist in `dive_3d_page.dart:313`; adding members without updating them breaks the build.

- [ ] **Step 1: Write the failing tests**

Append to `contour_builder_test.dart` (new imports: `package:submersion/features/bathymetry/domain/bathymetry_grid.dart`, `package:submersion/features/dive_sites/domain/entities/dive_site.dart`, `package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart`, `package:submersion/features/dive_3d/presentation/scene_overlay.dart`):

```dart
  group('buildContourLayers', () {
    BathymetryGrid gridOf(List<List<double?>> rowsSouthToNorth) {
      final rows = rowsSouthToNorth.length;
      final cols = rowsSouthToNorth.first.length;
      return BathymetryGrid(
        originLat: 0,
        originLon: 0,
        // ~0.0009 deg lat is ~100 m; longitude at lat 0 is ~111320 m/deg.
        cellSizeLatDeg: 100.0 / 110540.0,
        cellSizeLonDeg: 100.0 / 111320.0,
        rows: rows,
        cols: cols,
        depthsMeters: [for (final r in rowsSouthToNorth) ...r],
        sourceId: 'test',
        resolutionMeters: 100,
        fetchedAt: DateTime.utc(2026, 8, 15),
      );
    }

    const center = GeoPoint(0, 0);

    SpatialProjection projFor(BathymetryGrid grid) {
      // Mirror the geometry services: the grid box frames the scene.
      return SpatialProjection(
        minEast: 0,
        maxEast: 100.0 * (grid.cols - 1),
        minNorth: 0,
        maxNorth: 100.0 * (grid.rows - 1),
        maxDepth: grid.maxDepthMeters,
      );
    }

    test('produces overlay-gated layers and major labels', () {
      // 3x3 grid sloping south (5 m) to north (45 m). Auto levels for a
      // 45 m span: step 5, levels 5..45, major at 25. Every contour is a
      // horizontal east-west line, so each level yields ONE polyline.
      final grid = gridOf([
        [5.0, 5.0, 5.0],
        [25.0, 25.0, 25.0],
        [45.0, 45.0, 45.0],
      ]);
      final result = buildContourLayers(
        grid: grid,
        center: center,
        projection: projFor(grid),
        appearance: const SeascapeAppearance(),
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
      );
      // Auto levels 5..45 (step 5, major at 25). Level 5 yields NO line:
      // every corner is >= 5, so both cells are case 15 (all inside). The
      // other 8 levels each cross exactly one cell row: with inside = ">=",
      // level 25 crosses only the south cell (t = 1 at the shared edge) and
      // level 45 crosses the north cell at its top edge. 8 layers total:
      // 10,15,20,25,30,35,40,45.
      expect(result.layers, hasLength(8));
      expect(
        result.layers.every((l) => l.overlay == SceneOverlay.contours),
        isTrue,
      );
      // One labeled level (25 m major) with 5 anchor triplets.
      expect(result.labels, hasLength(1));
      expect(result.labels.single.text, '25 m');
      expect(result.labels.single.anchorsXyz.length, 15);
      // Anchors ride the contour's scene height: yOf(25) plus lifts.
      final y = projFor(grid).yOf(25);
      expect(result.labels.single.anchorsXyz[1], closeTo(y + 0.08, 1e-6));
    });

    test('ribbon width scales with thickness and majors are wider', () {
      final grid = gridOf([
        [5.0, 5.0, 5.0],
        [25.0, 25.0, 25.0],
        [45.0, 45.0, 45.0],
      ]);
      ContourBuildResult at(double thickness) => buildContourLayers(
        grid: grid,
        center: center,
        projection: projFor(grid),
        appearance: SeascapeAppearance(contourThickness: thickness),
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
      );
      double widthOf(SceneLayer layer) {
        // Ribbon vertices come in left/right pairs; the first pair's
        // separation is the full ribbon width in scene units.
        final p = layer.mesh.positions;
        final dx = p[3] - p[0], dz = p[5] - p[2];
        return math.sqrt(dx * dx + dz * dz);
      }

      final thin = at(1.0);
      final thick = at(2.0);
      expect(widthOf(thick.layers.first),
          closeTo(widthOf(thin.layers.first) * 2, 1e-6));
      // Rendered levels are 10,15,20,25,...: the 25 m major is index 3.
      expect(widthOf(thin.layers[3]), greaterThan(widthOf(thin.layers[0])));
    });

    test('custom level color overrides the ink', () {
      final grid = gridOf([
        [5.0, 5.0],
        [45.0, 45.0],
      ]);
      final result = buildContourLayers(
        grid: grid,
        center: center,
        projection: projFor(grid),
        appearance: const SeascapeAppearance(
          contourMode: SeascapeContourMode.custom,
          customLevels: [
            SeascapeContourLevel(depthMeters: 20.0, colorArgb: 0xFF10B981),
          ],
        ),
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
      );
      expect(result.layers, hasLength(1));
      // 0xFF10B981: r = 0x10/255, per-vertex float colors.
      expect(result.layers.single.mesh.colors[0], closeTo(0x10 / 255, 1e-4));
      // Custom levels are all labeled.
      expect(result.labels.single.text, '20 m');
    });

    test('empty result for a flat or too-shallow grid', () {
      final grid = gridOf([
        [1.0, 1.0],
        [1.2, 1.2],
      ]);
      final result = buildContourLayers(
        grid: grid,
        center: center,
        projection: projFor(grid),
        appearance: const SeascapeAppearance(),
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
      );
      expect(result.layers, isEmpty);
      expect(result.labels, isEmpty);
    });
  });
```

Add `import 'dart:math' as math;` to the test file.

- [ ] **Step 2: Run tests to verify the new group fails**

Run: `flutter test test/features/dive_3d/domain/spatial/contour_builder_test.dart`
Expected: compile FAIL (`buildContourLayers` undefined).

- [ ] **Step 3: Implement ribbons, anchors, and assembly**

Append to `contour_builder.dart` (new imports: `dart:typed_data`, `dart:ui`, `package:submersion/features/bathymetry/domain/bathymetry_grid.dart`, `package:submersion/features/dive_3d/domain/entities/mesh_data.dart`, `package:submersion/features/dive_3d/domain/scene_3d.dart`, `package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart`, `package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart`, `package:submersion/features/dive_3d/presentation/scene_overlay.dart`, `package:submersion/core/utils/geo_math.dart`, `package:submersion/features/dive_sites/domain/entities/dive_site.dart`):

```dart
/// Scene-Y lift above the terrain surface so contour ribbons never z-fight
/// the mesh they trace (scene ySpan is 6.0).
const double contourLiftSceneUnits = 0.03;
const double _labelExtraLift = 0.05;
const double _minorHalfWidth = 0.016;
const double _majorHalfWidth = 0.030;
const Color _contourInk = Color(0xFFF8FAFC);
const double _minorOpacity = 0.5;
const double _majorOpacity = 0.85;
const int _labelAnchorCount = 5;

/// A labeled contour: the display-unit text plus candidate anchor points
/// (flat xyz scene-space triplets). The chrome painter picks the candidate
/// nearest the camera each frame.
class ContourLabelSpec {
  final String text;
  final List<double> anchorsXyz;
  const ContourLabelSpec({required this.text, required this.anchorsXyz});
}

/// Everything the geometry services fold into a scene for contours.
class ContourBuildResult {
  final List<SceneLayer> layers;
  final List<ContourLabelSpec> labels;
  const ContourBuildResult({required this.layers, required this.labels});
  static const ContourBuildResult empty = ContourBuildResult(
    layers: [],
    labels: [],
  );
}

/// Builds the contour SceneLayers + label anchors for a real bathymetry
/// grid. Pure and sendable: safe inside compute() isolates.
ContourBuildResult buildContourLayers({
  required BathymetryGrid grid,
  required GeoPoint center,
  required SpatialProjection projection,
  required SeascapeAppearance appearance,
  required double displayUnitInMeters,
  required String depthSymbol,
}) {
  final levels = resolvedContourLevels(
    maxDepthMeters: grid.maxDepthMeters,
    displayUnitInMeters: displayUnitInMeters,
    depthSymbol: depthSymbol,
    appearance: appearance,
  );
  if (levels.isEmpty || grid.rows < 2 || grid.cols < 2) {
    return ContourBuildResult.empty;
  }

  final mLon = metersPerDegreeLongitude(center.latitude);
  double eastOf(int c) =>
      (grid.originLon + grid.cellSizeLonDeg * c - center.longitude) * mLon;
  double northOf(int r) =>
      (grid.originLat + grid.cellSizeLatDeg * r - center.latitude) *
      BathymetryTerrainBuilder.metersPerDegLat;

  final layers = <SceneLayer>[];
  final labels = <ContourLabelSpec>[];
  for (final level in levels) {
    final polylines = marchGrid(
      rows: grid.rows,
      cols: grid.cols,
      depthAt: grid.depthAt,
      eastOf: eastOf,
      northOf: northOf,
      levelMeters: level.depthMeters,
    );
    if (polylines.isEmpty) continue;

    final y = projection.yOf(level.depthMeters) + contourLiftSceneUnits;
    final sceneLines = <List<double>>[];
    for (final line in polylines) {
      final pts = line.pointsEastNorth;
      final xyz = List<double>.filled(pts.length ~/ 2 * 3, 0);
      for (var i = 0; i < pts.length ~/ 2; i++) {
        xyz[i * 3] = projection.xOf(pts[i * 2]);
        xyz[i * 3 + 1] = y;
        xyz[i * 3 + 2] = projection.zOf(pts[i * 2 + 1]);
      }
      sceneLines.add(xyz);
      layers.add(
        SceneLayer(
          _ribbonMesh(
            xyz,
            isMajor: level.isMajor,
            colorArgb: level.colorArgb,
            thicknessFactor: appearance.contourThickness,
          ),
          overlay: SceneOverlay.contours,
        ),
      );
    }

    if (level.isMajor) {
      // Anchor candidates ride the longest polyline of the level.
      sceneLines.sort((a, b) => b.length.compareTo(a.length));
      final longest = sceneLines.first;
      final vertexCount = longest.length ~/ 3;
      final anchors = <double>[];
      for (var k = 0; k < _labelAnchorCount; k++) {
        final vi = vertexCount <= 1
            ? 0
            : (k * (vertexCount - 1) / (_labelAnchorCount - 1)).round();
        anchors
          ..add(longest[vi * 3])
          ..add(longest[vi * 3 + 1] + _labelExtraLift)
          ..add(longest[vi * 3 + 2]);
      }
      labels.add(ContourLabelSpec(text: level.label, anchorsXyz: anchors));
    }
  }
  return ContourBuildResult(layers: layers, labels: labels);
}

/// A thin horizontal ribbon along a scene-space polyline (constant y), the
/// same perpendicular-extrusion pattern as SpatialPathBuilder.buildRibbon.
MeshData _ribbonMesh(
  List<double> xyz, {
  required bool isMajor,
  required int? colorArgb,
  required double thicknessFactor,
}) {
  final n = xyz.length ~/ 3;
  if (n < 2) {
    return MeshData(
      positions: Float32List(0),
      indices: Uint32List(0),
      colors: Float32List(0),
    );
  }
  final halfWidth =
      (isMajor ? _majorHalfWidth : _minorHalfWidth) * thicknessFactor;
  final color = colorArgb != null ? Color(colorArgb) : _contourInk;
  final opacity = colorArgb != null
      ? _majorOpacity
      : (isMajor ? _majorOpacity : _minorOpacity);

  final positions = Float32List(n * 6);
  final colors = Float32List(n * 6);
  for (var i = 0; i < n; i++) {
    final j = i < n - 1 ? i : i - 1;
    var tx = xyz[(j + 1) * 3] - xyz[j * 3];
    var tz = xyz[(j + 1) * 3 + 2] - xyz[j * 3 + 2];
    final len = math.sqrt(tx * tx + tz * tz);
    if (len > 1e-9) {
      tx /= len;
      tz /= len;
    }
    final px = -tz, pz = tx;
    final vi = i * 6;
    positions[vi] = xyz[i * 3] - px * halfWidth;
    positions[vi + 1] = xyz[i * 3 + 1];
    positions[vi + 2] = xyz[i * 3 + 2] - pz * halfWidth;
    positions[vi + 3] = xyz[i * 3] + px * halfWidth;
    positions[vi + 4] = xyz[i * 3 + 1];
    positions[vi + 5] = xyz[i * 3 + 2] + pz * halfWidth;
    for (var s = 0; s < 2; s++) {
      colors[vi + s * 3] = color.r;
      colors[vi + s * 3 + 1] = color.g;
      colors[vi + s * 3 + 2] = color.b;
    }
  }
  final indices = Uint32List((n - 1) * 6);
  var q = 0;
  for (var i = 0; i < n - 1; i++) {
    final a = i * 2, b = i * 2 + 1, c = i * 2 + 2, d = i * 2 + 3;
    indices[q++] = a;
    indices[q++] = b;
    indices[q++] = c;
    indices[q++] = b;
    indices[q++] = d;
    indices[q++] = c;
  }
  return MeshData(
    positions: positions,
    indices: indices,
    colors: colors,
    opacity: opacity,
  );
}
```

Note the anchor-lift expectation in the first test: `yOf(25) + contourLiftSceneUnits + _labelExtraLift = yOf(25) + 0.08`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_3d/domain/spatial/contour_builder_test.dart`
Expected: PASS. If the layer count differs, print the actual level list and recheck which levels cross the data range by hand before touching the table.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_3d/domain/spatial/contour_builder.dart test/features/dive_3d/domain/spatial/contour_builder_test.dart lib/features/dive_3d/presentation/scene_overlay.dart lib/features/dive_3d/presentation/pages/dive_3d_page.dart
git commit -m "feat(seascape): contour ribbon layers and label anchors"
```

### Task 6: Steep-wall highlight builder

**Files:**
- Create: `lib/features/dive_3d/domain/spatial/wall_highlight_builder.dart`
- Test: `test/features/dive_3d/domain/spatial/wall_highlight_builder_test.dart`

**Interfaces:**
- Consumes: `BathymetryGrid`, `SpatialProjection`, `MeshData`, `BathymetryTerrainBuilder.metersPerDegLat`, `metersPerDegreeLongitude` (geo_math), `GeoPoint`.
- Produces:
  - `double? wallCellSlopeDegrees({required double? sw, required double? se, required double? nw, required double? ne, required double eastSpacingMeters, required double northSpacingMeters})` (null when any corner is null or <= 0)
  - `MeshData? buildWallHighlightMesh({required BathymetryGrid grid, required GeoPoint center, required SpatialProjection projection, required double thresholdDeg})` (null when no cell qualifies)
  Task 9 consumes both.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_3d/domain/spatial/wall_highlight_builder_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/spatial/wall_highlight_builder.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  group('wallCellSlopeDegrees', () {
    test('north-sloping cell: 50 m drop over 100 m is 26.57 degrees', () {
      // dNorth = ((nw + ne) - (sw + se)) / 2 / 100 = ((60+60)-(10+10))/2/100
      //        = 0.5; dEast = 0. angle = atan(0.5) = 26.565 degrees.
      final angle = wallCellSlopeDegrees(
        sw: 10, se: 10, nw: 60, ne: 60,
        eastSpacingMeters: 100,
        northSpacingMeters: 100,
      );
      expect(angle, isNotNull);
      expect(angle!, closeTo(26.565, 0.01));
    });

    test('diagonal slope combines both axes', () {
      // dEast = ((se + ne) - (sw + nw)) / 2 / 100 = ((30+30)-(10+10))/2/100
      //       = 0.1; dNorth = 0. angle = atan(0.1) = 5.71 degrees.
      final angle = wallCellSlopeDegrees(
        sw: 10, se: 30, nw: 10, ne: 30,
        eastSpacingMeters: 100,
        northSpacingMeters: 100,
      );
      expect(angle!, closeTo(5.71, 0.01));
    });

    test('null or land corner disqualifies the cell', () {
      expect(
        wallCellSlopeDegrees(
          sw: null, se: 10, nw: 60, ne: 60,
          eastSpacingMeters: 100, northSpacingMeters: 100,
        ),
        isNull,
      );
      expect(
        wallCellSlopeDegrees(
          sw: -3, se: 10, nw: 60, ne: 60,
          eastSpacingMeters: 100, northSpacingMeters: 100,
        ),
        isNull,
      );
    });
  });

  group('buildWallHighlightMesh', () {
    BathymetryGrid gridOf(List<List<double?>> rowsSouthToNorth) {
      final rows = rowsSouthToNorth.length;
      final cols = rowsSouthToNorth.first.length;
      return BathymetryGrid(
        originLat: 0,
        originLon: 0,
        cellSizeLatDeg: 100.0 / 110540.0,
        cellSizeLonDeg: 100.0 / 111320.0,
        rows: rows,
        cols: cols,
        depthsMeters: [for (final r in rowsSouthToNorth) ...r],
        sourceId: 'test',
        resolutionMeters: 100,
        fetchedAt: DateTime.utc(2026, 8, 15),
      );
    }

    SpatialProjection projFor(BathymetryGrid grid) => SpatialProjection(
      minEast: 0,
      maxEast: 100.0 * (grid.cols - 1),
      minNorth: 0,
      maxNorth: 100.0 * (grid.rows - 1),
      maxDepth: grid.maxDepthMeters,
    );

    test('one steep cell yields one lifted quad, threshold gates it', () {
      // Left cell slopes 10 -> 60 north (26.57 deg); right cell is flat.
      final grid = gridOf([
        [10.0, 10.0, 10.0],
        [60.0, 60.0, 10.0],
      ]);
      final mesh = buildWallHighlightMesh(
        grid: grid,
        center: const GeoPoint(0, 0),
        projection: projFor(grid),
        thresholdDeg: 22,
      );
      expect(mesh, isNotNull);
      // Right cell: dEast and dNorth both 25/100 -> atan(0.3536) = 19.47
      // degrees, under 22: only the LEFT cell qualifies. 4 vertices, 6
      // indices, translucent red.
      expect(mesh!.vertexCount, 4);
      expect(mesh.indices, hasLength(6));
      expect(mesh.opacity, closeTo(0.45, 1e-9));
      // Vertices ride the terrain surface plus a small lift: the sw corner
      // sits at yOf(10) + 0.015.
      final proj = projFor(grid);
      expect(mesh.positions[1], closeTo(proj.yOf(10) + 0.015, 1e-5));

      expect(
        buildWallHighlightMesh(
          grid: grid,
          center: const GeoPoint(0, 0),
          projection: proj,
          thresholdDeg: 30,
        ),
        isNull,
      );
    });
  });
}
```

Before trusting the "right cell" comment, recompute by hand: right cell corners sw=10, se=10, nw=60, ne=10. dEast = ((10+10)-(10+60))/2/100 = -0.25; dNorth = ((60+10)-(10+10))/2/100 = 0.25; magnitude = sqrt(0.0625+0.0625) = 0.3536; atan = 19.47 degrees. Correct as written.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/spatial/wall_highlight_builder_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement**

Create `lib/features/dive_3d/domain/spatial/wall_highlight_builder.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

const Color _wallColor = Color(0xFFEF4444);
const double _wallOpacity = 0.45;
const double _wallLiftSceneUnits = 0.015;

/// Mean slope of one grid cell from its corner depths, in degrees, or null
/// when any corner is nodata or land. Grid resolution SMOOTHS real walls:
/// a sheer wall inside one ~67 m cell reads as a modest slope, which is
/// why the default threshold is 22 degrees, not 45.
double? wallCellSlopeDegrees({
  required double? sw,
  required double? se,
  required double? nw,
  required double? ne,
  required double eastSpacingMeters,
  required double northSpacingMeters,
}) {
  if (sw == null || se == null || nw == null || ne == null) return null;
  if (sw <= 0 || se <= 0 || nw <= 0 || ne <= 0) return null;
  if (eastSpacingMeters <= 0 || northSpacingMeters <= 0) return null;
  final dEast = ((se + ne) - (sw + nw)) / 2 / eastSpacingMeters;
  final dNorth = ((nw + ne) - (sw + se)) / 2 / northSpacingMeters;
  return math.atan(math.sqrt(dEast * dEast + dNorth * dNorth)) *
      180 /
      math.pi;
}

/// A translucent red quilt over every cell steeper than [thresholdDeg],
/// riding the terrain surface lifted a hair so it never z-fights the mesh.
/// Returns null when nothing qualifies (no empty layers in the scene).
MeshData? buildWallHighlightMesh({
  required BathymetryGrid grid,
  required GeoPoint center,
  required SpatialProjection projection,
  required double thresholdDeg,
}) {
  if (grid.rows < 2 || grid.cols < 2) return null;
  final mLon = metersPerDegreeLongitude(center.latitude);
  final eastSpacing = grid.cellSizeLonDeg * mLon;
  final northSpacing =
      grid.cellSizeLatDeg * BathymetryTerrainBuilder.metersPerDegLat;

  double eastOf(int c) =>
      (grid.originLon + grid.cellSizeLonDeg * c - center.longitude) * mLon;
  double northOf(int r) =>
      (grid.originLat + grid.cellSizeLatDeg * r - center.latitude) *
      BathymetryTerrainBuilder.metersPerDegLat;

  final positions = <double>[];
  final indices = <int>[];
  for (var r = 0; r < grid.rows - 1; r++) {
    for (var c = 0; c < grid.cols - 1; c++) {
      final sw = grid.depthAt(r, c);
      final se = grid.depthAt(r, c + 1);
      final nw = grid.depthAt(r + 1, c);
      final ne = grid.depthAt(r + 1, c + 1);
      final slope = wallCellSlopeDegrees(
        sw: sw,
        se: se,
        nw: nw,
        ne: ne,
        eastSpacingMeters: eastSpacing,
        northSpacingMeters: northSpacing,
      );
      if (slope == null || slope < thresholdDeg) continue;

      final base = positions.length ~/ 3;
      void vertex(double east, double north, double depth) {
        positions
          ..add(projection.xOf(east))
          ..add(projection.yOf(depth) + _wallLiftSceneUnits)
          ..add(projection.zOf(north));
      }

      vertex(eastOf(c), northOf(r), sw!);
      vertex(eastOf(c + 1), northOf(r), se!);
      vertex(eastOf(c), northOf(r + 1), nw!);
      vertex(eastOf(c + 1), northOf(r + 1), ne!);
      indices.addAll([base, base + 1, base + 2, base + 1, base + 3, base + 2]);
    }
  }
  if (indices.isEmpty) return null;

  final colors = Float32List(positions.length);
  for (var i = 0; i < positions.length ~/ 3; i++) {
    colors[i * 3] = _wallColor.r;
    colors[i * 3 + 1] = _wallColor.g;
    colors[i * 3 + 2] = _wallColor.b;
  }
  return MeshData(
    positions: Float32List.fromList(positions),
    indices: Uint32List.fromList(indices),
    colors: colors,
    opacity: _wallOpacity,
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_3d/domain/spatial/wall_highlight_builder_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_3d/domain/spatial/wall_highlight_builder.dart test/features/dive_3d/domain/spatial/wall_highlight_builder_test.dart
git commit -m "feat(seascape): steep-wall highlight mesh builder"
```

---

### Task 7: Terrain ramp options (custom range + banded gradient)

**Files:**
- Modify: `lib/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart`
- Test: `test/features/dive_3d/domain/spatial/bathymetry_terrain_builder_test.dart` (extend)

**Interfaces:**
- Consumes: existing `BathymetryTerrainBuilder.build`.
- Produces:
  - `static Color depthColor(double t, {bool banded = false})` (public; `t` is 0..1 along the ramp; banded quantizes into 10 segments sampled at segment centers)
  - public `static const Color shallowColor / deepColor / landColor` (renamed from `_shallow` / `_deep` / `_land`; update all in-file uses)
  - `build(...)` gains optional named `double? rampMaxDepthMeters` and `bool rampBanded = false`. Ramp normalization becomes `t = depth / max(rampMaxDepthMeters ?? projection.maxDepth, 1.0)` clamped to 0..1 (deeper cells clamp to the deepest color).
  Tasks 9 and 11 consume `depthColor`, `shallowColor`, `deepColor`, `landColor`, and the new `build` params.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/dive_3d/domain/spatial/bathymetry_terrain_builder_test.dart` (read its existing helpers first and reuse its grid construction; add `import 'dart:ui' show Color;` if absent):

```dart
  group('depth ramp options', () {
    test('depthColor banded quantizes into 10 segment centers', () {
      // t = 0.0 and t = 0.09 both land in segment 0 (center 0.05);
      // t = 0.95 lands in segment 9 (center 0.95).
      expect(
        BathymetryTerrainBuilder.depthColor(0.0, banded: true),
        BathymetryTerrainBuilder.depthColor(0.09, banded: true),
      );
      expect(
        BathymetryTerrainBuilder.depthColor(0.0, banded: true),
        isNot(BathymetryTerrainBuilder.depthColor(0.11, banded: true)),
      );
      expect(
        BathymetryTerrainBuilder.depthColor(1.0, banded: true),
        BathymetryTerrainBuilder.depthColor(0.95, banded: true),
      );
      // Continuous stays continuous.
      expect(
        BathymetryTerrainBuilder.depthColor(0.0),
        isNot(BathymetryTerrainBuilder.depthColor(0.09)),
      );
    });

    test('rampMaxDepthMeters clamps deeper terrain to the deepest color', () {
      // One shallow (10 m) and one deep (80 m) vertex; ramp max 20 m: the
      // 80 m vertex must carry exactly the deep color, and the 10 m vertex
      // the t = 0.5 color.
      final grid = BathymetryGrid(
        originLat: 0,
        originLon: 0,
        cellSizeLatDeg: 100.0 / 110540.0,
        cellSizeLonDeg: 100.0 / 111320.0,
        rows: 2,
        cols: 2,
        depthsMeters: const [10, 80, 10, 80],
        sourceId: 'test',
        resolutionMeters: 100,
        fetchedAt: DateTime.utc(2026, 8, 15),
      );
      final proj = SpatialProjection(
        minEast: 0, maxEast: 100, minNorth: 0, maxNorth: 100, maxDepth: 80,
      );
      final terrain = BathymetryTerrainBuilder.build(
        grid: grid,
        center: const GeoPoint(0, 0),
        projection: proj,
        rampMaxDepthMeters: 20,
      );
      final deep = BathymetryTerrainBuilder.deepColor;
      // Vertex 1 (row 0, col 1) is the 80 m cell.
      expect(terrain.terrain.colors[3], closeTo(deep.r, 1e-4));
      expect(terrain.terrain.colors[4], closeTo(deep.g, 1e-4));
      final half = BathymetryTerrainBuilder.depthColor(0.5);
      expect(terrain.terrain.colors[0], closeTo(half.r, 1e-4));
    });

    test('default build output is unchanged (regression guard)', () {
      // Build with and without the new params left at defaults and compare
      // color buffers byte for byte.
      final grid = BathymetryGrid(
        originLat: 0,
        originLon: 0,
        cellSizeLatDeg: 100.0 / 110540.0,
        cellSizeLonDeg: 100.0 / 111320.0,
        rows: 2,
        cols: 2,
        depthsMeters: const [10, 40, 20, 30],
        sourceId: 'test',
        resolutionMeters: 100,
        fetchedAt: DateTime.utc(2026, 8, 15),
      );
      final proj = SpatialProjection(
        minEast: 0, maxEast: 100, minNorth: 0, maxNorth: 100, maxDepth: 40,
      );
      final a = BathymetryTerrainBuilder.build(
        grid: grid, center: const GeoPoint(0, 0), projection: proj,
      );
      final b = BathymetryTerrainBuilder.build(
        grid: grid,
        center: const GeoPoint(0, 0),
        projection: proj,
        rampBanded: false,
      );
      expect(a.terrain.colors, b.terrain.colors);
    });
  });
```

- [ ] **Step 2: Run tests to verify the new group fails**

Run: `flutter test test/features/dive_3d/domain/spatial/bathymetry_terrain_builder_test.dart`
Expected: compile FAIL (`depthColor`, `deepColor` undefined).

- [ ] **Step 3: Implement**

In `bathymetry_terrain_builder.dart`:

1. Rename the color constants public and add `depthColor`:
```dart
  static const Color shallowColor = Color(0xFF2DD4BF);
  static const Color deepColor = Color(0xFF1E3A8A);
  static const Color landColor = Color(0xFFC2A878);

  /// The ramp color at normalized depth [t] (0 = shallow, 1 = ramp max).
  /// Banded mode quantizes into 10 equal segments sampled at their centers
  /// so the seascape reads like a stepped nautical chart tint.
  static Color depthColor(double t, {bool banded = false}) {
    final tc = t.clamp(0.0, 1.0);
    final tt = banded ? (((tc * 10).floor().clamp(0, 9)) + 0.5) / 10 : tc;
    return Color.lerp(shallowColor, deepColor, tt)!;
  }
```
Update all in-file uses of `_shallow` / `_deep` / `_land` (the `_water` plane color stays private).

2. Extend `build`:
```dart
  static SpatialTerrain build({
    required BathymetryGrid grid,
    required GeoPoint center,
    required SpatialProjection projection,
    double? rampMaxDepthMeters,
    bool rampBanded = false,
  }) {
```
and replace the color branch (`:79-84`) with:
```dart
        final Color color;
        if (raw == null || raw <= 0) {
          color = landColor;
        } else {
          final ramp = math.max(rampMaxDepthMeters ?? maxDepth, 1.0);
          color = depthColor(depth / ramp, banded: rampBanded);
        }
```
(`maxDepth` here is the existing local `math.max(projection.maxDepth, 1.0)`.)

- [ ] **Step 4: Run the suite**

Run: `flutter test test/features/dive_3d/domain/spatial/`
Expected: PASS (contour, wall, terrain, axes, and both geometry-service suites).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart test/features/dive_3d/domain/spatial/bathymetry_terrain_builder_test.dart
git commit -m "feat(seascape): terrain ramp range and banded gradient"
```

### Task 8: SceneOverlay values + overlay menu + l10n batch 1

**Files:**
- Modify: `lib/features/dive_3d/presentation/scene_overlay.dart`
- Modify: `lib/features/dive_3d/presentation/pages/dive_3d_page.dart:302-328`
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/dive_3d/presentation/pages/dive_3d_page_test.dart` (extend)

**Interfaces:**
- Consumes: nothing new.
- Produces: `SceneOverlay.contours`, `SceneOverlay.water`, `SceneOverlay.steepWalls`; l10n keys `dive3d_seascape_overlay_contours`, `dive3d_seascape_overlay_walls`, `dive3d_overlay_water`. Tasks 5, 9, 13, 14 consume the enum values; 13 and 14 the first two keys.

- [ ] **Step 1: Write the failing test**

Append to `dive_3d_page_test.dart` (inside `main`, using that file's existing page-pumping helper; read the file first to reuse its scaffolding exactly):

```dart
  testWidgets('overlay menu hides seascape-only overlays', (tester) async {
    // Pump the page with the existing helper, then open the layers menu.
    // (Reuse the same setup as the existing overlay-menu test in this file;
    // only the assertions below are new.)
    // ... open PopupMenuButton<SceneOverlay> via
    // await tester.tap(find.byIcon(Icons.layers)); await tester.pump();
    expect(find.text('Temperature layers'), findsOneWidget);
    expect(find.text('Contours'), findsNothing);
    expect(find.text('Steep walls'), findsNothing);
    expect(find.text('Water surface'), findsNothing);
  });
```

If `dive_3d_page_test.dart` has no test that opens the overlay menu, add this one modeled on the page's existing pump pattern (bounded pumps, settings override).

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/dive_3d/presentation/pages/dive_3d_page_test.dart`
Expected: FAIL (the enum values and keys do not exist yet, so the compile fails; that counts).

- [ ] **Step 3: Implement enum + menu + keys**

1. `scene_overlay.dart`:
```dart
/// Scene elements the diver can show or hide in the 3D view.
enum SceneOverlay {
  strata,
  ceiling,
  curtain,
  markers,
  paths,
  contours,
  water,
  steepWalls,
}
```

2. `dive_3d_page.dart`: the menu filter (`:308-309`) becomes:
```dart
            // Seascape-only overlays have no meaning in this analytical
            // view; keep them out of the menu.
            for (final overlay in SceneOverlay.values)
              if (!const {
                SceneOverlay.paths,
                SceneOverlay.contours,
                SceneOverlay.water,
                SceneOverlay.steepWalls,
              }.contains(overlay))
```
and the exhaustive switch (`:313-320`) gains:
```dart
                    SceneOverlay.contours =>
                      context.l10n.dive3d_seascape_overlay_contours,
                    SceneOverlay.water => context.l10n.dive3d_overlay_water,
                    SceneOverlay.steepWalls =>
                      context.l10n.dive3d_seascape_overlay_walls,
```

3. `app_en.arb` (next to `dive3d_seascape_overlay_paths` at `:13956`):
```json
  "dive3d_seascape_overlay_contours": "Contours",
  "@dive3d_seascape_overlay_contours": {},
  "dive3d_seascape_overlay_walls": "Steep walls",
  "@dive3d_seascape_overlay_walls": {},
  "dive3d_overlay_water": "Water surface",
  "@dive3d_overlay_water": {},
```
Translations for the other 10 arb files (place next to the same key; keep JSON valid):

| Locale | contours | walls | water |
| --- | --- | --- | --- |
| de | "Tiefenlinien" | "Steilwände" | "Wasseroberfläche" |
| es | "Isóbatas" | "Paredes verticales" | "Superficie del agua" |
| fr | "Isobathes" | "Tombants" | "Surface de l'eau" |
| it | "Isobate" | "Pareti ripide" | "Superficie dell'acqua" |
| nl | "Dieptelijnen" | "Steile wanden" | "Wateroppervlak" |
| pt | "Isóbatas" | "Paredes íngremes" | "Superfície da água" |
| hu | "Mélységvonalak" | "Meredek falak" | "Vízfelszín" |
| ar | "خطوط الأعماق" | "جدران شديدة الانحدار" | "سطح الماء" |
| he | "קווי עומק" | "קירות תלולים" | "פני המים" |
| zh | "等深线" | "陡壁" | "水面" |

4. From the PROJECT ROOT run `flutter gen-l10n`; commit the regenerated `app_localizations*.dart`.

- [ ] **Step 4: Run the page suite**

Run: `flutter test test/features/dive_3d/presentation/pages/dive_3d_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_3d/presentation/scene_overlay.dart lib/features/dive_3d/presentation/pages/dive_3d_page.dart lib/l10n/arb/
git commit -m "feat(seascape): contours, water, and steep-wall overlay values"
```

---

### Task 9: Geometry services + providers thread appearance through

**Files:**
- Modify: `lib/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart`
- Modify: `lib/features/dive_3d/domain/spatial/spatial_geometry_service.dart`
- Modify: `lib/features/dive_3d/application/site_seascape_providers.dart`
- Modify: `lib/features/dive_3d/application/spatial_providers.dart`
- Test: `test/features/dive_3d/domain/spatial/site_seascape_geometry_service_test.dart`, `test/features/dive_3d/domain/spatial/spatial_geometry_service_bathymetry_test.dart` (extend both)

**Interfaces:**
- Consumes: `buildContourLayers`, `ContourBuildResult`, `ContourLabelSpec`, `buildWallHighlightMesh`, `SeascapeAppearance`, terrain `rampMaxDepthMeters`/`rampBanded` params, `SceneOverlay.water`/`.steepWalls`.
- Produces (later tasks rely on these exact shapes):
  - `SiteSeascapeInput` gains optional named `SeascapeAppearance appearance = const SeascapeAppearance()`, `double displayUnitInMeters = 1.0`, `String depthSymbol = 'm'` (existing call sites keep compiling).
  - `SiteSeascapeGeometryService.buildWithLabels(SiteSeascapeInput) -> ({Scene3d scene, List<ContourLabelSpec> contourLabels})`; existing `build` becomes `buildWithLabels(input).scene`.
  - `SpatialGeometryService.buildWithFrame(...)` gains the same three optional named params and its return record gains `List<ContourLabelSpec> contourLabels`.
  - `SiteSeascapeReady` gains `final List<ContourLabelSpec> contourLabels;` (optional ctor param, default `const []`). `SpatialSceneResult` gains the same.
  - Both providers watch `settingsProvider.select(...)` for `(seascapeAppearance, depthUnit)` and pass `displayUnitInMeters = depthUnit == DepthUnit.feet ? 0.3048 : 1.0`, `depthSymbol = depthUnit.symbol`.

**Layer order** (painter paints layers in list order; lifted overlays paint after the terrain they ride):
- Site scene: terrain, contour layers, wall layer, per-dive paths/pins, site pin, water (`overlay: SceneOverlay.water`).
- Spatial scene: terrain, contour layers, wall layer, ribbon, entry pin, exit pin, water (`overlay: SceneOverlay.water`).
- Contours/walls are built ONLY when the terrain is real bathymetry (spatial: `useBathymetry`; site: always real).

- [ ] **Step 1: Write the failing service tests**

Append to `site_seascape_geometry_service_test.dart` (reuse its existing grid/input helpers; read the file first):

```dart
  test('real terrain gains contour and water-gated layers plus labels', () {
    // Grid sloping 5 -> 45 m: auto levels 5..45, 8 rendered lines (see
    // contour_builder_test), major 25 labeled.
    final grid = BathymetryGrid(
      originLat: 0,
      originLon: 0,
      cellSizeLatDeg: 100.0 / 110540.0,
      cellSizeLonDeg: 100.0 / 111320.0,
      rows: 3,
      cols: 3,
      depthsMeters: const [5, 5, 5, 25, 25, 25, 45, 45, 45],
      sourceId: 'test',
      resolutionMeters: 100,
      fetchedAt: DateTime.utc(2026, 8, 15),
    );
    final result = const SiteSeascapeGeometryService().buildWithLabels(
      SiteSeascapeInput(
        grid: grid,
        center: const GeoPoint(0, 0),
        siteName: 'Test',
        divePaths: const [],
        nearbySites: const [],
      ),
    );
    final overlays = result.scene.layers.map((l) => l.overlay).toList();
    expect(overlays.where((o) => o == SceneOverlay.contours), hasLength(8));
    expect(overlays.last, SceneOverlay.water);
    expect(result.contourLabels.single.text, '25 m');
    // 5 -> 45 over 200 m north is atan(40/200 per-cell 20/100 = 0.2)
    // = 11.3 degrees: below the default 22, so no wall layer.
    expect(overlays.contains(SceneOverlay.steepWalls), isFalse);
  });

  test('steep terrain gains a wall layer once the threshold allows', () {
    final grid = BathymetryGrid(
      originLat: 0,
      originLon: 0,
      cellSizeLatDeg: 100.0 / 110540.0,
      cellSizeLonDeg: 100.0 / 111320.0,
      rows: 2,
      cols: 2,
      depthsMeters: const [10, 10, 60, 60],
      sourceId: 'test',
      resolutionMeters: 100,
      fetchedAt: DateTime.utc(2026, 8, 15),
    );
    final result = const SiteSeascapeGeometryService().buildWithLabels(
      SiteSeascapeInput(
        grid: grid,
        center: const GeoPoint(0, 0),
        siteName: 'Wall',
        divePaths: const [],
        nearbySites: const [],
        appearance: const SeascapeAppearance(wallAngleDeg: 20),
      ),
    );
    expect(
      result.scene.layers.where((l) => l.overlay == SceneOverlay.steepWalls),
      hasLength(1),
    );
  });

  test('build() still returns the bare scene (compat)', () {
    // The existing tests in this file keep passing unchanged; this guard
    // just pins the delegation.
    // (No new assertions needed beyond the suite passing.)
  });
```

Append to `spatial_geometry_service_bathymetry_test.dart`. That file already constructs a `ReckonedPath` and a `BathymetryGrid` for its existing bathymetry tests; read it first and reuse its path fixture (call it `path` below) plus the 3x3 sloping grid vector from the site test above (call it `grid`, center `GeoPoint(0, 0)`):

```dart
  test('bathymetry scene gains contours and labels', () {
    final built = const SpatialGeometryService().buildWithFrame(
      path,
      grid: grid,
      gridCenter: const GeoPoint(0, 0),
    );
    final overlays = built.scene.layers.map((l) => l.overlay).toList();
    expect(overlays.where((o) => o == SceneOverlay.contours), isNotEmpty);
    expect(overlays.last, SceneOverlay.water);
    expect(built.contourLabels, isNotEmpty);
  });

  test('synthesized fallback gets no contours or walls, water stays gated',
      () {
    final built = const SpatialGeometryService().buildWithFrame(path);
    final overlays = built.scene.layers.map((l) => l.overlay).toList();
    expect(overlays.contains(SceneOverlay.contours), isFalse);
    expect(overlays.contains(SceneOverlay.steepWalls), isFalse);
    expect(overlays.last, SceneOverlay.water);
    expect(built.contourLabels, isEmpty);
  });
```

- [ ] **Step 2: Run to verify failures**

Run: `flutter test test/features/dive_3d/domain/spatial/site_seascape_geometry_service_test.dart test/features/dive_3d/domain/spatial/spatial_geometry_service_bathymetry_test.dart`
Expected: compile FAIL (`buildWithLabels`, `appearance` param undefined).

- [ ] **Step 3: Implement the services**

`site_seascape_geometry_service.dart`:
1. `SiteSeascapeInput` gains the three fields (constructor optional named, defaults as in Interfaces).
2. Replace `build` with:
```dart
  Scene3d build(SiteSeascapeInput input) => buildWithLabels(input).scene;

  ({Scene3d scene, List<ContourLabelSpec> contourLabels}) buildWithLabels(
    SiteSeascapeInput input,
  ) {
```
3. Inside, after the terrain build, pass the ramp options:
```dart
    final terrain = BathymetryTerrainBuilder.build(
      grid: input.grid,
      center: input.center,
      projection: proj,
      rampMaxDepthMeters: input.appearance.rampMaxDepthMeters,
      rampBanded: input.appearance.rampBanded,
    );

    final contours = buildContourLayers(
      grid: input.grid,
      center: input.center,
      projection: proj,
      appearance: input.appearance,
      displayUnitInMeters: input.displayUnitInMeters,
      depthSymbol: input.depthSymbol,
    );
    final wallMesh = buildWallHighlightMesh(
      grid: input.grid,
      center: input.center,
      projection: proj,
      thresholdDeg: input.appearance.wallAngleDeg,
    );

    final layers = <SceneLayer>[SceneLayer(terrain.terrain)];
    layers.addAll(contours.layers);
    if (wallMesh != null) {
      layers.add(SceneLayer(wallMesh, overlay: SceneOverlay.steepWalls));
    }
```
4. The water layer becomes `SceneLayer(terrain.water, overlay: SceneOverlay.water)`.
5. Return `(scene: Scene3d(...), contourLabels: contours.labels)`.

`spatial_geometry_service.dart`: mirror the same changes inside `buildWithFrame` under `useBathymetry` (synthesized branch adds NO contours/walls and passes no ramp options; ramp options only apply to `BathymetryTerrainBuilder.build`). Water layer: `SceneLayer(terrain.water, overlay: SceneOverlay.water)` in BOTH branches. `build` and `buildWithFrame` gain the three optional named params; the empty-path early return adds `contourLabels: const <ContourLabelSpec>[]` to its record.

- [ ] **Step 4: Wire the providers**

`site_seascape_providers.dart`:
1. `SiteSeascapeReady` gains `final List<ContourLabelSpec> contourLabels;` with ctor default `const []`.
2. In the provider body, before building the input:
```dart
  final appearance = ref.watch(
    settingsProvider.select((s) => s.seascapeAppearance),
  );
  final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
```
3. `SiteSeascapeInput(..., appearance: appearance, displayUnitInMeters: depthUnit == DepthUnit.feet ? 0.3048 : 1.0, depthSymbol: depthUnit.symbol)`.
4. Replace the build call:
```dart
  final built = grid.rows * grid.cols > _isolateCellThreshold
      ? await compute(_buildScene, input)
      : const SiteSeascapeGeometryService().buildWithLabels(input);
```
with `_buildScene` retyped:
```dart
({Scene3d scene, List<ContourLabelSpec> contourLabels}) _buildScene(
  SiteSeascapeInput input,
) => const SiteSeascapeGeometryService().buildWithLabels(input);
```
5. `SiteSeascapeReady(scene: built.scene, contourLabels: built.contourLabels, ...)`.
Imports: `contour_builder.dart`, `seascape_appearance.dart`, `settings_providers.dart`, `package:submersion/core/constants/units.dart`.

`spatial_providers.dart`: same pattern. `SpatialSceneResult` gains `final List<ContourLabelSpec> contourLabels;` (ctor default `const []`); `_SpatialBuildInput` record gains `SeascapeAppearance appearance, double displayUnitInMeters, String depthSymbol`; `_buildSpatial` forwards them; the provider watches the same two selects and fills the record; the result carries `contourLabels: built.contourLabels`.

- [ ] **Step 5: Run the affected suites**

Run:
```bash
flutter test test/features/dive_3d/domain/spatial/ test/features/dive_3d/presentation/site_seascape_page_test.dart test/features/dive_3d/presentation/pages/spatial_site_page_test.dart
```
Expected: PASS. The page tests exercise the providers through their overrides and must stay green; if a page test now fails on a missing settings field, its `_TestSettingsNotifier` already defaults `AppSettings()`, which carries the new field, so no test change should be needed.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/dive_3d/domain/spatial/ lib/features/dive_3d/application/ test/features/dive_3d/domain/spatial/
git commit -m "feat(seascape): thread appearance into geometry and providers"
```

### Task 10: SceneProjector mirrorX + the chart camera pose

**Files:**
- Modify: `lib/features/dive_3d/presentation/renderer/scene_projector.dart`
- Modify: `lib/features/dive_3d/presentation/renderer/preview_painter.dart` (pass-through)
- Test: `test/features/dive_3d/presentation/renderer/scene_projector_chart_pose_test.dart` (new)

**Interfaces:**
- Consumes: existing `SceneProjector`, `compassNeedleAngle` (`tissue_chrome_painters.dart:175`).
- Produces: `SceneProjector({..., bool mirrorX = false})`; top-level `const double chartYawDegrees = 180.0;` and `const double chartPitchDegrees = 90.0;` in `scene_projector.dart`; `Dive3dScenePainter({..., bool mirrorX = false})`. Tasks 11, 13 consume all three.

**Why mirrorX exists (do not "simplify" it away):** with this projector's rotation order, a top-down view that is simultaneously north-up, east-right, AND viewed from above does not exist on yaw/pitch alone. yaw 0 / pitch +90 gives east-right but north-DOWN (a mirrored map); yaw 0 / pitch -90 gives the correct compass orientation but views the terrain from BELOW, inverting the painter's back-to-front sort (lifted contours would paint under the terrain). The chart pose is therefore yaw 180 / pitch +90 / mirrorX, which is from-above, north-up, east-right. The painter's flat shading already flips face normals toward the camera, so mirrored winding is harmless.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_3d/presentation/renderer/scene_projector_chart_pose_test.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';

void main() {
  const bounds = SceneBounds(
    durationSeconds: 1,
    maxDepthMeters: 30,
    sceneMinY: -SceneBounds.ySpan,
    sceneMaxY: 0.6,
    sceneMinZ: -3,
    sceneMaxZ: 3,
  );

  SceneProjector chartProjector() => SceneProjector(
    size: const Size(400, 400),
    bounds: bounds,
    yawDegrees: chartYawDegrees,
    pitchDegrees: chartPitchDegrees,
    mirrorX: true,
  );

  test('chart pose: east projects right, north projects up', () {
    final p = chartProjector();
    final o = p.project(5, 0, 0); // scene center-ish
    final east = p.project(6, 0, 0);
    final north = p.project(5, 0, 1);
    expect(east.dx, greaterThan(o.dx));
    expect((east.dy - o.dy).abs(), lessThan(1e-6));
    expect(north.dy, lessThan(o.dy)); // screen y grows downward
    expect((north.dx - o.dx).abs(), lessThan(1e-6));
  });

  test('chart pose: viewed from above (surface nearer than depth)', () {
    final p = chartProjector();
    expect(p.viewDepth(5, 0, 0), greaterThan(p.viewDepth(5, -4, 0)));
  });

  test('chart pose: compass needle points straight up', () {
    final angle = compassNeedleAngle(chartProjector());
    expect(angle, isNotNull);
    expect(angle!, closeTo(-math.pi / 2, 1e-6));
  });

  test('mirrorX defaults off and leaves the classic pose unchanged', () {
    final a = SceneProjector(size: const Size(400, 400), bounds: bounds);
    final b = SceneProjector(
      size: const Size(400, 400),
      bounds: bounds,
      mirrorX: false,
    );
    expect(a.project(3, -2, 1), b.project(3, -2, 1));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/dive_3d/presentation/renderer/scene_projector_chart_pose_test.dart`
Expected: compile FAIL (`mirrorX`, `chartYawDegrees` undefined).

- [ ] **Step 3: Implement**

`scene_projector.dart`:
```dart
/// The chart-mode camera pose: from above, north-up, east-right. This trio
/// is load-bearing: yaw/pitch alone cannot give all three at once (see the
/// chart-pose test), so chart mode always pairs these angles with
/// mirrorX: true.
const double chartYawDegrees = 180.0;
const double chartPitchDegrees = 90.0;
```
Add the field and param:
```dart
  final bool _mirror;

  SceneProjector({
    required Size size,
    required SceneBounds bounds,
    double yawDegrees = -32,
    double pitchDegrees = 22,
    double zoom = 1.0,
    bool mirrorX = false,
  }) : _mirror = mirrorX,
       ...
```
and in `_view`, mirror the x output:
```dart
    final rx = (cx * _cy + z * _sy) * (_mirror ? -1.0 : 1.0);
```
(The fit loop in the constructor already runs through `_view`, so centering keeps working; `_mirror` must be assigned BEFORE the fit loop runs, which the initializer-list assignment guarantees.)

`preview_painter.dart`: `Dive3dScenePainter` gains `final bool mirrorX;` (ctor default `false`), passes it to its `SceneProjector`, and includes it in `shouldRepaint`.

- [ ] **Step 4: Run renderer tests**

Run: `flutter test test/features/dive_3d/presentation/renderer/`
Expected: PASS (new test plus any existing renderer tests).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_3d/presentation/renderer/scene_projector.dart lib/features/dive_3d/presentation/renderer/preview_painter.dart test/features/dive_3d/presentation/renderer/scene_projector_chart_pose_test.dart
git commit -m "feat(seascape): mirrorX projector option and chart camera pose"
```

---

### Task 11: Contour labels in AxisChromePainter + viewport chart mode

**Files:**
- Modify: `lib/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart` (`AxisChromePainter`, `:187`)
- Modify: `lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart`
- Test: `test/features/dive_3d/presentation/renderer/contour_label_anchor_test.dart` (new), `test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart` (extend; the existing viewport test file lives under `test/features/dive_3d/` [locate with `grep -rln "Dive3dInteractiveViewport" test/`] and this plan's steps adapt to wherever it is)

**Interfaces:**
- Consumes: `ContourLabelSpec` (Task 5), `chartYawDegrees`/`chartPitchDegrees`/`mirrorX` (Task 10).
- Produces:
  - top-level `int bestContourAnchorIndex(SceneProjector p, List<double> anchorsXyz)` in `tissue_chrome_painters.dart` (returns the triplet index whose viewDepth is largest, i.e. nearest the camera)
  - `AxisChromePainter({..., List<ContourLabelSpec>? contourLabels, bool mirrorX = false})`
  - `Dive3dInteractiveViewport({..., bool chartMode = false, List<ContourLabelSpec>? contourLabels})`; in chart mode one-finger drag PANS instead of rotating, the camera is pinned to the chart pose, and double-tap resets to the chart pose.
  Tasks 13 and 14 consume the viewport params.

- [ ] **Step 1: Write the failing anchor test**

Create `test/features/dive_3d/presentation/renderer/contour_label_anchor_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';

void main() {
  test('bestContourAnchorIndex picks the camera-nearest candidate', () {
    const bounds = SceneBounds(durationSeconds: 1, maxDepthMeters: 30);
    // Default camera (yaw -32, pitch 22). Three candidates along z: the
    // one with the largest viewDepth must win; assert against viewDepth
    // itself so the test is camera-convention-proof.
    final p = SceneProjector(size: const Size(400, 300), bounds: bounds);
    final anchors = <double>[
      2, -1, -2, // triplet 0
      5, -1, 0, // triplet 1
      8, -1, 2, // triplet 2
    ];
    final best = bestContourAnchorIndex(p, anchors);
    final depths = [
      p.viewDepth(2, -1, -2),
      p.viewDepth(5, -1, 0),
      p.viewDepth(8, -1, 2),
    ];
    final maxDepth = depths.reduce((a, b) => a > b ? a : b);
    expect(depths[best], maxDepth);
  });
}
```

- [ ] **Step 2: Run to verify it fails, then implement the painter side**

Run: `flutter test test/features/dive_3d/presentation/renderer/contour_label_anchor_test.dart` (expected: compile FAIL).

In `tissue_chrome_painters.dart`:

1. Import `contour_builder.dart` (for `ContourLabelSpec`).
2. Top-level helper:
```dart
/// Index of the anchor triplet nearest the camera. The nearest candidate
/// sits on the visible front side of the terrain, so the label is never
/// stranded behind a ridge.
int bestContourAnchorIndex(SceneProjector p, List<double> anchorsXyz) {
  var best = 0;
  var bestDepth = double.negativeInfinity;
  for (var i = 0; i < anchorsXyz.length ~/ 3; i++) {
    final d = p.viewDepth(
      anchorsXyz[i * 3],
      anchorsXyz[i * 3 + 1],
      anchorsXyz[i * 3 + 2],
    );
    if (d > bestDepth) {
      bestDepth = d;
      best = i;
    }
  }
  return best;
}
```
3. `AxisChromePainter` gains fields `final List<ContourLabelSpec>? contourLabels;` and `final bool mirrorX;` (ctor: `this.contourLabels`, `this.mirrorX = false`), passes `mirrorX` to its `SceneProjector`, and in `paint` after `paintAxisLabels`:
```dart
    _paintContourLabels(canvas, size, p);
```
```dart
  void _paintContourLabels(Canvas canvas, Size size, SceneProjector p) {
    final specs = contourLabels;
    if (specs == null || specs.isEmpty) return;
    for (final spec in specs) {
      if (spec.anchorsXyz.length < 3) continue;
      final i = bestContourAnchorIndex(p, spec.anchorsXyz);
      final at = p.project(
        spec.anchorsXyz[i * 3],
        spec.anchorsXyz[i * 3 + 1],
        spec.anchorsXyz[i * 3 + 2],
      );
      // A label whose every candidate is off-canvas skips this frame.
      if (at.dx < -12 ||
          at.dy < -12 ||
          at.dx > size.width + 12 ||
          at.dy > size.height + 12) {
        continue;
      }
      final tp = TextPainter(
        text: TextSpan(
          text: spec.text,
          style: TextStyle(
            color: style.label,
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: textDirection,
      )..layout();
      final rect = Rect.fromCenter(
        center: at,
        width: tp.width + 8,
        height: tp.height + 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()..color = style.markerOutline.withValues(alpha: 0.6),
      );
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }
  }
```
4. `shouldRepaint` adds `|| !identical(old.contourLabels, contourLabels) || old.mirrorX != mirrorX`.

- [ ] **Step 3: Viewport chart mode + passthrough**

In `dive_3d_interactive_viewport.dart`:

1. New widget fields (ctor optional named): `final bool chartMode;` (default `false`), `final List<ContourLabelSpec>? contourLabels;`. Import `contour_builder.dart` and use `chartYawDegrees`/`chartPitchDegrees` from `scene_projector.dart`.
2. In the state:
```dart
  void _applyPose() {
    if (widget.chartMode) {
      _yaw = chartYawDegrees;
      _pitch = chartPitchDegrees;
    } else {
      _yaw = _initialYaw;
      _pitch = _initialPitch;
    }
    _zoom = 1.0;
    _pan = Offset.zero;
  }

  @override
  void initState() {
    super.initState();
    _applyPose();
  }

  @override
  void didUpdateWidget(Dive3dInteractiveViewport old) {
    super.didUpdateWidget(old);
    if (old.chartMode != widget.chartMode) {
      setState(_applyPose);
      _refreshHoverAfterCameraChange();
    }
  }
```
(The field initializers `_yaw = _initialYaw` etc. stay; `_applyPose` overwrites them.)
3. `_onPanUpdate` branches:
```dart
  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      if (widget.chartMode) {
        // Chart mode is a locked plan view: one-finger drag pans the map.
        _pan += details.delta;
      } else {
        _yaw += details.delta.dx * 0.4;
        _pitch = (_pitch + details.delta.dy * 0.4).clamp(-80.0, 80.0);
      }
    });
    _refreshHoverAfterCameraChange();
  }
```
4. `_resetCamera` becomes `setState(_applyPose);` followed by the existing hover refresh.
5. `_projectorFor` adds `mirrorX: widget.chartMode`. Pass `mirrorX: widget.chartMode` to `Dive3dScenePainter`, `AxisChromePainter`, and `_ScrubCursorPainter` (add the field to `_ScrubCursorPainter` and its `SceneProjector`; include in its `shouldRepaint`). Pass `contourLabels: widget.contourLabels` to `AxisChromePainter`.

- [ ] **Step 4: Write the failing viewport test and run everything**

Locate the viewport widget test file with `grep -rln "Dive3dInteractiveViewport(" test/` and add:

```dart
  testWidgets('chart mode pins the chart pose and pans instead of rotating',
      (tester) async {
    // Build the viewport with a minimal one-layer scene (reuse this file's
    // existing scene fixture) and chartMode: true.
    // 1) The scene painter must carry the chart pose:
    Dive3dScenePainter scenePainter() => tester
        .widget<CustomPaint>(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is Dive3dScenePainter,
          ),
        )
        .painter! as Dive3dScenePainter;
    expect(scenePainter().yawDegrees, chartYawDegrees);
    expect(scenePainter().pitchDegrees, chartPitchDegrees);
    expect(scenePainter().mirrorX, isTrue);
    // 2) A drag must NOT change yaw/pitch (it pans).
    await tester.drag(
      find.byType(Dive3dInteractiveViewport),
      const Offset(60, 40),
    );
    await tester.pump();
    expect(scenePainter().yawDegrees, chartYawDegrees);
    expect(scenePainter().pitchDegrees, chartPitchDegrees);
  });
```

Run: `flutter test test/features/dive_3d/`
Expected: PASS across the whole dive_3d suite (renderer, domain, pages, widgets).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart test/features/dive_3d/
git commit -m "feat(seascape): contour labels in chrome and chart-mode camera"
```

### Task 12: Depth legend widget

**Files:**
- Create: `lib/features/dive_3d/presentation/widgets/seascape_depth_legend.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (one key)
- Test: `test/features/dive_3d/presentation/widgets/seascape_depth_legend_test.dart`

**Interfaces:**
- Consumes: `BathymetryTerrainBuilder.depthColor/shallowColor/deepColor/landColor` (Task 7), `resolvedContourLevels` (Task 3), `SeascapeAppearance`.
- Produces: `SeascapeDepthLegend({required double maxDepthMeters, required bool hasLand, required SeascapeAppearance appearance, required double displayUnitInMeters, required String depthSymbol})` with root `key: ValueKey('seascapeDepthLegend')`; l10n key `dive3d_seascape_legend_land`. Tasks 14 and 15 consume the widget.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_3d/presentation/widgets/seascape_depth_legend_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/seascape_depth_legend.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget host(SeascapeDepthLegend legend) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: legend),
);

void main() {
  testWidgets('shows the ramp ends in display units', (tester) async {
    await tester.pumpWidget(host(const SeascapeDepthLegend(
      maxDepthMeters: 40,
      hasLand: false,
      appearance: SeascapeAppearance(),
      displayUnitInMeters: 1.0,
      depthSymbol: 'm',
    )));
    expect(find.text('0 m'), findsOneWidget);
    expect(find.text('40 m'), findsOneWidget);
    expect(find.text('Land'), findsNothing);
  });

  testWidgets('clamped custom range shows a plus cap', (tester) async {
    await tester.pumpWidget(host(const SeascapeDepthLegend(
      maxDepthMeters: 80,
      hasLand: true,
      appearance: SeascapeAppearance(rampMaxDepthMeters: 20),
      displayUnitInMeters: 1.0,
      depthSymbol: 'm',
    )));
    expect(find.text('20+ m'), findsOneWidget);
    expect(find.text('Land'), findsOneWidget);
  });

  testWidgets('banded mode renders 10 discrete swatches', (tester) async {
    await tester.pumpWidget(host(const SeascapeDepthLegend(
      maxDepthMeters: 40,
      hasLand: false,
      appearance: SeascapeAppearance(rampBanded: true),
      displayUnitInMeters: 1.0,
      depthSymbol: 'm',
    )));
    expect(
      find.byKey(const ValueKey('seascapeLegendBandedBar')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('seascapeLegendBandedBar')),
        matching: find.byType(ColoredBox),
      ),
      findsNWidgets(10),
    );
  });

  testWidgets('feet diver reads feet', (tester) async {
    await tester.pumpWidget(host(const SeascapeDepthLegend(
      maxDepthMeters: 30.48,
      hasLand: false,
      appearance: SeascapeAppearance(),
      displayUnitInMeters: 0.3048,
      depthSymbol: 'ft',
    )));
    expect(find.text('100 ft'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/dive_3d/presentation/widgets/seascape_depth_legend_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement**

Add the l10n key to all 11 arb files (en shown; translations: de "Land", es "Tierra", fr "Terre", it "Terra", nl "Land", pt "Terra", hu "Szárazföld", ar "يابسة", he "יבשה", zh "陆地"):
```json
  "dive3d_seascape_legend_land": "Land",
  "@dive3d_seascape_legend_land": {},
```
Run `flutter gen-l10n` from the project root.

Create `seascape_depth_legend.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact depth legend for the seascape views: the terrain color ramp
/// (continuous or banded, honoring a custom ramp range with a "+" cap when
/// deeper terrain clamps) plus a land swatch when the grid has any.
class SeascapeDepthLegend extends StatelessWidget {
  final double maxDepthMeters;
  final bool hasLand;
  final SeascapeAppearance appearance;
  final double displayUnitInMeters;
  final String depthSymbol;

  const SeascapeDepthLegend({
    super.key,
    required this.maxDepthMeters,
    required this.hasLand,
    required this.appearance,
    required this.displayUnitInMeters,
    required this.depthSymbol,
  });

  static const double _barHeight = 96;
  static const double _barWidth = 12;

  String _depthText(double meters, {bool clamped = false}) {
    final v = meters / displayUnitInMeters;
    final text = v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
    return clamped ? '$text+ $depthSymbol' : '$text $depthSymbol';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rampMax = appearance.rampMaxDepthMeters ?? maxDepthMeters;
    final clamped = appearance.rampMaxDepthMeters != null &&
        appearance.rampMaxDepthMeters! < maxDepthMeters;
    final labelStyle = Theme.of(context).textTheme.labelSmall;

    final bar = appearance.rampBanded
        ? Column(
            key: const ValueKey('seascapeLegendBandedBar'),
            children: [
              for (var i = 0; i < 10; i++)
                Expanded(
                  child: ColoredBox(
                    color: BathymetryTerrainBuilder.depthColor(
                      (i + 0.5) / 10,
                      banded: true,
                    ),
                    child: const SizedBox(width: _barWidth),
                  ),
                ),
            ],
          )
        : const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  BathymetryTerrainBuilder.shallowColor,
                  BathymetryTerrainBuilder.deepColor,
                ],
              ),
            ),
            child: SizedBox(width: _barWidth, height: _barHeight),
          );

    return Container(
      key: const ValueKey('seascapeDepthLegend'),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: SizedBox(
                  width: _barWidth,
                  height: _barHeight,
                  child: bar,
                ),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_depthText(0), style: labelStyle),
                  Text(
                    _depthText(rampMax, clamped: clamped),
                    style: labelStyle,
                  ),
                ],
              ),
            ],
          ),
          if (hasLand) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: const ColoredBox(
                    color: BathymetryTerrainBuilder.landColor,
                    child: SizedBox(width: 12, height: 12),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  context.l10n.dive3d_seascape_legend_land,
                  style: labelStyle,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/dive_3d/presentation/widgets/seascape_depth_legend_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_3d/presentation/widgets/seascape_depth_legend.dart test/features/dive_3d/presentation/widgets/seascape_depth_legend_test.dart lib/l10n/arb/
git commit -m "feat(seascape): depth legend widget"
```

### Task 13: Terrain appearance sheet + l10n batch 2

**Files:**
- Create: `lib/features/dive_3d/presentation/widgets/terrain_appearance_sheet.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/dive_3d/presentation/widgets/terrain_appearance_sheet_test.dart`

**Interfaces:**
- Consumes: `settingsProvider` + `SettingsNotifier.setSeascapeAppearance` (Task 2), `SeascapeAppearance` types.
- Produces: `void showTerrainAppearanceSheet(BuildContext context)` and widget `TerrainAppearanceSheet`; l10n keys listed below. Tasks 14 and 15 call `showTerrainAppearanceSheet`.

- [ ] **Step 1: Add l10n batch 2 to all 11 arb files, then `flutter gen-l10n` (project root)**

English (place next to the other `dive3d_seascape_*` keys; every key also gets its empty `"@key": {}` metadata line):

```json
  "dive3d_seascape_appearance": "Terrain appearance",
  "dive3d_seascape_chartView": "Chart view",
  "dive3d_seascape_orbitView": "3D view",
  "dive3d_seascape_appearance_rampRange": "Limit color depth range",
  "dive3d_seascape_appearance_rampMax": "Deepest color at",
  "dive3d_seascape_appearance_banded": "Banded gradient",
  "dive3d_seascape_appearance_contours": "Contour levels",
  "dive3d_seascape_appearance_contourAuto": "Auto",
  "dive3d_seascape_appearance_contourCustom": "Custom",
  "dive3d_seascape_appearance_addLevel": "Add level",
  "dive3d_seascape_appearance_defaultColor": "Default",
  "dive3d_seascape_appearance_thickness": "Contour line thickness",
  "dive3d_seascape_appearance_wallAngle": "Steep wall angle",
  "dive3d_seascape_appearance_wallAngleNote": "Bathymetry cells average the slope inside them, so real walls read flatter than they are. Keep this well under 45 degrees."
```

Translations (same key order: appearance / chartView / orbitView / rampRange / rampMax / banded / contours / auto / custom / addLevel / defaultColor / thickness / wallAngle / wallAngleNote):

- **de:** "Geländedarstellung" / "Kartenansicht" / "3D-Ansicht" / "Farbtiefenbereich begrenzen" / "Dunkelste Farbe bei" / "Gestufter Verlauf" / "Tiefenlinien" / "Automatisch" / "Benutzerdefiniert" / "Linie hinzufügen" / "Standard" / "Liniendicke" / "Steilwand-Winkel" / "Bathymetriezellen mitteln das Gefälle in ihrem Inneren, echte Wände wirken daher flacher. Deutlich unter 45 Grad bleiben."
- **es:** "Aspecto del terreno" / "Vista de carta" / "Vista 3D" / "Limitar rango de profundidad del color" / "Color más oscuro a" / "Degradado en bandas" / "Niveles de isóbatas" / "Automático" / "Personalizado" / "Añadir nivel" / "Predeterminado" / "Grosor de las líneas" / "Ángulo de pared vertical" / "Las celdas batimétricas promedian la pendiente interior, así que las paredes reales parecen menos inclinadas. Manténgalo muy por debajo de 45 grados."
- **fr:** "Apparence du terrain" / "Vue carte" / "Vue 3D" / "Limiter la plage de profondeur des couleurs" / "Couleur la plus foncée à" / "Dégradé par paliers" / "Niveaux d'isobathes" / "Automatique" / "Personnalisé" / "Ajouter un niveau" / "Par défaut" / "Épaisseur des lignes" / "Angle de tombant" / "Les cellules bathymétriques moyennent la pente interne : les vrais tombants paraissent moins raides. Rester bien en dessous de 45 degrés."
- **it:** "Aspetto del terreno" / "Vista carta" / "Vista 3D" / "Limita l'intervallo di profondità dei colori" / "Colore più scuro a" / "Gradiente a bande" / "Livelli delle isobate" / "Automatico" / "Personalizzato" / "Aggiungi livello" / "Predefinito" / "Spessore delle linee" / "Angolo di parete ripida" / "Le celle batimetriche mediano la pendenza interna, quindi le pareti reali sembrano meno ripide. Restare ben sotto i 45 gradi."
- **nl:** "Terreinweergave" / "Kaartweergave" / "3D-weergave" / "Kleurdieptebereik beperken" / "Donkerste kleur op" / "Gradiënt in banden" / "Dieptelijnniveaus" / "Automatisch" / "Aangepast" / "Niveau toevoegen" / "Standaard" / "Lijndikte" / "Steile-wandhoek" / "Bathymetriecellen middelen de helling binnenin, echte wanden ogen dus vlakker. Blijf ruim onder 45 graden."
- **pt:** "Aparência do terreno" / "Vista de carta" / "Vista 3D" / "Limitar intervalo de profundidade das cores" / "Cor mais escura em" / "Gradiente em faixas" / "Níveis de isóbatas" / "Automático" / "Personalizado" / "Adicionar nível" / "Padrão" / "Espessura das linhas" / "Ângulo de parede íngreme" / "As células batimétricas fazem a média do declive interno, então paredes reais parecem menos íngremes. Mantenha bem abaixo de 45 graus."
- **hu:** "Terep megjelenése" / "Térképnézet" / "3D nézet" / "Színmélység-tartomány korlátozása" / "Legsötétebb szín ennél" / "Sávos színátmenet" / "Mélységvonal-szintek" / "Automatikus" / "Egyéni" / "Szint hozzáadása" / "Alapértelmezett" / "Vonalvastagság" / "Meredek fal szöge" / "A batimetriai cellák átlagolják a bennük lévő lejtést, így a valódi falak laposabbnak tűnnek. Maradjon jóval 45 fok alatt."
- **ar:** "مظهر التضاريس" / "عرض الخريطة" / "عرض ثلاثي الأبعاد" / "تحديد نطاق عمق الألوان" / "أغمق لون عند" / "تدرج شرائطي" / "مستويات خطوط الأعماق" / "تلقائي" / "مخصص" / "إضافة مستوى" / "افتراضي" / "سماكة الخطوط" / "زاوية الجدار الشديد" / "تحسب خلايا قياس الأعماق متوسط الميل داخلها، لذا تبدو الجدران الحقيقية أقل انحدارا. ابق أقل بكثير من 45 درجة."
- **he:** "מראה פני השטח" / "תצוגת מפה" / "תצוגת תלת-ממד" / "הגבלת טווח עומק הצבעים" / "הצבע הכהה ביותר בעומק" / "מעבר צבע במדרגות" / "רמות קווי עומק" / "אוטומטי" / "מותאם אישית" / "הוספת רמה" / "ברירת מחדל" / "עובי הקווים" / "זווית קיר תלול" / "תאי מדידת עומק ממצעים את השיפוע שבתוכם, ולכן קירות אמיתיים נראים מתונים יותר. יש להישאר הרבה מתחת ל-45 מעלות."
- **zh:** "地形外观" / "海图视图" / "3D 视图" / "限制颜色深度范围" / "最深颜色位于" / "分段渐变" / "等深线层级" / "自动" / "自定义" / "添加层级" / "默认" / "等深线粗细" / "陡壁角度" / "水深网格会平均单元内的坡度，实际陡壁看起来更平缓。请保持远低于 45 度。"

- [ ] **Step 2: Write the failing test**

Create `test/features/dive_3d/presentation/widgets/terrain_appearance_sheet_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/terrain_appearance_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  Future<ProviderContainer> pumpSheet(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: TerrainAppearanceSheet()),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('banded switch writes through to settings', (tester) async {
    final container = await pumpSheet(tester);
    expect(
      container.read(settingsProvider).seascapeAppearance.rampBanded,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('seascapeBandedSwitch')));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.rampBanded,
      isTrue,
    );
  });

  testWidgets('ramp range toggle seeds a default max and clears it',
      (tester) async {
    final container = await pumpSheet(tester);
    await tester.tap(find.byKey(const ValueKey('seascapeRampRangeSwitch')));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.rampMaxDepthMeters,
      40.0,
    );
    await tester.tap(find.byKey(const ValueKey('seascapeRampRangeSwitch')));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.rampMaxDepthMeters,
      isNull,
    );
  });

  testWidgets('custom mode adds a level via the add button', (tester) async {
    final container = await pumpSheet(tester);
    await tester.tap(find.text('Custom'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('seascapeAddLevelButton')));
    await tester.pump();
    final appearance =
        container.read(settingsProvider).seascapeAppearance;
    expect(appearance.contourMode, SeascapeContourMode.custom);
    expect(appearance.customLevels, hasLength(1));
    expect(appearance.customLevels.single.depthMeters, 10.0);
  });

  testWidgets('wall angle slider persists its value', (tester) async {
    final container = await pumpSheet(tester);
    final slider = find.byKey(const ValueKey('seascapeWallAngleSlider'));
    await tester.drag(slider, const Offset(200, 0));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.wallAngleDeg,
      greaterThan(22.0),
    );
  });
}
```

- [ ] **Step 3: Run to verify it fails**

Run: `flutter test test/features/dive_3d/presentation/widgets/terrain_appearance_sheet_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 4: Implement the sheet**

Create `terrain_appearance_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Opens the terrain-appearance editor for the seascape views.
void showTerrainAppearanceSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const SafeArea(
      child: SingleChildScrollView(child: TerrainAppearanceSheet()),
    ),
  );
}

/// Issue #1065 knobs: ramp depth range, banded gradient, contour mode with
/// a custom level editor, line thickness, steep-wall angle. Every change
/// writes straight through SettingsNotifier (device-local persistence),
/// so both seascape pages and their providers react immediately.
class TerrainAppearanceSheet extends ConsumerWidget {
  const TerrainAppearanceSheet({super.key});

  static const List<int?> _palette = [
    null, // default ink
    0xFFEF4444,
    0xFFF97316,
    0xFFFDE047,
    0xFF10B981,
    0xFF3B82F6,
    0xFFA855F7,
  ];
  static const double _defaultRampMaxMeters = 40.0;
  static const double _defaultNewLevelMeters = 10.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final appearance = ref.watch(
      settingsProvider.select((s) => s.seascapeAppearance),
    );
    final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
    final unitInMeters = depthUnit == DepthUnit.feet ? 0.3048 : 1.0;
    final notifier = ref.read(settingsProvider.notifier);
    void update(SeascapeAppearance next) =>
        notifier.setSeascapeAppearance(next);

    String depthText(double meters) {
      final v = meters / unitInMeters;
      final text = v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
      return '$text ${depthUnit.symbol}';
    }

    final rampMax = appearance.rampMaxDepthMeters;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.dive3d_seascape_appearance,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SwitchListTile(
            key: const ValueKey('seascapeRampRangeSwitch'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.dive3d_seascape_appearance_rampRange),
            value: rampMax != null,
            onChanged: (on) => update(
              on
                  ? appearance.copyWith(
                      rampMaxDepthMeters: _defaultRampMaxMeters,
                    )
                  : appearance.copyWith(clearRampMax: true),
            ),
          ),
          if (rampMax != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.dive3d_seascape_appearance_rampMax),
              subtitle: Slider(
                key: const ValueKey('seascapeRampMaxSlider'),
                min: 5,
                max: 200,
                value: (rampMax / unitInMeters).clamp(5.0, 200.0),
                onChanged: (v) => update(
                  appearance.copyWith(
                    rampMaxDepthMeters: v.roundToDouble() * unitInMeters,
                  ),
                ),
              ),
              trailing: Text(depthText(rampMax)),
            ),
          SwitchListTile(
            key: const ValueKey('seascapeBandedSwitch'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.dive3d_seascape_appearance_banded),
            value: appearance.rampBanded,
            onChanged: (on) => update(appearance.copyWith(rampBanded: on)),
          ),
          const Divider(),
          Text(l10n.dive3d_seascape_appearance_contours),
          const SizedBox(height: 8),
          SegmentedButton<SeascapeContourMode>(
            key: const ValueKey('seascapeContourModeSegments'),
            segments: [
              ButtonSegment(
                value: SeascapeContourMode.auto,
                label: Text(l10n.dive3d_seascape_appearance_contourAuto),
              ),
              ButtonSegment(
                value: SeascapeContourMode.custom,
                label: Text(l10n.dive3d_seascape_appearance_contourCustom),
              ),
            ],
            selected: {appearance.contourMode},
            onSelectionChanged: (sel) =>
                update(appearance.copyWith(contourMode: sel.single)),
          ),
          if (appearance.contourMode == SeascapeContourMode.custom) ...[
            for (var i = 0; i < appearance.customLevels.length; i++)
              _levelRow(context, appearance, i, unitInMeters, update),
            TextButton.icon(
              key: const ValueKey('seascapeAddLevelButton'),
              icon: const Icon(Icons.add),
              label: Text(l10n.dive3d_seascape_appearance_addLevel),
              onPressed: () => update(
                appearance.copyWith(
                  customLevels: [
                    ...appearance.customLevels,
                    const SeascapeContourLevel(
                      depthMeters: _defaultNewLevelMeters,
                    ),
                  ],
                ),
              ),
            ),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.dive3d_seascape_appearance_thickness),
            subtitle: Slider(
              key: const ValueKey('seascapeThicknessSlider'),
              min: 0.5,
              max: 3.0,
              divisions: 10,
              value: appearance.contourThickness,
              onChanged: (v) =>
                  update(appearance.copyWith(contourThickness: v)),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.dive3d_seascape_appearance_wallAngle),
            subtitle: Slider(
              key: const ValueKey('seascapeWallAngleSlider'),
              min: 5,
              max: 90,
              divisions: 85,
              value: appearance.wallAngleDeg.clamp(5.0, 90.0),
              onChanged: (v) =>
                  update(appearance.copyWith(wallAngleDeg: v.roundToDouble())),
            ),
            trailing: Text('${appearance.wallAngleDeg.round()}°'),
          ),
          Text(
            l10n.dive3d_seascape_appearance_wallAngleNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _levelRow(
    BuildContext context,
    SeascapeAppearance appearance,
    int index,
    double unitInMeters,
    void Function(SeascapeAppearance) update,
  ) {
    final level = appearance.customLevels[index];
    List<SeascapeContourLevel> withLevel(SeascapeContourLevel? next) => [
      for (var i = 0; i < appearance.customLevels.length; i++)
        if (i != index)
          appearance.customLevels[i]
        else if (next != null)
          next,
    ];
    final display = level.depthMeters / unitInMeters;
    return Row(
      children: [
        SizedBox(
          width: 96,
          child: TextFormField(
            key: ValueKey('seascapeLevelField$index'),
            initialValue: display % 1 == 0
                ? display.toStringAsFixed(0)
                : display.toStringAsFixed(1),
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
            onFieldSubmitted: (text) {
              final v = double.tryParse(text.replaceAll(',', '.'));
              if (v == null || v <= 0) return;
              update(
                appearance.copyWith(
                  customLevels: withLevel(
                    SeascapeContourLevel(
                      depthMeters: v * unitInMeters,
                      colorArgb: level.colorArgb,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        DropdownButton<int?>(
          key: ValueKey('seascapeLevelColor$index'),
          value: level.colorArgb,
          items: [
            for (final c in _palette)
              DropdownMenuItem(
                value: c,
                child: c == null
                    ? Text(
                        context.l10n.dive3d_seascape_appearance_defaultColor,
                      )
                    : CircleAvatar(radius: 8, backgroundColor: Color(c)),
              ),
          ],
          onChanged: (c) => update(
            appearance.copyWith(
              customLevels: withLevel(
                SeascapeContourLevel(
                  depthMeters: level.depthMeters,
                  colorArgb: c,
                ),
              ),
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          key: ValueKey('seascapeLevelRemove$index'),
          icon: const Icon(Icons.delete_outline),
          onPressed: () =>
              update(appearance.copyWith(customLevels: withLevel(null))),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run, format, commit**

Run: `flutter test test/features/dive_3d/presentation/widgets/terrain_appearance_sheet_test.dart`
Expected: PASS. Then:
```bash
dart format .
git add lib/features/dive_3d/presentation/widgets/terrain_appearance_sheet.dart test/features/dive_3d/presentation/widgets/terrain_appearance_sheet_test.dart lib/l10n/arb/
git commit -m "feat(seascape): terrain appearance sheet"
```

### Task 14: Site seascape page integration

**Files:**
- Modify: `lib/features/dive_3d/presentation/pages/site_seascape_page.dart`
- Test: `test/features/dive_3d/presentation/site_seascape_page_test.dart` (extend)

**Interfaces:**
- Consumes: viewport `chartMode`/`contourLabels` (Task 11), `SeascapeDepthLegend` (Task 12), `showTerrainAppearanceSheet` (Task 13), `SiteSeascapeReady.contourLabels` (Task 9), l10n keys (Tasks 8, 13), `DepthUnit` (`core/constants/units.dart`).
- Produces: the finished site page. Keys for tests: `ValueKey('seascapeAppearanceButton')`, `ValueKey('seascapeChartToggle')`.

- [ ] **Step 1: Write the failing tests**

Extend `site_seascape_page_test.dart` (the existing `readyState()` helper works unchanged; `_TestSettingsNotifier` supplies default `AppSettings()`, which now carries `seascapeAppearance`):

```dart
  testWidgets('contours default on, chip toggles them off', (tester) async {
    await tester.pumpWidget(page(readyState()));
    await tester.pump();
    await tester.pump();
    Dive3dInteractiveViewport viewport() => tester
        .widget<Dive3dInteractiveViewport>(
          find.byType(Dive3dInteractiveViewport),
        );
    expect(viewport().visibleOverlays, contains(SceneOverlay.contours));
    expect(viewport().visibleOverlays, contains(SceneOverlay.water));
    expect(viewport().chartMode, isFalse);
    await tester.tap(find.text('Contours'));
    await tester.pump();
    expect(
      viewport().visibleOverlays,
      isNot(contains(SceneOverlay.contours)),
    );
    // Walls chip exists and defaults off.
    expect(find.text('Steep walls'), findsOneWidget);
    expect(
      viewport().visibleOverlays,
      isNot(contains(SceneOverlay.steepWalls)),
    );
  });

  testWidgets('chart toggle enters chart mode and hides the water plane',
      (tester) async {
    await tester.pumpWidget(page(readyState()));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('seascapeChartToggle')));
    await tester.pump();
    final viewport = tester.widget<Dive3dInteractiveViewport>(
      find.byType(Dive3dInteractiveViewport),
    );
    expect(viewport.chartMode, isTrue);
    expect(viewport.visibleOverlays, isNot(contains(SceneOverlay.water)));
  });

  testWidgets('legend renders on the ready state', (tester) async {
    await tester.pumpWidget(page(readyState()));
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const ValueKey('seascapeDepthLegend')),
      findsOneWidget,
    );
  });
```

Add the needed imports (`scene_overlay.dart`, `seascape_depth_legend` is found by key so no import needed).

- [ ] **Step 2: Run to verify failures**

Run: `flutter test test/features/dive_3d/presentation/site_seascape_page_test.dart`
Expected: FAIL (`chartMode` getter absent until Task 11 landed; chips/keys absent).

- [ ] **Step 3: Implement the page changes**

In `site_seascape_page.dart`:

1. State: `_visible` initial set becomes `{SceneOverlay.markers, SceneOverlay.paths, SceneOverlay.contours}`; add `bool _chartMode = false;`.
2. AppBar gains actions:
```dart
        actions: [
          IconButton(
            key: const ValueKey('seascapeAppearanceButton'),
            icon: const Icon(Icons.tune),
            tooltip: context.l10n.dive3d_seascape_appearance,
            onPressed: () => showTerrainAppearanceSheet(context),
          ),
          IconButton(
            key: const ValueKey('seascapeChartToggle'),
            icon: Icon(_chartMode ? Icons.view_in_ar : Icons.map_outlined),
            tooltip: _chartMode
                ? context.l10n.dive3d_seascape_orbitView
                : context.l10n.dive3d_seascape_chartView,
            onPressed: () => setState(() => _chartMode = !_chartMode),
          ),
        ],
```
3. In the ready branch, watch the appearance selects once at the top of `build`:
```dart
    final appearance = ref.watch(
      settingsProvider.select((s) => s.seascapeAppearance),
    );
    final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
```
4. Viewport call gains:
```dart
                              visibleOverlays: {
                                ..._visible,
                                if (!_chartMode) SceneOverlay.water,
                              },
                              chartMode: _chartMode,
                              contourLabels: state.contourLabels,
```
(the destructured `SiteSeascapeReady` pattern adds `:final contourLabels`).
5. Add the legend to the ready Stack, after the source chip:
```dart
                      Positioned(
                        top: 40,
                        right: 8,
                        child: SeascapeDepthLegend(
                          maxDepthMeters: axisInputs.maxDepth,
                          hasLand: grid.depthsMeters.any(
                            (d) => d == null || d <= 0,
                          ),
                          appearance: appearance,
                          displayUnitInMeters:
                              depthUnit == DepthUnit.feet ? 0.3048 : 1.0,
                          depthSymbol: depthUnit.symbol,
                        ),
                      ),
```
6. `_overlayChips()` gains two chips after the existing ones:
```dart
          chip(
            SceneOverlay.contours,
            context.l10n.dive3d_seascape_overlay_contours,
          ),
          chip(
            SceneOverlay.steepWalls,
            context.l10n.dive3d_seascape_overlay_walls,
          ),
```
7. Imports: `seascape_appearance` is NOT needed here (type comes through settings); add `core/constants/units.dart`, `terrain_appearance_sheet.dart`, `seascape_depth_legend.dart`.

- [ ] **Step 4: Run, format, commit**

Run: `flutter test test/features/dive_3d/presentation/site_seascape_page_test.dart`
Expected: PASS (all old and new tests). Then:
```bash
dart format .
git add lib/features/dive_3d/presentation/pages/site_seascape_page.dart test/features/dive_3d/presentation/site_seascape_page_test.dart
git commit -m "feat(seascape): chart mode, legend, and appearance on the site page"
```

---

### Task 15: Per-dive seascape page integration

**Files:**
- Modify: `lib/features/dive_3d/presentation/pages/spatial_site_page.dart`
- Test: `test/features/dive_3d/presentation/pages/spatial_site_page_test.dart` (extend)

**Interfaces:**
- Consumes: same widgets/keys as Task 14; `SpatialSceneResult.contourLabels`/`grid`/`axisInputs`.
- Produces: the finished per-dive page: tune action, a chip row (Contours default on, Steep walls default off) above the `TimeScrubBar` shown only when the terrain is real (`result.grid != null`), legend under the same condition, contours/water/walls in the visible-overlay state. NO chart mode here.

- [ ] **Step 1: Write the failing tests**

Extend `spatial_site_page_test.dart` using its existing fixtures (read the file; it already fabricates a `SpatialSceneResult` with a grid for the hover tests). Add:

```dart
  testWidgets('real-terrain scene shows chips and legend, contours on',
      (tester) async {
    // Pump with the file's existing real-grid result fixture.
    // ...
    final viewport = tester.widget<Dive3dInteractiveViewport>(
      find.byType(Dive3dInteractiveViewport),
    );
    expect(viewport.visibleOverlays, contains(SceneOverlay.contours));
    expect(viewport.visibleOverlays, contains(SceneOverlay.water));
    expect(viewport.chartMode, isFalse);
    expect(find.text('Contours'), findsOneWidget);
    expect(find.text('Steep walls'), findsOneWidget);
    expect(find.byKey(const ValueKey('seascapeDepthLegend')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('seascapeAppearanceButton')),
      findsOneWidget,
    );
  });

  testWidgets('synthesized scene hides chips and legend', (tester) async {
    // Pump with the file's existing null-grid (synthesized) fixture.
    // ...
    expect(find.text('Contours'), findsNothing);
    expect(find.byKey(const ValueKey('seascapeDepthLegend')), findsNothing);
  });
```

Fill the pump lines from the file's own helpers; keep bounded pumps.

- [ ] **Step 2: Run to verify failures**

Run: `flutter test test/features/dive_3d/presentation/pages/spatial_site_page_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

In `spatial_site_page.dart`:

1. State gains `final Set<SceneOverlay> _visible = {SceneOverlay.markers, SceneOverlay.contours};`.
2. AppBar gains the same tune action as Task 14 (key `seascapeAppearanceButton`).
3. Viewport call: replace `visibleOverlays: const {SceneOverlay.markers}` with
```dart
                            visibleOverlays: {
                              ..._visible,
                              SceneOverlay.water,
                            },
                            contourLabels: result.contourLabels,
```
4. Watch the two settings selects at the top of `build` (same two lines as Task 14 step 3).
5. Legend, only when real terrain, added to the Stack after `_captions`:
```dart
                    if (result.grid != null && result.axisInputs != null)
                      Positioned(
                        top: 40,
                        right: 8,
                        child: SeascapeDepthLegend(
                          maxDepthMeters: result.axisInputs!.maxDepth,
                          hasLand: result.grid!.depthsMeters.any(
                            (d) => d == null || d <= 0,
                          ),
                          appearance: appearance,
                          displayUnitInMeters:
                              depthUnit == DepthUnit.feet ? 0.3048 : 1.0,
                          depthSymbol: depthUnit.symbol,
                        ),
                      ),
```
6. Above the `TimeScrubBar` inside the bottom `SafeArea`, wrap in a `Column(mainAxisSize: MainAxisSize.min)` with a chip row first, shown only for real terrain:
```dart
                    if (result.grid != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            FilterChip(
                              label: Text(
                                context
                                    .l10n
                                    .dive3d_seascape_overlay_contours,
                              ),
                              selected:
                                  _visible.contains(SceneOverlay.contours),
                              onSelected: (on) => setState(() {
                                on
                                    ? _visible.add(SceneOverlay.contours)
                                    : _visible.remove(SceneOverlay.contours);
                              }),
                            ),
                            FilterChip(
                              label: Text(
                                context.l10n.dive3d_seascape_overlay_walls,
                              ),
                              selected:
                                  _visible.contains(SceneOverlay.steepWalls),
                              onSelected: (on) => setState(() {
                                on
                                    ? _visible.add(SceneOverlay.steepWalls)
                                    : _visible.remove(
                                        SceneOverlay.steepWalls,
                                      );
                              }),
                            ),
                          ],
                        ),
                      ),
```
7. Imports as in Task 14.

- [ ] **Step 4: Run, format, commit**

Run: `flutter test test/features/dive_3d/presentation/pages/spatial_site_page_test.dart`
Expected: PASS. Then:
```bash
dart format .
git add lib/features/dive_3d/presentation/pages/spatial_site_page.dart test/features/dive_3d/presentation/pages/spatial_site_page_test.dart
git commit -m "feat(seascape): contours, walls, and legend on the per-dive page"
```

---

### Task 16: Sites-map entry point

**Files:**
- Modify: `lib/shared/widgets/map_list_layout/map_info_card.dart`
- Modify: `lib/features/dive_sites/presentation/widgets/site_map_content.dart:461`
- Test: `test/shared/widgets/map_info_card_test.dart` (create or extend; locate any existing file with `grep -rln "MapInfoCard" test/`)

**Interfaces:**
- Consumes: `MapInfoCard` (title/subtitle/leading/onDetailsTap), `SiteSeascapePage`.
- Produces: `MapInfoCard({..., Widget? trailing})` rendered between the text column and the chevron. The trailing widget's semantics (tooltip) come from the CALLER so the shared widget stays l10n-free for its consumers (known trap: l10n inside shared widgets breaks consumer tests).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/map_list_layout/map_info_card.dart';

void main() {
  testWidgets('renders the trailing widget before the details chevron',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MapInfoCard(
          title: 'Salt Pier',
          onDetailsTap: () {},
          trailing: IconButton(
            icon: const Icon(Icons.terrain),
            onPressed: () => tapped = true,
          ),
        ),
      ),
    ));
    await tester.tap(find.byIcon(Icons.terrain));
    expect(tapped, isTrue);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails, then implement**

Run the test (compile FAIL on `trailing`). Then:

1. `map_info_card.dart`: add `final Widget? trailing;` (ctor `this.trailing`), and render it in the `Row` between the `Expanded` column and the chevron:
```dart
                if (trailing != null) trailing!,
```
2. `site_map_content.dart` `_buildMapInfoCard` (`:461`): pass the seascape action, mirroring the site-detail app bar action (`site_detail_page.dart:281-290`):
```dart
    return MapInfoCard(
      title: site.name,
      subtitle: subtitle.isNotEmpty ? subtitle : null,
      leading: CircleAvatar(
        backgroundColor: colorScheme.primaryContainer,
        child: Icon(Icons.location_on, color: colorScheme.primary),
      ),
      trailing: site.hasCoordinates
          ? IconButton(
              icon: const Icon(Icons.terrain),
              tooltip: context.l10n.dive3d_seascape_siteTitle,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SiteSeascapePage(siteId: site.id),
                ),
              ),
            )
          : null,
      onDetailsTap: widget.onDetailsTap != null
          ? () => widget.onDetailsTap!(site.id)
          : () => context.push('/sites/${site.id}'),
    );
```
with the import `package:submersion/features/dive_3d/presentation/pages/site_seascape_page.dart`.

- [ ] **Step 3: Run the affected suites, format, commit**

Run: `flutter test test/shared/ test/features/dive_sites/`
Expected: PASS. Then:
```bash
dart format .
git add lib/shared/widgets/map_list_layout/map_info_card.dart lib/features/dive_sites/presentation/widgets/site_map_content.dart test/shared/
git commit -m "feat(seascape): open the seascape from the sites map callout"
```

---

### Task 17: Spec amendment + full verification

**Files:**
- Modify: `docs/superpowers/specs/2026-08-15-seascape-contours-chart-mode-design.md`

- [ ] **Step 1: Amend the spec (two corrections found at planning time)**

First, the level-selection rule: in the spec's Contour generation section, extend the "Selection rule" sentence to read "... the minor interval is the smallest nice step, floored at 1 display unit, that yields at most 15 levels across the wet depth range". Without the floor, the at-most-15 rule alone can never produce fewer than 2 levels, so the spec's flat-site guard would be dead code (and near-flat sites would get centimeter contours).

Second, the persistence paragraph:

Replace the sentence beginning "New `AppSettings` fields:" (in the Terrain appearance sheet section) with:

```markdown
Persistence (corrected at planning time): the knobs live on `AppSettings`
as ONE `SeascapeAppearance` value object, persisted DEVICE-LOCALLY as a
single JSON string in SharedPreferences (`SettingsKeys.seascapeAppearance`,
the `profileMetricsFollowViewport` lane). The per-diver `diver_settings`
table is deliberately NOT touched: its discrete columns would require a
main-DB schema migration plus sync surface, which this slice scopes out.
```

Also update the spec's File plan entry for settings to name
`lib/features/settings/presentation/providers/settings_providers.dart`, and
replace "Dive-sites map marker callout (exact file located at planning
time)" with the two real files
(`lib/shared/widgets/map_list_layout/map_info_card.dart`,
`lib/features/dive_sites/presentation/widgets/site_map_content.dart`).

- [ ] **Step 2: Full verification**

```bash
dart format .
flutter analyze
flutter test
```
Expected: format makes no changes on the second run, analyze reports zero issues (infos are CI-fatal in this project), full suite green. Run `flutter gen-l10n` from the project root once more and confirm `git status` shows no drift (generated localizations already committed).

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-08-15-seascape-contours-chart-mode-design.md
git commit -m "docs(seascape): record device-local persistence lane in spec"
```

---

## Execution notes

- Tasks 1-7 are pure domain/data work and parallel-safe in principle, but run them in order: 4 and 5 share `contour_builder.dart`, and 5 depends on 8's enum values (Task 5 Step 3a covers the ordering).
- The pre-push hook may run against the wrong tree from a worktree; verify locally (`flutter analyze` + targeted tests) and push from the worktree only after Task 17's full verification.
- Never commit `database.g.dart` (gitignored, CI regenerates). The `app_localizations*.dart` files ARE committed.








