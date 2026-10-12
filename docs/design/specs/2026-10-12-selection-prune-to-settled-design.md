# Selection: prune to settled rows in one place

Issue: #2581 (refs #2365, #2572, #2577)

## Problem

Lists that filter through a query id set prune their multi-selection after
every build, so a bulk action can never reach a row that is not on screen.
When a filter changes, the new id set starts with no value, and pruning to that
empty frame dropped every check. #2572 and #2577 fixed this by guarding each
prune by hand:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted && rowsAsync.hasSettled) _selection.pruneTo(visibleIds);
});
```

The rule lives in 18 call sites instead of in the selection mechanism, and each
site has to get two things right:

1. Check `hasSettled` before pruning.
2. Read the ids from the same value the guard checked. `valueOrNull` goes
   through `when`, which returns null for a reload that still holds its
   previous value, while `hasSettled` is true; the prune then wipes every
   check. Buddies still has this mismatch in both modes today, and so do Tags
   and Dive media.

Two related edges come from the same loading window, where the selection bar
and `SelectableListScope` receive empty `selectableIds`:

- Select-all (button or Ctrl/Cmd-A) calls `selectAll([])` and replaces the
  surviving checks with an empty set.
- Bulk actions, Delete included, stay live while the list shows a spinner, so
  they can act on checked rows the new filter is about to hide.

## Goals

- One helper owns the settled rule, and the ids it prunes to are derived from
  the value it checked, so the two cannot disagree.
- Every `AsyncValue`-backed selectable list uses it.
- While rows are unsettled, nothing that acts on rows can run.
- A guard test stops a new list from reintroducing a bare prune.

## Non-goals

- Changing what counts as "visible" or "selectable" on any list.
- The media library, whose rows are not an `AsyncValue` (`state.entries`); it
  keeps `pruneTo`.

## Design

### SelectionController

`lib/shared/selection/selection_controller.dart` gains:

```dart
/// Whether the rows last reported through [pruneToSettled] have loaded or
/// failed. True until a surface reports otherwise, so surfaces that never
/// call it are unaffected.
ValueListenable<bool> get rowsSettled => _rowsSettled;
final ValueNotifier<bool> _rowsSettled = ValueNotifier(true);

void pruneToSettled<T>(
  AsyncValue<T> rows,
  Iterable<String> Function(T rows) idsOf,
)
```

Behaviour of `pruneToSettled`:

| `rows` state | `rowsSettled` | Prune |
| --- | --- | --- |
| First load (no value, no error) | false | none; checks kept |
| Reload holding a previous value | true | to `idsOf(previous value)` |
| Data | true | to `idsOf(value)` |
| Error holding a previous value | true | to `idsOf(previous value)` |
| Error with no value | true | to nothing |

`idsOf` receives the settled value itself. It only needs to repeat the
derivation steps that filter rows: `pruneTo` works on set membership, so sort
order is irrelevant.

`selectAll` becomes a no-op while `rowsSettled` is false. That one guard covers
the bar's select-all button, Ctrl/Cmd-A in `SelectableListScope`, the dive
list's select-by-date-range and its group-header select, all of which route
through `selectAll`.

`dispose()` also disposes `_rowsSettled`. `pruneTo(List<String>)` stays public
for the media library.

`rowsSettled` is a separate notifier rather than a field of `SelectionState`:
settledness describes the rows, not the selection, and `exit()` resets the
state to `SelectionState.inactive`, which would otherwise forget that rows are
still loading.

### SelectionAppBar during loading

`SelectionAppBar` listens to `Listenable.merge([controller,
controller.rowsSettled])`. While rows are unsettled:

- Disabled: select-all, every inline and overflow `BulkAction` (including
  `alwaysEnabled` ones such as select-by-date-range), and Delete.
- Live: Close and Deselect-all (they only discard the diver's own checks), and
  the "N selected" title.

The flag is set in a post-frame callback, so a bar painted one frame earlier
can still show enabled controls. Every dispatch (`_invoke`, `_invokeDelete`)
re-checks `controller.rowsSettled.value` at tap time, so a stale frame cannot
slip an action through.

`SelectableListScope` needs no change: its Ctrl/Cmd-A goes through the guarded
`selectAll`.

### Migration

Each prune becomes:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) _selection.pruneToSettled(rowsAsync, (rows) => rows.map(...));
});
```

| List | File | `idsOf` |
| --- | --- | --- |
| Buddies (list, table) | `lib/features/buddies/presentation/widgets/buddy_list_content.dart` | `rows.map((b) => b.buddy.id)` |
| Certifications (list, table) | `lib/features/certifications/presentation/widgets/certification_list_content.dart` | `rows.map((c) => c.id)` |
| Courses (list, table) | `lib/features/courses/presentation/widgets/course_list_content.dart` | `rows.map((c) => c.id)` |
| Dive centers (list, table) | `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart` | `rows.map((c) => c.id)` |
| Sites (list, table) | `lib/features/dive_sites/presentation/widgets/site_list_content.dart` | `rows.map((s) => s.site.id)` |
| Equipment (list, table) | `lib/features/equipment/presentation/widgets/equipment_list_content.dart` | `rows.map((e) => e.id)` |
| Trips (list, table) | `lib/features/trips/presentation/widgets/trip_list_content.dart` | `rows.map((t) => t.trip.id)` |
| Dives (list) | `lib/features/dive_log/presentation/widgets/dive_list_content.dart` | `(p) => p.dives.map((d) => d.id)` |
| Dives (table) | same | `rows.map((d) => d.id)` |
| Species | `lib/features/marine_life/presentation/pages/species_manage_page.dart` | `_visibleSpecies(rows).where(_isSelectable).map((s) => s.id)` |
| Tags | `lib/features/tags/presentation/pages/tag_manage_page.dart` | `_visibleStats(rows).map((s) => s.tag.id)` |
| Cylinder configs | `lib/features/cylinder_configs/presentation/pages/cylinder_config_list_page.dart` | `rows.map((c) => c.id)` |
| Devices | `lib/features/dive_computer/presentation/pages/device_list_page.dart` | `rows.map((c) => c.id)` |
| Service kinds | `lib/features/equipment/presentation/pages/service_kind_list_page.dart` | `rows.where((k) => !k.isBuiltIn).map((k) => k.id)` |
| Transfers | `lib/features/media_store/presentation/pages/transfers_page.dart` | `rows.map((e) => e.id.toString())` |
| Dive media | `lib/features/media/presentation/widgets/dive_media_section.dart` | `rows.map((m) => m.id)` |
| Site media | `lib/features/media/presentation/widgets/site_media_section.dart` | `rows.map((m) => m.id)` |

The in-build `visibleIds` / `selectableIds` that feed the bar and the scope
stay. Buddies, Tags and Dive media switch them from `valueOrNull` to `.value`
so the bar agrees with the prune. Dive media's enrichment backfill keeps its
own `valueOrNull` read, which is unrelated to selection.

### Architecture guard

`test/architecture/selection_prune_settled_test.dart`, in the allowlist style
of `number_parsing_single_source_test.dart`:

1. A `pruneTo(` call in `lib/` outside `selection_controller.dart` fails
   unless the file is allowlisted with a reason. The allowlist starts with
   `lib/features/media/presentation/pages/media_library_view.dart` (rows are
   not an `AsyncValue`).
2. A `hasSettled` within a few lines of a `pruneTo(` or `pruneToSettled(` call
   fails, so hand-written guards cannot return.
3. Every allowlisted file exists and still calls `pruneTo(`, so a stale
   exemption fails.

## Testing

- `test/shared/selection/selection_controller_test.dart`: `pruneToSettled` for
  first load (no prune, `rowsSettled` false), reload holding a previous value
  (prunes to it), data, error holding a previous value, error with no value
  (prunes to nothing); `rowsSettled` returning to true; `selectAll` a no-op
  while unsettled; disposal.
- `test/shared/selection/selection_app_bar_test.dart`: while unsettled,
  select-all, extras (including `alwaysEnabled`) and Delete are disabled while
  Close and Deselect-all stay live; a handler captured from a settled frame
  dispatches nothing once the controller reports unsettled.
- `test/shared/selection/selectable_list_scope_test.dart`: Ctrl/Cmd-A while
  unsettled keeps the checks.
- Lists: the existing "a new filter keeps the checks" widget tests stay green;
  a Buddies regression for a reload that holds its previous value; one
  list-level test that Delete is disabled during a filter change's loading
  frame.
- The new architecture guard.
