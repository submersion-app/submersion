# Dive type favourites

Issue: #4413. Release: v1.8.5.

## Intent

Custom dive types always land at the bottom of the dive type picker, below the
15 built-in types. A diver who logs one type often (the forum example is a
custom *dry diving* type) scrolls past every built-in each time they pick it.
Divers should be able to put the types they use at the top of every picker.

## Goals

- A diver can star (favourite) any dive type, built-in or custom.
- Every dive type picker lists favourites first: dive edit and bulk edit (the
  checklist sheet), the Refine filter dropdown, and the connections search.
- Stars can be set in two places: the Dive Types settings page and the
  picker's checklist sheet itself.
- Favourites are per diver profile and sync with the rest of that diver's
  settings.

## Non-goals

- Free reordering (drag handles, a custom order for every type). Favourites
  were chosen over full reorder.
- Favourites for other catalogs (dive roles, site types, service kinds).
- Changing the order used anywhere that is not a picker (exports, badge rows,
  the dive's own type list).

## Anti-goals

- One diver's stars leaking into another profile on the same database.
  Built-in `dive_types` rows are shared by every profile, so the stars must not
  be written to those rows.
- Rows jumping under the diver's finger while the checklist sheet is open.

## Approaches considered

1. **Favourites on top (chosen).** A per-diver set of starred type ids. Starred
   types come first in every picker; the rest keep today's order. Fixes the
   reported case directly, reuses the hidden-built-ins storage pattern, adds
   little UI. Cannot fine-tune order inside either group.
2. **Full drag reorder.** One per-diver order for all types, edited by drag on
   the settings page. Most control, but needs drag UI on phone and desktop, a
   reset, and a rule for where new types land.
3. **Custom types first, no setting.** Matches the settings page and needs
   almost no code, but does nothing for a diver who mostly uses one built-in.

Eric picked approach 1, with stars editable from both Settings and the picker.

## Design

### Storage

- New nullable column `diver_settings.favourite_dive_type_ids` (TEXT), a
  sorted JSON list of dive type ids; null means no favourites. Column-only
  schema rung, no backfill: every existing diver starts with no favourites.
- `AppSettings` gains `favouriteDiveTypeIds` (`Set<String>`, default empty),
  saved and loaded by `DiverSettingsRepository` like `hiddenBuiltInIds`, so it
  rides the existing diver_settings sync and appears in the settings conflict
  catalogue with its own label.
- `SettingsNotifier.setDiveTypeFavourite(id, favourite)` toggles one id.

### Ordering

- One pure function orders a type list: favourites first, each group keeping
  its incoming relative order (sort order, then name, as today).
- Pickers read a favourites-ordered view of the dive types. `diveTypesProvider`
  itself stays in repository order, so exports, label resolvers and the
  settings page are unaffected.
- Hiding wins: a hidden built-in stays out of the pickers even when starred.
  A type the dive already has is still offered, as today (issue #401 `keep`).
- An id in the set that matches no type (a deleted custom type, or one from a
  profile the diver no longer has) is ignored when ordering.

### Checklist sheet (dive edit and bulk edit)

```
Dive types                     Close
  FAVOURITES
  [x] Dry diving                  ★
  [ ] Shore                       ★
  ─────────────────────────────────
  [ ] Recreational                ☆
  [ ] Technical                   ☆
```

- A "Favourites" label heads the starred group and a divider separates it from
  the rest. With no favourites the sheet looks as it does today.
- Each row has a trailing star button (tooltip "Add to favourites" or "Remove
  from favourites"). Tapping it saves immediately and fills or empties the
  star, but the row stays where it is until the sheet is next opened.
- The star is a separate tap target from the checkbox; starring does not tick
  or untick the type.

### Refine filter dropdown and connections search

- The Refine dropdown lists favourites first, in the same order as the sheet.
- The connections search mixes every entity kind and ranks hits busiest
  first. A starred dive type that matches the search moves to the top of the
  hits; every other hit keeps the busiest-first order. Confirmed with Eric
  after planning showed the search is not a dive type picker.
- No header, divider or star buttons in either.

### Dive Types settings page

- Each row, custom and built-in, gets a star button next to its existing
  trailing controls. The page keeps its current sections and order.

### Strings

New ARB keys for the "Favourites" label, the two star tooltips and the
conflict-catalogue field label, in every locale.

## Left to the builder

- Where the ordering function and the ordered provider live (likely under
  `lib/features/dive_types/`).
- The schema version number (next free rung at the time of building) and the
  part file it goes in, per the database split rules.
- Test layout: unit tests for the ordering function and codec, repository
  round-trip for the column, widget tests for the sheet and settings page.
