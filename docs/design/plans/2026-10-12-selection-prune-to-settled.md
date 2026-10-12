# Selection Prune To Settled Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the "prune only once the rows have settled" rule from 18 hand-written call sites into `SelectionController.pruneToSettled`, and make the selection bar inert while rows are loading.

**Architecture:** `SelectionController` gains a `rowsSettled` notifier and `pruneToSettled<T>(AsyncValue<T>, idsOf)`, which records settledness and prunes to ids derived from the value it checked. `selectAll` refuses while unsettled; `SelectionAppBar` listens to `rowsSettled` and disables every control that acts on rows. Every `AsyncValue`-backed selectable list migrates to the helper, and an architecture guard keeps bare `pruneTo` out of `lib/`.

**Tech Stack:** Flutter, Riverpod 3.4 (`AsyncValue`), flutter_test.

**Spec:** `docs/design/specs/2026-10-12-selection-prune-to-settled-design.md`

## Global Constraints

- No em-dashes or en-dashes as punctuation in code, comments or docs.
- No emojis. No mention of any AI tool in commits or code.
- `dart format .` before every commit; `flutter analyze` clean.
- Paths in tests built platform-agnostically (the guard normalizes `\` to `/`).
- Tests that replace process-wide state restore it (`addTearDown`).
- `pruneTo(List<String>)` stays public; only `media_library_view.dart` may call it outside the controller.

## Review Focus

1. **Exit and re-enter while rows are loading.** `exit()` must not reset `rowsSettled`; re-entering selection during a spinner must still find select-all disabled. Pinned in Task 1.
2. **Rows settle again after a loading window.** The bar must re-enable without the diver touching anything. Pinned in Task 2.
3. **A surface that never reports rows** (media library, species tag picker, photo picker) keeps a live select-all. Pinned in Task 1 (fresh controller is settled).
4. **Error with no value while an implicit selection is active** prunes to nothing and therefore ends the implicit mode, the same as `pruneTo([])`. Pinned in Task 1.
5. **Dive list select-by-date-range during loading** routes through `selectAll` and must do nothing. Covered by Task 1's `selectAll` guard; Task 2 pins the `alwaysEnabled` action as disabled.

---

### Task 1: `SelectionController.pruneToSettled` and `rowsSettled`

**Files:**
- Modify: `lib/shared/selection/selection_controller.dart`
- Test: `test/shared/selection/selection_controller_test.dart`

**Interfaces:**
- Produces:
  - `ValueListenable<bool> SelectionController.rowsSettled` (initially `true`)
  - `void SelectionController.pruneToSettled<T>(AsyncValue<T> rows, Iterable<String> Function(T rows) idsOf)`
  - `selectAll` is a no-op while `rowsSettled.value` is false.

- [ ] **Step 1: Write the failing tests**

Add imports at the top of `test/shared/selection/selection_controller_test.dart`:

```dart
import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
```

Add a helper below `main`'s opening (file-private, after the imports, before `void main()`):

```dart
/// A real reload that holds its previous value, built the way the app makes
/// one: a provider whose dependency moves. `copyWithPrevious` is internal to
/// Riverpod, so the state cannot be constructed directly.
Future<AsyncValue<List<String>>> _reloadingFrom(List<String> previous) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final trigger = StateProvider<int>((ref) => 0);
  var next = Completer<List<String>>();
  final rows = FutureProvider<List<String>>((ref) {
    ref.watch(trigger);
    return next.future;
  });
  container.listen(rows, (_, _) {});
  next.complete(previous);
  await container.read(rows.future);
  next = Completer<List<String>>();
  container.read(trigger.notifier).state++;
  final reloading = container.read(rows);
  assert(reloading.isLoading && reloading.hasValue);
  return reloading;
}
```

Add a group at the end of `main()`:

```dart
  group('SelectionController.pruneToSettled', () {
    late SelectionController controller;
    setUp(() => controller = SelectionController()..selectAll(['a', 'b']));
    tearDown(() => controller.dispose());

    List<String> ids(List<String> rows) => rows;

    test('is settled before any rows are reported', () {
      expect(SelectionController().rowsSettled.value, isTrue);
    });

    test('a first load keeps the checks and reports unsettled', () {
      controller.pruneToSettled(const AsyncLoading<List<String>>(), ids);
      expect(controller.value.checkedIds, {'a', 'b'});
      expect(controller.rowsSettled.value, isFalse);
    });

    test('data prunes to the ids derived from it', () {
      controller.pruneToSettled(const AsyncData(['a', 'c']), ids);
      expect(controller.value.checkedIds, {'a'});
      expect(controller.rowsSettled.value, isTrue);
    });

    test('idsOf receives the settled value, so derived filters apply', () {
      controller.pruneToSettled(
        const AsyncData(['a', 'b']),
        (rows) => rows.where((id) => id != 'b'),
      );
      expect(controller.value.checkedIds, {'a'});
    });

    test('a reload holding its previous value prunes to that value', () async {
      final reloading = await _reloadingFrom(['b']);
      controller.pruneToSettled(reloading, ids);
      expect(controller.value.checkedIds, {'b'});
      expect(controller.rowsSettled.value, isTrue);
    });

    test('an error with no value prunes to nothing', () {
      controller.pruneToSettled(
        AsyncError<List<String>>(StateError('boom'), StackTrace.empty),
        ids,
      );
      expect(controller.value.checkedIds, isEmpty);
      expect(controller.rowsSettled.value, isTrue);
    });

    test('an error with no value ends an implicit selection', () {
      final implicit = SelectionController()..enterImplicit('a');
      addTearDown(implicit.dispose);
      implicit.pruneToSettled(
        AsyncError<List<String>>(StateError('boom'), StackTrace.empty),
        ids,
      );
      expect(implicit.value.isActive, isFalse);
    });

    test('settling again reports settled', () {
      controller.pruneToSettled(const AsyncLoading<List<String>>(), ids);
      controller.pruneToSettled(const AsyncData(['a', 'b']), ids);
      expect(controller.rowsSettled.value, isTrue);
      expect(controller.value.checkedIds, {'a', 'b'});
    });

    test('select all does nothing while rows are unsettled', () {
      controller.pruneToSettled(const AsyncLoading<List<String>>(), ids);
      controller.selectAll(const []);
      expect(controller.value.checkedIds, {'a', 'b'});
    });

    test('exit keeps the rows unsettled, so re-entry cannot select all', () {
      controller.pruneToSettled(const AsyncLoading<List<String>>(), ids);
      controller
        ..exit()
        ..enterExplicit()
        ..selectAll(const ['x']);
      expect(controller.rowsSettled.value, isFalse);
      expect(controller.value.checkedIds, isEmpty);
    });

    test('notifies rowsSettled listeners only on a change', () {
      var calls = 0;
      controller.rowsSettled.addListener(() => calls++);
      controller.pruneToSettled(const AsyncData(['a', 'b']), ids);
      controller.pruneToSettled(const AsyncLoading<List<String>>(), ids);
      controller.pruneToSettled(const AsyncLoading<List<String>>(), ids);
      expect(calls, 1);
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/shared/selection/selection_controller_test.dart`
Expected: compile failure, `rowsSettled` / `pruneToSettled` not defined.

- [ ] **Step 3: Implement**

In `lib/shared/selection/selection_controller.dart`, add the import (it
re-exports Riverpod and the `hasSettled` extension):

```dart
import 'package:submersion/core/providers/provider.dart';
```

Inside `SelectionController`, after the constructor:

```dart
  final ValueNotifier<bool> _rowsSettled = ValueNotifier(true);

  /// Whether the rows last reported through [pruneToSettled] have loaded or
  /// failed.
  ///
  /// True until a surface reports otherwise, so a surface that never calls
  /// [pruneToSettled] (the media library prunes a plain list) is unaffected.
  /// Kept apart from [SelectionState] because it describes the rows, not the
  /// selection: [exit] resets the state, and must not forget that the rows
  /// are still loading.
  ValueListenable<bool> get rowsSettled => _rowsSettled;
```

Guard `selectAll` (first line of its body), and extend its doc comment:

```dart
  /// Does nothing while [rowsSettled] is false: the surface passes empty ids
  /// until its rows load, and checking "all" of nothing would replace the
  /// checks the diver kept through a filter change.
  void selectAll(List<String> selectableIds) {
    if (!_rowsSettled.value) return;
```

Add after `pruneTo`:

```dart
  /// Record whether [rows] have settled and, once they have, prune to the
  /// ids [idsOf] derives from them.
  ///
  /// The one way an async list prunes, so the settled check and the ids it
  /// prunes to come from the same value and cannot disagree. A first load
  /// has no rows yet (a new query's id set starts that way), and pruning to
  /// that empty frame would drop every check; it leaves the selection alone.
  /// A reload holding its previous value prunes to that value, and an error
  /// with no value prunes to nothing.
  ///
  /// [idsOf] needs to repeat only the steps that filter rows: pruning works
  /// on membership, so sort order is irrelevant.
  void pruneToSettled<T>(
    AsyncValue<T> rows,
    Iterable<String> Function(T rows) idsOf,
  ) {
    _rowsSettled.value = rows.hasSettled;
    if (!rows.hasSettled) return;
    final value = rows.value;
    pruneTo(value == null ? const [] : idsOf(value).toList());
  }
```

Add a `dispose` override at the end of the class:

```dart
  @override
  void dispose() {
    _rowsSettled.dispose();
    super.dispose();
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/shared/selection/`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format lib/shared/selection test/shared/selection
git add lib/shared/selection/selection_controller.dart test/shared/selection/selection_controller_test.dart
git commit -m "feat(selection): add SelectionController.pruneToSettled and rowsSettled"
```

---

### Task 2: `SelectionAppBar` and `SelectableListScope` during loading

**Files:**
- Modify: `lib/shared/selection/selection_app_bar.dart`
- Test: `test/shared/selection/selection_app_bar_test.dart`
- Test: `test/shared/selection/selectable_list_scope_test.dart`

**Interfaces:**
- Consumes: `controller.rowsSettled`, `controller.pruneToSettled` (Task 1).
- Produces: no new API. While `rowsSettled` is false, the bar's select-all, inline and overflow actions and Delete are disabled; Close and Deselect-all stay live.

- [ ] **Step 1: Write the failing tests**

Add to `test/shared/selection/selection_app_bar_test.dart` imports:

```dart
import 'package:submersion/core/providers/provider.dart';
```

Add a group at the end of `main()`:

```dart
  group('SelectionAppBar while rows are loading', () {
    void startLoading() => controller.pruneToSettled(
      const AsyncLoading<List<String>>(),
      (rows) => rows,
    );

    BulkAction extra({bool alwaysEnabled = false, VoidCallback? onRun}) =>
        BulkAction(
          id: alwaysEnabled ? 'by_date' : 'export',
          icon: Icons.ios_share,
          label: alwaysEnabled ? 'By date' : 'Export',
          alwaysEnabled: alwaysEnabled,
          onInvoke: () {
            onRun?.call();
            return BulkActionOutcome.completed;
          },
        );

    testWidgets('select all, extras and delete are disabled', (tester) async {
      controller.selectAll(const ['a']);
      startLoading();
      await tester.pumpWidget(
        host(actions: [extra(), extra(alwaysEnabled: true)]),
      );
      await tester.pumpAndSettle();

      IconButton button(String key) =>
          tester.widget<IconButton>(find.byKey(ValueKey(key)));
      expect(button('selection_select_all').onPressed, isNull);
      expect(button('selection_action_export').onPressed, isNull);
      expect(button('selection_action_by_date').onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('selection_overflow')));
      await tester.pumpAndSettle();
      final delete = tester.widget<PopupMenuItem<String>>(
        find.byKey(const ValueKey('selection_delete')),
      );
      expect(delete.enabled, isFalse);
    });

    testWidgets('close and deselect all stay live', (tester) async {
      controller.selectAll(const ['a']);
      startLoading();
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('selection_deselect_all')));
      await tester.pumpAndSettle();
      expect(controller.value.checkedIds, isEmpty);
      await tester.tap(find.byKey(const ValueKey('selection_exit')));
      await tester.pumpAndSettle();
      expect(controller.value.isActive, isFalse);
    });

    testWidgets('controls come back once the rows settle', (tester) async {
      controller.selectAll(const ['a']);
      startLoading();
      await tester.pumpWidget(host(actions: [extra()]));
      await tester.pumpAndSettle();

      controller.pruneToSettled(const AsyncData(['a', 'b']), (rows) => rows);
      await tester.pumpAndSettle();
      final selectAll = tester.widget<IconButton>(
        find.byKey(const ValueKey('selection_select_all')),
      );
      expect(selectAll.onPressed, isNotNull);
      final export = tester.widget<IconButton>(
        find.byKey(const ValueKey('selection_action_export')),
      );
      expect(export.onPressed, isNotNull);
    });

    testWidgets('a control painted before the rows unsettled runs nothing', (
      tester,
    ) async {
      var ran = 0;
      controller.selectAll(const ['a']);
      await tester.pumpWidget(host(actions: [extra(onRun: () => ran++)]));
      await tester.pumpAndSettle();
      final export = tester.widget<IconButton>(
        find.byKey(const ValueKey('selection_action_export')),
      );

      // The flag flips in a post-frame callback; a tap can land before the
      // bar repaints, so the handler from the settled frame must check too.
      startLoading();
      export.onPressed!();
      await tester.pumpAndSettle();
      expect(ran, 0);
      expect(controller.value.isActive, isTrue);
    });
  });
```

Add to `test/shared/selection/selectable_list_scope_test.dart` imports:

```dart
import 'package:submersion/core/providers/provider.dart';
```

and inside the `SelectableListScope` group:

```dart
    testWidgets('Ctrl-A keeps the checks while rows are loading', (
      tester,
    ) async {
      controller
        ..selectAll(const ['a'])
        ..pruneToSettled(const AsyncLoading<List<String>>(), (rows) => rows);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(controller.value.checkedIds, {'a'});
    });
```

- [ ] **Step 2: Run to verify the bar tests fail**

Run: `flutter test test/shared/selection/selection_app_bar_test.dart test/shared/selection/selectable_list_scope_test.dart`
Expected: the "while rows are loading" tests FAIL (controls enabled, handler ran). The scope test already PASSES via Task 1's guard; it pins the behaviour.

- [ ] **Step 3: Implement in `lib/shared/selection/selection_app_bar.dart`**

Add to the class doc comment, after the paragraph about leaving selection mode:

```dart
/// While the rows are loading ([SelectionController.rowsSettled] is false),
/// nothing that acts on rows can run: select-all, every extra (including
/// [BulkAction.alwaysEnabled] ones) and delete are disabled, and each
/// dispatch re-checks at tap time because the flag flips a frame before the
/// bar repaints. Close and deselect-all stay live; they only discard the
/// diver's own checks.
```

Replace the `ValueListenableBuilder` in `build` with a `ListenableBuilder` over both notifiers:

```dart
    return ListenableBuilder(
      listenable: Listenable.merge([controller, controller.rowsSettled]),
      builder: (context, _) {
        final state = controller.value;
        final settled = controller.rowsSettled.value;
        final count = state.count;
        // ... title and leading unchanged ...
        final trailing = _buildControls(
          context,
          count,
          state.checkedIds,
          settled: settled,
        );
```

Guard both dispatch paths:

```dart
  Future<void> _runAndMaybeExit(
    FutureOr<BulkActionOutcome> Function() handler, {
    bool exitsOnComplete = true,
  }) async {
    // A control painted while the rows were settled can still be tapped in
    // the frame before the bar repaints disabled.
    if (!controller.rowsSettled.value) return;
    final outcome = await handler();
```

In `_buildControls`, add the `required bool settled` named parameter and gate each control:

```dart
  List<Widget> _buildControls(
    BuildContext context,
    int count,
    Set<String> checkedIds, {
    required bool settled,
  }) {
    // ... assert unchanged ...
    final allChecked =
        count >= selectableIds.length && selectableIds.isNotEmpty;
    bool enabledFor(BulkAction action) =>
        settled && action.isEnabledForSelection(count, checkedIds);
```

- select-all: `onPressed: allChecked || !settled ? null : () => controller.selectAll(selectableIds),`
- inline extras: `onPressed: enabledFor(action) ? () => _start(_invoke(action), action.id) : null,`
- overflow extras: `enabled: enabledFor(action),`
- delete: `_buildDeleteItem(context, count, settled: settled)`, and in `_buildDeleteItem` add `{required bool settled}` with `final enabled = settled && count > 0;`

- [ ] **Step 4: Run to verify they pass**

Run: `flutter test test/shared/selection/`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
dart format lib/shared/selection test/shared/selection
git add lib/shared/selection/selection_app_bar.dart test/shared/selection/selection_app_bar_test.dart test/shared/selection/selectable_list_scope_test.dart
git commit -m "feat(selection): keep the selection bar inert while rows load"
```

---

### Task 3: Migrate the id-set lists

**Files (list mode and table mode in each):**
- Modify: `lib/features/buddies/presentation/widgets/buddy_list_content.dart` (~536, ~662)
- Modify: `lib/features/certifications/presentation/widgets/certification_list_content.dart` (~211, ~429)
- Modify: `lib/features/courses/presentation/widgets/course_list_content.dart` (~151, ~387)
- Modify: `lib/features/dive_centers/presentation/widgets/dive_center_list_content.dart` (~226, ~464)
- Modify: `lib/features/dive_sites/presentation/widgets/site_list_content.dart` (~822, ~1002)
- Modify: `lib/features/equipment/presentation/widgets/equipment_list_content.dart` (~381, ~777)
- Modify: `lib/features/trips/presentation/widgets/trip_list_content.dart` (~235, ~494)
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart` (~1145, ~1696)
- Test: `test/features/buddies/presentation/widgets/buddy_list_content_test.dart`
- Test: `test/features/trips/presentation/widgets/trip_list_content_test.dart`

**Interfaces:**
- Consumes: `SelectionController.pruneToSettled` (Task 1), bar behaviour (Task 2).

- [ ] **Step 1: Write the failing Buddies regression**

In `buddy_list_content_test.dart`, add near the other file-private providers:

```dart
/// Moved to make the buddies source reload while holding its previous
/// value, the way a dependency change does in the app.
final _buddyReloadProvider = StateProvider<int>((ref) => 0);
```

Add a group in `main()`:

```dart
  group('a reload holding its previous value', () {
    for (final mode in [ListViewMode.detailed, ListViewMode.table]) {
      testWidgets('keeps the checks (${mode.name})', (tester) async {
        final controller = SelectionController();
        addTearDown(controller.dispose);
        final all = [
          _makeBuddy(id: 'b1', name: 'Alice'),
          _makeBuddy(id: 'b2', name: 'Bob'),
        ];
        final overrides = await _buildPhoneOverrides(
          buddies: all,
          viewMode: mode,
        );
        await tester.pumpWidget(
          testApp(
            overrides: [
              ...overrides,
              allBuddiesWithDiveCountProvider.overrideWith((ref) {
                ref.watch(_buddyReloadProvider);
                return Future.delayed(
                  const Duration(milliseconds: 50),
                  () => all,
                );
              }),
            ],
            locale: const Locale('en'),
            child: BuddyListContent(
              showAppBar: true,
              selectionController: controller,
            ),
          ),
        );
        await tester.pumpAndSettle();
        controller.enterExplicit();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('selection_select_all')));
        await tester.pumpAndSettle();
        expect(find.text('2 selected'), findsOneWidget);

        ProviderScope.containerOf(
          tester.element(find.byType(BuddyListContent)),
        ).read(_buddyReloadProvider.notifier).state++;
        // Two frames inside the reload: one builds, the next runs the prune.
        await tester.pump();
        await tester.pump();
        expect(find.text('2 selected'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('2 selected'), findsOneWidget);
      });
    }
  });
```

If `_buildPhoneOverrides` already contains an `allBuddiesWithDiveCountProvider` override, drop it from the spread with `.where` or build the list inline; a duplicate override throws. Check `BuddyListContent` accepts `selectionController` (as `TripListContent` does); if the parameter name differs, use the existing one.

- [ ] **Step 2: Run to verify it fails**

Run: `flutter test test/features/buddies/presentation/widgets/buddy_list_content_test.dart --plain-name "a reload holding its previous value"`
Expected: FAIL, "0 selected" or the bar gone (the `valueOrNull` read prunes to nothing).

- [ ] **Step 3: Add the loading-frame assertion to Trips**

In `trip_list_content_test.dart`, inside `group('a new filter', ...)`'s loop, add a second test:

```dart
      testWidgets('disables bulk actions while the new filter loads '
          '(${mode.name})', (tester) async {
        // Same setup as 'keeps the checks that stay on screen' above,
        // through the select-all tap and the '2 selected' expectation.
        // ... (copy the setup verbatim) ...

        ProviderScope.containerOf(
          tester.element(find.byType(TripListContent)),
        ).read(tripFilterProvider.notifier).state = const TripFilterState(
          equipmentId: 'e1',
        );
        await tester.pump(); // builds the loading frame, prune reports it
        await tester.pump(); // the bar repaints disabled
        final selectAll = tester.widget<IconButton>(
          find.byKey(const ValueKey('selection_select_all')),
        );
        expect(selectAll.onPressed, isNull);
        await tester.tap(find.byKey(const ValueKey('selection_overflow')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 10));
        final delete = tester.widget<PopupMenuItem<String>>(
          find.byKey(const ValueKey('selection_delete')),
        );
        expect(delete.enabled, isFalse);
        await tester.pumpAndSettle();
      });
```

Factor the shared setup into a local `Future<SelectionController> pumpSelected(WidgetTester tester, ListViewMode mode)` inside the group rather than duplicating it, and use it from both tests.

Run: `flutter test test/features/trips/presentation/widgets/trip_list_content_test.dart --plain-name "disables bulk actions"`
Expected: FAIL (the prune is still hand-guarded, so `rowsSettled` never flips).

- [ ] **Step 4: Migrate each call site**

Every prune becomes `if (mounted) _selection.pruneToSettled(<rowsAsync>, <idsOf>);` inside the existing post-frame callback, with the old `hasSettled` check removed:

| File, mode | Replacement |
| --- | --- |
| buddies list, table | `_selection.pruneToSettled(buddiesAsync, (rows) => rows.map((b) => b.buddy.id))` |
| certifications list, table | `_selection.pruneToSettled(certificationsAsync, (rows) => rows.map((c) => c.id))` |
| courses list, table | `_selection.pruneToSettled(coursesAsync, (rows) => rows.map((c) => c.id))` |
| dive centers list, table | `_selection.pruneToSettled(centersAsync, (rows) => rows.map((c) => c.id))` |
| sites list, table | `_selection.pruneToSettled(sitesAsync, (rows) => rows.map((s) => s.site.id))` |
| equipment list, table | `_selection.pruneToSettled(equipmentAsync, (rows) => rows.map((e) => e.id))` |
| trips list, table | `_selection.pruneToSettled(tripsAsync, (rows) => rows.map((t) => t.trip.id))` |
| dives list | `_selection.pruneToSettled(paginatedAsync, (page) => page.dives.map((d) => d.id))` |
| dives table | `_selection.pruneToSettled(tableAsync, (rows) => rows.map((d) => d.id))` |

Then, per file:
- Keep the in-build `visibleIds` wherever it still feeds `selectableIds`, `SelectableListScope` or a bulk action. Where it only fed the prune, delete it (analyze flags an unused local).
- Buddies: change both `buddiesAsync.valueOrNull` reads at the prune sites to `buddiesAsync.value`, and drop the `async_value_extensions.dart` import if nothing else uses it.
- Courses: the list-mode comment "List mode filters by status and sorts..." is stale (`_visibleCourses` only sorts); reword it to say the list sorts and the prune follows membership.
- Update each prune comment to name `pruneToSettled` (for example: "Drop checked trips that fell out of the filtered list once its rows settle, so a bulk action can never reach a trip that is not on screen.").

- [ ] **Step 5: Run the list tests**

Run:
```bash
flutter test test/features/buddies/presentation/widgets/buddy_list_content_test.dart test/features/certifications/presentation/widgets test/features/courses/presentation/widgets test/features/dive_centers/presentation/widgets test/features/dive_sites/presentation/widgets/site_list_content_test.dart test/features/equipment/presentation/widgets/equipment_list_content_test.dart test/features/trips/presentation/widgets/trip_list_content_test.dart test/features/dive_log/presentation/widgets/dive_list_content_test.dart
```
Expected: all pass, including every existing "a new filter keeps the checks" test.

- [ ] **Step 6: Commit**

```bash
dart format lib/features test/features
git add <the eight lib files> test/features/buddies/presentation/widgets/buddy_list_content_test.dart test/features/trips/presentation/widgets/trip_list_content_test.dart
git commit -m "feat(selection): prune the id-set lists through pruneToSettled"
```

---

### Task 4: Migrate the other async lists

**Files:**
- Modify: `lib/features/marine_life/presentation/pages/species_manage_page.dart` (~79)
- Modify: `lib/features/tags/presentation/pages/tag_manage_page.dart` (~64)
- Modify: `lib/features/cylinder_configs/presentation/pages/cylinder_config_list_page.dart` (~55)
- Modify: `lib/features/dive_computer/presentation/pages/device_list_page.dart` (~57)
- Modify: `lib/features/equipment/presentation/pages/service_kind_list_page.dart` (~85)
- Modify: `lib/features/media_store/presentation/pages/transfers_page.dart` (~79)
- Modify: `lib/features/media/presentation/widgets/dive_media_section.dart` (~315)
- Modify: `lib/features/media/presentation/widgets/site_media_section.dart` (~214)
- Test: `test/features/tags/presentation/pages/tag_manage_page_test.dart` (existing file; create the group if absent)

**Interfaces:**
- Consumes: `SelectionController.pruneToSettled` (Task 1).

- [ ] **Step 1: Write the failing Tags regression**

Tags reads `statsAsync.valueOrNull`, so a dependency-driven reload of `tagStatisticsProvider` wipes the checks. Add a test in the tag manage page test that mirrors Task 3's Buddies regression: override `tagStatisticsProvider` with a body that `ref.watch`es a file-private `StateProvider<int>` and returns two tag statistics after `Future.delayed(50 ms)`; enter selection through the page's controller (or the "Select items" entry the page offers), select all, bump the trigger, `pump()` twice, and expect `2 selected`. Read the existing test file first and reuse its tag-statistic builders and overrides.

Run: `flutter test test/features/tags/presentation/pages/tag_manage_page_test.dart --plain-name "reload"`
Expected: FAIL.

- [ ] **Step 2: Migrate each call site**

| File | Replacement |
| --- | --- |
| species | `_selection.pruneToSettled(speciesAsync, (rows) => _visibleSpecies(rows).where(_isSelectable).map((s) => s.id))` |
| tags | `_selection.pruneToSettled(statsAsync, (rows) => _visibleStats(rows).map((s) => s.tag.id))` |
| cylinder configs | `_selection.pruneToSettled(configsAsync, (rows) => rows.map((c) => c.id))` |
| devices | `_selection.pruneToSettled(computersAsync, (rows) => rows.map((c) => c.id))` |
| service kinds | `_selection.pruneToSettled(kindsAsync, (rows) => rows.where((k) => !k.isBuiltIn).map((k) => k.id))` |
| transfers | `_selection.pruneToSettled(entries, (rows) => rows.map((e) => e.id.toString()))` |
| dive media | `_selection.pruneToSettled(mediaAsync, (rows) => rows.map((m) => m.id))` |
| site media | `_selection.pruneToSettled(mediaAsync, (rows) => rows.map((m) => m.id))` |

Species already guards with `hasSettled`; remove it. Tags and dive media switch the in-build `visibleIds` from `valueOrNull` to `.value`; dive media's `_scheduleEnrichmentBackfill(mediaAsync.valueOrNull)` stays as it is. Remove a now-unused `visibleIds`/`selectableIds` local or extension import only if analyze flags it.

- [ ] **Step 3: Run the tests**

```bash
flutter test test/features/marine_life test/features/tags test/features/cylinder_configs test/features/dive_computer/presentation/pages/device_list_page_test.dart test/features/equipment/presentation/pages test/features/media_store test/features/media/presentation/widgets
```
Expected: all pass, the Tags regression included. (If a listed path has no test file, drop it from the command.)

- [ ] **Step 4: Commit**

```bash
dart format lib/features test/features
git add <the eight lib files> <the tags test>
git commit -m "feat(selection): prune the remaining async lists through pruneToSettled"
```

---

### Task 5: Architecture guard

**Files:**
- Create: `test/architecture/selection_prune_settled_test.dart`

- [ ] **Step 1: Write the guard**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An async list prunes its selection through `pruneToSettled` and nowhere
/// else (#2581).
///
/// A bare `pruneTo` on an async list either prunes to the empty frame of a
/// first load, dropping every check, or needs a hand-written `hasSettled`
/// guard whose ids must come from the same getter it checked. That rule was
/// copied into 18 call sites and drifted in three of them. The helper owns
/// it now; this keeps new lists on it.
void main() {
  const controller = 'lib/shared/selection/selection_controller.dart';

  /// Files permitted to call `pruneTo`, with the reason.
  const allowed = <String, String>{
    'lib/features/media/presentation/pages/media_library_view.dart':
        'its rows are a paged list, not an AsyncValue',
  };

  final bareCall = RegExp(r'\.pruneTo\(');
  final anyPrune = RegExp(r'\.pruneTo(Settled)?\(');

  Iterable<(String, List<String>)> libFiles() sync* {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path == controller) continue;
      yield (path, entity.readAsLinesSync());
    }
  }

  bool isComment(String line) => line.trimLeft().startsWith('//');

  test('only allowlisted files call pruneTo', () {
    final offenders = <String>[];
    for (final (path, lines) in libFiles()) {
      if (allowed.containsKey(path)) continue;
      for (var i = 0; i < lines.length; i++) {
        if (isComment(lines[i])) continue;
        if (bareCall.hasMatch(lines[i])) offenders.add('$path:${i + 1}');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'prune an async list with _selection.pruneToSettled(rowsAsync, '
          '(rows) => ...ids), so a first load keeps the checks and the ids '
          'come from the value the settled check read',
    );
  });

  test('no hand-written hasSettled guard sits beside a prune', () {
    final offenders = <String>[];
    for (final (path, lines) in libFiles()) {
      for (var i = 0; i < lines.length; i++) {
        if (isComment(lines[i]) || !anyPrune.hasMatch(lines[i])) continue;
        final from = i < 3 ? 0 : i - 3;
        for (var j = from; j <= i; j++) {
          if (!isComment(lines[j]) && lines[j].contains('hasSettled')) {
            offenders.add('$path:${j + 1}');
          }
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'pruneToSettled checks hasSettled itself; drop the caller guard',
    );
  });

  test('every allowlisted file exists and still calls pruneTo', () {
    // A stale exemption is how a guard quietly stops guarding.
    for (final entry in allowed.entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: '${entry.key} is missing');
      expect(
        bareCall.hasMatch(file.readAsStringSync()),
        isTrue,
        reason:
            '${entry.key} is allowlisted as "${entry.value}" but no longer '
            'calls pruneTo; remove it from the allowlist',
      );
    }
  });
}
```

- [ ] **Step 2: Prove the guard can fail**

Temporarily change one migrated site (for example `trip_list_content.dart` list mode) back to `if (mounted && tripsAsync.hasSettled) _selection.pruneTo(visibleIds);` after copying the file to the scratchpad, run `flutter test test/architecture/selection_prune_settled_test.dart`, and expect the first two tests to FAIL naming that line. Restore the file from the scratchpad copy (not `git checkout`), then confirm `git diff --stat` shows no change to it.

- [ ] **Step 3: Run the guard and the whole architecture folder**

Run: `flutter test test/architecture/`
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
dart format test/architecture
git add test/architecture/selection_prune_settled_test.dart
git commit -m "test(selection): guard against a bare pruneTo on an async list"
```

---

### Task 6: Final verification

- [ ] `grep -rn "hasSettled" lib` shows only `async_value_extensions.dart`, `selection_controller.dart`, and the non-selection uses (nav track, site terrain pane, spatial site page).
- [ ] `dart format .` leaves no diff.
- [ ] `flutter analyze` reports no issues.
- [ ] `flutter test test/shared/ test/architecture/` passes (adoption guards live in `test/shared/`).
- [ ] Re-run the Task 3 and Task 4 test commands; all pass.
