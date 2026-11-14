# Equipment Custom Colours Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task (inline, per the build-feature workflow). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a diver give an equipment item any `#RRGGBB` colour through a
custom picker, and offer recently used custom colours (a synced remembered
list plus the colours on their gear) in the colour sheet.

**Architecture:** The tag custom-colour dialog and its HSV controls move to
`lib/shared/widgets/color_picker/` and take their preview as a parameter.
The remembered list is a JSON column on `diver_settings` in the
`listArrangement` sync fact group, wired like `equipmentCollapsedGroups`
(#4184). Gear colours come from a Drift query over `equipment_attributes`.
A pure function merges the row; the colour field reads both sources on tap
and hands them to a plain sheet widget.

**Tech Stack:** Flutter, Drift, Riverpod (StateNotifier settings, FutureProvider
with `invalidateSelfWhen`), ARB l10n (11 locales).

**Spec:** `docs/design/specs/2026-11-14-equipment-custom-colors-design.md`

## Global Constraints

- Stored colour format stays `#RRGGBB` uppercase via `normalizeEquipmentColor`.
- Remembered list: at most 8, most recent first. Recent row: at most 12.
- Presets (`equipmentColorPalette`, 22 codes) never appear in the Recent row
  and are never remembered.
- Only the custom dialog's "Use" writes the remembered list; tapping any
  swatch writes no setting.
- Schema rung v364 (renumber if main takes 364 before merge); nullable column,
  no backfill, floor does not move.
- New strings go into all 11 ARB files with real translations, inserted by
  anchor line (never JSON round-trip an ARB); run `flutter gen-l10n` after the
  translations are in.
- Custom colour name pattern: "<nearest name> (<code>)", e.g. "Orange (#FF6A00)".
- No em-dashes anywhere; no emojis; `dart format .` before each commit.

## Review Focus

1. A remembered list from a peer holding junk (`["red", "#12345", 7]`, or not
   JSON at all) must read as its valid entries, never throw in the sheet.
   Pinned in Task 3 codec tests.
2. A colour stored in lowercase (`#ff6a00`, from CSV) and the same colour in
   the remembered list must show once. Pinned in Task 5 merge tests and
   Task 4 query tests.
3. Typing a preset's hex in the dialog picks it but does not remember it, and
   it is drawn selected among the presets, not duplicated in Recent. Pinned
   in Tasks 3 and 5.
4. Opening the sheet for an item whose off-palette colour is in neither
   source still shows it, selected, first. Pinned in Task 5 widget test.
5. Gear colour lookup failing (DB error) must still open the sheet with the
   presets. Pinned in Task 6 field test.

---

### Task 1: Shared custom colour dialog

**Files:**
- Create: `lib/shared/widgets/color_picker/color_hex.dart`
- Move: `lib/features/tags/presentation/widgets/hsv_color_controls.dart` to
  `lib/shared/widgets/color_picker/hsv_color_controls.dart`
- Create: `lib/shared/widgets/color_picker/custom_color_dialog.dart`
- Modify: `lib/features/tags/domain/tag_palette.dart` (drop `tagHexOf`,
  `parseTagHexInput`, `_hexInput`; use `colorHexOf`)
- Modify: `lib/features/tags/presentation/widgets/custom_tag_color_dialog.dart`
  (becomes a thin caller of the shared dialog)
- Modify: `lib/features/tags/presentation/widgets/tag_color_picker.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb` (rename keys), generated
  `app_localizations*.dart`
- Test: move `test/features/tags/presentation/widgets/hsv_color_controls_test.dart`
  to `test/shared/widgets/color_picker/`; create
  `test/shared/widgets/color_picker/color_hex_test.dart` (the
  `parseTagHexInput` / `tagHexOf` groups from `tag_palette_test.dart`, moved);
  update `custom_tag_color_dialog_test.dart` keys.

**Interfaces:**
- Produces:
  - `String colorHexOf(Color color)` (capitals, alpha dropped)
  - `String? parseColorHexInput(String text)` (trims, optional `#`, any case)
  - `Future<String?> showCustomColorDialog(BuildContext context, {required Color initial, required String title, required Widget Function(Color color) preview})`
    completing with `#RRGGBB` capitals or null on cancel. Hex field key
    `ValueKey('custom-color-hex')`, Use button key `ValueKey('custom-color-use')`.
  - l10n keys renamed (values and translations unchanged):
    `tags_color_custom` to `common_color_custom`, `tags_color_hexLabel` to
    `common_color_hexLabel`, `tags_color_hexError` to `common_color_hexError`,
    `tags_color_use` to `common_color_use`, `tags_color_hueLabel` to
    `common_color_hueLabel`, `tags_color_squareLabel` to
    `common_color_squareLabel`.

- [ ] **Step 1:** Move the tests first: `git mv` the HSV test, create
  `color_hex_test.dart` with the moved groups renamed to the new functions,
  and change `custom_tag_color_dialog_test.dart` to find
  `ValueKey('custom-color-hex')` / `ValueKey('custom-color-use')`.
- [ ] **Step 2:** Run
  `flutter test test/shared/widgets/color_picker test/features/tags`.
  Expected: compile failures (new paths and names not there yet).
- [ ] **Step 3:** Rename the l10n keys with a word-boundary `sed` across
  `lib/l10n/arb/*.arb`, `lib/l10n/arb/app_localizations*.dart`, `lib/` and
  `test/` (the `@tags_color_*` metadata too). Then `flutter gen-l10n`.
- [ ] **Step 4:** `git mv` the HSV controls, create `color_hex.dart` and
  `custom_color_dialog.dart` (body lifted from `_CustomTagColorDialog`, with
  the chip replaced by `preview(currentColor)` wrapped in `ExcludeSemantics`,
  and `title` as the AlertDialog title). `showCustomTagColorDialog` keeps its
  signature and calls `showCustomColorDialog(title: l10n.common_color_custom,
  preview: (c) => TagChip.unsaved(name: name, color: c))`.
- [ ] **Step 5:** Run
  `flutter test test/shared/widgets/color_picker test/features/tags`.
  Expected: PASS.
- [ ] **Step 6:** `dart format .`, `flutter analyze`, `flutter test test/architecture/`, then commit
  `refactor(tags): share the custom colour dialog`.

### Task 2: Names for custom colours

**Files:**
- Modify: `lib/features/equipment/presentation/utils/equipment_color_names.dart`
- Modify: `lib/features/dive_log/presentation/profile_colors/swatch_name.dart`
- Modify: all 11 ARBs (new `equipment_color_customName`), generated l10n
- Test: `test/features/equipment/presentation/equipment_color_names_test.dart`,
  existing swatch name tests (find with `grep -rl swatchName test`)

**Interfaces:**
- Produces:
  - `String nearestEquipmentColor(Color color)`: the palette code (from
    `equipmentColorPalette`) with the least CIE76 distance; the Lab math moves
    here from `swatch_name.dart`.
  - `equipmentColorName(l10n, hex)`: presets unchanged; a valid off-palette
    code returns `l10n.equipment_color_customName(name, code)`; an invalid
    value returns itself.
  - ARB: `"equipment_color_customName": "{name} ({code})"` with both
    placeholders `String`, placed after `equipment_color_white` in each file.

- [ ] **Step 1: Write the failing tests**

```dart
test('off-palette code reads as nearest name and code', () {
  expect(equipmentColorName(l10n, '#FF6A00'), 'Orange (#FF6A00)');
  expect(equipmentColorName(l10n, '#ff6a00'), 'Orange (#FF6A00)');
});
test('presets keep their plain names', () {
  expect(equipmentColorName(l10n, '#F97316'), 'Orange');
});
test('an invalid value passes through', () {
  expect(equipmentColorName(l10n, 'Red'), 'Red');
});
test('nearestEquipmentColor finds the closest preset', () {
  expect(nearestEquipmentColor(const Color(0xFF0A0A0A)), equipmentColorBlack);
});
```

  Check `'#FF6A00'` really lands on Orange `#F97316` (CIE76) before fixing the
  expectation; pick a code that does if not.
- [ ] **Step 2:** Run `flutter test test/features/equipment/presentation/equipment_color_names_test.dart`. Expected: FAIL.
- [ ] **Step 3:** Add the ARB key with translations in all 11 files, run
  `flutter gen-l10n`, implement `nearestEquipmentColor`, change the
  fallback, and make `swatchName` return
  `equipmentColorName(l10n, nearestEquipmentColor(color))`.
- [ ] **Step 4:** Run the names test and the swatch name tests. Expected: PASS
  (profile swatch names unchanged).
- [ ] **Step 5:** Format, analyze, commit `feat(equipment): name custom colours by their nearest colour`.

### Task 3: Remembered colours on the diver's settings

**Files:**
- Modify: `lib/core/database/tables/diver_tables.dart` (column after
  `equipmentCollapsedGroups`)
- Modify: `lib/core/database/database.dart` (`currentSchemaVersion = 364`, add
  `364` with a comment to the version list after `363`)
- Create: `lib/core/database/migrations/helpers/recent_equipment_colors_migrations.dart`
  (extension `RecentEquipmentColorsMigrations`, `_assertRecentEquipmentColorsColumn()`
  via `_addColumnIfMissing('diver_settings', 'recent_equipment_colors', 'TEXT')`)
- Modify: `lib/core/database/migrations/app_database_migrations.dart` (part),
  `migrations/ladder/rungs_v340_onward.dart` (v364 rung + `reportProgress`),
  `migrations/before_open_settings_columns.dart` (backstop)
- Modify: `lib/core/services/sync/sync_fact_groups.dart`
  (`'recentEquipmentColors': 'recent_equipment_colors'` in
  `diverSettingsListArrangement`)
- Regenerate: `lib/features/settings/data/resources/sql_column_notes.generated.dart`
  (`dart run tool/generate_sql_column_notes.dart`), `database.g.dart`
  (`dart run build_runner build --delete-conflicting-outputs`, unfiltered)
- Modify: `lib/features/settings/domain/list_arrangements.dart`,
  `lib/features/settings/data/repositories/list_arrangement_columns.dart`,
  `lib/features/settings/presentation/conflicts/catalogue/diver_settings_fields.dart`
  (`FieldKind.opaque`, new key `settings_conflict_field_recentEquipmentColors`
  "Recent equipment colors" in all 11 ARBs),
  `lib/features/settings/presentation/providers/list_arrangement_writes.dart`
- Create: `lib/features/equipment/presentation/utils/recent_equipment_colors.dart`
- Test: `test/core/database/migration_v364_recent_equipment_colors_test.dart`
  (modelled on `migration_v363_site_catalogue_id_test.dart`),
  `test/core/services/sync/diver_settings_list_arrangement_sync_test.dart`
  (add the column), `test/features/equipment/presentation/utils/recent_equipment_colors_test.dart`,
  a write test beside the existing `updateEquipmentCollapsedGroups` test
  (find with `grep -rl updateEquipmentCollapsedGroups test`)

**Interfaces:**
- Produces:
  - `ListArrangements.recentEquipmentColors` (`String?`, JSON) with `copyWith`.
  - `const int rememberedEquipmentColorCap = 8;`
  - `List<String> decodeRecentEquipmentColors(String? json)`: never throws;
    keeps entries that `normalizeEquipmentColor` accepts, normalised, first
    occurrence wins, presets dropped, capped at 8.
  - `String encodeRecentEquipmentColors(List<String> codes)`: JSON array.
  - `List<String> rememberEquipmentColor(List<String> current, String hex)`:
    invalid or preset `hex` returns `current` unchanged; else the normalised
    code first, its old copy removed, capped at 8.
  - `Future<void> SettingsNotifier.updateRecentEquipmentColors(List<String> Function(List<String> current) change)`
    on the `ListArrangementWrites` extension, mirroring
    `updateEquipmentCollapsedGroups`.

- [ ] **Step 1: Write the failing tests**

```dart
test('decode keeps the valid part of a malformed value', () {
  expect(decodeRecentEquipmentColors(null), isEmpty);
  expect(decodeRecentEquipmentColors('not json'), isEmpty);
  expect(
    decodeRecentEquipmentColors('["red", "#12345", 7, "#ff6a00", "#FF6A00", "#F97316"]'),
    ['#FF6A00'],
  );
});
test('decode caps at 8', () { /* 10 distinct codes in, first 8 out */ });
test('remember moves to front, dedups, caps', () {
  final eight = [for (var i = 0; i < 8; i++) '#00000$i'];
  expect(rememberEquipmentColor(eight, '#000003').first, '#000003');
  expect(rememberEquipmentColor(eight, '#000003'), hasLength(8));
  expect(rememberEquipmentColor(eight, '#ABCDEF'), ['#ABCDEF', ...eight.take(7)]);
});
test('remember ignores presets and invalid codes', () {
  expect(rememberEquipmentColor(const ['#123456'], '#F97316'), ['#123456']);
  expect(rememberEquipmentColor(const ['#123456'], 'red'), ['#123456']);
});
```

  Migration test: v364 in the ladder and keeps the floor; an upgraded v363
  database gains a nullable `recent_equipment_colors`; a database that already
  has it is untouched. Sync test: the column round-trips under
  `list_arrangement_hlc` and leaves the row `hlc` alone. Write test: calling
  `updateRecentEquipmentColors` before settings load builds on the saved value.
- [ ] **Step 2:** Run the four test files. Expected: FAIL.
- [ ] **Step 3:** Implement the column, rung, backstop, fact group entry,
  codegen, column notes, `ListArrangements` field and mapping, catalogue
  entry with translations, `flutter gen-l10n`, the utils file and the write
  method.
- [ ] **Step 4:** Run the four test files, `flutter test test/core/database`
  and `test/features/settings`. Expected: PASS.
- [ ] **Step 5:** Format, analyze, `flutter test test/architecture/`, commit
  `feat(settings): remember custom equipment colours per diver`.

### Task 4: The diver's gear colours

**Files:**
- Create: `lib/features/equipment/data/repositories/equipment_color_queries.dart`
- Modify: `lib/features/equipment/data/repositories/equipment_repository_impl.dart`
  (one-line delegate, like `_visibility`)
- Modify: `lib/features/equipment/presentation/providers/equipment_providers.dart`
- Test: `test/features/equipment/data/repositories/equipment_color_queries_test.dart`

**Interfaces:**
- Produces:
  - `class EquipmentColorQueries { const EquipmentColorQueries(AppDatabase db); Future<List<String>> gearColors(String diverId); }`
    Rows: `equipment_attributes` joined to `equipment` where
    `equipment.diver_id = diverId`, `attr_key = 'color'`, `is_custom = 0`,
    any status; ordered by the attribute's `updated_at` descending; values
    normalised with `normalizeEquipmentColor`, invalid and preset codes
    dropped, first occurrence kept, at most 12.
  - `Future<List<String>> EquipmentRepository.getGearColors(String diverId)`.
  - `final equipmentGearColorsProvider = FutureProvider<List<String>>` that
    awaits `validatedCurrentDiverIdProvider.future` (null diver gives `[]`),
    invalidates on `watchEquipmentChanges()` and `watchAttributeChanges()`.

- [ ] **Step 1: Write the failing tests** (seed with `EquipmentRepository`
  and `saveAttributes` as other repository tests do):
  owner scoping (another diver's item excluded), retired included,
  newest `updated_at` first, `#ff6a00` and `#FF6A00` show once as
  `#FF6A00`, presets and `"Red"` skipped, custom fields named "color" skipped.
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** Implement the query class, delegate and provider.
- [ ] **Step 4:** Run it plus `flutter test test/architecture/provider_change_tick_test.dart`. Expected: PASS.
- [ ] **Step 5:** Format, analyze, commit `feat(equipment): read the custom colours on a diver's gear`.

### Task 5: Recent row and Custom in the colour sheet

**Files:**
- Modify: `lib/features/equipment/presentation/utils/recent_equipment_colors.dart`
- Modify: `lib/features/equipment/presentation/widgets/equipment_color_sheet.dart`
- Modify: all 11 ARBs (`equipment_color_recent` "Recent"), generated l10n
- Test: `recent_equipment_colors_test.dart`,
  `test/features/equipment/presentation/widgets/equipment_color_sheet_test.dart`

**Interfaces:**
- Consumes: `showCustomColorDialog` (Task 1), `equipmentColorName` (Task 2),
  `rememberedEquipmentColorCap` (Task 3).
- Produces:
  - `const int recentEquipmentColorRowCap = 12;`
  - `List<String> recentEquipmentColorRow({String? current, required List<String> remembered, required List<String> gear})`:
    order current (if off-palette), remembered, gear; normalised; presets and
    invalid dropped; de-duplicated; capped at 12.
  - `Future<EquipmentColorChoice?> showEquipmentColorSheet(BuildContext context, {String? selected, List<String> recent = const [], ValueChanged<String>? onRemember})`
    where `recent` is the already-merged row. `EquipmentColorSheet` gains the
    same two fields.
  - Keys: recent swatches `ValueKey('color-swatch-recent-$hex')`, custom
    `ValueKey('color-swatch-custom')`.

- [ ] **Step 1: Write the failing tests**

```dart
test('row orders current, remembered, gear without repeats', () {
  expect(
    recentEquipmentColorRow(
      current: '#abcdef',
      remembered: const ['#111111', '#ABCDEF'],
      gear: const ['#222222', '#111111', '#F97316'],
    ),
    ['#ABCDEF', '#111111', '#222222'],
  );
});
test('a preset current colour is not in the row', () { /* current '#F97316' */ });
test('row caps at 12', () { /* 20 distinct in, 12 out */ });
```

  Widget tests: with `recent` empty there is no "Recent" text and the custom
  swatch follows the last preset; with `recent` it shows "Recent", the
  recent swatches labelled "<name> (<code>)", and the custom swatch last;
  the selected off-palette code is drawn selected (Semantics `selected`);
  tapping a recent swatch completes with it and `onRemember` is not called;
  the custom swatch opens the dialog, typing `ff6a00` and Use completes with
  `#FF6A00` and calls `onRemember('#FF6A00')` once; Cancel leaves the sheet
  open and calls nothing.
- [ ] **Step 2:** Run both test files. Expected: FAIL.
- [ ] **Step 3:** Implement. The Custom swatch reuses `_Swatch` with a `null`
  colour variant drawing `Icons.add` (label `common_color_custom`). The
  dialog opens on the selected colour, else `TagColors.fromHex('#3B82F6')`,
  title `common_color_custom`, preview a 36 dp circle plus
  `equipmentColorName`. On Use: `onRemember?.call(code)` then pop the sheet
  with `(hex: code)`.
- [ ] **Step 4:** Run both test files. Expected: PASS.
- [ ] **Step 5:** Format, analyze, commit `feat(equipment): recent and custom colours in the item colour sheet`.

### Task 6: Wire the field to the sources

**Files:**
- Modify: `lib/features/equipment/presentation/widgets/equipment_color_field.dart`
  (ConsumerWidget)
- Test: `equipment_color_field_test.dart`; wrap pumps in `ProviderScope` in
  `equipment_attribute_form_section_test.dart`,
  `equipment_purchase_form_section_test.dart`,
  `equipment_figure_position_field_test.dart` as needed

**Interfaces:**
- Consumes: `equipmentGearColorsProvider` (Task 4),
  `decodeRecentEquipmentColors`, `rememberEquipmentColor`,
  `updateRecentEquipmentColors` (Task 3), `recentEquipmentColorRow` and the
  new `showEquipmentColorSheet` parameters (Task 5).
- Produces: nothing new; field API unchanged.

- [ ] **Step 1: Write the failing tests** (override
  `equipmentGearColorsProvider` and `settingsProvider` with
  `MockSettingsNotifier` from `test/helpers/mock_providers.dart`): the sheet
  shows a remembered colour and a gear colour; Use in the dialog stores the
  code at the front of `listArrangements.recentEquipmentColors`; a gear
  provider that throws still opens the sheet with the presets and the
  remembered colours.
- [ ] **Step 2:** Run it. Expected: FAIL.
- [ ] **Step 3:** On tap: read the remembered list from
  `ref.read(settingsProvider).listArrangements.recentEquipmentColors`, await
  `ref.read(equipmentGearColorsProvider.future)` inside try/catch (failure
  gives `[]`, logged with `logFailure`), merge with `recentEquipmentColorRow`,
  open the sheet with `onRemember: (hex) => ref.read(settingsProvider.notifier).updateRecentEquipmentColors((c) => rememberEquipmentColor(c, hex))`
  (not awaited; errors logged).
- [ ] **Step 4:** Run the field test and the three consumer tests. Expected: PASS.
- [ ] **Step 5:** Format, analyze, `flutter test test/architecture/ test/shared/`,
  commit `feat(equipment): offer remembered and gear colours when picking an item colour`.

### Task 7: Final checks

- [ ] `git diff --numstat origin/main -- lib/l10n/arb/` rows match across
  locales; `grep -A1 "get common_color_custom\|equipment_color_customName\|equipment_color_recent\|recentEquipmentColors" lib/l10n/arb/app_localizations_de.dart`
  shows German.
- [ ] `git diff origin/main | grep -nP "^\+.*\x{2014}"` finds nothing added by this branch.
- [ ] After screenshots of the sheet (presets only, with Recent row, dialog)
  in light and dark.
