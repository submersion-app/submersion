# Clone an equipment set (issue #2156)

## Goal

A diver who uses nearly the same rig on many dives can copy an existing set,
change the one or two items that differ, and keep both sets. The flow matches
Clone for a single equipment item (issue #3184): the set page's 3-dot menu has
a Clone entry that opens the set form filled in from the source, named
"<name> (copy)". Nothing is written until the diver taps Save.

The set form also gains the equipment form's unsaved-changes warning, in every
mode: Back with unsaved changes asks "Discard Changes?" (Keep Editing /
Discard).

## Behaviour

| Field                         | On the clone                         | Why |
|-------------------------------|--------------------------------------|-----|
| Name                          | `equipment_clone_nameCopy` of source ("<name> (copy)") | Same text as the equipment clone |
| Description                   | Copied                               | |
| Members (`equipmentIds`)      | Copied, minus items the diver can no longer see (a removed share, issue #2046) | The clone belongs to the diver; members they cannot see would be rows they cannot untick |
| Show figure                   | Copied                               | A display preference |
| Default                       | Off                                  | Only one default per diver; a clone must not take it from the source |
| Auto-apply on computer import | Off                                  | Two opted-in sets that share a computer are both applied, so the import would get both rosters |
| Geofences                     | None                                 | A duplicate fence ties with the source's and picks one set arbitrarily |

The diver can turn Default, Auto-apply and Geofences on before saving. A clone
is on no dives, so its save never asks the "update past dives" question.

## Flow

1. Set page, 3-dot menu, Clone: pushes `/equipment/sets/new?cloneFrom=<id>`.
2. The form opens filled in, titled "Clone Equipment Set".
3. Save creates the set, shows "Equipment set cloned" and pops with the new
   id. The set page then shows the clone in place of the source: on a phone
   the clone's page replaces the source's; in the desktop split
   (`?setSelected=`) the clone is selected in the list.
4. Back asks first, even on an untouched clone, since the copy itself is
   unsaved (the equipment clone does the same). Discard pops with nothing and
   the source page stays as it was.

### Back warning in every mode

- New set: asks once anything differs from a blank form.
- Edit: asks once anything differs from the set as it opened. A change put
  back as it was is no change.
- Clone: always asks.

"Differs" compares what the save would write: trimmed name and description,
members as a set, the three switches, and each geofence by id, label,
position and radius (not the timestamps the geofence editor stamps).

## Changes

- `domain/services/equipment_set_clone_seed.dart`: `equipmentSetCloneSeed`,
  the pure field rules above.
- `presentation/helpers/equipment_set_form_values.dart`: the comparable form
  snapshot behind the Back warning.
- `presentation/widgets/unsaved_changes_scope.dart`: the `PopScope` guard and
  the discard dialog, reusing the `equipment_edit_discardDialog_*` strings.
- `presentation/helpers/equipment_set_clone_action.dart`: the menu action and
  the navigation after the save.
- `presentation/widgets/set_geofences_editor.dart` and
  `presentation/helpers/staged_geofences.dart`: the form's Geofences section,
  moved out so `equipment_set_edit_page.dart` stays under 800 lines.
- `equipment_set_edit_page.dart`: `cloneFromId`, seeding from the source
  (which stops being watched once seeded), the clone title and snackbar, the
  Back guard.
- `equipment_set_detail_page.dart`: the Clone menu entry.
- `app_router.dart`: `newEquipmentSet` passes `cloneFrom`.
- l10n: `equipment_setEdit_appBar_cloneTitle` and
  `equipment_setEdit_snackbar_cloned` in all 11 locales; the menu label reuses
  `equipment_menu_clone`.

## Tests

- `equipment_set_clone_seed_test.dart`, `equipment_set_form_values_test.dart`:
  the pure rules.
- `equipment_set_edit_clone_test.dart`: prefilled form; save creates a second
  set and leaves the source (default, auto-apply, geofence) as it was; Back
  on an untouched clone warns, Keep Editing stays, Discard creates nothing;
  missing source.
- `equipment_set_edit_discard_test.dart`: the Back warning for new and edited
  sets, including a change put back.
- `equipment_set_detail_clone_test.dart`: the menu entry; the clone replaces
  the source page on a phone and is selected in the desktop split; a discard
  leaves the source page.

## PR

- Branch `feature-request-2156-clone-equipment-set`; description says
  `Closes #2156`.
- UI change: screenshots of the set page menu with Clone, the clone form, the
  discard dialog and the clone's page after save, at phone (300px) and
  desktop (1200px) widths, attached through the screenshots gist.
