# Tag color picker: keep the current color, more colors, custom colors

Issue: #4384

## Why

A diver edited a tag that a dive import had created and found they could not
choose the color it had: the tag now looks different from every other
imported tag, and the editor offers no way back.

The cause is in two places:

- Import paths call `TagRepository.getOrCreateTag(name)` without a color, so
  the tag is stored with a null `colorHex`. `Tag.color` draws a null color as
  `Colors.blue` (Material `#2196F3`), which is not one of the 20 swatches in
  `TagColors.predefined`.
- The edit dialog (`tag_manage_page.dart`) and the merge sheet
  (`tag_merge_sheet.dart`) seed the selection with
  `tag.colorHex ?? TagColors.predefined.first`. Opening a null-color tag
  therefore preselects Red, and Save writes `#EF4444` even when the diver only
  renamed it.

UDDF imports can also bring any `#RRGGBB` from another app, which no palette
contains, and the editor drops that too.

The reporter also asked for more colors to choose from.

## Goals

1. Opening a tag's editor and saving without touching the color never changes
   the color the tag shows.
2. A tag with no stored color looks the same as a tag colored with the
   palette's Blue, and the picker shows Blue selected for it.
3. Divers can choose from 60 palette colors: each of the 20 current hues in a
   light, base and dark shade.
4. Divers can choose any color through a custom color dialog.

## Non-goals

- Giving imported tags a color when they are created. They keep a null
  `colorHex`; only how null is drawn changes.
- Rewriting stored tag colors. No migration, no backfill, no schema change.
- The equipment color sheet and the certification agency picker. They keep
  their current palettes.
- Remembering recently used custom colors.
- Changing how tags created inline in the dive editor pick their color (they
  keep rotating through the 20 base colors).

## Anti-goals

- Recoloring anything the diver did not touch. In particular,
  `TagColors.predefined` keeps its 20 entries in their current order:
  `agencyColorFor` in `certification_agencies/domain/agency_colors.dart`
  picks `predefined[hash % length]`, and `equipmentColorPalette`,
  `equipmentColorName` and `swatchName` are built on it. Changing its length
  or order would silently recolor agency badges and rename profile swatches.
- A picker whose swatches shrink below the platform tap target
  (`tagTapTarget`: 48 dp touch, 32 dp pointer).

## Design

### Palette

- `TagColors.predefined` is unchanged: these are the base shades (Tailwind's
  500 step for each hue).
- New lists, in the same hue order, for the light shades (Tailwind 300) and
  the dark shades (Tailwind 700):

  | Hue | Light | Base | Dark |
  | --- | --- | --- | --- |
  | Red | `#FCA5A5` | `#EF4444` | `#B91C1C` |
  | Orange | `#FDBA74` | `#F97316` | `#C2410C` |
  | Amber | `#FCD34D` | `#F59E0B` | `#B45309` |
  | Yellow | `#FDE047` | `#EAB308` | `#A16207` |
  | Lime | `#BEF264` | `#84CC16` | `#4D7C0F` |
  | Green | `#86EFAC` | `#22C55E` | `#15803D` |
  | Emerald | `#6EE7B7` | `#10B981` | `#047857` |
  | Teal | `#5EEAD4` | `#14B8A6` | `#0F766E` |
  | Cyan | `#67E8F9` | `#06B6D4` | `#0E7490` |
  | Sky | `#7DD3FC` | `#0EA5E9` | `#0369A1` |
  | Blue | `#93C5FD` | `#3B82F6` | `#1D4ED8` |
  | Indigo | `#A5B4FC` | `#6366F1` | `#4338CA` |
  | Violet | `#C4B5FD` | `#8B5CF6` | `#6D28D9` |
  | Purple | `#D8B4FE` | `#A855F7` | `#7E22CE` |
  | Fuchsia | `#F0ABFC` | `#D946EF` | `#A21CAF` |
  | Pink | `#F9A8D4` | `#EC4899` | `#BE185D` |
  | Rose | `#FDA4AF` | `#F43F5E` | `#BE123C` |
  | Stone | `#D6D3D1` | `#78716C` | `#44403C` |
  | Zinc | `#D4D4D8` | `#71717A` | `#3F3F46` |
  | Slate | `#CBD5E1` | `#64748B` | `#334155` |

- Chips stay readable at either end: `tagChipColorsFor` paints a 15 per cent
  tint with a full-strength border and lightness-adjusted label that clears
  WCAG AA, so no shade or custom color needs special handling.

### No-color fallback

- `Tag.color` draws a null, empty or unparseable `colorHex` as the palette
  Blue `#3B82F6` instead of `Colors.blue`. Nothing stored changes.
- "Unparseable" keeps today's meaning: whatever `Tag.color`'s current parse
  rejects. Its parse stays as lenient as it is now. UDDF imports store the
  raw `<color>` text unchecked, so a stored value can be `FF0000` (drawn red
  today), an 8-digit code, or `red`; any value drawn as a real color today
  keeps drawing as that same color. Only the values that already fell back to
  Material blue move to the palette Blue. (Builder's call, from the anti-goal
  of never recoloring what the diver did not touch.)
- Every picker treats a null `colorHex` as Blue selected. Saving without
  touching the color writes back what was there: a null stays null (the
  diver did not choose Blue; the tag simply has no color).
- A diver who taps the Blue dot, or enters `#3B82F6` in the custom dialog,
  on a null-color tag has chosen Blue, and `#3B82F6` is saved. The picker's
  selection can be null ("no color, drawn as Blue"), which is a different
  value from `#3B82F6`, so a plain comparison of the selection with the
  opening value decides what is saved; no separate "touched" flag is needed.
  (Builder's call.)

### The picker (layout B, chosen from mockups)

Used by the create dialog, the edit dialog and the merge sheet: the existing
`TagColorPicker` is replaced, keeping its role and call sites.

- A single preview chip at the top shows the tag's name (live from the name
  field) in the selected color, using `TagChip.unsaved`. It replaces the 20
  chip-shaped swatches.
- Below it, every palette color is a round dot. Each hue is a column of three
  dots: light, base, dark from top to bottom. The 20 columns wrap to the
  available width (about ten across on desktop, fewer on a phone).
- Every dot owns the platform tap target (`tagTapTarget`); the grid grows
  taller on a phone rather than the dots shrinking.
- When the selected color is not one of the 60 palette colors, an extra
  "current color" dot leads the grid, selected, drawn the way `Tag.color`
  draws the stored value. Matching against the palette uses the color as
  drawn: `FF0000`, `#ff0000` and `#FF0000` all match a palette entry with the
  same RGB, and that palette dot is shown selected instead of a current dot.
  The current dot stays in the grid for the life of the dialog, so a diver
  who taps a palette dot can tap back to it; tapping it restores the exact
  stored text. There is at most one current dot: the latest off-palette color
  the dialog was given or produced replaces any earlier one.
- A "+" dot ends the grid and opens the custom color dialog.
- The selected dot wears a ring in the theme's primary color, as the current
  swatches do.

### Custom color dialog (option B, chosen from mockups)

- A small dialog over the editor: a preview chip of the tag, a
  saturation/brightness square, a hue slider under it, a hex field, and Cancel
  and Use.
- It opens on the color currently selected in the grid, as drawn. For a
  stored value that is not a plain `#RRGGBB` (an imported `FF0000` or an
  8-digit code), the square, the slider and the hex field start on the
  drawn color's `#RRGGBB`, so Use is enabled from the start.
- Dragging or tapping the square or the slider updates the preview and the hex
  field live. Typing a valid hex code moves the square and the slider to
  match.
- The hex field accepts six hex digits with or without a leading `#`,
  surrounding whitespace ignored. While the text is not a valid code, Use is
  disabled and the field shows an error line saying what it expects.
- Use returns the color as `#RRGGBB` in capitals and selects it in the grid.
  If it matches a palette color, that palette dot is selected; otherwise it
  becomes the "current color" dot (replacing any earlier one).
- Cancel returns without changing the selection.
- The square and the slider take mouse and touch. Keyboard and screen-reader
  users set a color through the hex field.

### Saving

- The create dialog, the edit dialog and the merge sheet save the selected
  color. When the selection is still the color the dialog opened with, they
  save that original value unchanged (including null, and including the
  original casing of an imported code).
- A new tag created from the manage page still starts on the first base color
  (Red), as today.
- In the merge sheet, picking which tag's name to keep also picks that tag's
  color, as today; a null-color tag now selects Blue (shown) and saves null.
  Each such pick resets the merge's "opening value" to that tag's stored
  `colorHex`, and if that color is off the palette it becomes the current
  dot, replacing the previous one. A pick of a tag whose color is on the
  palette leaves the current dot in place. (Builder's call: the caller owns
  the opening value and passes it to the picker, so the picker does not need
  to know about merges.)

### Accessibility and language

- Each dot is announced by name: the hue's localized name for a base shade
  (the existing `equipment_color_*` strings), and the hue's name with "light"
  or "dark" for the other shades, for example "Teal, dark". The current-color
  dot is announced as the current color with its code; the "+" dot as
  "Custom color".
- New strings (shade wording, the custom dialog's title, field label, error
  line and Use button, the current-color and custom-color labels) go into all
  11 ARB files, translated.

## Builder's calls

- Widget structure and file split (the picker, the square, the slider and the
  dialog as separate small files under `lib/features/tags/presentation/`).
- Where the light and dark lists and the shade-name lookup live, as long as
  `TagColors.predefined` is untouched.
- Exact dot size inside the tap target, spacing, and the square's size.
- The HSV conversion: Flutter's `HSVColor` is enough; no new package.
- Test layout and how the gesture tests drive the square and slider.
