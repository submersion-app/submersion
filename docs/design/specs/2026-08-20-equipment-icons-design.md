# Equipment icon set (issue #1189)

## Problem

Several `EquipmentType` values map to a metaphor rather than to the object.
Fins render as ocean waves, a mask as an eyeball, a knife as scissors, boots as
a hiking figure, a hood as a smiley, a reel as an infinity symbol, and a DPV as
a kick scooter. Wetsuit and drysuit share one hanger glyph. Issue #1189 reports
this as "the icons for the equipment are missing, or rather, there are some,
but they don't really fit the equipment".

The reporter attached a mockup of solid dive-gear silhouettes. No stock icon
font contains those shapes.

## Approach

Twenty-one types split three ways.

**Ten are drawn from scratch** because neither Material Icons nor Material
Design Icons has the shape: regulator, BCD, wetsuit, drysuit, rebreather, hood,
gloves, boots, reel, DPV.

**Five are remapped** to dive glyphs already present in the bundled MDI webfont
but not currently exposed: fins, mask, knife, weights, SMB.

**Six are left alone** because they are already right: dive computer,
transmitter, tank, light, camera, other.

## Delivery: a font, not widgets

The custom glyphs ship as a generated TrueType font, so `equipmentTypeIcon`
keeps returning `IconData` and none of its twelve call sites change.

This matters beyond convenience. `dive_edit_page.dart:3279` passes the result
into another widget's `IconData`-typed parameter, so a widget return type would
ripple past the twelve call sites into those widgets' signatures. A font also
inherits `IconTheme` size, colour and opacity, directionality and semantics for
free, where a `CustomPainter` would re-implement all of it and `flutter_svg`
would add a dependency plus runtime path parsing on every rebuild.

Cost is a few KB: Flutter's icon tree-shaker subsets the font at build time
because every `IconData` is `const`.

## Glyph authoring

`tool/equipment_glyphs.py` is the source of truth. Each glyph is composed from
overlapping primitives on a 24-unit grid: `circle`, `ellipse`, `rrect`, `poly`
and `bar` (a thick segment with round caps).

Two rules govern the geometry, both learned by rendering drafts rather than by
reasoning about them:

1. **Nonzero winding, not evenodd.** TrueType fills with the nonzero rule.
   Solid contours are wound clockwise and holes counter-clockwise. Previewing
   with `fill-rule="evenodd"` renders overlaps as holes that the real font
   fills solid.

2. **A hole must not extend beyond the shape it cuts.** Outside that shape the
   winding number is -1, which nonzero fills. A face opening that overshoots
   the hem comes back as a black bar.

`poly` normalises winding by signed area rather than trusting point order,
because `bar`'s offset points flip orientation with the segment's own
direction: a hand-ordered quad unions for a hose running right and subtracts
for one running left.

## Font generation

`tool/build_equipment_icon_font.py` reads the glyph definitions, converts each
24-unit path to a 1000-upem TrueType glyph, and writes
`assets/fonts/submersion-equipment.ttf`. It requires `fonttools`, is run by
hand when glyphs change, and its output is committed so no contributor needs
the toolchain to build the app.

Code points start at U+E900, inside the Unicode Private Use Area.

## Files

New:

- `tool/equipment_glyphs.py`: glyph geometry
- `tool/build_equipment_icon_font.py`: font builder
- `assets/fonts/submersion-equipment.ttf`: generated, committed
- `lib/core/icons/submersion_icons.dart`: a `const IconData` per custom glyph

Modified:

- `lib/core/icons/mdi_icons.dart`: five new MDI code points
- `lib/features/equipment/presentation/utils/equipment_type_icon.dart`: the mapping
- `pubspec.yaml`: font family declaration
- `test/features/equipment/presentation/equipment_type_icon_test.dart`

## Mapping

| Type | Was | Becomes |
| --- | --- | --- |
| regulator | `Icons.air` | `SubmersionIcons.regulator` |
| bcd | `Icons.checkroom` | `SubmersionIcons.bcd` |
| wetsuit | `Icons.dry_cleaning` | `SubmersionIcons.wetsuit` |
| drysuit | `Icons.dry_cleaning` | `SubmersionIcons.drysuit` |
| rebreather | `Icons.recycling` | `SubmersionIcons.rebreather` |
| hood | `Icons.face` | `SubmersionIcons.hood` |
| gloves | `Icons.pan_tool` | `SubmersionIcons.gloves` |
| boots | `Icons.hiking` | `SubmersionIcons.boots` |
| reel | `Icons.all_inclusive` | `SubmersionIcons.reel` |
| dpv | `Icons.electric_scooter` | `SubmersionIcons.dpv` |
| fins | `Icons.water` | `MdiIcons.divingFlippers` |
| mask | `Icons.visibility` | `MdiIcons.divingScubaMask` |
| knife | `Icons.content_cut` | `MdiIcons.knifeMilitary` |
| weights | `Icons.fitness_center` | `MdiIcons.weight` |
| smb | `Icons.flag` | `MdiIcons.divingScubaFlag` |

`MdiIcons.knifeMilitary` rather than `MdiIcons.knife`: rendering the outlines
showed `knife` is a chef's knife, while `knifeMilitary` has the guard and blade
of a dive knife.

`MdiIcons.divingScubaFlag` is a diver-down flag rather than a literal sausage
buoy. It is the closest dive-domain shape in the font and beats a generic flag.

## Testing

The existing test file keeps its two structural guarantees, which are the ones
that caught real bugs before: every type resolves to an icon, and only `other`
gets the generic glyph.

Changes:

- Drop "the two exposure suits deliberately share one glyph". They no longer
  do, and the issue named that as a defect.
- Update the DPV assertion from `Icons.electric_scooter`.
- Add: every custom glyph resolves to the `Submersion Equipment` font family,
  so a code point that never made it into the font fails here rather than
  rendering as tofu on a device.
- Add: the custom code points are distinct, so a copy-paste in the constants
  file cannot silently alias two types to one glyph.

The exhaustive switch keeps its missing `default:` arm, so a new
`EquipmentType` stays a compile error in `equipmentTypeIcon`.

## Out of scope

The reporter's "PS: CCR doesn't work at all" is about rebreather support, not
icons. It is too vague to act on and belongs in its own issue.
