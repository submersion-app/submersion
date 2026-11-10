# Tag Color Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tag editors keep a tag's current color, draw "no color" as the palette Blue, and offer 60 palette shades plus a custom color dialog (issue #4384).

**Architecture:** A pure-Dart palette module in `tags/domain` owns the shade lists, the lenient parse that `Tag.color` already uses, palette matching and hex input parsing. The picker becomes a stateful widget in its own file: a preview chip, a wrapping grid of hue columns of dots, an optional "current color" dot and a "+" dot that opens a custom dialog built from two small HSV controls. Callers hold the selection as a nullable string, so an untouched selection saves back exactly what was stored.

**Tech Stack:** Flutter, Riverpod, flutter_test, ARB localization (`flutter gen-l10n`). No new packages; `HSVColor` from Flutter.

**Spec:** `docs/design/specs/2026-11-09-tag-color-picker-design.md`

## Global Constraints

- `TagColors.predefined` keeps its 20 entries, values and order. Agency colors, the equipment palette and `swatchName` read it.
- No schema change, migration or rewrite of stored `colorHex` values.
- No-color fallback is `#3B82F6`. Light shades are Tailwind 300, dark shades Tailwind 700, exactly as tabled in the spec.
- `Tag.color` keeps today's lenient parse: anything it draws as a color today it still draws the same.
- Custom colors are returned as `#RRGGBB` in capitals. Hex input accepts six hex digits, optional `#`, surrounding whitespace ignored.
- Every dot owns `tagTapTarget(platform)` (48 touch, 32 pointer).
- New strings go into all 11 ARB files, translated. No em-dashes anywhere.
- The equipment color sheet and agency picker are untouched.

## Review Focus

1. A stored code in another casing (`#3b82f6`) opens with the Blue dot selected and, untouched, saves the original text. Test in Task 6.
2. A stored `FF0000` (no `#`) draws red, shows as the current dot, and the custom dialog opens on `#FF0000` with Use enabled. Tests in Tasks 4 and 5.
3. A stored unparseable value (`red`) draws Blue, shows the Blue dot selected with no current dot, and untouched saves `red`. Test in Task 5.
4. On a 320 dp wide phone dialog the grid wraps with no overflow and every dot keeps 48 dp. Test in Task 5.
5. Typing a grey (`#808080`) into the hex field leaves the hue slider where it was instead of jumping to red. Test in Task 4.

---

### Task 1: Palette module and the Blue fallback

**Files:**
- Create: `lib/features/tags/domain/tag_palette.dart`
- Modify: `lib/features/tags/domain/entities/tag.dart` (`Tag.color`)
- Test: `test/features/tags/domain/tag_palette_test.dart`, `test/features/tags/domain/entities/tag_test.dart`

**Interfaces:**
- Produces:
  - `enum TagShade { light, base, dark }`
  - `typedef TagPaletteEntry = ({int hue, TagShade shade, String hex});` (`hue` is the index into `TagColors.predefined`)
  - `const String tagDefaultColorHex = '#3B82F6';`
  - `const List<String> tagLightShades`, `const List<String> tagDarkShades` (20 each, hue order)
  - `List<TagPaletteEntry> get tagPalette` (60 entries, hue-major: light, base, dark per hue)
  - `Color? parseStoredTagColor(String? stored)`: today's `Tag.color` parse minus the fallback; null for null, empty or a parse failure
  - `Color drawnTagColor(String? stored)`: `parseStoredTagColor(stored) ?? TagColors.fromHex(tagDefaultColorHex)`
  - `String tagHexOf(Color color)`: `#RRGGBB` capitals, alpha ignored
  - `TagPaletteEntry? tagPaletteEntryFor(String? stored)`: the entry whose hex equals `tagHexOf(drawnTagColor(stored))`
  - `String? parseTagHexInput(String text)`: trimmed, optional `#`, exactly six hex digits, returns capitals `#RRGGBB`; else null

- [ ] **Step 1: Write failing tests** in `tag_palette_test.dart`:
  - `tagLightShades` and `tagDarkShades` have 20 entries and equal the spec table (assert Red `#FCA5A5`/`#B91C1C`, Blue `#93C5FD`/`#1D4ED8`, Slate `#CBD5E1`/`#334155`).
  - `TagColors.predefined` still has 20 entries starting `#EF4444` and ending `#64748B` (guard).
  - `tagPalette.length == 60`, `tagPalette[0] == (hue: 0, shade: TagShade.light, hex: '#FCA5A5')`, `tagPalette[31] == (hue: 10, shade: TagShade.base, hex: '#3B82F6')`.
  - `tagPaletteEntryFor(null)`, `('')`, `('red')` and `('#3b82f6')` all return the base Blue entry; `('FF0000')` returns null; `('#EF4444')` returns base Red; `('ef4444')` returns base Red.
  - `drawnTagColor('FF0000') == const Color(0xFFFF0000)`; `drawnTagColor(null) == const Color(0xFF3B82F6)`.
  - `parseTagHexInput`: `' #2e8b57 '` gives `'#2E8B57'`; `'2E8B57'` gives `'#2E8B57'`; `'#FFF'`, `'#GGGGGG'`, `'#2E8B571'`, `''`, `'#-00001'` give null.
  - `tagHexOf(const Color(0x80FF0000)) == '#FF0000'`.
  In `tag_test.dart`: a tag with null, empty and `'nothex'` `colorHex` has `color == const Color(0xFF3B82F6)`; `'FF0000'` stays `Color(0xFFFF0000)`.

- [ ] **Step 2: Run** `flutter test test/features/tags/domain` and expect compile failures for the missing symbols.

- [ ] **Step 3: Implement** `tag_palette.dart` and make `Tag.color` return `drawnTagColor(colorHex)`. `parseStoredTagColor` keeps the exact current body (`replaceFirst('#', '')`, `int.parse('FF$hex', radix: 16)`, catch to null). `parseTagHexInput` checks the pattern `^#?[0-9A-Fa-f]{6}$` before parsing.

- [ ] **Step 4: Run** `flutter test test/features/tags/domain test/features/certification_agencies test/features/equipment/presentation/equipment_color_names_test.dart` and expect PASS.

- [ ] **Step 5: Commit** `feat(tags): palette shades and a palette Blue for tags with no color`.

### Task 2: Strings and color names

**Files:**
- Modify: all 11 `lib/l10n/arb/app_*.arb` (keys inserted after `tags_manage_colorLabel` in each), regenerate `lib/l10n/arb/app_localizations*.dart` with `flutter gen-l10n`
- Create: `lib/features/tags/presentation/tag_color_names.dart`
- Test: `test/features/tags/presentation/tag_color_names_test.dart`

**Interfaces:**
- Produces ARB keys (English values):
  - `tags_color_shadeLight` "{color}, light"; `tags_color_shadeDark` "{color}, dark" (placeholder `color`, String)
  - `tags_color_current` "Current color, {code}" (placeholder `code`, String)
  - `tags_color_custom` "Custom color" (dot label and dialog title)
  - `tags_color_hexLabel` "Hex code"
  - `tags_color_hexError` "Enter six digits 0-9 or A-F, like #2E8B57"
  - `tags_color_use` "Use"
  - `tags_color_hueLabel` "Hue"; `tags_color_squareLabel` "Saturation and brightness"
- Produces `String tagColorName(AppLocalizations l10n, TagPaletteEntry entry)`: base shade is `equipmentColorName(l10n, entry.hex)`; light and dark wrap the base hue's name (`equipmentColorName(l10n, TagColors.predefined[entry.hue])`) in the shade strings.

- [ ] **Step 1: Write failing tests:** with `lookupAppLocalizations(const Locale('en'))`, base Teal is `'Teal'`, light Teal `'Teal, light'`, dark Slate `'Slate, dark'`; with `Locale('de')` dark Teal contains the German Teal name from `equipment_color_teal`.
- [ ] **Step 2: Run** the test; expect compile failure.
- [ ] **Step 3: Add the keys** to `app_en.arb` with `@` descriptions and placeholders, translate into ar, de, es, fr, he, hu, it, nl, pt, zh (keep each locale's own comma or separator style), run `flutter gen-l10n`, then implement `tagColorName`.
- [ ] **Step 4: Run** the test and `flutter analyze lib/l10n lib/features/tags`; expect PASS and no issues.
- [ ] **Step 5: Commit** `feat(tags): name the tag palette shades`.

### Task 3: HSV controls

**Files:**
- Create: `lib/features/tags/presentation/widgets/hsv_color_controls.dart`
- Test: `test/features/tags/presentation/widgets/hsv_color_controls_test.dart`

**Interfaces:**
- Produces:
  - `class SaturationValueSquare extends StatelessWidget { const SaturationValueSquare({super.key, required this.color, required this.onChanged}); final HSVColor color; final ValueChanged<HSVColor> onChanged; }`: saturation left to right 0 to 1, value bottom to top 0 to 1; tap and pan both report, clamped to the box; paints the hue's gradient and a ring at the current point; `Semantics(label: l10n.tags_color_squareLabel)`.
  - `class HueSlider extends StatelessWidget { const HueSlider({super.key, required this.color, required this.onChanged}); final HSVColor color; final ValueChanged<HSVColor> onChanged; }`: hue 0 to 360 left to right, keeps saturation and value; tap and pan; `Semantics(label: l10n.tags_color_hueLabel)`.

- [ ] **Step 1: Write failing tests** (pump in a 300x300 box under the l10n-wired test app): tapping the square's top-right corner reports saturation 1 and value 1 with the hue unchanged; bottom-left reports 0 and 0; a drag past the edge reports clamped values; tapping the slider's midpoint reports hue 180 with saturation and value unchanged.
- [ ] **Step 2: Run**; expect compile failure.
- [ ] **Step 3: Implement** with `GestureDetector` (`onTapDown`, `onPanDown`, `onPanUpdate`) and `CustomPaint`; size from `LayoutBuilder`.
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(tags): color square and hue slider`.

### Task 4: Custom color dialog

**Files:**
- Create: `lib/features/tags/presentation/widgets/custom_tag_color_dialog.dart`
- Test: `test/features/tags/presentation/widgets/custom_tag_color_dialog_test.dart`

**Interfaces:**
- Consumes: Task 1 `parseTagHexInput`, `tagHexOf`; Task 3 controls.
- Produces: `Future<String?> showCustomTagColorDialog(BuildContext context, {required Color initial, required String name})`: completes with capitals `#RRGGBB` on Use, null on Cancel or dismissal. Keys: `ValueKey('tag-color-hex')` on the field, `ValueKey('tag-color-use')` on Use.

- [ ] **Step 1: Write failing tests:**
  - Opened with `initial: Color(0xFFFF0000)`, the field reads `#FF0000` and Use is enabled; Use completes with `'#FF0000'`.
  - Typing `2e8b57` and Use completes with `'#2E8B57'`; the preview `TagChip` color is `Color(0xFF2E8B57)`.
  - Typing `#2E8B5` disables Use and shows `'Enter six digits 0-9 or A-F, like #2E8B57'`.
  - Tapping the square's top-right corner updates the field to the full-saturation, full-value color of the current hue.
  - Starting at `#2E8B57`, typing `#808080` leaves the `HueSlider`'s `color.hue` at the green hue (about 146), not 0.
  - Cancel completes with null.
- [ ] **Step 2: Run**; expect compile failure.
- [ ] **Step 3: Implement** as a `StatefulWidget` holding an `HSVColor` and a `TextEditingController`. Control changes rewrite the field with `tagHexOf`; a valid typed code sets the HSV from `HSVColor.fromColor`, keeping the previous hue when the new saturation is 0. The preview is `TagChip.unsaved(name: name, color: ..., dense: true)`.
- [ ] **Step 4: Run**; expect PASS.
- [ ] **Step 5: Commit** `feat(tags): custom tag color dialog`.

### Task 5: The picker

**Files:**
- Create: `lib/features/tags/presentation/widgets/tag_color_picker.dart`
- Modify: `lib/features/tags/presentation/widgets/tag_input_widget.dart` (delete `TagColorPicker` and `_ColorSwatch`, export or import the new file where callers need it)
- Test: rewrite `test/features/tags/presentation/widgets/tag_color_picker_test.dart`

**Interfaces:**
- Consumes: Tasks 1, 2 and 4.
- Produces: `class TagColorPicker extends StatefulWidget { const TagColorPicker({super.key, required this.selectedColor, required this.onColorSelected, this.nameController}); final String? selectedColor; final ValueChanged<String> onColorSelected; final TextEditingController? nameController; }`. Keys: `ValueKey('tag-color-${entry.hex}')` per palette dot, `ValueKey('tag-color-current')`, `ValueKey('tag-color-custom')`.
- State: `String? _current`, the latest off-palette value it was given (`tagPaletteEntryFor(value) == null`), set in `initState` and replaced in `didUpdateWidget`; never cleared.
- Selection: when `selectedColor == _current` the current dot is selected; otherwise the dot for `tagPaletteEntryFor(selectedColor)`.
- Taps: a palette dot reports its `hex`; the current dot reports `_current`; "+" awaits `showCustomTagColorDialog(initial: drawnTagColor(widget.selectedColor), name: <name text>)` and reports a non-null result.

- [ ] **Step 1: Write failing tests:**
  - One preview `TagChip` showing the typed name in `drawnTagColor(selectedColor)`; it follows typing.
  - 60 palette dots plus the custom dot; no current dot for `'#EF4444'`, `null` or `'red'`.
  - `selectedColor: null` marks the `#3B82F6` dot selected (semantics `isSelected`), and so does `'#3b82f6'`.
  - `selectedColor: 'FF0000'` shows the current dot, selected, labelled `'Current color, FF0000'`; tapping the base Red dot reports `'#EF4444'`; after the parent rebuilds with `'#EF4444'`, the current dot is still there and tapping it reports `'FF0000'`.
  - Rebuilding with a second off-palette value `'#123456'` replaces the current dot's label.
  - Dots are announced `'Teal'`, `'Teal, light'`, `'Teal, dark'`; the "+" dot `'Custom color'`.
  - "+" opens the dialog on `#FF0000` for `'FF0000'`; Use with `#2E8B57` reports `'#2E8B57'`; Cancel reports nothing.
  - Keep the existing tap-target group: each dot's size is at least 48 on Android and iOS and 32 on macOS, Windows and Linux.
  - At a 320 dp wide dialog on Android, `tester.takeException()` is null and the last hue's dots sit below the first hue's (the grid wrapped).
- [ ] **Step 2: Run**; expect failures.
- [ ] **Step 3: Implement.** Layout: `Column(preview, SizedBox(12), Wrap(spacing: 4, runSpacing: 8, children: [current dot?, ...20 hue columns of 3 dots, custom dot]))`. A dot is `Semantics(button: true, selected:, label:)` around a `GestureDetector` with `HitTestBehavior.opaque` in a `tagTapTarget` square, painting a 24 dp circle with a 2 dp `colorScheme.primary` ring when selected (ring space reserved always). The custom dot is an outlined circle with `Icons.add`.
- [ ] **Step 4: Run** the picker test; expect PASS.
- [ ] **Step 5: Commit** `feat(tags): compact tag color grid with current and custom colors`.

### Task 6: Callers keep the stored color

**Files:**
- Modify: `lib/features/tags/presentation/pages/tag_manage_page.dart` (`_showEditDialog`), `lib/features/tags/presentation/widgets/tag_merge_sheet.dart`
- Test: `test/features/tags/presentation/pages/tag_manage_page_test.dart`, `test/features/tags/presentation/widgets/tag_merge_sheet_test.dart`

**Interfaces:**
- Consumes: Task 5 `TagColorPicker`.
- Edit dialog: `String? selectedColor = tag.colorHex;` and the save writes `colorHex: color` unchanged (`copyWith` with a null keeps a null tag null). Create dialog unchanged.
- Merge sheet: `String? _selectedColor`, seeded with `mostUsed.tag.colorHex` and set to `stat.tag.colorHex` on each radio change; passed straight to `mergeTags(colorHex:)`.

- [ ] **Step 1: Write failing tests** (replace the three `'Select color #22C55E'` finders with `find.bySemanticsLabel('Green')`):
  - Editing a null-color tag, renaming it and saving records an update whose `colorHex` is null.
  - Editing a `'#3b82f6'` tag and saving untouched records `'#3b82f6'`.
  - Editing a null-color tag, tapping Blue and saving records `'#3B82F6'`.
  - Editing an `'FF0000'` tag, saving untouched records `'FF0000'`.
  - Merge sheet: most-used tag has null color, merging untouched passes `colorHex: null`; switching the kept tag to an `'#123456'` tag shows the current dot labelled with `#123456` and merging passes `'#123456'`.
- [ ] **Step 2: Run** both files; expect the new tests to fail.
- [ ] **Step 3: Implement** the two seeding changes and the nullable merge state.
- [ ] **Step 4: Run** `flutter test test/features/tags`; expect PASS.
- [ ] **Step 5: Commit** `fix(tags): keep a tag's color when it is edited or merged`.

### Task 7: Whole-branch checks

- [ ] **Step 1:** `dart format .` and `flutter analyze`; expect no issues.
- [ ] **Step 2:** `grep -rl "TagColorPicker\|TagManagePage\|TagMergeSheet" test` and run every hit, plus `test/features/tags test/features/certification_agencies test/features/equipment test/features/dive_log/presentation/profile_colors test/architecture test/shared`; expect PASS.
- [ ] **Step 3:** Capture the after screenshots with the same harness as the before shots (edit dialog for a null-color tag: desktop light, desktop dark, phone), plus the custom color dialog.
