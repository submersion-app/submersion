# Weight Planner Attribute-Informed Priors Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Feed equipment attributes (multi-panel thickness, suit style, shell material, glove type, BCD style, lift capacity) into the weight planner's per-item buoyancy priors.

**Architecture:** A new pure value object `GearBuoyancyTraits` carries attribute data from the bridge (`gearFeatureFor`, the only code that knows `EquipmentAttribute`) into `GearFeature.fromEquipment`, which resolves priors through a strict ladder: explicit `buoyancy_kg` (strength 8.0) → attribute-derived physics factors (4.0) → legacy string parse (4.0) → flat type defaults (2.0). The ridge engine, physics, observations, and UI are untouched.

**Tech Stack:** Pure Dart in `lib/core/buoyancy/` (no Flutter/DB imports there); Riverpod bridge in the weight-planner feature.

**Spec:** `docs/superpowers/specs/2026-07-17-weight-planner-attribute-priors-design.md`

## Global Constraints

- **Stacked branch:** `worktree-weight-planner-attributes` is based on `worktree-equipment-attributes` (PR #608) and merges after it. Do not rebase onto main.
- **No schema/migration/sync/UI changes.** If a step seems to need one, stop — it's a design error.
- `lib/core/buoyancy/` must stay pure Dart: no imports from `features/`, Flutter, or Drift.
- **Deliberate behavior changes (spec-sanctioned, update the pinned tests, do not "fix" back):** wetsuit prior clamp rises 8→10 kg; legacy string-parsed wetsuit thickness strength rises 2.0→4.0.
- Exact factor values are normative from the spec: suit styles full 1.0 / semi_dry 1.1 / two_piece 1.35 / shorty 0.55; drysuit neoprene 13.0 / crushed_neoprene 11.0 / trilaminate 9.0 / vulcanized_rubber 9.0 / absent 10.0; per-mm hood 0.10 / gloves 0.06 / boots 0.12; glove type mitt ×1.15 / dry ×0.5; BCD jacket +0.5 / back_inflate 0.0 / wing −0.5 / sidemount −0.3 / absent −0.5; bladder +0.01 kg per kg lift. Clamps: effective thickness [0,15] mm; wetsuit prior [0,10] kg; hood/gloves/boots [0,2] kg; BCD [−2,2] kg.
- Strength rule: 4.0 when at least one contributing attribute was present for that type (wetsuit and accessories require thickness; drysuit requires shell material; BCD requires style OR lift); else 2.0.
- Run `dart format .` before every commit; never pipe `flutter analyze` through `tail` in a way that masks its exit code; run specific test files, not the whole suite.
- **Before Task 1:** this fresh worktree needs codegen once: `dart run build_runner build --delete-conflicting-outputs`.

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/core/buoyancy/gear_buoyancy_traits.dart` (create) | attribute snapshot value object + panel-designation parser |
| `lib/core/buoyancy/gear_feature.dart` (modify) | prior ladder + per-type factor functions |
| `lib/features/weight_planner/presentation/providers/weight_planner_providers.dart` (modify) | bridge builds traits from the attribute store |
| `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` (modify) | five new `EquipmentAttrKeys` constants, referenced by the catalog |
| `test/core/buoyancy/gear_buoyancy_traits_test.dart` (create) | parser + equality |
| `test/core/buoyancy/gear_feature_test.dart` (modify) | factor table, ladder, regression pins |
| `test/features/weight_planner/presentation/weight_planner_providers_test.dart` (modify) | bridge trait construction |
| `test/core/buoyancy/weight_prediction_engine_test.dart` (modify) | end-to-end shorty-vs-full and drysuit-material behaviors |

---

### Task 1: GearBuoyancyTraits value object + panel parser

**Files:**
- Create: `lib/core/buoyancy/gear_buoyancy_traits.dart`
- Test: `test/core/buoyancy/gear_buoyancy_traits_test.dart` (create)

**Interfaces:**
- Produces: `class GearBuoyancyTraits { double? primaryThicknessMm; List<double> panelThicknessesMm; String? suitStyle; String? shellMaterial; String? bcdStyle; double? liftCapacityKg; String? gloveType; }` (const ctor, all named optional, Equatable) and `static List<double> parsePanelsMm(String text)`.

- [ ] **Step 0: One-time worktree codegen**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: completes with "wrote N outputs" (fresh worktree has no generated files).

- [ ] **Step 1: Write the failing test**

Create `test/core/buoyancy/gear_buoyancy_traits_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/gear_buoyancy_traits.dart';

void main() {
  test('parsePanelsMm handles single and multi-panel designations', () {
    expect(GearBuoyancyTraits.parsePanelsMm('5'), [5.0]);
    expect(GearBuoyancyTraits.parsePanelsMm('5/4'), [5.0, 4.0]);
    expect(GearBuoyancyTraits.parsePanelsMm('8/7/6'), [8.0, 7.0, 6.0]);
    expect(GearBuoyancyTraits.parsePanelsMm('4,3'), [4.0, 3.0]);
    expect(GearBuoyancyTraits.parsePanelsMm('6-3'), [6.0, 3.0]);
    expect(GearBuoyancyTraits.parsePanelsMm('6/5/4mm'), [6.0, 5.0, 4.0]);
    expect(GearBuoyancyTraits.parsePanelsMm('5.5 mm'), [5.5]);
  });

  test('parsePanelsMm skips garbage and empty segments', () {
    expect(GearBuoyancyTraits.parsePanelsMm('thin'), isEmpty);
    expect(GearBuoyancyTraits.parsePanelsMm(''), isEmpty);
    expect(GearBuoyancyTraits.parsePanelsMm('5/x/3'), [5.0, 3.0]);
    expect(GearBuoyancyTraits.parsePanelsMm(' 7 / 5 '), [7.0, 5.0]);
  });

  test('value equality', () {
    const a = GearBuoyancyTraits(
      primaryThicknessMm: 5,
      panelThicknessesMm: [5, 4],
      suitStyle: 'full',
    );
    const b = GearBuoyancyTraits(
      primaryThicknessMm: 5,
      panelThicknessesMm: [5, 4],
      suitStyle: 'full',
    );
    expect(a, b);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/buoyancy/gear_buoyancy_traits_test.dart`
Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement**

Create `lib/core/buoyancy/gear_buoyancy_traits.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Attribute-derived facts about one equipment item that influence its
/// buoyancy prior. Built by the weight-planner bridge from the equipment
/// attribute store; the buoyancy engine has no knowledge of that store.
///
/// String fields carry the attribute system's stable choice keys
/// ('shorty', 'trilaminate', 'wing', ...), never display strings.
class GearBuoyancyTraits extends Equatable {
  final double? primaryThicknessMm;
  final List<double> panelThicknessesMm;
  final String? suitStyle;
  final String? shellMaterial;
  final String? bcdStyle;
  final double? liftCapacityKg;
  final String? gloveType;

  const GearBuoyancyTraits({
    this.primaryThicknessMm,
    this.panelThicknessesMm = const [],
    this.suitStyle,
    this.shellMaterial,
    this.bcdStyle,
    this.liftCapacityKg,
    this.gloveType,
  });

  static final RegExp _panelSeparators = RegExp(r'[/,\-]');
  static final RegExp _number = RegExp(r'(\d+(?:\.\d+)?)');

  /// Parses a thickness designation into its panel values, thickest-first by
  /// convention ("5/4/3" -> [5,4,3]). Tolerates `mm` suffixes, whitespace,
  /// and `,`/`-` separators; unparseable segments are skipped.
  static List<double> parsePanelsMm(String text) {
    final panels = <double>[];
    for (final segment in text.split(_panelSeparators)) {
      final match = _number.firstMatch(segment);
      if (match == null) continue;
      final value = double.tryParse(match.group(1)!);
      if (value != null) panels.add(value);
    }
    return panels;
  }

  @override
  List<Object?> get props => [
    primaryThicknessMm,
    panelThicknessesMm,
    suitStyle,
    shellMaterial,
    bcdStyle,
    liftCapacityKg,
    gloveType,
  ];
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/buoyancy/gear_buoyancy_traits_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(buoyancy): GearBuoyancyTraits attribute snapshot with panel parser"
```

---

### Task 2: GearFeature prior ladder + factor functions

**Files:**
- Modify: `lib/core/buoyancy/gear_feature.dart`
- Test: `test/core/buoyancy/gear_feature_test.dart` (extend + update two pins)

**Interfaces:**
- Consumes: `GearBuoyancyTraits` (Task 1).
- Produces: `GearFeature.fromEquipment({..., GearBuoyancyTraits? traits})`; internal statics `_attributePrior`, `_effectiveThicknessMm`, `_typeDefault`. Existing public surface (`GearFeature` fields, `priorStrength` semantics) otherwise unchanged — Task 3 relies on the new `traits:` named parameter only.

- [ ] **Step 1: Write the failing tests**

Append to `test/core/buoyancy/gear_feature_test.dart` (inside `main()`; reuse the file's existing `feature(...)` helper if present, else construct directly as shown):

```dart
  group('attribute-derived priors', () {
    GearFeature suit({GearBuoyancyTraits? traits, String name = 'Suit'}) =>
        GearFeature.fromEquipment(
          id: 'w1',
          type: EquipmentType.wetsuit,
          name: name,
          traits: traits,
        );

    test('multi-panel blend: torso 0.5 + limb mean 0.5', () {
      final f = suit(
        traits: const GearBuoyancyTraits(panelThicknessesMm: [5, 4, 3]),
      );
      // 5*0.5 + ((4+3)/2)*0.5 = 4.25
      expect(f.priorKg, closeTo(4.25, 0.001));
      expect(f.priorStrength, 4.0);
      expect(f.hasUserSpec, isFalse);
    });

    test('single panel equals primary; style factors apply', () {
      expect(
        suit(
          traits: const GearBuoyancyTraits(
            panelThicknessesMm: [5],
            suitStyle: 'shorty',
          ),
        ).priorKg,
        closeTo(5 * 0.55, 0.001),
      );
      expect(
        suit(
          traits: const GearBuoyancyTraits(
            primaryThicknessMm: 5,
            suitStyle: 'two_piece',
          ),
        ).priorKg,
        closeTo(5 * 1.35, 0.001),
      );
      expect(
        suit(
          traits: const GearBuoyancyTraits(
            primaryThicknessMm: 5,
            suitStyle: 'semi_dry',
          ),
        ).priorKg,
        closeTo(5.5, 0.001),
      );
    });

    test('wetsuit prior clamps to 10 kg; style without thickness falls back', () {
      expect(
        suit(
          traits: const GearBuoyancyTraits(
            primaryThicknessMm: 9,
            suitStyle: 'two_piece',
          ),
        ).priorKg,
        10.0,
      );
      final styleOnly = suit(
        traits: const GearBuoyancyTraits(suitStyle: 'shorty'),
      );
      expect(styleOnly.priorKg, 4.0);
      expect(styleOnly.priorStrength, 2.0);
    });

    test('drysuit shell material factors', () {
      GearFeature dry(String? material) => GearFeature.fromEquipment(
        id: 'd1',
        type: EquipmentType.drysuit,
        name: 'Dry',
        traits: material == null
            ? null
            : GearBuoyancyTraits(shellMaterial: material),
      );
      expect(dry('neoprene').priorKg, 13.0);
      expect(dry('crushed_neoprene').priorKg, 11.0);
      expect(dry('trilaminate').priorKg, 9.0);
      expect(dry('vulcanized_rubber').priorKg, 9.0);
      expect(dry('neoprene').priorStrength, 4.0);
      expect(dry(null).priorKg, 10.0);
      expect(dry(null).priorStrength, 2.0);
      // Unknown future choice key falls through to the default, weak.
      expect(dry('unobtainium').priorKg, 10.0);
      expect(dry('unobtainium').priorStrength, 2.0);
    });

    test('accessories scale per mm with clamps and glove modifiers', () {
      GearFeature acc(EquipmentType type, {GearBuoyancyTraits? traits}) =>
          GearFeature.fromEquipment(
            id: 'a1',
            type: type,
            name: 'Acc',
            traits: traits,
          );
      expect(
        acc(
          EquipmentType.hood,
          traits: const GearBuoyancyTraits(primaryThicknessMm: 7),
        ).priorKg,
        closeTo(0.7, 0.001),
      );
      expect(
        acc(
          EquipmentType.boots,
          traits: const GearBuoyancyTraits(primaryThicknessMm: 5),
        ).priorKg,
        closeTo(0.6, 0.001),
      );
      expect(
        acc(
          EquipmentType.gloves,
          traits: const GearBuoyancyTraits(
            primaryThicknessMm: 5,
            gloveType: 'mitt',
          ),
        ).priorKg,
        closeTo(0.06 * 5 * 1.15, 0.001),
      );
      expect(
        acc(
          EquipmentType.gloves,
          traits: const GearBuoyancyTraits(
            primaryThicknessMm: 5,
            gloveType: 'dry',
          ),
        ).priorKg,
        closeTo(0.06 * 5 * 0.5, 0.001),
      );
      // No thickness -> old flat defaults, weak.
      final flat = acc(
        EquipmentType.gloves,
        traits: const GearBuoyancyTraits(gloveType: 'mitt'),
      );
      expect(flat.priorKg, 0.2);
      expect(flat.priorStrength, 2.0);
      // Absurd thickness clamps: effective mm capped at 15, prior at 2 kg.
      expect(
        acc(
          EquipmentType.boots,
          traits: const GearBuoyancyTraits(primaryThicknessMm: 400),
        ).priorKg,
        lessThanOrEqualTo(2.0),
      );
    });

    test('bcd style and lift capacity', () {
      GearFeature bcd({GearBuoyancyTraits? traits}) =>
          GearFeature.fromEquipment(
            id: 'b1',
            type: EquipmentType.bcd,
            name: 'BCD',
            traits: traits,
          );
      expect(
        bcd(traits: const GearBuoyancyTraits(bcdStyle: 'jacket')).priorKg,
        closeTo(0.5, 0.001),
      );
      expect(
        bcd(traits: const GearBuoyancyTraits(bcdStyle: 'back_inflate')).priorKg,
        closeTo(0.0, 0.001),
      );
      expect(
        bcd(traits: const GearBuoyancyTraits(bcdStyle: 'wing')).priorKg,
        closeTo(-0.5, 0.001),
      );
      expect(
        bcd(traits: const GearBuoyancyTraits(bcdStyle: 'sidemount')).priorKg,
        closeTo(-0.3, 0.001),
      );
      final wing20 = bcd(
        traits: const GearBuoyancyTraits(bcdStyle: 'wing', liftCapacityKg: 20),
      );
      expect(wing20.priorKg, closeTo(-0.5 + 0.2, 0.001));
      expect(wing20.priorStrength, 4.0);
      // Lift alone still counts as attribute-derived (base = absent -0.5).
      final liftOnly = bcd(
        traits: const GearBuoyancyTraits(liftCapacityKg: 30),
      );
      expect(liftOnly.priorKg, closeTo(-0.5 + 0.3, 0.001));
      expect(liftOnly.priorStrength, 4.0);
      // No attributes -> unchanged default.
      expect(bcd().priorKg, -0.5);
      expect(bcd().priorStrength, 2.0);
    });

    test('explicit buoyancy still wins over traits', () {
      final f = GearFeature.fromEquipment(
        id: 'w1',
        type: EquipmentType.wetsuit,
        name: 'Suit',
        buoyancyKg: 1.25,
        traits: const GearBuoyancyTraits(primaryThicknessMm: 7),
      );
      expect(f.priorKg, 1.25);
      expect(f.priorStrength, 8.0);
      expect(f.hasUserSpec, isTrue);
    });

    test('legacy string parse now carries attribute strength', () {
      final f = GearFeature.fromEquipment(
        id: 'w1',
        type: EquipmentType.wetsuit,
        name: '7mm Farmer John',
      );
      expect(f.priorKg, closeTo(7.0, 0.001));
      expect(f.priorStrength, 4.0);
    });

    test('no attributes reproduces current defaults exactly', () {
      GearFeature bare(EquipmentType type) => GearFeature.fromEquipment(
        id: 'x',
        type: type,
        name: 'Item',
      );
      expect(bare(EquipmentType.wetsuit).priorKg, 4.0);
      expect(bare(EquipmentType.drysuit).priorKg, 10.0);
      expect(bare(EquipmentType.bcd).priorKg, -0.5);
      expect(bare(EquipmentType.hood).priorKg, 0.3);
      expect(bare(EquipmentType.gloves).priorKg, 0.2);
      expect(bare(EquipmentType.boots).priorKg, 0.4);
      expect(bare(EquipmentType.fins).priorKg, 0.0);
      for (final t in [
        EquipmentType.wetsuit,
        EquipmentType.drysuit,
        EquipmentType.bcd,
        EquipmentType.hood,
        EquipmentType.fins,
      ]) {
        expect(bare(t).priorStrength, 2.0, reason: t.name);
      }
    });
  });
```

Also update the two now-outdated pins elsewhere in this file (spec-sanctioned changes):
1. The wetsuit clamp test asserting a cap of 8 kg — change the expectation to 10 kg (e.g. a `'9mm'` name now yields 9.0, and only values above 10 clamp).
2. Any assertion that a string-parsed wetsuit has `priorStrength` 2.0 — change to 4.0. (If no such assertion exists, nothing to do.)

- [ ] **Step 2: Run tests to verify the new group fails**

Run: `flutter test test/core/buoyancy/gear_feature_test.dart`
Expected: FAIL — `traits` named parameter does not exist.

- [ ] **Step 3: Implement the ladder and factors**

In `lib/core/buoyancy/gear_feature.dart`:

1. Add import: `import 'package:submersion/core/buoyancy/gear_buoyancy_traits.dart';`
2. Add constant after `_typeDefaultStrength` (line ~40): `static const double _attributeStrength = 4.0;`
3. Add `GearBuoyancyTraits? traits` to the factory signature and replace the `else` branch of the prior resolution (currently lines 65-69) with the ladder:

```dart
  factory GearFeature.fromEquipment({
    required String id,
    required EquipmentType type,
    required String name,
    String? size,
    String? thickness,
    double? buoyancyKg,
    double? weightKg,
    GearBuoyancyTraits? traits,
  }) {
    if (type == EquipmentType.weights || type == EquipmentType.tank) {
      throw ArgumentError('EquipmentType.${type.name} is not a gear feature');
    }

    final double prior;
    final double strength;
    final bool hasUserSpec;
    if (buoyancyKg != null) {
      prior = buoyancyKg;
      strength = _metadataStrength;
      hasUserSpec = true;
    } else {
      hasUserSpec = false;
      final attributed = _attributePrior(type, traits);
      if (attributed != null) {
        prior = attributed;
        strength = _attributeStrength;
      } else {
        final legacyMm = type == EquipmentType.wetsuit
            ? _legacyWetsuitThicknessMm(name, size, thickness)
            : null;
        if (legacyMm != null) {
          // A thickness parsed from free text carries real information, so
          // it gets the same intermediate trust as attribute-derived priors.
          prior = legacyMm.clamp(0.0, 10.0);
          strength = _attributeStrength;
        } else {
          prior = _typeDefault(type);
          strength = _typeDefaultStrength;
        }
      }
    }

    return GearFeature(
      id: id,
      label: name,
      priorKg: prior,
      priorStrength: strength,
      dryMassKg: weightKg ?? _typeDryMass(type),
      hasUserSpec: hasUserSpec,
    );
  }
```

4. Replace `_typePrior` (lines 81-108) with the factor functions:

```dart
  /// Physics-informed prior from equipment attributes, or null when the
  /// item's attributes say nothing useful for its type. Factor values are
  /// normative from the design spec; unknown choice keys (future catalog
  /// additions) fall through to the absent branch and never throw.
  static double? _attributePrior(EquipmentType type, GearBuoyancyTraits? t) {
    if (t == null) return null;
    final mm = _effectiveThicknessMm(t);
    switch (type) {
      case EquipmentType.wetsuit:
        if (mm == null) return null;
        return (mm * _suitStyleFactor(t.suitStyle)).clamp(0.0, 10.0);
      case EquipmentType.drysuit:
        return switch (t.shellMaterial) {
          'neoprene' => 13.0,
          'crushed_neoprene' => 11.0,
          'trilaminate' => 9.0,
          'vulcanized_rubber' => 9.0,
          _ => null,
        };
      case EquipmentType.hood:
        if (mm == null) return null;
        return (0.10 * mm).clamp(0.0, 2.0);
      case EquipmentType.gloves:
        if (mm == null) return null;
        return (0.06 * mm * _gloveTypeFactor(t.gloveType)).clamp(0.0, 2.0);
      case EquipmentType.boots:
        if (mm == null) return null;
        return (0.12 * mm).clamp(0.0, 2.0);
      case EquipmentType.bcd:
        if (t.bcdStyle == null && t.liftCapacityKg == null) return null;
        final base = switch (t.bcdStyle) {
          'jacket' => 0.5,
          'back_inflate' => 0.0,
          'wing' => -0.5,
          'sidemount' => -0.3,
          _ => -0.5,
        };
        final bladder = 0.01 * (t.liftCapacityKg ?? 0.0);
        return (base + bladder).clamp(-2.0, 2.0);
      default:
        return null;
    }
  }

  /// Area-weighted panel blend: torso (thickest, written first) 0.5 + mean
  /// of the remaining panels 0.5. Single panel is itself. Clamped [0,15] mm.
  static double? _effectiveThicknessMm(GearBuoyancyTraits t) {
    final panels = t.panelThicknessesMm;
    double? mm;
    if (panels.length > 1) {
      final rest = panels.sublist(1);
      final restMean = rest.reduce((a, b) => a + b) / rest.length;
      mm = panels.first * 0.5 + restMean * 0.5;
    } else if (panels.length == 1) {
      mm = panels.first;
    } else {
      mm = t.primaryThicknessMm;
    }
    if (mm == null) return null;
    return mm.clamp(0.0, 15.0);
  }

  static double _suitStyleFactor(String? style) => switch (style) {
    'semi_dry' => 1.1,
    'two_piece' => 1.35,
    'shorty' => 0.55,
    _ => 1.0,
  };

  static double _gloveTypeFactor(String? gloveType) => switch (gloveType) {
    'mitt' => 1.15,
    'dry' => 0.5,
    _ => 1.0,
  };

  static double? _legacyWetsuitThicknessMm(
    String name,
    String? size,
    String? thickness,
  ) =>
      _parseThicknessMm(thickness ?? '', _explicitThicknessPattern) ??
      _parseThicknessMm(size ?? '', _thicknessPattern) ??
      _parseThicknessMm(name, _thicknessPattern);

  static double _typeDefault(EquipmentType type) => switch (type) {
    EquipmentType.wetsuit => 4.0,
    EquipmentType.drysuit => 10.0,
    EquipmentType.bcd => -0.5,
    EquipmentType.hood => 0.3,
    EquipmentType.gloves => 0.2,
    EquipmentType.boots => 0.4,
    _ => 0.0,
  };
```

(`_typeDryMass`, `_parseThicknessMm`, the two regexes, and `props` stay as-is.)

- [ ] **Step 4: Run the buoyancy suite**

Run: `flutter test test/core/buoyancy/`
Expected: ALL PASS (including the updated clamp/strength pins).

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "feat(buoyancy): attribute-derived prior ladder and per-type factor functions"
```

---

### Task 3: Bridge builds traits + EquipmentAttrKeys constants

**Files:**
- Modify: `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart` (`EquipmentAttrKeys`, lines ~27-32, and the five catalog literals)
- Modify: `lib/features/weight_planner/presentation/providers/weight_planner_providers.dart` (`gearFeatureFor`, lines 18-31)
- Test: `test/features/weight_planner/presentation/weight_planner_providers_test.dart` (extend)

**Interfaces:**
- Consumes: `GearBuoyancyTraits`, `GearFeature.fromEquipment(traits:)` (Tasks 1-2); `EquipmentItem.attrText/attrNum`.
- Produces: `EquipmentAttrKeys.suitStyle/shellMaterial/bcdStyle/liftCapacityKg/gloveType` constants; `gearFeatureFor` passing populated traits.

- [ ] **Step 1: Write the failing test**

Append to `test/features/weight_planner/presentation/weight_planner_providers_test.dart` (inside `main()`; the file already imports `EquipmentItem`, `EquipmentAttribute`, `gearFeatureFor`, and `EquipmentType`; add `import 'package:submersion/core/buoyancy/gear_buoyancy_traits.dart';` only if the assertion below needs the type — it does not):

```dart
  test('gearFeatureFor feeds attribute traits into the prior', () {
    final shorty = EquipmentItem(
      id: 's1',
      name: 'Tropic suit',
      type: EquipmentType.wetsuit,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 's1',
          key: 'thickness_mm',
          valueText: '5/4',
          valueNum: 5.0,
        ),
        EquipmentAttribute.curated(
          equipmentId: 's1',
          key: 'suit_style',
          valueText: 'shorty',
        ),
      ],
    );
    final feature = gearFeatureFor(shorty)!;
    // Panels [5,4] -> effective 4.5 mm; shorty factor 0.55.
    expect(feature.priorKg, closeTo(4.5 * 0.55, 0.001));
    expect(feature.priorStrength, 4.0);

    final wing = EquipmentItem(
      id: 'b1',
      name: 'Tech wing',
      type: EquipmentType.bcd,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'b1',
          key: 'bcd_style',
          valueText: 'wing',
        ),
        EquipmentAttribute.curated(
          equipmentId: 'b1',
          key: 'lift_capacity_kg',
          valueNum: 20,
        ),
      ],
    );
    expect(gearFeatureFor(wing)!.priorKg, closeTo(-0.3, 0.001));
  });

  test('numeric thickness is used without text re-parsing', () {
    // valueNum present, valueText absent: prior comes from the number.
    final suit = EquipmentItem(
      id: 's2',
      name: 'Suit',
      type: EquipmentType.wetsuit,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 's2',
          key: 'thickness_mm',
          valueNum: 6.5,
        ),
      ],
    );
    expect(gearFeatureFor(suit)!.priorKg, closeTo(6.5, 0.001));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/weight_planner/presentation/weight_planner_providers_test.dart`
Expected: the new tests FAIL (prior comes out 4.5/5.0-ish without style factor, or strength 2.0/wrong, because traits are not passed yet). The pre-existing tests still pass.

- [ ] **Step 3: Add the key constants**

In `equipment_attribute_catalog.dart`, extend `EquipmentAttrKeys`:

```dart
abstract final class EquipmentAttrKeys {
  static const size = 'size';
  static const thicknessMm = 'thickness_mm';
  static const buoyancyKg = 'buoyancy_kg';
  static const dryWeightKg = 'dry_weight_kg';
  static const suitStyle = 'suit_style';
  static const shellMaterial = 'shell_material';
  static const bcdStyle = 'bcd_style';
  static const liftCapacityKg = 'lift_capacity_kg';
  static const gloveType = 'glove_type';
}
```

Then replace the five corresponding string literals in the `_byType` map (`key: 'suit_style'` → `key: EquipmentAttrKeys.suitStyle`, and likewise for `shell_material`, `bcd_style`, `lift_capacity_kg`, `glove_type`). No behavior change; the catalog test suite must stay green.

- [ ] **Step 4: Build traits in the bridge**

In `weight_planner_providers.dart`, add imports:

```dart
import 'package:submersion/core/buoyancy/gear_buoyancy_traits.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
```

and replace `gearFeatureFor` (lines 18-31):

```dart
GearFeature? gearFeatureFor(EquipmentItem item) {
  if (item.type == EquipmentType.weights || item.type == EquipmentType.tank) {
    return null;
  }
  final thicknessText = item.attrText(EquipmentAttrKeys.thicknessMm);
  return GearFeature.fromEquipment(
    id: item.id,
    type: item.type,
    name: item.name,
    size: item.size,
    thickness: item.thickness,
    buoyancyKg: item.buoyancyKg,
    weightKg: item.weightKg,
    traits: GearBuoyancyTraits(
      primaryThicknessMm: item.attrNum(EquipmentAttrKeys.thicknessMm),
      panelThicknessesMm: thicknessText == null
          ? const []
          : GearBuoyancyTraits.parsePanelsMm(thicknessText),
      suitStyle: item.attrText(EquipmentAttrKeys.suitStyle),
      shellMaterial: item.attrText(EquipmentAttrKeys.shellMaterial),
      bcdStyle: item.attrText(EquipmentAttrKeys.bcdStyle),
      liftCapacityKg: item.attrNum(EquipmentAttrKeys.liftCapacityKg),
      gloveType: item.attrText(EquipmentAttrKeys.gloveType),
    ),
  );
}
```

(The legacy `size`/`thickness` strings stay as fallback inputs; a traits object with all-null fields makes `_attributePrior` return null, dropping to the legacy ladder.)

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/weight_planner/ test/features/equipment/domain/equipment_attribute_catalog_test.dart`
Expected: ALL PASS.

- [ ] **Step 6: Commit**

```bash
dart format .
git add -A
git commit -m "feat(weight-planner): bridge equipment attributes into buoyancy traits"
```

---

### Task 4: Engine-level behavior tests + verification sweep

**Files:**
- Modify: `test/core/buoyancy/weight_prediction_engine_test.dart` (extend)

**Interfaces:**
- Consumes: the full stack from Tasks 1-3. Uses the engine test file's existing helpers (`fit`, `rig`, `obs` — check their exact names/signatures at the top of the file and adapt the calls below to match; the assertions are what matter).

- [ ] **Step 1: Write the behavior tests**

Append to `test/core/buoyancy/weight_prediction_engine_test.dart`, following the file's existing helper style for building gear maps and rigs (adapt helper names to what exists — the file already builds `Map<String, GearFeature> gearById` inputs for `WeightPredictionEngine.fit`):

```dart
  group('attribute-informed priors at the engine level', () {
    GearFeature suitFeature(String id, {String? style}) =>
        GearFeature.fromEquipment(
          id: id,
          type: EquipmentType.wetsuit,
          name: 'Suit $id',
          traits: GearBuoyancyTraits(
            primaryThicknessMm: 5,
            suitStyle: style,
          ),
        );

    test('a shorty predicts less lead than a full suit of equal thickness',
        () {
      // Zero history: prediction = priors + physics, so the gear prior
      // difference flows straight through to the total.
      final gear = {
        'full': suitFeature('full', style: 'full'),
        'shorty': suitFeature('shorty', style: 'shorty'),
      };
      final model = WeightPredictionEngine.fit(
        observations: const [],
        gearById: (id) => gear[id]!,
        bodyWeightKg: 80,
      );
      final fullKg = model
          .predict(RigSpec(gearIds: const ['full'], tanks: const []))
          .totalKg;
      final shortyKg = model
          .predict(RigSpec(gearIds: const ['shorty'], tanks: const []))
          .totalKg;
      expect(fullKg - shortyKg, closeTo(5.0 - 5.0 * 0.55, 0.25));
    });

    test('drysuit shell material shifts an unseen-suit swap', () {
      GearFeature dry(String id, String material) =>
          GearFeature.fromEquipment(
            id: id,
            type: EquipmentType.drysuit,
            name: 'Dry $id',
            traits: GearBuoyancyTraits(shellMaterial: material),
          );
      final gear = {
        'neo': dry('neo', 'neoprene'),
        'trilam': dry('trilam', 'trilaminate'),
      };
      final model = WeightPredictionEngine.fit(
        observations: const [],
        gearById: (id) => gear[id]!,
        bodyWeightKg: 80,
      );
      final neoKg = model
          .predict(RigSpec(gearIds: const ['neo'], tanks: const []))
          .totalKg;
      final trilamKg = model
          .predict(RigSpec(gearIds: const ['trilam'], tanks: const []))
          .totalKg;
      expect(neoKg - trilamKg, closeTo(4.0, 0.5));
    });
  });
```

Check `RigSpec`'s actual constructor (named params and required fields) at the top of `weight_prediction_engine.dart` and match it — if `RigSpec` requires `waterType` or `bodyWeightKg`, pass `waterType: null` / the same 80. Add imports for `GearBuoyancyTraits` if the file lacks them.

- [ ] **Step 2: Run the tests**

Run: `flutter test test/core/buoyancy/weight_prediction_engine_test.dart`
Expected: ALL PASS (these are behavior confirmations of already-implemented code — if one fails, the factor plumbing from Tasks 2-3 has a bug; debug there, do not loosen the assertion beyond the stated tolerances).

- [ ] **Step 3: Verification sweep**

Run each:

```bash
dart format . && flutter analyze
flutter test test/core/buoyancy/
flutter test test/features/weight_planner/
flutter test test/features/equipment/
```

Expected: format changes nothing, "No issues found!", all suites pass.

- [ ] **Step 4: Spec cross-check**

Open the spec and confirm: goals 1-4 all implemented (factors, numeric-first thickness, 4.0 strength tier, regression pin test exists); non-goals untouched (no tank bridge, no TermSource change, no schema/UI diffs — `git diff worktree-equipment-attributes --stat` should show only the 8 files in the File Structure table plus the plan/spec docs).

- [ ] **Step 5: Commit**

```bash
dart format .
git add -A
git commit -m "test(buoyancy): engine-level attribute-prior behavior coverage"
```
