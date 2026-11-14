# Equipment custom colours: picker, hex field and recent colours

Issue: #4537

## Why

A diver gives an equipment item a colour so the item, its list row and the
diver figure look like the real gear. Today the colour sheet offers only the
fixed `equipmentColorPalette` (the 20 tag colours plus Black and White), and
the presets sometimes miss: a forum user's orange mask is far more vivid than
the "Orange" swatch. Divers asked for a colour editor (Sidemount-Forum #147,
#154; promised in #155).

Success: a diver can match any real colour exactly, find that colour again
in one tap for their next item, and see the same colours on every device they
sync.

## Goals

1. The colour sheet offers a Custom choice that opens a picker (saturation and
   brightness square, hue slider) with a hex field for an exact `#RRGGBB`.
2. The 22 presets stay, as they are, as quick swatches.
3. A Recent row offers custom colours the diver has used before, merged from
   two sources:
   - a remembered list of the colours confirmed in the custom dialog, stored
     on the diver's settings and synced;
   - the off-palette colours already on the diver's own items.
4. A custom colour has an accessible name: the nearest named colour plus the
   code, for example "Orange (#FF6A00)".

## Non-goals

- Changing how colours are stored on items. The value stays `#RRGGBB` in the
  `color` attribute's `valueText`; `normalizeEquipmentColor` already accepts
  any code, and CSV import and export, sync and the diver figure read it
  unchanged.
- Changing the presets, their order or their names. `TagColors.predefined`
  keeps its 20 entries (see the tag picker spec, #4384, for why).
- A "forget this colour" action. The remembered list is capped, so old
  colours age out.
- Recent colours in the tag picker or the certification agency picker.
- Transparency. Codes are opaque `#RRGGBB`.

## Anti-goals

- Opening the sheet and closing it, or saving the item untouched, must never
  change the item's colour. An off-palette colour the item already has stays
  selectable in the sheet.
- Remembering a colour must not republish the diver's other settings (a
  gradient-factor or units change on another device must not be overwritten
  by a stale copy riding along with a colour pick).
- No swatch below the platform tap target (48 dp touch, 32 dp pointer); the
  sheet's existing swatches are 48 dp.

## Constraints

- Schema is at v363. A new rung adds one nullable column; it rewrites no
  stored values, so it needs no change-log rewrite or post-sync repeat.
- `before_open.dart` is at the 800-line guard; any before-open backstop goes in
  `before_open_settings_columns.dart`, as #4184's did.
- Every user-visible string goes through l10n, in every ARB file.
- Equipment can be shared between divers (#2046); `equipment.diver_id` is the
  owner.

## Approaches

**Remembered list storage** (the diver chose A):

- **A. A JSON list column on `diver_settings`, in the existing
  `listArrangement` sync fact group (chosen).** The group already carries
  `equipmentCollapsedGroups`, a JSON list with the same need: a frequent tap
  that must not stamp the settings row's clock. One nullable column, one rung,
  and the conflict catalogue, merge and settings plumbing are reused. A colour
  pick shares a clock with sorts and view modes, which only orders two
  near-simultaneous low-stakes changes.
- B. The same column under a new fact group of its own: a second clock column
  and new catalogue wiring for no behaviour a diver would notice.
- C. A synced table of colour rows: a new sync entity, serializer arms and
  delete tombstones for eight strings. Dropped.

**Gear colours:** a Drift query over `equipment_attributes` joined to
`equipment`. The in-memory equipment list does not carry attributes, so it
cannot supply them.

**Picker:** move the tag dialog's `SaturationValueSquare` and `HueSlider` to
`lib/shared/widgets/` and build one shared custom colour dialog whose preview
is a parameter. A colour picker package was rejected: a new dependency and a
picker that looks unlike the tag one.

## Design

### The sheet

```
Item colour
 (/) (o)(o)(o) ... 22 presets ... (o)(o)
 Recent
 (o) (o) (o) ...                      (+)
```

- Row 1, unchanged: None, then the 22 presets.
- A "Recent" label and row below, shown only when it has at least one colour.
  Its swatches are the same 48 dp `_Swatch`, labelled with the custom colour
  name. The "+" Custom swatch ends the Recent row; with no recent colours the
  label and row are omitted and "+" ends the preset row instead.
- Selection: the swatch equal to the item's current code is drawn selected,
  wherever it sits.
- Tapping a preset or a recent swatch pops it as today and writes nothing to
  settings: the remembered list changes only through the dialog's "Use", so a
  gear colour tapped in the row is not promoted into the synced list (agreed
  in design). Tapping "+" opens the
  custom dialog; "Use" there remembers the code (below) and pops the sheet with
  it. Cancel returns to the sheet unchanged.

### The Recent row's contents

Built from, in this order, de-duplicated by code, presets excluded, capped
at 12:

1. The item's current colour, when it is off the palette (so the sheet never
   hides it, as the tag picker keeps an off-palette tag colour).
2. The remembered list, most recent first.
3. The diver's gear colours: off-palette codes on items the current diver
   owns (`equipment.diver_id`), retired items included, ordered by the colour
   attribute's `updated_at`, newest first.

A pure function in the equipment domain merges the three lists so it is unit
tested without widgets. The sheet reads a provider that streams it.

### The remembered list

- Column `diver_settings.recent_equipment_colors`, nullable TEXT, a JSON array
  of `#RRGGBB` strings, most recent first, at most 8. Null and `[]` both read
  as empty.
- Joins `SyncFactGroups.diverSettingsListArrangement` (Dart key
  `recentEquipmentColors`), so writes stamp `list_arrangement_hlc`, not the row
  clock.
- Wired like `equipmentCollapsedGroups`: `ListArrangements` field and
  `copyWith`, `list_arrangement_columns.dart` both ways, a write method on
  the arrangement writes mixin that runs against the saved value once
  settings load, a conflict catalogue entry with an l10n field name, and the
  `sql_column_notes.generated.dart` entry.
- A codec (`encode`/`decode`) normalises each entry through
  `normalizeEquipmentColor`, drops invalid ones and duplicates, and trims to 8,
  so a malformed value from a peer reads as the valid part of itself.
- Remember: put the code first, remove its earlier copy, trim to 8. A preset
  code is never remembered (picked through the dialog by typing its hex, it is
  already a quick swatch).
- Remembering happens on "Use" in the custom dialog, not on item save (my
  call: the diver chose that colour; a cancelled item edit leaving it in the
  list is harmless and it ages out).

### The custom dialog

- Shared `showCustomColorDialog(context, initial:, title:, preview:)` in
  `lib/shared/widgets/`, built from the tag dialog: square, hue slider, hex
  field with its validation and error text, Cancel and Use. `preview` is a
  builder from the current colour to a widget.
- Tags keep their chip preview through it and their behaviour; the hex field
  and Use button keys become the shared dialog's (`custom-color-hex`,
  `custom-color-use`).
- Equipment's preview is a 36 dp swatch with the custom colour name beside it.
- It opens on the item's current colour, or the palette Blue (`#3B82F6`) when
  the item has none (my call).
- Hex input parsing (`parseTagHexInput`, accepting with or without `#`, any
  case) moves with it; tag-specific names stay as thin aliases or callers
  update.
- The l10n strings the dialog uses (`tags_color_custom`, `tags_color_hexLabel`,
  `tags_color_hexError`, `tags_color_use`, `tags_color_squareLabel` and the hue
  slider's) are tag-prefixed; the shared dialog takes the title from its
  caller and new neutral keys replace the rest (`common_color_*`), keeping the
  existing translations' wording.

### Names

- The nearest-named-colour search (CIE76 in Lab, today private to
  `dive_log/presentation/profile_colors/swatch_name.dart`) moves to
  `equipment/presentation/utils/equipment_color_names.dart` as
  `nearestEquipmentColor(Color)`; `swatchName` calls it.
- `equipmentColorName` keeps its exact preset names and changes only its
  fallback: an off-palette valid code reads "<nearest name> (#RRGGBB)" through
  a new l10n pattern; an invalid value still reads as itself. This reaches the
  form field, the detail page, the sheet's swatches and their semantics.

### Diver figure

No change. The rim is chosen from the actual colour's contrast against each
backdrop, so very light and very dark codes already get one. A pure `#000000`
loses the shade line (darkening black is black) as any near-black would;
accepted.

## Tests

- Codec: round trip, malformed JSON, invalid and duplicate entries, cap, null.
- Remember: move-to-front, cap, preset not remembered, runs against the saved
  value once settings load.
- Merge function: ordering, de-dup across sources, preset exclusion, current
  colour first, cap 12, empty.
- Gear colour query: owner scoping, retired included, newest first,
  case-insensitive de-dup, invalid values skipped.
- Migration test for the new rung (fresh and upgraded databases), the
  list-arrangement sync test with the new column, conflict catalogue coverage.
- Widgets: Recent row shown and hidden, "+" placement, selection of an
  off-palette current colour, dialog Use remembers and pops, Cancel keeps the
  sheet, semantics labels; tag dialog tests still pass through the shared
  dialog.
- Name: preset names unchanged, off-palette "Orange (#FF6A00)", invalid passes
  through, `swatchName` unchanged for profile swatches.

## Left to the builder

- File and widget names within the folders above.
- Whether the gear colour query lives on `EquipmentRepository` or a small
  query class beside it, following the repository's delegation pattern.
- Exact l10n key names for the new strings.
