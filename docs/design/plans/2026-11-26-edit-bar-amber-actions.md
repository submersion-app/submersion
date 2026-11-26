# Edit Bar Amber Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cancel and Save on an unlocked record page's bar wear the pencil's amber, Save filled and Cancel as a ring, so they stand out.

**Architecture:** A new `RecordEditAction` button in `lib/shared/widgets/record_editing/` reads `RecordPencilColors` and draws one of two styles. `RecordEditBar`, `RecordEditPaneHeader` and `RecordSatelliteBar` use it in place of `AppBarTextAction`. Tests that find the bars' actions by type move to the new widget.

**Tech Stack:** Flutter, Material 3 (`FilledButton`, `OutlinedButton`), flutter_test.

**Spec:** `docs/design/specs/2026-11-26-edit-bar-amber-actions-design.md` (issue #5034)

## Global Constraints

- Colours come only from `RecordPencilColors.of(context)`: `fill`, `onFill`, `outline`. No new colour constants.
- Filled: background `fill`, label `onFill`, ring `outline`. Ring: transparent background, ring `outline`, label `outline`.
- Disabled: the style's own colours at 0.38 opacity.
- Busy (filled only): a 20 px `CircularProgressIndicator` (stroke 2) in `onFill` in place of the label, the label kept as its semantics label; the fill stays at full strength while busy.
- The bars keep their height (`kToolbarHeight`), tint, underline and layout.
- No em-dashes in code, comments or docs. No emojis.

## Review Focus

1. A long translation of Cancel and Save (and the pane's menu) on a 320 px wide phone: nothing overflows; the title ellipsizes first.
2. System text at 200%: the buttons fit the 56 px bar without an overflow error.
3. Every preset, light and dark: Cancel's label reads on the bar (4.5:1) and its ring shows against it (3:1); Save's label reads on its fill (4.5:1).
4. Saving: the spinner reads on the fill (3:1) and a screen reader still hears "Save".
5. Disabled Save looks different from enabled Save (its fill is faded, not the same colour).

---

### Task 1: The `RecordEditAction` button

**Files:**
- Create: `lib/shared/widgets/record_editing/record_edit_action.dart`
- Modify: `lib/core/theme/record_pencil_colors.dart` (class doc: the edit bars' actions wear these colours too)
- Test: `test/shared/widgets/record_editing/record_edit_action_test.dart`

**Interfaces:**
- Produces:
  - `enum RecordEditActionStyle { filled, ring }`
  - `class RecordEditAction extends StatelessWidget` with
    `const RecordEditAction({Key? key, required String label, required VoidCallback? onPressed, RecordEditActionStyle style = RecordEditActionStyle.filled, bool busy = false})`
    and public final fields `label`, `onPressed`, `style`, `busy` (tests read them as they read `AppBarTextAction`'s).

- [ ] **Step 1: Write the failing tests** (host: `MaterialApp` with `ThemeData.light()` / `.dark()`, `Scaffold(body: Center(child: RecordEditAction(...)))`)
  - `filled draws the pencil's fill, ring and glyph colour (light)` / `(dark)`: the `Material` under the button has `color == RecordPencilColors.light.fill` (`.dark.fill`), its shape's side colour `== outline`, and the label's `RenderParagraph` colour `== onFill`.
  - `ring draws a transparent ground with the pencil's ring and label in its colour`: Material colour transparent, side colour `== outline`, label colour `== outline`, in light and dark.
  - `a disabled action fades its colours`: with `onPressed: null`, filled background alpha and label alpha are `0.38 * ` the enabled values; the same for the ring's side and label.
  - `busy swaps the label for a spinner in the glyph colour`: `find.text('Save')` finds nothing, the `CircularProgressIndicator`'s `color == onFill`, `tester.getSemantics` of the button has label `Save`, and the Material colour is still the full `fill`.
  - `a tap calls onPressed`; `a disabled action ignores taps`.
  - `the label stays onFill under a theme whose primary matches its app bar` (Tropical): placed inside an `AppBar(actions:)` of `AppThemeRegistry` Tropical light, the label colour is still `onFill` (filled) and `outline` (ring).

- [ ] **Step 2: Run and see them fail**
  Run: `flutter test test/shared/widgets/record_editing/record_edit_action_test.dart`
  Expected: compile failure, `RecordEditAction` not defined.

- [ ] **Step 3: Implement `RecordEditAction`**
  Filled builds a `FilledButton`, ring an `OutlinedButton`, each with `styleFrom` setting foreground, background, disabled foreground/background and `side` per Global Constraints, `visualDensity: VisualDensity.compact` and horizontal padding 14. While `busy`, pass the enabled background as the disabled background so the fill does not fade. Doc comment: why amber (one editing colour with the pencil and dot, #5034), why not `AppBarTextAction` (it pins to the bar's foreground; these bring their own).

- [ ] **Step 4: Run and see them pass**
  Run: `flutter test test/shared/widgets/record_editing/record_edit_action_test.dart`
  Expected: all pass.

- [ ] **Step 5: Commit** `feat(record-editing): an amber edit action in the pencil's colours`

### Task 2: The three bars use it

**Files:**
- Modify: `lib/shared/widgets/record_editing/record_edit_bar.dart` (Cancel `style: ring`, Save `filled` with `busy: isSaving`)
- Modify: `lib/shared/widgets/record_editing/record_edit_pane_header.dart` (same)
- Modify: `lib/shared/widgets/record_editing/record_satellite_bar.dart` (Done `filled`)
- Test: `test/shared/widgets/record_editing/record_edit_bar_test.dart`, `record_edit_pane_header_test.dart`, `record_satellite_test.dart`

**Interfaces:**
- Consumes: `RecordEditAction`, `RecordEditActionStyle` from Task 1.

- [ ] **Step 1: Update and add the failing tests**
  - In both bar tests, `_action` finds `RecordEditAction` by `label` instead of `AppBarTextAction`.
  - New `Cancel is a ring and Save is filled` in both: `_action(tester, 'Cancel').style == RecordEditActionStyle.ring`, `_action(tester, 'Save').style == RecordEditActionStyle.filled`; with `saveLabel: 'Send'`, Send is filled.
  - Replace `the bar text reads on its background` (per preset, light and dark): the title and Cancel's label at 4.5:1 or better against the bar background; Cancel's ring colour at 3:1 or better against it; Save's label at 4.5:1 or better against `RecordPencilColors.of(context).fill`.
  - New `long labels fit a phone-width bar`: 320 x 640 surface in Dutch (`Annuleren`, the longest Cancel of the app's languages), no exception thrown (`tester.takeException()` is null) and the title's `RenderParagraph` reports `didExceedMaxLines`. (Built first with a 20-character `saveLabel`; the test font draws every glyph as a 14 px square, so that label overflowed the old bar too.)
  - New `the bar fits at 200% text`: `MediaQuery(textScaler: TextScaler.linear(2))`, no exception.
  - New `the saving spinner reads on the fill` (bar test, per preset light and dark): with `isSaving: true`, the spinner colour against `fill` is 3:1 or better.
  - In `record_satellite_test.dart`, a `Done is filled` test: the satellite bar's `RecordEditAction` labelled Done has `style == filled`.

- [ ] **Step 2: Run and see them fail**
  Run: `flutter test test/shared/widgets/record_editing/record_edit_bar_test.dart test/shared/widgets/record_editing/record_edit_pane_header_test.dart test/shared/widgets/record_editing/record_satellite_test.dart`
  Expected: failures finding `RecordEditAction`.

- [ ] **Step 3: Swap `AppBarTextAction` for `RecordEditAction` in the three bars**, dropping the now-unused import. Update `RecordEditBar`'s and `RecordEditPaneHeader`'s class docs to say Cancel and Save wear the pencil's amber.

- [ ] **Step 4: Run and see them pass** (same command). Expected: all pass.

- [ ] **Step 5: Commit** `feat(record-editing): Cancel and Save in the pencil's amber on the edit bars`

### Task 3: Tests that find the bars' actions by type

**Files (modify; each finds a record bar's Cancel, Save, Send or Done as `AppBarTextAction`):**
`test/shared/widgets/record_editing/record_editor_host_test.dart`, `record_editor_host_menu_test.dart`, `record_editor_host_can_save_test.dart`, `record_edit_controller_operation_test.dart`;
`test/features/safety/presentation/pages/incident_edit_page_test.dart`, `incident_edit_page_sitting_test.dart`, `incident_check_in_link_test.dart`, `add_chamber_page_test.dart`;
`test/features/rules/presentation/rule_edit_page_test.dart`, `rule_edit_page_sitting_test.dart`;
`test/features/pre_dive/presentation/pages/pre_dive_template_edit_page_test.dart`, `pre_dive_template_edit_page_sitting_test.dart`;
`test/features/checklists/presentation/pages/checklist_template_edit_page_sitting_test.dart`;
`test/features/cylinder_configs/presentation/cylinder_config_edit_page_sitting_test.dart`;
`test/features/transmitters/presentation/pages/transmitter_edit_page_sitting_test.dart`;
`test/features/tank_presets/presentation/pages/tank_preset_edit_page_test.dart`;
`test/features/weight_presets/presentation/pages/weight_preset_editor_page_test.dart`;
`test/features/settings/presentation/pages/diver_profile_harness.dart`;
`test/features/dive_log/presentation/pages/dive_detail_page_unlock_harness.dart`, `dive_detail_page_unlock_open_test.dart`, `dive_detail_page_unlock_pane_site_test.dart`;
`test/features/dive_sites/presentation/pages/site_detail_page_new_test.dart`;
`test/features/equipment/presentation/pages/equipment_set_detail_page_unlock_test.dart`, `equipment_set_detail_page_history_test.dart`.

Not touched: `app_bar_text_action_test.dart`, `app_bar_text_action_adoption_test.dart` and `species_review_page_test.dart` (its page uses `AppBarTextAction` directly, not a record bar).

- [ ] **Step 1: In each file, read every `AppBarTextAction` use and confirm it targets a record bar action**, then replace the type with `RecordEditAction` and the import with `record_edit_action.dart` (keep `app_bar_text_action.dart` only where a non-record action remains).
- [ ] **Step 2: Run the changed files by path**
  Run: `flutter test <each file above>` (files, never folders)
  Expected: all pass.
- [ ] **Step 3: `dart format .` and `flutter analyze`**, expected clean.
- [ ] **Step 4: Commit** `test(record-editing): find the edit bars' actions as RecordEditAction`
