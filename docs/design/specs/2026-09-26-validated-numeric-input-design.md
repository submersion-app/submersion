# Validated numeric input (issue #1900)

## Problem

`parseUserDecimal` / `parseUserInt` return `null` both for a blank field and
for text that cannot be read in the active locale. Almost every caller
collapses the two with `?? 0`, `?? previous`, or by storing the null, so a
diver who mistypes a number gets no feedback and the app silently records 0,
drops the value, or keeps a stale one. A survey found 192 calls (177 direct,
15 via `smartParseUserDecimal`) in 53 files under `lib/`. Safety-relevant
fields are among the silent ones: dive max/avg depth and times, tank
pressures and volume, every CCR/SCR panel field, bulk setpoints, planner
segment depth/duration, plan tank pressure/volume, deco calculator altitude,
and the GTR reserve dialog.

Visible feedback exists in a handful of places, each hand-rolled, with five
different message keys.

## Decisions

| Topic | Decision |
|---|---|
| Scope | Every call site in one PR, `Closes #1900`. |
| Parser | Smart parsing everywhere (`smartParseUserDecimal`, new `smartParseUserInt`). |
| Error text | One shared message that names the locale's decimal separator. |
| Unreadable input | Pages with a Save action block it (Form + validator). Live-updating fields keep the last valid value and show the error. Nothing unreadable is ever written as 0 or null. |
| Blank input | Each field keeps its current blank meaning, written explicitly at the call site. Questionable ones are listed in the PR for the maintainer to decide, not changed here. |
| Structure | A shared core plus two adapters (validator for Form sites, `NumberField` widget for live sites). |
| Old strings | Pure "not a number" keys are replaced by the shared key and deleted from all 11 locales. Range and semantic messages stay. |
| Guardrail | An architecture test forbids direct parser calls outside the shared layer. |

## Components

### `lib/core/utils/number_input.dart`

Add `smartParseUserInt(String text)`: `smartParseUserDecimal`, then the same
"reject a fractional part" rule `parseUserInt` applies. No other change; the
strict parsers remain the implementation underneath.

### `lib/shared/widgets/forms/number_input_validation.dart` (new)

```dart
sealed class NumberRead { const NumberRead(); }
final class NumberBlank extends NumberRead { const NumberBlank(); }
final class NumberValue extends NumberRead { const NumberValue(this.value); final double value; }
final class NumberInvalid extends NumberRead { const NumberInvalid(); }

NumberRead readNumber(String text, {bool integer = false});

FormFieldValidator<String> numberValidator(
  BuildContext context, {
  bool integer = false,
  bool required = false,
  String? Function(double value)? check,
});

String? invalidNumberText(
  BuildContext context,
  String text, {
  bool integer = false,
});
```

- `readNumber` uses the smart parsers. `integer: true` returns
  `NumberInvalid` for a fractional value.
- `numberValidator` returns, in order: `numberInput_required` when blank and
  `required`; `null` when blank otherwise; the invalid message when
  unreadable; then `check(value)` for field-specific rules, whose messages
  are the existing field keys.
- `invalidNumberText` is the message alone, for the few places that render
  an error outside a `TextFormField` (the `PlanNumberField` row).

Call sites read values with an exhaustive `switch` on `NumberRead`, so the
blank and invalid handling is stated at each site and enforced by the
compiler:

```dart
maxDepth: switch (readNumber(_maxDepthController.text)) {
  NumberValue(:final value) => units.depthToMeters(value),
  NumberBlank() => null,
  NumberInvalid() => null, // unreachable: the validator blocked save
},
```

### `lib/shared/widgets/forms/number_field.dart` (new)

`NumberField` wraps `TextFormField` for live-updating sites:

- Parameters: `controller`, `decoration`, `integer`, `allowNegative`,
  `required`, `check`, `onChanged(NumberRead)`, plus pass-throughs the call
  sites need (`focusNode`, `enabled`, `textAlign`, `onEditingComplete`,
  `onFieldSubmitted`, `key`).
- Sets `TextInputType.numberWithOptions(decimal: !integer, signed: allowNegative)`
  and a filter allowing digits, `.` and `,` (plus `-` when `allowNegative`),
  replacing the duplicated `_decimalFilter` helpers.
- `validator: numberValidator(...)` with
  `autovalidateMode: AutovalidateMode.onUserInteraction`, so the error shows
  as the diver types, and `Form.validate()` blocks save when the field sits
  inside a Form (tank editor, CCR/SCR panels inside the dive edit page).
- Reports every change as a `NumberRead`. The widget holds no value memory;
  a live caller maps `NumberInvalid` to "keep the previous value" in its own
  switch, keeping that rule visible where the value is stored.

### Localization

New keys in all 11 ARB files:

- `numberInput_invalidNumber(separator)`: "Enter a number, using '{separator}' for decimals"
- `numberInput_invalidWholeNumber`: "Enter a whole number"
- `numberInput_required`: "Required"

Deleted once unreferenced: `numberInput_invalidValue`,
`gasCalculators_blender_invalidNumber`, `equipmentConditionSettings_invalid`,
`passport_logFill_invalidNumber`, `divers_edit_priorInvalidNumber`, and any
other key found during the sweep whose only meaning is "this is not a
number". A key that also carries a range or semantic rule stays.

## Migration map

| Wiring today | Becomes |
|---|---|
| FormRow / SuggestionFormRow / TextFormField inside a Form, parsed on save | `validator: numberValidator(...)`, save reads via `switch (readNumber(...))` |
| TextField + `onChanged`, no feedback | `NumberField`, `NumberInvalid` keeps the previous value |
| Parsed on a button press without a Form | Wrapped in a `Form`, validator added, the action blocks while invalid |
| Filter / search sheets | `NumberField`; invalid text leaves the current filter unchanged |
| Hand-rolled errorText or `_error` state | Replaced by `NumberField` / `numberValidator`; local helpers deleted |
| `PlanNumberField` | Reads via `readNumber`; unreadable text gets the red border and the message under the row; blur still reverts to the plan's value |
| Derived display reads (chips, N2 readouts, warnings, info cards) | `readNumber`, invalid treated like blank; the input field shows the error |

Files by feature (line numbers from the survey, approximate):

- **dive_log:** `dive_edit_page.dart` (save path, bulk edit, bulk setpoints
  and scrubber, weight rows, runtime and altitude derivations),
  `visibility_display.dart`, `tank_editor.dart`, `ccr_settings_panel.dart`,
  `scr_settings_panel.dart`, `dive_filter_sheet.dart`,
  `dive_search_page.dart`, `dive_numbering_dialog.dart`, the edit sections
  that own `_decimalFilter`.
- **dive_planner:** `segment_editor.dart`, `plan_tank_list.dart`,
  `setup/plan_gas_section.dart`, `setup/plan_number_field.dart`,
  `setup/plan_air_breaks_control.dart`, `setup/plan_environment_section.dart`.
- **planner:** `ccr_settings_section.dart`,
  `contingency_settings_section.dart`, `pscr_settings_section.dart`.
- **deco_calculator:** `environment_inputs.dart`.
- **gas_calculators (blender):** `blender_field_parsing.dart`,
  `blender_fill_gases_card.dart`, `blender_mix_row.dart`,
  `blender_billing_card.dart`, `blender_line_edit_sheet.dart`,
  `mix_template_menu.dart`, `mix_template_manager.dart`.
- **cylinders and gear:** `cylinder_config_item_editor.dart`,
  `log_fill_sheet.dart`, `tank_preset_edit_page.dart`,
  `transmitter_edit_page.dart`.
- **dive_sites:** `site_edit_page.dart`, `location_section.dart`,
  `site_filter_sheet.dart`.
- **equipment:** `equipment_edit_page.dart`, `service_kind_list_page.dart`,
  `exposure_interval_input.dart`, `service_schedule_dialogs.dart`,
  `service_record_dialog.dart`, `equipment_attribute_form_section.dart`.
- **settings:** `equipment_condition_settings_page.dart`,
  `gtr_reserve_dialog.dart` (and its caller in `settings_page.dart`),
  `visibility_scale_picker.dart`, `body_weight_edit_page.dart`,
  `prior_experience_edit_page.dart`, `fix_dive_times_page.dart`.
- **other:** `weight_planner_page.dart`, `weight_preset_editor_page.dart`,
  `checklist_template_edit_page.dart`, `data_quality_inbox_page.dart`,
  `pre_dive_session_runner_page.dart`, `pre_dive_template_edit_page.dart`,
  `terrain_appearance_sheet.dart`, `site_feature_sheet.dart`,
  `rental_gear_note_sheet.dart`.

The architecture guard is the completeness check: the sweep is done when it
passes.

## Blank-input audit

Every migrated site writes its `NumberBlank()` case explicitly with today's
behavior. Sites where that behavior looks questionable are collected in a
"Blank-input decisions for review" table in the PR description, unchanged.
Known candidates: a blank weight-preset amount silently drops the row; a
blank dive number becomes 0; a blank diluent O2 drops the diluent gas.

## Guardrail

`test/architecture/number_parsing_single_source_test.dart` scans `lib/` and
fails when `parseUserDecimal(`, `parseUserInt(`, `smartParseUserDecimal(` or
`smartParseUserInt(` appears outside `lib/core/utils/number_input.dart` and
`lib/shared/widgets/forms/number_input_validation.dart`.

## Testing

- Unit: `smartParseUserInt`; `readNumber` under en and de (blank, value,
  wrong-separator correction, genuinely malformed, integer with a
  fraction); `numberValidator` (blank optional, blank required, invalid,
  invalid integer, `check` message passthrough).
- Widget: `NumberField` shows the error on interaction, reports
  `NumberInvalid`, and makes `Form.validate()` fail.
- Regression, safety tier at minimum: unreadable max depth blocks the dive
  save; an unreadable CCR setpoint keeps the previous value and shows the
  error; an unreadable segment depth blocks the segment; unreadable tank
  start pressure keeps the previous value. Existing tests asserting deleted
  keys or old behavior are updated.
- One full suite run, `flutter analyze`, `dart format .`.

## PR

One branch, commits grouped by feature (core, widget, dive_log, planner,
equipment and sites, settings and misc, key cleanup, guard). The description
carries `Closes #1900`, the blank-input table, and screenshots (before and
after, light and dark) of a Form field error on the dive edit page, a live
field error in the CCR panel, and the planner row message, captured through
throwaway goldens and handed to the maintainer for upload.

## Out of scope

- Changing any field's blank meaning.
- Range validation for fields that have none today (for example negative
  depth), beyond keeping existing range messages.
- Visual redesign of FormRow or the planner rows.
