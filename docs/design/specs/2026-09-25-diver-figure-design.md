# Diver figure: visual representation of equipment sets and dive gear

Tracking issue: #2326. Status: approved 2026-09-25; labelling revised the same day after
the first build showed numbered discs could not be read at a glance (section 8);
scope cut on 2026-09-26 to the set page, the set edit page, the dive detail
page, and item colour (section 14).

## 1. Summary

An equipment set is shown today as rows grouped by type. This design adds an
illustrated diver, drawn front and back from the set's items, with every item
named on the figure and each name led by a small number that matches the item
list. Items may carry an optional colour that tints their artwork. The figure
is opt-in per set and appears on the set page and, while the set is being
edited, on the set edit page. A diver-wide setting, also off by default, adds
it to the equipment card on the dive detail page.

The artwork is authored as SVG files under `tool/figure/` and compiled to Dart
path strings, drawn by a `CustomPainter`.

## 2. Goals and non-goals

Goals, in the diver's words:

1. Open a set and see at once what it contains.
2. See each piece of gear in its own colour.
3. See what was worn on a given dive.

Non-goals for this program:

- Photos of items (issue #2024) and any raster imagery on the figure.
- Body types, skin tone, hair, or a face. The figure is a neutral mannequin.
- Drag-to-place or any editing of where an item sits.
- Animation.
- Any required list, completeness check, or missing-gear warning. A set holds
  whatever the diver puts in it, with no required number or type of items.
- Figures anywhere other than the set page, the set edit page, and the dive
  detail page: none on the set list, the item page, the pre-dive runner, or
  the statistics pages.
- Sharing the figure as an image, and the figure in any PDF export.

## 3. Decisions made during design

| Question | Decision |
| --- | --- |
| Figure style | Illustrated diver whose gear changes the picture, not a silhouette or a tile layout |
| View | Front and back pair, so every type has a visible anchor |
| Labels | Names on the figure, each led by a small number: label columns beside one figure with a Front / Back switch on a phone, name pills beside the gear on a pair on wider screens; the list keeps matching number badges |
| On or off | A per-set switch, off by default and off for every existing set: "Show diver figure" on the set edit page and Show / Hide in the set page's menu (section 8.7) |
| BCD position | Worn on the back: the bladder is drawn behind the tank and every BCD style labels on the back view; the front shows only straps, cummerbund, and inflator |
| How far the drawing adapts | Type, the choice attributes that already exist, and a new per-item colour |
| Base body | Neutral mannequin drawn from theme tones, no skin, no face |
| Artwork pipeline | SVG sources compiled to Dart path data, drawn by a CustomPainter |
| Delivery | Two PRs under one tracking issue (section 14) |

Rejected alternatives: a schematic silhouette (theme-safe but not what the
diver wanted), a kit layout with no person, a three-quarter view (hides the far
side), leader-line labels (no room for columns beside a pair on a phone),
tap-to-reveal labels (nothing readable at a glance), numbered discs
with the list as the only legend (built first, then dropped: a number says
nothing until you find it in the list, so the figure could not be read at a
glance), runtime SVG assets
(a new dependency), hand-written drawing code.

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
in scope (section 13).

The header digest is what keeps the checked-in artwork honest in CI, where
Python does not run: a Dart test recomputes the digest from `tool/figure/` and
fails when the generated file is stale. This mirrors the l10n staleness gate.

### 5.3 Parsing at runtime

Path strings become `ui.Path` objects through the `path_parsing` package,
already a transitive dependency, promoted to a direct one; a thirty-line
`PathProxy` adapter targets `dart:ui`. Parsed paths are cached per piece in a
process-wide map, so each piece is parsed once however often the figure is
rebuilt.

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
- Number badges use `primary` and `onPrimary`.

`FigurePalette.light` is a fixed light palette; the themed palette takes its
fixed gear greys from it. The palette class is pure Dart (colours as ARGB
ints).

## 7. Composer and model

Pure Dart, no Flutter import, under `lib/features/equipment/figure/domain/`.

```dart
class FigureItemInput {
  final String id;
  final EquipmentType type;
  final String name;
  final Map<String, String?> attributes; // choice keys and the colour hex
  final bool isChild;                     // parent link or assembly part
  final TankRole? tankRole;               // dive detail page only
}

class FigureModel {
  final List<PlacedItem> placed;
  final List<PlacedItem> tray;
  int get itemCount;                      // placed plus tray
}

class PlacedItem {
  final int number;
  final FigureItemInput item;
  final FigureZone? zone;                 // null for tray items
  final List<String> pieceIds;            // one per view drawn
  final int color;                        // resolved ARGB
}

FigureModel composeFigure(List<FigureItemInput> items);
```

`composeFigure` numbers top-level items in input order, places them in
placement priority order, and reports the tray. On the dive detail page a
tank with a `tankRole` of sidemount left or right, or stage, is placed by that
role instead of the set rule.

## 8. Widget and interaction

### 8.1 `DiverFigure`

```dart
DiverFigure({
  required FigureModel model,
  required String semanticsLabel,          // the whole picture
  required String Function(PlacedItem) labelText,         // the item's name
  required String Function(FigureView, int) sideLabel,    // "Front · 8"
  FigureMode mode = FigureMode.pair,       // the only mode
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
- Pills are placed in number order, each at the free spot nearest its anchor.
  A pill whose name does not fit on its outward side moves across when the
  other side has more room.

### 8.4 Legend, tray, and tap linking

- The set page's list keeps a leading `FigureNumberBadge` per top-level row;
  child items and assembly parts get none. The number on a label and on its
  row always match.
- The tray ("Also carried") tiles show the number, the type icon, and the name.
- Tapping a label, a pill, or a tray tile selects the item: its row scrolls
  into view and flashes, using the contrast-derived highlight. Tapping a row's
  badge selects its label. The row's own tap still opens the item. Selection
  is page-local state.

### 8.5 Mode

The figure has one mode, the pair described above, used on the set page, the
set edit page (section 10), and the dive detail page (section 11).

### 8.6 Accessibility

The painted figure carries a summary label built from the plural strings, for
example "Reef set, 9 items". Each label, pill, and tray tile is a button whose
semantics read "3, BCD, Hollis SMS75".

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
- The set edit page's live figure (section 10) follows the switch on the
  form, so turning it on shows the figure at once and turning it off hides it.

## 9. Item colour

- `AttributeKind.color` is added to the catalog, with a `color` attribute in a
  new `AttributeGroup.appearance` applied to every type except `o2Cell`,
  `battery`, and `other`. The value is `#RRGGBB` in `valueText`, so it needs
  no schema change and flows through sync, export, backup, and import like
  every other attribute.
- The colour is optional. The attribute form renders the kind as a swatch row
  that opens a bottom sheet with the same fixed palette as
  `TagColors.predefined`, plus "none". The tags picker widget previews a tag
  chip, so the sheet is a sibling widget that shares the palette rather than
  the widget itself.
- With no colour set, the placement table's per-type default applies.
- The figure on the set page and on the set edit page uses the colour.

## 10. Set edit page

- When the form's "Show diver figure" switch is on, the figure sits above the
  item groups, composed from the items currently ticked, so it redraws on
  every tick and untick before the set is saved.
- It is the same pair widget as on the set page, with the same numbering,
  labels, and tray, drawn from the ticked items that have a checkbox row (a
  retired member has none), in the order the page lists them. Each ticked
  row gets the matching number badge; tapping a name on the figure scrolls
  to and flashes that item's checkbox row, and tapping a row's badge brings
  the figure into view. When the switch is off, the edit page is exactly as
  it was before the figure.

## 11. Dive detail page

- A diver-wide switch, "Show diver figure on dives" under Settings >
  Appearance > Dives, stored as `diver_settings.show_dive_figure`: not null,
  default 0, so it is off for every diver, new and existing, and added in its
  own schema rung by an idempotent helper called from the upgrade step and the
  `beforeOpen` backstop. Off, the dive page is exactly as it was.
- On, the figure sits inside the collapsible equipment card, above the gear
  tree, composed from the tree's top-level rows in the tree's order (the
  diver's arrangement). An assembly's parts sit inside its row and are not
  drawn.
- A dive tank linked to a tank gear item (`dive_tanks.equipment_id`) passes
  its role, so sidemount, stage, and back-gas tanks sit where the dive used
  them. Dive tanks with no gear link are not drawn.
- Unlike the set pages, the dive figure carries no numbers: its labels and
  tray tiles show the name alone, each read as "BCD, Hollis SMS75", and the
  tree's rows carry no badge (issue #2774). The figure already names every
  item beside its gear, so a number on the gear list told the diver nothing
  new. Tapping a name on the figure scrolls to and flashes its row.

## 12. Localization

All new strings land in all eleven locales. Plural strings use CLDR categories
(the `=1` branch is the `one` category, so zero is spelled out where a locale
needs it):

- The figure's summary label and each item's semantics label
- The tray heading ("Also carried")
- The phone switch: "Front · {count}" and "Back · {count}"
- The per-set switch: "Show diver figure" on the edit page, and "Show diver
  figure" / "Hide diver figure" in the set page menu
- Item colour: the attribute's name, "None", and a screen-reader name for each
  swatch
- The dive switch's title and subtitle, and the dive figure's summary name

## 13. Testing

- **Artwork:** digest staleness test; every type has a placement; every piece
  a placement names exists; every path parses; every path stays in the box.
- **Composer:** fill order, the sidemount rule, doubles at count 2, overflow to
  the tray, hidden children and parts, numbering follows input order, placement
  priority ignores input order, an item's colour overrides its type default,
  and a malformed colour falls back to it.
- **Palette:** iterate `AppThemeRegistry.presets` times `Brightness.values`
  and assert contrast floors for badge digit on badge, label text on the page,
  and body on surface. Never assert which role was picked.
- **Label layout:** column side assignment including centre anchors, stacking
  without overlap, level placement when there is room, truncation width; pill
  outward side, moving across when the outward side is too narrow, placement
  without overlap, maximum width.
- **Widgets:** label and pill semantics, the switch shows counts and swaps
  views, phone versus wide by width, tap selects and flashes the row, badge
  selects the label, 40 pt targets on both platforms, the set page figure
  follows the per-set switch, the edit page figure redraws on tick and follows
  the form's switch, the colour swatch sheet sets and clears the colour, the
  dive figure follows the diver-wide switch, dive tank roles place linked
  tanks, and neither the dive figure nor the dive tree shows a number. Page
  tests use the same provider overrides as the existing set detail tests.
- **Rendering:** goldens are macOS-only here and skipped in CI. Visual review
  during development uses the throwaway-golden screenshot method.
- **Schema:** a migration test for each rung (`equipment_sets.show_figure`
  and `diver_settings.show_dive_figure`), including the `beforeOpen` backstop
  for a database already past it, and the sync fallback for a peer's payload
  that predates the dive switch.
- **Architecture guards:** run `test/architecture/` after adding files.

## 14. Delivery

Two PRs under issue #2326, each saying `Part of #2326` and the last
`Closes #2326`, each built from its own implementation plan written just
before it against the code as it then stands.

1. **Figure core and set page** (PR #2372). Zones, placement table,
   `tool/figure/` sources for the mannequin and every piece, generator with
   verify, generated artwork, path cache, palette, composer, painter, widget,
   set page figure, legend badges, tap linking, and the per-set switch.
2. **Item colour, the set edit page figure, and the dive figure.** Attribute
   kind, swatch sheet, per-type defaults, tinting, the live figure on the edit
   page, and the dive detail figure with its diver-wide switch.

Scope history: the design first planned six phases. On 2026-09-26 the gaps
phase (a per-diver and per-set required-types list with "Missing" labels and
warnings), the set list thumbnails, the item page's "where it sits" card, the
share image, and the PDFs (a gear sheet and the figure in the logbook) were
dropped: a set carries no required number or type of items. The dive detail
figure was dropped and restored the same day. The live figure on the set edit
page, first planned with the gaps, and the dive figure joined the colour
phase.

File layout:

```
tool/figure/                                   SVG sources and manifest.json
tool/build_figure_artwork.py                   generator and --verify
lib/features/equipment/figure/domain/          zones, placement, composer, model, palette
lib/features/equipment/figure/artwork/         figure_artwork.gen.dart (generated)
lib/features/equipment/figure/presentation/    painter, widget, labels, badge
```

## 15. Risks and open points

- **Artwork volume.** 65 SVG pieces for 41 types, their variants, and the
  back-view pieces. Mitigation: the placement table, mannequin, and pipeline
  landed first, then pieces in batches reviewed on a contact sheet; the verify
  step blocks a change that leaves a type without its default piece.
- **Theme contrast.** Fixed gear greys must read on ten schemes; the palette
  tests across every preset are the guard. Item colours are the diver's
  choice, so the outline and shade roles keep a light piece's edge visible on
  a light surface.
