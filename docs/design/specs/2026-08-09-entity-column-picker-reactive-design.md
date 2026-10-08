# Reactive entity table column picker

**Date:** 2026-08-09
**Status:** Approved

## Problem

User report:

> Buddy column view settings do not dynamically update status like it does for
> dives (pin/show/hide happens silently in the background)

Opening **Column settings** on the buddy table and tapping pin, remove, or add
changes nothing in the sheet. The underlying table does update, so the change
appears to happen "silently in the background". The dive table's column picker
updates its sheet immediately.

## Root cause

Two column pickers exist, and only one is reactive.

`TableColumnPicker` (dives, `lib/features/dive_log/presentation/widgets/table_column_picker.dart`)
is a `ConsumerWidget`. It calls `ref.watch(tableViewConfigProvider)` inside its
own `build`, so the sheet is itself a Riverpod consumer and rebuilds on every
mutation.

`EntityTableColumnPicker` (`lib/shared/widgets/entity_table/entity_table_column_picker.dart`)
is a plain `StatelessWidget` that receives `config` as a constructor field.
Every call site passes a snapshot taken with `ref.read`, for example
`buddy_list_page.dart:82`:

```dart
final config = ref.read(buddyTableConfigProvider);
final notifier = ref.read(buddyTableConfigProvider.notifier);
showEntityTableColumnPicker<BuddyField>(
  context,
  config: config,
  adapter: BuddyFieldAdapter.instance,
  onToggleColumn: notifier.toggleColumn,
  onReorderColumn: notifier.reorderColumn,
  onTogglePin: notifier.togglePin,
);
```

`ref.read` samples a value without registering a dependency. The callbacks fire
and `EntityTableConfigNotifier` updates its state correctly, and the list content
widgets do use `ref.watch`, so the table behind the sheet re-renders. The sheet
holds a config frozen at open time for as long as it stays open.

Four visible symptoms, one cause:

| Action | Expected in sheet | Actual |
| ------ | ----------------- | ------ |
| Pin / unpin | Icon flips `push_pin` <-> `push_pin_outlined`; Remove button appears or disappears | No change |
| Remove | Column leaves VISIBLE COLUMNS, appears under AVAILABLE FIELDS | No change |
| Add | Field leaves AVAILABLE FIELDS, appears in VISIBLE COLUMNS | No change |
| Reorder | Row settles in its new position | Row snaps back to original position |

## Scope

The shared picker is used by seven entity tables, all with the identical defect:

- buddies (`buddy_list_page.dart`)
- courses (`course_list_page.dart`)
- dive sites (`site_list_page.dart`)
- certifications (`certification_list_page.dart`)
- trips (`trip_list_page.dart`)
- dive centers (`dive_center_list_page.dart`)
- equipment (`equipment_list_page.dart`)

All seven are fixed. Fixing only buddies would leave six instances of the same
bug and an inconsistency inside a shared widget.

## Design

Invert the dependency. The sheet subscribes to the provider instead of being fed
a snapshot of its value.

### API

```dart
void showEntityTableColumnPicker<F extends EntityField>(
  BuildContext context, {
  required StateNotifierProvider<EntityTableConfigNotifier<F>,
      EntityTableViewConfig<F>> configProvider,
  required EntityFieldAdapter<dynamic, F> adapter,
})
```

`EntityTableColumnPicker<F>` becomes a `ConsumerWidget`:

- `ref.watch(configProvider)` supplies the config, so the sheet rebuilds on
  every mutation
- `ref.read(configProvider.notifier)` supplies `toggleColumn`, `reorderColumn`,
  and `togglePin`

Four parameters (`config`, `onToggleColumn`, `onReorderColumn`, `onTogglePin`)
collapse into one (`configProvider`); `adapter` is unchanged. The result is
structurally identical to
`TableColumnPicker`, so the two pickers stop diverging.

This removes the class of bug rather than the instance: there is no longer a
snapshot that can go stale, so the mistake cannot be reintroduced at a call site.

### Why the generic change is clean

All seven providers share one declared type:

```dart
StateNotifierProvider<EntityTableConfigNotifier<F>, EntityTableViewConfig<F>>
```

A single type parameter `F` threads the whole signature. `StateNotifierProvider`
lives in `flutter_riverpod/legacy` under Riverpod 3; the project's barrel
`lib/core/providers/provider.dart` re-exports both `flutter_riverpod` and
`flutter_riverpod/legacy`, so importing the barrel supplies `ConsumerWidget` and
the legacy provider type together. `entity_table_config_providers.dart` already
imports it this way.

No changes to `EntityTableConfigNotifier`, `EntityTableViewConfig`, or the
persistence path. `_save()` debouncing is untouched.

### Call sites

Each `onPressed` shrinks from six lines to three:

```dart
columnSettingsAction: IconButton(
  icon: const Icon(Icons.view_column_outlined),
  tooltip: 'Column settings',
  onPressed: () => showEntityTableColumnPicker<BuddyField>(
    context,
    configProvider: buddyTableConfigProvider,
    adapter: BuddyFieldAdapter.instance,
  ),
),
```

## Included improvement: reuse existing translations

The entity picker hardcodes English `'Columns'`, `'Done'`, `'VISIBLE COLUMNS'`,
and `'AVAILABLE FIELDS'`, while the dive picker uses `context.l10n`. The keys
`columnConfig_columns`, `columnConfig_done`, `columnConfig_visibleColumns`, and
`columnConfig_availableFields` already exist and are translated in all 12
locales, so this adds no new ARB entries and leaves English output byte
identical (the code uppercases the section labels, as the dive picker does).
Since the `build` method is being rewritten anyway, the literals are swapped for
`context.l10n` lookups.

**Explicitly out of scope:**

- The `'Column settings'` tooltip on the seven pages — needs new ARB keys across
  12 locales, and sits outside the sheet.
- The `Pin` / `Unpin` / `Remove` / `Add` tooltips — hardcoded in the dive picker
  too, so localizing only the entity picker would create a new inconsistency
  rather than remove one.

## Testing

`test/shared/widgets/entity_table/entity_table_column_picker_test.dart` (354
lines) currently asserts that callbacks fired:

```dart
expect(toggledField, equals(_TestField.entityStatus));
```

That assertion passes while the bug is present — the callback does fire; the
sheet just never redraws. The tests are rewritten to drive a real
`StateNotifierProvider` built over the existing `_TestField` and `_TestAdapter`
fixtures, and to assert on what the user sees.

New or rewritten cases:

1. **Pin toggles visibly** — tap Pin on the unpinned column; filled `push_pin`
   count goes from 1 to 2 and that row's Remove button disappears.
2. **Unpin toggles visibly** — tap Unpin on the pinned column; icon becomes
   outlined and a Remove button appears for it.
3. **Remove moves the field** — tap Remove on a visible column; the field
   disappears from the reorderable list and appears under AVAILABLE FIELDS with
   an Add button.
4. **Add moves the field** — tap Add on a hidden field; it appears in VISIBLE
   COLUMNS, and its category header disappears once that category is empty.
5. **Reorder persists** — drag a row and confirm the new order survives the
   rebuild rather than snapping back.

Carried over unchanged: sheet opens, section headers render, visible/hidden
fields are partitioned correctly, category headers appear only for categories
with hidden fields, Done dismisses the sheet, all-visible config hides every
category section.

`test/helpers/test_app.dart` already wraps children in a `ProviderScope` and
installs the l10n delegates, so no helper changes are needed and the l10n swap
does not change any asserted English string.

## Verification

- `flutter analyze` clean
- `flutter test` passing
- `dart format .` produces no changes
- Manual run on macOS: open buddy table -> Column settings, confirm pin, remove,
  add, and reorder all update the sheet immediately

## Files touched

**Modified:**

- `lib/shared/widgets/entity_table/entity_table_column_picker.dart`
- `lib/features/buddies/presentation/pages/buddy_list_page.dart`
- `lib/features/courses/presentation/pages/course_list_page.dart`
- `lib/features/dive_sites/presentation/pages/site_list_page.dart`
- `lib/features/certifications/presentation/pages/certification_list_page.dart`
- `lib/features/trips/presentation/pages/trip_list_page.dart`
- `lib/features/dive_centers/presentation/pages/dive_center_list_page.dart`
- `lib/features/equipment/presentation/pages/equipment_list_page.dart`
- `test/shared/widgets/entity_table/entity_table_column_picker_test.dart`

No new files. No database, ARB, or codegen changes.
