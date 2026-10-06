# Entry/Exit Method Mirroring — Design

Date: 2026-08-06
Status: Approved

## Problem

The dive edit form has two independent pickers for entry method and exit
method, both drawing from the shared `EntryMethod` enum
(`lib/core/constants/enums.dart`). For most dives — especially shore dives —
the two values are identical, so divers select the same value twice on every
log entry. Entry and exit methods should be identical by default, with the
ability to override when they genuinely differ (for example giant stride
entry, ladder exit on a boat dive).

## Decision

This is an **edit-form convenience only**. The saved dive always stores both
concrete values, exactly as today. There is no data-model inheritance, no
schema change, and no change to how any consumer reads the fields.

## Behavior

### Linking

In the single-dive edit page (`dive_edit_page.dart`, used for both new and
existing dives), the exit-method picker is *linked* to the entry-method
picker:

- While linked, changing the entry picker sets the exit picker to the same
  value. Clearing entry clears exit.
- The moment the user changes the exit picker directly, the link breaks for
  the remainder of the editing session. Exit then behaves exactly as it does
  today. The link does not re-form within the session, even if the user
  manually sets exit equal to entry.
- There is no visual link indicator. The behavior is the familiar
  "billing address same as shipping" pattern: follow until touched.

### Link state on open

- New dive: linked.
- Existing dive: linked when the saved exit equals the saved entry, or when
  the saved exit is empty. Unlinked when they differ.
- Opening a dive and saving without touching either picker never changes
  stored values. An empty exit is only backfilled if the user actively
  changes the entry picker during the session (a deliberate act while
  linked), never on load or on an untouched save.

### Out of scope (explicitly unchanged)

- Bulk edit (`bulk_edit_field_set.dart`): its entry and exit dropdowns stay
  fully independent. Mirroring there would silently activate the exit field
  and overwrite per-dive exit values across the selection.
- Database schema, `Dive` entity, sync/HLC handling.
- UDDF export/import, MacDive import.
- Statistics (Conditions breakdowns), dive detail page display.
- l10n: no new strings.

## Implementation

All contained in the `dive_edit_page.dart` state class:

- One new field: `bool _exitMethodLinked`.
- Initialization: `true` for new dives; for loaded dives,
  `_exitMethod == null || _exitMethod == _entryMethod`.
- Entry picker `onChanged`: in addition to setting `_entryMethod`, when
  `_exitMethodLinked` is true also set `_exitMethod` to the same value
  (including null when cleared).
- Exit picker `onChanged`: set `_exitMethod` and set
  `_exitMethodLinked = false`.

Both `EnumPickerRow` call sites (around `dive_edit_page.dart:3562`) are the
only UI touch points. Save paths are unchanged — they already read
`_entryMethod` / `_exitMethod`.

Caution: the same state class also renders the bulk-edit layout
(`_buildBulkForm`, which wraps `_enumDropdown` pickers for the same
`_entryMethod` / `_exitMethod` fields in `BulkFieldGate` rows). The
mirroring logic must therefore live in the single-dive `EnumPickerRow`
`onChanged` handlers only — never in a shared setter — so bulk mode cannot
inherit it accidentally.

## Testing (TDD)

Widget tests for the dive edit page:

1. New dive: selecting an entry method fills the exit picker with the same
   value.
2. New dive: changing entry again updates the mirrored exit (follow
   behavior).
3. Touching the exit picker breaks the link: subsequent entry changes leave
   exit alone for the rest of the session.
4. Existing dive with entry == exit: opens linked; changing entry updates
   both.
5. Existing dive with entry != exit: opens unlinked; changing entry leaves
   exit alone.
6. Existing dive with entry set and exit empty: open and save untouched —
   exit remains empty (no silent backfill).
7. Clearing entry while linked clears exit.

Existing edit-page and bulk-edit tests must continue to pass unmodified
except where they assert the old independent-picker behavior on a new dive.

## Risks

- The re-link-on-open rule infers intent from value equality rather than a
  stored flag. A diver who deliberately set entry = exit = Shore and later
  edits entry to Boat will see exit follow. This is judged the desired
  outcome in almost all cases and avoids schema creep for a form nicety.
