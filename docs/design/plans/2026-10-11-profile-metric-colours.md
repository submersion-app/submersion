# Profile Metric Colours Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, in this session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver pick, per diver and synced, the colour of 20 dive-profile metrics from a 26-swatch palette, with swap-on-conflict, and have every place the metric's colour appears follow the choice.

**Architecture:** A pure value object (`ProfileMetricColorOverrides`) stores only the metrics a diver changed and owns the swap, Default/Auto and dedupe rules. Twenty nullable ARGB columns on `diver_settings` (schema v282) persist it, mapped in one helper file beside the repository. A resolved `ProfileMetricPalette` (overrides plus the theme's tertiary colour) is built where the chart, legend and options dialog render, and the pure line builders take colours as parameters.

**Tech Stack:** Flutter, Riverpod (`StateNotifier` settings), Drift (SQLite), fl_chart, gen-l10n ARB files.

**Spec:** `docs/design/specs/2026-10-11-profile-metric-colours-design.md`

## Global Constraints

- Issue #3012, release v1.8.2. Branch `ericgriffin/build-feature-3012-997f15`.
- Recolourable metrics, in this enum order: depth, temperature, pressure, heartRate, sac, maxDepth, ceiling, ndl, tts, gtr, cns, otu, ppO2, ppN2, ppHe, mod, density, gf, surfaceGf, meanDepth (20).
- Auto metrics (no fixed default): temperature (theme `colorScheme.tertiary`), pressure (per-gas colour; swatch `Colors.orange`).
- Palette, in order: the 18 fixed defaults in enum order, then `0xFF00838F`, `0xFFCDDC39`, then `0xFF689F38`, `0xFFFF7043`, `0xFF29B6F6`, `0xFFE040FB`, `0xFFF50057`, `0xFF00E676` (26).
- Legibility floors pinned by test: pairwise CIE76 ΔE >= 10; contrast >= 1.5:1 against `0xFFFFFFFF` and `0xFF121212`.
- Schema v282, additive; `minimumCompatibleSchemaVersion` stays 280. Columns `profile_color_<metric>` nullable INTEGER, no backfill.
- A null colour syncs as a value. Do NOT add the columns to `_nullMeansUnsetKeys`.
- UI strings use US spelling ("Color"), as the rest of the app does. No em dashes anywhere.
- `ListTile.trailing` holds only fixed-width widgets (guard `test/architecture/list_tile_trailing_width_test.dart`).
- New strings are translated into all 10 locales before `flutter gen-l10n` runs.
- `DiveProfileMiniChart` is unchanged.

## Review Focus

1. A diver on two devices resets on one: the null must reach the other. Pinned in Task 4 (sync test: incoming null clears).
2. Per-field conflict resolution leaves two metrics on one colour: the chart must still render distinct colours and the next pick must repair it. Pinned in Task 1 (dedupe tests) and Task 4 (notifier writes the dedupe fix).
3. Picking a colour for temperature or pressure while on Auto, when another metric holds that colour: the holder must get a free swatch, never a theme-dependent colour. Pinned in Task 1.
4. A colour pick tapped before the diver's settings finish loading must not be overwritten by the load. Pinned in Task 4 (setter awaits `settingsLoaded`, as `setTrendGapThreshold` does).
5. A multi-tank dive must keep per-gas pressure colours even with a custom pressure colour set. Pinned in Task 5.

---

### Task 1: Palette core (enum, swatches, overrides, resolved palette, swatch names)

**Files:**
- Create: `lib/features/dive_log/presentation/profile_colors/profile_metric.dart`
- Create: `lib/features/dive_log/presentation/profile_colors/profile_metric_swatches.dart`
- Create: `lib/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart`
- Create: `lib/features/dive_log/presentation/profile_colors/profile_metric_palette.dart`
- Create: `lib/features/dive_log/presentation/profile_colors/swatch_name.dart`
- Test: `test/features/dive_log/presentation/profile_colors/profile_metric_color_overrides_test.dart`
- Test: `test/features/dive_log/presentation/profile_colors/profile_metric_swatches_test.dart`
- Test: `test/features/dive_log/presentation/profile_colors/profile_metric_palette_test.dart`
- Test: `test/features/dive_log/presentation/profile_colors/swatch_name_test.dart`

**Interfaces:**
- Produces:
  - `enum ProfileMetric { depth, temperature, pressure, heartRate, sac, maxDepth, ceiling, ndl, tts, gtr, cns, otu, ppO2, ppN2, ppHe, mod, density, gf, surfaceGf, meanDepth }` with `Color? defaultColor`, `bool get isAuto`, `String get settingsKey` (`'profileColor' + capitalized name`, e.g. `profileColorPpO2`).
  - `const List<Color> profileMetricSwatches` (26).
  - `class ProfileMetricColorOverrides` with `const ProfileMetricColorOverrides()`, `static const none`, `factory .fromArgb(Map<ProfileMetric, int?>)`, `int? argbOf(ProfileMetric)`, `int? effectiveArgb(ProfileMetric)`, `bool get isEmpty`, `int get count`, `ProfileMetricColorOverrides withColor(ProfileMetric, Color?)`, `ProfileMetricColorOverrides deduped()`, `ProfileMetric? holderOf(int argb, {ProfileMetric? except})`, value `==`.
  - `class ProfileMetricPalette` with `ProfileMetricPalette({required ProfileMetricColorOverrides overrides, required Color temperatureAuto})`, `Color colorOf(ProfileMetric)`, `Color? get pressureOverride`, `Color rightAxisColor(ProfileRightAxisMetric)`.
  - `String swatchName(AppLocalizations l10n, Color color)`.

- [ ] **Step 1: Write the enum and swatch list (no logic to test-drive yet)**

`lib/features/dive_log/presentation/profile_colors/profile_metric.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

/// A profile-chart metric whose colour a diver can choose (issue #3012).
///
/// Metrics whose colour carries its own meaning are absent: the ascent-rate
/// bands and bars, the deco-stop band, O2 cell traces, gas-switch markers,
/// event lines (severity colours) and multi-tank pressure lines (gas colours).
enum ProfileMetric {
  depth(ProfileMetricColors.depth),

  /// Auto: follows the theme's `colorScheme.tertiary`.
  temperature(null),

  /// Auto: each tank's gas colour. A chosen colour applies on a single-tank
  /// dive only.
  pressure(null),
  heartRate(ProfileMetricColors.heartRate),
  sac(ProfileMetricColors.sac),
  maxDepth(ProfileMetricColors.maxDepth),
  ceiling(ProfileMetricColors.ceiling),
  ndl(ProfileMetricColors.ndl),
  tts(ProfileMetricColors.tts),
  gtr(ProfileMetricColors.gtr),
  cns(ProfileMetricColors.cns),
  otu(ProfileMetricColors.otu),
  ppO2(ProfileMetricColors.ppO2),
  ppN2(ProfileMetricColors.ppN2),
  ppHe(ProfileMetricColors.ppHe),
  mod(ProfileMetricColors.mod),
  density(ProfileMetricColors.density),
  gf(ProfileMetricColors.gf),
  surfaceGf(ProfileMetricColors.surfaceGf),
  meanDepth(ProfileMetricColors.meanDepth);

  const ProfileMetric(this.defaultColor);

  /// The colour shipped for this metric, or null for an Auto metric.
  final Color? defaultColor;

  bool get isAuto => defaultColor == null;

  /// The `diver_settings` column (Dart name) and sync key holding this
  /// metric's colour, e.g. `profileColorPpO2`.
  String get settingsKey =>
      'profileColor${name[0].toUpperCase()}${name.substring(1)}';
}
```

`lib/features/dive_log/presentation/profile_colors/profile_metric_swatches.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

/// Every colour a diver can give a profile metric (issue #3012), in the order
/// the picker shows them: the 18 fixed metric defaults, the two colours the
/// events and ascent-rate swatches keep, then six extras. Its length must
/// exceed the number of metrics so a swap always finds a free colour.
const List<Color> profileMetricSwatches = [
  ProfileMetricColors.depth,
  ProfileMetricColors.heartRate,
  ProfileMetricColors.sac,
  ProfileMetricColors.maxDepth,
  ProfileMetricColors.ceiling,
  ProfileMetricColors.ndl,
  ProfileMetricColors.tts,
  ProfileMetricColors.gtr,
  ProfileMetricColors.cns,
  ProfileMetricColors.otu,
  ProfileMetricColors.ppO2,
  ProfileMetricColors.ppN2,
  ProfileMetricColors.ppHe,
  ProfileMetricColors.mod,
  ProfileMetricColors.density,
  ProfileMetricColors.gf,
  ProfileMetricColors.surfaceGf,
  ProfileMetricColors.meanDepth,
  ProfileMetricColors.events,
  ProfileMetricColors.ascentRateLine,
  Color(0xFF689F38), // Light Green 700
  Color(0xFFFF7043), // Deep Orange 400
  Color(0xFF29B6F6), // Light Blue 400
  Color(0xFFE040FB), // Purple A200
  Color(0xFFF50057), // Pink A400
  Color(0xFF00E676), // Green A400
];
```

- [ ] **Step 2: Write the swatch tests**

`test/features/dive_log/presentation/profile_colors/profile_metric_swatches_test.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_swatches.dart';

double _lin(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

List<double> _lab(Color c) {
  final r = _lin(c.r), g = _lin(c.g), b = _lin(c.b);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
}

double _deltaE(Color a, Color b) {
  final la = _lab(a), lb = _lab(b);
  return math.sqrt(
    math.pow(la[0] - lb[0], 2) +
        math.pow(la[1] - lb[1], 2) +
        math.pow(la[2] - lb[2], 2),
  );
}

double _contrast(Color a, Color b) {
  final hi = math.max(a.computeLuminance(), b.computeLuminance());
  final lo = math.min(a.computeLuminance(), b.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('has 26 distinct swatches, more than there are metrics', () {
    final argb = profileMetricSwatches.map((c) => c.toARGB32()).toSet();
    expect(argb, hasLength(26));
    expect(argb.length, greaterThan(ProfileMetric.values.length));
  });

  test('holds every fixed metric default, so the defaults are one '
      'arrangement of the palette', () {
    final argb = profileMetricSwatches.map((c) => c.toARGB32()).toSet();
    for (final metric in ProfileMetric.values) {
      final d = metric.defaultColor;
      if (d == null) continue;
      expect(argb, contains(d.toARGB32()), reason: metric.name);
    }
  });

  test('no two swatches are closer than CIE76 deltaE 10', () {
    for (var i = 0; i < profileMetricSwatches.length; i++) {
      for (var j = i + 1; j < profileMetricSwatches.length; j++) {
        final a = profileMetricSwatches[i], b = profileMetricSwatches[j];
        expect(
          _deltaE(a, b),
          greaterThanOrEqualTo(10),
          reason: '#${a.toARGB32().toRadixString(16)} vs '
              '#${b.toARGB32().toRadixString(16)}',
        );
      }
    }
  });

  test('every swatch reads at least 1.5:1 on light and dark charts', () {
    const light = Color(0xFFFFFFFF);
    const dark = Color(0xFF121212);
    for (final c in profileMetricSwatches) {
      final hex = c.toARGB32().toRadixString(16);
      expect(_contrast(c, light), greaterThanOrEqualTo(1.5), reason: hex);
      expect(_contrast(c, dark), greaterThanOrEqualTo(1.5), reason: hex);
    }
  });

  test('settingsKey names the column the way Drift does', () {
    expect(ProfileMetric.depth.settingsKey, 'profileColorDepth');
    expect(ProfileMetric.ppO2.settingsKey, 'profileColorPpO2');
    expect(ProfileMetric.surfaceGf.settingsKey, 'profileColorSurfaceGf');
  });
}
```

- [ ] **Step 3: Run the swatch tests**

Run: `flutter test test/features/dive_log/presentation/profile_colors/profile_metric_swatches_test.dart`
Expected: PASS (the enum and list from Step 1 already satisfy them; they pin the legibility floors).

- [ ] **Step 4: Write the failing overrides tests**

`test/features/dive_log/presentation/profile_colors/profile_metric_color_overrides_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_swatches.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

int _argb(Color c) => c.toARGB32();
const _purpleA200 = Color(0xFFE040FB);

void main() {
  const none = ProfileMetricColorOverrides.none;

  group('withColor', () {
    test('a free colour is stored for the metric alone', () {
      final next = none.withColor(ProfileMetric.ppO2, _purpleA200);
      expect(next.argbOf(ProfileMetric.ppO2), _argb(_purpleA200));
      expect(next.count, 1);
    });

    test('a colour another metric shows swaps the two', () {
      // TTS shows Pink 800 by default; ppO2 takes it.
      final next = none.withColor(ProfileMetric.ppO2, ProfileMetricColors.tts);
      expect(next.effectiveArgb(ProfileMetric.ppO2), _argb(ProfileMetricColors.tts));
      expect(next.effectiveArgb(ProfileMetric.tts), _argb(ProfileMetricColors.ppO2));
      expect(next.count, 2);
    });

    test('a metric handed its own default stores no override', () {
      final swapped = none.withColor(ProfileMetric.ppO2, ProfileMetricColors.tts);
      // TTS takes Pink 800 back; ppO2 receives Cyan 600, its own default.
      final back = swapped.withColor(ProfileMetric.tts, ProfileMetricColors.tts);
      expect(back, none);
    });

    test('null on a fixed-default metric is choosing that default', () {
      final swapped = none.withColor(ProfileMetric.ppO2, ProfileMetricColors.tts);
      expect(swapped.withColor(ProfileMetric.ppO2, null), none);
    });

    test('an Auto metric taking a held colour hands the holder the first '
        'free swatch, never a theme colour', () {
      final next = none.withColor(
        ProfileMetric.temperature,
        ProfileMetricColors.depth,
      );
      expect(
        next.effectiveArgb(ProfileMetric.temperature),
        _argb(ProfileMetricColors.depth),
      );
      // Swatches 0-17 are held by the 18 fixed defaults (depth's now by
      // temperature); 18 (Cyan 800) is the first free one.
      expect(next.effectiveArgb(ProfileMetric.depth), _argb(profileMetricSwatches[18]));
    });

    test('null on an Auto metric returns it to Auto and swaps nothing', () {
      final custom = none.withColor(ProfileMetric.pressure, _purpleA200);
      final back = custom.withColor(ProfileMetric.pressure, null);
      expect(back.argbOf(ProfileMetric.pressure), isNull);
      expect(back.effectiveArgb(ProfileMetric.pressure), isNull);
      expect(back, none);
    });

    test('picking the colour a metric already shows changes nothing', () {
      expect(none.withColor(ProfileMetric.ndl, ProfileMetricColors.ndl), none);
    });

    test('Auto metrics on Auto never receive a swap', () {
      final next = none.withColor(ProfileMetric.ppO2, ProfileMetricColors.ndl);
      expect(next.effectiveArgb(ProfileMetric.temperature), isNull);
      expect(next.effectiveArgb(ProfileMetric.pressure), isNull);
    });
  });

  group('deduped', () {
    test('keeps the first metric in enum order and moves later holders to '
        'the first free swatch', () {
      // Two devices resolved per field: ppO2 and ppN2 both hold Purple A200.
      final clash = ProfileMetricColorOverrides.fromArgb({
        ProfileMetric.ppO2: _argb(_purpleA200),
        ProfileMetric.ppN2: _argb(_purpleA200),
      });
      final fixed = clash.deduped();
      expect(fixed.effectiveArgb(ProfileMetric.ppO2), _argb(_purpleA200));
      // Free under the clash: Cyan 600 (ppO2's default, now unused) is
      // swatch 10, the first one nobody shows.
      expect(fixed.effectiveArgb(ProfileMetric.ppN2), _argb(ProfileMetricColors.ppO2));
    });

    test('an override equal to an earlier metric default moves the later '
        'metric', () {
      final clash = ProfileMetricColorOverrides.fromArgb({
        ProfileMetric.meanDepth: _argb(ProfileMetricColors.depth),
      });
      final fixed = clash.deduped();
      expect(fixed.effectiveArgb(ProfileMetric.depth), _argb(ProfileMetricColors.depth));
      expect(
        fixed.effectiveArgb(ProfileMetric.meanDepth),
        isNot(_argb(ProfileMetricColors.depth)),
      );
    });

    test('returns itself when nothing clashes', () {
      final ok = none.withColor(ProfileMetric.ppO2, _purpleA200);
      expect(identical(ok.deduped(), ok), isTrue);
    });

    test('withColor starts from the deduped state', () {
      final clash = ProfileMetricColorOverrides.fromArgb({
        ProfileMetric.ppO2: _argb(_purpleA200),
        ProfileMetric.ppN2: _argb(_purpleA200),
      });
      final next = clash.withColor(ProfileMetric.gf, const Color(0xFF00E676));
      final shown = [
        for (final m in ProfileMetric.values)
          if (next.effectiveArgb(m) case final v?) v,
      ];
      expect(shown.toSet(), hasLength(shown.length));
    });
  });

  group('fromArgb', () {
    test('drops nulls, fully transparent values and stored defaults', () {
      final o = ProfileMetricColorOverrides.fromArgb({
        ProfileMetric.depth: null,
        ProfileMetric.ppO2: 0x0000ACC1,
        ProfileMetric.ndl: _argb(ProfileMetricColors.ndl),
        ProfileMetric.gf: _argb(_purpleA200),
      });
      expect(o.count, 1);
      expect(o.argbOf(ProfileMetric.gf), _argb(_purpleA200));
    });

    test('keeps a colour outside the palette (a newer build may add some)', () {
      final o = ProfileMetricColorOverrides.fromArgb({
        ProfileMetric.gf: 0xFF123456,
      });
      expect(o.argbOf(ProfileMetric.gf), 0xFF123456);
    });
  });

  test('equality is by value', () {
    expect(
      none.withColor(ProfileMetric.ppO2, _purpleA200),
      none.withColor(ProfileMetric.ppO2, _purpleA200),
    );
    expect(
      none.withColor(ProfileMetric.ppO2, _purpleA200).hashCode,
      none.withColor(ProfileMetric.ppO2, _purpleA200).hashCode,
    );
  });
}
```

- [ ] **Step 5: Run to verify it fails**

Run: `flutter test test/features/dive_log/presentation/profile_colors/profile_metric_color_overrides_test.dart`
Expected: FAIL to compile, `profile_metric_color_overrides.dart` not found.

- [ ] **Step 6: Implement the overrides**

`lib/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_swatches.dart';

/// The profile-metric colours a diver chose (issue #3012): only the metrics
/// they changed, as ARGB ints. A metric absent here shows its default, or
/// its automatic colour when it [ProfileMetric.isAuto].
///
/// Colours stay unique across metrics: [withColor] swaps a taken colour, and
/// [deduped] repairs a clash that per-field sync conflict resolution can
/// leave behind.
@immutable
class ProfileMetricColorOverrides {
  const ProfileMetricColorOverrides() : _argb = const {};

  ProfileMetricColorOverrides._of(Map<ProfileMetric, int> argb)
    : _argb = Map.unmodifiable(argb);

  /// From stored column values: nulls, fully transparent values and values
  /// equal to the metric's own default are dropped. A colour outside the
  /// palette is kept, since a newer build may offer more swatches.
  factory ProfileMetricColorOverrides.fromArgb(Map<ProfileMetric, int?> stored) {
    final kept = <ProfileMetric, int>{};
    for (final entry in stored.entries) {
      final raw = entry.value;
      if (raw == null) continue;
      final argb = raw & 0xFFFFFFFF;
      if ((argb >> 24) == 0) continue;
      _put(kept, entry.key, argb);
    }
    return kept.isEmpty ? none : ProfileMetricColorOverrides._of(kept);
  }

  static const ProfileMetricColorOverrides none = ProfileMetricColorOverrides();

  final Map<ProfileMetric, int> _argb;

  bool get isEmpty => _argb.isEmpty;

  /// How many metrics carry a chosen colour.
  int get count => _argb.length;

  /// The chosen colour for [metric], or null when it shows its default.
  int? argbOf(ProfileMetric metric) => _argb[metric];

  /// The colour [metric] shows: its override, else its fixed default. Null
  /// for an Auto metric left on Auto, which shows no palette colour.
  int? effectiveArgb(ProfileMetric metric) => _effective(_argb, metric);

  /// The metric other than [except] that shows [argb], if any.
  ProfileMetric? holderOf(int argb, {ProfileMetric? except}) =>
      _holder(_argb, argb, except: except);

  /// [metric] takes [color]; null means its default, or Auto.
  ///
  /// A metric already showing the colour receives the colour [metric] was
  /// showing, or, when [metric] was on Auto, the first swatch nobody shows.
  /// Any metric left holding its own default stores no override.
  ProfileMetricColorOverrides withColor(ProfileMetric metric, Color? color) {
    final base = deduped();
    final target = color?.toARGB32() ?? metric.defaultColor?.toARGB32();
    final next = Map<ProfileMetric, int>.of(base._argb);
    if (target == null) {
      // Auto: no other metric can be showing "no colour", so nothing swaps.
      next.remove(metric);
      return _from(next, base);
    }
    final previous = base.effectiveArgb(metric);
    if (previous == target) return base;
    final holder = base.holderOf(target, except: metric);
    _put(next, metric, target);
    if (holder != null) {
      _put(next, holder, previous ?? _firstFree(next));
    }
    return _from(next, base);
  }

  /// Every metric showing a distinct colour: the first metric, in enum order,
  /// keeps a shared colour and each later one moves to the first free swatch.
  /// Returns this object when nothing clashes.
  ProfileMetricColorOverrides deduped() {
    final next = Map<ProfileMetric, int>.of(_argb);
    final seen = <int>{};
    var changed = false;
    for (final metric in ProfileMetric.values) {
      final shown = _effective(next, metric);
      if (shown == null) continue;
      if (seen.add(shown)) continue;
      final free = _firstFree(next);
      _put(next, metric, free);
      seen.add(free);
      changed = true;
    }
    return changed ? _from(next, this) : this;
  }

  static ProfileMetricColorOverrides _from(
    Map<ProfileMetric, int> argb,
    ProfileMetricColorOverrides same,
  ) {
    if (mapEquals(argb, same._argb)) return same;
    return argb.isEmpty ? none : ProfileMetricColorOverrides._of(argb);
  }

  static int? _effective(Map<ProfileMetric, int> argb, ProfileMetric metric) =>
      argb[metric] ?? metric.defaultColor?.toARGB32();

  static ProfileMetric? _holder(
    Map<ProfileMetric, int> argb,
    int target, {
    ProfileMetric? except,
  }) {
    for (final other in ProfileMetric.values) {
      if (other != except && _effective(argb, other) == target) return other;
    }
    return null;
  }

  /// Stores [argb] for [metric], or clears it when it is the default.
  static void _put(Map<ProfileMetric, int> argb, ProfileMetric metric, int value) {
    if (value == metric.defaultColor?.toARGB32()) {
      argb.remove(metric);
    } else {
      argb[metric] = value;
    }
  }

  static int _firstFree(Map<ProfileMetric, int> argb) {
    final used = <int>{
      for (final metric in ProfileMetric.values)
        if (_effective(argb, metric) case final shown?) shown,
    };
    for (final swatch in profileMetricSwatches) {
      final value = swatch.toARGB32();
      if (!used.contains(value)) return value;
    }
    throw StateError('the palette must outnumber the metrics');
  }

  @override
  bool operator ==(Object other) =>
      other is ProfileMetricColorOverrides && mapEquals(other._argb, _argb);

  @override
  int get hashCode => Object.hashAllUnordered(
    _argb.entries.map((e) => Object.hash(e.key, e.value)),
  );
}
```

- [ ] **Step 7: Run to verify it passes**

Run: `flutter test test/features/dive_log/presentation/profile_colors/profile_metric_color_overrides_test.dart`
Expected: PASS. If the dedupe expectation "first free is Cyan 600" fails, recompute by hand from the swatch order rather than editing the rule: under the clash, swatches held are the 16 fixed defaults other than ppO2's and ppN2's, plus Purple A200; swatch 10 (Cyan 600) is the first unheld.

- [ ] **Step 8: Write the failing palette and swatch-name tests**

`test/features/dive_log/presentation/profile_colors/profile_metric_palette_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_palette.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

const _tertiary = Color(0xFF7D5260);
const _purpleA200 = Color(0xFFE040FB);

ProfileMetricPalette _palette([
  ProfileMetricColorOverrides o = ProfileMetricColorOverrides.none,
]) => ProfileMetricPalette(overrides: o, temperatureAuto: _tertiary);

void main() {
  test('defaults reproduce today\'s colours', () {
    final p = _palette();
    expect(p.colorOf(ProfileMetric.depth), ProfileMetricColors.depth);
    expect(p.colorOf(ProfileMetric.ppO2), ProfileMetricColors.ppO2);
    expect(p.colorOf(ProfileMetric.temperature), _tertiary);
    expect(p.colorOf(ProfileMetric.pressure), ProfileMetricColors.pressure);
    expect(p.pressureOverride, isNull);
  });

  test('a chosen colour wins, and a chosen pressure is exposed', () {
    final p = _palette(
      ProfileMetricColorOverrides.none
          .withColor(ProfileMetric.ppO2, _purpleA200)
          .withColor(ProfileMetric.pressure, ProfileMetricColors.events),
    );
    expect(p.colorOf(ProfileMetric.ppO2), _purpleA200);
    expect(p.pressureOverride, ProfileMetricColors.events);
    expect(p.colorOf(ProfileMetric.pressure), ProfileMetricColors.events);
  });

  test('renders a clash deduped', () {
    final p = _palette(
      ProfileMetricColorOverrides.fromArgb({
        ProfileMetric.ppO2: _purpleA200.toARGB32(),
        ProfileMetric.ppN2: _purpleA200.toARGB32(),
      }),
    );
    expect(p.colorOf(ProfileMetric.ppO2), isNot(p.colorOf(ProfileMetric.ppN2)));
  });

  group('rightAxisColor', () {
    test('NDL follows the chart (Yellow 700), not the old Light Green copy', () {
      expect(
        _palette().rightAxisColor(ProfileRightAxisMetric.ndl),
        ProfileMetricColors.ndl,
      );
    });

    test('follows a chosen colour', () {
      final p = _palette(
        ProfileMetricColorOverrides.none.withColor(ProfileMetric.ppO2, _purpleA200),
      );
      expect(p.rightAxisColor(ProfileRightAxisMetric.ppO2), _purpleA200);
    });

    test('temperature follows the theme; ascent rate and O2 cells keep '
        'their own colours', () {
      final p = _palette();
      expect(p.rightAxisColor(ProfileRightAxisMetric.temperature), _tertiary);
      expect(
        p.rightAxisColor(ProfileRightAxisMetric.ascentRate),
        ProfileRightAxisMetric.ascentRate.color,
      );
      expect(
        p.rightAxisColor(ProfileRightAxisMetric.o2CellMv),
        ProfileRightAxisMetric.o2CellMv.color,
      );
    });
  });
}
```

`test/features/dive_log/presentation/profile_colors/swatch_name_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_swatches.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/swatch_name.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('names a swatch by the nearest named equipment colour', () {
    expect(swatchName(l10n, const Color(0xFF00ACC1)), 'Cyan');
    expect(swatchName(l10n, const Color(0xFF3F51B5)), 'Indigo');
    expect(swatchName(l10n, const Color(0xFFF44336)), 'Red');
  });

  test('names every swatch with a word, never a hex code', () {
    for (final c in profileMetricSwatches) {
      expect(swatchName(l10n, c), isNot(startsWith('#')));
    }
  });
}
```

- [ ] **Step 9: Run to verify they fail**

Run: `flutter test test/features/dive_log/presentation/profile_colors/`
Expected: FAIL to compile, `profile_metric_palette.dart` and `swatch_name.dart` not found.

- [ ] **Step 10: Implement the palette and swatch names**

`lib/features/dive_log/presentation/profile_colors/profile_metric_palette.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';

/// The colour each profile metric is drawn in for the active diver: their
/// chosen colours (deduped), else the defaults, with temperature's Auto
/// colour taken from the theme.
@immutable
class ProfileMetricPalette {
  ProfileMetricPalette({
    required ProfileMetricColorOverrides overrides,
    required this.temperatureAuto,
  }) : overrides = overrides.deduped();

  final ProfileMetricColorOverrides overrides;

  /// The theme's `colorScheme.tertiary`, temperature's Auto colour.
  final Color temperatureAuto;

  Color colorOf(ProfileMetric metric) {
    final argb = overrides.effectiveArgb(metric);
    if (argb != null) return Color(argb);
    return switch (metric) {
      ProfileMetric.temperature => temperatureAuto,
      // Pressure's Auto colour is per gas; this is its legend swatch.
      _ => ProfileMetricColors.pressure,
    };
  }

  /// The pressure colour the diver chose, which a single-tank dive's
  /// pressure line and threshold markers use; null while on Auto.
  Color? get pressureOverride {
    final argb = overrides.argbOf(ProfileMetric.pressure);
    return argb == null ? null : Color(argb);
  }

  /// The right Y axis's label colour for [metric]. Ascent rate and O2 cells
  /// are not recolourable and keep their own.
  Color rightAxisColor(ProfileRightAxisMetric metric) => switch (metric) {
    ProfileRightAxisMetric.temperature => colorOf(ProfileMetric.temperature),
    ProfileRightAxisMetric.pressure => colorOf(ProfileMetric.pressure),
    ProfileRightAxisMetric.heartRate => colorOf(ProfileMetric.heartRate),
    ProfileRightAxisMetric.sac => colorOf(ProfileMetric.sac),
    ProfileRightAxisMetric.ndl => colorOf(ProfileMetric.ndl),
    ProfileRightAxisMetric.ppO2 => colorOf(ProfileMetric.ppO2),
    ProfileRightAxisMetric.ppN2 => colorOf(ProfileMetric.ppN2),
    ProfileRightAxisMetric.ppHe => colorOf(ProfileMetric.ppHe),
    ProfileRightAxisMetric.gasDensity => colorOf(ProfileMetric.density),
    ProfileRightAxisMetric.gf => colorOf(ProfileMetric.gf),
    ProfileRightAxisMetric.surfaceGf => colorOf(ProfileMetric.surfaceGf),
    ProfileRightAxisMetric.meanDepth => colorOf(ProfileMetric.meanDepth),
    ProfileRightAxisMetric.tts => colorOf(ProfileMetric.tts),
    ProfileRightAxisMetric.cns => colorOf(ProfileMetric.cns),
    ProfileRightAxisMetric.otu => colorOf(ProfileMetric.otu),
    ProfileRightAxisMetric.gtr => colorOf(ProfileMetric.gtr),
    ProfileRightAxisMetric.ascentRate ||
    ProfileRightAxisMetric.o2CellMv => metric.color ?? temperatureAuto,
  };
}
```

If the analyzer reports the switch is not exhaustive, `ProfileRightAxisMetric` has a value this list misses: map it to its `ProfileMetric` if one exists, else add it to the last arm.

`lib/features/dive_log/presentation/profile_colors/swatch_name.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The name a diver and a screen reader know [color] by: the nearest (CIE76)
/// of the app's named equipment colours. None of the profile swatches is an
/// equipment colour exactly, so an exact lookup would name none of them.
String swatchName(AppLocalizations l10n, Color color) {
  final target = _lab(color);
  var best = equipmentColorPalette.first;
  var bestDistance = double.infinity;
  for (final hex in equipmentColorPalette) {
    final d = _distance(target, _lab(TagColors.fromHex(hex)));
    if (d < bestDistance) {
      bestDistance = d;
      best = hex;
    }
  }
  return equipmentColorName(l10n, best);
}

double _lin(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

List<double> _lab(Color c) {
  final r = _lin(c.r), g = _lin(c.g), b = _lin(c.b);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
}

double _distance(List<double> a, List<double> b) => math.sqrt(
  math.pow(a[0] - b[0], 2) + math.pow(a[1] - b[1], 2) + math.pow(a[2] - b[2], 2),
);
```

- [ ] **Step 11: Run all Task 1 tests**

Run: `flutter test test/features/dive_log/presentation/profile_colors/`
Expected: PASS. If a `swatchName` expectation ('Cyan', 'Indigo', 'Red') fails, compute the nearest name with a throwaway script before changing the test; the rule (nearest by ΔE) is what the test pins, not a particular word.

- [ ] **Step 12: Format, analyze, architecture guard, commit**

```bash
dart format lib/features/dive_log/presentation/profile_colors test/features/dive_log/presentation/profile_colors
flutter analyze lib/features/dive_log/presentation/profile_colors test/features/dive_log/presentation/profile_colors
flutter test test/architecture/
git add lib/features/dive_log/presentation/profile_colors test/features/dive_log/presentation/profile_colors
git commit -m "feat(dive-log): add the profile metric colour palette and swap rules"
```

---

### Task 2: Strings (all locales)

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the 10 locale ARBs `app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- Regenerate: `lib/l10n/arb/app_localizations*.dart`

**Interfaces:**
- Produces (generated getters): `settings_appearance_metricColors`, `settings_appearance_metricColors_subtitleDefault`, `settings_appearance_metricColors_subtitleCustomized(int count)`, `settings_metricColors_resetAll`, `settings_metricColors_resetAllTitle`, `settings_metricColors_resetAllBody`, `settings_metricColors_reset`, `settings_metricColors_default`, `settings_metricColors_auto`, `settings_metricColors_autoTemperature`, `settings_metricColors_autoPressure`, `settings_metricColors_pressureCustom`, `settings_metricColors_sheetTitle(String metric)`, `settings_metricColors_swapsWith(String metric)`, `settings_conflict_field_profileColor(String metric)`.

- [ ] **Step 1: Check each locale's established nouns**

Run: `grep -n '"settings_appearance_subsection_defaultVisibleMetrics"\|"settings_conflict_field_trendGapCollapseMonths"\|"common_action_cancel"' lib/l10n/arb/app_*.arb`
Read each locale's "Default Visible Metrics" value and use the same word for "metric" in that locale's strings below (adjust the drafts in Step 2 if a locale already uses a different noun). In `app_fr.arb` and `app_hu.arb`, match the accenting of the neighbouring settings keys.

- [ ] **Step 2: Insert the keys by anchor with a script**

Write this script to the scratchpad as `add_metric_color_strings.py` and run it with `python3.14 -I <path>` from the repo root. It inserts each key after the anchor `"settings_appearance_subsection_defaultVisibleMetrics"` line in every ARB (the conflict key after `"settings_conflict_field_trendGapCollapseMonths"`), adds `@`-metadata to `app_en.arb` only, refuses to write if a file would not round-trip through `json.loads`, and never re-serializes a file.

```python
import json, pathlib, sys

ARB = pathlib.Path('lib/l10n/arb')
APPEARANCE_ANCHOR = '"settings_appearance_subsection_defaultVisibleMetrics"'
CONFLICT_ANCHOR = '"settings_conflict_field_trendGapCollapseMonths"'
CONFLICT_KEY = 'settings_conflict_field_profileColor'

KEYS = [
    'settings_appearance_metricColors',
    'settings_appearance_metricColors_subtitleDefault',
    'settings_appearance_metricColors_subtitleCustomized',
    'settings_metricColors_resetAll',
    'settings_metricColors_resetAllTitle',
    'settings_metricColors_resetAllBody',
    'settings_metricColors_reset',
    'settings_metricColors_default',
    'settings_metricColors_auto',
    'settings_metricColors_autoTemperature',
    'settings_metricColors_autoPressure',
    'settings_metricColors_pressureCustom',
    'settings_metricColors_sheetTitle',
    'settings_metricColors_swapsWith',
    CONFLICT_KEY,
]

T = {
 'en': ['Metric Colors', 'Default colors',
        '{count, plural, one{{count} customized} other{{count} customized}}',
        'Reset all', 'Reset metric colors?',
        'Every metric goes back to its default color.', 'Reset', 'Default',
        'Auto', 'Auto: follows the theme', 'Auto: each gas has its own color',
        'Used on single-tank dives', '{metric} color', 'Swaps with {metric}',
        'Profile color: {metric}'],
 'de': ['Farben der Messwerte', 'Standardfarben',
        '{count, plural, one{{count} angepasst} other{{count} angepasst}}',
        'Alle zurücksetzen', 'Farben der Messwerte zurücksetzen?',
        'Jeder Messwert erhält wieder seine Standardfarbe.', 'Zurücksetzen',
        'Standard', 'Automatisch', 'Automatisch: folgt dem Design',
        'Automatisch: jedes Gas hat eine eigene Farbe',
        'Für Tauchgänge mit einer Flasche', 'Farbe für {metric}',
        'Tauscht mit {metric}', 'Profilfarbe: {metric}'],
 'es': ['Colores de las métricas', 'Colores predeterminados',
        '{count, plural, one{{count} personalizado} other{{count} personalizados}}',
        'Restablecer todo', '¿Restablecer los colores de las métricas?',
        'Cada métrica vuelve a su color predeterminado.', 'Restablecer',
        'Predeterminado', 'Automático', 'Automático: sigue el tema',
        'Automático: cada gas tiene su propio color',
        'Se usa en inmersiones con una sola botella', 'Color de {metric}',
        'Se intercambia con {metric}', 'Color del perfil: {metric}'],
 'fr': ['Couleurs des mesures', 'Couleurs par défaut',
        '{count, plural, one{{count} personnalisée} other{{count} personnalisées}}',
        'Tout réinitialiser', 'Réinitialiser les couleurs des mesures ?',
        'Chaque mesure reprend sa couleur par défaut.', 'Réinitialiser',
        'Par défaut', 'Auto', 'Auto : suit le thème',
        'Auto : chaque gaz a sa propre couleur',
        'Utilisée pour les plongées à un seul bloc', 'Couleur de {metric}',
        "S'échange avec {metric}", 'Couleur du profil : {metric}'],
 'it': ['Colori delle metriche', 'Colori predefiniti',
        '{count, plural, one{{count} personalizzato} other{{count} personalizzati}}',
        'Ripristina tutto', 'Ripristinare i colori delle metriche?',
        'Ogni metrica torna al suo colore predefinito.', 'Ripristina',
        'Predefinito', 'Automatico', 'Automatico: segue il tema',
        'Automatico: ogni gas ha il suo colore',
        'Usato nelle immersioni con una sola bombola', 'Colore di {metric}',
        'Si scambia con {metric}', 'Colore del profilo: {metric}'],
 'nl': ['Kleuren van meetwaarden', 'Standaardkleuren',
        '{count, plural, one{{count} aangepast} other{{count} aangepast}}',
        'Alles herstellen', 'Kleuren van meetwaarden herstellen?',
        'Elke meetwaarde krijgt weer zijn standaardkleur.', 'Herstellen',
        'Standaard', 'Automatisch', 'Automatisch: volgt het thema',
        'Automatisch: elk gas heeft een eigen kleur',
        'Gebruikt bij duiken met één fles', 'Kleur van {metric}',
        'Wisselt met {metric}', 'Profielkleur: {metric}'],
 'pt': ['Cores das métricas', 'Cores predefinidas',
        '{count, plural, one{{count} personalizada} other{{count} personalizadas}}',
        'Redefinir tudo', 'Redefinir as cores das métricas?',
        'Cada métrica volta à sua cor predefinida.', 'Redefinir',
        'Predefinida', 'Automática', 'Automática: segue o tema',
        'Automática: cada gás tem a sua cor',
        'Usada em mergulhos com um só cilindro', 'Cor de {metric}',
        'Troca com {metric}', 'Cor do perfil: {metric}'],
 'hu': ['Mérőszámok színei', 'Alapértelmezett színek',
        '{count, plural, one{{count} testreszabva} other{{count} testreszabva}}',
        'Összes visszaállítása', 'Visszaállítod a mérőszámok színeit?',
        'Minden mérőszám visszakapja az alapértelmezett színét.',
        'Visszaállítás', 'Alapértelmezett', 'Automatikus',
        'Automatikus: a témát követi',
        'Automatikus: minden gáznak saját színe van',
        'Egypalackos merülésekhez', '{metric} színe',
        'Csere ezzel: {metric}', 'Profilszín: {metric}'],
 'ar': ['ألوان المقاييس', 'الألوان الافتراضية',
        '{count, plural, one{{count} مخصص} other{{count} مخصصة}}',
        'إعادة تعيين الكل', 'إعادة تعيين ألوان المقاييس؟',
        'يعود كل مقياس إلى لونه الافتراضي.', 'إعادة تعيين', 'افتراضي',
        'تلقائي', 'تلقائي: يتبع السمة', 'تلقائي: لكل غاز لونه الخاص',
        'يُستخدم في الغطسات بأسطوانة واحدة', 'لون {metric}',
        'يتبادل مع {metric}', 'لون ملف الغوصة: {metric}'],
 'he': ['צבעי מדדים', 'צבעי ברירת מחדל',
        '{count, plural, one{{count} מותאם} other{{count} מותאמים}}',
        'איפוס הכול', 'לאפס את צבעי המדדים?',
        'כל מדד יחזור לצבע ברירת המחדל שלו.', 'איפוס', 'ברירת מחדל',
        'אוטומטי', 'אוטומטי: לפי ערכת הנושא', 'אוטומטי: לכל גז צבע משלו',
        'בשימוש בצלילות עם מכל אחד', 'הצבע של {metric}',
        'מתחלף עם {metric}', 'צבע פרופיל: {metric}'],
 'zh': ['指标颜色', '默认颜色', '{count, plural, other{已自定义 {count} 项}}',
        '全部重置', '重置指标颜色？', '每个指标都将恢复默认颜色。', '重置',
        '默认', '自动', '自动：跟随主题', '自动：每种气体有各自的颜色',
        '用于单气瓶潜水', '{metric}颜色', '与{metric}互换', '轮廓颜色：{metric}'],
}

META = {
 'settings_appearance_metricColors_subtitleCustomized':
     '{"placeholders": {"count": {"type": "int"}}}',
 'settings_metricColors_sheetTitle': '{"placeholders": {"metric": {"type": "String"}}}',
 'settings_metricColors_swapsWith': '{"placeholders": {"metric": {"type": "String"}}}',
 CONFLICT_KEY: '{"placeholders": {"metric": {"type": "String"}}}',
}

def line(key, value):
    return '  "%s": %s,\n' % (key, json.dumps(value, ensure_ascii=False))

for locale, values in T.items():
    path = ARB / f'app_{locale}.arb'
    src = path.read_text(encoding='utf-8')
    if '"settings_appearance_metricColors"' in src:
        sys.exit(f'{path} already has the keys')
    lines = src.splitlines(keepends=True)
    def insert_after(anchor, new_lines):
        for i, l in enumerate(lines):
            if l.lstrip().startswith(anchor):
                j = i + 1
                # Skip the anchor's own @-metadata block in app_en.arb.
                while j < len(lines) and lines[j].lstrip().startswith('"@'):
                    depth = lines[j].count('{') - lines[j].count('}')
                    j += 1
                    while depth > 0:
                        depth += lines[j].count('{') - lines[j].count('}')
                        j += 1
                lines[j:j] = new_lines
                return
        sys.exit(f'{anchor} missing in {path}')
    def block(key, value):
        out = [line(key, value)]
        if locale == 'en' and key in META:
            out.append('  "@%s": %s,\n' % (key, META[key]))
        return out
    appearance = []
    for key, value in zip(KEYS[:-1], values[:-1]):
        appearance += block(key, value)
    insert_after(APPEARANCE_ANCHOR, appearance)
    insert_after(CONFLICT_ANCHOR, block(CONFLICT_KEY, values[-1]))
    out = ''.join(lines)
    json.loads(out)
    path.write_text(out, encoding='utf-8')
    print('OK', path)
```

- [ ] **Step 3: Verify the diff shape, then generate**

```bash
git diff --numstat -- lib/l10n/arb/*.arb
flutter gen-l10n
grep -A2 "get settings_metricColors_resetAll" lib/l10n/arb/app_localizations_de.dart
```

Expected: `app_en.arb` +19/-0, each locale +15/-0; the German getter returns "Alle zurücksetzen". A smaller row means a locale silently did not change. `app_en.arb` is alphabetical: if `flutter gen-l10n` or a test complains about ordering, move the block, not the anchor.

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/arb
git commit -m "i18n(settings): add strings for profile metric colors"
```

---

### Task 3: Schema v282

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (after `trendGapCollapseMonths`)
- Modify: `lib/core/database/migrations/helpers/diver_migrations.dart` (end of extension)
- Modify: `lib/core/database/migrations/ladder/rungs_v231_onward.dart` (after the v281 rung)
- Modify: `lib/core/database/migrations/before_open.dart` (after the v281 backstop line)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion`, `migrationVersions`)
- Test: `test/core/database/migration_v282_profile_metric_colors_test.dart`
- Modify: `test/core/database/migration_v281_trend_gap_collapse_test.dart` only if it pins `currentSchemaVersion` to exactly 281 (it uses `greaterThanOrEqualTo`, so it should not need to change)

**Interfaces:**
- Produces: Drift row fields `DiverSetting.profileColor<Metric>` (`int?`) and companion fields `DiverSettingsCompanion.profileColor<Metric>` for the 20 metrics; SQL columns `profile_color_<snake>`.

- [ ] **Step 1: Write the failing migration test**

`test/core/database/migration_v282_profile_metric_colors_test.dart`:

```dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

const _columns = [
  'profile_color_depth',
  'profile_color_temperature',
  'profile_color_pressure',
  'profile_color_heart_rate',
  'profile_color_sac',
  'profile_color_max_depth',
  'profile_color_ceiling',
  'profile_color_ndl',
  'profile_color_tts',
  'profile_color_gtr',
  'profile_color_cns',
  'profile_color_otu',
  'profile_color_pp_o2',
  'profile_color_pp_n2',
  'profile_color_pp_he',
  'profile_color_mod',
  'profile_color_density',
  'profile_color_gf',
  'profile_color_surface_gf',
  'profile_color_mean_depth',
];

/// Schema v282: diver_settings.profile_color_* (issue #3012).
void main() {
  NativeDatabase setupDb() => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 281');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v282 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(282));
    expect(AppDatabase.migrationVersions, contains(282));
    expect(
      AppDatabase.migrationStepCount(281),
      AppDatabase.migrationStepCount(282) + 1,
    );
  });

  test('this rung is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(282));
  });

  test('upgrading from v281 adds 20 null colour columns', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final row = (await db
            .customSelect('SELECT ${_columns.join(', ')} FROM diver_settings')
            .get())
        .single;
    for (final column in _columns) {
      expect(row.read<int?>(column), isNull, reason: column);
    }
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/core/database/migration_v282_profile_metric_colors_test.dart`
Expected: FAIL (`migrationVersions` lacks 282; then "no such column").

- [ ] **Step 3: Add the columns, helper, rung, backstop and version**

In `diver_tables.dart`, directly after the `trendGapCollapseMonths` block (`// coverage:ignore-end` that follows it):

```dart
  // v282: per-diver profile metric colours (issue #3012), ARGB ints; null is
  // the metric's default (or Auto). Codegen input, never executed.
  // coverage:ignore-start
  IntColumn get profileColorDepth => integer().nullable()();
  IntColumn get profileColorTemperature => integer().nullable()();
  IntColumn get profileColorPressure => integer().nullable()();
  IntColumn get profileColorHeartRate => integer().nullable()();
  IntColumn get profileColorSac => integer().nullable()();
  IntColumn get profileColorMaxDepth => integer().nullable()();
  IntColumn get profileColorCeiling => integer().nullable()();
  IntColumn get profileColorNdl => integer().nullable()();
  IntColumn get profileColorTts => integer().nullable()();
  IntColumn get profileColorGtr => integer().nullable()();
  IntColumn get profileColorCns => integer().nullable()();
  IntColumn get profileColorOtu => integer().nullable()();
  IntColumn get profileColorPpO2 => integer().nullable()();
  IntColumn get profileColorPpN2 => integer().nullable()();
  IntColumn get profileColorPpHe => integer().nullable()();
  IntColumn get profileColorMod => integer().nullable()();
  IntColumn get profileColorDensity => integer().nullable()();
  IntColumn get profileColorGf => integer().nullable()();
  IntColumn get profileColorSurfaceGf => integer().nullable()();
  IntColumn get profileColorMeanDepth => integer().nullable()();
  // coverage:ignore-end
```

At the end of the `DiverMigrations` extension in `diver_migrations.dart`:

```dart
  /// v282: diver_settings.profile_color_* (issue #3012). Nullable ARGB ints,
  /// no default and no backfill: null is the metric's default colour.
  /// Re-asserted in beforeOpen.
  Future<void> _assertProfileMetricColorColumns() async {
    final cols = await customSelect(
      "PRAGMA table_info('diver_settings')",
    ).get();
    if (cols.isEmpty) return;
    final names = cols.map((c) => c.read<String>('name')).toSet();
    for (final column in _profileMetricColorColumns) {
      if (!names.contains(column)) {
        await customStatement(
          'ALTER TABLE diver_settings ADD COLUMN $column INTEGER',
        );
      }
    }
  }
```

and, at file top level below the extension:

```dart
const List<String> _profileMetricColorColumns = [
  'profile_color_depth',
  'profile_color_temperature',
  'profile_color_pressure',
  'profile_color_heart_rate',
  'profile_color_sac',
  'profile_color_max_depth',
  'profile_color_ceiling',
  'profile_color_ndl',
  'profile_color_tts',
  'profile_color_gtr',
  'profile_color_cns',
  'profile_color_otu',
  'profile_color_pp_o2',
  'profile_color_pp_n2',
  'profile_color_pp_he',
  'profile_color_mod',
  'profile_color_density',
  'profile_color_gf',
  'profile_color_surface_gf',
  'profile_color_mean_depth',
];
```

(`diver_migrations.dart` is a `part of` file; a private top-level const is visible to the library. If the file is not a part, keep it private to that file the same way.)

In `rungs_v231_onward.dart`, after `if (from < 281) await reportProgress();`:

```dart
    // v282: diver_settings.profile_color_* (issue #3012). Columns only, null
    // meaning the default colour; re-asserted in beforeOpen.
    if (from < 282) {
      await _assertProfileMetricColorColumns();
    }
    if (from < 282) await reportProgress();
```

In `before_open.dart`, after `await _assertTrendGapCollapseColumn();`:

```dart
    // v282 backstop: diver_settings.profile_color_*.
    await _assertProfileMetricColorColumns();
```

In `database.dart`: `currentSchemaVersion = 282;` and append to `migrationVersions` after `281,`:

```dart
    // v282: diver_settings.profile_color_* (issue #3012). Additive nullable
    // columns, so the floor stays at 280.
    282,
```

- [ ] **Step 4: Regenerate Drift code**

Run the scratchpad codegen script (it spells the build command without a bare `build` token): `<scratchpad>/codegen.sh`
Expected: exits 0; `grep -c profileColorPpO2 lib/core/database/database.g.dart` is non-zero.

- [ ] **Step 5: Run the migration tests and the database suite**

```bash
flutter test test/core/database/migration_v282_profile_metric_colors_test.dart test/core/database/migration_v281_trend_gap_collapse_test.dart
flutter test test/core/database
```

Expected: PASS. A schema-snapshot or "every rung has a test" guard that fails names exactly what it wants; follow its message.

- [ ] **Step 6: Commit**

```bash
git add lib/core/database test/core/database/migration_v282_profile_metric_colors_test.dart
git commit -m "feat(settings): add profile metric colour columns to diver settings (v282)"
```

---

### Task 4: Settings, repository, sync and conflicts

**Files:**
- Create: `lib/features/settings/data/repositories/profile_metric_color_columns.dart`
- Modify: `lib/features/settings/data/repositories/diver_settings_repository.dart` (`createSettingsForDiver`, `_storedColumns`, `_mapRowToAppSettings`)
- Modify: `lib/features/settings/presentation/providers/settings_providers.dart` (`AppSettings` field/ctor/copyWith, two notifier setters)
- Create: `lib/features/dive_log/presentation/profile_colors/profile_metric_label.dart`
- Create: `lib/features/settings/presentation/conflicts/catalogue/profile_color_fields.dart`
- Modify: `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart` (spread the new map)
- Test: `test/features/settings/data/profile_metric_color_columns_test.dart`
- Test: `test/core/services/sync/sync_diver_settings_profile_colors_test.dart`
- Test: `test/features/settings/presentation/providers/settings_notifier_profile_colors_test.dart`
- Test: `test/features/settings/presentation/conflicts/profile_color_fields_test.dart`

**Interfaces:**
- Consumes: Task 1 `ProfileMetric`, `ProfileMetricColorOverrides`, `swatchName`; Task 2 `settings_conflict_field_profileColor`; Task 3 columns.
- Produces:
  - `AppSettings.profileMetricColors` (`ProfileMetricColorOverrides`, default `ProfileMetricColorOverrides.none`), `copyWith(profileMetricColors:)`.
  - `SettingsNotifier.setProfileMetricColor(ProfileMetric metric, Color? color)`, `SettingsNotifier.resetProfileMetricColors()`.
  - `DiverSettingsCompanion withProfileMetricColors(DiverSettingsCompanion, ProfileMetricColorOverrides)`, `ProfileMetricColorOverrides profileMetricColorsFromRow(DiverSetting)`.
  - `String profileMetricLabel(AppLocalizations l10n, ProfileMetric metric)`.
  - `String? profileColorLabeler(AppLocalizations l10n, String stored)`, `Map<String, ConflictField> profileColorConflictFields`.

- [ ] **Step 1: Write the failing column-mapping test**

`test/features/settings/data/profile_metric_color_columns_test.dart`:

```dart
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';
import 'package:submersion/features/settings/data/repositories/profile_metric_color_columns.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  setUp(() async => db = await setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  test('round-trips every metric through its own column', () async {
    var overrides = ProfileMetricColorOverrides.none;
    final values = <ProfileMetric, int>{};
    for (var i = 0; i < ProfileMetric.values.length; i++) {
      final metric = ProfileMetric.values[i];
      // Distinct, opaque, outside the palette so no swap rule interferes.
      values[metric] = 0xFF000000 | (0x010101 * (i + 1));
    }
    overrides = ProfileMetricColorOverrides.fromArgb(values);

    await db.customStatement('PRAGMA foreign_keys = OFF');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.diverSettings).insert(
      withProfileMetricColors(
        DiverSettingsCompanion.insert(
          id: 'ds-pc',
          diverId: 'diver-pc',
          createdAt: now,
          updatedAt: now,
        ),
        overrides,
      ),
    );
    final row = await (db.select(db.diverSettings)
          ..where((t) => t.id.equals('ds-pc')))
        .getSingle();
    expect(profileMetricColorsFromRow(row), overrides);
    for (final metric in ProfileMetric.values) {
      expect(row.toJson()[metric.settingsKey], values[metric], reason: metric.name);
    }
  });

  test('an empty override set writes null to every column', () {
    final c = withProfileMetricColors(
      const DiverSettingsCompanion(),
      ProfileMetricColorOverrides.none,
    );
    final cols = c.toColumns(false);
    expect(cols.keys.where((k) => k.startsWith('profile_color_')), hasLength(20));
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/settings/data/profile_metric_color_columns_test.dart`
Expected: FAIL to compile, `profile_metric_color_columns.dart` missing.

- [ ] **Step 3: Implement the mapping file**

`lib/features/settings/data/repositories/profile_metric_color_columns.dart`:

```dart
import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_color_overrides.dart';

/// [companion] with every `profile_color_*` column set from [overrides]
/// (null where the metric shows its default), so a save also clears a
/// colour the diver reset.
DiverSettingsCompanion withProfileMetricColors(
  DiverSettingsCompanion companion,
  ProfileMetricColorOverrides overrides,
) {
  Value<int?> v(ProfileMetric m) => Value(overrides.argbOf(m));
  return companion.copyWith(
    profileColorDepth: v(ProfileMetric.depth),
    profileColorTemperature: v(ProfileMetric.temperature),
    profileColorPressure: v(ProfileMetric.pressure),
    profileColorHeartRate: v(ProfileMetric.heartRate),
    profileColorSac: v(ProfileMetric.sac),
    profileColorMaxDepth: v(ProfileMetric.maxDepth),
    profileColorCeiling: v(ProfileMetric.ceiling),
    profileColorNdl: v(ProfileMetric.ndl),
    profileColorTts: v(ProfileMetric.tts),
    profileColorGtr: v(ProfileMetric.gtr),
    profileColorCns: v(ProfileMetric.cns),
    profileColorOtu: v(ProfileMetric.otu),
    profileColorPpO2: v(ProfileMetric.ppO2),
    profileColorPpN2: v(ProfileMetric.ppN2),
    profileColorPpHe: v(ProfileMetric.ppHe),
    profileColorMod: v(ProfileMetric.mod),
    profileColorDensity: v(ProfileMetric.density),
    profileColorGf: v(ProfileMetric.gf),
    profileColorSurfaceGf: v(ProfileMetric.surfaceGf),
    profileColorMeanDepth: v(ProfileMetric.meanDepth),
  );
}

/// The colours stored on [row].
ProfileMetricColorOverrides profileMetricColorsFromRow(DiverSetting row) =>
    ProfileMetricColorOverrides.fromArgb({
      ProfileMetric.depth: row.profileColorDepth,
      ProfileMetric.temperature: row.profileColorTemperature,
      ProfileMetric.pressure: row.profileColorPressure,
      ProfileMetric.heartRate: row.profileColorHeartRate,
      ProfileMetric.sac: row.profileColorSac,
      ProfileMetric.maxDepth: row.profileColorMaxDepth,
      ProfileMetric.ceiling: row.profileColorCeiling,
      ProfileMetric.ndl: row.profileColorNdl,
      ProfileMetric.tts: row.profileColorTts,
      ProfileMetric.gtr: row.profileColorGtr,
      ProfileMetric.cns: row.profileColorCns,
      ProfileMetric.otu: row.profileColorOtu,
      ProfileMetric.ppO2: row.profileColorPpO2,
      ProfileMetric.ppN2: row.profileColorPpN2,
      ProfileMetric.ppHe: row.profileColorPpHe,
      ProfileMetric.mod: row.profileColorMod,
      ProfileMetric.density: row.profileColorDensity,
      ProfileMetric.gf: row.profileColorGf,
      ProfileMetric.surfaceGf: row.profileColorSurfaceGf,
      ProfileMetric.meanDepth: row.profileColorMeanDepth,
    });
```

Run the Step 1 test. Expected: PASS.

- [ ] **Step 4: Add the `AppSettings` field**

In `settings_providers.dart`, import `profile_metric_color_overrides.dart` (package import, in the existing import group). Beside `trendGapThreshold` in each of the three places:

Field:

```dart
  /// The profile-chart metric colours this diver chose (issue #3012).
  final ProfileMetricColorOverrides profileMetricColors;
```

Constructor default: `this.profileMetricColors = ProfileMetricColorOverrides.none,`

`copyWith` parameter: `ProfileMetricColorOverrides? profileMetricColors,` and body: `profileMetricColors: profileMetricColors ?? this.profileMetricColors,`

- [ ] **Step 5: Wire the repository**

In `diver_settings_repository.dart`, import `profile_metric_color_columns.dart`, then:

1. `createSettingsForDiver`: wrap the inserted companion: `.insert(withProfileMetricColors(DiverSettingsCompanion(...), s.profileMetricColors))` (the opening `DiverSettingsCompanion(` and its matching `)` just before `.insert`'s closing paren).
2. `_storedColumns`: change `=> DiverSettingsCompanion(` to `=> withProfileMetricColors(DiverSettingsCompanion(` and its closing `);` to `), settings.profileMetricColors);`.
3. `_mapRowToAppSettings`: add `profileMetricColors: profileMetricColorsFromRow(row),` after `trendGapThreshold: ...`.

- [ ] **Step 6: Write the failing sync test**

`test/core/services/sync/sync_diver_settings_profile_colors_test.dart`:

```dart
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

const _purple = 0xFFE040FB;

void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.diverSettings).insert(
      DiverSettingsCompanion.insert(
        id: 'ds-pc',
        diverId: 'diver-pc',
        createdAt: now,
        updatedAt: now,
        profileColorPpO2: const Value(_purple),
      ),
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<DiverSetting> row() => (db.select(db.diverSettings)
        ..where((t) => t.id.equals('ds-pc')))
      .getSingle();

  test('exports and re-imports a chosen colour', () async {
    final exported = await serializer.fetchRecord('diverSettings', 'ds-pc');
    expect(exported!['profileColorPpO2'], _purple);
    await serializer.upsertRecord('diverSettings', exported);
    expect((await row()).profileColorPpO2, _purple);
  });

  test('a peer without the column (older build) keeps the local colour', () async {
    final exported = await serializer.fetchRecord('diverSettings', 'ds-pc');
    final legacy = Map<String, dynamic>.from(exported!)
      ..removeWhere((k, _) => k.startsWith('profileColor'));
    await serializer.upsertRecord('diverSettings', legacy);
    expect((await row()).profileColorPpO2, _purple);
  });

  test('an incoming null (a reset elsewhere) clears the colour', () async {
    final exported = await serializer.fetchRecord('diverSettings', 'ds-pc');
    final reset = Map<String, dynamic>.from(exported!)
      ..['profileColorPpO2'] = null;
    await serializer.upsertRecord('diverSettings', reset);
    expect((await row()).profileColorPpO2, isNull);
  });
}
```

- [ ] **Step 7: Run it**

Run: `flutter test test/core/services/sync/sync_diver_settings_profile_colors_test.dart`
Expected: PASS without serializer changes (nullable columns need no seed; omitted keys are kept by `_withLocalForOmitted`; null is not in `_nullMeansUnsetKeys`). If the "older build" test fails, read `_withLocalForOmitted` for the reason before touching the serializer; do not add the columns to `_nullMeansUnsetKeys`.

- [ ] **Step 8: Write the failing notifier test**

Template the harness on `test/features/settings/presentation/providers/settings_notifier_real_test.dart` (the real `SettingsNotifier` over a test database, as the trend gap threshold test there does). Create `test/features/settings/presentation/providers/settings_notifier_profile_colors_test.dart` with these cases, using that file's setup helpers verbatim:

```dart
  test('setProfileMetricColor swaps and persists both metrics', () async {
    // container/notifier built exactly as settings_notifier_real_test does.
    await notifier.setProfileMetricColor(ProfileMetric.ppO2, ProfileMetricColors.tts);
    final s = container.read(settingsProvider).profileMetricColors;
    expect(s.effectiveArgb(ProfileMetric.ppO2), ProfileMetricColors.tts.toARGB32());
    expect(s.effectiveArgb(ProfileMetric.tts), ProfileMetricColors.ppO2.toARGB32());
    final stored = await repository.getSettingsForDiver(diverId);
    expect(stored!.profileMetricColors, s);
  });

  test('resetProfileMetricColors clears every colour', () async {
    await notifier.setProfileMetricColor(ProfileMetric.ppO2, const Color(0xFFE040FB));
    await notifier.resetProfileMetricColors();
    final stored = await repository.getSettingsForDiver(diverId);
    expect(stored!.profileMetricColors, ProfileMetricColorOverrides.none);
  });

  test('a pick made before the load is not overwritten by it', () async {
    // Start the setter before awaiting settingsLoaded, as the trend gap
    // threshold test in settings_notifier_real_test does.
    final pick = notifier.setProfileMetricColor(
      ProfileMetric.gf,
      const Color(0xFF00E676),
    );
    await notifier.settingsLoaded;
    await pick;
    expect(
      container.read(settingsProvider).profileMetricColors.argbOf(ProfileMetric.gf),
      0xFF00E676,
    );
  });
```

Run: `flutter test test/features/settings/presentation/providers/settings_notifier_profile_colors_test.dart`
Expected: FAIL, `setProfileMetricColor` not defined.

- [ ] **Step 9: Implement the setters**

In `SettingsNotifier`, after `setTrendGapThreshold`:

```dart
  /// [metric] takes [color] (null: its default, or Auto), swapping with any
  /// metric already showing it (issue #3012). Waits for the load first, as
  /// [setTrendGapThreshold] does, so an early pick is not overwritten.
  Future<void> setProfileMetricColor(ProfileMetric metric, Color? color) async {
    try {
      await settingsLoaded;
    } catch (_) {
      // Already logged by the load; defaults are the fallback.
    }
    if (!mounted) return;
    state = state.copyWith(
      profileMetricColors: state.profileMetricColors.withColor(metric, color),
    );
    await _saveSettings();
  }

  /// Every profile metric back to its default colour.
  Future<void> resetProfileMetricColors() async {
    try {
      await settingsLoaded;
    } catch (_) {
      // Already logged by the load; defaults are the fallback.
    }
    if (!mounted) return;
    state = state.copyWith(
      profileMetricColors: ProfileMetricColorOverrides.none,
    );
    await _saveSettings();
  }
```

Import `profile_metric.dart` too. Run the Step 8 test. Expected: PASS. Then search for hand-written `SettingsNotifier` fakes that `implements SettingsNotifier` without `noSuchMethod` (`grep -rln "implements SettingsNotifier" test | xargs grep -L noSuchMethod`) and add the two methods to any it finds.

- [ ] **Step 10: Metric labels and conflict fields (test first)**

`test/features/settings/presentation/conflicts/profile_color_fields_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart';
import 'package:submersion/features/settings/presentation/conflicts/catalogue/profile_color_fields.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test('every colour column is in the diver settings catalogue', () {
    for (final metric in ProfileMetric.values) {
      final field = diverSettingsFields[metric.settingsKey];
      expect(field, isNotNull, reason: metric.settingsKey);
      expect(field!.kind, FieldKind.enumValue);
    }
  });

  test('labels the field with the metric name', () {
    expect(
      diverSettingsFields['profileColorPpO2']!.label(l10n),
      'Profile color: ppO2',
    );
  });

  test('names a stored colour by word and hex', () {
    expect(profileColorLabeler(l10n, '${0xFF00ACC1}'), 'Cyan (#00ACC1)');
    expect(profileColorLabeler(l10n, 'not a number'), isNull);
  });
}
```

(If the ppO2 legend label in `app_en.arb` is not "ppO2", use its actual value; check with `grep '"diveLog_legend_label_ppO2"' lib/l10n/arb/app_en.arb`.)

`lib/features/dive_log/presentation/profile_colors/profile_metric_label.dart`:

```dart
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The name the chart's legend gives [metric].
String profileMetricLabel(AppLocalizations l10n, ProfileMetric metric) =>
    switch (metric) {
      ProfileMetric.depth => l10n.diveLog_legend_label_depth,
      ProfileMetric.temperature => l10n.diveLog_legend_label_temp,
      ProfileMetric.pressure => l10n.diveLog_legend_label_pressure,
      ProfileMetric.heartRate => l10n.diveLog_legend_label_heartRate,
      ProfileMetric.sac => l10n.diveLog_legend_label_sacRate,
      ProfileMetric.maxDepth => l10n.diveLog_legend_label_maxDepth,
      ProfileMetric.ceiling => l10n.diveLog_legend_label_ceiling,
      ProfileMetric.ndl => l10n.diveLog_legend_label_ndl,
      ProfileMetric.tts => l10n.diveLog_legend_label_tts,
      ProfileMetric.gtr => l10n.diveLog_legend_label_gtr,
      ProfileMetric.cns => l10n.diveLog_legend_label_cns,
      ProfileMetric.otu => l10n.diveLog_legend_label_otu,
      ProfileMetric.ppO2 => l10n.diveLog_legend_label_ppO2,
      ProfileMetric.ppN2 => l10n.diveLog_legend_label_ppN2,
      ProfileMetric.ppHe => l10n.diveLog_legend_label_ppHe,
      ProfileMetric.mod => l10n.diveLog_legend_label_mod,
      ProfileMetric.density => l10n.diveLog_legend_label_gasDensity,
      ProfileMetric.gf => l10n.diveLog_legend_label_gfPercent,
      ProfileMetric.surfaceGf => l10n.diveLog_legend_label_surfaceGf,
      ProfileMetric.meanDepth => l10n.diveLog_legend_label_meanDepth,
    };
```

`lib/features/settings/presentation/conflicts/catalogue/profile_color_fields.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_label.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/swatch_name.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A stored profile colour (an ARGB int) as "Cyan (#00ACC1)"; null for a
/// value that is not one.
String? profileColorLabeler(AppLocalizations l10n, String stored) {
  final argb = int.tryParse(stored);
  if (argb == null) return null;
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();
  return '${swatchName(l10n, Color(argb))} (#$rgb)';
}

/// One conflict-dialog field per `diver_settings.profile_color_*` column.
final Map<String, ConflictField> profileColorConflictFields = {
  for (final metric in ProfileMetric.values)
    metric.settingsKey: ConflictField(
      (l) => l.settings_conflict_field_profileColor(profileMetricLabel(l, metric)),
      FieldKind.enumValue,
      enumLabel: profileColorLabeler,
    ),
};
```

In `diver_settings_fields.dart`, import the new file and add `...profileColorConflictFields,` as the last entry of `diverSettingsFields`. Run the test. Expected: PASS. Then run the existing catalogue guards: `flutter test test/features/settings/presentation/conflicts`.

- [ ] **Step 11: Format, analyze, settings and sync suites, commit**

```bash
dart format lib/features/settings lib/features/dive_log/presentation/profile_colors test/features/settings test/core/services/sync
flutter analyze
flutter test test/features/settings test/core/services/sync test/architecture
git add lib/features/settings lib/features/dive_log/presentation/profile_colors test/features/settings test/core/services/sync/sync_diver_settings_profile_colors_test.dart
git commit -m "feat(settings): persist, sync and resolve conflicts for profile metric colours"
```

---

### Task 5: Chart wiring

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/profile_metric_line_builders.dart`
- Modify: `lib/features/dive_log/presentation/widgets/partial_pressure_line_builders.dart`
- Modify: `lib/features/dive_log/presentation/widgets/tank_line_builders.dart`
- Modify: `lib/features/dive_log/data/services/profile_markers_service.dart` (`ProfileMarker.getColor`)
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_profile_chart_metric_colors_test.dart`
- Modify (call-site fallout): existing tests that call the builders directly (`grep -rln "buildSacLine\|buildCeilingLine\|buildNdlLine\|buildModLine\|buildDensityLine\|buildGfLine\|buildSurfaceGfLine\|buildMeanDepthLine\|buildTtsLine\|buildGtrLine\|buildCnsLine\|buildOtuLine\|buildPpO2Line\|buildPpN2Line\|buildPpHeLine\|buildMultiTankPressureLines" test`)

**Interfaces:**
- Consumes: Task 1 `ProfileMetricPalette`, `ProfileMetric`; Task 4 `AppSettings.profileMetricColors`.
- Produces: every `build*Line` in the two builder files takes a leading `Color color` positional parameter (matching `buildHeartRateLine`); `buildMultiTankPressureLines(..., Color? singleTankColor)` named parameter; `ProfileMarker.getColor({List<Color>? tankColors, Color? maxDepthColor})`.

- [ ] **Step 1: Write the failing chart test**

`test/features/dive_log/presentation/widgets/dive_profile_chart_metric_colors_test.dart`. Use the harness of `dive_profile_chart_gtr_test.dart` (copy its `_TestSettingsNotifier`, `_profile()`, `_harness` shape and `_touchCentre`), with the notifier constructed from a given `AppSettings`:

```dart
const _purple = Color(0xFFE040FB);
const _greenA400 = Color(0xFF00E676);

Iterable<Color?> _barColors(WidgetTester tester) => tester
    .widget<LineChart>(find.byType(LineChart))
    .data
    .lineBarsData
    .map((b) => b.color);

void main() {
  testWidgets('a chosen ppO2 colour draws the line and its tooltip bullet', (
    tester,
  ) async {
    List<TooltipRow>? rows;
    final settings = AppSettings(
      defaultShowPpO2: true,
      profileMetricColors: ProfileMetricColorOverrides.none.withColor(
        ProfileMetric.ppO2,
        _purple,
      ),
    );
    await tester.pumpWidget(_harness(
      settings: settings,
      profile: _profile(),
      ppO2Curve: List<double>.filled(20, 1.2),
      onTooltipData: (r) => rows = r,
    ));
    await tester.pumpAndSettle();

    expect(_barColors(tester), contains(_purple));
    expect(_barColors(tester), isNot(contains(ProfileMetricColors.ppO2)));
    await _touchCentre(tester, () => rows);
    expect(rows!.map((r) => r.bulletColor), contains(_purple));
  });

  testWidgets('a chosen pressure colour draws a single tank, and its '
      'threshold markers', (tester) async {
    final settings = AppSettings(
      profileMetricColors: ProfileMetricColorOverrides.none.withColor(
        ProfileMetric.pressure,
        _greenA400,
      ),
    );
    await tester.pumpWidget(_harness(
      settings: settings,
      profile: _profile(),
      tankPressures: {
        't1': [
          for (var i = 0; i < 20; i++)
            TankPressurePoint(tankId: 't1', timestamp: i * 30, pressure: 200.0 - i * 5),
        ],
      },
    ));
    await tester.pumpAndSettle();
    expect(_barColors(tester), contains(_greenA400));
  });

  testWidgets('a multi-tank dive keeps per-gas colours whatever the '
      'pressure colour', (tester) async {
    final settings = AppSettings(
      profileMetricColors: ProfileMetricColorOverrides.none.withColor(
        ProfileMetric.pressure,
        _greenA400,
      ),
    );
    List<TankPressurePoint> series(String id) => [
      for (var i = 0; i < 20; i++)
        TankPressurePoint(tankId: id, timestamp: i * 30, pressure: 200.0 - i * 5),
    ];
    await tester.pumpWidget(_harness(
      settings: settings,
      profile: _profile(),
      tankPressures: {'t1': series('t1'), 't2': series('t2')},
    ));
    await tester.pumpAndSettle();
    expect(_barColors(tester), isNot(contains(_greenA400)));
  });

  testWidgets('the right axis label takes the palette colour', (tester) async {
    final settings = AppSettings(
      defaultRightAxisMetric: ProfileRightAxisMetric.ndl,
      defaultShowNdl: true,
    );
    await tester.pumpWidget(_harness(
      settings: settings,
      profile: _profile(),
      ndlCurve: List<int>.filled(20, 1200),
    ));
    await tester.pumpAndSettle();
    final axisColors = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.style?.color)
        .whereType<Color>();
    expect(axisColors, contains(ProfileMetricColors.ndl));
  });
}
```

The `_harness` takes `AppSettings settings` and forwards `ppO2Curve`, `ndlCurve`, `tankPressures` and `onTooltipData` to `DiveProfileChart`. Check the actual `AppSettings` field names for the NDL default toggle and the right-axis default (`grep -n "defaultShowNdl\|defaultRightAxisMetric" lib/features/settings/presentation/providers/settings_providers.dart`) and the right axis's source (`profileLegendProvider` seeds from settings); adjust the field names, not the assertions. For the marker half of the second test, also pass `markers: [ProfileMarker(timestamp: 300, depth: 10, type: ProfileMarkerType.pressureHalf, tankId: 't1', tankIndex: 0, value: 100)]` and assert the drawn marker colour through whatever the chart exposes for markers (read how `dive_profile_chart_test.dart` asserts marker drawing first); if markers are painted without an inspectable widget, assert `ProfileMarker.getColor` directly in a unit test instead.

Run: `flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_metric_colors_test.dart`
Expected: FAIL (the chart ignores `profileMetricColors`).

- [ ] **Step 2: Give the builders colour parameters**

In `profile_metric_line_builders.dart`, for each of `buildSacLine`, `buildCeilingLine`, `buildNdlLine`, `buildModLine`, `buildDensityLine`, `buildGfLine`, `buildSurfaceGfLine`, `buildMeanDepthLine`, `buildTtsLine`, `buildGtrLine`, `buildCnsLine`, `buildOtuLine`: add `Color color,` as the first positional parameter and delete the local `const xColor = ProfileMetricColors.x;` line, renaming its uses to `color`. In `buildGtrLine`, replace `color: ProfileRightAxisMetric.gtr.color!,` with `color: color,`. Remove the `profile_metric_colors.dart` import if it becomes unused.

In `partial_pressure_line_builders.dart`, add `Color color,` as the first positional parameter of `buildPpO2Line`, `buildPpN2Line`, `buildPpHeLine` and pass `color: color` instead of `color: ProfileMetricColors.ppX`.

In `tank_line_builders.dart`, add a named parameter `Color? singleTankColor` to `buildMultiTankPressureLines` and replace the colour expression with:

```dart
    // A diver's chosen pressure colour applies on a single-tank dive only;
    // with several tanks the gas colours are what tell them apart.
    final color = sortedIds.length == 1 && singleTankColor != null
        ? singleTankColor
        : tank != null
        ? GasColors.forGasMix(tank.gasMix)
        : getTankColor(i);
```

In `ProfileMarker.getColor` (`profile_markers_service.dart`):

```dart
  Color getColor({List<Color>? tankColors, Color? maxDepthColor}) {
    if (type == ProfileMarkerType.maxDepth) {
      // Pink 900 - distinct from the heart-rate red curve.
      return maxDepthColor ?? const Color(0xFF880E4F);
    }
```

(rest unchanged).

- [ ] **Step 3: Resolve the palette in the chart**

In `dive_profile_chart.dart`:

1. Imports: `profile_colors/profile_metric.dart`, `profile_colors/profile_metric_palette.dart`.
2. State field beside the other build-time fields: `late ProfileMetricPalette _palette;`
3. In `build`, directly after `final settings = ref.watch(settingsProvider);`:

```dart
    _palette = ProfileMetricPalette(
      overrides: settings.profileMetricColors,
      temperatureAuto: Theme.of(context).colorScheme.tertiary,
    );
```

4. Helper methods in the state class:

```dart
  Color _metricColor(ProfileMetric metric) => _palette.colorOf(metric);

  /// The single tank's chosen pressure colour, or null (several tanks, or
  /// pressure on Auto).
  Color? get _singleTankPressureColor =>
      (widget.tankPressures?.length ?? 0) == 1 ? _palette.pressureOverride : null;
```

- [ ] **Step 4: Replace every colour site**

Work through this table, finding each site with the grep given (line numbers drift). `P(x)` means `_metricColor(ProfileMetric.x)`.

| Site (grep) | Replace with |
| --- | --- |
| `_velocityDepthColor`: `? AppColors.chartDepth` | `? P(depth)` |
| tooltip depth row `bulletColor: AppColors.chartDepth,` | `bulletColor: P(depth),` |
| `_overlayColor(overlay, ProfileMetricColors.depth)` (2 sites) | `_overlayColor(overlay, P(depth))` |
| `const depthColor = AppColors.chartDepth;` | `final depthColor = P(depth);` |
| tooltip temperature `bulletColor: colorScheme.tertiary,` | `bulletColor: P(temperature),` |
| `_overlayColor(overlay, colorScheme.tertiary)` | `_overlayColor(overlay, P(temperature))` |
| temperature overlay line `Theme.of(context).colorScheme.tertiary,` (inside `_overlayColor`) | `P(temperature),` |
| temperature line `color: colorScheme.tertiary,` (in the temperature line builder method) | `color: P(temperature),` |
| tooltip ceiling `bulletColor: const Color(0xFF7B1FA2),` | `bulletColor: P(ceiling),` |
| tooltip heart rate `bulletColor: Colors.red,` | `bulletColor: P(heartRate),` |
| tooltip SAC `bulletColor: Colors.teal,` | `bulletColor: P(sac),` |
| tooltip NDL `bulletColor: Colors.yellow.shade700,` | `bulletColor: P(ndl),` |
| tooltip ppO2 `bulletColor: const Color(0xFF00ACC1),` | `bulletColor: P(ppO2),` |
| tooltip ppN2 `bulletColor: Colors.indigo,` | `bulletColor: P(ppN2),` |
| tooltip ppHe `bulletColor: Colors.pink.shade300,` | `bulletColor: P(ppHe),` |
| tooltip MOD `bulletColor: const Color(0xFFFFB300),` | `bulletColor: P(mod),` |
| tooltip density `bulletColor: const Color(0xFF827717),` | `bulletColor: P(density),` |
| tooltip GF `bulletColor: Colors.deepPurple,` | `bulletColor: P(gf),` |
| tooltip surface GF `bulletColor: Colors.purple.shade300,` | `bulletColor: P(surfaceGf),` |
| tooltip mean depth `bulletColor: Colors.blueGrey,` | `bulletColor: P(meanDepth),` |
| tooltip TTS `bulletColor: const Color(0xFFAD1457),` | `bulletColor: P(tts),` |
| tooltip GTR `bulletColor: ProfileRightAxisMetric.gtr.color!,` | `bulletColor: P(gtr),` |
| tooltip CNS `bulletColor: const Color(0xFFE65100),` | `bulletColor: P(cns),` |
| tooltip OTU `bulletColor: const Color(0xFF6D4C41),` | `bulletColor: P(otu),` |
| every `ProfileMetricColors.<x>` passed to `_overlayColor` or as an overlay row `color:` for ceiling, ndl, tts, gtr, mod, meanDepth, ppO2, ppN2, ppHe, density, gf, surfaceGf, cns, otu | `P(<x>)` |
| `const heartRateColor = ProfileMetricColors.heartRate;` | `final heartRateColor = P(heartRate);` |
| each `_buildXLine(...)` wrapper calling a builder from Step 2 | pass `P(x)` as the new first argument |
| tooltip tank row `final color = tank != null ? GasColors.forGasMix(tank.gasMix) : _getTankColor(i);` | `final color = _singleTankPressureColor ?? (tank != null ? GasColors.forGasMix(tank.gasMix) : _getTankColor(i));` |
| `_buildMultiTankPressureLines` | add `singleTankColor: _singleTankPressureColor,` |
| `marker.getColor()` (2 sites) | `marker.getColor(maxDepthColor: P(maxDepth), tankColors: _singleTankPressureColor == null ? null : [_singleTankPressureColor!])` |
| right axis `effectiveRightAxisMetric.getColor(colorScheme)` and `effectiveRightAxisMetric.getColor(\n colorScheme,\n)` | `_palette.rightAxisColor(effectiveRightAxisMetric)` |
| right-axis menu `metric.getColor(colorScheme)` | `_palette.rightAxisColor(metric)` |

Leave alone: `ProfileMetricColors.decoStops` (not recolourable), ascent-rate and O2 cell colours, `DiveProfileMiniChart`, and the `colorScheme.primary` playback cursor.

Then: `grep -n "ProfileMetricColors\.\|AppColors.chartDepth\|colorScheme.tertiary\|Color(0xFF" lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` and confirm every remaining hit is on the leave-alone list.

- [ ] **Step 5: Run the new test and fix the builder call-site fallout**

```bash
flutter test test/features/dive_log/presentation/widgets/dive_profile_chart_metric_colors_test.dart
flutter analyze
```

Expected: the new test PASSES. `flutter analyze` lists each test that calls a builder with the old arity; pass the metric's default (`ProfileMetricColors.x`) as the new first argument there, which keeps those tests' existing colour assertions meaningful.

- [ ] **Step 6: Run the chart suite**

Run: `flutter test test/features/dive_log/presentation/widgets/`
Expected: PASS. A test that asserted the right axis NDL colour was Light Green 700 (`0xFF689F38`) is asserting the old mismatch; change it to `ProfileMetricColors.ndl` and say so in the commit message.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/dive_log test/features/dive_log
git add lib/features/dive_log test/features/dive_log
git commit -m "feat(dive-log): draw profile metrics in the diver's chosen colours"
```

---

### Task 6: Legend and options dialog

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/active_legend_entries.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_profile_legend.dart` (the `activeLegendEntries` call)
- Modify: `lib/features/dive_log/presentation/widgets/chart_options_dialog.dart`
- Test: `test/features/dive_log/presentation/widgets/active_legend_entries_test.dart` (extend)
- Test: `test/features/dive_log/presentation/widgets/chart_options_dialog_metric_colors_test.dart`

**Interfaces:**
- Consumes: `ProfileMetricPalette`, `ProfileMetric`.
- Produces: `activeLegendEntries(context, {required config, required state, required ProfileMetricPalette palette})`.

- [ ] **Step 1: Write the failing legend test**

Add to `active_legend_entries_test.dart` (reuse its existing pump helper; it currently calls `activeLegendEntries(context, config: config, state: state)`, so add a `palette` argument to that helper with a default of `ProfileMetricPalette(overrides: ProfileMetricColorOverrides.none, temperatureAuto: Theme.of(context).colorScheme.tertiary)`):

```dart
  testWidgets('a chosen colour reaches the legend entry', (tester) async {
    final entries = await pumpEntries(
      tester,
      config: const ProfileLegendConfig(hasPpO2: true),
      state: const ProfileLegendState(showPpO2: true),
      overrides: ProfileMetricColorOverrides.none.withColor(
        ProfileMetric.ppO2,
        const Color(0xFFE040FB),
      ),
    );
    expect(
      entries.singleWhere((e) => e.label == 'ppO2').color,
      const Color(0xFFE040FB),
    );
  });
```

(Use the file's real config/state constructors and the real ppO2 label; read the file's first test for both.)

Run: `flutter test test/features/dive_log/presentation/widgets/active_legend_entries_test.dart`
Expected: FAIL (no `palette` parameter).

- [ ] **Step 2: Thread the palette through the legend**

In `active_legend_entries.dart`, add `required ProfileMetricPalette palette` and replace, for the recolourable metrics, `ProfileMetricColors.<x>` with `palette.colorOf(ProfileMetric.<x>)` and `colorScheme.tertiary` (temperature) with `palette.colorOf(ProfileMetric.temperature)`. For the pressure-threshold markers entry, use `palette.pressureOverride != null && config.tankPressures?.length == 1 ? palette.pressureOverride! : ProfileMetricColors.pressureMarkers`. For the per-tank entries, use `config.tankPressures?.length == 1 && palette.pressureOverride != null ? palette.pressureOverride! : (tank != null ? GasColors.forGasMix(tank.gasMix) : tankFallbackColor(i))`. Leave events, ascent-rate, deco-stop, gas and O2 cell entries as they are. Update the doc comment's "Colours come from [ProfileMetricColors]" to say they come from the diver's [ProfileMetricPalette].

In `dive_profile_legend.dart`, build the palette where it calls `activeLegendEntries` (it is inside a widget with `ref`; if not, read `settingsProvider` through the nearest `Consumer`), passing `ProfileMetricPalette(overrides: ref.watch(settingsProvider.select((s) => s.profileMetricColors)), temperatureAuto: Theme.of(context).colorScheme.tertiary)`.

Run the legend test. Expected: PASS.

- [ ] **Step 3: Write the failing dialog test**

`test/features/dive_log/presentation/widgets/chart_options_dialog_metric_colors_test.dart`: pump `ChartOptionsDialog` the way the existing dialog test does (`grep -rln "ChartOptionsDialog(" test`), inside a `MaterialApp.router` with a `GoRouter` that has `/` (the dialog host) and `/settings/metric-colors` (a `Text('colors page')`), and settings with ppO2 set to Purple A200.

```dart
  testWidgets('swatches follow the chosen colour', (tester) async {
    // pump as above with config hasPpO2: true
    final swatch = find.descendant(
      of: find.ancestor(of: find.text('ppO2'), matching: find.byType(Row)).first,
      matching: find.byWidgetPredicate(
        (w) => w is Container && (w.decoration as BoxDecoration?)?.color == const Color(0xFFE040FB),
      ),
    );
    expect(swatch, findsWidgets);
  });

  testWidgets('the Metric Colors link opens the settings page', (tester) async {
    // pump as above
    await tester.scrollUntilVisible(find.text('Metric Colors'), 100);
    await tester.tap(find.text('Metric Colors'));
    await tester.pumpAndSettle();
    expect(find.text('colors page'), findsOneWidget);
  });
```

(Read `buildToggleItem` in `chart_options_dialog_rows.dart` for how the swatch is drawn, and match the finder to it.)

Run it. Expected: FAIL.

- [ ] **Step 4: Thread the palette through the dialog and add the link**

In `chart_options_dialog.dart`: in the `Consumer` builder, build `final palette = ProfileMetricPalette(overrides: ref.watch(settingsProvider.select((s) => s.profileMetricColors)), temperatureAuto: Theme.of(context).colorScheme.tertiary);` and pass it into `_buildSections` (new `required ProfileMetricPalette palette` parameter). Replace the recolourable `ProfileMetricColors.<x>` and the temperature `colorScheme.tertiary` swatches with `palette.colorOf(...)`, and the per-tank and threshold-marker swatches with the single-tank rule from Task 6 Step 2. Then add, as the last child of the Display section:

```dart
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.palette_outlined, size: 18),
              label: Text(context.l10n.settings_appearance_metricColors),
              onPressed: () {
                // Capture the router before the pop unmounts this context.
                final router = GoRouter.of(context);
                Navigator.of(context).pop();
                router.push('/settings/metric-colors');
              },
            ),
          ),
```

(import `package:go_router/go_router.dart`). Run the dialog test. Expected: PASS.

- [ ] **Step 5: Run the dive log widget suite and commit**

```bash
dart format lib/features/dive_log test/features/dive_log
flutter analyze
flutter test test/features/dive_log/presentation/widgets/
git add lib/features/dive_log test/features/dive_log
git commit -m "feat(dive-log): show chosen metric colours in the legend and chart options"
```

---

### Task 7: Settings page, palette sheet and entry tile

**Files:**
- Create: `lib/features/settings/presentation/pages/profile_metric_colors_page.dart`
- Create: `lib/features/settings/presentation/widgets/profile_metric_color_sheet.dart`
- Modify: `lib/core/router/app_router.dart` (route beside `default-metrics`)
- Modify: `lib/features/settings/presentation/pages/section_appearance_page.dart` (tile after "Default Visible Metrics")
- Test: `test/features/settings/presentation/pages/profile_metric_colors_page_test.dart`
- Test: `test/features/settings/presentation/pages/section_appearance_page_test.dart` (extend)

**Interfaces:**
- Consumes: `ProfileMetric`, `ProfileMetricPalette`, `ProfileMetricColorOverrides`, `profileMetricSwatches`, `profileMetricLabel`, `swatchName`, notifier setters, Task 2 strings.
- Produces: route `/settings/metric-colors` named `metricColors`; `ProfileMetricColorsPage`; `Future<void> showProfileMetricColorSheet(BuildContext context, {required ProfileMetric metric, required ProfileMetricPalette palette, required ValueChanged<Color?> onPicked})`.

- [ ] **Step 1: Write the failing page tests**

`test/features/settings/presentation/pages/profile_metric_colors_page_test.dart`, with a stub notifier in the style of `default_visible_metrics_page_test.dart`:

```dart
class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier([AppSettings? s]) : super(s ?? const AppSettings());

  @override
  Future<void> setProfileMetricColor(ProfileMetric metric, Color? color) async =>
      state = state.copyWith(
        profileMetricColors: state.profileMetricColors.withColor(metric, color),
      );

  @override
  Future<void> resetProfileMetricColors() async => state = state.copyWith(
    profileMetricColors: ProfileMetricColorOverrides.none,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _page(_StubSettingsNotifier n) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => n)],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: Locale('en'),
    home: ProfileMetricColorsPage(),
  ),
);

void main() {
  testWidgets('lists all 20 metrics with section headers', (tester) async {
    await tester.pumpWidget(_page(_StubSettingsNotifier()));
    await tester.pumpAndSettle();
    for (final label in ['Depth', 'Mean Depth']) {
      await tester.scrollUntilVisible(find.text(label), 200);
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('metricColorRow')), findsWidgets);
  });

  testWidgets('Auto metrics say so in their subtitle', (tester) async {
    await tester.pumpWidget(_page(_StubSettingsNotifier()));
    await tester.pumpAndSettle();
    expect(find.text('Auto: follows the theme'), findsOneWidget);
    expect(find.text('Auto: each gas has its own color'), findsOneWidget);
  });

  testWidgets('the sheet labels a held swatch and tapping it swaps', (
    tester,
  ) async {
    final n = _StubSettingsNotifier();
    await tester.pumpWidget(_page(n));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('ppO2'), 200);
    await tester.tap(find.text('ppO2'));
    await tester.pumpAndSettle();
    // TTS's Pink 800 carries the TTS label beneath it.
    final tts = find.bySemanticsLabel(RegExp('Swaps with TTS'));
    expect(tts, findsOneWidget);
    await tester.tap(tts);
    await tester.pumpAndSettle();
    expect(
      n.state.profileMetricColors.effectiveArgb(ProfileMetric.tts),
      ProfileMetricColors.ppO2.toARGB32(),
    );
  });

  testWidgets('Reset all is disabled with nothing customised, and clears '
      'after confirming', (tester) async {
    final n = _StubSettingsNotifier(AppSettings(
      profileMetricColors: ProfileMetricColorOverrides.none.withColor(
        ProfileMetric.ppO2,
        const Color(0xFFE040FB),
      ),
    ));
    await tester.pumpWidget(_page(n));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reset all'));
    await tester.pumpAndSettle();
    expect(find.text('Reset metric colors?'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(n.state.profileMetricColors, ProfileMetricColorOverrides.none);
    final button = tester.widget<IconButton>(
      find.ancestor(of: find.byIcon(Icons.restart_alt), matching: find.byType(IconButton)),
    );
    expect(button.onPressed, isNull);
  });
}
```

(Use the real English legend labels for Depth, Mean Depth, ppO2 and TTS from `app_en.arb`.)

Run it. Expected: FAIL to compile (page missing).

- [ ] **Step 2: Implement the sheet**

`lib/features/settings/presentation/widgets/profile_metric_color_sheet.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_label.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_palette.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_swatches.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/swatch_name.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The colour choice for one profile metric (issue #3012): Default (or
/// Auto), then every palette swatch. A swatch another metric shows names it,
/// since picking it swaps the two.
Future<void> showProfileMetricColorSheet(
  BuildContext context, {
  required ProfileMetric metric,
  required ProfileMetricPalette palette,
  required ValueChanged<Color?> onPicked,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _SheetBody(
          metric: metric,
          palette: palette,
          onPicked: (color) {
            Navigator.of(sheetContext).pop();
            onPicked(color);
          },
        ),
      ),
    ),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.metric,
    required this.palette,
    required this.onPicked,
  });

  final ProfileMetric metric;
  final ProfileMetricPalette palette;
  final ValueChanged<Color?> onPicked;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = palette.overrides.effectiveArgb(metric);
    final onDefault = palette.overrides.argbOf(metric) == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settings_metricColors_sheetTitle(profileMetricLabel(l10n, metric)),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _Swatch(
              // The colour Default/Auto gives, not the current choice.
              color:
                  metric.defaultColor ??
                  (metric == ProfileMetric.temperature
                      ? palette.temperatureAuto
                      : ProfileMetricColors.pressure),
              selected: onDefault,
              caption: metric.isAuto
                  ? l10n.settings_metricColors_auto
                  : l10n.settings_metricColors_default,
              semanticsLabel: metric.isAuto
                  ? l10n.settings_metricColors_auto
                  : l10n.settings_metricColors_default,
              onTap: () => onPicked(null),
            ),
            for (final swatch in profileMetricSwatches)
              _buildSwatch(context, swatch, current),
          ],
        ),
      ],
    );
  }

  Widget _buildSwatch(BuildContext context, Color swatch, int? current) {
    final l10n = context.l10n;
    final argb = swatch.toARGB32();
    final holder = palette.overrides.holderOf(argb, except: metric);
    final holderLabel = holder == null ? null : profileMetricLabel(l10n, holder);
    final name = swatchName(l10n, swatch);
    return _Swatch(
      color: swatch,
      selected: argb == current && palette.overrides.argbOf(metric) != null,
      caption: holderLabel,
      semanticsLabel: holderLabel == null
          ? name
          : '$name, ${l10n.settings_metricColors_swapsWith(holderLabel)}',
      onTap: () => onPicked(swatch),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
    this.caption,
  });

  final Color color;
  final bool selected;
  final String semanticsLabel;
  final String? caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: SizedBox(
          width: 56,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Center(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? scheme.onSurface : scheme.outlineVariant,
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 16,
                child: caption == null
                    ? null
                    : Text(
                        caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

The "selected" rule: the Default swatch is ringed when the metric has no override; a palette swatch is ringed when it is the metric's override. (On defaults, the default swatch and the palette swatch of the same colour would otherwise both ring.)

- [ ] **Step 3: Implement the page**

`lib/features/settings/presentation/pages/profile_metric_colors_page.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_label.dart';
import 'package:submersion/features/dive_log/presentation/profile_colors/profile_metric_palette.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/profile_metric_color_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Appearance > Dives > Metric Colors (issue #3012).
class ProfileMetricColorsPage extends ConsumerWidget {
  const ProfileMetricColorsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overrides = ref.watch(
      settingsProvider.select((s) => s.profileMetricColors),
    );
    final palette = ProfileMetricPalette(
      overrides: overrides,
      temperatureAuto: Theme.of(context).colorScheme.tertiary,
    );
    final notifier = ref.read(settingsProvider.notifier);

    Widget row(ProfileMetric metric) => _MetricRow(
      key: const ValueKey('metricColorRow'),
      metric: metric,
      palette: palette,
      onTap: () => showProfileMetricColorSheet(
        context,
        metric: metric,
        palette: palette,
        onPicked: (color) => notifier.setProfileMetricColor(metric, color),
      ),
    );

    Widget header(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings_appearance_metricColors),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: l10n.settings_metricColors_resetAll,
            onPressed: overrides.isEmpty
                ? null
                : () => _confirmReset(context, notifier),
          ),
        ],
      ),
      body: ListView(
        children: [
          row(ProfileMetric.depth),
          header(l10n.diveLog_chartSection_overlays),
          for (final m in const [
            ProfileMetric.temperature,
            ProfileMetric.pressure,
            ProfileMetric.heartRate,
            ProfileMetric.sac,
          ])
            row(m),
          header(l10n.diveLog_chartSection_markers),
          row(ProfileMetric.maxDepth),
          header(l10n.diveLog_chartSection_decompression),
          for (final m in const [
            ProfileMetric.ceiling,
            ProfileMetric.ndl,
            ProfileMetric.tts,
            ProfileMetric.gtr,
            ProfileMetric.cns,
            ProfileMetric.otu,
          ])
            row(m),
          header(l10n.diveLog_chartSection_gasAnalysis),
          for (final m in const [
            ProfileMetric.ppO2,
            ProfileMetric.ppN2,
            ProfileMetric.ppHe,
            ProfileMetric.mod,
            ProfileMetric.density,
          ])
            row(m),
          header(l10n.diveLog_chartSection_other),
          for (final m in const [
            ProfileMetric.gf,
            ProfileMetric.surfaceGf,
            ProfileMetric.meanDepth,
          ])
            row(m),
        ],
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    SettingsNotifier notifier,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settings_metricColors_resetAllTitle),
        content: Text(l10n.settings_metricColors_resetAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.settings_metricColors_reset),
          ),
        ],
      ),
    );
    if (confirmed == true) await notifier.resetProfileMetricColors();
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    super.key,
    required this.metric,
    required this.palette,
    required this.onTap,
  });

  final ProfileMetric metric;
  final ProfileMetricPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final custom = palette.overrides.argbOf(metric) != null;
    final subtitle = switch (metric) {
      ProfileMetric.temperature when !custom =>
        l10n.settings_metricColors_autoTemperature,
      ProfileMetric.pressure when !custom => l10n.settings_metricColors_autoPressure,
      ProfileMetric.pressure => l10n.settings_metricColors_pressureCustom,
      _ => null,
    };
    return ListTile(
      title: Text(profileMetricLabel(l10n, metric)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: palette.colorOf(metric),
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      onTap: onTap,
    );
  }
}
```

- [ ] **Step 4: Route and entry tile**

In `app_router.dart`, after the `default-metrics` `GoRoute`:

```dart
              GoRoute(
                path: 'metric-colors',
                name: 'metricColors',
                builder: (context, state) => const ProfileMetricColorsPage(),
              ),
```

(import the page). In `section_appearance_page.dart` `_buildDiveProfileSettings`, directly after the "Default visible metrics" `ListTile`:

```dart
      ListTile(
        leading: const Icon(Icons.palette_outlined),
        title: Text(context.l10n.settings_appearance_metricColors),
        subtitle: Text(
          settings.profileMetricColors.isEmpty
              ? context.l10n.settings_appearance_metricColors_subtitleDefault
              : context.l10n.settings_appearance_metricColors_subtitleCustomized(
                  settings.profileMetricColors.count,
                ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings/metric-colors'),
      ),
```

Add to `section_appearance_page_test.dart`, next to the existing default-visible-metrics tile test, a test that the dive section shows "Metric Colors" with subtitle "Default colors", and "1 customized" when one override is set.

- [ ] **Step 5: Run the page, appearance, route and architecture tests**

```bash
flutter test test/features/settings/presentation/pages/profile_metric_colors_page_test.dart test/features/settings/presentation/pages/section_appearance_page_test.dart test/features/settings/presentation/pages/settings_manage_nav_routes_test.dart
flutter test test/architecture/ test/shared/
```

Expected: PASS. If the page test's held-swatch finder fails, debug with `tester.getSemantics`; the semantics label is "<name>, Swaps with TTS".

- [ ] **Step 6: Commit**

```bash
dart format lib test
flutter analyze
git add lib/features/settings lib/core/router/app_router.dart test/features/settings
git commit -m "feat(settings): choose profile metric colors under Appearance"
```

---

### Task 8: Whole-branch verification

- [ ] **Step 1: Format and analyze the whole repo**

```bash
dart format .
flutter analyze
```

Expected: no changes from format beyond this branch's files; analyze clean.

- [ ] **Step 2: Run every affected suite**

```bash
flutter test test/features/dive_log test/features/settings test/core/database test/core/services/sync test/architecture test/shared
```

Expected: PASS. Log long runs to the scratchpad, never to `.superpowers/`.

- [ ] **Step 3: Check the strings shipped translated**

```bash
grep -A2 "get settings_appearance_metricColors\b" lib/l10n/arb/app_localizations_fr.dart lib/l10n/arb/app_localizations_zh.dart
git diff --numstat origin/main -- lib/l10n/arb/*.arb
```

Expected: French and Chinese bodies, not English; equal added-line counts across locales.

- [ ] **Step 4: Scan for em dashes in the branch's additions**

```bash
git diff origin/main -- . ':(exclude)lib/l10n/arb/app_localizations*.dart' | grep '^+' | grep -c $'\xe2\x80\x94'
```

Expected: `0`.
