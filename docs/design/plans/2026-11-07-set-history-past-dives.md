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
- `rewriteAssemblyOnDives(assemblyId, rewrites, {required bool alsoLogged,
  bool notify = true})` replaces `rewriteAssemblyOnPastDives`.
- `rewriteSetOnDives(setId, rewrites, {required bool alsoLogged,
  bool notify = true})`.
- Both return the dives they changed and go through one private loop: pick
  the dive ids, read each dive's provenance, apply, skip unchanged,
  `_writeGearDiff`, `_bumpDives`, then notify and schedule the quality scan.
  With `notify: false` the caller does both once its own transaction
  commits, as an agent apply does.
- The queries behind them (which dives carry an assembly or a set, how many,
  and which gear each dive's diver may be given) live in
  `GearTemplateDiveQueries`, next to the repository.
- A part an assembly change adds goes on a dive only as a fresh expansion
  would put it there: active, and usable by the dive's diver (an unowned
  dive: the assembly owner's). A swap onto a part the dive may not take
  only takes the old part off.

`EquipmentSetRepository.updateSet` returns the members it actually added and
removed (after `_liveEquipmentIds`), as a record. The notifier passes it on.

## Domain

`SetHistoryRewrite` (new file next to `gear_history_rewrite.dart`), pure:

- `SetItemAdded(itemId)`: the dive must carry the set. A missing item is
  expanded through `GearExpander.expand` with its active parts, tagged with
  the set. A loose hand-added row is adopted (tagged). A row under another
  assembly, or one another set put there, is left alone, before the
  expander could tag it; so is a part of the item that another set put on
  the dive, with everything under it.
- `SetItemRemoved(itemId)`: only when its row is top level and tagged with
  this set, removes the rows the set hung under it. A row under it that the
  set did not put there (by hand, or by another set), or a part still a
  member in its own right, stays with its own parts and moves to the top
  level.

`applyTo(rows, setId, {index, isActive, isUsable, isMember})`: the
repository loads the components index and the active ids once per batch.
`isUsable` is the filter applying a set already uses
(`EquipmentVisibilityQueries.usableSetMemberIds` for the dive's diver: no
other profile's unshared gear, nothing on the wishlist), resolved per diver;
a dive with no diver is filtered for the set's owner, as the dive edit page
falls back to the diver it is open for. An added item that is inactive or
not usable is not put on the dive. `isMember` names the set's members after
the change.

## Callers

| Path | Template change | Rewrite |
|---|---|---|
| Component picker (add, replace) | as today | always, `alsoLogged` from the dialog |
| Components card (remove) | as today | always, `alsoLogged` from the dialog |
| Set edit page (save) | `updateSet` | always when members changed, `alsoLogged` from the dialog |
| Agent writes, components and sets | as today | always, `alsoLogged: false` |
| UDDF import, clone service, sync | as today | none: they copy or restore data, the diver did not edit a template |

The agent's component update and delete read the row first, for the parent
and the old part the rewrite needs. An update refuses a row that is gone; a
delete of one (say with its assembly earlier in the same set) has nothing to
replay.

A rewrite that fails after the template was saved leaves the template saved
and reports the error, as the component flow does. The set edit page runs it
last, after the default flag and the geofences, so a failure cannot cost
those edits, and runs it even when one of those writes fails, so the planned
dives still follow the members already saved (`saveThenReplay`). The first
error is the one reported.

Adding a member never reaches below a part another assembly holds on the
dive: `GearExpander` leaves such a row and everything under it alone, so a
part the diver took off under that assembly is not put back for the set.

The set edit page asks before writing anything, so Cancel saves nothing. It
asks only when editing, when the ticked members differ from the loaded set,
and when the count is above zero. The save logic moves into a helper file;
the page is at 798 lines.

## Dialog

`showAssemblyHistoryDialog` gains a `setMembers` change whose body is the set
sentence pair. `askAssemblyHistory` counts through
`countLoggedDivesWithAssembly`; a new `askSetHistory` counts through
`countLoggedDivesWithSet`. New strings in all 11 locales:
`equipment_setEdit_historyOnDives` (plural) and `equipment_setEdit_historyAsk`.

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
