# Perdix Video Overlay Implementation Plan (#168)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A draggable, translucent Shearwater-Perdix-style dive computer face overlaid on videos (synced to playback) and photos (static at capture instant) in `PhotoViewerPage`.

**Architecture:** A pure `PerdixFaceResolver` maps a dive-time second to an immutable `PerdixFaceData` using the existing `resolveSample()` machinery; a presentational `PerdixFace` widget renders it Perdix-style; a `DraggablePerdixOverlay` wrapper adds fraction-based dragging and an `AnimatedBuilder`-driven video clock; `PhotoViewerPage` mounts it behind an availability gate with a toggle button, hoisting the `VideoPlayerController` up via callback. Spec: `docs/superpowers/specs/2026-07-16-perdix-video-overlay-design.md`.

**Tech Stack:** Flutter, Riverpod (StateNotifier settings), video_player, SharedPreferences, flutter gen-l10n.

## Global Constraints

- ALL work happens in the worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/perdix-video-overlay-168` on branch `worktree-perdix-video-overlay-168`. Run every command from that directory. NEVER touch the main checkout. Subagents: `cd` there first — subagent shells start in the MAIN tree.
- `dart format .` must produce no changes before every commit.
- Run `flutter analyze` bare — never pipe through `tail`/`head` (masks failures).
- No emojis anywhere in code, comments, or docs.
- All displayed values respect the active diver's unit settings via `UnitFormatter`.
- New user-visible strings go into ALL 11 ARB files (`lib/l10n/arb/app_en.arb` + de, es, fr, it, pt, nl, he, hu, zh, ar). Regenerate with `flutter gen-l10n`.
- No Shearwater branding text/logo on the face (trademark).
- Max 800 lines per file; keep files focused.
- Commit messages: conventional style, NO Co-Authored-By line, NO session URL.
- TDD: write the failing test first for every unit of behavior.
- Do not run the full `flutter test` suite (too slow); run the specific test files named in each task. The pre-push hook runs the full suite.

---

### Task 1: Perdix overlay settings (enabled flag + position)

Three device-local settings persisted in SharedPreferences, mirroring the existing `fullscreenReadoutCardX/Y` pattern exactly (NOT the per-diver DB pattern).

**Files:**
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart`
- Test: `test/features/settings/presentation/providers/settings_notifier_real_test.dart`

**Interfaces:**
- Consumes: existing `SettingsNotifier`, `AppSettings`, `SettingsKeys`, `_loadSettings`/`_saveSettings` plumbing.
- Produces (used by Task 5):
  - `AppSettings.perdixOverlayEnabled` (`bool`, default `false`)
  - `AppSettings.perdixOverlayX` / `perdixOverlayY` (`double?`, null = default corner)
  - `SettingsNotifier.setPerdixOverlayEnabled(bool value)`
  - `SettingsNotifier.setPerdixOverlayPosition(double x, double y)` (clamps to 0..1, non-finite → default corner `(1.0, 0.0)`)

- [ ] **Step 1: Write the failing tests**

Open `test/features/settings/presentation/providers/settings_notifier_real_test.dart`. It already contains the 4-fake `ProviderContainer` setup (`sharedPreferencesProvider`, `_InMemorySettingsRepository`, `_EmptyDiverRepository`, `_NullDiverIdNotifier`) and a `waitForInit()` helper, plus existing readout-card tests at lines ~362-393. Add a new group inside the same `main()`, reusing the file's existing `container`/`prefs`/`waitForInit` helpers verbatim (match their exact local names as found in the file):

```dart
group('perdix overlay settings', () {
  test('defaults: disabled, null position', () async {
    final notifier = container.read(settingsProvider.notifier);
    await waitForInit(notifier);
    final s = container.read(settingsProvider);
    expect(s.perdixOverlayEnabled, isFalse);
    expect(s.perdixOverlayX, isNull);
    expect(s.perdixOverlayY, isNull);
  });

  test('setPerdixOverlayEnabled persists to prefs and state', () async {
    final notifier = container.read(settingsProvider.notifier);
    await waitForInit(notifier);
    await notifier.setPerdixOverlayEnabled(true);
    expect(container.read(settingsProvider).perdixOverlayEnabled, isTrue);
    expect(prefs.getBool('perdix_overlay_enabled'), isTrue);
    await notifier.setPerdixOverlayEnabled(false);
    expect(container.read(settingsProvider).perdixOverlayEnabled, isFalse);
    expect(prefs.getBool('perdix_overlay_enabled'), isFalse);
  });

  test('setPerdixOverlayPosition persists and clamps', () async {
    final notifier = container.read(settingsProvider.notifier);
    await waitForInit(notifier);
    await notifier.setPerdixOverlayPosition(0.25, 0.75);
    var s = container.read(settingsProvider);
    expect(s.perdixOverlayX, 0.25);
    expect(s.perdixOverlayY, 0.75);
    expect(prefs.getDouble('perdix_overlay_x'), 0.25);
    expect(prefs.getDouble('perdix_overlay_y'), 0.75);

    await notifier.setPerdixOverlayPosition(-2.0, 9.0);
    s = container.read(settingsProvider);
    expect(s.perdixOverlayX, 0.0);
    expect(s.perdixOverlayY, 1.0);
  });

  test('setPerdixOverlayPosition sanitizes non-finite to default corner', () async {
    final notifier = container.read(settingsProvider.notifier);
    await waitForInit(notifier);
    await notifier.setPerdixOverlayPosition(double.nan, double.infinity);
    final s = container.read(settingsProvider);
    expect(s.perdixOverlayX, 1.0);
    expect(s.perdixOverlayY, 0.0);
  });
});
```

Note: the existing `waitForInit` may take no argument — copy the call convention used by the neighboring tests in that file.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart`
Expected: FAIL — `perdixOverlayEnabled` getter not defined.

- [ ] **Step 3: Implement the settings chain**

In `lib/features/settings/presentation/providers/settings_providers.dart`, mirror the `fullscreenReadoutCardX/Y` chain (all six touchpoints):

1. `SettingsKeys` (near line 77):
```dart
static const String perdixOverlayEnabled = 'perdix_overlay_enabled';
static const String perdixOverlayX = 'perdix_overlay_x';
static const String perdixOverlayY = 'perdix_overlay_y';
```
2. `AppSettings` fields (near line 315):
```dart
/// Perdix-style media overlay: shown over photos/videos when enabled.
final bool perdixOverlayEnabled;

/// Persisted overlay position as fractions of the movable range (0..1).
/// Null means the default corner. Device-local, not per-diver.
final double? perdixOverlayX;
final double? perdixOverlayY;
```
3. Constructor (near line 414): `this.perdixOverlayEnabled = false,` / `this.perdixOverlayX,` / `this.perdixOverlayY,`
4. `copyWith` params + body (near lines 546/670):
```dart
perdixOverlayEnabled: perdixOverlayEnabled ?? this.perdixOverlayEnabled,
perdixOverlayX: perdixOverlayX ?? this.perdixOverlayX,
perdixOverlayY: perdixOverlayY ?? this.perdixOverlayY,
```
5. `_loadSettings` (near line 772): read `prefs.getBool(SettingsKeys.perdixOverlayEnabled) ?? false` and the two doubles into locals; pass them in BOTH the no-diver branch (~780) and the diver branch (~791), exactly as the readout-card values are.
6. `_saveSettings` (near line 843):
```dart
await prefs.setBool(SettingsKeys.perdixOverlayEnabled, state.perdixOverlayEnabled);
final perdixX = state.perdixOverlayX;
if (perdixX != null) {
  await prefs.setDouble(SettingsKeys.perdixOverlayX, perdixX);
}
final perdixY = state.perdixOverlayY;
if (perdixY != null) {
  await prefs.setDouble(SettingsKeys.perdixOverlayY, perdixY);
}
```
7. Notifier setters (near line 1315, next to `setFullscreenReadoutCardPosition`):
```dart
Future<void> setPerdixOverlayEnabled(bool value) async {
  state = state.copyWith(perdixOverlayEnabled: value);
  await _saveSettings();
}

Future<void> setPerdixOverlayPosition(double x, double y) async {
  state = state.copyWith(
    perdixOverlayX: x.isFinite ? x.clamp(0.0, 1.0) : 1.0,
    perdixOverlayY: y.isFinite ? y.clamp(0.0, 1.0) : 0.0,
  );
  await _saveSettings();
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/settings/presentation/providers/settings_notifier_real_test.dart`
Expected: PASS (all groups, including pre-existing ones).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -u
git commit -m "feat: add Perdix overlay settings (enabled flag and position)"
```

---

### Task 2: PerdixFaceData + PerdixFaceResolver

Pure data resolution: dive-time second → face values. No Flutter imports beyond entities.

**Files:**
- Create: `lib/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart`
- Test: `test/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver_test.dart`

**Interfaces:**
- Consumes:
  - `resolveSample({required List<DiveProfilePoint> profile, ProfileAnalysis? analysis, Map<String, List<TankPressurePoint>>? tankPressures, required int timestamp}) → InstrumentSample` from `lib/features/dive_log/presentation/widgets/instrument_tiles.dart:196`
  - `indexForTimestamp(List<DiveProfilePoint>, int) → int?` from `lib/features/dive_log/domain/services/profile_position.dart:7` (floor/at-or-before, clamped)
  - `buildGasUsageSegments({required List<DiveTank> tanks, required List<GasSwitchWithTank> gasSwitches, required int diveDurationSeconds}) → List<GasUsageSegment>` and `buildActiveTankIntervals(...)` from `lib/features/dive_log/data/services/gas_usage_segments_service.dart:40,140` (verify the exact `buildActiveTankIntervals` named parameters at line 140 before use; it follows the same tanks/gasSwitches/diveDurationSeconds shape)
  - `GasUsageSegment` fields: `startSeconds`, `endSeconds` (exclusive), `label` (from `GasMix.name`, e.g. `Air`, `EAN32`, `Tx 21/35`)
- Produces (used by Tasks 3-5):
```dart
class PerdixFaceData {
  final int diveTimeSeconds;        // clamped dive time actually resolved
  final double? depthMeters;
  final double? runningMaxDepthMeters; // max depth UP TO this time, not dive max
  final int? ndlSeconds;
  final double? ceilingMeters;
  final int? ttsSeconds;
  final double? temperatureCelsius;
  final String? gasLabel;           // "Air" / "EAN32" / "Tx 21/35"
  final double? tankPressureBar;    // active tank's pressure at this time
  final double? cnsPercent;
  final double? ppO2Bar;
  final bool inDeco;
}

class PerdixFaceResolver {
  PerdixFaceResolver({
    required List<DiveProfilePoint> profile,
    ProfileAnalysis? analysis,
    List<DiveTank> tanks = const [],
    List<GasSwitchWithTank> gasSwitches = const [],
    Map<String, List<TankPressurePoint>>? tankPressures,
  });
  bool get isAvailable;                       // profile not empty
  PerdixFaceData resolve(int diveTimeSeconds); // clamps to profile time range
}
```

- [ ] **Step 1: Write the failing tests**

Create `test/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart';

DiveProfilePoint p(int t, double depth, {double? temp, int? ndl, double? ceiling, int? decoType, int? tts, double? cns, double? ppO2}) =>
    DiveProfilePoint(
      timestamp: t,
      depth: depth,
      temperature: temp,
      ndl: ndl,
      ceiling: ceiling,
      decoType: decoType,
      tts: tts,
      cns: cns,
      ppO2: ppO2,
    );

void main() {
  final profile = [
    p(0, 0.0, temp: 24.0, ndl: 3600),
    p(10, 5.0, temp: 23.0, ndl: 3000),
    p(20, 18.0, temp: 22.0, ndl: 1500),
    p(30, 12.0, temp: 22.0, ndl: 1800),
    p(40, 6.0, temp: 23.0, ndl: 2400),
  ];

  group('PerdixFaceResolver.resolve', () {
    test('floor sample resolution between samples', () {
      final r = PerdixFaceResolver(profile: profile);
      final d = r.resolve(25); // between t=20 and t=30 -> floor to t=20
      expect(d.depthMeters, 18.0);
      expect(d.temperatureCelsius, 22.0);
      expect(d.ndlSeconds, 1500);
    });

    test('clamps below first and above last sample', () {
      final r = PerdixFaceResolver(profile: profile);
      expect(r.resolve(-100).depthMeters, 0.0);
      expect(r.resolve(-100).diveTimeSeconds, 0);
      expect(r.resolve(9999).depthMeters, 6.0);
      expect(r.resolve(9999).diveTimeSeconds, 40);
    });

    test('running max depth is max so far, not dive max', () {
      final r = PerdixFaceResolver(profile: profile);
      expect(r.resolve(10).runningMaxDepthMeters, 5.0);
      expect(r.resolve(20).runningMaxDepthMeters, 18.0);
      expect(r.resolve(40).runningMaxDepthMeters, 18.0); // holds after shallowing
    });

    test('inDeco from decoType == 2 and ceiling passthrough', () {
      final decoProfile = [
        p(0, 0.0),
        p(10, 30.0, ceiling: 6.0, decoType: 2, tts: 900, ndl: -1),
      ];
      final r = PerdixFaceResolver(profile: decoProfile);
      final d = r.resolve(10);
      expect(d.inDeco, isTrue);
      expect(d.ceilingMeters, 6.0);
      expect(d.ttsSeconds, 900);
    });

    test('empty profile: isAvailable false', () {
      final r = PerdixFaceResolver(profile: const []);
      expect(r.isAvailable, isFalse);
    });

    test('all-optional-null dive resolves with nulls', () {
      final bare = [p(0, 0.0), p(10, 12.0)];
      final r = PerdixFaceResolver(profile: bare);
      final d = r.resolve(10);
      expect(d.depthMeters, 12.0);
      expect(d.temperatureCelsius, isNull);
      expect(d.ndlSeconds, isNull);
      expect(d.gasLabel, isNull);
      expect(d.tankPressureBar, isNull);
      expect(d.inDeco, isFalse);
    });
  });

  group('gas label across a switch', () {
    // Two tanks: back gas air (order 0), deco EAN50 (order 1); switch at t=30.
    final tanks = [
      DiveTank(
        id: 'tank-air',
        diveId: 'd1',
        gasMix: const GasMix(o2: 21.0, he: 0.0),
        order: 0,
      ),
      DiveTank(
        id: 'tank-ean50',
        diveId: 'd1',
        gasMix: const GasMix(o2: 50.0, he: 0.0),
        order: 1,
      ),
    ];
    final switches = [
      GasSwitchWithTank(
        gasSwitch: GasSwitch(
          id: 'gs1',
          diveId: 'd1',
          timestamp: 30,
          tankId: 'tank-ean50',
          createdAt: DateTime(2026, 1, 1),
        ),
        tankName: 'Deco',
        gasMix: 'EAN50',
        o2Fraction: 0.50,
        heFraction: 0.0,
      ),
    ];

    test('label before and after the switch', () {
      final r = PerdixFaceResolver(
        profile: profile,
        tanks: tanks,
        gasSwitches: switches,
      );
      expect(r.resolve(10).gasLabel, 'Air');
      expect(r.resolve(35).gasLabel, 'EAN50');
      expect(r.resolve(40).gasLabel, 'EAN50'); // end of dive inclusive
    });

    test('tank pressure follows the active tank', () {
      final pressures = {
        'tank-air': [
          TankPressurePoint(id: 'p1', tankId: 'tank-air', timestamp: 0, pressure: 200.0),
          TankPressurePoint(id: 'p2', tankId: 'tank-air', timestamp: 30, pressure: 120.0),
        ],
        'tank-ean50': [
          TankPressurePoint(id: 'p3', tankId: 'tank-ean50', timestamp: 30, pressure: 180.0),
        ],
      };
      final r = PerdixFaceResolver(
        profile: profile,
        tanks: tanks,
        gasSwitches: switches,
        tankPressures: pressures,
      );
      expect(r.resolve(10).tankPressureBar, 200.0);
      expect(r.resolve(35).tankPressureBar, 180.0);
    });
  });
}
```

Notes for the implementer: `DiveTank`, `GasMix`, `TankPressurePoint`, `DiveProfilePoint` constructors live in `lib/features/dive_log/domain/entities/dive.dart` (`DiveTank` at ~line 938, `GasMix` at ~1027, `TankPressurePoint` at ~920). Check required constructor params (e.g. `DiveTank` may require `volume`/`workingPressure` or `createdAt`) and add the minimal required arguments to the fixtures — do not change the assertions.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver_test.dart`
Expected: FAIL — file `perdix_face_resolver.dart` does not exist.

- [ ] **Step 3: Implement the resolver**

Create `lib/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart`:

```dart
import '../../../../dive_log/data/services/gas_usage_segments_service.dart';
import '../../../../dive_log/data/services/profile_analysis_service.dart';
import '../../../../dive_log/domain/entities/dive.dart';
import '../../../../dive_log/domain/entities/gas_switch.dart';
import '../../../../dive_log/domain/services/profile_position.dart';
import '../../../../dive_log/presentation/widgets/instrument_tiles.dart';

/// Snapshot of dive computer readings at one moment of the dive, shaped for
/// the Perdix-style media overlay. Values are metric; formatting happens in
/// the widget layer.
class PerdixFaceData {
  final int diveTimeSeconds;
  final double? depthMeters;
  final double? runningMaxDepthMeters;
  final int? ndlSeconds;
  final double? ceilingMeters;
  final int? ttsSeconds;
  final double? temperatureCelsius;
  final String? gasLabel;
  final double? tankPressureBar;
  final double? cnsPercent;
  final double? ppO2Bar;
  final bool inDeco;

  const PerdixFaceData({
    required this.diveTimeSeconds,
    this.depthMeters,
    this.runningMaxDepthMeters,
    this.ndlSeconds,
    this.ceilingMeters,
    this.ttsSeconds,
    this.temperatureCelsius,
    this.gasLabel,
    this.tankPressureBar,
    this.cnsPercent,
    this.ppO2Bar,
    this.inDeco = false,
  });
}

/// Resolves [PerdixFaceData] for arbitrary dive-time seconds. Construct once
/// per dive data load (prefix-max and gas segments are precomputed); resolve
/// is cheap enough to call per video frame.
class PerdixFaceResolver {
  PerdixFaceResolver({
    required List<DiveProfilePoint> profile,
    ProfileAnalysis? analysis,
    List<DiveTank> tanks = const [],
    List<GasSwitchWithTank> gasSwitches = const [],
    Map<String, List<TankPressurePoint>>? tankPressures,
  })  : _profile = profile,
        _analysis = analysis,
        _tankPressures = tankPressures,
        _prefixMaxDepths = _computePrefixMax(profile),
        _gasSegments = (profile.isEmpty || tanks.isEmpty)
            ? const []
            : buildGasUsageSegments(
                tanks: tanks,
                gasSwitches: gasSwitches,
                diveDurationSeconds: profile.last.timestamp,
              ),
        _activeTankIntervals = (profile.isEmpty || tanks.isEmpty)
            ? const {}
            : buildActiveTankIntervals(
                tanks: tanks,
                gasSwitches: gasSwitches,
                diveDurationSeconds: profile.last.timestamp,
              );

  final List<DiveProfilePoint> _profile;
  final ProfileAnalysis? _analysis;
  final Map<String, List<TankPressurePoint>>? _tankPressures;
  final List<double> _prefixMaxDepths;
  final List<GasUsageSegment> _gasSegments;
  final Map<String, List<({int start, int end})>> _activeTankIntervals;

  bool get isAvailable => _profile.isNotEmpty;

  static List<double> _computePrefixMax(List<DiveProfilePoint> profile) {
    final result = List<double>.filled(profile.length, 0.0);
    var running = 0.0;
    for (var i = 0; i < profile.length; i++) {
      if (profile[i].depth > running) running = profile[i].depth;
      result[i] = running;
    }
    return result;
  }

  PerdixFaceData resolve(int diveTimeSeconds) {
    if (_profile.isEmpty) {
      return PerdixFaceData(diveTimeSeconds: diveTimeSeconds);
    }
    final clamped = diveTimeSeconds
        .clamp(_profile.first.timestamp, _profile.last.timestamp);
    final sample = resolveSample(
      profile: _profile,
      analysis: _analysis,
      tankPressures: _tankPressures,
      timestamp: clamped,
    );
    final index = indexForTimestamp(_profile, clamped)!;
    final ceiling = sample.ceilingMeters;
    final activeTankId = _activeTankIdAt(clamped);
    final pressures = sample.tankPressuresBar;
    return PerdixFaceData(
      diveTimeSeconds: clamped,
      depthMeters: sample.depthMeters,
      runningMaxDepthMeters: _prefixMaxDepths[index],
      ndlSeconds: sample.ndlSeconds,
      ceilingMeters: ceiling,
      ttsSeconds: sample.ttsSeconds,
      temperatureCelsius: sample.temperatureCelsius,
      gasLabel: _gasLabelAt(clamped),
      tankPressureBar: activeTankId != null
          ? pressures[activeTankId] ??
              (pressures.isEmpty ? null : pressures.values.first)
          : (pressures.isEmpty ? null : pressures.values.first),
      cnsPercent: sample.cnsPercent,
      ppO2Bar: sample.ppO2Bar,
      inDeco: sample.inDeco || ((ceiling ?? 0) > 0),
    );
  }

  String? _gasLabelAt(int t) {
    if (_gasSegments.isEmpty) return null;
    for (final segment in _gasSegments) {
      if (t >= segment.startSeconds && t < segment.endSeconds) {
        return segment.label;
      }
    }
    // endSeconds is exclusive; the final second of the dive belongs to the
    // last segment.
    return t >= _gasSegments.last.endSeconds ? _gasSegments.last.label : null;
  }

  String? _activeTankIdAt(int t) {
    for (final entry in _activeTankIntervals.entries) {
      for (final window in entry.value) {
        if (t >= window.start && t < window.end) return entry.key;
      }
    }
    // Same exclusive-end handling for the final second.
    String? lastTank;
    var lastEnd = -1;
    for (final entry in _activeTankIntervals.entries) {
      for (final window in entry.value) {
        if (window.end > lastEnd) {
          lastEnd = window.end;
          lastTank = entry.key;
        }
      }
    }
    return t >= lastEnd && lastEnd >= 0 ? lastTank : null;
  }
}
```

Adjust `buildActiveTankIntervals` call and the interval record field names (`start`/`end`) to match the real signature at `gas_usage_segments_service.dart:140-177`, and `GasUsageSegment` field names at lines 8-24. Do NOT re-derive gas logic — reuse those services.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/widgets/perdix_overlay/ test/features/media/presentation/widgets/perdix_overlay/
git commit -m "feat: add PerdixFaceResolver for media playback readouts"
```

---

### Task 3: PerdixFace widget + l10n labels

The presentational Perdix screen: translucent panel, three collapsing rows, deco swap, color coding, unit-aware formatting.

**Files:**
- Create: `lib/features/media/presentation/widgets/perdix_overlay/perdix_face.dart`
- Modify: `lib/l10n/arb/app_en.arb` (+ the 10 other `app_*.arb` files)
- Test: `test/features/media/presentation/widgets/perdix_overlay/perdix_face_test.dart`

**Interfaces:**
- Consumes: `PerdixFaceData` (Task 2), `AppSettings`, `UnitFormatter` (`lib/core/utils/unit_formatter.dart:10` — `formatDepth(double?, {int decimals = 1})`, `formatTemperature(double?, {int decimals = 0})`, `formatPressure(double?, {int decimals = 0})`), `context.l10n` extension (`lib/l10n/l10n_extension.dart`).
- Produces (used by Task 4):
```dart
class PerdixFace extends StatelessWidget {
  const PerdixFace({
    super.key,
    required this.data,
    required this.settings,
    this.width = 300,
  });
}
```

- [ ] **Step 1: Add the ARB strings**

Add to `lib/l10n/arb/app_en.arb` (keys sorted into place alphabetically near other `media_` keys):

```json
"media_perdixOverlay_labelDepth": "DEPTH",
"media_perdixOverlay_labelNdl": "NDL",
"media_perdixOverlay_labelTime": "TIME",
"media_perdixOverlay_labelStop": "STOP",
"media_perdixOverlay_labelTts": "TTS",
"media_perdixOverlay_labelMax": "MAX",
"media_perdixOverlay_labelTemp": "TEMP",
"media_perdixOverlay_labelGas": "GAS",
"media_perdixOverlay_labelTank": "TANK",
"media_perdixOverlay_labelCns": "CNS",
"media_perdixOverlay_labelPpo2": "PPO2",
"media_perdixOverlay_toggleTooltip": "Dive computer overlay"
```

Add the same keys to all 10 other ARB files. NDL, TTS, MAX, STOP, GAS, TANK, CNS, PPO2 are standard dive-computer abbreviations — keep them unchanged in every locale. Translate DEPTH/TIME/TEMP and the tooltip:

| Locale | labelDepth | labelTime | labelTemp | toggleTooltip |
|---|---|---|---|---|
| de | TIEFE | ZEIT | TEMP | Tauchcomputer-Overlay |
| es | PROF | TIEMPO | TEMP | Superposicion de ordenador de buceo |
| fr | PROF | TEMPS | TEMP | Superposition ordinateur de plongee |
| it | PROF | TEMPO | TEMP | Overlay computer subacqueo |
| pt | PROF | TEMPO | TEMP | Sobreposicao de computador de mergulho |
| nl | DIEPTE | TIJD | TEMP | Duikcomputer-overlay |
| he | עומק | זמן | טמפ | שכבת מחשב צלילה |
| hu | MELYS | IDO | HOM | Buvarszamitogep-retegek |
| zh | 深度 | 时间 | 温度 | 潜水电脑叠加层 |
| ar | العمق | الوقت | الحرارة | طبقة كمبيوتر الغوص |

(Use proper accented characters in the actual ARB files — es `Superposición`, fr `PROF`/`Superposition ordinateur de plongée`, hu `MÉLYS`/`IDŐ`/`HŐM`/`Búvárszámítógép-réteg`, pt `Sobreposição`. The table above is ASCII-limited; the ARBs must not be.)

Then run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/arb/app_localizations*.dart` with the new getters.

- [ ] **Step 2: Write the failing widget tests**

Create `test/features/media/presentation/widgets/perdix_overlay/perdix_face_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Widget host(PerdixFace face) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: face)),
    );

Color? textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

void main() {
  const settings = AppSettings();

  testWidgets('renders full three-row face', (tester) async {
    const data = PerdixFaceData(
      diveTimeSeconds: 1935, // 32:15
      depthMeters: 18.4,
      runningMaxDepthMeters: 24.1,
      ndlSeconds: 24 * 60,
      temperatureCelsius: 22.0,
      gasLabel: 'Air',
      tankPressureBar: 142.0,
      cnsPercent: 8.0,
      ppO2Bar: 0.85,
    );
    await tester.pumpWidget(host(const PerdixFace(data: data, settings: settings)));
    expect(find.text('DEPTH'), findsOneWidget);
    expect(find.text('NDL'), findsOneWidget);
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('32:15'), findsOneWidget);
    expect(find.text('24'), findsOneWidget); // NDL minutes
    expect(find.text('MAX'), findsOneWidget);
    expect(find.text('GAS'), findsOneWidget);
    expect(find.text('Air'), findsOneWidget);
    expect(find.text('TANK'), findsOneWidget);
    expect(find.text('CNS'), findsOneWidget);
    expect(find.text('8%'), findsOneWidget);
    expect(find.text('PPO2'), findsOneWidget);
    expect(find.text('1.85'), findsNothing);
    expect(find.text('0.85'), findsOneWidget);
  });

  testWidgets('third row collapses when tank/cns/ppO2 all absent', (tester) async {
    const data = PerdixFaceData(
      diveTimeSeconds: 600,
      depthMeters: 10.0,
      runningMaxDepthMeters: 12.0,
      ndlSeconds: 1800,
      temperatureCelsius: 24.0,
    );
    await tester.pumpWidget(host(const PerdixFace(data: data, settings: settings)));
    expect(find.text('TANK'), findsNothing);
    expect(find.text('CNS'), findsNothing);
    expect(find.text('PPO2'), findsNothing);
    expect(find.text('GAS'), findsNothing); // no gas label either
  });

  testWidgets('deco swap: NDL cell becomes STOP, MAX becomes TTS', (tester) async {
    const data = PerdixFaceData(
      diveTimeSeconds: 2400,
      depthMeters: 21.0,
      runningMaxDepthMeters: 45.0,
      ceilingMeters: 5.2, // rounds UP to 6 m stop
      ttsSeconds: 14 * 60,
      inDeco: true,
    );
    await tester.pumpWidget(host(const PerdixFace(data: data, settings: settings)));
    expect(find.text('STOP'), findsOneWidget);
    expect(find.text('NDL'), findsNothing);
    expect(find.text('6m'), findsOneWidget); // UnitFormatter.formatDepth(6.0, decimals: 0)
    expect(find.text('TTS'), findsOneWidget);
    expect(find.text('MAX'), findsNothing);
    expect(find.text('14'), findsOneWidget); // TTS minutes
  });

  testWidgets('NDL color thresholds', (tester) async {
    PerdixFaceData ndl(int seconds) => PerdixFaceData(
          diveTimeSeconds: 0,
          depthMeters: 18.0,
          ndlSeconds: seconds,
        );
    await tester.pumpWidget(host(PerdixFace(data: ndl(6 * 60), settings: settings)));
    expect(textColor(tester, '6'), PerdixFace.perdixGreen);
    await tester.pumpWidget(host(PerdixFace(data: ndl(4 * 60), settings: settings)));
    expect(textColor(tester, '4'), PerdixFace.perdixYellow);
    await tester.pumpWidget(host(PerdixFace(data: ndl(0), settings: settings)));
    expect(textColor(tester, '0'), PerdixFace.perdixRed);
  });

  testWidgets('ppO2 color thresholds', (tester) async {
    PerdixFaceData ppo2(double v) => PerdixFaceData(
          diveTimeSeconds: 0,
          depthMeters: 18.0,
          ppO2Bar: v,
        );
    await tester.pumpWidget(host(PerdixFace(data: ppo2(1.2), settings: settings)));
    expect(textColor(tester, '1.20'), Colors.white);
    await tester.pumpWidget(host(PerdixFace(data: ppo2(1.45), settings: settings)));
    expect(textColor(tester, '1.45'), PerdixFace.perdixYellow);
    await tester.pumpWidget(host(PerdixFace(data: ppo2(1.65), settings: settings)));
    expect(textColor(tester, '1.65'), PerdixFace.perdixRed);
  });

  testWidgets('imperial units respected', (tester) async {
    // Check the AppSettings unit-field API in settings_providers.dart and
    // construct imperial settings accordingly (depth feet, temp F, pressure psi).
    final imperial = const AppSettings().copyWith(
      depthUnit: DepthUnit.feet,
      temperatureUnit: TemperatureUnit.fahrenheit,
      pressureUnit: PressureUnit.psi,
    );
    const data = PerdixFaceData(
      diveTimeSeconds: 60,
      depthMeters: 18.4,
      runningMaxDepthMeters: 24.1,
      temperatureCelsius: 22.0,
      tankPressureBar: 142.0,
    );
    await tester.pumpWidget(host(PerdixFace(data: data, settings: imperial)));
    // 18.4 m = 60.4 ft; exact strings come from UnitFormatter — assert via
    // its own output so the test does not hardcode conversion math:
    // expect(find.text(UnitFormatter(imperial).formatDepth(18.4)), findsOneWidget);
    expect(find.text(UnitFormatter(imperial).formatDepth(18.4)), findsOneWidget);
    expect(find.text(UnitFormatter(imperial).formatTemperature(22.0)), findsOneWidget);
  });
}
```

Add the needed import for `UnitFormatter` (`package:submersion/core/utils/unit_formatter.dart`) and verify the unit-enum names (`DepthUnit.feet` etc.) in `settings_providers.dart`; fix the test's enum references to the real names, keeping the assertions.

- [ ] **Step 3: Run tests to verify they fail**

Run: `flutter test test/features/media/presentation/widgets/perdix_overlay/perdix_face_test.dart`
Expected: FAIL — `perdix_face.dart` does not exist.

- [ ] **Step 4: Implement PerdixFace**

Create `lib/features/media/presentation/widgets/perdix_overlay/perdix_face.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../../core/utils/unit_formatter.dart';
import '../../../../../l10n/l10n_extension.dart';
import '../../../settings/presentation/providers/settings_providers.dart'
    show AppSettings; // adjust import to wherever AppSettings lives
import 'perdix_face_resolver.dart';

/// Perdix-style dive computer face. Pure presentation: renders one
/// [PerdixFaceData] snapshot with real-device layout and color conventions.
/// No Shearwater branding (trademark).
class PerdixFace extends StatelessWidget {
  const PerdixFace({
    super.key,
    required this.data,
    required this.settings,
    this.width = 300,
  });

  final PerdixFaceData data;
  final AppSettings settings;
  final double width;

  static const perdixGreen = Color(0xFF35D43C);
  static const perdixYellow = Color(0xFFFFD83A);
  static const perdixRed = Color(0xFFFF4A3A);
  static const perdixCyan = Color(0xFF9ADCF0);
  static const _panelColor = Color(0x8C000000); // black at 55% opacity

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(settings);
    final cells = _buildCells(l10n, units);
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 3) {
      final rowCells = cells.sublist(i, (i + 3).clamp(0, cells.length));
      rows.add(Row(
        children: [
          for (final cell in rowCells) Expanded(child: cell),
          for (var j = rowCells.length; j < 3; j++) const Expanded(child: SizedBox()),
        ],
      ));
    }
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            rows[i],
          ],
        ],
      ),
    );
  }

  /// Cell order: row 1 = DEPTH | NDL-or-STOP | TIME (always present),
  /// row 2 = MAX-or-TTS | TEMP | GAS, row 3 = TANK | CNS | PPO2.
  /// Rows 2-3 include only cells with data; a fully empty row vanishes.
  List<Widget> _buildCells(dynamic l10n, UnitFormatter units) {
    final cells = <Widget>[
      _cell(
        l10n.media_perdixOverlay_labelDepth,
        units.formatDepth(data.depthMeters ?? 0),
        Colors.white,
        large: true,
      ),
      if (data.inDeco && data.ceilingMeters != null)
        _cell(
          l10n.media_perdixOverlay_labelStop,
          units.formatDepth(_stopDepthMeters(data.ceilingMeters!), decimals: 0),
          perdixRed,
          large: true,
        )
      else if (data.ndlSeconds != null)
        _cell(
          l10n.media_perdixOverlay_labelNdl,
          '${(data.ndlSeconds! ~/ 60)}',
          _ndlColor(data.ndlSeconds!),
          large: true,
        )
      else
        const SizedBox(),
      _cell(
        l10n.media_perdixOverlay_labelTime,
        _formatMinSec(data.diveTimeSeconds),
        Colors.white,
        large: true,
      ),
    ];

    final row2 = <Widget>[
      if (data.inDeco && data.ttsSeconds != null)
        _cell(l10n.media_perdixOverlay_labelTts, '${data.ttsSeconds! ~/ 60}', Colors.white)
      else if (!data.inDeco && data.runningMaxDepthMeters != null)
        _cell(l10n.media_perdixOverlay_labelMax,
            units.formatDepth(data.runningMaxDepthMeters), Colors.white),
      if (data.temperatureCelsius != null)
        _cell(l10n.media_perdixOverlay_labelTemp,
            units.formatTemperature(data.temperatureCelsius), Colors.white),
      if (data.gasLabel != null)
        _cell(l10n.media_perdixOverlay_labelGas, data.gasLabel!, Colors.white),
    ];

    final row3 = <Widget>[
      if (data.tankPressureBar != null)
        _cell(l10n.media_perdixOverlay_labelTank,
            units.formatPressure(data.tankPressureBar), Colors.white),
      if (data.cnsPercent != null)
        _cell(l10n.media_perdixOverlay_labelCns,
            '${data.cnsPercent!.round()}%', _cnsColor(data.cnsPercent!)),
      if (data.ppO2Bar != null)
        _cell(l10n.media_perdixOverlay_labelPpo2,
            data.ppO2Bar!.toStringAsFixed(2), _ppO2Color(data.ppO2Bar!)),
    ];

    return [...cells, ...row2, ...row3];
  }

  /// Ceiling rounded UP to the next stop increment: 3 m metric, 10 ft imperial.
  double _stopDepthMeters(double ceilingMeters) {
    if (settings.depthUnit == DepthUnit.feet) {
      final feet = ceilingMeters * 3.280839895;
      final stopFeet = (feet / 10).ceil() * 10;
      return stopFeet / 3.280839895;
    }
    return ((ceilingMeters / 3).ceil() * 3).toDouble();
  }

  Color _ndlColor(int seconds) {
    if (seconds <= 0) return perdixRed;
    if (seconds <= 5 * 60) return perdixYellow;
    return perdixGreen;
  }

  Color _ppO2Color(double bar) {
    if (bar >= 1.6) return perdixRed;
    if (bar >= 1.4) return perdixYellow;
    return Colors.white;
  }

  Color _cnsColor(double percent) {
    if (percent >= 80) return perdixRed;
    if (percent >= 50) return perdixYellow;
    return Colors.white;
  }

  static String _formatMinSec(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _cell(String label, String value, Color color, {bool large = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 0.5,
            color: perdixCyan,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: large ? 28 : 15,
            fontWeight: FontWeight.w700,
            height: 1.05,
            color: color,
          ),
        ),
      ],
    );
  }
}
```

Implementation notes:
- Fix the `AppSettings`/`DepthUnit` imports to the real declaring files (`AppSettings` lives in `settings_providers.dart`; the unit enums may live in a separate units file — follow how `unit_formatter.dart` imports them).
- Row collapse: build row 2 and row 3 as their own lists (as shown) and only add a `Row` when the list is non-empty — adjust `_buildCells`/`build` so empty rows produce no `Row` widget at all. Keep row 1 always present.
- The type of `l10n` should be `AppLocalizations`, not `dynamic` — import `package:submersion/l10n/arb/app_localizations.dart`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/media/presentation/widgets/perdix_overlay/perdix_face_test.dart`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/widgets/perdix_overlay/ lib/l10n/ test/features/media/presentation/widgets/perdix_overlay/
git commit -m "feat: add PerdixFace dive computer display widget with l10n labels"
```

---

### Task 4: DraggablePerdixOverlay wrapper

Drag + playback clock. Takes a generic `Listenable` + position getter instead of `VideoPlayerController` so tests need no real video.

**Files:**
- Create: `lib/features/media/presentation/widgets/perdix_overlay/draggable_perdix_overlay.dart`
- Test: `test/features/media/presentation/widgets/perdix_overlay/draggable_perdix_overlay_test.dart`
- Reference (copy pattern, do not modify): `lib/features/dive_log/presentation/widgets/draggable_readout_card.dart`

**Interfaces:**
- Consumes: `PerdixFaceResolver`, `PerdixFace` (Tasks 2-3).
- Produces (used by Task 5):
```dart
class DraggablePerdixOverlay extends StatefulWidget {
  const DraggablePerdixOverlay({
    super.key,
    required this.resolver,
    required this.baseElapsedSeconds, // enrichment.elapsedSeconds
    required this.settings,
    this.playback,        // Listenable ticking with playback (VideoPlayerController); null = static photo mode
    this.positionGetter,  // Duration Function(); required when playback != null
    this.initialFraction, // persisted Offset(x,y) fractions or null (default corner top-right)
    this.onDragEnd,       // ValueChanged<Offset> — persist fractions
  });
}
```

- [ ] **Step 1: Write the failing widget tests**

Create `test/features/media/presentation/widgets/perdix_overlay/draggable_perdix_overlay_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/draggable_perdix_overlay.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

DiveProfilePoint p(int t, double depth) =>
    DiveProfilePoint(timestamp: t, depth: depth);

Widget host(Widget overlay) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox.expand(child: Stack(children: [overlay])),
      ),
    );

void main() {
  final resolver = PerdixFaceResolver(
    profile: [p(0, 0.0), p(60, 10.0), p(120, 20.0), p(180, 15.0)],
  );
  const settings = AppSettings();

  testWidgets('static photo mode renders the sample at baseElapsedSeconds',
      (tester) async {
    await tester.pumpWidget(host(DraggablePerdixOverlay(
      resolver: resolver,
      baseElapsedSeconds: 120,
      settings: settings,
    )));
    expect(find.text('20.0m'), findsOneWidget);
    expect(find.text('2:00'), findsOneWidget);
  });

  testWidgets('video mode advances with the playback listenable',
      (tester) async {
    final position = ValueNotifier<Duration>(Duration.zero);
    await tester.pumpWidget(host(DraggablePerdixOverlay(
      resolver: resolver,
      baseElapsedSeconds: 60,
      settings: settings,
      playback: position,
      positionGetter: () => position.value,
    )));
    expect(find.text('10.0m'), findsOneWidget); // t = 60
    position.value = const Duration(seconds: 60);
    await tester.pump();
    expect(find.text('20.0m'), findsOneWidget); // t = 120
  });

  testWidgets('drag moves the card and reports final fraction', (tester) async {
    Offset? reported;
    await tester.pumpWidget(host(DraggablePerdixOverlay(
      resolver: resolver,
      baseElapsedSeconds: 0,
      settings: settings,
      initialFraction: const Offset(0, 0),
      onDragEnd: (f) => reported = f,
    )));
    final before = tester.getTopLeft(find.byType(DraggablePerdixOverlay));
    await tester.drag(find.text('DEPTH'), const Offset(120, 80));
    await tester.pumpAndSettle();
    expect(reported, isNotNull);
    expect(reported!.dx, greaterThan(0));
    expect(reported!.dy, greaterThan(0));
    expect(reported!.dx, lessThanOrEqualTo(1.0));
    expect(reported!.dy, lessThanOrEqualTo(1.0));
    final after = tester.getTopLeft(find.byType(DraggablePerdixOverlay));
    expect(after, isNot(before));
  });
}
```

(If the drag target `find.text('DEPTH')` is ambiguous, drag `find.byType(PerdixFace)` instead.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/media/presentation/widgets/perdix_overlay/draggable_perdix_overlay_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement the wrapper**

Create `lib/features/media/presentation/widgets/perdix_overlay/draggable_perdix_overlay.dart`. Copy the fraction/drag mechanics from `DraggableReadoutCard` (`draggable_readout_card.dart` — `_fraction` state, `_sanitize` for NaN guards, `_onPanUpdate` converting pixel deltas to fractions of the movable range via `LayoutBuilder` constraints minus card size, `Align` with `FractionalOffset`):

```dart
import 'package:flutter/material.dart';

import '../../../settings/presentation/providers/settings_providers.dart'
    show AppSettings; // adjust to real AppSettings location
import 'perdix_face.dart';
import 'perdix_face_resolver.dart';

/// Draggable host for [PerdixFace]. In video mode ([playback] non-null) the
/// face re-resolves each playback tick; in photo mode it renders one static
/// sample. Drag mechanics mirror DraggableReadoutCard: position is a
/// fraction of the movable range, persisted via [onDragEnd].
class DraggablePerdixOverlay extends StatefulWidget {
  const DraggablePerdixOverlay({
    super.key,
    required this.resolver,
    required this.baseElapsedSeconds,
    required this.settings,
    this.playback,
    this.positionGetter,
    this.initialFraction,
    this.onDragEnd,
  }) : assert(playback == null || positionGetter != null,
            'positionGetter is required in video mode');

  final PerdixFaceResolver resolver;
  final int baseElapsedSeconds;
  final AppSettings settings;
  final Listenable? playback;
  final Duration Function()? positionGetter;
  final Offset? initialFraction;
  final ValueChanged<Offset>? onDragEnd;

  @override
  State<DraggablePerdixOverlay> createState() => _DraggablePerdixOverlayState();
}

class _DraggablePerdixOverlayState extends State<DraggablePerdixOverlay> {
  static const _cardWidth = 300.0;
  static const _defaultFraction = Offset(1.0, 0.0); // top-right corner

  late Offset _fraction = _sanitize(widget.initialFraction);

  Offset _sanitize(Offset? value) {
    if (value == null) return _defaultFraction;
    final x = value.dx.isFinite ? value.dx.clamp(0.0, 1.0) : 1.0;
    final y = value.dy.isFinite ? value.dy.clamp(0.0, 1.0) : 0.0;
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Align(
          alignment: FractionalOffset(_fraction.dx, _fraction.dy),
          child: GestureDetector(
            onPanUpdate: (details) => _onPanUpdate(details, constraints),
            onPanEnd: (_) => widget.onDragEnd?.call(_fraction),
            child: _buildFace(),
          ),
        );
      },
    );
  }

  void _onPanUpdate(DragUpdateDetails details, BoxConstraints constraints) {
    // Movable range = stack size minus the card footprint; guard divide-by-zero
    // on tiny panes. Mirror DraggableReadoutCard's delta-to-fraction math,
    // using the face's rendered size (context.size of the child) where the
    // reference implementation does.
    final rangeX = (constraints.maxWidth - _cardWidth).clamp(1.0, double.infinity);
    final rangeY = (constraints.maxHeight - _faceHeight()).clamp(1.0, double.infinity);
    setState(() {
      _fraction = Offset(
        (_fraction.dx + details.delta.dx / rangeX).clamp(0.0, 1.0),
        (_fraction.dy + details.delta.dy / rangeY).clamp(0.0, 1.0),
      );
    });
  }

  double _faceHeight() {
    final box = context.findRenderObject() as RenderBox?;
    return box?.size.height ?? 120.0;
  }

  Widget _buildFace() {
    final playback = widget.playback;
    if (playback == null) {
      return PerdixFace(
        data: widget.resolver.resolve(widget.baseElapsedSeconds),
        settings: widget.settings,
      );
    }
    return AnimatedBuilder(
      animation: playback,
      builder: (context, _) {
        final position = widget.positionGetter!();
        final t = widget.baseElapsedSeconds + position.inMilliseconds ~/ 1000;
        return PerdixFace(
          data: widget.resolver.resolve(t),
          settings: widget.settings,
        );
      },
    );
  }
}
```

Before finalizing, read `draggable_readout_card.dart` lines 41-110 and align `_onPanUpdate`/size measurement with how it actually measures the card (it uses the card's own key/size rather than the whole render object — copy that approach so drag speed feels identical).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media/presentation/widgets/perdix_overlay/draggable_perdix_overlay_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/widgets/perdix_overlay/ test/features/media/presentation/widgets/perdix_overlay/
git commit -m "feat: add DraggablePerdixOverlay drag and playback wrapper"
```

---

### Task 5: PhotoViewerPage integration

Controller hoisting, availability gate, toggle button, mounting, position persistence.

**Files:**
- Modify: `lib/features/media/presentation/pages/photo_viewer_page.dart`
- Test: `test/features/media/presentation/pages/photo_viewer_perdix_test.dart` (new)
- Reference: `test/features/media/presentation/pages/photo_viewer_lightroom_test.dart` (copy setup pattern)

**Interfaces:**
- Consumes: everything from Tasks 1-4, plus:
  - `diveProvider(diveId)` — `FutureProvider.family<Dive?, String>` (`dive_providers.dart:198`); hydrated `Dive` has `.profile`, `.tanks`
  - `activeDiveSourceProvider(diveId)`, `sourceProfilesProvider(diveId)`, `sourceProfileAnalysisProvider((diveId:, sourceId:))` — copy the profile/analysis selection pattern from `fullscreen_profile_page.dart:121-244` so analysis curves stay index-aligned with the profile passed to the resolver (this is the documented `resolveSample` caveat)
  - `gasSwitchesProvider(diveId)` (`gas_switch_providers.dart:9`), `tankPressuresProvider(diveId)` (`dive_providers.dart:996`)
  - `MatchConfidence` from `lib/features/media/domain/entities/media_item.dart:33`
- Produces: user-facing feature; no downstream consumers.

- [ ] **Step 1: Write the failing widget tests**

Create `test/features/media/presentation/pages/photo_viewer_perdix_test.dart`, cloning the setup skeleton of `photo_viewer_lightroom_test.dart` (test database `setUpTestDatabase()`, `SharedPreferences.setMockInitialValues`, `tester.runAsync` pump helper, `ProviderScope` overrides, `MaterialApp` with l10n delegates). Key differences: also override `diveProvider`, `sourceProfilesProvider`, `gasSwitchesProvider`, and `tankPressuresProvider`, and build media items WITH enrichment.

```dart
// Fixtures (adapt entity constructor params to their real signatures):
final profile = [
  DiveProfilePoint(timestamp: 0, depth: 0.0),
  DiveProfilePoint(timestamp: 60, depth: 10.0, temperature: 22.0),
  DiveProfilePoint(timestamp: 120, depth: 20.0, temperature: 21.0),
];
// dive: a domain Dive with id 'd1' and profile above (check Dive constructor
// for required fields; reuse any existing test factory helpers if present).
// enriched photo MediaItem 'm1': enrichment = MediaEnrichment(
//   mediaId: 'm1', diveId: 'd1', elapsedSeconds: 60,
//   matchConfidence: MatchConfidence.exact, ... required fields ...)
// unenriched photo MediaItem 'm2': enrichment = null.

// Overrides for every test:
//   sharedPreferencesProvider.overrideWithValue(prefs),
//   mediaForDiveProvider('d1').overrideWith((ref) async => [media]),
//   diveProvider('d1').overrideWith((ref) async => dive),
//   sourceProfilesProvider('d1').overrideWith((ref) async => {}),
//   gasSwitchesProvider('d1').overrideWith((ref) async => []),
//   tankPressuresProvider('d1').overrideWith((ref) async => {}),
// (sourceProfileAnalysisProvider and activeDiveSourceProvider: override the
//  analysis to null via the same overrideWith pattern; check their key types.)

testWidgets('toggle button hidden when media has no enrichment', (tester) async {
  await pumpViewer(tester, media: unenrichedItem);
  expect(find.byTooltip('Dive computer overlay'), findsNothing);
  expect(find.text('DEPTH'), findsNothing);
});

testWidgets('toggle button shown for enriched media; toggles the face', (tester) async {
  await pumpViewer(tester, media: enrichedItem);
  expect(find.byTooltip('Dive computer overlay'), findsOneWidget);
  expect(find.text('DEPTH'), findsNothing); // disabled by default
  await tester.tap(find.byTooltip('Dive computer overlay'));
  await tester.pumpAndSettle();
  expect(find.text('DEPTH'), findsOneWidget);
  expect(find.text('10.0m'), findsOneWidget); // static sample at elapsed 60
  await tester.tap(find.byTooltip('Dive computer overlay'));
  await tester.pumpAndSettle();
  expect(find.text('DEPTH'), findsNothing);
});

testWidgets('face visible on enriched photo when setting pre-enabled', (tester) async {
  SharedPreferences.setMockInitialValues({'perdix_overlay_enabled': true});
  // re-obtain prefs after setMockInitialValues
  await pumpViewer(tester, media: enrichedItem);
  expect(find.text('DEPTH'), findsOneWidget);
});

testWidgets('face stays visible when viewer chrome is hidden', (tester) async {
  SharedPreferences.setMockInitialValues({'perdix_overlay_enabled': true});
  await pumpViewer(tester, media: enrichedItem);
  // Tap the photo to hide top/bottom overlays.
  await tester.tapAt(tester.getCenter(find.byType(PhotoViewerPage)));
  await tester.pumpAndSettle();
  expect(find.byIcon(Icons.close), findsNothing); // chrome hidden
  expect(find.text('DEPTH'), findsOneWidget);     // Perdix face still there
});
```

Write these as real compiling tests: build the fixtures with the actual entity constructors (check `MediaEnrichment` and `Dive` required params), and put the shared override list + pump helper in a local function as the Lightroom test does.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/media/presentation/pages/photo_viewer_perdix_test.dart`
Expected: FAIL — no toggle tooltip / DEPTH text found.

- [ ] **Step 3: Implement the integration**

In `lib/features/media/presentation/pages/photo_viewer_page.dart`:

1. **Controller hoisting.** Add to `_PhotoViewerPageState`:
```dart
final Map<String, VideoPlayerController> _videoControllers = {};

void _onVideoControllerChanged(String mediaId, VideoPlayerController? controller) {
  if (!mounted) return;
  setState(() {
    if (controller == null) {
      _videoControllers.remove(mediaId);
    } else {
      _videoControllers[mediaId] = controller;
    }
  });
}
```
Extend `_VideoItem` with `required this.onControllerChanged` (`void Function(String mediaId, VideoPlayerController? controller)`), thread it from `_PhotoGallery` (add the same field there and pass `widget.onControllerChanged` down; the page passes `_onVideoControllerChanged`). In `_VideoItemState._initializeVideo()`, after the controller is stored in state, call `widget.onControllerChanged(widget.item.id, controller);`. In `_VideoItemState.dispose()`, call `widget.onControllerChanged(widget.item.id, null);` BEFORE `_controller?.dispose()`. If Flutter reports setState-during-build from the init path, wrap the page-side setState in `WidgetsBinding.instance.addPostFrameCallback`.

2. **Data for the resolver** (in `_PhotoViewerPageState.build`, next to the existing `diveProvider` watch at ~line 81):
```dart
final activeSourceId = ref.watch(activeDiveSourceProvider(widget.diveId));
final analysis = ref
    .watch(sourceProfileAnalysisProvider(
        (diveId: widget.diveId, sourceId: activeSourceId)))
    .value;
final sourceProfiles = ref.watch(sourceProfilesProvider(widget.diveId)).value;
final gasSwitches =
    ref.watch(gasSwitchesProvider(widget.diveId)).value ?? const [];
final tankPressures = ref.watch(tankPressuresProvider(widget.diveId)).value;
```
Copy the exact provider key shapes and the `chartProfile` selection (active source's points when >= 2 sources, else `dive.profile`) from `fullscreen_profile_page.dart:121-244`. Build the resolver in `build` (it is only rebuilt on page-level setState, not per video frame):
```dart
final perdixProfile = /* chartProfile per the pattern above */;
final perdixResolver = PerdixFaceResolver(
  profile: perdixProfile,
  analysis: analysis,
  tanks: dive?.tanks ?? const [],
  gasSwitches: gasSwitches,
  tankPressures: tankPressures,
);
```

3. **Availability gate:**
```dart
final perdixAvailable = enrichment?.elapsedSeconds != null &&
    enrichment!.matchConfidence != MatchConfidence.noProfile &&
    perdixResolver.isAvailable;
```

4. **Toggle button.** Add to `_TopOverlay` constructor: `required this.showPerdixToggle, required this.perdixEnabled, required this.onTogglePerdix`. In its `Row`, after the write-metadata button:
```dart
if (showPerdixToggle)
  IconButton(
    icon: Icon(
      Icons.watch,
      color: perdixEnabled ? Theme.of(context).colorScheme.primary : Colors.white,
    ),
    tooltip: context.l10n.media_perdixOverlay_toggleTooltip,
    onPressed: onTogglePerdix,
  ),
```
Page passes `showPerdixToggle: perdixAvailable`, `perdixEnabled: settings.perdixOverlayEnabled`, and:
```dart
onTogglePerdix: () => ref
    .read(settingsProvider.notifier)
    .setPerdixOverlayEnabled(!settings.perdixOverlayEnabled),
```

5. **Mounting — OUTSIDE the `if (_showOverlay)` block** (critical: viewer chrome hides during video playback; the Perdix face must not). Add as the last child of the page `Stack` (~after line 190):
```dart
if (perdixAvailable && settings.perdixOverlayEnabled)
  DraggablePerdixOverlay(
    key: ValueKey(
        'perdix-${currentItem.id}-${settings.perdixOverlayX}-${settings.perdixOverlayY == null}'),
    resolver: perdixResolver,
    baseElapsedSeconds: enrichment.elapsedSeconds!,
    settings: settings,
    playback: currentItem.isVideo ? _videoControllers[currentItem.id] : null,
    positionGetter: currentItem.isVideo
        ? () =>
            _videoControllers[currentItem.id]?.value.position ?? Duration.zero
        : null,
    initialFraction: (settings.perdixOverlayX != null &&
            settings.perdixOverlayY != null)
        ? Offset(settings.perdixOverlayX!, settings.perdixOverlayY!)
        : null,
    onDragEnd: (fraction) => ref
        .read(settingsProvider.notifier)
        .setPerdixOverlayPosition(fraction.dx, fraction.dy),
  ),
```
Key notes: the `ValueKey` re-seeds position only when the persisted seed transitions from null (late settings load), mirroring the fullscreen page's re-key trick at `fullscreen_profile_page.dart:411-434` — copy that key recipe exactly rather than the sketch above. When the current item is a video whose controller has not initialized yet, `playback` is null and the face renders the static capture-instant sample until the controller arrives (acceptable; it appears in the map via `_onVideoControllerChanged`, which triggers setState). Guard: if `currentItem.isVideo && _videoControllers[currentItem.id] == null`, pass `playback: null, positionGetter: null` (already the effect of the map lookup — make sure both are null together to satisfy the assert).

6. Imports: `draggable_perdix_overlay.dart`, `perdix_face_resolver.dart`, the dive_log providers used above, and `MatchConfidence` (already imported via media_item entity).

- [ ] **Step 4: Run the new tests and the existing viewer test**

Run: `flutter test test/features/media/presentation/pages/photo_viewer_perdix_test.dart test/features/media/presentation/pages/photo_viewer_lightroom_test.dart`
Expected: PASS (both files; the Lightroom test guards against regressions in `_TopOverlay`).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add -u lib test
git commit -m "feat: add Perdix dive computer overlay to photo viewer (#168)"
```

---

### Task 6: Verification pass

**Files:** none new.

- [ ] **Step 1: Formatting and static analysis**

Run: `dart format .` — expected: no files changed (fix and re-commit if any).
Run: `flutter analyze` — bare, no pipes. Expected: `No issues found!`

- [ ] **Step 2: Run all feature tests**

Run:
```bash
flutter test \
  test/features/settings/presentation/providers/settings_notifier_real_test.dart \
  test/features/media/presentation/widgets/perdix_overlay/ \
  test/features/media/presentation/pages/
```
Expected: all PASS.

- [ ] **Step 3: Manual smoke on macOS**

Before launching, confirm no other `flutter run -d macos` instance is active (two instances kill each other — check with the user first if unsure). Then:
```bash
flutter run -d macos
```
Checklist: open a dive with an enriched video → toggle button appears → enable → face shows and values move during playback → drag it, close and reopen viewer, position and enabled state persist → seek the video, face follows → open an enriched photo, static face matches capture instant → open an unmatched photo/video, no toggle button → switch diver units to imperial, values reformat.

- [ ] **Step 4: Commit any fixes, then report**

Report results honestly (including anything skipped). Branch is ready for the finishing-a-development-branch flow (PR per repo conventions: no attribution lines in the PR body).
