# Equipment sets: update past dives on member changes (issue #4283)

## Goal

Changing a set's members offers the same "also update N past dives" choice
that changing an assembly's parts already offers. The component flow's count
and rewrite are unified on the way, and planned dives follow every template
change.

## Rules

- A dive carries a set when one of its `dive_equipment` rows has
  `via_set_id = <set>`. A dive carries an assembly when it has a
  `dive_equipment` row for that item. One query per case feeds both the
  count and the rewrite.
- Planned dives (`is_planned = 1`) follow every template change; logged dives
  only when the diver picks "Also update N dives". The dialog counts logged
  dives only and is skipped when there are none.
- Every dive of every diver is in scope, as the rewrite already is.
- Unchanged dives are skipped, as today.

## Data layer

`DiveRepository` (methods on the class, not an extension, so the widget
tests' `Fake implements DiveRepository` can override them):

- `countLoggedDivesWithAssembly(assemblyId)` and
  `countLoggedDivesWithSet(setId)`.
- `rewriteAssemblyOnDives(assemblyId, rewrites, {required bool alsoLogged})`
  replaces `rewriteAssemblyOnPastDives`.
- `rewriteSetOnDives(setId, rewrites, {required bool alsoLogged})`.
- Both go through one private loop: pick the dive ids, read each dive's
  provenance, apply, skip unchanged, `_writeGearDiff`, `_bumpDives`, then
  notify and schedule the quality scan.

`EquipmentSetRepository.updateSet` returns the members it actually added and
removed (after `_liveEquipmentIds`), as a record. The notifier passes it on.

## Domain

`SetHistoryRewrite` (new file next to `gear_history_rewrite.dart`), pure:

- `SetItemAdded(itemId)`: the dive must carry the set. A missing item is
  expanded through `GearExpander.expand` with its active parts, tagged with
  the set. A loose hand-added row is adopted (tagged). A row under another
  assembly is left alone, before the expander could tag it.
- `SetItemRemoved(itemId)`: removes the item's subtree only when its row is
  top level and tagged with this set.

`applyTo(rows, setId, {index, isActive, isUsable})`: the repository loads the
components index and the active ids once per batch. `isUsable` is the filter
applying a set already uses (`EquipmentVisibilityQueries.usableSetMemberIds`
for the dive's diver: no other profile's unshared gear, nothing on the
wishlist), resolved per diver; a dive with no diver skips it, as the dive
edit page does. An added item that is inactive or not usable is not put on
the dive.

## Callers

| Path | Template change | Rewrite |
|---|---|---|
| Component picker (add, replace) | as today | always, `alsoLogged` from the dialog |
| Components card (remove) | as today | always, `alsoLogged` from the dialog |
| Set edit page (save) | `updateSet` | always when members changed, `alsoLogged` from the dialog |
| Agent writes, components and sets | as today | always, `alsoLogged: false` |
| UDDF import, clone service, sync | as today | none: they copy or restore data, the diver did not edit a template |

The agent's component update and delete read the row first, for the parent
and the old part the rewrite needs, and refuse a row that is gone.

A rewrite that fails after the template was saved leaves the template saved
and reports the error, as the component flow does.

The set edit page asks before writing anything, so Cancel saves nothing. It
asks only when editing, when the ticked members differ from the loaded set,
and when the count is above zero. The save logic moves into a helper file;
the page is at 798 lines.

## Dialog

`showAssemblyHistoryDialog` gains a `setMembers` change whose body is the set
sentence pair. `askAssemblyHistory` counts through
`countLoggedDivesWithAssembly`; a new `askSetHistory` counts through
`countLoggedDivesWithSet`. New strings in all 11 locales:
`equipment_setHistory_onDives` (plural) and `equipment_setHistory_ask`.

## Tests (TDD)

- `set_history_rewrite_test.dart`: add (missing, hand-added, nested, dive
  without the set, inactive part skipped), remove (tagged, hand-added kept,
  nested kept, dive without the set).
- Repository: count and rewrite agree for sets and assemblies; planned dives
  rewritten with `alsoLogged: false` and never counted; logged dives only
  with `alsoLogged: true`; plans untouched; unchanged dives not re-stamped;
  `updateSet` returns its diff.
- Agent writes: a set or component change rewrites planned dives only.
- Widgets: set edit page dialog conditions and the three answers; picker and
  card call the rewrite on "From now on" too, with `alsoLogged: false`.

## Out of scope

Dives without a set tag, saved plans, `dive_tanks`, an agent parameter for
past dives.
