# Diver figure: visual representation of equipment sets and dive gear

Tracking issue: #2326. Status: approved 2026-09-25; labelling revised the same day after
the first build showed numbered discs could not be read at a glance (section 8).

## 1. Summary

An equipment set is shown today as rows grouped by type. This design adds an
illustrated diver, drawn front and back from the set's items, with numbered
callouts that match the existing item list. Gaps against a per-set required
list show as dashed callouts. Items may carry a colour that tints their
artwork. The figure appears on the set page, the set edit page, set list cards,
the item page, and the dive detail equipment section, and it can be shared as
an image, printed as a one-page gear sheet PDF, and included in the detailed
logbook PDF.

The artwork is authored as SVG files under `tool/figure/` and compiled to Dart
path strings, so one set of data draws on screen, in the share image, and in
PDFs through the PDF library's `drawShape`.

## 2. Goals and non-goals

Goals, in the diver's words:

1. Open a set and see at once what it contains.
2. See what a set is missing before a trip.
3. Share or print a gear sheet for a buddy, instructor, or operator.
4. See what was worn on a given dive.

Non-goals for this program:

- Photos of items (issue #2024) and any raster imagery on the figure.
- Body types, skin tone, hair, or a face. The figure is a neutral mannequin.
- Drag-to-place or any editing of where an item sits.
- Animation.
- Figures for the pre-dive runner or the statistics pages.

## 3. Decisions made during design

| Question | Decision |
| --- | --- |
| Figure style | Illustrated diver whose gear changes the picture, not a silhouette or a tile layout |
| View | Front and back pair, so every type has a visible anchor |
| Labels | Names on the figure, each led by a small number: label columns beside one figure with a Front / Back switch on a phone, name pills beside the gear on a pair on wider screens; the list keeps matching number badges |
| On or off | A per-set switch, off by default and off for every existing set: "Show diver figure" on the set edit page and Show / Hide in the set page's menu (section 8.7) |
| BCD position | Worn on the back: the bladder is drawn behind the tank and every BCD style labels on the back view; the front shows only straps, cummerbund, and inflator |
| What counts as a gap | A per-set required list, seeded from a per-diver default |
| How far the drawing adapts | Type, the choice attributes that already exist, and a new per-item colour |
| Base body | Neutral mannequin drawn from theme tones, no skin, no face |
| Sharing | Share as image, gear sheet PDF per set, and the figure in the detailed logbook PDF |
| Artwork pipeline | SVG sources compiled to Dart path data, drawn by a CustomPainter |
| Delivery | Six stacked PRs, one per phase, one tracking issue |

Rejected alternatives: a schematic silhouette (theme-safe but not what the
diver wanted), a kit layout with no person, a three-quarter view (hides the far
side), leader-line labels (no room for columns beside a pair on a phone),
tap-to-reveal labels (a shared image would carry no names), numbered discs
with the list as the only legend (built first, then dropped: a number says
nothing until you find it in the list, so the figure could not be read at a
glance), runtime SVG assets
(a new dependency and a second code path for PDFs), hand-written drawing code.

## 4. The body-zone model

### 4.1 Views and zones

`FigureView` is `front` or `back`. `FigureZone` is an enum of anchor points,
each with a view, an anchor coordinate in figure space, and a capacity. Figure
space is 200 wide by 400 tall, y down, shared by every piece of artwork.

Front zones: `head`, `face`, `hud`, `maskStrap`, `mouth`, `octo` (the right
chest), `chest` (chest-mount rebreather), `chestClipLeft`, `chestClipRight`,
`torsoFront`, `suit` (anchor on the left upper arm), `underlayer` (anchor on
the right upper arm, capacity 2), `wristLeft`, `wristRight`, `console`, `hands`, `handLeft`,
`handRight`, `cameraArm` (capacity 2), `hipLeft`, `hipRight`, `waist`,
`thighLeft`, `thighRight`, `calfLeft`, `ankles`, `feet`, `fins`, `dpv`,
`stageLeft`, `stageRight`.

Back zones: `backTank` (capacity 2), `backplate`, `wing`, `tankValve`
(capacity 2), `trimLeft`, `trimRight`, `buttDRing`, `sidemountLeft`,
`sidemountRight`.

A zone's anchor is where its label points, so it must sit on visible gear.
On the back the tank covers the centre line from the shoulders to the waist,
so `wing` anchors on the bladder's edge beside the tank (126, 150) and
`backplate` on the plate's edge (118, 176).

Every zone has capacity 1 unless stated. Zones are shared by types: `mouth`
takes a regulator or a second stage, whichever is placed first.

### 4.2 Placement table

`FigurePlacement.forType(type, attributes:, context:)` returns the candidate
zones in order, the artwork pieces (one per view, either optional) and the
default colour. `context` carries what the composer already knows about the
set: whether a sidemount harness or rebreather is present. The composer fills
the first candidate zone with room; a type with no candidates, or with every
candidate full, goes to the tray.

| Type | Candidate zones | Variants (attribute) | Default colour |
| --- | --- | --- | --- |
| regulator | mouth, octo | none | black |
| firstStage | tankValve | none | metal |
| secondStage | mouth, octo | none | black |
| hose | tray | none | black |
| bcd | wing (a BCD is worn on the back, so it shares the wing's zone; a rig has one or the other and a second goes to the tray) | `bcd_style`: jacket (default: straps, cummerbund and inflator in front, bladder behind the tank), back_inflate and wing (harness front piece plus a wing back piece), sidemount (harness front piece plus sidemount rigging on the back) | black |
| backplate | backplate | none | metal |
| wing | wing | none | black |
| harness | torsoFront | none | black |
| tankBand | tray | none | black |
| weightPocket | hipLeft, hipRight | `weight_style`: trim goes to trimLeft, trimRight | black |
| gearPocket | hipLeft, hipRight | `pocket_mount`: thigh goes to thighLeft, thighRight; waist_belt goes to waist | black |
| wetsuit | suit | none | dark blue |
| drysuit | suit | none | dark grey |
| undersuit | underlayer | none | mid grey |
| baselayer | underlayer | none | light grey |
| rashGuard | underlayer, suit (the canonical order places it before the suits, so it must not claim the suit zone first) | none | dark blue |
| fins | fins | none | black |
| mask | face | none | black |
| snorkel | maskStrap | none | black |
| computer | wristLeft, wristRight | `mount`: console goes to console, hud goes to hud | black |
| transmitter | tankValve | none | metal |
| instrument | console, wristLeft, wristRight | `mount`: wrist puts the wrists first | black |
| compass | wristRight, wristLeft | `mount`: console goes to console | black |
| tank | backTank, stageLeft, stageRight; with a sidemount harness or rebreather present: sidemountLeft, sidemountRight, stageLeft, stageRight | `tank_material`: steel is dark grey; the backTank piece is a single at count 1 and a manifolded pair at count 2 | aluminium |
| rebreather | backTank | `mount_configuration`: chest goes to chest, sidemount goes to sidemountLeft; the rebreather takes the whole zone | black |
| weights | waist | `weight_style`: integrated goes to hipLeft and hipRight, trim goes to trimLeft and trimRight, ankle goes to ankles | black |
| light | handLeft, chestClipLeft, chestClipRight | none | yellow |
| camera | handRight, handLeft | none | black |
| housing | handRight | none | black |
| strobe | cameraArm | none | black |
| smb | buttDRing, thighLeft | none | orange |
| reel | buttDRing, hipRight | none | black |
| knife | calfLeft, hipLeft | none | metal |
| tool | tray | none | metal |
| hood | head | none | black |
| gloves | hands | none | black |
| boots | feet | none | black |
| dpv | dpv | none | black |
| o2Cell | hidden when a child, tray when top-level | none | metal |
| battery | hidden when a child, tray when top-level | none | metal |
| other | tray | none | mid grey |

`hands` is a single zone for a pair of gloves, anchored between the wrists;
`handLeft` and `handRight` are the zones for things held.

### 4.3 Placement order versus numbering order

Two orders are involved and they are deliberately different:

- **Placement priority** is fixed: the composer walks the items in the
  canonical type order from `equipment_type_order.dart`, so an outer suit claims
  the `suit` zone before a rash guard can, and the first regulator claims
  `mouth` before an octopus. This order never changes with the diver's sort
  setting.
- **Numbering** follows the order the caller passes, which is the arranged
  display order of the page. Numbers therefore increase down the legend, and a
  change of sort renumbers the figure and the list together.

### 4.4 Children, parts, and the tray

- An item with a parent link, and any assembly part, is not drawn and not
  numbered. The parent carries the number. This covers O2 cells, batteries,
  and regulator stages recorded as components.
- The tray holds items whose type has no zone and items that overflowed their
  candidates. Tray items are numbered like any other, so the legend is
  complete. The tray is drawn as a row of small tiles under the figures, each
  tile the type icon from `equipmentTypeIcon` with its number badge.

### 4.5 Layers

Pieces are painted in a fixed layer order per view, low to high: body,
underlayer suits, outer suit, pockets, harness or BCD, chest-mounted gear,
tanks and wing (back view), hoses, waist items, hands and wrists, head items
(hood, mask, snorkel, HUD), fins and boots, tray. A covered layer (an undersuit
beneath a drysuit) is still painted and still gets its label; the outer layer
simply covers the artwork.

## 5. Artwork pipeline

### 5.1 Sources

`tool/figure/` holds one SVG per piece, drawn in the shared 200 by 400 figure
space, plus `manifest.json` declaring for each piece: `id`, `view`, `layer`,
and for each path in file order its colour role. The mannequin is two pieces,
`body_front` and `body_back`. Type pieces are named
`<type>[_<variant>]_<view>`, for example `bcd_jacket_front`,
`bcd_wing_back`, `tank_doubles_back`.

The generator accepts the SVG subset it needs: `path` elements with `d`,
plus `rect`, `circle`, and `ellipse`, which it converts to path data. A
`transform` attribute anywhere is rejected, as are gradients, filters,
strokes, text, `use`, and `image`, each with a message naming the file, so
every piece is authored in absolute figure space. Shading comes from separate
paths with the shade roles.

### 5.2 Generator and output

`tool/build_figure_artwork.py` (no third-party dependencies beyond the
standard library, like the glyph script) reads the sources and writes
`lib/features/equipment/figure/artwork/figure_artwork.gen.dart`:

```dart
// GENERATED by tool/build_figure_artwork.py. Do not edit.
// sources-digest: <sha256 of every source file and the manifest, sorted by name>
const figureArtwork = <String, FigurePieceData>{
  'body_front': FigurePieceData(
    view: FigureView.front,
    layer: 0,
    paths: [FigurePathData(role: FigureRole.body, d: 'M ...'), ...],
  ),
  ...
};
```

`--verify` checks: every type's default variant has a piece for at least one
view, every path parses, every path's bounds lie inside the figure box, every
role name is known, and every piece id in the manifest matches a source file.
Any failure exits 1. The check that every piece the placement table names
exists lives on the Dart side, where both the table and the generated map are
in scope (section 14).

The header digest is what keeps the checked-in artwork honest in CI, where
Python does not run: a Dart test recomputes the digest from `tool/figure/` and
fails when the generated file is stale. This mirrors the l10n staleness gate.

### 5.3 Parsing at runtime

Path strings become `ui.Path` objects through the `path_parsing` package,
already a transitive dependency, promoted to a direct one; a thirty-line
`PathProxy` adapter targets `dart:ui`. Parsed paths are cached per piece in a
process-wide map, so a list of thirty sets parses each piece once.

## 6. Colour roles and palette

Paths carry roles, never colours: `body`, `bodyShade`, `gearDark`,
`gearLight`, `metal`, `itemColor`, `itemShade`, `outline`.

`FigurePalette` resolves roles to colours:

- `body` and `bodyShade` derive from the theme: the body is `onSurface`
  blended onto `surface` at a fixed fraction, then adjusted until it clears a
  1.6:1 contrast against both `surface` and `surfaceContainer`, using the
  contrast helpers in `EquipmentSectionColors`. Four of the five theme presets
  collapse their secondary roles, so a role is never trusted as a tone.
- `gearDark`, `gearLight`, `metal`, and `outline` are fixed greys chosen once
  to read on both brightnesses.
- `itemColor` is the item's colour attribute when set, otherwise the type
  default from the placement table. `itemShade` is the same colour darkened by
  a fixed fraction, and its outline darkened further, so a white fin keeps an
  edge on a light surface.
- Number badges use `primary` and `onPrimary`; gap labels use the theme's
  warning colour resolved the way the service status indicator does.

`FigurePalette.light` is a fixed light palette used for the share image and
PDFs regardless of the app theme. The palette class is pure Dart (colours as
ARGB ints) so the PDF code can use it without Flutter.

## 7. Composer and model

Pure Dart, no Flutter import, under `lib/features/equipment/figure/domain/`.

```dart
class FigureItemInput {
  final String id;
  final EquipmentType type;
  final String name;
  final Map<String, String?> attributes; // choice keys and the colour hex
  final bool isChild;                     // parent link or assembly part
  final TankRole? tankRole;               // dive surfaces only
}

class FigureModel {
  final List<PlacedItem> placed;
  final List<PlacedItem> tray;
  final List<FigureGap> gaps;
  final int itemCount;                    // numbered items
}

class PlacedItem {
  final int number;
  final FigureItemInput item;
  final FigureZone? zone;                 // null for tray items
  final List<String> pieceIds;            // one per view drawn
  final int color;                        // resolved ARGB
}

class FigureGap {
  final int number;
  final EquipmentType type;
  final FigureZone zone;                  // the type's first candidate
}

FigureModel composeFigure(
  List<FigureItemInput> items, {
  Set<EquipmentType> requiredTypes = const {},
});
```

`composeFigure` numbers top-level items in input order, places them in
placement priority order, appends gaps numbered after the items, and reports
the tray. On dive surfaces a tank with a `tankRole` of sidemount left or right,
or stage, is placed by that role instead of the set rule.

## 8. Widget and interaction

### 8.1 `DiverFigure`

```dart
DiverFigure({
  required FigureModel model,
  required String semanticsLabel,          // the whole picture
  required String Function(PlacedItem) labelText,         // the item's name
  required String Function(FigureView, int) sideLabel,    // "Front · 8"
  FigureMode mode = FigureMode.pair,       // pair; thumbnail and locate later
  String? selectedItemId,
  int selectionSerial = 0,                 // bumped on every selection
  ValueChanged<PlacedItem>? onItemTap,
  String Function(PlacedItem)? itemSemantics,            // "3, BCD, Hollis SMS75"
  String? trayTitle,
})
```

The figures are drawn by `DiverFigurePainter` (unchanged). Labels are
widgets placed over it, positioned by two pure functions that take the model,
a `FigureLayout`, and each label's measured width, so both are unit-tested
without widgets:

- `labelColumns(model, view, layout, columnWidth)` for the phone layout.
- `labelPills(model, layout, maxPillWidth)` for the wide layout.

Each label is a small number badge followed by the item's name, truncated
with an ellipsis: up to two lines in a phone column, one line in a pill.
Every label has a tap target at least 40 pt tall, measured in tests on both
platforms; the row grows with the diver's text size so large text never
overflows it, and pill widths are measured at that text size.

### 8.2 Phone layout, under 600 pt wide

- A segmented Front / Back switch sits above the figure. Each segment shows
  its item count ("Front · 8", "Back · 3"). It opens on Front, and the choice
  is page-local state.
- One figure is centred at 36 percent of the width, so each column keeps
  about 96 pt at the set page's 326 pt box (a 390 pt phone) and a
  two-line name fits about 18 characters, for example "Scubapro Hydros" over
  "Pro". The space either side holds a label column.
- An anchor left of the figure's centre line labels on the left, right of it
  on the right; an anchor on the centre line goes to whichever side has fewer
  labels so far, in number order.
- Labels in a column stack in anchor height order. Each sits level with its
  anchor unless that would overlap the label above, in which case it moves
  down just enough. A thin leader line joins the label to a small dot on its
  anchor.

### 8.3 Wide layout, 600 pt and wider

- Both figures side by side, each at the 1:2 aspect, capped at 360 pt tall.
  The spare width is split evenly between the two margins and the gutter
  (the gutter between 12 and 220 pt), so pills have room on every side.
- Each placed item gets a pill beside its anchor on the outward side (left of
  the anchor for anchors left of the centre line, right otherwise), with a
  short leader tick. The pill's maximum width is a quarter of the available
  width, and it never reaches past the box edge or into the other figure.
- Pills are placed in number order; a pill that would overlap one already
  placed steps down by its own height plus a gap until it is clear.
- The share image and both PDFs (section 12) always use this layout, since
  their width is fixed.

### 8.4 Legend, tray, and tap linking

- The set page's list keeps a leading `FigureNumberBadge` per top-level row;
  child items and assembly parts get none. The number on a label and on its
  row always match.
- The tray ("Also carried") tiles show the number, the type icon, and the name.
- Tapping a label, a pill, or a tray tile selects the item: its row scrolls
  into view and flashes, using the contrast-derived highlight. Tapping a row's
  badge selects its label. The row's own tap still opens the item. Selection
  is page-local state.

### 8.5 Modes

- `pair`: the layouts above. The set page and the dive card.
- `thumbnail` (phase 4): front figure only, no labels, no tray, at about 40 by
  80 pt, with a warning dot when the model has gaps.
- `locate` (phase 4): the bare mannequin with only one item painted, and one
  label.

### 8.6 Accessibility

The painted figure carries a summary label built from the plural strings, for
example "Reef set, 9 items, 2 missing". Each label, pill, and tray tile is a
button whose semantics read "3, BCD, Hollis SMS75". Thumbnails carry only the
summary label.

### 8.7 The per-set switch

- `equipment_sets.show_figure` (v229), not null, default 0, so every set
  that existed before the column and every new set starts with the figure
  off. Added by an idempotent helper called from the upgrade step and the
  `beforeOpen` backstop, like the v220 auto-apply column. Sets sync as whole
  rows, so the flag syncs with no new registration.
- `EquipmentSet.showFigure`, read and written by the repository.
- The set edit page has a "Show diver figure" switch beside the default-set
  and auto-apply switches. The set page's overflow menu offers "Show diver
  figure" or "Hide diver figure" and saves at once.
- Off, the set page is exactly as it was before the figure: no figure card
  and no number badges on the list, since the numbers only mean something
  beside the figure.
- Every figure surface that belongs to a set follows its switch: the set
  list thumbnail (phase 4), the share image (phase 5), and the gear sheet
  PDF (phase 6). The dive detail figure is not tied to one set; phase 4
  decides whether it follows the dive's sets or its own switch.

## 9. Gaps

### 9.1 Diver default

A new `diver_settings` column `figure_required_types TEXT` holds a JSON array
of `EquipmentType` names. Null means "never set" and resolves to the built-in
seed: mask, fins, wetsuit, bcd, regulator, tank, computer. An empty array is a
real value and means nothing is required, which is why this codec differs from
the condition-rules codec that collapses empty to null. The column is added by
an `_assert...` helper called from both the upgrade step and `beforeOpen`, in
the same shape as the v206 condition settings columns. It is exposed on
`AppSettings` as `Set<EquipmentType>? figureRequiredTypes` with a
`setFigureRequiredTypes` notifier method.

Settings > Equipment > "Required for a complete set" lists every type with a
checkbox and a "Reset to the built-in list" action.

### 9.2 Per-set list

A new synced child table:

```dart
class EquipmentSetRequiredTypes extends Table {
  TextColumn get setId =>
      text().references(EquipmentSets, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentType => text()();
  IntColumn get updatedAt => integer().nullable().clientDefault(
      () => DateTime.now().millisecondsSinceEpoch)();
  TextColumn get hlc => text().nullable()();
  @override
  Set<Column> get primaryKey => {setId, equipmentType};
}
```

Schema rung: the next free one when phase 2 is cut. Phase 1 took 229 for
the per-set switch (228 is cylinder fills, #2364), so re-verify
against main and open PRs before choosing. The migration
creates the table and seeds one row per existing set and built-in type, so gap
spotting works for sets that predate the feature (see section 16).

`EquipmentSet` gains `requiredTypes: Set<EquipmentType>`, loaded with the set
and saved with it. `createSet` copies the diver default into the new rows.
The set edit page gets a "Required for this set" section below the item groups
with the same per-type checkboxes and a "Reset to my default" action.

Sync registration follows `equipmentSetItems` at every touch point: the hlc
target with composite key columns, the serializer's base table, incremental
export, parent-gated child, id resolver, fetch, upsert, record ids, delete;
the sync service's apply order right after `equipmentSets`, `entityHasUpdatedAt`
true, `parentRefs` from `setId`. A change to a set's required list stamps only
these rows, never the parent set, per the child-sync design. The row follows
the set's cascade on delete and joins the set items' wipe and adopt rules.

### 9.3 Satisfaction rules

A required type is satisfied by an item of that type in the set, or by one of
its substitutes:

| Required | Also satisfied by |
| --- | --- |
| regulator | rebreather |
| tank | rebreather |
| bcd | wing, backplate, harness |
| wetsuit | drysuit |
| drysuit | wetsuit |

Every other type is satisfied only by itself. A set with an empty required list
has no gaps.

### 9.4 What the diver sees

- A dashed label in the warning colour at the type's first candidate zone,
  reading "Missing: hood", placed by the same column or pill rules as the
  items and numbered after them.
- The legend ends with one "Missing: hood, exposure suit" line in the same
  colour, and the set page header count reads "9 items, 2 missing".
- The set list card's thumbnail shows a warning dot.
- On the set edit page, the figure sits above the item groups and redraws on
  every tick, so a gap disappears the moment its type is checked.

## 10. Item colour

- `AttributeKind.color` is added to the catalog, with a `color` attribute in a
  new `AttributeGroup.appearance` applied to every type except `o2Cell`,
  `battery`, and `other`. The value is `#RRGGBB` in `valueText`, so it needs
  no schema change and flows through sync, export, backup, and import like
  every other attribute.
- The attribute form renders the kind as a swatch row that opens a bottom
  sheet with the same fixed palette as `TagColors.predefined`, plus "none".
  The tags picker widget previews a tag chip, so the sheet is a sibling widget
  that shares the palette rather than the widget itself.
- With no colour set, the placement table's per-type default applies.
- Every figure mode, the share image, and both PDFs use the colour.

## 11. Other surfaces

- **Dive detail.** The figure sits inside the existing collapsible equipment
  card above `DiveGearTreeView`, composed from the same top-level gear rows the
  tree shows, with dive tank roles passed through for linked tanks. Dive tanks
  with no gear link are not drawn. The tree's rows gain the number badge, and
  the sort button renumbers both. No gap labels on a dive.
- **Set list.** The folder icon on each card becomes the thumbnail. The list
  already loads each set's items; the composer runs per card and the painter
  uses the shared path cache.
- **Item page.** A "Where it sits" card after the header shows the locate mode.
  It is omitted for tray types and child items.

## 12. Share image and PDFs

### 12.1 Share image

`DiverFigureImageRenderer.render({model, title, legendRows, missingLine})`
draws offscreen with a `PictureRecorder`, the way the certification card
renderer does: title, the pair with its name pills (the wide layout), and the
missing line, with `FigurePalette.light` on a white surface, at 2x. The set
page menu and the dive equipment card header gain a share action that hands the
bytes to `ExportService().exportImageAsPng` with the share sheet anchored, so
the existing save-to-photos, save-to-file, and share choices apply. File names
are `gear_<set>.png` and `dive_gear_<number>_<date>.png`.

### 12.2 Gear sheet PDF

`GearSheetPdfService.build({set, items, model, labels, units, dates})`
follows the plan slate service: the app's PDF fonts and theme, one A4
`MultiPage`, a title block (set name, diver name, date), the pair drawn as
vectors, and a table with number, type, name, brand and model, serial, and next
service due. The result goes to `sharePdfBytes`. The share sheet already offers
print on both mobile platforms, so the printing package is not needed.

`drawFigureOnPdf(PdfGraphics g, PdfPoint size, FigureModel model, FigureView
view, FigurePalette palette)` is the PDF painter, called from a
`pw.CustomPaint` painter callback. It applies a scale and a y-flip (PDF space
points up), then for each piece path sets the fill colour for its role, calls
`drawShape(d)`, and fills. Discs are `drawEllipse` plus `drawString`.

### 12.3 Detailed logbook template

Only the detailed template changes. Its equipment section becomes a row: the
vector pair on the left at about a quarter of the page height, the existing
field rows on the right, numbered to match the figure's labels. `PdfExportOptions` gains
`includeGearFigure`, default true, surfaced as a switch in the existing PDF
options sheet. Simple, PADI, and NAUI templates are untouched.

### 12.4 Layering

The figure model, composer, placement table, palette, and generated artwork
have no Flutter import, so the PDF code under `lib/core/services` uses them
directly. Only the painter, widget, and image renderer live in the feature's
presentation layer.

## 13. Localization

All new strings land in all eleven locales. Plural strings use CLDR categories
(the `=1` branch is the `one` category, so zero is spelled out where a locale
needs it):

- items-with-missing count line, missing line, tray heading ("Also carried")
- "Where it sits", "Share gear image", "Gear sheet"
- Settings: section title, "Required for a complete set", "Reset to the
  built-in list"; set edit: "Required for this set", "Reset to my default"
- Semantics labels for item labels and gap labels
- The phone switch: "Front · {count}" and "Back · {count}"; a gap label: "Missing: {type}"
- Gear sheet labels, passed to the PDF service as a labels record like the
  plan slate's, so the PDF is in the diver's language

## 14. Testing

- **Artwork:** digest staleness test; every type has a placement; every piece
  a placement names exists; every path parses; every path stays in the box.
- **Composer:** fill order, the sidemount rule, doubles at count 2, overflow to
  the tray, hidden children and parts, numbering follows input order, placement
  priority ignores input order, each substitution rule, empty required list,
  dive tank roles.
- **Palette:** iterate `AppThemeRegistry.presets` times `Brightness.values`
  and assert contrast floors for badge digit on badge, label text on the page,
  gap colour on body, body on surface. Never assert which role was picked.
- **Label layout:** column side assignment including centre anchors, stacking
  without overlap, level placement when there is room, truncation width; pill
  outward side, stepping without overlap, maximum width.
- **Widgets:** label and pill semantics, the switch shows counts and swaps
  views, phone versus wide by width, tap selects and flashes the row, badge
  selects the label, 40 pt targets on both platforms, thumbnail has no labels,
  locate has one, set page count line, edit page redraw on tick, list
  warning dot, item page card present and absent, dive card figure and
  renumbering after sort. Page tests use the same provider overrides as the
  existing set detail tests.
- **Rendering:** the image renderer test asserts dimensions and that the body
  region is painted; goldens are macOS-only here and skipped in CI. Visual
  review during development uses the throwaway-golden screenshot method.
- **Schema and sync:** a migration test for the rung; the suites that enumerate
  synced tables (hlc registration, parent refs, child hlc, serializer batch
  coverage, delete tombstones) demand the new table's registration.
- **Settings:** codec round trip including the empty array, notifier save,
  settings page toggles.
- **PDF:** gear sheet builds one page and contains the item names in its text
  stream; the PDF painter's role mapping and y-flip are pinned in pure Dart;
  the detailed template's equipment row honours the option.
- **Share:** the fake share sheet from the media tests verifies a PNG with the
  expected name.
- **Architecture guards:** run `test/architecture/` after adding files.

## 15. Delivery

Six stacked PRs, each branched from the previous, each saying `Part of #2326`
and the last `Closes #2326`. One implementation plan per phase, written just
before that phase is built against the code as it then stands.

1. **Figure core and set page.** Zones, placement table, `tool/figure/`
   sources for the mannequin and all 41 default pieces plus the attribute
   variants, generator with verify, generated artwork, path cache, palette,
   composer, painter, widget in pair mode, set page figure, legend badges,
   tap linking. Artwork is the bulk; it lands in batches reviewed on a
   contact sheet.
2. **Gaps.** Settings column and page, per-set table with rung and sync
   registration, satisfaction rules, gap labels, missing line, edit page live
   figure, list warning dot.
3. **Item colour.** Attribute kind, swatch sheet, per-type defaults, tinting.
4. **Other surfaces.** Dive detail figure and tree badges, set list
   thumbnails, item page locate card.
5. **Share image.** Offscreen renderer, share action on the set page and the
   dive card.
6. **PDFs.** Gear sheet service, detailed template row, export option.

File layout:

```
tool/figure/                                   SVG sources and manifest.json
tool/build_figure_artwork.py                   generator and --verify
lib/features/equipment/figure/domain/          zones, placement, composer, model, palette
lib/features/equipment/figure/artwork/         figure_artwork.gen.dart (generated)
lib/features/equipment/figure/presentation/    painter, widget, badge, image renderer
lib/core/services/pdf_templates/pdf_figure.dart the PDF painter
lib/core/services/export/pdf/gear_sheet_pdf_service.dart
```

## 16. Risks and open points

- **Artwork volume.** About 60 SVG pieces for 41 types and their variants.
  Mitigation: the placement table, mannequin, and pipeline land first, then
  pieces in batches; the verify step blocks a PR that leaves a type without
  its default piece.
- **Existing sets and the seed.** Sets that exist before phase 2 have no
  required rows. The migration seeds every existing set once from the
  built-in list, so gap spotting works for existing users; a diver who wants
  a partial set clears its list. This is the one call to confirm at spec
  review.
- **Theme contrast.** Fixed gear greys must read on ten schemes; the palette
  tests across every preset are the guard.
- **Thumbnail cost.** Bounded by the path cache and a composer that is linear
  in items.
