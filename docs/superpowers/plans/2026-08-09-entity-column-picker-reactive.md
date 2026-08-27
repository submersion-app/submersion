# Reactive Entity Table Column Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the shared entity table column picker update its own sheet immediately when a column is pinned, removed, added, or reordered, matching the dive table's picker.

**Architecture:** `EntityTableColumnPicker` currently receives an `EntityTableViewConfig` snapshot captured with `ref.read` at open time, so it never rebuilds. Change it to receive the `StateNotifierProvider` itself and become a `ConsumerWidget` that calls `ref.watch` on it, exactly as `TableColumnPicker` (dives) already does. All seven call sites lose four parameters and gain one.

**Tech Stack:** Flutter 3.44.4 / Dart 3.12.2, Riverpod (legacy `StateNotifierProvider`), Material 3, `flutter_test` widget tests.

**Spec:** `docs/superpowers/specs/2026-08-09-entity-column-picker-reactive-design.md`

## Global Constraints

- Worktree: `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/entity-column-picker-reactive`, branch `worktree-entity-column-picker-reactive`. Use worktree-absolute paths for every Read/Edit/Write; a main-tree absolute path silently edits the main checkout.
- No emojis in code, comments, or docs.
- Immutability: never mutate an existing `EntityTableViewConfig` or its column list in place; use `copyWith`.
- `dart format .` (whole repo) must produce no changes. CI formats the whole project.
- `flutter analyze` must be run with NO path argument before claiming green. CI treats info-level lints, including in `test/`, as failures.
- Never pipe an `analyze` or `test` run you are gating on into `tail`/`grep` — the pipeline exit status becomes the pipe's and masks failure. Use `<cmd> > log 2>&1; echo EXIT:$?`.
- Do not add new ARB keys. Only keys that already exist in all 12 locales may be used.
- `flutter test` on the whole suite must be run with `run_in_background: true`; targeted files may run in the foreground.

## File Structure

**Modified:**

| File | Responsibility after the change |
| ---- | ------------------------------- |
| `lib/shared/widgets/entity_table/entity_table_column_picker.dart` | Owns the picker sheet. Becomes a `ConsumerWidget`; subscribes to the config provider it is given and reads mutations off that provider's notifier. Exports the `EntityTableConfigProvider<F>` typedef used by call sites. |
| `lib/features/buddies/presentation/pages/buddy_list_page.dart` | Passes `buddyTableConfigProvider` instead of a snapshot plus three callbacks. |
| `lib/features/courses/presentation/pages/course_list_page.dart` | Same, `courseTableConfigProvider`. |
| `lib/features/dive_sites/presentation/pages/site_list_page.dart` | Same, `siteTableConfigProvider`. |
| `lib/features/certifications/presentation/pages/certification_list_page.dart` | Same, `certificationTableConfigProvider`. |
| `lib/features/trips/presentation/pages/trip_list_page.dart` | Same, `tripTableConfigProvider`. |
| `lib/features/dive_centers/presentation/pages/dive_center_list_page.dart` | Same, `diveCenterTableConfigProvider`. |
| `lib/features/equipment/presentation/pages/equipment_list_page.dart` | Same, `equipmentTableConfigProvider`. |
| `test/shared/widgets/entity_table/entity_table_column_picker_test.dart` | Drives the picker through a real `StateNotifierProvider` and asserts on rendered state rather than on callback invocation. |

**Created:** none. **Not touched:** `EntityTableConfigNotifier`, `EntityTableViewConfig`, `EntityTableColumnConfig`, any ARB file, any generated file, the database.

## Background the implementer needs

**Why the bug exists.** `ref.read(provider)` samples a value without subscribing. `ref.watch(provider)` subscribes and triggers rebuilds. The picker was handed a `ref.read` result, so it rendered a config frozen at open time. The list content widgets behind the sheet use `ref.watch`, which is why the table updated while the sheet did not.

**`onReorderItem`, not `onReorder`.** `ReorderableListView.builder` in Flutter 3.44 deprecates `onReorder` in favour of `onReorderItem`, which pre-adjusts `newIndex` for the item removed at `oldIndex`. `EntityTableConfigNotifier.reorderColumn` does a plain `removeAt` then `insert`, which is correct only against that pre-adjusted index. Leave `onReorderItem` alone.

**The 500 ms debounce timer.** Every notifier mutation calls `_save()`, which starts a 500 ms `Timer`. In widget tests the notifier has no repository (`init` is never called), so the timer callback is a harmless no-op — but `testWidgets` fails a test that ends with a pending timer, and `pumpAndSettle` does NOT drain a bare `Timer` because a `Timer` schedules no frames. Every test that triggers a mutation must end with `await tester.pump(const Duration(milliseconds: 600));`.

**No page test opens this sheet.** Grep confirms no test taps the "Column settings" button, so the signature change breaks no existing page test — only the picker's own test file.

---

### Task 1: Make the picker subscribe to its config provider

**Files:**
- Modify: `lib/shared/widgets/entity_table/entity_table_column_picker.dart` (whole file)
- Modify: `lib/features/buddies/presentation/pages/buddy_list_page.dart:78-93`
- Modify: `lib/features/courses/presentation/pages/course_list_page.dart:77-92`
- Modify: `lib/features/dive_sites/presentation/pages/site_list_page.dart:118-133`
- Modify: `lib/features/certifications/presentation/pages/certification_list_page.dart:78-95`
- Modify: `lib/features/trips/presentation/pages/trip_list_page.dart:78-93`
- Modify: `lib/features/dive_centers/presentation/pages/dive_center_list_page.dart:121-136`
- Modify: `lib/features/equipment/presentation/pages/equipment_list_page.dart:115-130`
- Test: `test/shared/widgets/entity_table/entity_table_column_picker_test.dart`

**Interfaces:**

- Consumes (all already exist, do not redefine):
  - `EntityTableConfigNotifier<F extends EntityField>` from `lib/shared/providers/entity_table_config_providers.dart`, with `void toggleColumn(F field)`, `void reorderColumn(int oldIndex, int newIndex)`, `void togglePin(F field)`.
  - `EntityTableViewConfig<F>` from `lib/shared/models/entity_table_config.dart`, with `List<EntityTableColumnConfig<F>> columns`.
  - `EntityTableColumnConfig<F>` with `F field` and `bool isPinned`.
  - `EntityFieldAdapter<T, F>` from `lib/shared/constants/entity_field.dart`, with `Map<String, List<F>> get fieldsByCategory` and `F fieldFromName(String name)`.
  - `lib/core/providers/provider.dart` is a barrel re-exporting `package:flutter_riverpod/flutter_riverpod.dart` AND `package:flutter_riverpod/legacy.dart`. It is the only import needed for both `ConsumerWidget` and `StateNotifierProvider`.

- Produces (later tasks and all call sites rely on these exact names):
  - `typedef EntityTableConfigProvider<F extends EntityField> = StateNotifierProvider<EntityTableConfigNotifier<F>, EntityTableViewConfig<F>>;`
  - `void showEntityTableColumnPicker<F extends EntityField>(BuildContext context, {required EntityTableConfigProvider<F> configProvider, required EntityFieldAdapter<dynamic, F> adapter})`
  - `class EntityTableColumnPicker<F extends EntityField> extends ConsumerWidget` with fields `configProvider` and `adapter`.

- [ ] **Step 1: Replace the test file's fixtures and launcher with provider-driven versions**

In `test/shared/widgets/entity_table/entity_table_column_picker_test.dart`, leave the `_TestField` class (lines 14-84) and `_TestAdapter` class (lines 90-110) exactly as they are. Replace the "Helpers" section — everything from `final _adapter = _TestAdapter();` down to the closing brace of `_buildPickerLauncher` — with this:

```dart
final _adapter = _TestAdapter();

/// Config where name (pinned) and count are visible; status and description
/// are hidden. Safe to share across tests: the notifier copies it into state
/// and every mutation builds new lists rather than mutating in place.
final _config = EntityTableViewConfig<_TestField>(
  columns: [
    EntityTableColumnConfig(field: _TestField.entityName, isPinned: true),
    EntityTableColumnConfig(field: _TestField.entityCount),
  ],
);

/// Builds a fresh provider backed by a real [EntityTableConfigNotifier], so
/// the picker exercises the same subscription path it uses in the app.
EntityTableConfigProvider<_TestField> _makeConfigProvider(
  EntityTableViewConfig<_TestField> initial,
) {
  return StateNotifierProvider<
    EntityTableConfigNotifier<_TestField>,
    EntityTableViewConfig<_TestField>
  >(
    (ref) => EntityTableConfigNotifier<_TestField>(
      defaultConfig: initial,
      fieldFromName: _adapter.fieldFromName,
    ),
  );
}

/// Builds a scaffold with a button that opens the column picker bottom sheet.
///
/// Pass [provider] when the test needs to drive the notifier directly;
/// otherwise a fresh provider is created from [config].
Widget _buildPickerLauncher({
  EntityTableViewConfig<_TestField>? config,
  EntityTableConfigProvider<_TestField>? provider,
  Locale? locale,
}) {
  final configProvider = provider ?? _makeConfigProvider(config ?? _config);
  return testApp(
    locale: locale,
    child: Builder(
      builder: (context) {
        return ElevatedButton(
          onPressed: () => showEntityTableColumnPicker<_TestField>(
            context,
            configProvider: configProvider,
            adapter: _adapter,
          ),
          child: const Text('Open Picker'),
        );
      },
    ),
  );
}

/// Reads the [ProviderContainer] backing the open sheet, so a test can mutate
/// the notifier the way non-picker code would and assert the sheet reacts.
ProviderContainer _containerOf(WidgetTester tester) {
  return ProviderScope.containerOf(
    tester.element(find.byType(EntityTableColumnPicker<_TestField>)),
  );
}

/// Drains the notifier's 500 ms save debounce. `pumpAndSettle` does not do
/// this: a bare Timer schedules no frames, and `testWidgets` fails a test that
/// ends with a timer still pending.
Future<void> _drainSaveDebounce(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 600));
}
```

Then replace the file's import block (lines 1-8) with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_column_picker.dart';

import '../../../helpers/test_app.dart';
```

- [ ] **Step 2: Delete the two callback-only tests and add the five reactivity tests**

Delete these existing tests entirely — they assert that a callback fired, which is true even with the bug present, so they cannot detect the regression:

- `'toggling a hidden field calls onToggleColumn callback'`
- `'removing a visible unpinned column calls onToggleColumn'`
- `'tapping pin icon calls onTogglePin callback'`

Keep unchanged: `'opens the picker dialog'`, `'shows visible columns section with current column names'`, `'shows available fields section with hidden fields'`, `'category headers are displayed for hidden fields'`, `'pinned column shows filled pin icon, unpinned shows outlined'`, `'Done button closes the picker'`, `'all fields visible hides available fields categories'`.

Add these five tests inside the existing `group('EntityTableColumnPicker', ...)`:

```dart
testWidgets('pinning a column updates the sheet without reopening it', (
  tester,
) async {
  await tester.pumpWidget(_buildPickerLauncher());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open Picker'));
  await tester.pumpAndSettle();

  // Name is pinned, Count is not.
  expect(find.byIcon(Icons.push_pin), findsOneWidget);
  expect(find.byIcon(Icons.push_pin_outlined), findsOneWidget);

  // Pin Count -- the only column offering a "Pin" tooltip.
  await tester.tap(find.byTooltip('Pin'));
  await tester.pumpAndSettle();

  expect(find.byIcon(Icons.push_pin), findsNWidgets(2));
  expect(find.byIcon(Icons.push_pin_outlined), findsNothing);
  // Pinned columns cannot be removed, so no Remove button survives.
  expect(find.byTooltip('Remove'), findsNothing);

  await _drainSaveDebounce(tester);
});

testWidgets('unpinning a column reveals its Remove button immediately', (
  tester,
) async {
  await tester.pumpWidget(_buildPickerLauncher());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open Picker'));
  await tester.pumpAndSettle();

  // Only Count (unpinned) offers Remove.
  expect(find.byTooltip('Remove'), findsOneWidget);

  await tester.tap(find.byTooltip('Unpin'));
  await tester.pumpAndSettle();

  expect(find.byIcon(Icons.push_pin), findsNothing);
  expect(find.byIcon(Icons.push_pin_outlined), findsNWidgets(2));
  expect(find.byTooltip('Remove'), findsNWidgets(2));

  await _drainSaveDebounce(tester);
});

testWidgets('removing a column moves it into AVAILABLE FIELDS immediately', (
  tester,
) async {
  await tester.pumpWidget(_buildPickerLauncher());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open Picker'));
  await tester.pumpAndSettle();

  // Status and description are hidden; the core category is fully visible.
  expect(find.byTooltip('Add'), findsNWidgets(2));
  expect(find.text('CORE'), findsNothing);

  await tester.tap(find.byTooltip('Remove'));
  await tester.pumpAndSettle();

  // Count now sits in the available section with an Add button.
  final countTile = find.widgetWithText(ListTile, 'Count');
  expect(countTile, findsOneWidget);
  expect(
    find.descendant(of: countTile, matching: find.byTooltip('Add')),
    findsOneWidget,
  );
  expect(find.byTooltip('Add'), findsNWidgets(3));
  // The core category now has a hidden field, so its header appears.
  expect(find.text('CORE'), findsOneWidget);

  await _drainSaveDebounce(tester);
});

testWidgets('adding a field moves it into VISIBLE COLUMNS immediately', (
  tester,
) async {
  await tester.pumpWidget(_buildPickerLauncher());
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open Picker'));
  await tester.pumpAndSettle();

  // Two visible columns means two drag handles.
  expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));

  final statusTile = find.widgetWithText(ListTile, 'Status');
  await tester.tap(
    find.descendant(of: statusTile, matching: find.byTooltip('Add')),
  );
  await tester.pumpAndSettle();

  // Status is now a visible column: it has a drag handle and a Pin button.
  expect(find.byIcon(Icons.drag_handle), findsNWidgets(3));
  final promotedStatus = find.widgetWithText(ListTile, 'Status');
  expect(
    find.descendant(of: promotedStatus, matching: find.byTooltip('Pin')),
    findsOneWidget,
  );
  // Only Description is left to add, and its category header still shows.
  expect(find.byTooltip('Add'), findsOneWidget);
  expect(find.text('DETAILS'), findsOneWidget);

  // Adding the last hidden field empties the category, which must drop its
  // header on the same rebuild.
  await tester.tap(find.byTooltip('Add'));
  await tester.pumpAndSettle();

  expect(find.byIcon(Icons.drag_handle), findsNWidgets(4));
  expect(find.byTooltip('Add'), findsNothing);
  expect(find.text('DETAILS'), findsNothing);

  await _drainSaveDebounce(tester);
});

testWidgets('sheet re-renders when the config changes from outside', (
  tester,
) async {
  final provider = _makeConfigProvider(_config);
  await tester.pumpWidget(_buildPickerLauncher(provider: provider));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open Picker'));
  await tester.pumpAndSettle();

  // Initial order: Name then Count.
  final initialOrder = tester
      .widgetList<ListTile>(find.byType(ListTile))
      .map((t) => (t.title! as Text).data)
      .toList();
  expect(initialOrder.take(2), equals(['Name', 'Count']));

  // Move Count above Name through the notifier, exactly as a completed drag
  // would. The open sheet must pick this up on its own.
  _containerOf(tester).read(provider.notifier).reorderColumn(1, 0);
  await tester.pumpAndSettle();

  final reordered = tester
      .widgetList<ListTile>(find.byType(ListTile))
      .map((t) => (t.title! as Text).data)
      .toList();
  expect(reordered.take(2), equals(['Count', 'Name']));

  await _drainSaveDebounce(tester);
});
```

- [ ] **Step 3: Run the test file and confirm it fails**

Run: `flutter test test/shared/widgets/entity_table/entity_table_column_picker_test.dart`

Expected: FAIL at compile time. `showEntityTableColumnPicker` has no `configProvider` parameter and still requires `config`, `onToggleColumn`, `onReorderColumn`, `onTogglePin`; `EntityTableConfigProvider` is undefined. Do not proceed until you have seen this failure.

- [ ] **Step 4: Rewrite the picker widget**

Replace the entire contents of `lib/shared/widgets/entity_table/entity_table_column_picker.dart` with the following. Only the imports, the typedef, the `show...` signature, the class declaration, and the `build` header change; the sheet's layout is byte-identical to the current version apart from `notifier.` prefixes on the three callbacks. `_AvailableCategorySection` is unchanged.

```dart
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

/// The provider type backing an entity table's column configuration.
///
/// Every entity table declares its provider with this shape, so the picker can
/// accept any of them behind a single type parameter.
typedef EntityTableConfigProvider<F extends EntityField> =
    StateNotifierProvider<
      EntityTableConfigNotifier<F>,
      EntityTableViewConfig<F>
    >;

/// Shows the [EntityTableColumnPicker] as a modal bottom sheet.
///
/// Takes the config provider itself rather than a config value: the sheet
/// subscribes to it, so pin, add, remove, and reorder are reflected while the
/// sheet stays open.
void showEntityTableColumnPicker<F extends EntityField>(
  BuildContext context, {
  required EntityTableConfigProvider<F> configProvider,
  required EntityFieldAdapter<dynamic, F> adapter,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => EntityTableColumnPicker<F>(
      configProvider: configProvider,
      adapter: adapter,
    ),
  );
}

/// Generic bottom sheet that lets users toggle column visibility and reorder
/// columns for any entity table.
///
/// Top section: reorderable list of visible columns with pin/remove controls.
/// Bottom section: available fields grouped by category with add buttons.
class EntityTableColumnPicker<F extends EntityField> extends ConsumerWidget {
  final EntityTableConfigProvider<F> configProvider;
  final EntityFieldAdapter<dynamic, F> adapter;

  const EntityTableColumnPicker({
    super.key,
    required this.configProvider,
    required this.adapter,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configProvider);
    final notifier = ref.read(configProvider.notifier);
    final theme = Theme.of(context);
    final visibleFields = config.columns.map((c) => c.field).toSet();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Columns', style: theme.textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  // Visible columns (reorderable)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'VISIBLE COLUMNS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: config.columns.length,
                    onReorderItem: notifier.reorderColumn,
                    itemBuilder: (context, index) {
                      final col = config.columns[index];
                      return ListTile(
                        key: ValueKey(col.field.name),
                        dense: true,
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(col.field.displayName),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                col.isPinned
                                    ? Icons.push_pin
                                    : Icons.push_pin_outlined,
                                size: 18,
                              ),
                              visualDensity: VisualDensity.compact,
                              tooltip: col.isPinned ? 'Unpin' : 'Pin',
                              onPressed: () => notifier.togglePin(col.field),
                            ),
                            if (!col.isPinned)
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  size: 18,
                                ),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Remove',
                                onPressed: () =>
                                    notifier.toggleColumn(col.field),
                              ),
                          ],
                        ),
                      );
                    },
                  ),

                  const Divider(height: 1),

                  // Available fields (grouped by category)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      'AVAILABLE FIELDS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  for (final entry in adapter.fieldsByCategory.entries)
                    _AvailableCategorySection<F>(
                      categoryName: entry.key,
                      fields: entry.value,
                      visibleFields: visibleFields,
                      onAdd: notifier.toggleColumn,
                    ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Renders a category header followed by add-buttons for each hidden field
/// in that category. Skipped entirely when all fields are already visible.
class _AvailableCategorySection<F extends EntityField> extends StatelessWidget {
  const _AvailableCategorySection({
    required this.categoryName,
    required this.fields,
    required this.visibleFields,
    required this.onAdd,
  });

  final String categoryName;
  final List<F> fields;
  final Set<EntityField> visibleFields;
  final void Function(F field) onAdd;

  @override
  Widget build(BuildContext context) {
    final hiddenFields = fields
        .where((f) => !visibleFields.contains(f))
        .toList();
    if (hiddenFields.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            categoryName.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
        ),
        for (final field in hiddenFields)
          ListTile(
            dense: true,
            leading: field.icon != null ? Icon(field.icon, size: 18) : null,
            title: Text(field.displayName),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 18),
              visualDensity: VisualDensity.compact,
              tooltip: 'Add',
              onPressed: () => onAdd(field),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: Run the picker test file and confirm it passes**

Run: `flutter test test/shared/widgets/entity_table/entity_table_column_picker_test.dart`

Expected: PASS, 12 tests. If a test fails with "A Timer is still pending", a mutation test is missing its `await _drainSaveDebounce(tester);`.

- [ ] **Step 6: Update the buddy call site**

In `lib/features/buddies/presentation/pages/buddy_list_page.dart`, replace lines 78-93:

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

- [ ] **Step 7: Update the remaining six call sites**

Apply the identical shape to each. The tooltip, icon, and trailing comma stay as they are; only the `onPressed` body changes from a block body to an arrow call.

`lib/features/courses/presentation/pages/course_list_page.dart` lines 77-92:

```dart
          columnSettingsAction: IconButton(
            icon: const Icon(Icons.view_column_outlined),
            tooltip: 'Column settings',
            onPressed: () => showEntityTableColumnPicker<CourseField>(
              context,
              configProvider: courseTableConfigProvider,
              adapter: CourseFieldAdapter.instance,
            ),
          ),
```

`lib/features/dive_sites/presentation/pages/site_list_page.dart` lines 118-133 (note: this file is indented two spaces less than the others):

```dart
        columnSettingsAction: IconButton(
          icon: const Icon(Icons.view_column_outlined),
          tooltip: 'Column settings',
          onPressed: () => showEntityTableColumnPicker<SiteField>(
            context,
            configProvider: siteTableConfigProvider,
            adapter: SiteFieldAdapter.instance,
          ),
        ),
```

`lib/features/certifications/presentation/pages/certification_list_page.dart` lines 78-95:

```dart
          columnSettingsAction: IconButton(
            icon: const Icon(Icons.view_column_outlined),
            tooltip: 'Column settings',
            onPressed: () => showEntityTableColumnPicker<CertificationField>(
              context,
              configProvider: certificationTableConfigProvider,
              adapter: CertificationFieldAdapter.instance,
            ),
          ),
```

`lib/features/trips/presentation/pages/trip_list_page.dart` lines 78-93:

```dart
          columnSettingsAction: IconButton(
            icon: const Icon(Icons.view_column_outlined),
            tooltip: 'Column settings',
            onPressed: () => showEntityTableColumnPicker<TripField>(
              context,
              configProvider: tripTableConfigProvider,
              adapter: TripFieldAdapter.instance,
            ),
          ),
```

`lib/features/dive_centers/presentation/pages/dive_center_list_page.dart` lines 121-136 (two spaces less indent):

```dart
        columnSettingsAction: IconButton(
          icon: const Icon(Icons.view_column_outlined),
          tooltip: 'Column settings',
          onPressed: () => showEntityTableColumnPicker<DiveCenterField>(
            context,
            configProvider: diveCenterTableConfigProvider,
            adapter: DiveCenterFieldAdapter.instance,
          ),
        ),
```

`lib/features/equipment/presentation/pages/equipment_list_page.dart` lines 115-130:

```dart
          columnSettingsAction: IconButton(
            icon: const Icon(Icons.view_column_outlined),
            tooltip: 'Column settings',
            onPressed: () => showEntityTableColumnPicker<EquipmentField>(
              context,
              configProvider: equipmentTableConfigProvider,
              adapter: EquipmentFieldAdapter.instance,
            ),
          ),
```

Do NOT remove any import from these seven files. Each still references its `<entity>TableConfigProvider` and its `<Entity>FieldAdapter`, so every existing import is still used.

- [ ] **Step 8: Analyze the whole project**

Run: `flutter analyze`

Expected: "No issues found!". No path argument, no pipe. If a page reports an unused local or an unused import, you left a stray `final config = ...` or `final notifier = ...` line behind — delete it.

- [ ] **Step 9: Format and run the affected page tests**

Run: `dart format .`

Then run the seven page test files that exercise these pages, one command each to stay inside the Bash timeout:

```
flutter test test/features/courses/presentation/pages/course_list_page_test.dart
flutter test test/features/dive_sites/presentation/pages/site_list_page_test.dart
flutter test test/features/certifications/presentation/pages/certification_list_page_test.dart
flutter test test/features/trips/presentation/pages/trip_list_page_test.dart
flutter test test/shared/widgets/entity_table/entity_table_column_picker_test.dart
flutter test test/shared/widgets/table_mode_layout/table_mode_layout_test.dart
flutter test test/features/shared/entity_table_config_provider_integration_test.dart
```

Expected: all pass.

- [ ] **Step 10: Commit**

```bash
git add lib/shared/widgets/entity_table/entity_table_column_picker.dart lib/features/buddies/presentation/pages/buddy_list_page.dart lib/features/courses/presentation/pages/course_list_page.dart lib/features/dive_sites/presentation/pages/site_list_page.dart lib/features/certifications/presentation/pages/certification_list_page.dart lib/features/trips/presentation/pages/trip_list_page.dart lib/features/dive_centers/presentation/pages/dive_center_list_page.dart lib/features/equipment/presentation/pages/equipment_list_page.dart test/shared/widgets/entity_table/entity_table_column_picker_test.dart
git commit -m "fix: entity table column picker now updates live

The shared picker received an EntityTableViewConfig captured with
ref.read at open time, so pin, add, remove, and reorder changed the
table behind the sheet but never the sheet itself. It now takes the
config provider and watches it, matching the dive table's picker.

Affects buddies, courses, dive sites, certifications, trips, dive
centers, and equipment."
```

---

### Task 2: Localize the picker's static labels

Reuses ARB keys that already exist in all 12 locales, so no ARB file changes and no `flutter gen-l10n` run. English output is unchanged, which is why Task 1's assertions on `'Columns'`, `'Done'`, `'VISIBLE COLUMNS'`, and `'AVAILABLE FIELDS'` keep passing.

**Files:**
- Modify: `lib/shared/widgets/entity_table/entity_table_column_picker.dart`
- Test: `test/shared/widgets/entity_table/entity_table_column_picker_test.dart`

**Interfaces:**
- Consumes: `context.l10n` from `package:submersion/l10n/l10n_extension.dart`, providing the existing getters `columnConfig_columns` ("Columns" / "Spalten"), `columnConfig_done` ("Done" / "Fertig"), `columnConfig_visibleColumns` ("Visible Columns" / "Sichtbare Spalten"), `columnConfig_availableFields` ("Available Fields" / "Verfügbare Felder"). The section labels are uppercased at the call site, as `TableColumnPicker` does.
- Consumes: `_buildPickerLauncher({..., Locale? locale})` from Task 1.
- Produces: nothing new.

- [ ] **Step 1: Write the failing localization test**

Add to `test/shared/widgets/entity_table/entity_table_column_picker_test.dart`, inside the existing group:

```dart
testWidgets('sheet labels follow the app locale', (tester) async {
  await tester.pumpWidget(
    _buildPickerLauncher(locale: const Locale('de')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open Picker'));
  await tester.pumpAndSettle();

  expect(find.text('Spalten'), findsOneWidget);
  expect(find.text('Fertig'), findsOneWidget);
  expect(find.text('SICHTBARE SPALTEN'), findsOneWidget);
  expect(find.text('VERFÜGBARE FELDER'), findsOneWidget);
});
```

`'Open Picker'` is the launcher button's own literal and is not localized, so it stays English under any locale.

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/shared/widgets/entity_table/entity_table_column_picker_test.dart --plain-name "sheet labels follow the app locale"`

Expected: FAIL — the sheet still renders the hardcoded English `'Columns'`, so `find.text('Spalten')` finds nothing.

- [ ] **Step 3: Swap the four literals for l10n lookups**

In `lib/shared/widgets/entity_table/entity_table_column_picker.dart`, add this import in alphabetical position (after `core/providers/provider.dart`, before `shared/constants/entity_field.dart`):

```dart
import 'package:submersion/l10n/l10n_extension.dart';
```

Then make exactly four replacements in `build`.

Header title:

```dart
                  Expanded(
                    child: Text(
                      context.l10n.columnConfig_columns,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
```

Done button (note `const` must be dropped from the `Text`):

```dart
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.columnConfig_done),
                  ),
```

Visible columns section label:

```dart
                    child: Text(
                      context.l10n.columnConfig_visibleColumns.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
```

Available fields section label:

```dart
                    child: Text(
                      context.l10n.columnConfig_availableFields.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
```

Leave the `Pin`, `Unpin`, `Remove`, and `Add` tooltips hardcoded. They have no ARB keys and are hardcoded in the dive picker too; localizing only this one would create a new inconsistency. They are out of scope per the spec.

- [ ] **Step 4: Run the full picker test file and confirm it passes**

Run: `flutter test test/shared/widgets/entity_table/entity_table_column_picker_test.dart`

Expected: PASS, 13 tests. The English assertions still hold because the English ARB values are identical to the literals that were removed.

- [ ] **Step 5: Analyze and format**

Run: `flutter analyze`

Expected: "No issues found!". A leftover `const` on the Done `Text` would surface here as a compile error; a newly-unneeded `const` elsewhere would surface as a `prefer_const_constructors` info, which CI treats as fatal.

Run: `dart format .`

- [ ] **Step 6: Commit**

```bash
git add lib/shared/widgets/entity_table/entity_table_column_picker.dart test/shared/widgets/entity_table/entity_table_column_picker_test.dart
git commit -m "fix: localize entity column picker sheet labels

Reuses the existing columnConfig_* keys already translated in all 12
locales, so no ARB changes. Brings the shared picker in line with the
dive table's picker, which was already localized."
```

---

### Task 3: Whole-project verification

**Files:** none modified. This task is a gate, not a change.

**Interfaces:**
- Consumes: the working tree produced by Tasks 1 and 2.
- Produces: evidence that the branch is CI-clean, and confirmation the reported bug is actually gone in the running app.

- [ ] **Step 1: Confirm formatting is clean**

Run: `dart format --output=none --set-exit-if-changed .`

Expected: exit 0, "0 changed".

- [ ] **Step 2: Confirm the whole project analyzes clean**

Run: `flutter analyze`

Expected: "No issues found!". No path argument. Do not pipe this into anything.

- [ ] **Step 3: Run the full test suite in the background**

Run, with `run_in_background: true` and a 600000 ms timeout:

```bash
flutter test > /tmp/full_test_run.log 2>&1; echo "EXIT:$?" >> /tmp/full_test_run.log
```

When it completes, read the tail of `/tmp/full_test_run.log` and confirm BOTH that it contains "All tests passed" and that the last line is `EXIT:0`. A background job reports exit 0 even when the suite failed, so the log is the source of truth, not the job status.

- [ ] **Step 4: Verify the fix in the running app**

Run: `flutter run -d macos`

Then, in the app:
1. Go to Buddies, switch the view mode to Table via the overflow menu.
2. Tap the column settings icon in the app bar.
3. Tap the pin on an unpinned column. The icon must fill immediately and that row's remove button must disappear.
4. Tap remove on an unpinned column. It must leave VISIBLE COLUMNS and appear under AVAILABLE FIELDS in the same frame.
5. Tap add on a field under AVAILABLE FIELDS. It must move up into VISIBLE COLUMNS.
6. Drag a column by its handle to a new position. It must stay where it was dropped rather than snapping back.
7. Repeat step 2 through 6 on one more entity table (Equipment) to confirm the shared fix carries.

Expected: every action updates the sheet immediately, matching the dive table's picker.

- [ ] **Step 5: Report**

Summarize for the user: what changed, the test counts, analyze and format results, and what was confirmed manually on macOS. Do not push or open a PR unless asked.

---

## Coverage map

| Spec section | Task |
| ------------ | ---- |
| Root cause: `ref.read` snapshot to `ref.watch` subscription | Task 1, steps 4 |
| Symptom: pin does not update | Task 1, steps 2 (test 1, 2), 4 |
| Symptom: remove does not update | Task 1, steps 2 (test 3), 4 |
| Symptom: add does not update | Task 1, steps 2 (test 4), 4 |
| Symptom: reorder snaps back | Task 1, steps 2 (test 5), 4 |
| API change to `showEntityTableColumnPicker` | Task 1, step 4 |
| All 7 call sites | Task 1, steps 6, 7 |
| Reuse existing `columnConfig_*` keys | Task 2, step 3 |
| `Column settings` / `Pin` / `Unpin` / `Remove` / `Add` stay unlocalized | Task 2, step 3 (explicit instruction) |
| Tests assert rendered state, not callbacks | Task 1, step 2 |
| Existing structural tests carried over | Task 1, step 2 (keep list) |
| Verification: analyze, format, test, manual macOS | Task 3 |
