# Dive edit form: flatten "The Dive" group and restore the calculate-from-profile button

Date: 2026-06-23
Issue: [#388](https://github.com/submersion-app/submersion/issues/388) "Calculate average depth button is missing from dive edit page"

## Background

The dive edit form's "The Dive" section once rendered max depth, avg depth, and
runtime as `TextFormField`s, each with an explicit one-tap calculator button
(`Icons.calculate_outlined`, tooltip `diveLog_edit_tooltip_calculateFromProfile`)
as a `suffixIcon` that filled the field from the dive profile. Those buttons were
added in commit `9c580892e8c`.

The refactor `c27e27692b2` ("rebuild The Dive group on shared form primitives")
moved max depth, bottom time, and avg depth into a hero `StatStrip` of `StatCell`s
and replaced the explicit buttons with a faint, conditional 14px `Icons.sync_outlined`
glyph that opens a popup menu (two taps) to apply the value. Runtime moved to a plain
`FormRow.text` with no calculate affordance at all. The tooltip string
`diveLog_edit_tooltip_calculateFromProfile` is now orphaned (still translated in all
11 locales, referenced nowhere in `lib/`).

Net effect (the bug in #388): the calculate-average-depth button appears missing.
The capability still exists but the affordance is undiscoverable, and runtime lost it
entirely.

## Goals

1. Remove the hero `StatStrip` from "The Dive" section. Max depth, avg depth, and
   bottom time render as ordinary form rows like the other fields (dive number, entry,
   exit, runtime, site).
2. Top three rows are Dive #, Entry, Exit (in that order).
3. Restore a prominent, one-tap "Calculate from dive profile" affordance on all four
   profile-derivable fields: max depth, avg depth, bottom time, runtime.

## Non-goals

- No change to the SAC / tank-pressure logic (issue #191, already resolved by #383 plus
  the v1.4.7.93 write-side guard). This is purely the edit-form affordance and layout.
- No change to other `StatStrip`/`StatCell` users (conditions section, tank cards, site
  edit). They never set `profileValue`, so they are unaffected.
- No change to the calculation logic itself (`Dive.calculate*FromProfile()` and the
  `_calculate*FromProfile` handlers in the page are reused as-is).

## Design

### 1. New field order in "The Dive" section

`the_dive_section.dart` renders a flat list of `FormRow`s (no `StatStrip` hero):

```
Dive #            FormRow.text
Entry             FormRow.picker
Exit              FormRow.picker
Surface interval  (existing conditional row, only when editing an existing dive)
Max depth         FormRow.text  + calculate affordance
Avg depth         FormRow.text  + calculate affordance
Bottom time       FormRow.text  + calculate affordance
Runtime           FormRow.text  + calculate affordance
Site              FormRow.picker
(site extras)     existing widget, unchanged
(profile block)   existing widget, unchanged
```

Numeric rows use `suffixText` for units: depth symbol for max/avg depth, `min` for
bottom time and runtime. Unit symbols continue to come from the active diver's
`UnitFormatter`, exactly as today.

### 2. Calculate affordance on `FormRow.text`

`lib/shared/widgets/forms/form_row.dart` — add two optional parameters to the
`FormRow.text` constructor:

- `String? profileValue` — the profile-derived value, formatted in display units.
- `VoidCallback? onUseProfileValue` — fills the field from the profile (the page's
  existing `_calculate*FromProfile(units)` handler).

Render rule, in the resting (non-editing) state only, mirroring the existing
`picker` variant's trailing `clear` button (form_row.dart:293-324):

- Show a trailing `IconButton`/`InkWell` with `Icons.calculate_outlined` and tooltip
  `diveLog_edit_tooltip_calculateFromProfile` when, and only when:
  `profileValue != null && onUseProfileValue != null && profileValue != controller.text`.
- The trailing area becomes a `Row` of `[value Text, if(show) calculate icon]`.
- One tap on the icon calls `onUseProfileValue`. The icon's tap is isolated from the
  row's tap-to-edit (same gesture isolation the clear button already relies on).

This condition is identical to `StatCell._showProfileGlyph`, so behavior is preserved:
the affordance hides once the field already holds the computed value (nothing to do),
and appears for the #388/#191 case (profile present, field empty or `0.0`).

### 3. Wire the four fields

`dive_edit_page.dart` `_buildTheDiveSection`: pass each numeric row a `profileValue`
(formatted `Dive.calculate*FromProfile()` when `hasProfile`, else null) and an
`onUseProfileValue` (`() => _calculate*FromProfile(units)`). The existing snackbars in
those handlers ("Avg depth calculated: ...") are retained.

### 4. Cleanup

- Delete the now-unused `ProfileSuggestion` class and the `_depthSuggestion` /
  `_minutesSuggestion` helpers (replaced by the inline `profileValue` strings).
- Delete `StatCell.profileValue`, `StatCell.onUseProfileValue`, `_showProfileGlyph`,
  and `_buildProfileGlyph` from `stat_strip.dart`. `the_dive_section.dart` was their
  only consumer.
- If `forms_statCell_useProfileValue` becomes unreferenced after this, remove it from
  all locale ARBs and regenerate; otherwise leave it.
- Revive `diveLog_edit_tooltip_calculateFromProfile` (already translated) as the icon
  tooltip; no new strings, so no new localization work.

## Files affected

- `lib/features/dive_log/presentation/widgets/edit_sections/the_dive_section.dart`
  (remove hero, flatten to rows, reorder, drop `ProfileSuggestion`).
- `lib/shared/widgets/forms/form_row.dart` (add the calculate affordance to `.text`).
- `lib/features/dive_log/presentation/pages/dive_edit_page.dart` (wire the four rows).
- `lib/shared/widgets/forms/stat_strip.dart` (remove the dead suggestion glyph).
- l10n ARBs only if `forms_statCell_useProfileValue` becomes orphaned.

## Behavior / edge cases

- No profile on the dive: no `profileValue`, so no calculate icon on any row (matches
  the old `suffixIcon` being null when `profile.isEmpty`).
- Field already equals the computed value: icon hidden (nothing to apply).
- Imported `avgDepth == 0.0` with a profile (the #191/#388 case): computed value differs
  from `0.0`, so the icon shows; one tap fills it; the snackbar confirms.
- Units: `profileValue` is formatted in the active unit system; tapping fills the same
  displayed units. Switching the comparison is string-based on the displayed value, as
  `StatCell` did.

## Testing (TDD)

Write tests first, then implement.

- `form_row` widget tests: `.text` row shows the calculate icon when `profileValue`
  differs from the controller text and `onUseProfileValue` is set; hidden when equal,
  when `profileValue` is null, or when `onUseProfileValue` is null; tapping the icon
  invokes `onUseProfileValue`; tapping elsewhere on the row still enters edit mode.
- `the_dive_section` / `dive_edit_page` widget tests: the four metric fields render as
  rows in the specified order with Dive #, Entry, Exit on top; no `StatStrip` in the
  tree; each metric row shows a calculate icon for a dive with a profile and a differing
  value; tapping the avg-depth icon fills the avg-depth field (the #388 regression).
- Update or remove existing `the_dive_section` tests that assert the `StatStrip`/hero.
- `flutter analyze` clean, `dart format` applied.

## Out of scope / follow-ups

- Whether to also surface a calculate affordance while a row is actively in edit mode
  (the design restores it in the resting state only, which is where discovery happens).
