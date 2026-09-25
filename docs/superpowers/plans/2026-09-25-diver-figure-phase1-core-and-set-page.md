# Diver Figure Phase 1: Core and Set Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Draw an illustrated front-and-back diver from an equipment set's items, with numbered callouts matched to the set page's item list.

**Architecture:** Artwork is authored as SVG under `tool/figure/` and compiled by a Python script into one generated Dart file of path strings tagged with colour roles. A pure-Dart composer maps items to body zones and numbers; a `CustomPainter` draws the pieces through a per-piece path cache; numbered discs are positioned widgets sharing the painter's transform. The set detail page shows the figure above its list and numbers the rows as the legend.

**Tech Stack:** Flutter 3.47, Dart 3.13, Riverpod, `path_parsing` 1.1 (promoted from transitive to direct), `crypto` (already direct), Python 3 standard library for the generator.

**Spec:** `docs/superpowers/specs/2026-09-25-diver-figure-design.md` (tracking issue #2326; this PR says `Part of #2326`).

## Global Constraints

- Figure space is 200 wide by 400 tall, y down, shared by every piece (spec 4.1).
- Paths carry colour roles, never colours: `body`, `bodyShade`, `gearDark`, `gearLight`, `metal`, `itemColor`, `itemShade`, `outline` (spec 6).
- The generator accepts `path`, `rect`, `circle`, `ellipse` only; `transform` attributes, gradients, filters, text, `use`, `image` are rejected by name (spec 5.1, narrowed: transforms are rejected rather than baked, so authors draw in absolute figure space).
- Domain code under `lib/features/equipment/figure/domain/` and the generated artwork import nothing from `package:flutter` or `dart:ui` (spec 12.4).
- Placement priority is the canonical type order in `equipment_type_order.dart`; numbering is the caller's order (spec 4.3).
- Child items (parent link or assembly part) are not drawn and not numbered (spec 4.4).
- Every new string lands in all eleven locales: ar, de, en, es, fr, he, hu, it, nl, pt, zh; plurals use `=1{...} other{...}` in `app_en.arb` and copy the category structure of `equipment_components_count` in each other locale.
- Colours derived from the theme are tested as outcomes across `AppThemeRegistry.presets` times `Brightness.values`, never as roles.
- Paths in tests and tools are built with `p.join(...)`, never string concatenation with `/`.
- No em-dashes anywhere. No emojis. `dart format .` before every commit. Commit messages carry no attribution lines.
- Nothing is pushed by this plan; the final task ends with the branch ready and reports.

## Review Focus

1. **A set with two BCDs, one a sidemount harness.** The torso zone holds one, the sidemount context must still be true, and the second BCD must land in the tray with its number intact. Test in Task 7.
2. **An attribute holding a value the table does not know** (a BCD style of `unknown`). The default variant applies rather than a crash or an empty figure. Test in Task 3.
3. **A malformed colour attribute** (`#12G`, `red`, empty). The type default applies. Test in Task 7.
4. **Sixty items of one type.** Every candidate zone fills, the rest go to the tray, and numbering stays 1 to 60 with no gaps or duplicates. Test in Task 7.
5. **A box narrower than the gutter or with zero height.** The layout must return positive, finite rectangles and disc positions must be finite so a collapsed card never throws. Test in Task 9.

---

## File Structure

New:

```
tool/figure/manifest.json                         piece registry: id, view, layer, roles
tool/figure/<piece>.svg                            one SVG per piece
tool/build_figure_artwork.py                       generator, --verify
lib/features/equipment/figure/domain/figure_view.dart
lib/features/equipment/figure/domain/figure_space.dart
lib/features/equipment/figure/domain/figure_zone.dart
lib/features/equipment/figure/domain/figure_role.dart
lib/features/equipment/figure/domain/figure_piece_data.dart
lib/features/equipment/figure/domain/figure_placement.dart
lib/features/equipment/figure/domain/figure_model.dart
lib/features/equipment/figure/domain/figure_composer.dart
lib/features/equipment/figure/domain/figure_inputs.dart
lib/features/equipment/figure/domain/figure_palette.dart
lib/features/equipment/figure/artwork/figure_artwork.g.dart   generated
lib/features/equipment/figure/presentation/figure_paths.dart
lib/features/equipment/figure/presentation/figure_layout.dart
lib/features/equipment/figure/presentation/figure_palette_theme.dart
lib/features/equipment/figure/presentation/diver_figure_painter.dart
lib/features/equipment/figure/presentation/figure_number_badge.dart
lib/features/equipment/figure/presentation/diver_figure.dart
test/features/equipment/figure/...                one test file per unit above
```

Modified:

```
pubspec.yaml                                                   path_parsing direct dependency
lib/features/equipment/presentation/widgets/equipment_section_colors.dart   readableOn made public
lib/features/equipment/presentation/pages/equipment_set_detail_page.dart    figure card, badges, selection
lib/l10n/arb/app_*.arb (11 files) and the generated app_localizations*.dart
```

---

### Task 1: Views, zones, roles, and piece data

**Files:**
- Create: `lib/features/equipment/figure/domain/figure_view.dart`
- Create: `lib/features/equipment/figure/domain/figure_space.dart`
- Create: `lib/features/equipment/figure/domain/figure_zone.dart`
- Create: `lib/features/equipment/figure/domain/figure_role.dart`
- Create: `lib/features/equipment/figure/domain/figure_piece_data.dart`
- Test: `test/features/equipment/figure/domain/figure_zone_test.dart`

**Interfaces:**
- Produces: `enum FigureView { front, back }`; `const double kFigureWidth = 200, kFigureHeight = 400`; `enum FigureZone` with `view`, `anchorX`, `anchorY`, `capacity`, `mirrored`; `enum FigureRole`; `class FigurePathData({role, d})`; `class FigurePieceData({id, view, layer, paths})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/figure/domain/figure_zone_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/figure/domain/figure_space.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// Zones are the anchor points every disc and every piece is placed by, so
/// they have to lie inside the figure and the left/right pairs have to be
/// true mirrors: a piece authored for the left twin is flipped onto the right.
void main() {
  test('every zone anchors inside the figure box', () {
    for (final zone in FigureZone.values) {
      expect(zone.anchorX, inInclusiveRange(0, kFigureWidth), reason: zone.name);
      expect(zone.anchorY, inInclusiveRange(0, kFigureHeight), reason: zone.name);
      expect(zone.capacity, greaterThanOrEqualTo(1), reason: zone.name);
    }
  });

  test('both views have zones', () {
    for (final view in FigureView.values) {
      expect(FigureZone.values.where((z) => z.view == view), isNotEmpty);
    }
  });

  test('mirrored zones sit at the mirror of an unmirrored twin', () {
    const pairs = {
      FigureZone.chestClipRight: FigureZone.chestClipLeft,
      FigureZone.wristRight: FigureZone.wristLeft,
      FigureZone.handRight: FigureZone.handLeft,
      FigureZone.hipRight: FigureZone.hipLeft,
      FigureZone.thighRight: FigureZone.thighLeft,
      FigureZone.stageRight: FigureZone.stageLeft,
      FigureZone.trimLeft: FigureZone.trimRight,
      FigureZone.sidemountLeft: FigureZone.sidemountRight,
    };
    for (final entry in pairs.entries) {
      final mirrored = entry.key;
      final twin = entry.value;
      expect(mirrored.mirrored, isTrue, reason: mirrored.name);
      expect(twin.mirrored, isFalse, reason: twin.name);
      expect(mirrored.view, twin.view, reason: mirrored.name);
      expect(mirrored.anchorX, closeTo(kFigureWidth - twin.anchorX, 0.001));
      expect(mirrored.anchorY, closeTo(twin.anchorY, 0.001));
    }
    final mirroredZones = FigureZone.values.where((z) => z.mirrored).toSet();
    expect(mirroredZones, pairs.keys.toSet(),
        reason: 'every mirrored zone must be listed here with its twin');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/figure/domain/figure_zone_test.dart`
Expected: FAIL, the imports do not resolve.

- [ ] **Step 3: Write the domain files**

```dart
// lib/features/equipment/figure/domain/figure_view.dart
/// Which side of the diver a zone or a piece of artwork belongs to.
enum FigureView { front, back }
```

```dart
// lib/features/equipment/figure/domain/figure_space.dart
/// The coordinate space every piece is drawn in and every zone is anchored
/// in: 200 wide, 400 tall, y down, the same for the front and the back.
const double kFigureWidth = 200;
const double kFigureHeight = 400;
```

```dart
// lib/features/equipment/figure/domain/figure_role.dart
/// A colour role on a path. The palette turns a role into a colour at paint
/// time, so the artwork never names a colour.
enum FigureRole {
  body,
  bodyShade,
  gearDark,
  gearLight,
  metal,
  itemColor,
  itemShade,
  outline,
}
```

```dart
// lib/features/equipment/figure/domain/figure_piece_data.dart
import 'package:submersion/features/equipment/figure/domain/figure_role.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';

/// One filled path of a piece: SVG path data in figure space plus its role.
class FigurePathData {
  const FigurePathData({required this.role, required this.d});

  final FigureRole role;
  final String d;
}

/// One piece of artwork, generated from `tool/figure/<id>.svg`.
///
/// Pieces are authored in absolute figure space. A piece placed in a
/// mirrored zone is flipped about the figure's centre line by the painter.
class FigurePieceData {
  const FigurePieceData({
    required this.id,
    required this.view,
    required this.layer,
    required this.paths,
  });

  final String id;
  final FigureView view;

  /// Paint order within a view, low first. The body is 0.
  final int layer;
  final List<FigurePathData> paths;
}
```

```dart
// lib/features/equipment/figure/domain/figure_zone.dart
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';

/// An anchor point on the mannequin where a type of gear sits.
///
/// Coordinates are in figure space (see `figure_space.dart`) as the viewer
/// sees them. "Left" and "right" name the diver's own side: on the front view
/// the diver's left is on the viewer's left, and on the back view it is on the
/// viewer's right, which is why the back-view `...Left` zones carry the larger
/// x and are the mirrored ones there.
///
/// A piece is authored for the unmirrored twin of a pair; a zone with
/// [mirrored] set has the painter flip that piece about x = 100.
enum FigureZone {
  // Front, head.
  head(FigureView.front, 100, 22),
  face(FigureView.front, 100, 40),
  hud(FigureView.front, 118, 36),
  maskStrap(FigureView.front, 128, 42),
  mouth(FigureView.front, 100, 58),
  // Front, torso.
  octo(FigureView.front, 120, 110),
  chestClipLeft(FigureView.front, 80, 100),
  chestClipRight(FigureView.front, 120, 100, mirrored: true),
  chest(FigureView.front, 100, 120),
  torsoFront(FigureView.front, 100, 140),
  suit(FigureView.front, 58, 110),
  underlayer(FigureView.front, 142, 110, capacity: 2),
  stageLeft(FigureView.front, 62, 160),
  stageRight(FigureView.front, 138, 160, mirrored: true),
  // Front, arms and hands.
  wristLeft(FigureView.front, 44, 196),
  wristRight(FigureView.front, 156, 196, mirrored: true),
  hands(FigureView.front, 40, 216),
  handLeft(FigureView.front, 28, 236),
  handRight(FigureView.front, 172, 236, mirrored: true),
  cameraArm(FigureView.front, 172, 252, capacity: 2, mirrored: true),
  console(FigureView.front, 62, 230),
  // Front, waist and legs.
  waist(FigureView.front, 100, 198),
  hipLeft(FigureView.front, 74, 206),
  hipRight(FigureView.front, 126, 206, mirrored: true),
  thighLeft(FigureView.front, 78, 250),
  thighRight(FigureView.front, 122, 250, mirrored: true),
  dpv(FigureView.front, 100, 280),
  calfLeft(FigureView.front, 76, 300),
  ankles(FigureView.front, 100, 335),
  feet(FigureView.front, 100, 352),
  fins(FigureView.front, 100, 380),
  // Back.
  tankValve(FigureView.back, 100, 74, capacity: 2),
  backTank(FigureView.back, 100, 130, capacity: 2),
  wing(FigureView.back, 100, 150),
  backplate(FigureView.back, 100, 176),
  trimRight(FigureView.back, 76, 176),
  trimLeft(FigureView.back, 124, 176, mirrored: true),
  buttDRing(FigureView.back, 100, 214),
  sidemountRight(FigureView.back, 60, 160),
  sidemountLeft(FigureView.back, 140, 160, mirrored: true);

  const FigureZone(
    this.view,
    this.anchorX,
    this.anchorY, {
    this.capacity = 1,
    this.mirrored = false,
  });

  final FigureView view;
  final double anchorX;
  final double anchorY;

  /// How many items the zone holds before the next candidate is tried.
  final int capacity;

  /// Whether a piece placed here is flipped about the centre line.
  final bool mirrored;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/figure/domain/figure_zone_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/figure test/features/equipment/figure
git add lib/features/equipment/figure/domain test/features/equipment/figure/domain/figure_zone_test.dart
git commit -m "feat(figure): views, zones, roles and piece data for the diver figure

Part of #2326"
```

---

### Task 2: Artwork pipeline with the mannequin

**Files:**
- Create: `tool/figure/manifest.json`
- Create: `tool/figure/body_front.svg`
- Create: `tool/figure/body_back.svg`
- Create: `tool/build_figure_artwork.py`
- Create: `lib/features/equipment/figure/artwork/figure_artwork.g.dart` (generated)
- Modify: `pubspec.yaml` (add `path_parsing: ^1.1.0` under `dependencies`, after `path: ^1.9.0`)
- Test: `test/features/equipment/figure/artwork/figure_artwork_test.dart`

**Interfaces:**
- Consumes: `FigurePieceData`, `FigurePathData`, `FigureRole`, `FigureView` from Task 1.
- Produces: `const String figureArtworkDigest`; `const Map<String, FigurePieceData> figureArtwork` with at least `body_front` and `body_back`; the generator command `python3 tool/build_figure_artwork.py [--verify]`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/figure/artwork/figure_artwork_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_parsing/path_parsing.dart';
import 'package:submersion/features/equipment/figure/artwork/figure_artwork.g.dart';
import 'package:submersion/features/equipment/figure/domain/figure_space.dart';

/// The generated artwork is a build artefact checked in like the icon font.
/// CI does not run the Python generator, so these tests are what keep the
/// file honest: its digest must match the sources it was built from, and
/// every path must parse and stay inside the figure box.
void main() {
  test('the generated artwork matches tool/figure', () {
    final dir = Directory(p.join('tool', 'figure'));
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.svg') || p.basename(f.path) == 'manifest.json')
        .toList()
      ..sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    final bytes = <int>[];
    for (final file in files) {
      bytes.addAll(utf8.encode('${p.basename(file.path)}\n'));
      bytes.addAll(file.readAsBytesSync());
    }
    expect(
      figureArtworkDigest,
      sha256.convert(bytes).toString(),
      reason: 'run: python3 tool/build_figure_artwork.py',
    );
  });

  test('the mannequin exists for both views', () {
    expect(figureArtwork['body_front']?.layer, 0);
    expect(figureArtwork['body_back']?.layer, 0);
  });

  test('every path parses and stays inside the figure box', () {
    for (final piece in figureArtwork.values) {
      expect(piece.paths, isNotEmpty, reason: piece.id);
      for (final path in piece.paths) {
        final proxy = _BoundsProxy();
        writeSvgPathDataToPath(path.d, proxy);
        expect(proxy.points, isNotEmpty, reason: '${piece.id}: ${path.d}');
        for (final point in proxy.points) {
          expect(point.$1, inInclusiveRange(-0.5, kFigureWidth + 0.5), reason: piece.id);
          expect(point.$2, inInclusiveRange(-0.5, kFigureHeight + 0.5), reason: piece.id);
        }
      }
    }
  });
}

class _BoundsProxy extends PathProxy {
  final points = <(double, double)>[];

  @override
  void moveTo(double x, double y) => points.add((x, y));

  @override
  void lineTo(double x, double y) => points.add((x, y));

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) {
    points.add((x1, y1));
    points.add((x2, y2));
    points.add((x3, y3));
  }

  @override
  void close() {}
}
```

- [ ] **Step 2: Add the dependency and run the test to verify it fails**

In `pubspec.yaml`, after the line `  path: ^1.9.0`, add:

```yaml
  path_parsing: ^1.1.0  # SVG path data for the diver figure artwork
```

Run: `flutter pub get && flutter test test/features/equipment/figure/artwork/figure_artwork_test.dart`
Expected: FAIL, `figure_artwork.g.dart` does not exist.

- [ ] **Step 3: Write the manifest and the mannequin SVGs**

`tool/figure/manifest.json`:

```json
{
  "pieces": [
    {"id": "body_front", "view": "front", "layer": 0,
     "roles": ["body", "body", "body", "body", "body", "body", "body", "body", "body", "body", "body", "bodyShade", "bodyShade"]},
    {"id": "body_back", "view": "back", "layer": 0,
     "roles": ["body", "body", "body", "body", "body", "body", "body", "body", "body", "body", "body", "bodyShade"]}
  ]
}
```

`tool/figure/body_front.svg` (thirteen shapes, in this order: head, neck, torso, left arm, right arm, left hand, right hand, left leg, right leg, left foot, right foot, torso shade, neck shade):

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 400">
  <circle cx="100" cy="42" r="22"/>
  <rect x="92" y="60" width="16" height="14"/>
  <rect x="68" y="72" width="64" height="128" rx="16"/>
  <path d="M70 82 L46 190 L60 194 L84 96 Z"/>
  <path d="M130 82 L154 190 L140 194 L116 96 Z"/>
  <circle cx="40" cy="214" r="11"/>
  <circle cx="160" cy="214" r="11"/>
  <path d="M78 196 L70 340 L94 340 L100 210 Z"/>
  <path d="M122 196 L130 340 L106 340 L100 210 Z"/>
  <rect x="68" y="338" width="26" height="20" rx="5"/>
  <rect x="106" y="338" width="26" height="20" rx="5"/>
  <rect x="120" y="80" width="12" height="112" rx="6"/>
  <ellipse cx="100" cy="72" rx="9" ry="3"/>
</svg>
```

`tool/figure/body_back.svg` (twelve shapes: the same eleven body shapes, then a spine shade):

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 400">
  <circle cx="100" cy="42" r="22"/>
  <rect x="92" y="60" width="16" height="14"/>
  <rect x="68" y="72" width="64" height="128" rx="16"/>
  <path d="M70 82 L46 190 L60 194 L84 96 Z"/>
  <path d="M130 82 L154 190 L140 194 L116 96 Z"/>
  <circle cx="40" cy="214" r="11"/>
  <circle cx="160" cy="214" r="11"/>
  <path d="M78 196 L70 340 L94 340 L100 210 Z"/>
  <path d="M122 196 L130 340 L106 340 L100 210 Z"/>
  <rect x="68" y="338" width="26" height="20" rx="5"/>
  <rect x="106" y="338" width="26" height="20" rx="5"/>
  <rect x="96" y="80" width="8" height="110" rx="4"/>
</svg>
```

- [ ] **Step 4: Write the generator**

`tool/build_figure_artwork.py`:

```python
#!/usr/bin/env python3
"""Compile the diver figure artwork into Dart.

Sources: tool/figure/manifest.json and one SVG per piece at tool/figure/<id>.svg,
drawn in the shared 200 by 400 figure space (y down).
Output:  lib/features/equipment/figure/artwork/figure_artwork.g.dart

    python3 tool/build_figure_artwork.py            # write the Dart file
    python3 tool/build_figure_artwork.py --verify   # check the sources and that the Dart file is current

Accepted SVG subset: <path d>, <rect> (x y width height, optional rx ry),
<circle>, <ellipse>, nested in any <g>. A transform attribute anywhere, or a
gradient, filter, text, use, image, pattern, mask, clipPath or style element,
is rejected by name. Shapes map in document order to the manifest's roles.

Bounds are checked conservatively: for an arc both endpoints plus the arc's
radii around them count, so a rounded rectangle needs its rx of margin from
the figure edge. Use straight edges for shapes that touch the edge.
"""
import argparse
import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "tool" / "figure"
OUT = ROOT / "lib" / "features" / "equipment" / "figure" / "artwork" / "figure_artwork.g.dart"
WIDTH, HEIGHT = 200.0, 400.0
ROLES = ["body", "bodyShade", "gearDark", "gearLight", "metal", "itemColor", "itemShade", "outline"]
VIEWS = ["front", "back"]
SHAPES = {"path", "rect", "circle", "ellipse"}
CONTAINERS = {"svg", "g", "title", "desc", "defs"}
REJECTED = {"linearGradient", "radialGradient", "filter", "text", "use", "image", "pattern", "mask", "clipPath", "style"}
TOKEN = re.compile(r"[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?")
ARGS = {"M": 2, "L": 2, "T": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "A": 7, "Z": 0}


class FigureError(Exception):
    pass


def n(v):
    s = "{:.2f}".format(v).rstrip("0").rstrip(".")
    return "0" if s in ("", "-0") else s


def local(tag):
    return tag.split("}")[-1]


def ellipse_path(cx, cy, rx, ry):
    return (
        "M{} {}A{} {} 0 1 1 {} {}A{} {} 0 1 1 {} {}Z".format(
            n(cx - rx), n(cy), n(rx), n(ry), n(cx + rx), n(cy), n(rx), n(ry), n(cx - rx), n(cy)
        )
    )


def rect_path(x, y, w, h, rx, ry):
    if rx <= 0 and ry <= 0:
        return "M{} {}H{}V{}H{}Z".format(n(x), n(y), n(x + w), n(y + h), n(x))
    rx = min(rx, w / 2)
    ry = min(ry, h / 2)
    return (
        "M{} {}H{}A{} {} 0 0 1 {} {}V{}A{} {} 0 0 1 {} {}H{}A{} {} 0 0 1 {} {}V{}A{} {} 0 0 1 {} {}Z".format(
            n(x + rx), n(y), n(x + w - rx), n(rx), n(ry), n(x + w), n(y + ry), n(y + h - ry),
            n(rx), n(ry), n(x + w - rx), n(y + h), n(x + rx), n(rx), n(ry), n(x), n(y + h - ry),
            n(y + ry), n(rx), n(ry), n(x + rx), n(y),
        )
    )


def attr(el, name, default=None):
    value = el.attrib.get(name, default)
    if value is None:
        raise FigureError("{} is missing {}".format(local(el.tag), name))
    return float(value)


def shapes_of(svg_file):
    """Every accepted shape in document order, as path data."""
    root = ET.parse(svg_file).getroot()
    shapes = []
    for el in root.iter():
        tag = local(el.tag)
        if tag in REJECTED:
            raise FigureError("{}: <{}> is not supported".format(svg_file.name, tag))
        if "transform" in el.attrib:
            raise FigureError("{}: transform attributes are not supported, draw in figure space".format(svg_file.name))
        if tag in CONTAINERS:
            if tag == "defs" and len(el):
                raise FigureError("{}: <defs> must be empty".format(svg_file.name))
            continue
        if tag == "path":
            shapes.append(el.attrib["d"].strip())
        elif tag == "rect":
            rx = float(el.attrib.get("rx", el.attrib.get("ry", 0)))
            ry = float(el.attrib.get("ry", el.attrib.get("rx", 0)))
            shapes.append(rect_path(attr(el, "x", 0), attr(el, "y", 0), attr(el, "width"), attr(el, "height"), rx, ry))
        elif tag == "circle":
            r = attr(el, "r")
            shapes.append(ellipse_path(attr(el, "cx", 0), attr(el, "cy", 0), r, r))
        elif tag == "ellipse":
            shapes.append(ellipse_path(attr(el, "cx", 0), attr(el, "cy", 0), attr(el, "rx"), attr(el, "ry")))
        else:
            raise FigureError("{}: <{}> is not supported".format(svg_file.name, tag))
    return shapes


def path_points(d):
    """Points that bound the path: every endpoint and control point, and for
    arcs the radii around both ends."""
    tokens = TOKEN.findall(d)
    points = []
    cx = cy = sx = sy = 0.0
    i = 0
    command = None
    while i < len(tokens):
        if tokens[i].isalpha():
            command = tokens[i]
            i += 1
            if command in "Zz":
                cx, cy = sx, sy
                continue
        if command is None:
            raise FigureError("path data must start with a command: {}".format(d[:40]))
        upper = command.upper()
        count = ARGS[upper]
        args = [float(t) for t in tokens[i:i + count]]
        if len(args) != count:
            raise FigureError("{} needs {} numbers: {}".format(command, count, d[:60]))
        i += count
        relative = command.islower()
        ox, oy = (cx, cy) if relative else (0.0, 0.0)
        if upper == "H":
            cx = ox + args[0]
        elif upper == "V":
            cy = oy + args[0]
        elif upper == "A":
            rx, ry = abs(args[0]), abs(args[1])
            ex, ey = ox + args[5], oy + args[6]
            for x, y in ((cx, cy), (ex, ey)):
                points.extend([(x - rx, y - ry), (x + rx, y + ry)])
            cx, cy = ex, ey
        else:
            for k in range(0, count, 2):
                points.append((ox + args[k], oy + args[k + 1]))
            cx, cy = ox + args[count - 2], oy + args[count - 1]
        if upper == "M":
            sx, sy = cx, cy
            command = "l" if relative else "L"
        points.append((cx, cy))
    return points


def load_manifest():
    data = json.loads((SRC / "manifest.json").read_text(encoding="utf-8"))
    pieces = data.get("pieces")
    if not isinstance(pieces, list) or not pieces:
        raise FigureError("manifest.json needs a non-empty pieces list")
    seen = set()
    for piece in pieces:
        pid = piece.get("id")
        if not isinstance(pid, str) or not re.fullmatch(r"[a-z][a-z0-9_]*", pid):
            raise FigureError("bad piece id: {!r}".format(pid))
        if pid in seen:
            raise FigureError("duplicate piece id: {}".format(pid))
        seen.add(pid)
        if piece.get("view") not in VIEWS:
            raise FigureError("{}: view must be one of {}".format(pid, VIEWS))
        if not isinstance(piece.get("layer"), int) or piece["layer"] < 0:
            raise FigureError("{}: layer must be a non-negative integer".format(pid))
        roles = piece.get("roles")
        if not isinstance(roles, list) or not roles or any(r not in ROLES for r in roles):
            raise FigureError("{}: roles must be a non-empty list drawn from {}".format(pid, ROLES))
    orphans = sorted(f.stem for f in SRC.glob("*.svg")) 
    orphans = [s for s in orphans if s not in seen]
    if orphans:
        raise FigureError("SVG files without a manifest entry: {}".format(", ".join(orphans)))
    return pieces


def compile_pieces(pieces):
    compiled = []
    for piece in pieces:
        svg_file = SRC / "{}.svg".format(piece["id"])
        if not svg_file.exists():
            raise FigureError("{}: {} is missing".format(piece["id"], svg_file.name))
        shapes = shapes_of(svg_file)
        if len(shapes) != len(piece["roles"]):
            raise FigureError("{}: {} shapes but {} roles".format(piece["id"], len(shapes), len(piece["roles"])))
        for d in shapes:
            for x, y in path_points(d):
                if not (0 <= x <= WIDTH and 0 <= y <= HEIGHT):
                    raise FigureError("{}: a shape leaves the figure box at ({}, {})".format(piece["id"], n(x), n(y)))
        compiled.append({"id": piece["id"], "view": piece["view"], "layer": piece["layer"],
                         "paths": list(zip(piece["roles"], shapes))})
    return compiled


def digest():
    h = hashlib.sha256()
    files = sorted(list(SRC.glob("*.svg")) + [SRC / "manifest.json"], key=lambda f: f.name)
    for f in files:
        h.update("{}\n".format(f.name).encode("utf-8"))
        h.update(f.read_bytes())
    return h.hexdigest()


def emit_dart(compiled, sources_digest):
    lines = [
        "// GENERATED by tool/build_figure_artwork.py from tool/figure/. Do not edit.",
        "// sources-digest: {}".format(sources_digest),
        "// dart format off",
        "",
        "import 'package:submersion/features/equipment/figure/domain/figure_piece_data.dart';",
        "import 'package:submersion/features/equipment/figure/domain/figure_role.dart';",
        "import 'package:submersion/features/equipment/figure/domain/figure_view.dart';",
        "",
        "/// SHA-256 over the manifest and every SVG, so a test can tell when this",
        "/// file is stale against its sources.",
        "const String figureArtworkDigest = '{}';".format(sources_digest),
        "",
        "/// Every piece of artwork by id.",
        "const Map<String, FigurePieceData> figureArtwork = {",
    ]
    for piece in compiled:
        lines.append("  '{}': FigurePieceData(".format(piece["id"]))
        lines.append("    id: '{}',".format(piece["id"]))
        lines.append("    view: FigureView.{},".format(piece["view"]))
        lines.append("    layer: {},".format(piece["layer"]))
        lines.append("    paths: [")
        for role, d in piece["paths"]:
            lines.append("      FigurePathData(role: FigureRole.{}, d: '{}'),".format(role, d))
        lines.append("    ],")
        lines.append("  ),")
    lines.append("};")
    lines.append("")
    return "\n".join(lines)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--verify", action="store_true", help="check sources and that the Dart file is current")
    args = parser.parse_args(argv)
    try:
        compiled = compile_pieces(load_manifest())
        text = emit_dart(compiled, digest())
    except (FigureError, ET.ParseError, KeyError, ValueError) as error:
        print("FAIL {}".format(error))
        return 1
    if args.verify:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print("FAIL {} is stale; run python3 tool/build_figure_artwork.py".format(OUT.relative_to(ROOT)))
            return 1
        print("OK {} pieces current".format(len(compiled)))
        return 0
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding="utf-8")
    print("wrote {} ({} pieces)".format(OUT.relative_to(ROOT), len(compiled)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
```

- [ ] **Step 5: Generate and verify**

Run: `python3 tool/build_figure_artwork.py && python3 tool/build_figure_artwork.py --verify`
Expected: `wrote lib/features/equipment/figure/artwork/figure_artwork.g.dart (2 pieces)` then `OK 2 pieces current`.

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/equipment/figure/artwork/figure_artwork_test.dart`
Expected: PASS, 3 tests. If the digest test fails, the sort order or the byte framing differs between the Python and Dart digests; both hash `name\n` followed by the file bytes, files sorted by base name.

- [ ] **Step 7: Confirm the generated file survives the formatter and the analyzer**

Run: `dart format lib/features/equipment/figure && python3 tool/build_figure_artwork.py --verify && flutter analyze lib/features/equipment/figure`
Expected: verify still prints `OK` (the `// dart format off` line protects the file) and analyze reports no issues. `analysis_options.yaml` excludes `**/*.g.dart`, so the long path strings raise no lint.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock tool/figure tool/build_figure_artwork.py lib/features/equipment/figure/artwork test/features/equipment/figure/artwork
git commit -m "feat(figure): artwork generator and the mannequin

Part of #2326"
```

---

### Task 3: The placement table

**Files:**
- Create: `lib/features/equipment/figure/domain/figure_placement.dart`
- Test: `test/features/equipment/figure/domain/figure_placement_test.dart`

**Interfaces:**
- Consumes: `FigureZone` (Task 1), `EquipmentType` from `lib/core/constants/enums.dart`, `EquipmentAttrKeys` from `lib/features/equipment/domain/constants/equipment_attribute_catalog.dart`.
- Produces: `abstract final class FigureColors` (ARGB ints); `class FigureContext({bool sidemountRig})`; `class FigurePlacementSpec({zones, piecesByZone, defaultColor, occupies})` with `isTray` and `piecesFor(zone)`; `FigurePlacement.forType(type, {attributes, context})`, `FigurePlacement.contributesSidemountRig(type, attributes)`, `FigurePlacement.childTypes`, `FigurePlacement.trayTypes`, `FigurePlacement.variantAttributeSets`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/figure/domain/figure_placement_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// The placement table is the whole "where does it go" knowledge of the
/// figure, so every type has to answer, and the variants have to move gear
/// the way the attribute says.
void main() {
  test('every type either has candidate zones or is a tray type', () {
    for (final type in EquipmentType.values) {
      final spec = FigurePlacement.forType(type);
      if (FigurePlacement.trayTypes.contains(type)) {
        expect(spec.isTray, isTrue, reason: type.name);
      } else {
        expect(spec.zones, isNotEmpty, reason: type.name);
        for (final zone in spec.zones) {
          expect(spec.piecesFor(zone), isNotEmpty,
              reason: '${type.name} has no artwork for ${zone.name}');
        }
      }
    }
  });

  test('a tank goes on the back unless the rig is sidemount', () {
    expect(FigurePlacement.forType(EquipmentType.tank).zones.first,
        FigureZone.backTank);
    final sidemount = FigurePlacement.forType(
      EquipmentType.tank,
      context: const FigureContext(sidemountRig: true),
    );
    expect(sidemount.zones.take(2),
        [FigureZone.sidemountLeft, FigureZone.sidemountRight]);
    expect(sidemount.zones, isNot(contains(FigureZone.backTank)));
    // Dive tank roles can still land a tank on the back in a sidemount rig,
    // so the artwork for every tank zone is always present.
    expect(sidemount.piecesFor(FigureZone.backTank), ['tank_single_back']);
  });

  test('a steel tank is drawn darker than an aluminium one', () {
    final aluminium = FigurePlacement.forType(EquipmentType.tank).defaultColor;
    final steel = FigurePlacement.forType(
      EquipmentType.tank,
      attributes: {EquipmentAttrKeys.tankMaterial: 'steel'},
    ).defaultColor;
    expect(steel, FigureColors.steel);
    expect(aluminium, FigureColors.aluminium);
  });

  test('a BCD style picks its pieces', () {
    expect(FigurePlacement.forType(EquipmentType.bcd)
        .piecesFor(FigureZone.torsoFront), ['bcd_jacket_front']);
    expect(FigurePlacement.forType(EquipmentType.bcd,
        attributes: {EquipmentAttrKeys.bcdStyle: 'wing'})
        .piecesFor(FigureZone.torsoFront), ['bcd_harness_front', 'bcd_wing_back']);
    expect(FigurePlacement.forType(EquipmentType.bcd,
        attributes: {EquipmentAttrKeys.bcdStyle: 'sidemount'})
        .piecesFor(FigureZone.torsoFront), ['bcd_sidemount_front', 'bcd_sidemount_back']);
  });

  test('an unknown attribute value falls back to the default variant', () {
    final spec = FigurePlacement.forType(EquipmentType.bcd,
        attributes: {EquipmentAttrKeys.bcdStyle: 'unknown'});
    expect(spec.piecesFor(FigureZone.torsoFront), ['bcd_jacket_front']);
    final computer = FigurePlacement.forType(EquipmentType.computer,
        attributes: {'mount': 'ankle'});
    expect(computer.zones, [FigureZone.wristLeft, FigureZone.wristRight]);
  });

  test('a console computer, a HUD, and integrated weights move zones', () {
    expect(FigurePlacement.forType(EquipmentType.computer,
        attributes: {'mount': 'console'}).zones, [FigureZone.console]);
    expect(FigurePlacement.forType(EquipmentType.computer,
        attributes: {'mount': 'hud'}).zones, [FigureZone.hud]);
    expect(FigurePlacement.forType(EquipmentType.weights,
        attributes: {EquipmentAttrKeys.weightStyle: 'integrated'}).zones,
        [FigureZone.hipLeft, FigureZone.hipRight]);
    expect(FigurePlacement.forType(EquipmentType.weights,
        attributes: {EquipmentAttrKeys.weightStyle: 'trim'}).zones,
        [FigureZone.trimLeft, FigureZone.trimRight]);
    expect(FigurePlacement.forType(EquipmentType.gearPocket,
        attributes: {'pocket_mount': 'thigh'}).zones,
        [FigureZone.thighLeft, FigureZone.thighRight]);
  });

  test('a back-mounted rebreather takes the whole back tank zone', () {
    final spec = FigurePlacement.forType(EquipmentType.rebreather);
    expect(spec.zones, [FigureZone.backTank]);
    expect(spec.occupies, FigureZone.backTank.capacity);
    expect(FigurePlacement.forType(EquipmentType.rebreather,
        attributes: {'mount_configuration': 'chest'}).zones, [FigureZone.chest]);
  });

  test('only a sidemount BCD or rebreather makes a sidemount rig', () {
    expect(FigurePlacement.contributesSidemountRig(
        EquipmentType.bcd, {EquipmentAttrKeys.bcdStyle: 'sidemount'}), isTrue);
    expect(FigurePlacement.contributesSidemountRig(
        EquipmentType.rebreather, {'mount_configuration': 'sidemount'}), isTrue);
    expect(FigurePlacement.contributesSidemountRig(EquipmentType.bcd, {}), isFalse);
    expect(FigurePlacement.contributesSidemountRig(EquipmentType.harness, {}), isFalse);
  });

  test('child types are tray types when they arrive top level', () {
    for (final type in FigurePlacement.childTypes) {
      expect(FigurePlacement.trayTypes, contains(type));
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/figure/domain/figure_placement_test.dart`
Expected: FAIL, `figure_placement.dart` does not exist.

- [ ] **Step 3: Write the placement table**

```dart
// lib/features/equipment/figure/domain/figure_placement.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// Default artwork colours per type, ARGB. A diver's own colour attribute
/// (phase 3) replaces these per item.
abstract final class FigureColors {
  static const int black = 0xFF2A2A2E;
  static const int metal = 0xFF9AA3AD;
  static const int aluminium = 0xFFC9CED4;
  static const int steel = 0xFF5B6470;
  static const int darkBlue = 0xFF1F3A5F;
  static const int darkGrey = 0xFF3A3F47;
  static const int midGrey = 0xFF7A8088;
  static const int lightGrey = 0xFFB8BEC6;
  static const int yellow = 0xFFF4C542;
  static const int orange = 0xFFF28C28;
}

/// What the composer already knows about the whole set when it places one
/// item: today only whether the rig is sidemount.
class FigureContext {
  const FigureContext({this.sidemountRig = false});

  final bool sidemountRig;
}

/// Where one type of gear may sit and what to draw there.
class FigurePlacementSpec {
  const FigurePlacementSpec({
    required this.zones,
    this.piecesByZone = const {},
    required this.defaultColor,
    this.occupies = 1,
  });

  /// Candidate zones in preference order. Empty means the tray.
  final List<FigureZone> zones;

  /// Artwork per zone, one piece per view drawn. A zone may be present here
  /// without being a candidate (a tank keeps its back artwork in a sidemount
  /// rig, because a dive tank role can still put it there).
  final Map<FigureZone, List<String>> piecesByZone;

  /// ARGB, used when the item carries no colour attribute.
  final int defaultColor;

  /// Slots consumed in the zone the item lands in. A back-mounted rebreather
  /// fills the whole back tank zone.
  final int occupies;

  bool get isTray => zones.isEmpty;

  List<String> piecesFor(FigureZone zone) => piecesByZone[zone] ?? const [];
}

/// The table from equipment type to body zone and artwork (spec section 4.2).
abstract final class FigurePlacement {
  /// Types that live inside another item; drawn only as their parent.
  static const Set<EquipmentType> childTypes = {
    EquipmentType.o2Cell,
    EquipmentType.battery,
  };

  /// Types with no place on the body. They are numbered in the tray.
  static const Set<EquipmentType> trayTypes = {
    EquipmentType.hose,
    EquipmentType.tankBand,
    EquipmentType.tool,
    EquipmentType.o2Cell,
    EquipmentType.battery,
    EquipmentType.other,
  };

  /// Every attribute combination the table reacts to, for tests that need
  /// to reach every variant.
  static const List<Map<String, String?>> variantAttributeSets = [
    {},
    {EquipmentAttrKeys.bcdStyle: 'back_inflate'},
    {EquipmentAttrKeys.bcdStyle: 'wing'},
    {EquipmentAttrKeys.bcdStyle: 'sidemount'},
    {_mount: 'wrist'},
    {_mount: 'console'},
    {_mount: 'hud'},
    {_mountConfiguration: 'chest'},
    {_mountConfiguration: 'sidemount'},
    {EquipmentAttrKeys.weightStyle: 'integrated'},
    {EquipmentAttrKeys.weightStyle: 'trim'},
    {EquipmentAttrKeys.weightStyle: 'ankle'},
    {_pocketMount: 'thigh'},
    {_pocketMount: 'waist_belt'},
    {EquipmentAttrKeys.tankMaterial: 'steel'},
  ];

  // Choice keys the catalog declares as literals rather than constants.
  static const String _mount = 'mount';
  static const String _mountConfiguration = 'mount_configuration';
  static const String _pocketMount = 'pocket_mount';

  static bool contributesSidemountRig(
    EquipmentType type,
    Map<String, String?> attributes,
  ) =>
      (type == EquipmentType.bcd &&
          attributes[EquipmentAttrKeys.bcdStyle] == 'sidemount') ||
      (type == EquipmentType.rebreather &&
          attributes[_mountConfiguration] == 'sidemount');

  static FigurePlacementSpec forType(
    EquipmentType type, {
    Map<String, String?> attributes = const {},
    FigureContext context = const FigureContext(),
  }) {
    switch (type) {
      case EquipmentType.regulator:
      case EquipmentType.secondStage:
        return const FigurePlacementSpec(
          zones: [FigureZone.mouth, FigureZone.octo],
          piecesByZone: {
            FigureZone.mouth: ['regulator_mouth_front'],
            FigureZone.octo: ['regulator_octo_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.firstStage:
        return const FigurePlacementSpec(
          zones: [FigureZone.tankValve],
          piecesByZone: {FigureZone.tankValve: ['firststage_back']},
          defaultColor: FigureColors.metal,
        );
      case EquipmentType.transmitter:
        return const FigurePlacementSpec(
          zones: [FigureZone.tankValve],
          piecesByZone: {FigureZone.tankValve: ['transmitter_back']},
          defaultColor: FigureColors.metal,
        );
      case EquipmentType.bcd:
        final pieces = switch (attributes[EquipmentAttrKeys.bcdStyle]) {
          'back_inflate' || 'wing' => const ['bcd_harness_front', 'bcd_wing_back'],
          'sidemount' => const ['bcd_sidemount_front', 'bcd_sidemount_back'],
          _ => const ['bcd_jacket_front'],
        };
        return FigurePlacementSpec(
          zones: const [FigureZone.torsoFront],
          piecesByZone: {FigureZone.torsoFront: pieces},
          defaultColor: FigureColors.black,
        );
      case EquipmentType.harness:
        return const FigurePlacementSpec(
          zones: [FigureZone.torsoFront],
          piecesByZone: {FigureZone.torsoFront: ['bcd_harness_front']},
          defaultColor: FigureColors.black,
        );
      case EquipmentType.backplate:
        return const FigurePlacementSpec(
          zones: [FigureZone.backplate],
          piecesByZone: {FigureZone.backplate: ['backplate_back']},
          defaultColor: FigureColors.metal,
        );
      case EquipmentType.wing:
        return const FigurePlacementSpec(
          zones: [FigureZone.wing],
          piecesByZone: {FigureZone.wing: ['bcd_wing_back']},
          defaultColor: FigureColors.black,
        );
      case EquipmentType.weightPocket:
        if (attributes[EquipmentAttrKeys.weightStyle] == 'trim') {
          return const FigurePlacementSpec(
            zones: [FigureZone.trimLeft, FigureZone.trimRight],
            piecesByZone: {
              FigureZone.trimLeft: ['weights_trim_back'],
              FigureZone.trimRight: ['weights_trim_back'],
            },
            defaultColor: FigureColors.black,
          );
        }
        return const FigurePlacementSpec(
          zones: [FigureZone.hipLeft, FigureZone.hipRight],
          piecesByZone: {
            FigureZone.hipLeft: ['weightpocket_hip_front'],
            FigureZone.hipRight: ['weightpocket_hip_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.gearPocket:
        switch (attributes[_pocketMount]) {
          case 'thigh':
            return const FigurePlacementSpec(
              zones: [FigureZone.thighLeft, FigureZone.thighRight],
              piecesByZone: {
                FigureZone.thighLeft: ['pocket_thigh_front'],
                FigureZone.thighRight: ['pocket_thigh_front'],
              },
              defaultColor: FigureColors.black,
            );
          case 'waist_belt':
            return const FigurePlacementSpec(
              zones: [FigureZone.waist],
              piecesByZone: {FigureZone.waist: ['pocket_waist_front']},
              defaultColor: FigureColors.black,
            );
          default:
            return const FigurePlacementSpec(
              zones: [FigureZone.hipLeft, FigureZone.hipRight],
              piecesByZone: {
                FigureZone.hipLeft: ['pocket_hip_front'],
                FigureZone.hipRight: ['pocket_hip_front'],
              },
              defaultColor: FigureColors.black,
            );
        }
      case EquipmentType.wetsuit:
        return const FigurePlacementSpec(
          zones: [FigureZone.suit],
          piecesByZone: {FigureZone.suit: ['wetsuit_front', 'wetsuit_back']},
          defaultColor: FigureColors.darkBlue,
        );
      case EquipmentType.drysuit:
        return const FigurePlacementSpec(
          zones: [FigureZone.suit],
          piecesByZone: {FigureZone.suit: ['drysuit_front', 'drysuit_back']},
          defaultColor: FigureColors.darkGrey,
        );
      case EquipmentType.undersuit:
        return const FigurePlacementSpec(
          zones: [FigureZone.underlayer],
          piecesByZone: {
            FigureZone.underlayer: ['undersuit_front', 'undersuit_back'],
          },
          defaultColor: FigureColors.midGrey,
        );
      case EquipmentType.baselayer:
        return const FigurePlacementSpec(
          zones: [FigureZone.underlayer],
          piecesByZone: {
            FigureZone.underlayer: ['baselayer_front', 'baselayer_back'],
          },
          defaultColor: FigureColors.lightGrey,
        );
      case EquipmentType.rashGuard:
        // Underlayer first: the canonical order places a rash guard before
        // the suits, so preferring the suit zone would steal it from a
        // wetsuit in the same set.
        return const FigurePlacementSpec(
          zones: [FigureZone.underlayer, FigureZone.suit],
          piecesByZone: {
            FigureZone.suit: ['rashguard_front', 'rashguard_back'],
            FigureZone.underlayer: ['rashguard_front', 'rashguard_back'],
          },
          defaultColor: FigureColors.darkBlue,
        );
      case EquipmentType.hood:
        return const FigurePlacementSpec(
          zones: [FigureZone.head],
          piecesByZone: {FigureZone.head: ['hood_front']},
          defaultColor: FigureColors.black,
        );
      case EquipmentType.gloves:
        return const FigurePlacementSpec(
          zones: [FigureZone.hands],
          piecesByZone: {FigureZone.hands: ['gloves_front']},
          defaultColor: FigureColors.black,
        );
      case EquipmentType.boots:
        return const FigurePlacementSpec(
          zones: [FigureZone.feet],
          piecesByZone: {FigureZone.feet: ['boots_front']},
          defaultColor: FigureColors.black,
        );
      case EquipmentType.fins:
        return const FigurePlacementSpec(
          zones: [FigureZone.fins],
          piecesByZone: {FigureZone.fins: ['fins_front']},
          defaultColor: FigureColors.black,
        );
      case EquipmentType.mask:
        return const FigurePlacementSpec(
          zones: [FigureZone.face],
          piecesByZone: {FigureZone.face: ['mask_front']},
          defaultColor: FigureColors.black,
        );
      case EquipmentType.snorkel:
        return const FigurePlacementSpec(
          zones: [FigureZone.maskStrap],
          piecesByZone: {FigureZone.maskStrap: ['snorkel_front']},
          defaultColor: FigureColors.black,
        );
      case EquipmentType.computer:
        return switch (attributes[_mount]) {
          'console' => const FigurePlacementSpec(
              zones: [FigureZone.console],
              piecesByZone: {FigureZone.console: ['computer_console_front']},
              defaultColor: FigureColors.black,
            ),
          'hud' => const FigurePlacementSpec(
              zones: [FigureZone.hud],
              piecesByZone: {FigureZone.hud: ['computer_hud_front']},
              defaultColor: FigureColors.black,
            ),
          _ => const FigurePlacementSpec(
              zones: [FigureZone.wristLeft, FigureZone.wristRight],
              piecesByZone: {
                FigureZone.wristLeft: ['computer_wrist_front'],
                FigureZone.wristRight: ['computer_wrist_front'],
              },
              defaultColor: FigureColors.black,
            ),
        };
      case EquipmentType.instrument:
        final wristFirst = attributes[_mount] == 'wrist';
        return FigurePlacementSpec(
          zones: wristFirst
              ? const [FigureZone.wristLeft, FigureZone.wristRight, FigureZone.console]
              : const [FigureZone.console, FigureZone.wristLeft, FigureZone.wristRight],
          piecesByZone: const {
            FigureZone.console: ['computer_console_front'],
            FigureZone.wristLeft: ['computer_wrist_front'],
            FigureZone.wristRight: ['computer_wrist_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.compass:
        if (attributes[_mount] == 'console') {
          return const FigurePlacementSpec(
            zones: [FigureZone.console],
            piecesByZone: {FigureZone.console: ['computer_console_front']},
            defaultColor: FigureColors.black,
          );
        }
        return const FigurePlacementSpec(
          zones: [FigureZone.wristRight, FigureZone.wristLeft],
          piecesByZone: {
            FigureZone.wristRight: ['compass_wrist_front'],
            FigureZone.wristLeft: ['compass_wrist_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.tank:
        return FigurePlacementSpec(
          zones: context.sidemountRig
              ? const [
                  FigureZone.sidemountLeft,
                  FigureZone.sidemountRight,
                  FigureZone.stageLeft,
                  FigureZone.stageRight,
                ]
              : const [FigureZone.backTank, FigureZone.stageLeft, FigureZone.stageRight],
          piecesByZone: const {
            FigureZone.backTank: ['tank_single_back'],
            FigureZone.sidemountLeft: ['tank_sidemount_back'],
            FigureZone.sidemountRight: ['tank_sidemount_back'],
            FigureZone.stageLeft: ['tank_stage_front'],
            FigureZone.stageRight: ['tank_stage_front'],
          },
          defaultColor: attributes[EquipmentAttrKeys.tankMaterial] == 'steel'
              ? FigureColors.steel
              : FigureColors.aluminium,
        );
      case EquipmentType.rebreather:
        return switch (attributes[_mountConfiguration]) {
          'chest' => const FigurePlacementSpec(
              zones: [FigureZone.chest],
              piecesByZone: {FigureZone.chest: ['rebreather_chest_front']},
              defaultColor: FigureColors.black,
            ),
          'sidemount' => const FigurePlacementSpec(
              zones: [FigureZone.sidemountLeft],
              piecesByZone: {
                FigureZone.sidemountLeft: ['rebreather_sidemount_back'],
              },
              defaultColor: FigureColors.black,
            ),
          _ => const FigurePlacementSpec(
              zones: [FigureZone.backTank],
              piecesByZone: {FigureZone.backTank: ['rebreather_back_back']},
              defaultColor: FigureColors.black,
              occupies: 2,
            ),
        };
      case EquipmentType.weights:
        return switch (attributes[EquipmentAttrKeys.weightStyle]) {
          'integrated' => const FigurePlacementSpec(
              zones: [FigureZone.hipLeft, FigureZone.hipRight],
              piecesByZone: {
                FigureZone.hipLeft: ['weights_integrated_front'],
                FigureZone.hipRight: ['weights_integrated_front'],
              },
              defaultColor: FigureColors.black,
            ),
          'trim' => const FigurePlacementSpec(
              zones: [FigureZone.trimLeft, FigureZone.trimRight],
              piecesByZone: {
                FigureZone.trimLeft: ['weights_trim_back'],
                FigureZone.trimRight: ['weights_trim_back'],
              },
              defaultColor: FigureColors.black,
            ),
          'ankle' => const FigurePlacementSpec(
              zones: [FigureZone.ankles],
              piecesByZone: {FigureZone.ankles: ['weights_ankle_front']},
              defaultColor: FigureColors.black,
            ),
          _ => const FigurePlacementSpec(
              zones: [FigureZone.waist],
              piecesByZone: {FigureZone.waist: ['weights_belt_front']},
              defaultColor: FigureColors.black,
            ),
        };
      case EquipmentType.light:
        return const FigurePlacementSpec(
          zones: [FigureZone.handLeft, FigureZone.chestClipLeft, FigureZone.chestClipRight],
          piecesByZone: {
            FigureZone.handLeft: ['light_hand_front'],
            FigureZone.chestClipLeft: ['light_clip_front'],
            FigureZone.chestClipRight: ['light_clip_front'],
          },
          defaultColor: FigureColors.yellow,
        );
      case EquipmentType.camera:
        return const FigurePlacementSpec(
          zones: [FigureZone.handRight, FigureZone.handLeft],
          piecesByZone: {
            FigureZone.handRight: ['camera_hand_front'],
            FigureZone.handLeft: ['camera_hand_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.housing:
        return const FigurePlacementSpec(
          zones: [FigureZone.handRight],
          piecesByZone: {FigureZone.handRight: ['housing_hand_front']},
          defaultColor: FigureColors.black,
        );
      case EquipmentType.strobe:
        return const FigurePlacementSpec(
          zones: [FigureZone.cameraArm],
          piecesByZone: {FigureZone.cameraArm: ['strobe_arm_front']},
          defaultColor: FigureColors.black,
        );
      case EquipmentType.smb:
        return const FigurePlacementSpec(
          zones: [FigureZone.buttDRing, FigureZone.thighLeft],
          piecesByZone: {
            FigureZone.buttDRing: ['smb_butt_back'],
            FigureZone.thighLeft: ['smb_thigh_front'],
          },
          defaultColor: FigureColors.orange,
        );
      case EquipmentType.reel:
        return const FigurePlacementSpec(
          zones: [FigureZone.buttDRing, FigureZone.hipRight],
          piecesByZone: {
            FigureZone.buttDRing: ['reel_butt_back'],
            FigureZone.hipRight: ['reel_hip_front'],
          },
          defaultColor: FigureColors.black,
        );
      case EquipmentType.knife:
        return const FigurePlacementSpec(
          zones: [FigureZone.calfLeft, FigureZone.hipLeft],
          piecesByZone: {
            FigureZone.calfLeft: ['knife_calf_front'],
            FigureZone.hipLeft: ['knife_hip_front'],
          },
          defaultColor: FigureColors.metal,
        );
      case EquipmentType.dpv:
        return const FigurePlacementSpec(
          zones: [FigureZone.dpv],
          piecesByZone: {FigureZone.dpv: ['dpv_front']},
          defaultColor: FigureColors.black,
        );
      case EquipmentType.hose:
      case EquipmentType.tankBand:
        return const FigurePlacementSpec(zones: [], defaultColor: FigureColors.black);
      case EquipmentType.tool:
      case EquipmentType.o2Cell:
      case EquipmentType.battery:
        return const FigurePlacementSpec(zones: [], defaultColor: FigureColors.metal);
      case EquipmentType.other:
        return const FigurePlacementSpec(zones: [], defaultColor: FigureColors.midGrey);
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/figure/domain/figure_placement_test.dart`
Expected: PASS, 9 tests. The switch is exhaustive over `EquipmentType`; if the analyzer reports a missing case, a type was added to the enum and needs a row here.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/figure test/features/equipment/figure
git add lib/features/equipment/figure/domain/figure_placement.dart test/features/equipment/figure/domain/figure_placement_test.dart
git commit -m "feat(figure): placement table from equipment type to body zone

Part of #2326"
```

---

### Artwork batches (Tasks 4 to 6)

The three artwork tasks share one method. For each piece: add its manifest
entry, write its SVG, then run the generator, its verify mode, and the
artwork test. Every SVG below is the complete file; shapes are listed in the
order the manifest's `roles` array names them. Coordinates are figure space.
The mannequin for reference: head circle (100, 42) r 22; neck 92 to 108 by
60 to 74; torso 68 to 132 by 72 to 200 with rx 16; left arm from the
shoulder (70, 82) to the wrist (46, 190); hands at (40, 214) and (160, 214)
r 11; legs from the hips (78, 196) and (122, 196) to (70, 340) and
(130, 340); feet 338 to 358.

Pieces authored for a mirrored zone are drawn at the unmirrored twin's
position (the left wrist, the left hip, the viewer-left sidemount slot) and
are flipped by the painter.

To look at a batch before committing it, render a contact sheet: write a
scratch SVG that wraps `body_front.svg`'s shapes and each new piece's shapes
in fill colours, then `qlmanage -t -s 800 -o <scratch dir> sheet.svg` and
open the PNG. The Browser pane cannot render a file outside the project, so
Quick Look is the tool.

### Task 4: Artwork batch A, head, exposure, hands and feet

**Files:**
- Modify: `tool/figure/manifest.json`
- Create: 19 SVGs under `tool/figure/` listed below
- Modify (generated): `lib/features/equipment/figure/artwork/figure_artwork.g.dart`

**Interfaces:**
- Produces piece ids: `hood_front`, `mask_front`, `snorkel_front`, `computer_hud_front`, `regulator_mouth_front`, `regulator_octo_front`, `wetsuit_front`, `wetsuit_back`, `drysuit_front`, `drysuit_back`, `undersuit_front`, `undersuit_back`, `baselayer_front`, `baselayer_back`, `rashguard_front`, `rashguard_back`, `gloves_front`, `boots_front`, `fins_front`.

- [ ] **Step 1: Add the manifest entries**

Append these objects to the `pieces` array in `tool/figure/manifest.json`:

```json
{"id": "hood_front", "view": "front", "layer": 100, "roles": ["itemColor", "itemColor", "body"]},
{"id": "mask_front", "view": "front", "layer": 100, "roles": ["itemColor", "gearLight", "gearLight", "itemShade", "itemShade"]},
{"id": "snorkel_front", "view": "front", "layer": 100, "roles": ["itemColor", "itemShade"]},
{"id": "computer_hud_front", "view": "front", "layer": 101, "roles": ["itemColor", "gearLight"]},
{"id": "regulator_mouth_front", "view": "front", "layer": 70, "roles": ["itemColor", "itemShade", "gearDark"]},
{"id": "regulator_octo_front", "view": "front", "layer": 70, "roles": ["itemColor", "gearDark"]},
{"id": "wetsuit_front", "view": "front", "layer": 20, "roles": ["itemColor", "itemColor", "itemColor", "itemColor", "itemColor", "itemShade"]},
{"id": "wetsuit_back", "view": "back", "layer": 20, "roles": ["itemColor", "itemColor", "itemColor", "itemColor", "itemColor", "itemShade"]},
{"id": "drysuit_front", "view": "front", "layer": 20, "roles": ["itemColor", "itemColor", "itemColor", "itemColor", "itemColor", "gearDark", "metal", "metal"]},
{"id": "drysuit_back", "view": "back", "layer": 20, "roles": ["itemColor", "itemColor", "itemColor", "itemColor", "itemColor", "gearDark", "itemShade"]},
{"id": "undersuit_front", "view": "front", "layer": 10, "roles": ["itemColor", "itemColor", "itemColor", "itemColor", "itemColor"]},
{"id": "undersuit_back", "view": "back", "layer": 10, "roles": ["itemColor", "itemColor", "itemColor", "itemColor", "itemColor"]},
{"id": "baselayer_front", "view": "front", "layer": 10, "roles": ["itemColor", "itemColor", "itemColor", "itemColor", "itemColor"]},
{"id": "baselayer_back", "view": "back", "layer": 10, "roles": ["itemColor", "itemColor", "itemColor", "itemColor", "itemColor"]},
{"id": "rashguard_front", "view": "front", "layer": 20, "roles": ["itemColor", "itemColor", "itemColor"]},
{"id": "rashguard_back", "view": "back", "layer": 20, "roles": ["itemColor", "itemColor", "itemColor"]},
{"id": "gloves_front", "view": "front", "layer": 90, "roles": ["itemColor", "itemColor", "itemShade", "itemShade"]},
{"id": "boots_front", "view": "front", "layer": 110, "roles": ["itemColor", "itemColor", "itemShade", "itemShade"]},
{"id": "fins_front", "view": "front", "layer": 110, "roles": ["itemShade", "itemShade", "itemColor", "itemColor"]}
```

- [ ] **Step 2: Write the SVGs**

Every file starts with `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 400">` and ends with `</svg>`; only the shapes are shown.

`hood_front.svg` (hood over the head, a bib, then the face painted back in body tone):
```svg
  <circle cx="100" cy="42" r="25"/>
  <rect x="84" y="60" width="32" height="18" rx="6"/>
  <ellipse cx="100" cy="44" rx="14" ry="16"/>
```

`mask_front.svg`:
```svg
  <rect x="82" y="34" width="36" height="14" rx="5"/>
  <rect x="85" y="37" width="13" height="8" rx="2"/>
  <rect x="102" y="37" width="13" height="8" rx="2"/>
  <rect x="76" y="38" width="6" height="6"/>
  <rect x="118" y="38" width="6" height="6"/>
```

`snorkel_front.svg`:
```svg
  <rect x="124" y="28" width="6" height="40" rx="3"/>
  <rect x="112" y="60" width="14" height="6" rx="3"/>
```

`computer_hud_front.svg`:
```svg
  <rect x="116" y="30" width="10" height="4" rx="2"/>
  <rect x="124" y="27" width="6" height="8" rx="2"/>
```

`regulator_mouth_front.svg` (second stage, its cover, the hose to the right shoulder):
```svg
  <circle cx="100" cy="58" r="6"/>
  <circle cx="100" cy="58" r="3"/>
  <path d="M104 56 C118 50 128 56 130 74 L126 76 C124 60 116 56 104 62 Z"/>
```

`regulator_octo_front.svg`:
```svg
  <circle cx="120" cy="110" r="6"/>
  <path d="M124 106 C134 96 136 84 130 76 L126 78 C130 86 128 98 118 108 Z"/>
```

`wetsuit_front.svg` (torso, both arms, both legs, front zip):
```svg
  <rect x="68" y="72" width="64" height="128" rx="16"/>
  <path d="M70 82 L46 190 L60 194 L84 96 Z"/>
  <path d="M130 82 L154 190 L140 194 L116 96 Z"/>
  <path d="M78 196 L70 340 L94 340 L100 210 Z"/>
  <path d="M122 196 L130 340 L106 340 L100 210 Z"/>
  <rect x="96" y="76" width="8" height="120" rx="4"/>
```

`wetsuit_back.svg` (same five, back zip):
```svg
  <rect x="68" y="72" width="64" height="128" rx="16"/>
  <path d="M70 82 L46 190 L60 194 L84 96 Z"/>
  <path d="M130 82 L154 190 L140 194 L116 96 Z"/>
  <path d="M78 196 L70 340 L94 340 L100 210 Z"/>
  <path d="M122 196 L130 340 L106 340 L100 210 Z"/>
  <rect x="97" y="76" width="6" height="100" rx="3"/>
```

`drysuit_front.svg` (five body shapes, neck seal, inflator valve, shoulder dump):
```svg
  <rect x="68" y="72" width="64" height="128" rx="16"/>
  <path d="M70 82 L46 190 L60 194 L84 96 Z"/>
  <path d="M130 82 L154 190 L140 194 L116 96 Z"/>
  <path d="M78 196 L70 340 L94 340 L100 210 Z"/>
  <path d="M122 196 L130 340 L106 340 L100 210 Z"/>
  <ellipse cx="100" cy="74" rx="12" ry="4"/>
  <circle cx="112" cy="118" r="5"/>
  <circle cx="72" cy="90" r="4"/>
```

`drysuit_back.svg` (five body shapes, neck seal, diagonal zip):
```svg
  <rect x="68" y="72" width="64" height="128" rx="16"/>
  <path d="M70 82 L46 190 L60 194 L84 96 Z"/>
  <path d="M130 82 L154 190 L140 194 L116 96 Z"/>
  <path d="M78 196 L70 340 L94 340 L100 210 Z"/>
  <path d="M122 196 L130 340 L106 340 L100 210 Z"/>
  <ellipse cx="100" cy="74" rx="12" ry="4"/>
  <path d="M74 84 L128 118 L126 122 L72 88 Z"/>
```

`undersuit_front.svg`, `undersuit_back.svg`, `baselayer_front.svg`, `baselayer_back.svg` (four files, identical shapes; the type's default colour tells them apart):
```svg
  <rect x="68" y="72" width="64" height="128" rx="16"/>
  <path d="M70 82 L46 190 L60 194 L84 96 Z"/>
  <path d="M130 82 L154 190 L140 194 L116 96 Z"/>
  <path d="M78 196 L70 340 L94 340 L100 210 Z"/>
  <path d="M122 196 L130 340 L106 340 L100 210 Z"/>
```

`rashguard_front.svg` and `rashguard_back.svg` (torso and short sleeves, identical files):
```svg
  <rect x="68" y="72" width="64" height="128" rx="16"/>
  <path d="M70 82 L60 118 L74 122 L84 96 Z"/>
  <path d="M130 82 L140 118 L126 122 L116 96 Z"/>
```

`gloves_front.svg` (two gloves, two cuffs):
```svg
  <circle cx="40" cy="214" r="12"/>
  <circle cx="160" cy="214" r="12"/>
  <rect x="44" y="188" width="16" height="8" rx="3"/>
  <rect x="140" y="188" width="16" height="8" rx="3"/>
```

`boots_front.svg` (two boots, two soles):
```svg
  <rect x="66" y="336" width="30" height="24" rx="6"/>
  <rect x="104" y="336" width="30" height="24" rx="6"/>
  <rect x="66" y="354" width="30" height="6" rx="2"/>
  <rect x="104" y="354" width="30" height="6" rx="2"/>
```

`fins_front.svg` (two foot pockets, two blades):
```svg
  <rect x="66" y="346" width="30" height="16" rx="5"/>
  <rect x="104" y="346" width="30" height="16" rx="5"/>
  <path d="M62 360 L100 360 L96 396 L52 392 Z"/>
  <path d="M100 360 L138 360 L148 392 L104 396 Z"/>
```

- [ ] **Step 3: Generate, verify, and test**

Run: `python3 tool/build_figure_artwork.py && python3 tool/build_figure_artwork.py --verify && flutter test test/features/equipment/figure/artwork/figure_artwork_test.dart`
Expected: `wrote ... (21 pieces)`, `OK 21 pieces current`, tests PASS. A `FAIL <id>: N shapes but M roles` message means a manifest roles array and its SVG disagree; count the shapes again.

- [ ] **Step 4: Look at the batch**

Render the contact sheet as described above and confirm at 24 px and at 96 px that the hood reads as a hood over a face, the mask has two lenses, and the fins extend past the feet. Fix a shape by editing its SVG and re-running Step 3.

- [ ] **Step 5: Commit**

```bash
git add tool/figure lib/features/equipment/figure/artwork
git commit -m "feat(figure): artwork for head, exposure suits, hands and feet

Part of #2326"
```

---

### Task 5: Artwork batch B, buoyancy, pockets and weights

**Files:**
- Modify: `tool/figure/manifest.json`
- Create: 14 SVGs under `tool/figure/`
- Modify (generated): `lib/features/equipment/figure/artwork/figure_artwork.g.dart`

**Interfaces:**
- Produces piece ids: `bcd_jacket_front`, `bcd_harness_front`, `bcd_wing_back`, `bcd_sidemount_front`, `bcd_sidemount_back`, `backplate_back`, `pocket_hip_front`, `pocket_thigh_front`, `pocket_waist_front`, `weightpocket_hip_front`, `weights_belt_front`, `weights_integrated_front`, `weights_trim_back`, `weights_ankle_front`.

- [ ] **Step 1: Add the manifest entries**

```json
{"id": "bcd_jacket_front", "view": "front", "layer": 40, "roles": ["itemColor", "itemShade", "itemShade", "itemShade", "gearDark", "metal"]},
{"id": "bcd_harness_front", "view": "front", "layer": 40, "roles": ["itemColor", "itemColor", "itemColor", "itemColor", "metal", "metal", "metal"]},
{"id": "bcd_wing_back", "view": "back", "layer": 58, "roles": ["itemColor", "itemShade"]},
{"id": "bcd_sidemount_front", "view": "front", "layer": 40, "roles": ["itemColor", "itemColor", "itemColor", "itemColor", "metal", "metal", "metal"]},
{"id": "bcd_sidemount_back", "view": "back", "layer": 58, "roles": ["itemColor", "itemShade", "itemShade", "metal", "metal"]},
{"id": "backplate_back", "view": "back", "layer": 55, "roles": ["itemColor", "itemShade", "itemShade"]},
{"id": "pocket_hip_front", "view": "front", "layer": 30, "roles": ["itemColor", "itemShade"]},
{"id": "pocket_thigh_front", "view": "front", "layer": 30, "roles": ["itemColor", "itemShade"]},
{"id": "pocket_waist_front", "view": "front", "layer": 30, "roles": ["itemColor", "itemShade"]},
{"id": "weightpocket_hip_front", "view": "front", "layer": 30, "roles": ["itemColor", "metal"]},
{"id": "weights_belt_front", "view": "front", "layer": 80, "roles": ["itemColor", "gearDark", "gearDark", "metal"]},
{"id": "weights_integrated_front", "view": "front", "layer": 80, "roles": ["itemColor", "gearLight"]},
{"id": "weights_trim_back", "view": "back", "layer": 62, "roles": ["itemColor", "itemShade"]},
{"id": "weights_ankle_front", "view": "front", "layer": 80, "roles": ["itemColor", "itemColor"]}
```

- [ ] **Step 2: Write the SVGs**

`bcd_jacket_front.svg` (jacket, two shoulder straps, cummerbund, inflator hose, buckle):
```svg
  <path d="M74 80 L126 80 L130 170 L70 170 Z"/>
  <rect x="78" y="76" width="10" height="90" rx="4"/>
  <rect x="112" y="76" width="10" height="90" rx="4"/>
  <rect x="72" y="150" width="56" height="14" rx="3"/>
  <rect x="78" y="96" width="6" height="40" rx="3"/>
  <rect x="94" y="154" width="12" height="6" rx="1"/>
```

`bcd_harness_front.svg` (two shoulder straps, waist strap, crotch strap, two D-rings, buckle):
```svg
  <rect x="78" y="76" width="10" height="110" rx="4"/>
  <rect x="112" y="76" width="10" height="110" rx="4"/>
  <rect x="72" y="176" width="56" height="10" rx="3"/>
  <rect x="97" y="184" width="6" height="24" rx="3"/>
  <circle cx="83" cy="100" r="4"/>
  <circle cx="117" cy="100" r="4"/>
  <rect x="94" y="178" width="12" height="6" rx="1"/>
```

`bcd_wing_back.svg` (bladder, centre shade):
```svg
  <path d="M74 84 C60 110 60 150 76 176 L124 176 C140 150 140 110 126 84 Z"/>
  <rect x="92" y="92" width="16" height="78" rx="8"/>
```

`bcd_sidemount_front.svg` (as the harness, D-rings lower on the chest):
```svg
  <rect x="78" y="76" width="10" height="110" rx="4"/>
  <rect x="112" y="76" width="10" height="110" rx="4"/>
  <rect x="72" y="176" width="56" height="10" rx="3"/>
  <rect x="97" y="184" width="6" height="24" rx="3"/>
  <circle cx="83" cy="120" r="4"/>
  <circle cx="117" cy="120" r="4"/>
  <rect x="94" y="178" width="12" height="6" rx="1"/>
```

`bcd_sidemount_back.svg` (butt plate, two bungees, two rails):
```svg
  <rect x="82" y="176" width="36" height="22" rx="6"/>
  <rect x="70" y="96" width="6" height="70" rx="3"/>
  <rect x="124" y="96" width="6" height="70" rx="3"/>
  <rect x="84" y="200" width="6" height="10" rx="2"/>
  <rect x="110" y="200" width="6" height="10" rx="2"/>
```

`backplate_back.svg` (plate, two slots):
```svg
  <path d="M84 84 L116 84 L120 190 L80 190 Z"/>
  <rect x="96" y="96" width="8" height="60" rx="4"/>
  <rect x="96" y="164" width="8" height="12" rx="4"/>
```

`pocket_hip_front.svg`:
```svg
  <rect x="62" y="196" width="24" height="22" rx="4"/>
  <rect x="62" y="196" width="24" height="7" rx="3"/>
```

`pocket_thigh_front.svg`:
```svg
  <rect x="66" y="238" width="24" height="26" rx="4"/>
  <rect x="66" y="238" width="24" height="7" rx="3"/>
```

`pocket_waist_front.svg`:
```svg
  <rect x="88" y="190" width="24" height="18" rx="4"/>
  <rect x="88" y="190" width="24" height="6" rx="3"/>
```

`weightpocket_hip_front.svg` (pouch, handle):
```svg
  <rect x="62" y="198" width="22" height="20" rx="4"/>
  <rect x="66" y="200" width="14" height="4" rx="2"/>
```

`weights_belt_front.svg` (belt, two blocks, buckle):
```svg
  <rect x="70" y="194" width="60" height="9" rx="2"/>
  <rect x="76" y="191" width="10" height="15" rx="2"/>
  <rect x="114" y="191" width="10" height="15" rx="2"/>
  <rect x="95" y="193" width="10" height="11" rx="1"/>
```

`weights_integrated_front.svg` (pouch, handle):
```svg
  <rect x="64" y="198" width="20" height="18" rx="4"/>
  <rect x="68" y="200" width="12" height="4" rx="2"/>
```

`weights_trim_back.svg` (pocket, strap; authored at the viewer-left trim slot):
```svg
  <rect x="66" y="168" width="20" height="16" rx="4"/>
  <rect x="64" y="174" width="24" height="4"/>
```

`weights_ankle_front.svg`:
```svg
  <rect x="70" y="326" width="24" height="10" rx="3"/>
  <rect x="106" y="326" width="24" height="10" rx="3"/>
```

- [ ] **Step 3: Generate, verify, and test**

Run: `python3 tool/build_figure_artwork.py && python3 tool/build_figure_artwork.py --verify && flutter test test/features/equipment/figure/artwork/figure_artwork_test.dart`
Expected: `wrote ... (35 pieces)`, `OK 35 pieces current`, tests PASS.

- [ ] **Step 4: Look at the batch and commit**

Render the contact sheet, confirm the jacket covers the torso and the wing reads as a bladder around the back, then:

```bash
git add tool/figure lib/features/equipment/figure/artwork
git commit -m "feat(figure): artwork for buoyancy, pockets and weights

Part of #2326"
```

---

### Task 6: Artwork batch C, tanks, rebreathers, instruments and accessories, with the completeness test

**Files:**
- Modify: `tool/figure/manifest.json`
- Create: 24 SVGs under `tool/figure/`
- Modify (generated): `lib/features/equipment/figure/artwork/figure_artwork.g.dart`
- Test: `test/features/equipment/figure/artwork/figure_artwork_completeness_test.dart`

**Interfaces:**
- Consumes: `FigurePlacement.forType`, `FigurePlacement.variantAttributeSets`, `FigureContext` (Task 3), `figureArtwork` (Task 2).
- Produces piece ids: `tank_single_back`, `tank_doubles_back`, `tank_sidemount_back`, `tank_stage_front`, `firststage_back`, `transmitter_back`, `rebreather_back_back`, `rebreather_chest_front`, `rebreather_sidemount_back`, `computer_wrist_front`, `computer_console_front`, `compass_wrist_front`, `light_hand_front`, `light_clip_front`, `camera_hand_front`, `housing_hand_front`, `strobe_arm_front`, `smb_butt_back`, `smb_thigh_front`, `reel_butt_back`, `reel_hip_front`, `knife_calf_front`, `knife_hip_front`, `dpv_front`.

- [ ] **Step 1: Write the failing completeness test**

```dart
// test/features/equipment/figure/artwork/figure_artwork_completeness_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/artwork/figure_artwork.g.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';

/// The placement table names artwork by id; the generated map is where the
/// ids come true. A type whose piece is missing would draw nothing and say
/// nothing, so this is the check that closes the loop. The Python generator
/// cannot do it because the table lives in Dart.
void main() {
  test('every piece the placement table names exists, plus the doubles tank', () {
    final named = <String>{'tank_doubles_back'};
    for (final type in EquipmentType.values) {
      for (final attributes in FigurePlacement.variantAttributeSets) {
        for (final sidemount in [false, true]) {
          final spec = FigurePlacement.forType(
            type,
            attributes: attributes,
            context: FigureContext(sidemountRig: sidemount),
          );
          for (final pieces in spec.piecesByZone.values) {
            named.addAll(pieces);
          }
        }
      }
    }
    final missing = named.where((id) => !figureArtwork.containsKey(id)).toList()..sort();
    expect(missing, isEmpty, reason: 'add these to tool/figure and regenerate');
  });

  test('every piece a zone names is drawn on that zone\'s view or its pair', () {
    // A zone's pieces may span both views (a BCD has a harness front and a
    // wing back), but a piece must belong to one of the two views.
    for (final piece in figureArtwork.values) {
      expect(FigureView.values, contains(piece.view), reason: piece.id);
    }
  });

  test('no piece in the artwork is unreachable from the table', () {
    final reachable = <String>{'body_front', 'body_back', 'tank_doubles_back'};
    for (final type in EquipmentType.values) {
      for (final attributes in FigurePlacement.variantAttributeSets) {
        for (final sidemount in [false, true]) {
          final spec = FigurePlacement.forType(type,
              attributes: attributes, context: FigureContext(sidemountRig: sidemount));
          for (final pieces in spec.piecesByZone.values) {
            reachable.addAll(pieces);
          }
        }
      }
    }
    final orphans = figureArtwork.keys.where((id) => !reachable.contains(id)).toList()..sort();
    expect(orphans, isEmpty, reason: 'artwork nothing places: remove it or place it');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/figure/artwork/figure_artwork_completeness_test.dart`
Expected: FAIL on the first test with the 24 ids of this batch listed as missing.

- [ ] **Step 3: Add the manifest entries**

```json
{"id": "tank_single_back", "view": "back", "layer": 60, "roles": ["itemColor", "gearLight", "gearDark", "gearDark", "gearDark"]},
{"id": "tank_doubles_back", "view": "back", "layer": 60, "roles": ["itemColor", "itemColor", "gearLight", "gearLight", "metal", "metal", "gearDark", "gearDark"]},
{"id": "tank_sidemount_back", "view": "back", "layer": 60, "roles": ["itemColor", "gearLight", "metal", "gearDark"]},
{"id": "tank_stage_front", "view": "front", "layer": 50, "roles": ["itemColor", "gearLight", "metal", "metal", "metal"]},
{"id": "firststage_back", "view": "back", "layer": 62, "roles": ["itemColor", "metal", "metal", "gearDark", "gearDark"]},
{"id": "transmitter_back", "view": "back", "layer": 63, "roles": ["itemColor", "metal"]},
{"id": "rebreather_back_back", "view": "back", "layer": 60, "roles": ["itemColor", "itemShade", "metal", "metal", "gearDark", "gearDark"]},
{"id": "rebreather_chest_front", "view": "front", "layer": 50, "roles": ["itemColor", "itemShade", "gearDark", "gearDark", "gearDark"]},
{"id": "rebreather_sidemount_back", "view": "back", "layer": 60, "roles": ["itemColor", "itemShade", "gearDark"]},
{"id": "computer_wrist_front", "view": "front", "layer": 90, "roles": ["gearDark", "itemColor", "gearLight"]},
{"id": "computer_console_front", "view": "front", "layer": 90, "roles": ["gearDark", "itemColor", "gearLight", "gearLight"]},
{"id": "compass_wrist_front", "view": "front", "layer": 90, "roles": ["gearDark", "itemColor", "gearLight", "gearDark"]},
{"id": "light_hand_front", "view": "front", "layer": 90, "roles": ["gearDark", "itemColor", "gearLight", "itemShade"]},
{"id": "light_clip_front", "view": "front", "layer": 50, "roles": ["itemColor", "itemShade", "metal"]},
{"id": "camera_hand_front", "view": "front", "layer": 90, "roles": ["itemColor", "gearDark", "gearLight", "itemShade"]},
{"id": "housing_hand_front", "view": "front", "layer": 89, "roles": ["itemColor", "gearDark", "itemShade", "itemShade"]},
{"id": "strobe_arm_front", "view": "front", "layer": 91, "roles": ["gearDark", "itemColor", "gearLight"]},
{"id": "smb_butt_back", "view": "back", "layer": 80, "roles": ["itemColor", "gearDark", "metal"]},
{"id": "smb_thigh_front", "view": "front", "layer": 80, "roles": ["itemColor", "gearDark"]},
{"id": "reel_butt_back", "view": "back", "layer": 80, "roles": ["itemColor", "gearLight", "metal"]},
{"id": "reel_hip_front", "view": "front", "layer": 80, "roles": ["itemColor", "gearLight", "metal"]},
{"id": "knife_calf_front", "view": "front", "layer": 80, "roles": ["itemShade", "itemColor", "gearDark", "gearDark"]},
{"id": "knife_hip_front", "view": "front", "layer": 80, "roles": ["itemShade", "itemColor"]},
{"id": "dpv_front", "view": "front", "layer": 85, "roles": ["itemColor", "itemShade", "gearDark", "gearDark"]}
```

- [ ] **Step 4: Write the SVGs**

`tank_single_back.svg` (cylinder, highlight, boot, two bands):
```svg
  <rect x="86" y="80" width="28" height="110" rx="12"/>
  <rect x="91" y="86" width="6" height="96" rx="3"/>
  <rect x="86" y="184" width="28" height="10" rx="4"/>
  <rect x="82" y="120" width="36" height="6" rx="2"/>
  <rect x="82" y="156" width="36" height="6" rx="2"/>
```

`tank_doubles_back.svg` (two cylinders, two highlights, manifold, isolator, two bands):
```svg
  <rect x="70" y="80" width="26" height="110" rx="11"/>
  <rect x="104" y="80" width="26" height="110" rx="11"/>
  <rect x="75" y="86" width="5" height="96" rx="2"/>
  <rect x="109" y="86" width="5" height="96" rx="2"/>
  <rect x="82" y="72" width="36" height="6" rx="3"/>
  <circle cx="100" cy="75" r="4"/>
  <rect x="66" y="120" width="68" height="6" rx="2"/>
  <rect x="66" y="156" width="68" height="6" rx="2"/>
```

`tank_sidemount_back.svg` (cylinder, highlight, valve, bungee; authored at the viewer-left slot):
```svg
  <rect x="44" y="110" width="26" height="100" rx="11"/>
  <rect x="49" y="116" width="5" height="86" rx="2"/>
  <rect x="54" y="102" width="6" height="10" rx="2"/>
  <rect x="40" y="124" width="34" height="4" rx="2"/>
```

`tank_stage_front.svg` (cylinder, highlight, valve, top clip, bottom clip):
```svg
  <rect x="50" y="120" width="22" height="84" rx="10"/>
  <rect x="54" y="126" width="4" height="70" rx="2"/>
  <rect x="58" y="112" width="6" height="10" rx="2"/>
  <circle cx="61" cy="116" r="3"/>
  <circle cx="61" cy="200" r="3"/>
```

`firststage_back.svg` (body, two ports, two hoses over the shoulders):
```svg
  <rect x="92" y="66" width="16" height="14" rx="3"/>
  <circle cx="90" cy="73" r="3"/>
  <circle cx="110" cy="73" r="3"/>
  <path d="M92 72 C78 72 72 84 74 96 L70 96 C68 82 76 68 92 68 Z"/>
  <path d="M108 72 C122 72 128 84 126 96 L130 96 C132 82 124 68 108 68 Z"/>
```

`transmitter_back.svg`:
```svg
  <rect x="112" y="60" width="8" height="16" rx="3"/>
  <circle cx="116" cy="60" r="4"/>
```

`rebreather_back_back.svg` (case, lid, two cylinders, two loop hoses):
```svg
  <rect x="72" y="76" width="56" height="120" rx="12"/>
  <rect x="72" y="76" width="56" height="18" rx="8"/>
  <rect x="62" y="100" width="12" height="80" rx="5"/>
  <rect x="126" y="100" width="12" height="80" rx="5"/>
  <path d="M84 76 C74 66 66 74 68 90 L64 90 C62 70 74 60 88 72 Z"/>
  <path d="M116 76 C126 66 134 74 132 90 L136 90 C138 70 126 60 112 72 Z"/>
```

`rebreather_chest_front.svg` (case, lid, two loop hoses, mouthpiece):
```svg
  <rect x="74" y="96" width="52" height="56" rx="10"/>
  <rect x="74" y="96" width="52" height="12" rx="6"/>
  <path d="M78 96 C74 80 84 66 96 62 L98 66 C88 70 80 82 82 96 Z"/>
  <path d="M122 96 C126 80 116 66 104 62 L102 66 C112 70 120 82 118 96 Z"/>
  <circle cx="100" cy="60" r="5"/>
```

`rebreather_sidemount_back.svg` (case, lid, hose; authored at the viewer-left slot):
```svg
  <rect x="40" y="104" width="30" height="110" rx="10"/>
  <rect x="40" y="104" width="30" height="14" rx="6"/>
  <path d="M56 104 C56 90 70 80 84 76 L86 80 C74 84 62 92 60 104 Z"/>
```

`computer_wrist_front.svg` (strap, case, screen; left wrist):
```svg
  <rect x="34" y="190" width="22" height="12" rx="3"/>
  <rect x="37" y="188" width="16" height="16" rx="3"/>
  <rect x="40" y="191" width="10" height="10" rx="1"/>
```

`computer_console_front.svg` (hose from the left hip, console, screen, gauge):
```svg
  <path d="M74 190 C60 200 54 214 58 226 L62 226 C58 214 64 202 76 194 Z"/>
  <rect x="52" y="222" width="20" height="30" rx="5"/>
  <rect x="55" y="226" width="14" height="12" rx="2"/>
  <circle cx="62" cy="244" r="5"/>
```

`compass_wrist_front.svg` (strap, bezel, card, needle):
```svg
  <rect x="34" y="191" width="22" height="10" rx="3"/>
  <circle cx="45" cy="196" r="9"/>
  <circle cx="45" cy="196" r="6"/>
  <path d="M45 191 L47 196 L45 201 L43 196 Z"/>
```

`light_hand_front.svg` (Goodman plate, head, lens, body):
```svg
  <rect x="30" y="206" width="20" height="8" rx="3"/>
  <circle cx="28" cy="234" r="10"/>
  <circle cx="28" cy="234" r="6"/>
  <rect x="24" y="214" width="8" height="14" rx="3"/>
```

`light_clip_front.svg` (body, head, clip; left chest D-ring):
```svg
  <rect x="76" y="92" width="8" height="26" rx="3"/>
  <rect x="74" y="88" width="12" height="6" rx="2"/>
  <circle cx="80" cy="120" r="3"/>
```

`camera_hand_front.svg` (body, lens, glass, grip; left hand):
```svg
  <rect x="12" y="226" width="34" height="24" rx="4"/>
  <circle cx="29" cy="238" r="8"/>
  <circle cx="29" cy="238" r="5"/>
  <rect x="12" y="226" width="8" height="24" rx="3"/>
```

`housing_hand_front.svg` (shell, port, two handles):
```svg
  <rect x="8" y="220" width="44" height="36" rx="6"/>
  <circle cx="29" cy="238" r="12"/>
  <rect x="4" y="224" width="6" height="28" rx="2"/>
  <rect x="50" y="224" width="6" height="28" rx="2"/>
```

`strobe_arm_front.svg` (arm, strobe head, flash; authored at the mirror of the camera arm zone):
```svg
  <path d="M26 250 L14 274 L18 276 L30 252 Z"/>
  <circle cx="14" cy="280" r="8"/>
  <circle cx="14" cy="280" r="4"/>
```

`smb_butt_back.svg` (rolled tube, band, clip):
```svg
  <rect x="90" y="206" width="20" height="12" rx="6"/>
  <rect x="98" y="205" width="4" height="14" rx="2"/>
  <circle cx="100" cy="203" r="3"/>
```

`smb_thigh_front.svg` (tube, band):
```svg
  <rect x="70" y="236" width="10" height="30" rx="5"/>
  <rect x="69" y="248" width="12" height="4" rx="2"/>
```

`reel_butt_back.svg` (spool, hub, clip):
```svg
  <circle cx="100" cy="216" r="9"/>
  <circle cx="100" cy="216" r="4"/>
  <circle cx="100" cy="205" r="3"/>
```

`reel_hip_front.svg` (spool, hub, clip; authored at the left hip, mirrored onto the right):
```svg
  <circle cx="72" cy="208" r="8"/>
  <circle cx="72" cy="208" r="3"/>
  <circle cx="72" cy="198" r="3"/>
```

`knife_calf_front.svg` (sheath, handle, two straps):
```svg
  <rect x="72" y="286" width="8" height="26" rx="3"/>
  <rect x="73" y="278" width="6" height="10" rx="2"/>
  <rect x="68" y="290" width="16" height="4" rx="2"/>
  <rect x="68" y="304" width="16" height="4" rx="2"/>
```

`knife_hip_front.svg` (sheath, handle):
```svg
  <rect x="66" y="198" width="7" height="22" rx="3"/>
  <rect x="67" y="190" width="5" height="10" rx="2"/>
```

`dpv_front.svg` (hull, nose cone, prop shroud, handle):
```svg
  <rect x="60" y="262" width="80" height="30" rx="14"/>
  <circle cx="140" cy="277" r="15"/>
  <circle cx="60" cy="277" r="12"/>
  <rect x="90" y="254" width="20" height="8" rx="3"/>
```

- [ ] **Step 5: Generate, verify, and run both artwork tests**

Run: `python3 tool/build_figure_artwork.py && python3 tool/build_figure_artwork.py --verify && flutter test test/features/equipment/figure/artwork`
Expected: `wrote ... (59 pieces)`, `OK 59 pieces current`, all tests PASS including the three completeness tests.

- [ ] **Step 6: Look at the batch and commit**

Render the contact sheet; confirm the single tank sits centred on the back with the bands visible, the doubles show a manifold, and the wrist computer sits at the left wrist. Then:

```bash
git add tool/figure lib/features/equipment/figure/artwork test/features/equipment/figure/artwork
git commit -m "feat(figure): artwork for tanks, rebreathers, instruments and accessories

Part of #2326"
```

---

### Task 7: Composer, model, and the inputs mapper

**Files:**
- Create: `lib/features/equipment/figure/domain/figure_model.dart`
- Create: `lib/features/equipment/figure/domain/figure_composer.dart`
- Create: `lib/features/equipment/figure/domain/figure_inputs.dart`
- Test: `test/features/equipment/figure/domain/figure_composer_test.dart`
- Test: `test/features/equipment/figure/domain/figure_inputs_test.dart`

**Interfaces:**
- Consumes: `FigurePlacement`, `FigurePlacementSpec`, `FigureContext` (Task 3); `FigureZone` (Task 1); `equipmentTypeRank`, `kCanonicalTypeOrder` from `lib/features/equipment/domain/constants/equipment_type_order.dart`; `EquipmentItem` and `ComponentsIndex` (existing).
- Produces: `class FigureItemInput({id, type, name, attributes, isChild, tankRole})`; `class PlacedItem({number, item, zone, pieceIds, color})`; `class FigureModel({placed, tray})` with `itemCount`, `numbered`, `byId(id)`; `FigureModel composeFigure(List<FigureItemInput> items)`; `List<FigureItemInput> figureInputsFromItems(List<EquipmentItem> items, {ComponentsIndex components})`; `int? parseFigureColor(String? hex)`.

- [ ] **Step 1: Write the failing composer tests**

```dart
// test/features/equipment/figure/domain/figure_composer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// The composer decides where each item sits and what number it carries.
/// Placement walks the canonical type order so an outer suit always wins
/// the suit zone; numbering follows the caller's order so the digits run
/// down the legend (spec 4.3).
void main() {
  FigureItemInput item(
    String id,
    EquipmentType type, {
    Map<String, String?> attributes = const {},
    bool isChild = false,
    TankRole? tankRole,
  }) =>
      FigureItemInput(
        id: id,
        type: type,
        name: id,
        attributes: attributes,
        isChild: isChild,
        tankRole: tankRole,
      );

  test('numbers follow input order while placement follows type order', () {
    // A second stage listed before the regulator is numbered first, but the
    // regulator (earlier in the canonical order) is placed first and takes
    // the mouth, leaving the octo slot to the second stage.
    final model = composeFigure([
      item('second', EquipmentType.secondStage),
      item('reg', EquipmentType.regulator),
    ]);
    expect(model.byId('second')!.number, 1);
    expect(model.byId('reg')!.number, 2);
    expect(model.byId('reg')!.zone, FigureZone.mouth);
    expect(model.byId('second')!.zone, FigureZone.octo);
  });

  test('a rash guard leaves the suit zone to a wetsuit', () {
    final model = composeFigure([
      item('rash', EquipmentType.rashGuard),
      item('wet', EquipmentType.wetsuit),
    ]);
    expect(model.byId('wet')!.zone, FigureZone.suit);
    expect(model.byId('rash')!.zone, FigureZone.underlayer);
    // Alone, it still has a place.
    expect(composeFigure([item('rash', EquipmentType.rashGuard)]).byId('rash')!.zone,
        FigureZone.underlayer);
  });

  test('a second item of a type takes the next candidate zone', () {
    final model = composeFigure([
      item('c1', EquipmentType.computer),
      item('c2', EquipmentType.computer),
      item('c3', EquipmentType.computer),
    ]);
    expect(model.byId('c1')!.zone, FigureZone.wristLeft);
    expect(model.byId('c2')!.zone, FigureZone.wristRight);
    expect(model.byId('c3')!.zone, isNull);
    expect(model.tray.map((p) => p.item.id), ['c3']);
    expect(model.byId('c3')!.number, 3);
  });

  test('two tanks on the back become doubles drawn once', () {
    final model = composeFigure([
      item('t1', EquipmentType.tank),
      item('t2', EquipmentType.tank),
      item('t3', EquipmentType.tank),
    ]);
    expect(model.byId('t1')!.zone, FigureZone.backTank);
    expect(model.byId('t1')!.pieceIds, ['tank_doubles_back']);
    expect(model.byId('t2')!.zone, FigureZone.backTank);
    expect(model.byId('t2')!.pieceIds, isEmpty);
    expect(model.byId('t3')!.zone, FigureZone.stageLeft);
    expect(model.byId('t3')!.pieceIds, ['tank_stage_front']);
  });

  test('a sidemount harness sends tanks to the sides', () {
    final model = composeFigure([
      item('t1', EquipmentType.tank),
      item('t2', EquipmentType.tank),
      item('h', EquipmentType.bcd,
          attributes: {EquipmentAttrKeys.bcdStyle: 'sidemount'}),
    ]);
    expect(model.byId('t1')!.zone, FigureZone.sidemountLeft);
    expect(model.byId('t2')!.zone, FigureZone.sidemountRight);
  });

  test('a second BCD goes to the tray but still makes the rig sidemount', () {
    final model = composeFigure([
      item('jacket', EquipmentType.bcd),
      item('harness', EquipmentType.bcd,
          attributes: {EquipmentAttrKeys.bcdStyle: 'sidemount'}),
      item('t1', EquipmentType.tank),
    ]);
    expect(model.byId('jacket')!.zone, FigureZone.torsoFront);
    expect(model.byId('harness')!.zone, isNull);
    expect(model.byId('harness')!.number, 2);
    expect(model.byId('t1')!.zone, FigureZone.sidemountLeft);
  });

  test('a back-mounted rebreather fills the back so a tank goes to a stage slot', () {
    final model = composeFigure([
      item('ccr', EquipmentType.rebreather),
      item('bailout', EquipmentType.tank),
    ]);
    expect(model.byId('ccr')!.zone, FigureZone.backTank);
    expect(model.byId('bailout')!.zone, FigureZone.stageLeft);
  });

  test('a dive tank role places the tank regardless of the set rule', () {
    final model = composeFigure([
      item('l', EquipmentType.tank, tankRole: TankRole.sidemountLeft),
      item('r', EquipmentType.tank, tankRole: TankRole.sidemountRight),
      item('s', EquipmentType.tank, tankRole: TankRole.stage),
      item('d', EquipmentType.tank, tankRole: TankRole.deco),
    ]);
    expect(model.byId('l')!.zone, FigureZone.sidemountLeft);
    expect(model.byId('r')!.zone, FigureZone.sidemountRight);
    expect(model.byId('s')!.zone, FigureZone.stageLeft);
    expect(model.byId('d')!.zone, FigureZone.stageRight);
  });

  test('children are neither drawn nor numbered', () {
    final model = composeFigure([
      item('ccr', EquipmentType.rebreather),
      item('cell', EquipmentType.o2Cell, isChild: true),
      item('mask', EquipmentType.mask),
    ]);
    expect(model.byId('cell'), isNull);
    expect(model.byId('mask')!.number, 2);
    expect(model.itemCount, 2);
  });

  test('a top-level child type and a tool land in the tray, numbered', () {
    final model = composeFigure([
      item('cell', EquipmentType.o2Cell),
      item('tool', EquipmentType.tool),
    ]);
    expect(model.tray.map((p) => p.number), [1, 2]);
    expect(model.placed, isEmpty);
  });

  test('a colour attribute wins over the type default, malformed ones lose', () {
    final model = composeFigure([
      item('red', EquipmentType.fins, attributes: {'color': '#FF0000'}),
      item('bad', EquipmentType.fins, attributes: {'color': '#12G'}),
      item('word', EquipmentType.mask, attributes: {'color': 'red'}),
      item('empty', EquipmentType.hood, attributes: {'color': ''}),
    ]);
    expect(model.byId('red')!.color, 0xFFFF0000);
    expect(model.byId('bad')!.color, FigureColors.black);
    expect(model.byId('word')!.color, FigureColors.black);
    expect(model.byId('empty')!.color, FigureColors.black);
  });

  test('sixty lights fill every candidate and overflow to the tray in order', () {
    final model = composeFigure([
      for (var i = 1; i <= 60; i++) item('l$i', EquipmentType.light),
    ]);
    expect(model.placed.length, 3);
    expect(model.tray.length, 57);
    expect(model.numbered.map((p) => p.number), List.generate(60, (i) => i + 1));
    expect(model.numbered.map((p) => p.item.id).toSet().length, 60);
  });

  test('numbered lists placed and tray items in number order', () {
    final model = composeFigure([
      item('tool', EquipmentType.tool),
      item('mask', EquipmentType.mask),
    ]);
    expect(model.numbered.map((p) => p.item.id), ['tool', 'mask']);
  });
}
```

- [ ] **Step 2: Write the failing inputs test**

```dart
// test/features/equipment/figure/domain/figure_inputs_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/figure/domain/figure_inputs.dart';

/// The mapper is the one place the figure reads the equipment entity, so it
/// pins how a child is recognised: a parent link, or being a part of an
/// assembly in the components index.
void main() {
  EquipmentItem gear(String id, EquipmentType type,
          {String? parentId, List<EquipmentAttribute> attributes = const []}) =>
      EquipmentItem(
        id: id,
        name: 'Item $id',
        type: type,
        parentEquipmentId: parentId,
        attributes: attributes,
      );

  test('a parent link makes a child', () {
    final inputs = figureInputsFromItems([
      gear('ccr', EquipmentType.rebreather),
      gear('cell', EquipmentType.o2Cell, parentId: 'ccr'),
    ]);
    expect(inputs.map((i) => i.isChild), [false, true]);
  });

  test('an assembly part is a child through the components index', () {
    final index = ComponentsIndex.fromRows([
      EquipmentComponent(
        id: 'c1',
        parentEquipmentId: 'reg',
        componentEquipmentId: 'second',
        role: 'Primary second stage',
        sortOrder: 0,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    ]);
    final inputs = figureInputsFromItems([
      gear('reg', EquipmentType.regulator),
      gear('second', EquipmentType.secondStage),
    ], components: index);
    expect(inputs.map((i) => i.isChild), [false, true]);
  });

  test('catalog attributes are copied, custom ones are not', () {
    final inputs = figureInputsFromItems([
      gear('bcd', EquipmentType.bcd, attributes: [
        const EquipmentAttribute(
          id: 'a1', equipmentId: 'bcd', key: 'bcd_style',
          isCustom: false, valueText: 'wing', valueNum: null, sortOrder: 0,
        ),
        const EquipmentAttribute(
          id: 'a2', equipmentId: 'bcd', key: 'note',
          isCustom: true, valueText: 'loaner', valueNum: null, sortOrder: 1,
        ),
      ]),
    ]);
    expect(inputs.single.attributes, {'bcd_style': 'wing'});
  });

  test('names and order are preserved', () {
    final inputs = figureInputsFromItems([
      gear('b', EquipmentType.fins),
      gear('a', EquipmentType.mask),
    ]);
    expect(inputs.map((i) => i.id), ['b', 'a']);
    expect(inputs.first.name, 'Item b');
  });
}
```

`EquipmentComponent` requires `id`, `parentEquipmentId`, `componentEquipmentId`, `createdAt` and `updatedAt`; `EquipmentAttribute` takes exactly the seven fields used above.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/figure/domain/figure_composer_test.dart test/features/equipment/figure/domain/figure_inputs_test.dart`
Expected: FAIL, the files do not exist.

- [ ] **Step 4: Write the model**

```dart
// lib/features/equipment/figure/domain/figure_model.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// What the composer needs to know about one item. Built from
/// [EquipmentItem] by `figureInputsFromItems`, or by hand in tests.
class FigureItemInput {
  const FigureItemInput({
    required this.id,
    required this.type,
    required this.name,
    this.attributes = const {},
    this.isChild = false,
    this.tankRole,
  });

  final String id;
  final EquipmentType type;
  final String name;

  /// Catalog attribute values by key (choice keys and, from phase 3, the
  /// `color` hex). Custom attributes are not included.
  final Map<String, String?> attributes;

  /// A parent link or an assembly part: drawn only as its parent.
  final bool isChild;

  /// On a dive, the linked dive tank's role, which places the tank ahead of
  /// the set rule. Null everywhere else.
  final TankRole? tankRole;
}

/// One numbered item on the figure or in the tray.
class PlacedItem {
  const PlacedItem({
    required this.number,
    required this.item,
    required this.zone,
    required this.pieceIds,
    required this.color,
  });

  final int number;
  final FigureItemInput item;

  /// Null for a tray item.
  final FigureZone? zone;

  /// Artwork to draw, one id per view; empty for the tray and for the second
  /// tank of a doubles pair.
  final List<String> pieceIds;

  /// ARGB, the item's own colour or its type default.
  final int color;
}

/// The composed figure: what to draw and what to number.
class FigureModel {
  const FigureModel({required this.placed, required this.tray});

  /// Items with a zone, in placement order.
  final List<PlacedItem> placed;

  /// Items with no zone, in number order.
  final List<PlacedItem> tray;

  int get itemCount => placed.length + tray.length;

  /// Every item in number order, placed and tray together.
  List<PlacedItem> get numbered =>
      [...placed, ...tray]..sort((a, b) => a.number.compareTo(b.number));

  PlacedItem? byId(String id) {
    for (final item in placed) {
      if (item.item.id == id) return item;
    }
    for (final item in tray) {
      if (item.item.id == id) return item;
    }
    return null;
  }
}
```

- [ ] **Step 5: Write the composer**

```dart
// lib/features/equipment/figure/domain/figure_composer.dart
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_zone.dart';

/// The attribute key an item's own colour lives under (phase 3 adds it to
/// the catalog; the composer honours it from the start).
const String kFigureColorAttribute = 'color';

/// `#RRGGBB` to ARGB, or null for anything else.
int? parseFigureColor(String? hex) {
  if (hex == null || hex.length != 7 || !hex.startsWith('#')) return null;
  final value = int.tryParse(hex.substring(1), radix: 16);
  if (value == null) return null;
  return 0xFF000000 | value;
}

/// Places [items] on the figure and numbers them (spec sections 4.2 to 4.4).
///
/// Numbers follow the order of [items]; placement walks the canonical type
/// order so the outcome does not depend on the diver's sort setting.
FigureModel composeFigure(List<FigureItemInput> items) {
  final topLevel = [for (final item in items) if (!item.isChild) item];
  final numberById = <String, int>{
    for (var i = 0; i < topLevel.length; i++) topLevel[i].id: i + 1,
  };
  final context = FigureContext(
    sidemountRig: topLevel.any(
      (item) => FigurePlacement.contributesSidemountRig(item.type, item.attributes),
    ),
  );
  final ordered = [...topLevel]..sort((a, b) {
      final byType = equipmentTypeRank(a.type, kCanonicalTypeOrder)
          .compareTo(equipmentTypeRank(b.type, kCanonicalTypeOrder));
      return byType != 0 ? byType : numberById[a.id]!.compareTo(numberById[b.id]!);
    });

  final occupancy = <FigureZone, int>{};
  final placed = <PlacedItem>[];
  final tray = <PlacedItem>[];
  for (final item in ordered) {
    final spec = FigurePlacement.forType(
      item.type,
      attributes: item.attributes,
      context: context,
    );
    final color = parseFigureColor(item.attributes[kFigureColorAttribute]) ??
        spec.defaultColor;
    final zone = _pickZone(item, spec, occupancy);
    final number = numberById[item.id]!;
    if (zone == null) {
      tray.add(PlacedItem(number: number, item: item, zone: null, pieceIds: const [], color: color));
      continue;
    }
    occupancy[zone] = (occupancy[zone] ?? 0) + spec.occupies;
    placed.add(PlacedItem(
      number: number,
      item: item,
      zone: zone,
      pieceIds: spec.piecesFor(zone),
      color: color,
    ));
  }
  tray.sort((a, b) => a.number.compareTo(b.number));
  return FigureModel(placed: _mergeDoubles(placed), tray: tray);
}

/// A dive tank role names its own zones ahead of the set rule; otherwise the
/// first candidate with room wins.
FigureZone? _pickZone(
  FigureItemInput item,
  FigurePlacementSpec spec,
  Map<FigureZone, int> occupancy,
) {
  final candidates = [..._zonesForTankRole(item), ...spec.zones];
  for (final zone in candidates) {
    if ((occupancy[zone] ?? 0) + spec.occupies <= zone.capacity) return zone;
  }
  return null;
}

List<FigureZone> _zonesForTankRole(FigureItemInput item) {
  if (item.type != EquipmentType.tank) return const [];
  return switch (item.tankRole) {
    TankRole.sidemountLeft => const [FigureZone.sidemountLeft, FigureZone.sidemountRight],
    TankRole.sidemountRight => const [FigureZone.sidemountRight, FigureZone.sidemountLeft],
    TankRole.stage ||
    TankRole.deco ||
    TankRole.bailout ||
    TankRole.pony =>
      const [FigureZone.stageLeft, FigureZone.stageRight],
    TankRole.backGas ||
    TankRole.diluent ||
    TankRole.oxygenSupply =>
      const [FigureZone.backTank],
    null => const [],
  };
}

/// Two tanks in the back tank zone are one manifolded pair: the first draws
/// the doubles piece and the second draws nothing (its disc still shows).
List<PlacedItem> _mergeDoubles(List<PlacedItem> placed) {
  final backTanks = [
    for (final p in placed)
      if (p.zone == FigureZone.backTank && p.item.type == EquipmentType.tank) p,
  ];
  if (backTanks.length < 2) return placed;
  return [
    for (final p in placed)
      if (identical(p, backTanks[0]))
        PlacedItem(number: p.number, item: p.item, zone: p.zone,
            pieceIds: const ['tank_doubles_back'], color: p.color)
      else if (identical(p, backTanks[1]))
        PlacedItem(number: p.number, item: p.item, zone: p.zone,
            pieceIds: const [], color: p.color)
      else
        p,
  ];
}
```

- [ ] **Step 6: Write the inputs mapper**

```dart
// lib/features/equipment/figure/domain/figure_inputs.dart
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';

/// Turns equipment entities into composer inputs, in the same order.
///
/// A child is an item with a parent link or one that is a part of an
/// assembly in [components]. Custom attributes are dropped: the figure reads
/// only catalog keys.
List<FigureItemInput> figureInputsFromItems(
  List<EquipmentItem> items, {
  ComponentsIndex components = ComponentsIndex.empty,
}) {
  return [
    for (final item in items)
      FigureItemInput(
        id: item.id,
        type: item.type,
        name: item.name,
        attributes: {
          for (final a in item.attributes)
            if (!a.isCustom) a.key: a.valueText,
        },
        isChild: item.parentEquipmentId != null ||
            components.parentIdsOf(item.id).isNotEmpty,
      ),
  ];
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/figure/domain/figure_composer_test.dart test/features/equipment/figure/domain/figure_inputs_test.dart`
Expected: PASS, 17 tests.

- [ ] **Step 8: Commit**

```bash
dart format lib/features/equipment/figure test/features/equipment/figure
git add lib/features/equipment/figure/domain test/features/equipment/figure/domain
git commit -m "feat(figure): composer places and numbers a set's items

Part of #2326"
```

---

### Task 8: Palette, pure and theme-derived

**Files:**
- Create: `lib/features/equipment/figure/domain/figure_palette.dart`
- Create: `lib/features/equipment/figure/presentation/figure_palette_theme.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_section_colors.dart` (make `_readableOn` public as `readableOn`)
- Test: `test/features/equipment/figure/domain/figure_palette_test.dart`
- Test: `test/features/equipment/figure/presentation/figure_palette_theme_test.dart`

**Interfaces:**
- Consumes: `FigureRole` (Task 1); `contrastRatio` and `EquipmentSectionColors.readableOn` (existing, the latter made public here); `AppThemeRegistry` (existing).
- Produces: `class FigurePalette({body, bodyShade, gearDark, gearLight, metal, outline, disc, onDisc})` with `static const light`, `int colorFor(FigureRole role, int itemColor)`, `static int darken(int argb, double fraction)`; `FigurePalette figurePaletteFor(ColorScheme scheme)`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/equipment/figure/domain/figure_palette_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/figure/domain/figure_palette.dart';
import 'package:submersion/features/equipment/figure/domain/figure_role.dart';

void main() {
  test('item roles take the item colour and its shade', () {
    const palette = FigurePalette.light;
    expect(palette.colorFor(FigureRole.itemColor, 0xFF4080C0), 0xFF4080C0);
    expect(palette.colorFor(FigureRole.itemShade, 0xFF4080C0),
        FigurePalette.darken(0xFF4080C0, 0.25));
    expect(palette.colorFor(FigureRole.body, 0xFF4080C0), palette.body);
    expect(palette.colorFor(FigureRole.metal, 0), palette.metal);
  });

  test('darken keeps alpha and scales the channels', () {
    expect(FigurePalette.darken(0xFF800000, 0.5), 0xFF400000);
    expect(FigurePalette.darken(0xFFFFFFFF, 0.25), 0xFFBFBFBF);
    expect(FigurePalette.darken(0x80FFFFFF, 0.25) >> 24, 0x80);
  });
}
```

```dart
// test/features/equipment/figure/presentation/figure_palette_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_theme_registry.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_section_colors.dart';

/// The mannequin and the discs have to read on every theme the app ships.
/// Four of the five presets are hand-built and collapse their secondary
/// roles, so these tests pin outcomes (contrast floors), never roles.
void main() {
  for (final preset in AppThemeRegistry.presets) {
    for (final brightness in Brightness.values) {
      final scheme = AppThemeRegistry.resolveTheme(preset, brightness).colorScheme;
      final palette = figurePaletteFor(scheme);
      final name = '${preset.id} ${brightness.name}';

      test('$name: the body stands off the surfaces', () {
        for (final surface in [scheme.surface, scheme.surfaceContainer]) {
          expect(contrastRatio(Color(palette.body), surface),
              greaterThanOrEqualTo(1.6));
        }
      });

      test('$name: the body shade differs from the body', () {
        expect(palette.bodyShade, isNot(palette.body));
      });

      test('$name: the disc digit reads on the disc', () {
        expect(contrastRatio(Color(palette.onDisc), Color(palette.disc)),
            greaterThanOrEqualTo(4.5));
      });

      test('$name: the fixed gear greys read on the body', () {
        expect(contrastRatio(Color(palette.gearDark), Color(palette.body)),
            greaterThanOrEqualTo(2.0));
      });
    }
  }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/figure/domain/figure_palette_test.dart test/features/equipment/figure/presentation/figure_palette_theme_test.dart`
Expected: FAIL, the files do not exist.

- [ ] **Step 3: Write the pure palette**

```dart
// lib/features/equipment/figure/domain/figure_palette.dart
import 'package:submersion/features/equipment/figure/domain/figure_role.dart';

/// Colours for every role, as ARGB ints so the PDF code can use the same
/// palette without Flutter.
class FigurePalette {
  const FigurePalette({
    required this.body,
    required this.bodyShade,
    required this.gearDark,
    required this.gearLight,
    required this.metal,
    required this.outline,
    required this.disc,
    required this.onDisc,
  });

  /// The share image and the PDFs draw with this whatever the app theme.
  static const FigurePalette light = FigurePalette(
    body: 0xFFCBD3DB,
    bodyShade: 0xFFB2BCC6,
    gearDark: 0xFF2A2A2E,
    gearLight: 0xFF8FD3FF,
    metal: 0xFF9AA3AD,
    outline: 0xFF1B1B1F,
    disc: 0xFF0B57D0,
    onDisc: 0xFFFFFFFF,
  );

  final int body;
  final int bodyShade;
  final int gearDark;
  final int gearLight;
  final int metal;
  final int outline;
  final int disc;
  final int onDisc;

  /// The colour for [role] on an item whose own colour is [itemColor].
  int colorFor(FigureRole role, int itemColor) => switch (role) {
        FigureRole.body => body,
        FigureRole.bodyShade => bodyShade,
        FigureRole.gearDark => gearDark,
        FigureRole.gearLight => gearLight,
        FigureRole.metal => metal,
        FigureRole.itemColor => itemColor,
        FigureRole.itemShade => darken(itemColor, 0.25),
        FigureRole.outline => outline,
      };

  /// Scales the RGB channels of [argb] down by [fraction], keeping alpha.
  static int darken(int argb, double fraction) {
    final keep = 1 - fraction;
    int channel(int shift) => ((argb >> shift) & 0xFF) * keep ~/ 1;
    return (argb & 0xFF000000) |
        (channel(16) << 16) |
        (channel(8) << 8) |
        channel(0);
  }
}
```

- [ ] **Step 4: Make the contrast helper public and write the theme derivation**

In `equipment_section_colors.dart`, rename `_readableOn` to `readableOn` (both the definition and its one call in the factory) and keep its doc comment. Then:

```dart
// lib/features/equipment/figure/presentation/figure_palette_theme.dart
import 'package:flutter/material.dart';
import 'package:submersion/features/equipment/figure/domain/figure_palette.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_section_colors.dart';

/// The palette for the current theme.
///
/// The mannequin is a blend of `onSurface` over `surface`, walked up until
/// it stands 1.6:1 off both the page surface and the container tint a card
/// sits on. Gear greys are fixed. The disc uses `primary` with whichever of
/// `onPrimary`, black or white reads on it.
FigurePalette figurePaletteFor(ColorScheme scheme) {
  final body = _bodyTone(scheme);
  final shade = Color.alphaBlend(scheme.surface.withValues(alpha: 0.35), body);
  final onDisc = EquipmentSectionColors.readableOn(scheme.primary, [scheme.onPrimary]);
  return FigurePalette(
    body: body.toARGB32(),
    bodyShade: shade.toARGB32(),
    gearDark: FigurePalette.light.gearDark,
    gearLight: FigurePalette.light.gearLight,
    metal: FigurePalette.light.metal,
    outline: FigurePalette.light.outline,
    disc: scheme.primary.toARGB32(),
    onDisc: onDisc.toARGB32(),
  );
}

/// Walks the blend up until the body stands off both surfaces and the fixed
/// dark gear grey still reads on it; on a dark scheme that second condition
/// is what lifts the body above the gear.
Color _bodyTone(ColorScheme scheme) {
  const gearDark = Color(FigurePalette.light.gearDark);
  for (var percent = 12; percent <= 100; percent += 2) {
    final blend = Color.alphaBlend(
      scheme.onSurface.withValues(alpha: percent / 100),
      scheme.surface,
    );
    final offSurfaces = [scheme.surface, scheme.surfaceContainer]
        .every((s) => contrastRatio(blend, s) >= 1.6);
    if (offSurfaces && contrastRatio(gearDark, blend) >= 2.0) return blend;
  }
  return scheme.onSurface;
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/figure/domain/figure_palette_test.dart test/features/equipment/figure/presentation/figure_palette_theme_test.dart test/features/equipment/presentation/widgets/equipment_section_colors_test.dart`
Expected: PASS, including the existing section-colours test after the rename. If a preset fails the body-off-surfaces floor at 100 percent, its `onSurface` equals its `surface`; there is no such preset today and the test is what would say so.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/equipment test/features/equipment
git add lib/features/equipment/figure lib/features/equipment/presentation/widgets/equipment_section_colors.dart test/features/equipment/figure
git commit -m "feat(figure): palette with theme-derived body tone

Part of #2326"
```

---

### Task 9: Path cache and layout

**Files:**
- Create: `lib/features/equipment/figure/presentation/figure_paths.dart`
- Create: `lib/features/equipment/figure/presentation/figure_layout.dart`
- Test: `test/features/equipment/figure/presentation/figure_paths_test.dart`
- Test: `test/features/equipment/figure/presentation/figure_layout_test.dart`

**Interfaces:**
- Consumes: `figureArtwork` (Task 2), `kFigureWidth`, `kFigureHeight`, `FigureView` (Task 1), `path_parsing`.
- Produces: `FigurePaths.of(String pieceId) -> List<Path>`, `FigurePaths.parseSvgPath(String d) -> Path`, `FigurePaths.cachedPieceCount`, `FigurePaths.clearCache()`; `class FigureLayout({front, back, scale})` with `static forSize(Size)`, `static preferredHeight(double width)`, `static const gutter = 12`, `static const maxHeight = 360`, `rectFor(view)`, `toBox(view, x, y) -> Offset`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/equipment/figure/presentation/figure_paths_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/figure/artwork/figure_artwork.g.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_paths.dart';

void main() {
  setUp(FigurePaths.clearCache);

  test('a piece parses into one path per shape and is cached', () {
    final piece = figureArtwork['body_front']!;
    final paths = FigurePaths.of('body_front');
    expect(paths.length, piece.paths.length);
    expect(FigurePaths.cachedPieceCount, 1);
    expect(identical(FigurePaths.of('body_front'), paths), isTrue);
    expect(FigurePaths.cachedPieceCount, 1);
  });

  test('the head circle has the bounds its arc describes', () {
    final head = FigurePaths.of('body_front').first.getBounds();
    expect(head.left, closeTo(78, 0.5));
    expect(head.right, closeTo(122, 0.5));
    expect(head.top, closeTo(20, 0.5));
    expect(head.bottom, closeTo(64, 0.5));
  });

  test('an unknown piece throws rather than drawing nothing', () {
    expect(() => FigurePaths.of('no_such_piece'), throwsArgumentError);
  });
}
```

```dart
// test/features/equipment/figure/presentation/figure_layout_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';

void main() {
  test('a phone width shares the box between two 1:2 figures', () {
    final layout = FigureLayout.forSize(const Size(360, 348));
    expect(layout.front.width, closeTo(174, 0.01));
    expect(layout.front.height, closeTo(348, 0.01));
    expect(layout.back.left, closeTo(174 + FigureLayout.gutter, 0.01));
    expect(layout.scale, closeTo(174 / 200, 0.0001));
  });

  test('a wide box caps the figures by height and centres them', () {
    final layout = FigureLayout.forSize(const Size(1000, 360));
    expect(layout.front.height, closeTo(360, 0.01));
    expect(layout.front.width, closeTo(180, 0.01));
    final total = layout.back.right - layout.front.left;
    expect(layout.front.left, closeTo((1000 - total) / 2, 0.01));
  });

  test('preferredHeight is the pair height for a width, capped', () {
    expect(FigureLayout.preferredHeight(360), closeTo(348, 0.01));
    expect(FigureLayout.preferredHeight(1000), FigureLayout.maxHeight);
  });

  test('toBox maps figure space through the scale and offset', () {
    final layout = FigureLayout.forSize(const Size(412, 400));
    final p = layout.toBox(FigureView.back, 100, 0);
    expect(p.dx, closeTo(layout.back.left + 100 * layout.scale, 0.001));
    expect(p.dy, closeTo(layout.back.top, 0.001));
  });

  test('a degenerate box stays finite and positive', () {
    for (final size in const [Size(0, 0), Size(5, 300), Size(300, 0)]) {
      final layout = FigureLayout.forSize(size);
      expect(layout.front.width, greaterThan(0));
      expect(layout.front.height, greaterThan(0));
      expect(layout.scale.isFinite, isTrue);
      final p = layout.toBox(FigureView.front, 100, 200);
      expect(p.dx.isFinite && p.dy.isFinite, isTrue);
    }
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/equipment/figure/presentation/figure_paths_test.dart test/features/equipment/figure/presentation/figure_layout_test.dart`
Expected: FAIL, the files do not exist.

- [ ] **Step 3: Write the path cache**

```dart
// lib/features/equipment/figure/presentation/figure_paths.dart
import 'dart:ui';

import 'package:path_parsing/path_parsing.dart';
import 'package:submersion/features/equipment/figure/artwork/figure_artwork.g.dart';

/// Parsed [Path]s per piece, built once per process.
///
/// Thirty set cards on one list draw the mannequin thirty times; the
/// strings are parsed once.
abstract final class FigurePaths {
  static final Map<String, List<Path>> _cache = {};

  static List<Path> of(String pieceId) {
    return _cache.putIfAbsent(pieceId, () {
      final piece = figureArtwork[pieceId];
      if (piece == null) {
        throw ArgumentError.value(pieceId, 'pieceId', 'unknown figure piece');
      }
      return List.unmodifiable([for (final p in piece.paths) parseSvgPath(p.d)]);
    });
  }

  static Path parseSvgPath(String d) {
    final proxy = _UiPathProxy();
    writeSvgPathDataToPath(d, proxy);
    return proxy.path;
  }

  static int get cachedPieceCount => _cache.length;

  static void clearCache() => _cache.clear();
}

class _UiPathProxy extends PathProxy {
  final Path path = Path();

  @override
  void moveTo(double x, double y) => path.moveTo(x, y);

  @override
  void lineTo(double x, double y) => path.lineTo(x, y);

  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);

  @override
  void close() => path.close();
}
```

- [ ] **Step 4: Write the layout**

```dart
// lib/features/equipment/figure/presentation/figure_layout.dart
import 'dart:math' as math;
import 'dart:ui';

import 'package:submersion/features/equipment/figure/domain/figure_space.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';

/// Where the front and back figures sit inside a box, and the scale from
/// figure space to that box. Both figures share one scale so they are the
/// same size.
class FigureLayout {
  const FigureLayout({required this.front, required this.back, required this.scale});

  static const double gutter = 12;
  static const double maxHeight = 360;

  final Rect front;
  final Rect back;
  final double scale;

  /// The pair side by side, each at the figure's 1:2 aspect, as large as the
  /// box allows, centred. A degenerate box still yields a positive layout.
  static FigureLayout forSize(Size size) {
    final byWidth = (size.width - gutter) / 2;
    final byHeight = size.height / 2;
    final figureWidth = math.max(1.0, math.min(byWidth, byHeight));
    final figureHeight = figureWidth * 2;
    final totalWidth = figureWidth * 2 + gutter;
    final left = (size.width - totalWidth) / 2;
    final top = (size.height - figureHeight) / 2;
    return FigureLayout(
      front: Rect.fromLTWH(left, top, figureWidth, figureHeight),
      back: Rect.fromLTWH(left + figureWidth + gutter, top, figureWidth, figureHeight),
      scale: figureWidth / kFigureWidth,
    );
  }

  /// The height a full-width pair wants for [width], capped at [maxHeight].
  static double preferredHeight(double width) =>
      math.min(maxHeight, math.max(2.0, width - gutter));

  Rect rectFor(FigureView view) => view == FigureView.front ? front : back;

  /// A figure-space point of [view] in box coordinates.
  Offset toBox(FigureView view, double x, double y) {
    final rect = rectFor(view);
    return Offset(rect.left + x * scale, rect.top + y * scale);
  }
}
```

`kFigureHeight` is not read here because the aspect is fixed at 1:2 by construction; the import of `figure_space.dart` is for `kFigureWidth`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/equipment/figure/presentation/figure_paths_test.dart test/features/equipment/figure/presentation/figure_layout_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/equipment/figure test/features/equipment/figure
git add lib/features/equipment/figure/presentation test/features/equipment/figure/presentation
git commit -m "feat(figure): path cache and pair layout

Part of #2326"
```

---

### Task 10: The painter

**Files:**
- Create: `lib/features/equipment/figure/presentation/diver_figure_painter.dart`
- Test: `test/features/equipment/figure/presentation/diver_figure_painter_test.dart`

**Interfaces:**
- Consumes: `FigureModel`, `PlacedItem` (Task 7); `FigurePalette` (Task 8); `FigurePaths`, `FigureLayout` (Task 9); `figureArtwork` (Task 2); `kFigureWidth` (Task 1).
- Produces: `class DiverFigurePainter extends CustomPainter` with `DiverFigurePainter({required FigureModel model, required FigurePalette palette})`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/figure/presentation/diver_figure_painter_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_palette.dart';
import 'package:submersion/features/equipment/figure/domain/figure_placement.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure_painter.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';

/// Goldens are macOS-only in this repo and skipped in CI, so the painter is
/// pinned by sampling pixels: the body where the torso is, the item colour
/// where a piece is, transparency in the gutter, and the flipped piece on a
/// mirrored zone.
void main() {
  // 424 by 400 gives each figure 200 by 400, so figure space maps 1:1 with
  // the front at x offset 6 and the back at x offset 218.
  const size = Size(424, 400);

  Future<int Function(Offset)> paint(FigureModel model) async {
    final recorder = PictureRecorder();
    DiverFigurePainter(model: model, palette: FigurePalette.light)
        .paint(Canvas(recorder), size);
    final image = await recorder.endRecording().toImage(424, 400);
    final bytes = (await image.toByteData())!;
    return (Offset p) {
      final i = (p.dy.round() * 424 + p.dx.round()) * 4;
      return (bytes.getUint8(i + 3) << 24) |
          (bytes.getUint8(i) << 16) |
          (bytes.getUint8(i + 1) << 8) |
          bytes.getUint8(i + 2);
    };
  }

  FigureItemInput item(String id, EquipmentType type) =>
      FigureItemInput(id: id, type: type, name: id);

  testWidgets('paints the mannequin on both views and nothing in the gutter', (tester) async {
    await tester.runAsync(() async {
      final pixel = await paint(composeFigure(const []));
      final layout = FigureLayout.forSize(size);
      expect(pixel(layout.toBox(FigureView.front, 100, 140)), FigurePalette.light.body);
      expect(pixel(layout.toBox(FigureView.back, 100, 140)), FigurePalette.light.body);
      expect(pixel(Offset(layout.front.right + FigureLayout.gutter / 2, 10)) >> 24, 0);
    });
  });

  testWidgets('a placed mask paints its lens where the artwork says', (tester) async {
    await tester.runAsync(() async {
      final pixel = await paint(composeFigure([item('m', EquipmentType.mask)]));
      final layout = FigureLayout.forSize(size);
      // mask_front's left lens spans x 85 to 98, y 37 to 45.
      expect(pixel(layout.toBox(FigureView.front, 91, 41)), FigurePalette.light.gearLight);
      // The frame around it takes the item colour.
      expect(pixel(layout.toBox(FigureView.front, 100, 36)), FigureColors.black);
    });
  });

  testWidgets('a second computer is flipped onto the right wrist', (tester) async {
    await tester.runAsync(() async {
      final pixel = await paint(composeFigure([
        item('c1', EquipmentType.computer),
        item('c2', EquipmentType.computer),
      ]));
      final layout = FigureLayout.forSize(size);
      // computer_wrist_front's case spans x 37 to 53, y 188 to 204; mirrored
      // about x = 100 that is x 147 to 163.
      expect(pixel(layout.toBox(FigureView.front, 45, 196)), FigureColors.black);
      expect(pixel(layout.toBox(FigureView.front, 155, 196)), FigureColors.black);
    });
  });

  testWidgets('layers paint low to high so a BCD covers the wetsuit', (tester) async {
    await tester.runAsync(() async {
      final pixel = await paint(composeFigure([
        item('bcd', EquipmentType.bcd),
        item('suit', EquipmentType.wetsuit),
      ]));
      final layout = FigureLayout.forSize(size);
      // Inside the jacket, between the straps: the jacket (black), not the
      // suit (dark blue).
      expect(pixel(layout.toBox(FigureView.front, 100, 120)), FigureColors.black);
      // On the thigh, only the suit.
      expect(pixel(layout.toBox(FigureView.front, 84, 260)), FigureColors.darkBlue);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/figure/presentation/diver_figure_painter_test.dart`
Expected: FAIL, the painter file does not exist.

- [ ] **Step 3: Write the painter**

```dart
// lib/features/equipment/figure/presentation/diver_figure_painter.dart
import 'package:flutter/rendering.dart';
import 'package:submersion/features/equipment/figure/artwork/figure_artwork.g.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/domain/figure_palette.dart';
import 'package:submersion/features/equipment/figure/domain/figure_piece_data.dart';
import 'package:submersion/features/equipment/figure/domain/figure_space.dart';
import 'package:submersion/features/equipment/figure/domain/figure_view.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_paths.dart';

/// Draws the front and back figures for a [FigureModel].
///
/// Each view paints the mannequin, then every placed piece of that view in
/// layer order (ties broken by item number), each path filled with its
/// role's colour. A piece on a mirrored zone is flipped about the figure's
/// centre line. Discs are not painted here; the widget positions them.
class DiverFigurePainter extends CustomPainter {
  DiverFigurePainter({required this.model, required this.palette});

  final FigureModel model;
  final FigurePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = FigureLayout.forSize(size);
    for (final view in FigureView.values) {
      final rect = layout.rectFor(view);
      canvas.save();
      canvas.translate(rect.left, rect.top);
      canvas.scale(layout.scale);
      _paintView(canvas, view);
      canvas.restore();
    }
  }

  void _paintView(Canvas canvas, FigureView view) {
    final entries = <_Entry>[
      _Entry(
        piece: figureArtwork[view == FigureView.front ? 'body_front' : 'body_back']!,
        itemColor: 0,
        mirrored: false,
        order: 0,
      ),
      for (final item in model.placed)
        for (final id in item.pieceIds)
          if (figureArtwork[id] case final piece? when piece.view == view)
            _Entry(
              piece: piece,
              itemColor: item.color,
              mirrored: item.zone!.mirrored,
              order: item.number,
            ),
    ]..sort((a, b) {
        final byLayer = a.piece.layer.compareTo(b.piece.layer);
        return byLayer != 0 ? byLayer : a.order.compareTo(b.order);
      });

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final entry in entries) {
      canvas.save();
      if (entry.mirrored) {
        canvas.translate(kFigureWidth, 0);
        canvas.scale(-1, 1);
      }
      final paths = FigurePaths.of(entry.piece.id);
      for (var i = 0; i < paths.length; i++) {
        paint.color = Color(palette.colorFor(entry.piece.paths[i].role, entry.itemColor));
        canvas.drawPath(paths[i], paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(DiverFigurePainter oldDelegate) =>
      !identical(oldDelegate.model, model) || !identical(oldDelegate.palette, palette);
}

class _Entry {
  const _Entry({
    required this.piece,
    required this.itemColor,
    required this.mirrored,
    required this.order,
  });

  final FigurePieceData piece;
  final int itemColor;
  final bool mirrored;
  final int order;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/equipment/figure/presentation/diver_figure_painter_test.dart`
Expected: PASS, 4 tests. A sampled pixel one channel off means anti-aliasing at an edge: move the sample one figure unit toward the shape's centre, never loosen the equality.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/equipment/figure test/features/equipment/figure
git add lib/features/equipment/figure/presentation/diver_figure_painter.dart test/features/equipment/figure/presentation/diver_figure_painter_test.dart
git commit -m "feat(figure): painter draws the pair with mirrored zones

Part of #2326"
```

---

### Task 11: Number badge and the DiverFigure widget

**Files:**
- Create: `lib/features/equipment/figure/presentation/figure_number_badge.dart`
- Create: `lib/features/equipment/figure/presentation/diver_figure.dart`
- Test: `test/features/equipment/figure/presentation/diver_figure_test.dart`

**Interfaces:**
- Consumes: `DiverFigurePainter` (Task 10), `FigureLayout` (Task 9), `figurePaletteFor` (Task 8), `FigureModel`, `PlacedItem` (Task 7), `equipmentTypeIcon` (existing).
- Produces: `class FigureNumberBadge({number, selected, size, onTap, semanticsLabel})`; `enum FigureMode { pair }`; `class DiverFigure({model, semanticsLabel, mode, selectedItemId, onItemTap, discLabel, trayTitle})` with `static const discSize = 20`, `hitSize = 40`; `Map<String, Offset> discPositions(FigureModel model, FigureLayout layout)`; disc keys `ValueKey('figure-disc-<itemId>')`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/equipment/figure/presentation/diver_figure_test.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';

void main() {
  FigureItemInput item(String id, EquipmentType type) =>
      FigureItemInput(id: id, type: type, name: 'Item $id');

  Future<void> pump(
    WidgetTester tester,
    FigureModel model, {
    String? selectedItemId,
    ValueChanged<PlacedItem>? onItemTap,
    String? trayTitle,
  }) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DiverFigure(
              model: model,
              semanticsLabel: 'Reef set, 3 items',
              selectedItemId: selectedItemId,
              onItemTap: onItemTap,
              discLabel: (p) => '${p.number}, ${p.item.type.name}, ${p.item.name}',
              trayTitle: trayTitle,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('one badge per placed item, labelled for a screen reader', (tester) async {
    final model = composeFigure([
      item('mask', EquipmentType.mask),
      item('bcd', EquipmentType.bcd),
      item('fins', EquipmentType.fins),
    ]);
    await pump(tester, model);
    expect(find.byType(FigureNumberBadge), findsNWidgets(3));
    expect(find.bySemanticsLabel('2, bcd, Item bcd'), findsOneWidget);
    expect(find.bySemanticsLabel('Reef set, 3 items'), findsOneWidget);
  });

  testWidgets('tapping a disc reports its item', (tester) async {
    final model = composeFigure([item('mask', EquipmentType.mask)]);
    PlacedItem? tapped;
    await pump(tester, model, onItemTap: (p) => tapped = p);
    await tester.tap(find.byKey(const ValueKey('figure-disc-mask')));
    expect(tapped?.item.id, 'mask');
  });

  testWidgets('a selected disc draws its ring', (tester) async {
    final model = composeFigure([item('mask', EquipmentType.mask)]);
    await pump(tester, model, selectedItemId: 'mask');
    final badge = tester.widget<FigureNumberBadge>(find.byType(FigureNumberBadge));
    expect(badge.selected, isTrue);
  });

  testWidgets('the hit box is 40 on both platforms', (tester) async {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final model = composeFigure([item('mask', EquipmentType.mask)]);
      await pump(tester, model, onItemTap: (_) {});
      final size = tester.getSize(find.byKey(const ValueKey('figure-disc-mask')));
      expect(size.width, greaterThanOrEqualTo(40), reason: platform.name);
      expect(size.height, greaterThanOrEqualTo(40), reason: platform.name);
    }
  });

  testWidgets('tray items get badges under a title; no tray, no title', (tester) async {
    final withTray = composeFigure([
      item('mask', EquipmentType.mask),
      item('tool', EquipmentType.tool),
    ]);
    await pump(tester, withTray, trayTitle: 'Also carried');
    expect(find.text('Also carried'), findsOneWidget);
    expect(find.byType(FigureNumberBadge), findsNWidgets(2));

    await pump(tester, composeFigure([item('mask', EquipmentType.mask)]),
        trayTitle: 'Also carried');
    expect(find.text('Also carried'), findsNothing);
  });

  test('discs sharing an anchor are nudged apart', () {
    final model = composeFigure([
      item('fs', EquipmentType.firstStage),
      item('tx', EquipmentType.transmitter),
    ]);
    final layout = FigureLayout.forSize(const Size(400, 388));
    final positions = discPositions(model, layout);
    expect((positions['fs']! - positions['tx']!).distance, greaterThanOrEqualTo(22));
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/figure/presentation/diver_figure_test.dart`
Expected: FAIL, the widget files do not exist.

- [ ] **Step 3: Write the badge**

```dart
// lib/features/equipment/figure/presentation/figure_number_badge.dart
import 'package:flutter/material.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';

/// The numbered disc, on the figure and at the head of a legend row.
///
/// Always drawn with a ring in the on-disc colour, so the disc keeps an edge
/// on a body or a gear colour close to `primary`; selection thickens it.
class FigureNumberBadge extends StatelessWidget {
  const FigureNumberBadge({
    super.key,
    required this.number,
    this.selected = false,
    this.size = 24,
    this.onTap,
    this.semanticsLabel,
  });

  final int number;
  final bool selected;
  final double size;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final palette = figurePaletteFor(Theme.of(context).colorScheme);
    final disc = Color(palette.disc);
    final onDisc = Color(palette.onDisc);
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: disc,
        border: Border.all(color: onDisc, width: selected ? 2.5 : 1),
      ),
      child: Text(
        '$number',
        style: TextStyle(
          color: onDisc,
          fontSize: size * 0.5,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      selected: selected,
      excludeSemantics: semanticsLabel != null,
      child: onTap == null
          ? circle
          : GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: circle),
    );
  }
}
```

- [ ] **Step 4: Write the widget**

```dart
// lib/features/equipment/figure/presentation/diver_figure.dart
import 'package:flutter/material.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure_painter.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_layout.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_palette_theme.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';

/// How the figure is shown. Phase 1 ships the pair; later phases add a
/// thumbnail and a locate mode.
enum FigureMode { pair }

/// The front and back figures with a numbered disc per placed item, and a
/// tray of tiles for items with no place on the body.
class DiverFigure extends StatelessWidget {
  const DiverFigure({
    super.key,
    required this.model,
    required this.semanticsLabel,
    this.mode = FigureMode.pair,
    this.selectedItemId,
    this.onItemTap,
    this.discLabel,
    this.trayTitle,
  });

  static const double discSize = 20;
  static const double hitSize = 40;

  final FigureModel model;

  /// Read for the whole picture, for example "Reef set, 9 items".
  final String semanticsLabel;
  final FigureMode mode;
  final String? selectedItemId;
  final ValueChanged<PlacedItem>? onItemTap;

  /// The screen-reader label of one disc, for example "3, BCD, Hollis SMS75".
  final String Function(PlacedItem item)? discLabel;

  /// Heading over the tray. The tray is hidden when the model has none.
  final String? trayTitle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 360.0;
        final height = FigureLayout.preferredHeight(width);
        final size = Size(width, height);
        final layout = FigureLayout.forSize(size);
        final positions = discPositions(model, layout);
        final palette = figurePaletteFor(Theme.of(context).colorScheme);
        final figures = SizedBox(
          width: width,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Semantics(
                  label: semanticsLabel,
                  image: true,
                  excludeSemantics: true,
                  child: CustomPaint(
                    painter: DiverFigurePainter(model: model, palette: palette),
                  ),
                ),
              ),
              for (final item in model.placed)
                Positioned(
                  left: positions[item.item.id]!.dx - hitSize / 2,
                  top: positions[item.item.id]!.dy - hitSize / 2,
                  child: SizedBox(
                    key: ValueKey('figure-disc-${item.item.id}'),
                    width: hitSize,
                    height: hitSize,
                    child: Center(
                      child: FigureNumberBadge(
                        number: item.number,
                        size: discSize,
                        selected: item.item.id == selectedItemId,
                        semanticsLabel: discLabel?.call(item),
                        onTap: onItemTap == null ? null : () => onItemTap!(item),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
        if (model.tray.isEmpty) return figures;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            figures,
            const SizedBox(height: 8),
            if (trayTitle != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(trayTitle!, style: Theme.of(context).textTheme.labelSmall),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in model.tray)
                  _TrayTile(
                    item: item,
                    selected: item.item.id == selectedItemId,
                    semanticsLabel: discLabel?.call(item),
                    onTap: onItemTap == null ? null : () => onItemTap!(item),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Disc centres in box space, in number order, nudged down and right when
/// an earlier disc sits within 22 points.
Map<String, Offset> discPositions(FigureModel model, FigureLayout layout) {
  const minDistance = 22.0;
  const nudge = Offset(14, 14);
  final result = <String, Offset>{};
  final taken = <Offset>[];
  final items = [...model.placed]..sort((a, b) => a.number.compareTo(b.number));
  for (final item in items) {
    final zone = item.zone!;
    var p = layout.toBox(zone.view, zone.anchorX, zone.anchorY);
    while (taken.any((t) => (t - p).distance < minDistance)) {
      p += nudge;
    }
    taken.add(p);
    result[item.item.id] = p;
  }
  return result;
}

class _TrayTile extends StatelessWidget {
  const _TrayTile({
    required this.item,
    required this.selected,
    required this.semanticsLabel,
    required this.onTap,
  });

  final PlacedItem item;
  final bool selected;
  final String? semanticsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticsLabel,
      button: onTap != null,
      selected: selected,
      excludeSemantics: semanticsLabel != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: DiverFigure.hitSize),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FigureNumberBadge(number: item.number, size: DiverFigure.discSize),
              const SizedBox(width: 6),
              Icon(equipmentTypeIcon(item.item.type), size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/features/equipment/figure/presentation/diver_figure_test.dart`
Expected: PASS, 6 tests. If the semantics finder for the disc label fails, the badge's `excludeSemantics` is dropping the label too; the label belongs on the outer `Semantics` and only the inner `Text` is excluded.

- [ ] **Step 6: Commit**

```bash
dart format lib/features/equipment/figure test/features/equipment/figure
git add lib/features/equipment/figure/presentation test/features/equipment/figure/presentation
git commit -m "feat(figure): DiverFigure widget with numbered discs and tray

Part of #2326"
```

---

### Task 12: The set page, with strings in eleven locales

**Files:**
- Modify: `lib/features/equipment/presentation/pages/equipment_set_detail_page.dart`
- Modify: `lib/l10n/arb/app_en.arb` and the ten other `lib/l10n/arb/app_*.arb`
- Modify (generated): `lib/l10n/arb/app_localizations*.dart`
- Modify: `test/features/equipment/presentation/pages/equipment_set_detail_default_test.dart` (add the components index override)
- Test: `test/features/equipment/presentation/pages/equipment_set_detail_figure_test.dart`

**Interfaces:**
- Consumes: `DiverFigure`, `FigureNumberBadge`, `composeFigure`, `figureInputsFromItems`, `FigureModel` (Tasks 7 and 11); `equipmentComponentsIndexProvider`, `ComponentsIndex` (existing).
- Produces: l10n getters `equipment_figure_summary(String name, int count)`, `equipment_figure_discLabel(int number, String type, String name)`, `equipment_figure_trayTitle`.

- [ ] **Step 1: Write the failing page test**

```dart
// test/features/equipment/presentation/pages/equipment_set_detail_figure_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_set_detail_page.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The set page shows the figure above its list and numbers the list as the
/// legend, so a disc and its row always agree.
void main() {
  EquipmentItem gear(String id, String name, EquipmentType type) =>
      EquipmentItem(id: id, name: name, type: type);

  Future<void> pump(WidgetTester tester, List<EquipmentItem> items) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final set = EquipmentSet(
      id: 's1',
      name: 'Reef set',
      equipmentIds: [for (final item in items) item.id],
      items: items,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentSetProvider.overrideWith((ref, id) async => set),
          equipmentSetGeofencesProvider.overrideWith((ref, id) async => []),
          equipmentArrangementProvider.overrideWithValue(
            EquipmentArrangement.defaults.copyWith(groupByType: false),
          ),
          equipmentComponentsIndexProvider.overrideWith(
            (ref) => Future.value(ComponentsIndex.fromRows(const [])),
          ),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EquipmentSetDetailPage(setId: 's1'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final three = [
    gear('m', 'Hollis M1', EquipmentType.mask),
    gear('b', 'Hollis SMS75', EquipmentType.bcd),
    gear('f', 'Jet Fins', EquipmentType.fins),
  ];

  testWidgets('the figure appears with one disc and one row badge per item', (tester) async {
    await pump(tester, three);
    expect(find.byType(DiverFigure), findsOneWidget);
    expect(find.byType(FigureNumberBadge), findsNWidgets(6));
    expect(find.bySemanticsLabel('Reef set, 3 items'), findsOneWidget);
    expect(find.bySemanticsLabel('2, BCD, Hollis SMS75'), findsOneWidget);
  });

  testWidgets('no items, no figure', (tester) async {
    await pump(tester, const []);
    expect(find.byType(DiverFigure), findsNothing);
  });

  testWidgets('tapping a disc selects its row and the row badge', (tester) async {
    await pump(tester, three);
    await tester.tap(find.byKey(const ValueKey('figure-disc-b')));
    await tester.pump();
    final selected = tester
        .widgetList<FigureNumberBadge>(find.byType(FigureNumberBadge))
        .where((b) => b.selected)
        .toList();
    expect(selected.length, 2);
    expect(selected.every((b) => b.number == 2), isTrue);
    // The highlight clears on its own.
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.widgetList<FigureNumberBadge>(find.byType(FigureNumberBadge)).any((b) => b.selected),
      isFalse,
    );
  });

  testWidgets('a tray item shows the carried heading', (tester) async {
    await pump(tester, [...three, gear('t', 'Wrench', EquipmentType.tool)]);
    expect(find.text('Also carried'), findsOneWidget);
    expect(find.bySemanticsLabel('4, Tool, Wrench'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/equipment/presentation/pages/equipment_set_detail_figure_test.dart`
Expected: FAIL, no `DiverFigure` on the page and the l10n getters do not exist.

- [ ] **Step 3: Add the strings**

In `lib/l10n/arb/app_en.arb`, after the line `"equipment_fab_addSet": ...`, insert:

```json
  "equipment_figure_discLabel": "{number}, {type}, {name}",
  "equipment_figure_summary": "{name}, {count, plural, =1{1 item} other{{count} items}}",
  "equipment_figure_trayTitle": "Also carried",
```

In each other locale file, after its `"equipment_sets_itemCountSingular"` line, insert the three keys with these values. The disc label is the same everywhere except Arabic, which uses its own comma.

| Locale | discLabel | summary | trayTitle |
| --- | --- | --- | --- |
| ar | `{number}، {type}، {name}` | `{name}، {count, plural, =1{عنصر واحد} other{{count} عناصر}}` | `يُحمل أيضًا` |
| de | `{number}, {type}, {name}` | `{name}, {count, plural, =1{1 Gegenstand} other{{count} Gegenstände}}` | `Außerdem dabei` |
| es | `{number}, {type}, {name}` | `{name}, {count, plural, =1{1 artículo} other{{count} artículos}}` | `También se lleva` |
| fr | `{number}, {type}, {name}` | `{name}, {count, plural, =1{1 élément} other{{count} éléments}}` | `Également emporté` |
| he | `{number}, {type}, {name}` | `{name}, {count, plural, =1{פריט אחד} other{{count} פריטים}}` | `נלקח גם` |
| hu | `{number}, {type}, {name}` | `{name}, {count, plural, =1{1 tétel} other{{count} tétel}}` | `Egyéb felszerelés` |
| it | `{number}, {type}, {name}` | `{name}, {count, plural, =1{1 elemento} other{{count} elementi}}` | `Portato anche` |
| nl | `{number}, {type}, {name}` | `{name}, {count, plural, =1{1 item} other{{count} items}}` | `Ook meegenomen` |
| pt | `{number}, {type}, {name}` | `{name}, {count, plural, =1{1 item} other{{count} itens}}` | `Também levado` |
| zh | `{number}, {type}, {name}` | `{name}, {count, plural, =1{1 件} other{{count} 件}}` | `另外携带` |

Before writing a locale's plural, open that file's `equipment_components_count` value: if it carries more categories than `=1` and `other` (Arabic and Hebrew may), give the summary the same categories with the count spelled the way that entry does.

Then run `flutter gen-l10n` and stage the regenerated `lib/l10n/arb/app_localizations*.dart` with the ARB edits; they are tracked.

- [ ] **Step 4: Add the components index override to the default test**

In `test/features/equipment/presentation/pages/equipment_set_detail_default_test.dart`, add to the `overrides` list, next to the geofences override:

```dart
          equipmentComponentsIndexProvider.overrideWith(
            (ref) => Future.value(ComponentsIndex.fromRows(const [])),
          ),
```

with the imports `package:submersion/features/equipment/domain/services/components_index.dart` and `package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart`. The page now reads that provider, and a page test without a database must not reach the repository.

- [ ] **Step 5: Change the page**

Convert the page to a stateful consumer and add the figure. The full diff, expressed as the new shapes of the parts that change:

Imports to add:

```dart
import 'dart:async';

import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/figure/domain/figure_composer.dart';
import 'package:submersion/features/equipment/figure/domain/figure_inputs.dart';
import 'package:submersion/features/equipment/figure/domain/figure_model.dart';
import 'package:submersion/features/equipment/figure/presentation/diver_figure.dart';
import 'package:submersion/features/equipment/figure/presentation/figure_number_badge.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
```

The widget declaration becomes:

```dart
class EquipmentSetDetailPage extends ConsumerStatefulWidget {
  final String setId;

  const EquipmentSetDetailPage({super.key, required this.setId});

  @override
  ConsumerState<EquipmentSetDetailPage> createState() =>
      _EquipmentSetDetailPageState();
}

class _EquipmentSetDetailPageState extends ConsumerState<EquipmentSetDetailPage> {
  /// The item whose disc and row are highlighted, cleared after a moment.
  String? _selectedId;
  Timer? _flashTimer;
  final Map<String, GlobalKey> _rowKeys = {};

  String get setId => widget.setId;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  void _select(String id) {
    _flashTimer?.cancel();
    setState(() => _selectedId = id);
    _flashTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _selectedId = null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _rowKeys[id]?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.3,
          duration: const Duration(milliseconds: 300),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final setAsync = ref.watch(equipmentSetProvider(setId));

    return setAsync.when(
      data: (set) {
        if (set == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.equipment_setDetail_notFoundTitle),
            ),
            body: Center(
              child: Text(context.l10n.equipment_setDetail_notFoundMessage),
            ),
          );
        }
        return _buildContent(context, set);
      },
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.equipment_setDetail_loadingTitle),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.equipment_setDetail_errorTitle),
        ),
        body: Center(
          child: Text(context.l10n.equipment_setDetail_errorMessage('$error')),
        ),
      ),
    );
  }
```

`_buildContent` and `_buildEquipmentTile` drop their `WidgetRef ref` parameter and use the state's `ref`; `_handleMenuAction` likewise. In `_buildContent`, before the `Scaffold`, compute the arranged groups once and the figure model from them:

```dart
    final groups = arrangeEquipment(
      set.items ?? const <EquipmentItem>[],
      ref.watch(equipmentArrangementProvider),
      typeLabel: (type) => type.localizedName(context.l10n),
    );
    final ordered = [for (final group in groups) ...group.items];
    final components =
        ref.watch(equipmentComponentsIndexProvider).value ?? ComponentsIndex.empty;
    final model = composeFigure(figureInputsFromItems(ordered, components: components));
    final numberById = {for (final p in model.numbered) p.item.id: p.number};
```

and replace the `for (final group in arrangeEquipment(...))` loop with `for (final group in groups)`, passing `numberById[item.id]` into the tile. Between the header card's trailing `const SizedBox(height: 24),` and the "Equipment items" title, when `ordered.isNotEmpty`, insert:

```dart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DiverFigure(
                  model: model,
                  semanticsLabel: context.l10n.equipment_figure_summary(
                    set.name,
                    model.itemCount,
                  ),
                  selectedItemId: _selectedId,
                  onItemTap: (placed) => _select(placed.item.id),
                  discLabel: (placed) => context.l10n.equipment_figure_discLabel(
                    placed.number,
                    placed.item.type.localizedName(context.l10n),
                    placed.item.name,
                  ),
                  trayTitle: context.l10n.equipment_figure_trayTitle,
                ),
              ),
            ),
            const SizedBox(height: 24),
```

The tile gains the row key, the highlight, and the badge:

```dart
  Widget _buildEquipmentTile(
    BuildContext context,
    EquipmentItem item,
    Map<String, EquipmentRowLabel> labels,
    int? number,
  ) {
    final selected = item.id == _selectedId;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: _rowKeys.putIfAbsent(item.id, GlobalKey.new),
      margin: const EdgeInsets.only(bottom: 8),
      color: selected ? scheme.primaryContainer : null,
      child: ListTile(
        onTap: () => context.push('/equipment/${item.id}'),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (number != null) ...[
              FigureNumberBadge(
                number: number,
                selected: selected,
                onTap: () => _select(item.id),
              ),
              const SizedBox(width: 8),
            ],
            CircleAvatar(
              backgroundColor: scheme.tertiaryContainer,
              child: Icon(
                equipmentTypeIcon(item.type),
                color: scheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
        // title, subtitle and trailing exactly as before
```

Nothing else on the page changes: the app bar, the header card, the empty state, the geofence list and the menu actions keep their code.

- [ ] **Step 6: Run the page tests**

Run: `flutter test test/features/equipment/presentation/pages/`
Expected: PASS, including the three existing set detail test files. If `equipment_set_detail_geofence_test.dart` fails on the components provider, it uses a real database and the provider resolves there; the failure is then elsewhere and its message says where.

- [ ] **Step 7: Commit**

```bash
dart format lib/features/equipment lib/l10n test/features/equipment
git add lib/features/equipment/presentation/pages/equipment_set_detail_page.dart lib/l10n/arb test/features/equipment/presentation/pages
git commit -m "feat(figure): diver figure and numbered legend on the set page

Part of #2326"
```

---

### Task 13: Whole-branch verification

**Files:** none new.

- [ ] **Step 1: Format and analyze the whole project**

Run: `dart format . && flutter analyze`
Expected: `No issues found!`. CI treats infos as fatal, so any info-level finding is fixed, not ignored. The generated artwork file is protected by its `// dart format off` line; if `python3 tool/build_figure_artwork.py --verify` reports it stale after formatting, the line is missing from the generator's header.

- [ ] **Step 2: Run the architecture guards and the feature's tests**

Run: `flutter test test/architecture test/features/equipment test/core/icons`
Expected: all PASS. The provider-tick guard scans every new provider read; this phase adds none, so it should not speak.

- [ ] **Step 3: Run the l10n staleness check the way the pre-push hook does**

Run: `flutter gen-l10n && git status --short lib/l10n`
Expected: no output from `git status`, meaning the generated localizations are exactly what the ARB files produce.

- [ ] **Step 4: Run the full suite once**

Run: `flutter test`
Expected: all PASS. One full run is enough; do not overlap it with another test run on this machine.

- [ ] **Step 5: Report**

Do not push and do not open a PR. Report: the commit list, the test counts, and the PR description to use, which must contain `Part of #2326` on its own line and the summary below.

PR description:

```
Phase 1 of the diver figure program: an illustrated front-and-back diver drawn from a set's items, with numbered callouts matched to the set page's item list.

- Body-zone model and a placement table for all 41 equipment types, with variants from the BCD style, mount, weight style, pocket mount and tank material attributes
- Artwork as SVG under tool/figure, compiled by tool/build_figure_artwork.py into path strings with colour roles; a digest test keeps the generated file honest in CI
- Pure composer: numbering by display order, placement by canonical type order, children hidden, overflow to a tray
- Theme-derived palette tested across every preset and brightness
- DiverFigure widget with numbered discs (40 pt targets) and the set page numbering its list as the legend, with tap-to-highlight both ways

Spec: docs/superpowers/specs/2026-09-25-diver-figure-design.md

Part of #2326
```
