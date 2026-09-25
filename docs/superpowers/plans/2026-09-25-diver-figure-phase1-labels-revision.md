# Diver Figure Phase 1 Revision: Names on the Figure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the numbered discs with names on the figure, so a diver can read what a set holds at a glance, and move the BCD to the back where it is worn.

**Architecture:** Two pure functions place labels (phone columns beside one figure, wide-screen pills beside a pair) from the composed model and a `FigureLayout`. `DiverFigure` becomes stateful, picks the layout by width, and draws labels as widgets over the unchanged painter plus a small leader-line painter. The jacket BCD gains a back piece and every BCD style places in the back-view wing zone.

**Tech Stack:** Flutter 3.47, Dart 3.13, Riverpod, the phase 1 figure code on this branch.

**Spec:** `docs/superpowers/specs/2026-09-25-diver-figure-design.md`, sections 3, 4.1, 4.2 and 8 (revised 2026-09-25). This plan continues branch `ericgriffin/equipment-visual-representation-db57a6` after commit `59d4eb57b88`.

## Global Constraints

- Phone layout below 600 pt of available width, wide layout at 600 pt and above (spec 8.2, 8.3).
- Every label is a number badge then the item's name, one line, ellipsis on overflow; every label's tap target is at least 40 pt tall (spec 8.1).
- Phone: a segmented Front / Back switch with per-side counts, opening on Front; centre anchors go to the side with fewer labels so far, in number order (spec 8.2).
- Wide: pills on the outward side of their anchor, max width a quarter of the pair's width, stepping down to clear overlaps (spec 8.3).
- The list keeps its number badges; label and row numbers always match (spec 8.4).
- Every BCD style places in the back-view `wing` zone; `wing` anchors at (126, 150), `backplate` at (118, 176) (spec 4.1, 4.2).
- Derived colours are tested as outcomes across `AppThemeRegistry.presets` x `Brightness.values`.
- New strings in all eleven locales; no hardcoded digit in an `=1` branch; `@` placeholder metadata in `app_en.arb` for typed parameters.
- The generated artwork file is `lib/features/equipment/figure/artwork/figure_artwork.gen.dart`, rebuilt with `python3 tool/build_figure_artwork.py`.
- No em-dashes. `dart format .` before every commit. Commit messages end with `Part of #2326` and carry no attribution.

## Review Focus

1. **More labels than fit beside the figure.** The column continues below the figure and the widget grows to hold it; nothing overlaps or clips. Test in Task 2 (stacking) and Task 3 (widget height).
2. **A very long item name.** The label truncates inside its column or pill; no overflow error, no label outside the box. Test in Task 3.
3. **The selected item is on the hidden side on a phone.** Tapping its row badge switches the view so its label is visible. Test in Task 3 and Task 4.
4. **Width exactly 600 versus 599.** 600 is wide, 599 is phone. Test in Task 3.
5. **A side with no items.** The switch reads "Back · 0", the back still draws the mannequin, no exception. Test in Task 3.

---

## File Structure

New:

```
lib/features/equipment/figure/presentation/figure_labels.dart          FigureLabelSlot, labelColumns, labelPills
lib/features/equipment/figure/presentation/figure_leader_painter.dart  leader lines and anchor dots
lib/features/equipment/figure/presentation/figure_name_label.dart      badge plus name, pill or plain
tool/figure/bcd_jacket_back.svg
test/features/equipment/figure/presentation/figure_labels_test.dart
```

Modified:

```
tool/figure/bcd_jacket_front.svg, tool/figure/manifest.json, figure_artwork.gen.dart
lib/features/equipment/figure/domain/figure_zone.dart          wing and backplate anchors
lib/features/equipment/figure/domain/figure_placement.dart     BCD in the wing zone, jacket back piece
lib/features/equipment/figure/presentation/figure_layout.dart  forSingle
lib/features/equipment/figure/presentation/diver_figure_painter.dart  layout and only
lib/features/equipment/figure/presentation/diver_figure.dart   stateful, phone and wide layouts
lib/features/equipment/presentation/pages/equipment_set_detail_page.dart
lib/l10n/arb/app_*.arb and generated app_localizations*.dart
tests: figure_placement_test, figure_composer_test, diver_figure_painter_test, diver_figure_test, equipment_set_detail_figure_test
```

---

### Task 1: The BCD on the back

**Files:**
- Modify: `tool/figure/bcd_jacket_front.svg`, `tool/figure/manifest.json`
- Create: `tool/figure/bcd_jacket_back.svg`
- Modify: `lib/features/equipment/figure/domain/figure_zone.dart`, `lib/features/equipment/figure/domain/figure_placement.dart`
- Modify (generated): `lib/features/equipment/figure/artwork/figure_artwork.gen.dart`
- Test: `test/features/equipment/figure/domain/figure_placement_test.dart`, `test/features/equipment/figure/domain/figure_composer_test.dart`, `test/features/equipment/figure/presentation/diver_figure_painter_test.dart`

**Interfaces:**
- Produces: piece `bcd_jacket_back` (back view, layer 55, below the tank's 60); `FigurePlacement.forType(EquipmentType.bcd)` returns `zones: [FigureZone.wing]` with pieces keyed by `FigureZone.wing`; `FigureZone.wing` anchor (126, 150), `FigureZone.backplate` anchor (118, 176).

- [ ] **Step 1: Change the tests to the new placement**

In `figure_placement_test.dart`, replace the body of `'a BCD style picks its pieces'` with:

```dart
    expect(FigurePlacement.forType(EquipmentType.bcd).zones, [FigureZone.wing]);
    expect(
      FigurePlacement.forType(EquipmentType.bcd).piecesFor(FigureZone.wing),
      ['bcd_jacket_front', 'bcd_jacket_back'],
    );
    expect(
      FigurePlacement.forType(
        EquipmentType.bcd,
        attributes: {EquipmentAttrKeys.bcdStyle: 'wing'},
      ).piecesFor(FigureZone.wing),
      ['bcd_harness_front', 'bcd_wing_back'],
    );
    expect(
      FigurePlacement.forType(
        EquipmentType.bcd,
        attributes: {EquipmentAttrKeys.bcdStyle: 'sidemount'},
      ).piecesFor(FigureZone.wing),
      ['bcd_sidemount_front', 'bcd_sidemount_back'],
    );
    // A separate harness item is still worn and labelled on the front.
    expect(
      FigurePlacement.forType(EquipmentType.harness).zones,
      [FigureZone.torsoFront],
    );
```

and in `'an unknown attribute value falls back to the default variant'` change `spec.piecesFor(FigureZone.torsoFront)` to `spec.piecesFor(FigureZone.wing)` with the expected `['bcd_jacket_front', 'bcd_jacket_back']`.

In `figure_composer_test.dart`, in `'a second BCD goes to the tray but still makes the rig sidemount'`, change `FigureZone.torsoFront` to `FigureZone.wing`, and add after the sidemount test:

```dart
  test('a BCD and a separate wing compete for the one back zone', () {
    final model = composeFigure([
      item('bcd', EquipmentType.bcd),
      item('wing', EquipmentType.wing),
    ]);
    expect(model.byId('bcd')!.zone, FigureZone.wing);
    expect(model.byId('wing')!.zone, isNull);
  });
```

In `diver_figure_painter_test.dart`, replace the test `'layers paint low to high so a BCD covers the wetsuit'` with:

```dart
  testWidgets('a jacket BCD shows straps in front and its bladder behind the tank', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final pixel = await paint(
        composeFigure([
          item('bcd', EquipmentType.bcd),
          item('suit', EquipmentType.wetsuit),
          item('tank', EquipmentType.tank),
        ]),
      );
      // Front: the left shoulder strap covers the suit...
      expect(pixel(layout.toBox(FigureView.front, 83, 120)), FigureColors.black);
      // ...but the chest between the straps shows the suit, not a jacket.
      expect(pixel(layout.toBox(FigureView.front, 92, 130)), FigureColors.darkBlue);
      // Back: the bladder shows beside the tank, and the tank is drawn over it.
      expect(pixel(layout.toBox(FigureView.back, 122, 150)), FigureColors.black);
      expect(pixel(layout.toBox(FigureView.back, 104, 150)), FigureColors.aluminium);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/figure/domain/figure_placement_test.dart test/features/equipment/figure/domain/figure_composer_test.dart test/features/equipment/figure/presentation/diver_figure_painter_test.dart`
Expected: FAIL on the BCD zone and piece assertions, the BCD-and-wing test, and the painter sample at front (92, 130) (the old jacket fills the chest).

- [ ] **Step 3: Redraw the jacket front and add its back**

Replace `tool/figure/bcd_jacket_front.svg` with:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 400">
  <rect x="78" y="76" width="10" height="94" rx="4"/>
  <rect x="112" y="76" width="10" height="94" rx="4"/>
  <rect x="86" y="104" width="28" height="6" rx="2"/>
  <rect x="70" y="150" width="60" height="16" rx="4"/>
  <rect x="72" y="84" width="6" height="56" rx="3"/>
  <rect x="94" y="154" width="12" height="8" rx="1"/>
</svg>
```

Create `tool/figure/bcd_jacket_back.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 400">
  <path d="M74 80 C62 104 62 160 74 188 L126 188 C138 160 138 104 126 80 Z"/>
  <rect x="97" y="86" width="6" height="96" rx="3"/>
  <rect x="78" y="76" width="10" height="12" rx="4"/>
  <rect x="112" y="76" width="10" height="12" rx="4"/>
</svg>
```

In `tool/figure/manifest.json`, set the `bcd_jacket_front` roles to `["itemColor", "itemColor", "itemShade", "itemColor", "gearDark", "metal"]` (strap, strap, chest strap, cummerbund, inflator, buckle) and add:

```json
{"id": "bcd_jacket_back", "view": "back", "layer": 55,
 "roles": ["itemColor", "itemShade", "itemShade", "itemShade"]}
```

- [ ] **Step 4: Move the BCD and the back anchors**

In `figure_zone.dart`:

```dart
  wing(FigureView.back, 126, 150),
  backplate(FigureView.back, 118, 176),
```

and add to the enum's doc comment: "Back-view anchors sit where their gear shows beside the tank, which covers the centre line from the shoulders to the waist."

In `figure_placement.dart`, the `EquipmentType.bcd` case becomes:

```dart
      case EquipmentType.bcd:
        // Worn on the back (the straps show in front), so every style is
        // labelled on the back view and shares the wing's zone: a rig has a
        // BCD or a wing, and a second one goes to the tray.
        final pieces = switch (attributes[EquipmentAttrKeys.bcdStyle]) {
          'back_inflate' ||
          'wing' => const ['bcd_harness_front', 'bcd_wing_back'],
          'sidemount' => const ['bcd_sidemount_front', 'bcd_sidemount_back'],
          _ => const ['bcd_jacket_front', 'bcd_jacket_back'],
        };
        return FigurePlacementSpec(
          zones: const [FigureZone.wing],
          piecesByZone: {FigureZone.wing: pieces},
          defaultColor: FigureColors.black,
        );
```

- [ ] **Step 5: Regenerate and run the tests**

Run: `python3 tool/build_figure_artwork.py && python3 tool/build_figure_artwork.py --verify && flutter test test/features/equipment/figure`
Expected: `wrote ... (60 pieces)`, `OK 60 pieces current`, all tests PASS including the artwork completeness tests (the new piece is reachable from the table).

- [ ] **Step 6: Commit**

```bash
dart format lib/features/equipment/figure test/features/equipment/figure
git add tool/figure lib/features/equipment/figure test/features/equipment/figure
git commit -m "feat(figure): the BCD is worn on the back

A jacket BCD now shows its straps, cummerbund and inflator in front and its
bladder behind the tank, and every BCD style is labelled on the back view.
Back-view anchors move to where the gear shows beside the tank.

Part of #2326"
```

---

### Task 2: Label layout functions and the single-figure layout

**Files:**
- Modify: `lib/features/equipment/figure/presentation/figure_layout.dart`
- Create: `lib/features/equipment/figure/presentation/figure_labels.dart`
- Test: `test/features/equipment/figure/presentation/figure_layout_test.dart`, `test/features/equipment/figure/presentation/figure_labels_test.dart`

**Interfaces:**
- Consumes: `FigureModel`, `PlacedItem`, `composeFigure` (phase 1); `FigureLayout.forSize`, `toBox`, `rectFor`.
- Produces: `FigureLayout.forSingle(Size size, {double fraction = 0.45})`; `const double kFigureLabelHeight = 40`, `kFigureLabelGap = 2`, `kFigureLeaderGap = 8`; `class FigureLabelSlot({item, rect, anchor, onLeft})`; `List<FigureLabelSlot> labelColumns({required FigureModel model, required FigureView view, required FigureLayout layout, required double width})`; `List<FigureLabelSlot> labelPills({required FigureModel model, required FigureLayout layout, required double width, required double maxWidth, required double Function(PlacedItem item) widthOf})`.

- [ ] **Step 1: Write the failing tests**

Append to `figure_layout_test.dart`:

```dart
  test('forSingle centres one figure at a fraction of the width', () {
    final layout = FigureLayout.forSingle(const Size(360, 420));
    expect(layout.front.width, closeTo(162, 0.01));
    expect(layout.front.left, closeTo(99, 0.01));
    expect(layout.front.top, 0);
    expect(layout.back, layout.front);
    expect(layout.scale, closeTo(162 / 200, 0.0001));
  });

  test('forSingle is capped by the box height and stays positive', () {
    expect(FigureLayout.forSingle(const Size(1000, 300)).front.height, 300);
    expect(FigureLayout.forSingle(Size.zero).front.width, greaterThan(0));
  });
```

Create `figure_labels_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_labels.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';

/// Labels are what make the figure readable at a glance, so where they go
/// is pinned here without widgets: which side, never overlapping, level with
/// their gear when there is room, and inside the box.
void main() {
  FigureItemInput item(String id, EquipmentType type) =>
      FigureItemInput(id: id, type: type, name: id);

  void expectNoOverlaps(List<FigureLabelSlot> slots) {
    for (var i = 0; i < slots.length; i++) {
      for (var j = i + 1; j < slots.length; j++) {
        expect(
          slots[i].rect.overlaps(slots[j].rect),
          isFalse,
          reason: '${slots[i].item.item.id} overlaps ${slots[j].item.item.id}',
        );
      }
    }
  }

  group('labelColumns', () {
    final layout = FigureLayout.forSingle(const Size(360, 420));
    final figure = layout.front;

    test('sides follow the anchor, centre anchors balance in number order', () {
      final model = composeFigure([
        item('mask', EquipmentType.mask), // face, centre
        item('reg', EquipmentType.regulator), // mouth, centre
        item('computer', EquipmentType.computer), // left wrist
        item('light', EquipmentType.light), // left hand
        item('fins', EquipmentType.fins), // centre
      ]);
      final slots = labelColumns(
        model: model,
        view: FigureView.front,
        layout: layout,
        width: 360,
      );
      final side = {for (final s in slots) s.item.item.id: s.onLeft};
      expect(side, {
        'mask': true,
        'reg': false,
        'computer': true,
        'light': true,
        'fins': false,
      });
      for (final s in slots) {
        if (s.onLeft) {
          expect(s.rect.right, lessThanOrEqualTo(figure.left));
        } else {
          expect(s.rect.left, greaterThanOrEqualTo(figure.right));
        }
      }
    });

    test('only the chosen view is labelled', () {
      final model = composeFigure([
        item('mask', EquipmentType.mask),
        item('tank', EquipmentType.tank),
      ]);
      final back = labelColumns(
        model: model,
        view: FigureView.back,
        layout: layout,
        width: 360,
      );
      expect(back.map((s) => s.item.item.id), ['tank']);
    });

    test('a lone label sits level with its anchor', () {
      final model = composeFigure([item('computer', EquipmentType.computer)]);
      final slot = labelColumns(
        model: model,
        view: FigureView.front,
        layout: layout,
        width: 360,
      ).single;
      expect(slot.rect.center.dy, closeTo(slot.anchor.dy, 0.001));
    });

    test('a crowded column stacks without overlap and never rises above its anchor', () {
      final model = composeFigure([
        item('mask', EquipmentType.mask),
        item('reg', EquipmentType.regulator),
        item('snorkel', EquipmentType.snorkel),
        item('octo', EquipmentType.secondStage),
        item('computer', EquipmentType.computer),
        item('compass', EquipmentType.compass),
        item('light', EquipmentType.light),
        item('camera', EquipmentType.camera),
        item('weights', EquipmentType.weights),
        item('knife', EquipmentType.knife),
        item('fins', EquipmentType.fins),
      ]);
      final slots = labelColumns(
        model: model,
        view: FigureView.front,
        layout: layout,
        width: 360,
      );
      expect(slots.length, model.placed.length);
      expectNoOverlaps(slots);
      for (final s in slots) {
        expect(
          s.rect.top,
          greaterThanOrEqualTo(s.anchor.dy - kFigureLabelHeight / 2 - 0.001),
        );
        expect(s.rect.height, kFigureLabelHeight);
      }
    });
  });

  group('labelPills', () {
    final layout = FigureLayout.forSize(const Size(900, 360));

    List<FigureLabelSlot> pills(FigureModel model, {double natural = 120}) =>
        labelPills(
          model: model,
          layout: layout,
          width: 900,
          maxWidth: 900 / 4,
          widthOf: (_) => natural,
        );

    test('a pill sits on the outward side of its anchor', () {
      final model = composeFigure([
        item('computer', EquipmentType.computer), // left of centre
        item('tank', EquipmentType.tank), // back, centre
      ]);
      final byId = {for (final s in pills(model)) s.item.item.id: s};
      expect(byId['computer']!.onLeft, isTrue);
      expect(byId['computer']!.rect.right, lessThanOrEqualTo(byId['computer']!.anchor.dx));
      expect(byId['tank']!.onLeft, isFalse);
      expect(byId['tank']!.rect.left, greaterThanOrEqualTo(byId['tank']!.anchor.dx));
    });

    test('pills are capped at a quarter of the width and stay in the box', () {
      final model = composeFigure([
        item('computer', EquipmentType.computer),
        item('light', EquipmentType.light),
        item('reel', EquipmentType.reel),
      ]);
      for (final s in pills(model, natural: 5000)) {
        expect(s.rect.width, lessThanOrEqualTo(900 / 4 + 0.001));
        expect(s.rect.left, greaterThanOrEqualTo(0));
        expect(s.rect.right, lessThanOrEqualTo(900.001));
      }
    });

    test('crowded pills step down until none overlap', () {
      final model = composeFigure([
        item('mask', EquipmentType.mask),
        item('reg', EquipmentType.regulator),
        item('octo', EquipmentType.secondStage),
        item('bcd', EquipmentType.bcd),
        item('computer', EquipmentType.computer),
        item('compass', EquipmentType.compass),
        item('light', EquipmentType.light),
        item('weights', EquipmentType.weights),
        item('reel', EquipmentType.reel),
        item('fins', EquipmentType.fins),
        item('tank', EquipmentType.tank),
        item('smb', EquipmentType.smb),
      ]);
      final slots = pills(model);
      expect(slots.length, model.placed.length);
      expectNoOverlaps(slots);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/figure/presentation/figure_layout_test.dart test/features/equipment/figure/presentation/figure_labels_test.dart`
Expected: FAIL, `forSingle` and `figure_labels.dart` do not exist.

- [ ] **Step 3: Add forSingle**

In `FigureLayout`, after `forSize`:

```dart
  /// One figure centred in [size] at [fraction] of its width (and the
  /// matching 1:2 height, capped by the box height), top-aligned so label
  /// columns can run below it. Both [front] and [back] are that rectangle,
  /// since the phone layout shows one view at a time.
  static FigureLayout forSingle(Size size, {double fraction = 0.45}) {
    final figureWidth = math.max(
      1.0,
      math.min(size.width * fraction, size.height / 2),
    );
    final rect = Rect.fromLTWH(
      (size.width - figureWidth) / 2,
      0,
      figureWidth,
      figureWidth * 2,
    );
    return FigureLayout(front: rect, back: rect, scale: figureWidth / kFigureWidth);
  }
```

- [ ] **Step 4: Write the label layout**

```dart
// lib/features/equipment/figure/presentation/figure_labels.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_space.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';

/// A label's height, which is also its tap target.
const double kFigureLabelHeight = 40;

/// Vertical space between stacked labels.
const double kFigureLabelGap = 2;

/// Space between a label and the figure or anchor it points at.
const double kFigureLeaderGap = 8;

/// Where one item's label sits, and the anchor its leader line points at.
class FigureLabelSlot {
  const FigureLabelSlot({
    required this.item,
    required this.rect,
    required this.anchor,
    required this.onLeft,
  });

  final PlacedItem item;
  final Rect rect;
  final Offset anchor;

  /// Whether the label sits left of its anchor, so its leader leaves the
  /// label's right edge.
  final bool onLeft;
}

bool _onCentre(PlacedItem p) =>
    (p.zone!.anchorX - kFigureWidth / 2).abs() <= 0.5;

bool _leftOfCentre(PlacedItem p) => p.zone!.anchorX < kFigureWidth / 2 - 0.5;

int _byNumber(PlacedItem a, PlacedItem b) => a.number.compareTo(b.number);

/// Phone layout (spec 8.2): labels for one [view] in columns either side of
/// the single figure, each level with its anchor unless that would overlap
/// the label above, in which case it moves down just enough.
List<FigureLabelSlot> labelColumns({
  required FigureModel model,
  required FigureView view,
  required FigureLayout layout,
  required double width,
}) {
  final figure = layout.rectFor(view);
  final items = [
    for (final p in model.placed)
      if (p.zone!.view == view) p,
  ]..sort(_byNumber);
  final left = <PlacedItem>[];
  final right = <PlacedItem>[];
  for (final p in items) {
    if (_onCentre(p)) {
      (left.length <= right.length ? left : right).add(p);
    } else if (_leftOfCentre(p)) {
      left.add(p);
    } else {
      right.add(p);
    }
  }
  final rightX = figure.right + kFigureLeaderGap;
  return [
    ..._stack(
      left,
      view,
      layout,
      x: 0,
      columnWidth: math.max(0, figure.left - kFigureLeaderGap),
      onLeft: true,
    ),
    ..._stack(
      right,
      view,
      layout,
      x: rightX,
      columnWidth: math.max(0, width - rightX),
      onLeft: false,
    ),
  ];
}

List<FigureLabelSlot> _stack(
  List<PlacedItem> column,
  FigureView view,
  FigureLayout layout, {
  required double x,
  required double columnWidth,
  required bool onLeft,
}) {
  final anchored = [
    for (final p in column)
      (item: p, anchor: layout.toBox(view, p.zone!.anchorX, p.zone!.anchorY)),
  ]..sort((a, b) {
      final byHeight = a.anchor.dy.compareTo(b.anchor.dy);
      return byHeight != 0 ? byHeight : _byNumber(a.item, b.item);
    });
  final slots = <FigureLabelSlot>[];
  var nextTop = 0.0;
  for (final entry in anchored) {
    final top = math.max(nextTop, entry.anchor.dy - kFigureLabelHeight / 2);
    slots.add(
      FigureLabelSlot(
        item: entry.item,
        rect: Rect.fromLTWH(x, top, columnWidth, kFigureLabelHeight),
        anchor: entry.anchor,
        onLeft: onLeft,
      ),
    );
    nextTop = top + kFigureLabelHeight + kFigureLabelGap;
  }
  return slots;
}

/// Wide layout (spec 8.3): a pill beside every placed item on the outward
/// side of its anchor, placed in number order and stepped down until it
/// clears the pills already placed. [widthOf] is the pill's natural width;
/// it is capped at [maxWidth] and at the room between the anchor and the
/// edge of the box.
List<FigureLabelSlot> labelPills({
  required FigureModel model,
  required FigureLayout layout,
  required double width,
  required double maxWidth,
  required double Function(PlacedItem item) widthOf,
}) {
  final items = [...model.placed]..sort(_byNumber);
  final taken = <Rect>[];
  final slots = <FigureLabelSlot>[];
  for (final p in items) {
    final zone = p.zone!;
    final anchor = layout.toBox(zone.view, zone.anchorX, zone.anchorY);
    final onLeft = _leftOfCentre(p);
    final room = onLeft
        ? anchor.dx - kFigureLeaderGap
        : width - anchor.dx - kFigureLeaderGap;
    final w = math.max(0.0, math.min(math.min(widthOf(p), maxWidth), room));
    final x = onLeft
        ? anchor.dx - kFigureLeaderGap - w
        : anchor.dx + kFigureLeaderGap;
    var rect = Rect.fromLTWH(
      x,
      math.max(0, anchor.dy - kFigureLabelHeight / 2),
      w,
      kFigureLabelHeight,
    );
    while (taken.any((t) => t.overlaps(rect))) {
      rect = rect.shift(const Offset(0, kFigureLabelHeight + kFigureLabelGap));
    }
    taken.add(rect);
    slots.add(
      FigureLabelSlot(item: p, rect: rect, anchor: anchor, onLeft: onLeft),
    );
  }
  return slots;
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/figure/presentation/figure_layout_test.dart test/features/equipment/figure/presentation/figure_labels_test.dart`
Expected: PASS. If the side-assignment test fails on `fins`, check the balance rule: after mask (left), reg (right), computer and light (left), the left column has three and the right one, so fins goes right.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/equipment/figure test/features/equipment/figure
git add lib/features/equipment/figure/presentation test/features/equipment/figure/presentation
git commit -m "feat(figure): label layout for phone columns and wide pills

Part of #2326"
```

---

### Task 3: Names on the figure in DiverFigure

**Files:**
- Modify: `lib/features/equipment/figure/presentation/diver_figure_painter.dart`
- Create: `lib/features/equipment/figure/presentation/figure_leader_painter.dart`
- Create: `lib/features/equipment/figure/presentation/figure_name_label.dart`
- Modify (rewrite): `lib/features/equipment/figure/presentation/diver_figure.dart`
- Test: `test/features/equipment/figure/presentation/diver_figure_painter_test.dart`, `test/features/equipment/figure/presentation/diver_figure_test.dart` (rewrite)

**Interfaces:**
- Consumes: `labelColumns`, `labelPills`, `FigureLabelSlot`, `kFigureLabelHeight`, `FigureLayout.forSingle` (Task 2); `figureHighlightFor`, `FigureNumberBadge` (phase 1).
- Produces: `DiverFigurePainter({required model, required palette, FigureLayout? layout, FigureView? only})`; `FigureLeaderPainter({required List<FigureLabelSlot> slots, required Color color})`; `FigureNameLabel({number, text, alignEnd, pill, selected, onTap, semanticsLabel})` with `static double preferredWidth(String, TextStyle, TextDirection)` and `static TextStyle styleOf(BuildContext)`; `DiverFigure({required model, required semanticsLabel, required String Function(PlacedItem) labelText, required String Function(FigureView, int) sideLabel, mode, selectedItemId, onItemTap, String Function(PlacedItem)? itemSemantics, trayTitle})` with `static const wideBreakpoint = 600`; label keys `ValueKey('figure-label-<itemId>')`. `discPositions`, `DiverFigure.discSize` and `discLabel` are removed.

- [ ] **Step 1: Write the failing painter test**

Append to `diver_figure_painter_test.dart`:

```dart
  testWidgets('with only one view, the painter draws that view in the single layout', (
    tester,
  ) async {
    await tester.runAsync(() async {
      const box = Size(400, 400);
      final single = FigureLayout.forSingle(box);
      Future<int> sample(FigureView only) async {
        final recorder = PictureRecorder();
        DiverFigurePainter(
          model: composeFigure(const []),
          palette: FigurePalette.light,
          layout: single,
          only: only,
        ).paint(Canvas(recorder), box);
        final image = await recorder.endRecording().toImage(400, 400);
        final bytes = (await image.toByteData())!;
        final p = single.toBox(only, 100, 140);
        final i = (p.dy.round() * 400 + p.dx.round()) * 4;
        return (bytes.getUint8(i + 3) << 24) |
            (bytes.getUint8(i) << 16) |
            (bytes.getUint8(i + 1) << 8) |
            bytes.getUint8(i + 2);
      }

      // The centre of the torso is plain body in front and the spine shade
      // behind, so the two samples tell the views apart.
      expect(await sample(FigureView.front), FigurePalette.light.body);
      expect(await sample(FigureView.back), FigurePalette.light.bodyShade);
    });
  });
```

- [ ] **Step 2: Rewrite the widget test**

Replace `test/features/equipment/figure/presentation/diver_figure_test.dart` with:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_name_label.dart';

void main() {
  FigureItemInput item(String id, EquipmentType type) =>
      FigureItemInput(id: id, type: type, name: 'Item $id');

  final reef = composeFigure([
    item('mask', EquipmentType.mask),
    item('bcd', EquipmentType.bcd),
    item('fins', EquipmentType.fins),
    item('tank', EquipmentType.tank),
  ]);

  Future<void> pump(
    WidgetTester tester,
    FigureModel model, {
    required double width,
    String? selectedItemId,
    ValueChanged<PlacedItem>? onItemTap,
    String Function(PlacedItem)? labelText,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DiverFigure(
              model: model,
              semanticsLabel: 'Reef set',
              labelText: labelText ?? (p) => p.item.name,
              sideLabel: (view, count) =>
                  '${view == FigureView.front ? 'Front' : 'Back'} · $count',
              itemSemantics: (p) =>
                  '${p.number}, ${p.item.type.name}, ${p.item.name}',
              selectedItemId: selectedItemId,
              onItemTap: onItemTap,
              trayTitle: 'Also carried',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder label(String id) => find.byKey(ValueKey('figure-label-$id'));

  group('phone', () {
    testWidgets('a switch with counts shows one side at a time', (tester) async {
      await pump(tester, reef, width: 360);
      expect(find.text('Front · 2'), findsOneWidget);
      expect(find.text('Back · 2'), findsOneWidget);
      expect(label('mask'), findsOneWidget);
      expect(label('tank'), findsNothing);
      await tester.tap(find.text('Back · 2'));
      await tester.pump();
      expect(label('tank'), findsOneWidget);
      expect(label('bcd'), findsOneWidget);
      expect(label('mask'), findsNothing);
    });

    testWidgets('selecting an item on the hidden side switches to it', (
      tester,
    ) async {
      await pump(tester, reef, width: 360);
      expect(label('bcd'), findsNothing);
      await pump(tester, reef, width: 360, selectedItemId: 'bcd');
      expect(label('bcd'), findsOneWidget);
    });

    testWidgets('an empty side reads zero and still draws', (tester) async {
      final frontOnly = composeFigure([item('mask', EquipmentType.mask)]);
      await pump(tester, frontOnly, width: 360);
      expect(find.text('Back · 0'), findsOneWidget);
      await tester.tap(find.text('Back · 0'));
      await tester.pump();
      expect(find.byType(FigureNameLabel), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('599 is the phone layout and 600 the wide one', (tester) async {
      await pump(tester, reef, width: 599);
      expect(find.byType(SegmentedButton<FigureView>), findsOneWidget);
      await pump(tester, reef, width: 600);
      expect(find.byType(SegmentedButton<FigureView>), findsNothing);
    });
  });

  group('wide', () {
    testWidgets('every placed item has a named pill with its number', (
      tester,
    ) async {
      await pump(tester, reef, width: 900);
      expect(find.byType(FigureNameLabel), findsNWidgets(4));
      expect(find.text('Item bcd'), findsOneWidget);
      expect(find.bySemanticsLabel('2, bcd, Item bcd'), findsOneWidget);
      expect(find.bySemanticsLabel('Reef set'), findsOneWidget);
    });

    testWidgets('tapping a label reports its item', (tester) async {
      PlacedItem? tapped;
      await pump(tester, reef, width: 900, onItemTap: (p) => tapped = p);
      await tester.tap(label('fins'));
      expect(tapped?.item.id, 'fins');
    });

    testWidgets('the selected label is marked selected', (tester) async {
      await pump(tester, reef, width: 900, selectedItemId: 'mask');
      final selected = tester
          .widgetList<FigureNameLabel>(find.byType(FigureNameLabel))
          .where((l) => l.selected);
      expect(selected.single.number, 1);
    });

    testWidgets('a very long name truncates inside the box', (tester) async {
      await pump(
        tester,
        reef,
        width: 900,
        labelText: (p) => 'An extraordinarily long item name that keeps going ${p.number}',
      );
      expect(tester.takeException(), isNull);
      for (final element in find.byType(FigureNameLabel).evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(900.001));
      }
    });
  });

  testWidgets('labels keep a 40 point target on both platforms', (tester) async {
    try {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        for (final width in [360.0, 900.0]) {
          await pump(tester, reef, width: width, onItemTap: (_) {});
          expect(
            tester.getSize(label('mask')).height,
            greaterThanOrEqualTo(40),
            reason: '${platform.name} at $width',
          );
        }
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('tray tiles show the name as well as the number', (tester) async {
    final withTray = composeFigure([
      item('mask', EquipmentType.mask),
      item('tool', EquipmentType.tool),
    ]);
    await pump(tester, withTray, width: 900);
    expect(find.text('Also carried'), findsOneWidget);
    expect(find.text('Item tool'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/figure/presentation/diver_figure_painter_test.dart test/features/equipment/figure/presentation/diver_figure_test.dart`
Expected: FAIL to compile: `layout` and `only` are not painter parameters, and `figure_name_label.dart` does not exist.

- [ ] **Step 4: Give the painter a layout and a single view**

In `DiverFigurePainter`, replace the constructor, fields and `paint`:

```dart
  DiverFigurePainter({
    required this.model,
    required this.palette,
    this.layout,
    this.only,
  });

  final FigureModel model;
  final FigurePalette palette;

  /// The layout to draw in; defaults to the pair, or the single figure when
  /// [only] is set. The widget passes its own so labels and art agree.
  final FigureLayout? layout;

  /// Draw just this view (the phone layout).
  final FigureView? only;

  @override
  void paint(Canvas canvas, Size size) {
    final l =
        layout ??
        (only == null
            ? FigureLayout.forSize(size)
            : FigureLayout.forSingle(size));
    for (final view in FigureView.values) {
      if (only != null && view != only) continue;
      final rect = l.rectFor(view);
      canvas.save();
      canvas.translate(rect.left, rect.top);
      canvas.scale(l.scale);
      _paintView(canvas, view);
      canvas.restore();
    }
  }
```

and `shouldRepaint` also compares `layout` and `only`:

```dart
  @override
  bool shouldRepaint(DiverFigurePainter oldDelegate) =>
      !identical(oldDelegate.model, model) ||
      !identical(oldDelegate.palette, palette) ||
      oldDelegate.only != only ||
      oldDelegate.layout?.front != layout?.front;
```

- [ ] **Step 5: Write the leader painter and the name label**

```dart
// lib/features/equipment/figure/presentation/figure_leader_painter.dart
import 'package:flutter/rendering.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_labels.dart';

/// A thin line from each label to its gear, ending in a small dot.
class FigureLeaderPainter extends CustomPainter {
  FigureLeaderPainter({required this.slots, required this.color});

  final List<FigureLabelSlot> slots;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = color;
    for (final slot in slots) {
      final from = slot.onLeft ? slot.rect.centerRight : slot.rect.centerLeft;
      canvas.drawLine(from, slot.anchor, line);
      canvas.drawCircle(slot.anchor, 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(FigureLeaderPainter oldDelegate) =>
      !identical(oldDelegate.slots, slots) || oldDelegate.color != color;
}
```

```dart
// lib/features/equipment/figure/presentation/figure_name_label.dart
import 'package:flutter/material.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';

/// A number badge and an item's name, one line, the whole slot tappable.
///
/// [pill] draws a rounded background (the wide layout); without it the
/// label is plain text in a column (the phone layout). [alignEnd] pushes the
/// content to the right edge, for labels left of their gear.
class FigureNameLabel extends StatelessWidget {
  const FigureNameLabel({
    super.key,
    required this.number,
    required this.text,
    this.alignEnd = false,
    this.pill = false,
    this.selected = false,
    this.onTap,
    this.semanticsLabel,
  });

  static const double badgeSize = 18;
  static const double _gap = 6;
  static const double _padding = 8;

  final int number;
  final String text;
  final bool alignEnd;
  final bool pill;
  final bool selected;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  static TextStyle styleOf(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall ?? const TextStyle(fontSize: 12);

  /// The width the label needs to show [text] in full.
  static double preferredWidth(
    String text,
    TextStyle style,
    TextDirection direction,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      maxLines: 1,
    )..layout();
    final width = badgeSize + _gap + painter.width + _padding * 2 + 2;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight = selected ? figureHighlightFor(scheme) : null;
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: _padding, vertical: 3),
      decoration: pill || selected
          ? BoxDecoration(
              color: highlight?.fill ?? scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant, width: 0.5),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FigureNumberBadge(number: number, size: badgeSize, selected: selected),
          const SizedBox(width: _gap),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: styleOf(context).copyWith(color: highlight?.onFill),
            ),
          ),
        ],
      ),
    );
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      selected: selected,
      excludeSemantics: semanticsLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: content,
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Rewrite DiverFigure**

Replace `lib/features/equipment/figure/presentation/diver_figure.dart` with:

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure_painter.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_labels.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_leader_painter.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_name_label.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';

/// How the figure is shown. Phase 1 ships the pair; later phases add a
/// thumbnail and a locate mode.
enum FigureMode { pair }

/// The diver figure with every placed item named on it (spec section 8).
///
/// Below [wideBreakpoint] one side shows at a time behind a Front / Back
/// switch, with label columns either side; from it upward the front and
/// back sit side by side with a name pill beside each item. Items with no
/// place on the body are tiles in a tray beneath.
class DiverFigure extends StatefulWidget {
  const DiverFigure({
    super.key,
    required this.model,
    required this.semanticsLabel,
    required this.labelText,
    required this.sideLabel,
    this.mode = FigureMode.pair,
    this.selectedItemId,
    this.onItemTap,
    this.itemSemantics,
    this.trayTitle,
  });

  static const double wideBreakpoint = 600;

  /// The tallest single figure on a phone.
  static const double phoneMaxFigureHeight = 420;

  final FigureModel model;

  /// Read for the whole picture, for example "Reef set, 9 items".
  final String semanticsLabel;

  /// The name shown on an item's label.
  final String Function(PlacedItem item) labelText;

  /// A switch segment's text, for example "Front · 8".
  final String Function(FigureView view, int count) sideLabel;
  final FigureMode mode;
  final String? selectedItemId;
  final ValueChanged<PlacedItem>? onItemTap;

  /// The screen-reader label of an item, for example "3, BCD, Hollis SMS75".
  final String Function(PlacedItem item)? itemSemantics;

  /// Heading over the tray. The tray is hidden when the model has none.
  final String? trayTitle;

  @override
  State<DiverFigure> createState() => _DiverFigureState();
}

class _DiverFigureState extends State<DiverFigure> {
  FigureView _view = FigureView.front;

  @override
  void didUpdateWidget(DiverFigure oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A newly selected item on the hidden side brings that side forward, so
    // tapping a back item's row on a phone shows its label.
    final id = widget.selectedItemId;
    if (id == null || id == oldWidget.selectedItemId) return;
    final zone = widget.model.byId(id)?.zone;
    if (zone != null) _view = zone.view;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 360.0;
        final figures = width >= DiverFigure.wideBreakpoint
            ? _wide(context, width)
            : _phone(context, width);
        if (widget.model.tray.isEmpty) return figures;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            figures,
            const SizedBox(height: 8),
            if (widget.trayTitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  widget.trayTitle!,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in widget.model.tray)
                  _TrayTile(
                    item: item,
                    name: widget.labelText(item),
                    selected: item.item.id == widget.selectedItemId,
                    semanticsLabel: widget.itemSemantics?.call(item),
                    onTap: widget.onItemTap == null
                        ? null
                        : () => widget.onItemTap!(item),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _phone(BuildContext context, double width) {
    final counts = {
      for (final view in FigureView.values)
        view: widget.model.placed.where((p) => p.zone!.view == view).length,
    };
    final layout = FigureLayout.forSingle(
      Size(width, DiverFigure.phoneMaxFigureHeight),
    );
    final slots = labelColumns(
      model: widget.model,
      view: _view,
      layout: layout,
      width: width,
    );
    return Column(
      children: [
        SegmentedButton<FigureView>(
          segments: [
            for (final view in FigureView.values)
              ButtonSegment(
                value: view,
                label: Text(widget.sideLabel(view, counts[view]!)),
              ),
          ],
          selected: {_view},
          showSelectedIcon: false,
          onSelectionChanged: (views) => setState(() => _view = views.first),
        ),
        const SizedBox(height: 12),
        _canvas(context, width, layout, slots, only: _view),
      ],
    );
  }

  Widget _wide(BuildContext context, double width) {
    final layout = FigureLayout.forSize(
      Size(width, FigureLayout.preferredHeight(width)),
    );
    final style = FigureNameLabel.styleOf(context);
    final direction = Directionality.of(context);
    final slots = labelPills(
      model: widget.model,
      layout: layout,
      width: width,
      maxWidth: width / 4,
      widthOf: (p) =>
          FigureNameLabel.preferredWidth(widget.labelText(p), style, direction),
    );
    return _canvas(context, width, layout, slots);
  }

  Widget _canvas(
    BuildContext context,
    double width,
    FigureLayout layout,
    List<FigureLabelSlot> slots, {
    FigureView? only,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final palette = figurePaletteFor(scheme);
    final height = [
      layout.front.bottom,
      for (final slot in slots) slot.rect.bottom,
    ].reduce(math.max);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Semantics(
              label: widget.semanticsLabel,
              image: true,
              excludeSemantics: true,
              child: CustomPaint(
                painter: DiverFigurePainter(
                  model: widget.model,
                  palette: palette,
                  layout: layout,
                  only: only,
                ),
                foregroundPainter: FigureLeaderPainter(
                  slots: slots,
                  color: scheme.outline,
                ),
              ),
            ),
          ),
          for (final slot in slots)
            Positioned.fromRect(
              rect: slot.rect,
              child: FigureNameLabel(
                key: ValueKey('figure-label-${slot.item.item.id}'),
                number: slot.item.number,
                text: widget.labelText(slot.item),
                alignEnd: slot.onLeft,
                pill: only == null,
                selected: slot.item.item.id == widget.selectedItemId,
                semanticsLabel: widget.itemSemantics?.call(slot.item),
                onTap: widget.onItemTap == null
                    ? null
                    : () => widget.onItemTap!(slot.item),
              ),
            ),
        ],
      ),
    );
  }
}

class _TrayTile extends StatelessWidget {
  const _TrayTile({
    required this.item,
    required this.name,
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
  });

  final PlacedItem item;
  final String name;
  final bool selected;
  final String? semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight = selected ? figureHighlightFor(scheme) : null;
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      selected: selected,
      excludeSemantics: semanticsLabel != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: kFigureLabelHeight),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: highlight?.fill ?? scheme.surfaceContainerHighest,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FigureNumberBadge(
                number: item.number,
                size: FigureNameLabel.badgeSize,
              ),
              const SizedBox(width: 6),
              Icon(
                equipmentTypeIcon(item.item.type),
                size: 18,
                color: highlight?.onFill,
              ),
              const SizedBox(width: 6),
              Text(
                name,
                style: FigureNameLabel.styleOf(
                  context,
                ).copyWith(color: highlight?.onFill),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/figure`
Expected: PASS. These tests do not import the set page, which still passes `discLabel` until Task 4.

- [ ] **Step 8: Do not commit yet**

The set page still passes `discLabel`, so the app does not compile until
Task 4 updates it. Task 4 commits this task's files with its own, keeping
every commit on the branch buildable.

---

### Task 4: The set page and its strings

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_set_detail_page.dart`
- Modify: `lib/l10n/arb/app_*.arb` (11) and generated `lib/l10n/arb/app_localizations*.dart`
- Test: `test/features/equipment/presentation/pages/equipment_set_detail_figure_test.dart`

**Interfaces:**
- Consumes: `DiverFigure` (Task 3).
- Produces: l10n getters `equipment_figure_frontCount(int count)`, `equipment_figure_backCount(int count)`.

- [ ] **Step 1: Update and extend the page test**

In `equipment_set_detail_figure_test.dart`, give `pump` a width parameter:

```dart
  Future<void> pump(
    WidgetTester tester,
    List<EquipmentItem> items, {
    double width = 900,
  }) async {
    tester.view.physicalSize = Size(width, 2400);
```

replace both `find.byKey(const ValueKey('figure-disc-b'))` with `find.byKey(const ValueKey('figure-label-b'))`, and add:

```dart
  testWidgets('on a phone, tapping a back item\'s badge shows the back', (
    tester,
  ) async {
    await pump(tester, three, width: 390);
    expect(find.text('Front · 2'), findsOneWidget);
    expect(find.text('Back · 1'), findsOneWidget);
    expect(find.byKey(const ValueKey('figure-label-b')), findsNothing);
    final bcdRow = find.ancestor(
      of: find.text('Hollis SMS75'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: bcdRow, matching: find.byType(FigureNumberBadge)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('figure-label-b')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('the wide figure names every item', (tester) async {
    await pump(tester, three);
    expect(find.text('Hollis M1'), findsNWidgets(2)); // the label and the row
    expect(find.text('Jet Fins'), findsNWidgets(2));
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/presentation/pages/equipment_set_detail_figure_test.dart`
Expected: FAIL to compile: the page passes `discLabel`, which `DiverFigure` no longer has, and the count getters do not exist.

- [ ] **Step 3: Add the strings**

In `lib/l10n/arb/app_en.arb`, before `"equipment_figure_discLabel"` insert:

```json
  "equipment_figure_backCount": "Back · {count}",
  "@equipment_figure_backCount": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
```

and after the `"@equipment_figure_discLabel"` block insert:

```json
  "equipment_figure_frontCount": "Front · {count}",
  "@equipment_figure_frontCount": {
    "placeholders": {
      "count": {"type": "int"}
    }
  },
```

In each other locale file, after its `"equipment_figure_trayTitle"` line, add the two keys with these values:

| Locale | frontCount | backCount |
| --- | --- | --- |
| ar | `الأمام · {count}` | `الخلف · {count}` |
| de | `Vorne · {count}` | `Hinten · {count}` |
| es | `Delante · {count}` | `Detrás · {count}` |
| fr | `Devant · {count}` | `Dos · {count}` |
| he | `חזית · {count}` | `גב · {count}` |
| hu | `Elöl · {count}` | `Hátul · {count}` |
| it | `Davanti · {count}` | `Dietro · {count}` |
| nl | `Voorkant · {count}` | `Achterkant · {count}` |
| pt | `Frente · {count}` | `Costas · {count}` |
| zh | `正面 · {count}` | `背面 · {count}` |

Run `flutter gen-l10n`.

- [ ] **Step 4: Pass names to the figure**

In `equipment_set_detail_page.dart`, the `DiverFigure(...)` call becomes:

```dart
                  child: DiverFigure(
                    model: model,
                    semanticsLabel: context.l10n.equipment_figure_summary(
                      set.name,
                      model.itemCount,
                    ),
                    labelText: (placed) => placed.item.name,
                    sideLabel: (view, count) => view == FigureView.front
                        ? context.l10n.equipment_figure_frontCount(count)
                        : context.l10n.equipment_figure_backCount(count),
                    selectedItemId: _selectedId,
                    onItemTap: (placed) => _select(placed.item.id),
                    itemSemantics: (placed) =>
                        context.l10n.equipment_figure_discLabel(
                          placed.number,
                          placed.item.type.localizedName(context.l10n),
                          placed.item.name,
                        ),
                    trayTitle: context.l10n.equipment_figure_trayTitle,
                  ),
```

and add `import 'package:submersion/features/equipment/figure/domain/figure_view.dart';`.

- [ ] **Step 5: Run the page tests**

Run: `flutter test test/features/equipment/presentation/pages/`
Expected: PASS, including the three existing set detail files.

- [ ] **Step 6: Commit Tasks 3 and 4 together**

```bash
dart format lib/features/equipment lib/l10n test/features/equipment
flutter analyze lib/features/equipment test/features/equipment
git add lib/features/equipment/figure test/features/equipment/figure lib/features/equipment/presentation/pages/equipment_set_detail_page.dart lib/l10n/arb test/features/equipment/presentation/pages/equipment_set_detail_figure_test.dart
git commit -m "feat(figure): names on the figure, columns on a phone and pills wide

The numbered discs could not be read at a glance: each number meant a trip
to the list. Every placed item now carries its name beside the gear, led
by its number. A phone shows one side at a time behind a Front / Back
switch with label columns; wider screens show the pair with a pill beside
each item. Tapping a back item's row on a phone brings the back forward.

Part of #2326"
```

---

### Task 5: Verification and a look at the result

**Files:** none new.

- [ ] **Step 1: Format, analyze, artwork, l10n**

Run: `dart format . && flutter analyze && python3 tool/build_figure_artwork.py --verify && flutter gen-l10n && git status --short lib/l10n`
Expected: no formatting changes, `No issues found!`, `OK 60 pieces current`, and no `lib/l10n` output from `git status`.

- [ ] **Step 2: Guards and the feature's tests**

Run: `flutter test test/architecture test/features/equipment test/core/icons`
Expected: all PASS.

- [ ] **Step 3: Full suite, once, with nothing else running**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 4: Screenshot the real page at both widths**

With the full suite finished, render the set page through a throwaway golden test (the method in the phase 1 plan's final task: a temporary test under `test/_tmp_shot/`, Arial loaded in `setUpAll`, `matchesGoldenFile` with `--update-goldens`) at a 390 pt phone width and a 900 pt width, copy both PNGs to the scratchpad, delete the temporary test and its `goldens/` directory, and confirm `git status` shows nothing new.

- [ ] **Step 5: Report**

Do not push. Report the commits, the test counts, and the two screenshots.
