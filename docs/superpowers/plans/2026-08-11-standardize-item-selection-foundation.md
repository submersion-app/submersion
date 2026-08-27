# Standardized Selection: Foundation and Dives Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the shared selection package described in
`docs/superpowers/specs/2026-08-11-standardize-item-selection-design.md` and convert
the Dives list to it, so multi-select is discoverable and every later surface has a
proven component set to adopt.

**Architecture:** A `ValueNotifier<SelectionState>` owns the selection state machine
(explicit vs implicit entry, range anchoring, pruning to the visible set). Widgets
around it are dumb: `SelectionLeading` swaps a row's leading element for a checkbox,
`SelectionAppBar` renders one action set into either an `AppBar` or a pane
`Container`, and `SelectableListScope` supplies Escape, Ctrl/Cmd-A and Android back
handling. Surfaces declare their bulk actions as a `List<BulkAction>`; the baseline
three are injected by the app bar.

**Tech Stack:** Flutter 3.x, Material 3, Riverpod (existing page state only -- the
selection package itself is Riverpod-free), `flutter_test`, ARB localization.

## Scope

This plan covers **Phase 1 and Phase 2** of the spec. Phase 3 (sites, buddies, tags,
dive media), Phases 4-5 (ten further surfaces) and Phase 6 (cleanup) are separate
plans written after this one lands.

## Global Constraints

- `dart format .` must produce no changes. Run it before every commit.
- `flutter analyze` must be clean. CI treats analyzer **infos** as fatal, not just
  warnings and errors.
- Every user-facing string must exist in all 11 locales in `lib/l10n/arb/`:
  `ar de en es fr he hu it nl pt zh`.
- No emojis in code, comments, or documentation.
- Immutability: never mutate an existing object or collection in place; return new
  instances.
- No `print` or `debugPrint` in production code.
- Commit messages must NOT contain a `Co-Authored-By` line, the "Generated with
  Claude Code" attribution, or a `claude.ai/code` session URL.
- Work happens in the worktree at
  `.claude/worktrees/standardize-selection` on branch
  `worktree-standardize-selection`. Do not `cd` to the main checkout.
- Run tests with `flutter test <path>` from the worktree root.

## File Structure

**Create:**

| File | Responsibility |
| --- | --- |
| `lib/shared/selection/selection_state.dart` | Immutable snapshot of a selection |
| `lib/shared/selection/selection_controller.dart` | The state machine, plus `idsInRange` |
| `lib/shared/selection/bulk_action.dart` | Declarative description of one bulk action |
| `lib/shared/selection/selection_leading.dart` | Animated leading-element / checkbox swap |
| `lib/shared/selection/selection_app_bar.dart` | One action set, two shells |
| `lib/shared/selection/selectable_list_scope.dart` | Escape, Ctrl/Cmd-A, Android back |
| `test/shared/selection/selection_controller_test.dart` | Unit tests for the machine |
| `test/shared/selection/selection_leading_test.dart` | Widget tests |
| `test/shared/selection/selection_app_bar_test.dart` | Widget tests |
| `test/shared/selection/selectable_list_scope_test.dart` | Widget tests |
| `test/helpers/selection_contract.dart` | Reusable contract assertion, run per surface |

**Modify:**

| File | Change |
| --- | --- |
| `lib/l10n/arb/app_*.arb` (11 files) | Add 5 `common_selection_*` keys |
| `lib/features/dive_log/presentation/widgets/dive_list_content.dart` | Replace local state machine and both bar builders |
| `lib/features/dive_log/presentation/widgets/dive_list_item.dart` | `isSelected` becomes `isChecked`; two independent channels |
| `lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart` | Same rename; use `SelectionLeading` |
| `lib/features/dive_log/presentation/pages/dive_list_page.dart` | `DiveListTile`: same rename; use `SelectionLeading` |
| `lib/features/dive_log/presentation/widgets/dive_table_view.dart` | Wire modifier-click; accept the controller |
| `test/features/dive_log/presentation/widgets/dive_list_selection_test.dart` | Update to the new API; add the contract call |

---

### Task 1: SelectionState and basic entry/exit

**Files:**
- Create: `lib/shared/selection/selection_state.dart`
- Create: `lib/shared/selection/selection_controller.dart`
- Test: `test/shared/selection/selection_controller_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class SelectionState` with `Set<String> checkedIds`, `bool isActive`,
    `bool enteredExplicitly`, `String? anchorId`, `int get count`,
    `bool isChecked(String id)`, `SelectionState copyWith({...})`,
    `static const SelectionState inactive`.
  - `class SelectionController extends ValueNotifier<SelectionState>` with
    `void enterExplicit()`, `void enterImplicit(String id)`,
    `void toggle(String id)`, `void exit()`.

- [ ] **Step 1: Write the failing test**

Create `test/shared/selection/selection_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';

void main() {
  group('SelectionController entry and exit', () {
    test('starts inactive with nothing checked', () {
      final controller = SelectionController();
      expect(controller.value.isActive, isFalse);
      expect(controller.value.checkedIds, isEmpty);
      expect(controller.value.count, 0);
    });

    test('enterExplicit activates with nothing checked', () {
      final controller = SelectionController();
      controller.enterExplicit();
      expect(controller.value.isActive, isTrue);
      expect(controller.value.enteredExplicitly, isTrue);
      expect(controller.value.checkedIds, isEmpty);
    });

    test('enterImplicit activates and checks the given id', () {
      final controller = SelectionController();
      controller.enterImplicit('b');
      expect(controller.value.isActive, isTrue);
      expect(controller.value.enteredExplicitly, isFalse);
      expect(controller.value.checkedIds, {'b'});
      expect(controller.value.anchorId, 'b');
    });

    test('toggle adds then removes an id', () {
      final controller = SelectionController();
      controller.enterExplicit();
      controller.toggle('a');
      expect(controller.value.checkedIds, {'a'});
      controller.toggle('a');
      expect(controller.value.checkedIds, isEmpty);
    });

    test('implicit entry auto-exits when the last id is unchecked', () {
      final controller = SelectionController();
      controller.enterImplicit('a');
      controller.toggle('a');
      expect(controller.value.isActive, isFalse);
    });

    test('explicit entry stays active at zero checked', () {
      final controller = SelectionController();
      controller.enterExplicit();
      controller.toggle('a');
      controller.toggle('a');
      expect(controller.value.isActive, isTrue);
      expect(controller.value.count, 0);
    });

    test('exit clears everything', () {
      final controller = SelectionController();
      controller.enterImplicit('a');
      controller.toggle('b');
      controller.exit();
      expect(controller.value, SelectionState.inactive);
    });

    test('notifies listeners on each transition', () {
      final controller = SelectionController();
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.enterExplicit();
      controller.toggle('a');
      controller.exit();
      expect(notifications, 3);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/selection/selection_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:submersion/shared/selection/selection_controller.dart'`

- [ ] **Step 3: Write the implementation**

Create `lib/shared/selection/selection_state.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Immutable snapshot of a multi-selection on one list or grid surface.
///
/// [enteredExplicitly] records how selection mode began, because that decides
/// how it ends: a mode the user asked for with the Select button survives at
/// zero checked items, while one entered by long-press or modifier-click
/// evaporates when the last item is unchecked.
@immutable
class SelectionState {
  /// Ids of the checked items. Always entity ids, never list indices.
  final Set<String> checkedIds;

  /// Whether selection mode is active at all.
  final bool isActive;

  /// True when the mode was entered deliberately (Select button, Ctrl/Cmd-A).
  final bool enteredExplicitly;

  /// Fixed origin for shift-click range extension.
  final String? anchorId;

  const SelectionState({
    required this.checkedIds,
    required this.isActive,
    required this.enteredExplicitly,
    required this.anchorId,
  });

  /// The resting state: no mode, nothing checked, no anchor.
  static const SelectionState inactive = SelectionState(
    checkedIds: <String>{},
    isActive: false,
    enteredExplicitly: false,
    anchorId: null,
  );

  int get count => checkedIds.length;

  bool isChecked(String id) => checkedIds.contains(id);

  SelectionState copyWith({
    Set<String>? checkedIds,
    bool? isActive,
    bool? enteredExplicitly,
    String? anchorId,
    bool clearAnchor = false,
  }) {
    return SelectionState(
      checkedIds: checkedIds ?? this.checkedIds,
      isActive: isActive ?? this.isActive,
      enteredExplicitly: enteredExplicitly ?? this.enteredExplicitly,
      anchorId: clearAnchor ? null : (anchorId ?? this.anchorId),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SelectionState &&
      other.isActive == isActive &&
      other.enteredExplicitly == enteredExplicitly &&
      other.anchorId == anchorId &&
      setEquals(other.checkedIds, checkedIds);

  @override
  int get hashCode => Object.hash(
    isActive,
    enteredExplicitly,
    anchorId,
    Object.hashAllUnordered(checkedIds),
  );
}
```

Create `lib/shared/selection/selection_controller.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'package:submersion/shared/selection/selection_state.dart';

/// Owns the multi-selection state machine for one list or grid surface.
///
/// Deliberately not a Riverpod provider: selection prunes to the visible set
/// and does not survive leaving the surface, so it is ephemeral view state.
/// A plain [ValueNotifier] is testable without a ProviderContainer.
class SelectionController extends ValueNotifier<SelectionState> {
  SelectionController() : super(SelectionState.inactive);

  /// Enter selection mode deliberately, with nothing checked.
  ///
  /// No-op when already active, so tapping Select twice does not clear the
  /// user's work.
  void enterExplicit() {
    if (value.isActive) return;
    value = const SelectionState(
      checkedIds: <String>{},
      isActive: true,
      enteredExplicitly: true,
      anchorId: null,
    );
  }

  /// Enter selection mode as a side effect of long-press or modifier-click,
  /// checking [id]. Behaves as [toggle] when the mode is already active.
  void enterImplicit(String id) {
    if (value.isActive) {
      toggle(id);
      return;
    }
    value = SelectionState(
      checkedIds: {id},
      isActive: true,
      enteredExplicitly: false,
      anchorId: id,
    );
  }

  /// Check or uncheck [id], moving the range anchor to it.
  ///
  /// Unchecking the last item ends an implicitly entered mode.
  void toggle(String id) {
    final next = Set<String>.from(value.checkedIds);
    if (!next.remove(id)) next.add(id);

    if (next.isEmpty && !value.enteredExplicitly) {
      exit();
      return;
    }
    value = value.copyWith(checkedIds: next, anchorId: id);
  }

  /// Leave selection mode and discard the selection.
  void exit() {
    value = SelectionState.inactive;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/selection/selection_controller_test.dart`
Expected: PASS, 8 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/shared/selection test/shared/selection
flutter analyze lib/shared/selection test/shared/selection
git add lib/shared/selection test/shared/selection
git commit -m "feat(selection): add SelectionState and entry/exit state machine"
```

---

### Task 2: Range extension with anchor semantics

**Files:**
- Modify: `lib/shared/selection/selection_controller.dart`
- Test: `test/shared/selection/selection_controller_test.dart`

**Interfaces:**
- Consumes: `SelectionController`, `SelectionState` from Task 1.
- Produces:
  - `List<String> idsInRange(List<String> orderedIds, String anchorId, String targetId)`
    — top-level, order-independent, inclusive of both ends, empty when either id
    is absent.
  - `void SelectionController.extendTo(String targetId, List<String> orderedIds, {String? fallbackAnchorId})`

- [ ] **Step 1: Write the failing test**

Append to `test/shared/selection/selection_controller_test.dart`, inside `main()`:

```dart
  group('idsInRange', () {
    const ordered = ['a', 'b', 'c', 'd', 'e'];

    test('is inclusive of both ends', () {
      expect(idsInRange(ordered, 'b', 'd'), ['b', 'c', 'd']);
    });

    test('is order-independent', () {
      expect(idsInRange(ordered, 'd', 'b'), ['b', 'c', 'd']);
    });

    test('returns the single id when anchor equals target', () {
      expect(idsInRange(ordered, 'c', 'c'), ['c']);
    });

    test('returns empty when an id is not present', () {
      expect(idsInRange(ordered, 'z', 'c'), isEmpty);
      expect(idsInRange(ordered, 'c', 'z'), isEmpty);
    });
  });

  group('SelectionController.extendTo', () {
    const ordered = ['a', 'b', 'c', 'd', 'e'];

    test('activates implicitly and checks the range from the fallback anchor', () {
      final controller = SelectionController();
      controller.extendTo('d', ordered, fallbackAnchorId: 'b');
      expect(controller.value.isActive, isTrue);
      expect(controller.value.enteredExplicitly, isFalse);
      expect(controller.value.checkedIds, {'b', 'c', 'd'});
      expect(controller.value.anchorId, 'b');
    });

    test('checks only the target when there is no anchor to fall back on', () {
      final controller = SelectionController();
      controller.extendTo('d', ordered);
      expect(controller.value.checkedIds, {'d'});
      expect(controller.value.anchorId, 'd');
    });

    test('keeps the anchor fixed across consecutive extends', () {
      final controller = SelectionController();
      controller.enterImplicit('b');
      controller.extendTo('d', ordered);
      expect(controller.value.checkedIds, {'b', 'c', 'd'});
      controller.extendTo('c', ordered);
      expect(controller.value.anchorId, 'b');
      expect(controller.value.checkedIds, containsAll({'b', 'c', 'd'}));
    });

    test('adds to an existing selection rather than replacing it', () {
      final controller = SelectionController();
      controller.enterImplicit('a');
      controller.toggle('e');
      controller.extendTo('c', ordered, fallbackAnchorId: 'b');
      expect(controller.value.checkedIds, {'a', 'e', 'b', 'c'});
    });

    test('ignores a target that is not in the visible list', () {
      final controller = SelectionController();
      controller.enterImplicit('a');
      controller.extendTo('zz', ordered);
      expect(controller.value.checkedIds, {'a'});
    });
  });
```

Add the import for `idsInRange` — it lives in `selection_controller.dart`, already
imported.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/selection/selection_controller_test.dart`
Expected: FAIL — `The function 'idsInRange' isn't defined` and
`The method 'extendTo' isn't defined for the type 'SelectionController'`.

- [ ] **Step 3: Write the implementation**

Add to `lib/shared/selection/selection_controller.dart`, above the class:

```dart
/// Inclusive id span between [anchorId] and [targetId] within [orderedIds].
///
/// Order-independent: extending backwards selects the same range. Returns an
/// empty list when either id is absent, so a stale anchor cannot select a
/// wrong span.
List<String> idsInRange(
  List<String> orderedIds,
  String anchorId,
  String targetId,
) {
  final anchorIndex = orderedIds.indexOf(anchorId);
  final targetIndex = orderedIds.indexOf(targetId);
  if (anchorIndex < 0 || targetIndex < 0) return const [];

  final lo = anchorIndex < targetIndex ? anchorIndex : targetIndex;
  final hi = anchorIndex < targetIndex ? targetIndex : anchorIndex;
  return [for (var i = lo; i <= hi; i++) orderedIds[i]];
}
```

Add to the `SelectionController` class:

```dart
  /// Check every item between the anchor and [targetId] in [orderedIds].
  ///
  /// The anchor is the controller's current anchor, else [fallbackAnchorId]
  /// (the row highlighted in the detail pane), else [targetId] itself. The
  /// anchor never moves during extension, so consecutive shift-clicks extend
  /// from the original origin rather than walking it forward.
  void extendTo(
    String targetId,
    List<String> orderedIds, {
    String? fallbackAnchorId,
  }) {
    if (!orderedIds.contains(targetId)) return;

    final anchor = value.anchorId ?? fallbackAnchorId ?? targetId;
    final next = Set<String>.from(value.checkedIds)
      ..addAll(idsInRange(orderedIds, anchor, targetId));

    value = SelectionState(
      checkedIds: next,
      isActive: true,
      enteredExplicitly: value.isActive ? value.enteredExplicitly : false,
      anchorId: anchor,
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/selection/selection_controller_test.dart`
Expected: PASS, 17 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/shared/selection test/shared/selection
flutter analyze lib/shared/selection test/shared/selection
git add lib/shared/selection test/shared/selection
git commit -m "feat(selection): add anchored range extension"
```

---

### Task 3: Select all, deselect all, and pruning

**Files:**
- Modify: `lib/shared/selection/selection_controller.dart`
- Test: `test/shared/selection/selection_controller_test.dart`

**Interfaces:**
- Consumes: Tasks 1-2.
- Produces:
  - `void SelectionController.selectAll(List<String> selectableIds)`
  - `void SelectionController.deselectAll()`
  - `void SelectionController.pruneTo(List<String> visibleIds)`

- [ ] **Step 1: Write the failing test**

Append to `test/shared/selection/selection_controller_test.dart`, inside `main()`:

```dart
  group('SelectionController bulk operations', () {
    test('selectAll activates explicitly and checks every selectable id', () {
      final controller = SelectionController();
      controller.selectAll(['a', 'b', 'c']);
      expect(controller.value.isActive, isTrue);
      expect(controller.value.enteredExplicitly, isTrue);
      expect(controller.value.checkedIds, {'a', 'b', 'c'});
    });

    test('selectAll only checks the ids it is given, excluding disabled rows', () {
      final controller = SelectionController();
      controller.enterImplicit('a');
      // 'c' is non-selectable, so the surface omits it from the argument.
      controller.selectAll(['a', 'b']);
      expect(controller.value.checkedIds, {'a', 'b'});
    });

    test('deselectAll clears but keeps an explicit mode active', () {
      final controller = SelectionController();
      controller.enterExplicit();
      controller.toggle('a');
      controller.deselectAll();
      expect(controller.value.isActive, isTrue);
      expect(controller.value.checkedIds, isEmpty);
    });

    test('deselectAll ends an implicit mode', () {
      final controller = SelectionController();
      controller.enterImplicit('a');
      controller.deselectAll();
      expect(controller.value.isActive, isFalse);
    });
  });

  group('SelectionController.pruneTo', () {
    test('drops checked ids that left the visible set', () {
      final controller = SelectionController();
      controller.enterExplicit();
      controller.toggle('a');
      controller.toggle('b');
      controller.toggle('c');
      controller.pruneTo(['a', 'c']);
      expect(controller.value.checkedIds, {'a', 'c'});
    });

    test('clears the anchor when the anchor is no longer visible', () {
      final controller = SelectionController();
      controller.enterImplicit('b');
      controller.pruneTo(['a', 'c']);
      expect(controller.value.anchorId, isNull);
    });

    test('ends an implicit mode when pruning empties the selection', () {
      final controller = SelectionController();
      controller.enterImplicit('b');
      controller.pruneTo(['a', 'c']);
      expect(controller.value.isActive, isFalse);
    });

    test('keeps an explicit mode active when pruning empties the selection', () {
      final controller = SelectionController();
      controller.enterExplicit();
      controller.toggle('b');
      controller.pruneTo(['a', 'c']);
      expect(controller.value.isActive, isTrue);
      expect(controller.value.checkedIds, isEmpty);
    });

    test('does nothing and does not notify when the mode is inactive', () {
      final controller = SelectionController();
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.pruneTo(['a']);
      expect(notifications, 0);
    });

    test('does not notify when nothing was pruned', () {
      final controller = SelectionController();
      controller.enterImplicit('a');
      var notifications = 0;
      controller.addListener(() => notifications++);
      controller.pruneTo(['a', 'b']);
      expect(notifications, 0);
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/selection/selection_controller_test.dart`
Expected: FAIL — `selectAll`, `deselectAll`, `pruneTo` not defined.

- [ ] **Step 3: Write the implementation**

Add to `SelectionController`:

```dart
  /// Check every id in [selectableIds].
  ///
  /// The surface passes only rows that can actually be acted on, so
  /// non-selectable rows are excluded by omission rather than by a filter
  /// here. Counts as explicit entry: the user asked for all of them.
  void selectAll(List<String> selectableIds) {
    value = SelectionState(
      checkedIds: Set<String>.from(selectableIds),
      isActive: true,
      enteredExplicitly: true,
      anchorId: value.anchorId,
    );
  }

  /// Uncheck everything, ending an implicitly entered mode.
  ///
  /// Ending the implicit mode here is the same rule as unchecking the last
  /// item by hand, so the two paths cannot disagree.
  void deselectAll() {
    if (!value.enteredExplicitly) {
      exit();
      return;
    }
    value = value.copyWith(checkedIds: const <String>{}, clearAnchor: true);
  }

  /// Drop checked ids that are no longer in [visibleIds].
  ///
  /// Called whenever the filtered, searched or sorted list changes, so the
  /// count always matches what is on screen and a bulk action can never reach
  /// a record the user cannot see.
  void pruneTo(List<String> visibleIds) {
    if (!value.isActive) return;

    final visible = visibleIds.toSet();
    final next = value.checkedIds.where(visible.contains).toSet();
    final anchorStillVisible =
        value.anchorId != null && visible.contains(value.anchorId);

    if (next.length == value.checkedIds.length &&
        (value.anchorId == null || anchorStillVisible)) {
      return;
    }

    if (next.isEmpty && !value.enteredExplicitly) {
      exit();
      return;
    }

    value = value.copyWith(
      checkedIds: next,
      anchorId: anchorStillVisible ? value.anchorId : null,
      clearAnchor: !anchorStillVisible,
    );
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/selection/selection_controller_test.dart`
Expected: PASS, 27 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/shared/selection test/shared/selection
flutter analyze lib/shared/selection test/shared/selection
git add lib/shared/selection test/shared/selection
git commit -m "feat(selection): add select-all, deselect-all and prune-to-visible"
```

---

### Task 4: Localization strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and the other 10 ARB files

**Interfaces:**
- Consumes: nothing.
- Produces: `context.l10n.common_selection_countSelected(count)`,
  `common_selection_enterTooltip`, `common_selection_exitTooltip`,
  `common_selection_selectAllTooltip`, `common_selection_deselectAllTooltip`.

- [ ] **Step 1: Add the English keys**

Add to `lib/l10n/arb/app_en.arb`:

```json
  "common_selection_countSelected": "{count} selected",
  "@common_selection_countSelected": {
    "placeholders": { "count": { "type": "Object" } }
  },
  "common_selection_enterTooltip": "Select items",
  "common_selection_exitTooltip": "Exit selection",
  "common_selection_selectAllTooltip": "Select all",
  "common_selection_deselectAllTooltip": "Deselect all",
```

- [ ] **Step 2: Add the translations**

Add the same five keys to each remaining ARB file with these values. Only
`app_en.arb` carries the `@common_selection_countSelected` metadata block; the
others carry the plain keys.

| Locale | countSelected | enterTooltip | exitTooltip | selectAllTooltip | deselectAllTooltip |
| --- | --- | --- | --- | --- | --- |
| ar | `{count} محدد` | `تحديد العناصر` | `إنهاء التحديد` | `تحديد الكل` | `إلغاء تحديد الكل` |
| de | `{count} ausgewählt` | `Elemente auswählen` | `Auswahl beenden` | `Alle auswählen` | `Auswahl aufheben` |
| es | `{count} seleccionados` | `Seleccionar elementos` | `Salir de la selección` | `Seleccionar todo` | `Deseleccionar todo` |
| fr | `{count} sélectionnés` | `Sélectionner des éléments` | `Quitter la sélection` | `Tout sélectionner` | `Tout désélectionner` |
| he | `{count} נבחרו` | `בחירת פריטים` | `יציאה מבחירה` | `בחר הכול` | `בטל בחירת הכול` |
| hu | `{count} kijelölve` | `Elemek kijelölése` | `Kijelölés befejezése` | `Összes kijelölése` | `Kijelölés megszüntetése` |
| it | `{count} selezionati` | `Seleziona elementi` | `Esci dalla selezione` | `Seleziona tutto` | `Deseleziona tutto` |
| nl | `{count} geselecteerd` | `Items selecteren` | `Selectie beëindigen` | `Alles selecteren` | `Alles deselecteren` |
| pt | `{count} selecionados` | `Selecionar itens` | `Sair da seleção` | `Selecionar tudo` | `Desmarcar tudo` |
| zh | `已选择 {count} 项` | `选择项目` | `退出选择` | `全选` | `取消全选` |

- [ ] **Step 3: Regenerate localizations and verify**

Run: `flutter gen-l10n`
Then: `flutter analyze lib/l10n`
Expected: no missing-translation warnings for the new keys.

- [ ] **Step 4: Commit**

```bash
dart format lib
git add lib/l10n
git commit -m "feat(l10n): add shared selection strings in all locales"
```

---

### Task 5: BulkAction model

**Files:**
- Create: `lib/shared/selection/bulk_action.dart`
- Test: `test/shared/selection/bulk_action_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class BulkAction` with fields `String id`, `IconData icon`,
  `String label`, `int minCount`, `int? maxCount`, `bool isDestructive`,
  `VoidCallback onInvoke`, and `bool isEnabledFor(int count)`.

- [ ] **Step 1: Write the failing test**

Create `test/shared/selection/bulk_action_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

void main() {
  BulkAction build({int minCount = 1, int? maxCount}) => BulkAction(
    id: 'merge',
    icon: Icons.merge_type,
    label: 'Merge',
    minCount: minCount,
    maxCount: maxCount,
    onInvoke: () {},
  );

  group('BulkAction.isEnabledFor', () {
    test('is disabled below minCount', () {
      expect(build(minCount: 2).isEnabledFor(1), isFalse);
    });

    test('is enabled at minCount', () {
      expect(build(minCount: 2).isEnabledFor(2), isTrue);
    });

    test('is enabled above minCount when there is no maximum', () {
      expect(build(minCount: 2).isEnabledFor(9), isTrue);
    });

    test('is disabled above maxCount', () {
      expect(build(minCount: 2, maxCount: 4).isEnabledFor(5), isFalse);
    });

    test('is disabled at zero regardless of configuration', () {
      expect(build(minCount: 0).isEnabledFor(0), isFalse);
    });

    test('defaults to non-destructive', () {
      expect(build().isDestructive, isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/selection/bulk_action_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/shared/selection/bulk_action.dart`:

```dart
import 'package:flutter/material.dart';

/// One bulk operation a surface offers on the current selection.
///
/// Surfaces declare their extras as a list of these; the baseline
/// select-all / deselect-all / delete controls are supplied by
/// SelectionAppBar itself, so no surface can accidentally omit them.
@immutable
class BulkAction {
  /// Stable identifier, used as the widget key and in tests.
  final String id;

  /// Canonical icon for the concept. One icon per concept across the app:
  /// every merge-like action uses the same glyph, including dive combine.
  final IconData icon;

  /// Localized label, shown as a tooltip and as the overflow menu entry.
  final String label;

  /// Smallest selection this action accepts. Merge needs 2, delete needs 1.
  final int minCount;

  /// Largest selection this action accepts, when one applies.
  final int? maxCount;

  /// Destructive actions render in the error color and confirm before acting.
  final bool isDestructive;

  /// Actions that operate on the list rather than on the current selection,
  /// such as "select by date range", and so stay enabled at zero checked.
  final bool alwaysEnabled;

  final VoidCallback onInvoke;

  const BulkAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.onInvoke,
    this.minCount = 1,
    this.maxCount,
    this.isDestructive = false,
    this.alwaysEnabled = false,
  });

  /// Whether this action can run against a selection of [count] items.
  ///
  /// An empty selection never enables an action, whatever [minCount] says,
  /// unless the action declared itself [alwaysEnabled].
  bool isEnabledFor(int count) {
    if (alwaysEnabled) return true;
    if (count == 0) return false;
    if (count < minCount) return false;
    if (maxCount != null && count > maxCount!) return false;
    return true;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/selection/bulk_action_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/shared/selection test/shared/selection
flutter analyze lib/shared/selection test/shared/selection
git add lib/shared/selection/bulk_action.dart test/shared/selection/bulk_action_test.dart
git commit -m "feat(selection): add BulkAction model"
```

---

### Task 6: SelectionLeading

**Files:**
- Create: `lib/shared/selection/selection_leading.dart`
- Test: `test/shared/selection/selection_leading_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `class SelectionLeading extends StatelessWidget` with named
  parameters `bool isSelectionMode`, `bool isChecked`, `bool isSelectable`,
  `Widget child`, `ValueChanged<bool>? onChanged`.

- [ ] **Step 1: Write the failing test**

Create `test/shared/selection/selection_leading_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/selection_leading.dart';

void main() {
  Widget host({
    required bool isSelectionMode,
    bool isChecked = false,
    bool isSelectable = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SelectionLeading(
          isSelectionMode: isSelectionMode,
          isChecked: isChecked,
          isSelectable: isSelectable,
          onChanged: (_) {},
          child: const Text('412'),
        ),
      ),
    );
  }

  group('SelectionLeading', () {
    testWidgets('shows the child and no checkbox outside selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(host(isSelectionMode: false));
      await tester.pumpAndSettle();
      expect(find.text('412'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('replaces the child with a checkbox in selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(host(isSelectionMode: true));
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('412'), findsNothing);
    });

    testWidgets('reflects the checked state', (tester) async {
      await tester.pumpWidget(host(isSelectionMode: true, isChecked: true));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
    });

    testWidgets('keeps the child for non-selectable rows', (tester) async {
      await tester.pumpWidget(
        host(isSelectionMode: true, isSelectable: false),
      );
      await tester.pumpAndSettle();
      expect(find.text('412'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('reports a change when tapped', (tester) async {
      bool? reported;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SelectionLeading(
              isSelectionMode: true,
              isChecked: false,
              onChanged: (v) => reported = v,
              child: const Text('412'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      expect(reported, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/selection/selection_leading_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/shared/selection/selection_leading.dart`:

```dart
import 'package:flutter/material.dart';

/// A row's leading slot, which becomes a checkbox in selection mode.
///
/// The swap is animated so entering and leaving the mode does not jolt the
/// list. Non-selectable rows keep their [child] and render no checkbox, which
/// is what tells the user at a glance that the row cannot be acted on.
class SelectionLeading extends StatelessWidget {
  /// The row's normal leading element: dive number badge, avatar, gear icon.
  final Widget child;

  final bool isSelectionMode;
  final bool isChecked;

  /// False for rows that cannot be acted on, such as built-in reference data.
  final bool isSelectable;

  final ValueChanged<bool>? onChanged;

  const SelectionLeading({
    super.key,
    required this.child,
    required this.isSelectionMode,
    required this.isChecked,
    this.isSelectable = true,
    this.onChanged,
  });

  static const Duration _swapDuration = Duration(milliseconds: 150);

  @override
  Widget build(BuildContext context) {
    final showCheckbox = isSelectionMode && isSelectable;

    return AnimatedSwitcher(
      duration: _swapDuration,
      child: showCheckbox
          ? Checkbox(
              key: const ValueKey('selection_leading_checkbox'),
              value: isChecked,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: onChanged == null
                  ? null
                  : (value) => onChanged!(value ?? false),
            )
          : KeyedSubtree(
              key: const ValueKey('selection_leading_child'),
              child: child,
            ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/selection/selection_leading_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/shared/selection test/shared/selection
flutter analyze lib/shared/selection test/shared/selection
git add lib/shared/selection/selection_leading.dart test/shared/selection/selection_leading_test.dart
git commit -m "feat(selection): add animated SelectionLeading swap"
```

---

### Task 7: SelectionAppBar

**Files:**
- Create: `lib/shared/selection/selection_app_bar.dart`
- Test: `test/shared/selection/selection_app_bar_test.dart`

**Interfaces:**
- Consumes: `SelectionController`, `SelectionState` (Tasks 1-3), `BulkAction`
  (Task 5), the `common_selection_*` strings (Task 4).
- Produces:
  - `enum SelectionBarShell { appBar, pane }`
  - `class SelectionAppBar extends StatelessWidget` with named parameters
    `SelectionController controller`, `List<String> selectableIds`,
    `List<BulkAction> actions`, `SelectionBarShell shell`,
    `VoidCallback? onDelete`, `int maxInlineActions`.
  - `PreferredSizeWidget` when `shell == SelectionBarShell.appBar`, achieved by
    the class implementing `PreferredSizeWidget` and returning
    `const Size.fromHeight(kToolbarHeight)`.

The action set and its ordering are computed once, in `_visibleActions`, and are
identical in both shells. Only the split between inline icons and the overflow menu
depends on `maxInlineActions`.

- [ ] **Step 1: Write the failing test**

Create `test/shared/selection/selection_app_bar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';

import '../../helpers/test_app.dart';

void main() {
  late SelectionController controller;

  setUp(() => controller = SelectionController());
  tearDown(() => controller.dispose());

  Widget host({
    SelectionBarShell shell = SelectionBarShell.appBar,
    List<BulkAction> actions = const [],
    VoidCallback? onDelete,
    int maxInlineActions = 3,
  }) {
    final bar = SelectionAppBar(
      controller: controller,
      selectableIds: const ['a', 'b', 'c'],
      actions: actions,
      shell: shell,
      onDelete: onDelete ?? () {},
      maxInlineActions: maxInlineActions,
    );
    return wrapWithTestApp(
      Scaffold(
        appBar: shell == SelectionBarShell.appBar ? bar : null,
        body: shell == SelectionBarShell.pane ? bar : const SizedBox(),
      ),
    );
  }

  group('SelectionAppBar', () {
    testWidgets('shows the selected count', (tester) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(find.textContaining('1'), findsWidgets);
    });

    testWidgets('exit control clears the selection', (tester) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_exit')));
      await tester.pumpAndSettle();
      expect(controller.value.isActive, isFalse);
    });

    testWidgets('select all checks every selectable id', (tester) async {
      controller.enterExplicit();
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();
      expect(controller.value.checkedIds, {'a', 'b', 'c'});
    });

    testWidgets('deselect all is disabled at zero checked', (tester) async {
      controller.enterExplicit();
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final button = tester.widget<IconButton>(
        find.byKey(const ValueKey('selection_deselect_all')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('delete is disabled at zero checked', (tester) async {
      controller.enterExplicit();
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      final button = tester.widget<IconButton>(
        find.byKey(const ValueKey('selection_delete')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('an extra below its minCount renders disabled', (tester) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(
        host(
          actions: [
            BulkAction(
              id: 'merge',
              icon: Icons.merge_type,
              label: 'Merge',
              minCount: 2,
              onInvoke: () {},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<IconButton>(
        find.byKey(const ValueKey('selection_action_merge')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('an enabled extra invokes its callback', (tester) async {
      var invoked = false;
      controller.enterImplicit('a');
      controller.toggle('b');
      await tester.pumpWidget(
        host(
          actions: [
            BulkAction(
              id: 'merge',
              icon: Icons.merge_type,
              label: 'Merge',
              minCount: 2,
              onInvoke: () => invoked = true,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_action_merge')));
      await tester.pumpAndSettle();
      expect(invoked, isTrue);
    });

    testWidgets('extras beyond maxInlineActions move to the overflow', (
      tester,
    ) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(
        host(
          maxInlineActions: 1,
          actions: [
            BulkAction(
              id: 'one',
              icon: Icons.merge_type,
              label: 'One',
              onInvoke: () {},
            ),
            BulkAction(
              id: 'two',
              icon: Icons.ios_share,
              label: 'Two',
              onInvoke: () {},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('selection_action_one')), findsOneWidget);
      expect(find.byKey(const ValueKey('selection_action_two')), findsNothing);
      expect(find.byKey(const ValueKey('selection_overflow')), findsOneWidget);
    });

    testWidgets('the pane shell renders the same actions without an AppBar', (
      tester,
    ) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(
        host(
          shell: SelectionBarShell.pane,
          actions: [
            BulkAction(
              id: 'merge',
              icon: Icons.merge_type,
              label: 'Merge',
              onInvoke: () {},
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);
      expect(
        find.byKey(const ValueKey('selection_action_merge')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('selection_exit')), findsOneWidget);
    });
  });
}
```

Note: `wrapWithTestApp` comes from `test/helpers/test_app.dart`, already used by
`dive_list_selection_test.dart`. Read that helper before writing this test and match
its actual function name and signature; if it differs, use the real one rather than
inventing a wrapper.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/selection/selection_app_bar_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/shared/selection/selection_app_bar.dart`:

```dart
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selection_controller.dart';

/// Which container the selection bar is rendered into.
enum SelectionBarShell {
  /// The surface owns the window chrome, so the bar is a real [AppBar].
  appBar,

  /// The surface is a pane or an embedded section, so the bar is a plain
  /// container placed above the list.
  pane,
}

/// The contextual bar shown while a surface is in selection mode.
///
/// One content builder, two shells. The baseline controls -- select all,
/// deselect all, delete -- are injected here rather than declared per surface,
/// so no list can ship without them. Surfaces contribute only their extras.
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final SelectionController controller;

  /// Ids the surface will accept actions on, already filtered to exclude
  /// non-selectable rows. Select-all uses exactly this list.
  final List<String> selectableIds;

  /// Surface-specific extras: merge, export, bulk edit, and so on.
  final List<BulkAction> actions;

  final SelectionBarShell shell;

  /// Invoked by the baseline delete control.
  final VoidCallback? onDelete;

  /// How many extras render as inline icons before the rest overflow.
  final int maxInlineActions;

  const SelectionAppBar({
    super.key,
    required this.controller,
    required this.selectableIds,
    required this.actions,
    required this.shell,
    this.onDelete,
    this.maxInlineActions = 3,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, state, _) {
        final count = state.count;
        final title = Text(context.l10n.common_selection_countSelected(count));
        final leading = IconButton(
          key: const ValueKey('selection_exit'),
          icon: const Icon(Icons.close),
          tooltip: context.l10n.common_selection_exitTooltip,
          onPressed: controller.exit,
        );
        final trailing = _buildControls(context, count);

        switch (shell) {
          case SelectionBarShell.appBar:
            return AppBar(leading: leading, title: title, actions: trailing);
          case SelectionBarShell.pane:
            return Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    leading,
                    const SizedBox(width: 8),
                    Expanded(child: title),
                    ...trailing,
                  ],
                ),
              ),
            );
        }
      },
    );
  }

  /// Baseline controls plus extras, in a fixed order, identical in both
  /// shells. Only the inline/overflow split depends on [maxInlineActions].
  List<Widget> _buildControls(BuildContext context, int count) {
    final allChecked = count >= selectableIds.length && selectableIds.isNotEmpty;
    final inline = actions.take(maxInlineActions).toList();
    final overflow = actions.skip(maxInlineActions).toList();

    return [
      IconButton(
        key: const ValueKey('selection_select_all'),
        icon: const Icon(Icons.select_all),
        tooltip: context.l10n.common_selection_selectAllTooltip,
        onPressed: allChecked
            ? null
            : () => controller.selectAll(selectableIds),
      ),
      IconButton(
        key: const ValueKey('selection_deselect_all'),
        icon: const Icon(Icons.deselect),
        tooltip: context.l10n.common_selection_deselectAllTooltip,
        onPressed: count == 0 ? null : controller.deselectAll,
      ),
      for (final action in inline)
        IconButton(
          key: ValueKey('selection_action_${action.id}'),
          icon: Icon(action.icon),
          tooltip: action.label,
          color: action.isDestructive
              ? Theme.of(context).colorScheme.error
              : null,
          onPressed: action.isEnabledFor(count) ? action.onInvoke : null,
        ),
      IconButton(
        key: const ValueKey('selection_delete'),
        icon: const Icon(Icons.delete_outline),
        tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
        color: Theme.of(context).colorScheme.error,
        onPressed: count == 0 ? null : onDelete,
      ),
      if (overflow.isNotEmpty)
        PopupMenuButton<String>(
          key: const ValueKey('selection_overflow'),
          itemBuilder: (context) => [
            for (final action in overflow)
              PopupMenuItem<String>(
                value: action.id,
                enabled: action.isEnabledFor(count),
                child: ListTile(
                  leading: Icon(action.icon),
                  title: Text(action.label),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
          ],
          onSelected: (id) {
            for (final action in overflow) {
              if (action.id == id) {
                action.onInvoke();
                return;
              }
            }
          },
        ),
    ];
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/selection/selection_app_bar_test.dart`
Expected: PASS, 9 tests.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/shared/selection test/shared/selection
flutter analyze lib/shared/selection test/shared/selection
git add lib/shared/selection/selection_app_bar.dart test/shared/selection/selection_app_bar_test.dart
git commit -m "feat(selection): add SelectionAppBar with baseline and declared actions"
```

---

### Task 8: SelectableListScope

**Files:**
- Create: `lib/shared/selection/selectable_list_scope.dart`
- Test: `test/shared/selection/selectable_list_scope_test.dart`

**Interfaces:**
- Consumes: `SelectionController` (Tasks 1-3).
- Produces: `class SelectableListScope extends StatelessWidget` with named
  parameters `SelectionController controller`, `List<String> selectableIds`,
  `Widget child`. Also exposes `static bool isModifierPressed()` and
  `static bool isShiftPressed()` for surfaces to classify pointer events.

- [ ] **Step 1: Write the failing test**

Create `test/shared/selection/selectable_list_scope_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_controller.dart';

void main() {
  late SelectionController controller;

  setUp(() => controller = SelectionController());
  tearDown(() => controller.dispose());

  Widget host() {
    return MaterialApp(
      home: Scaffold(
        body: SelectableListScope(
          controller: controller,
          selectableIds: const ['a', 'b', 'c'],
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  group('SelectableListScope', () {
    testWidgets('Escape exits selection mode', (tester) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.value.isActive, isFalse);
    });

    testWidgets('Escape does nothing when not in selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(controller.value.isActive, isFalse);
    });

    testWidgets('Ctrl-A selects all and enters the mode', (tester) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(controller.value.checkedIds, {'a', 'b', 'c'});
    });

    testWidgets('back exits selection mode instead of popping', (tester) async {
      controller.enterImplicit('a');
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(controller.value.isActive, isFalse);
      expect(popped, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shared/selection/selectable_list_scope_test.dart`
Expected: FAIL — URI does not exist.

- [ ] **Step 3: Write the implementation**

Create `lib/shared/selection/selectable_list_scope.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:submersion/shared/selection/selection_controller.dart';

/// Wraps a selectable list with its keyboard and back-navigation handling.
///
/// Escape leaves selection mode, Ctrl/Cmd-A checks everything, and Android
/// back leaves the mode rather than popping the route. Without this the only
/// way out is the bar's close button, which is what made selection mode feel
/// like a trap.
class SelectableListScope extends StatelessWidget {
  final SelectionController controller;

  /// Ids Ctrl/Cmd-A should check, already filtered to selectable rows.
  final List<String> selectableIds;

  final Widget child;

  const SelectableListScope({
    super.key,
    required this.controller,
    required this.selectableIds,
    required this.child,
  });

  /// True when the platform's multi-select modifier is held: Cmd on macOS,
  /// Control elsewhere.
  static bool isModifierPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return keys.contains(LogicalKeyboardKey.metaLeft) ||
          keys.contains(LogicalKeyboardKey.metaRight);
    }
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight);
  }

  /// True when either shift key is held, for range extension.
  static bool isShiftPressed() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, state, _) {
        return PopScope(
          canPop: !state.isActive,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) controller.exit();
          },
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () {
                if (controller.value.isActive) controller.exit();
              },
              const SingleActivator(LogicalKeyboardKey.keyA, control: true):
                  () => controller.selectAll(selectableIds),
              const SingleActivator(LogicalKeyboardKey.keyA, meta: true): () =>
                  controller.selectAll(selectableIds),
            },
            child: Focus(autofocus: true, child: child),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/shared/selection/selectable_list_scope_test.dart`
Expected: PASS, 4 tests.

If the back test fails because `handlePopRoute` is not available on the installed
Flutter version, replace that test with one that pumps a `PopScope` ancestor and
asserts `canPop` is false while the mode is active. Do not delete the assertion.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/shared/selection test/shared/selection
flutter analyze lib/shared/selection test/shared/selection
git add lib/shared/selection/selectable_list_scope.dart test/shared/selection/selectable_list_scope_test.dart
git commit -m "feat(selection): add Escape, Ctrl/Cmd-A and back handling"
```

---

### Task 9: The shared selection contract test

**Files:**
- Create: `test/helpers/selection_contract.dart`

**Interfaces:**
- Consumes: everything from Tasks 1-8.
- Produces:
  `Future<void> verifySelectionContract(WidgetTester tester, {required Widget Function() build, required Finder selectButton, required Finder firstRow, required Future<void> Function(WidgetTester) applyFilter, required int visibleAfterFilter})`

- [ ] **Step 1: Write the helper**

There is no failing-test step here: this file *is* test infrastructure, and Task 10
is what first exercises it. Create `test/helpers/selection_contract.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Asserts the app-wide selection contract against one surface.
///
/// Every selectable list and grid calls this, so a regression on any single
/// page fails loudly instead of drifting the way the hand-written per-page
/// implementations did.
///
/// [build] returns a fully wired widget for the surface under test.
/// [selectButton] finds the surface's Select affordance.
/// [firstRow] finds the first selectable row.
/// [applyFilter] narrows the surface so pruning can be observed, leaving
/// [visibleAfterFilter] rows on screen.
Future<void> verifySelectionContract(
  WidgetTester tester, {
  required Widget Function() build,
  required Finder selectButton,
  required Finder firstRow,
  required Future<void> Function(WidgetTester tester) applyFilter,
  required int visibleAfterFilter,
}) async {
  // The Select affordance is visible without any hidden gesture.
  await tester.pumpWidget(build());
  await tester.pumpAndSettle();
  expect(
    selectButton,
    findsOneWidget,
    reason: 'surface must expose a visible Select affordance',
  );

  // Tapping it enters the mode with nothing checked, and checkboxes appear.
  await tester.tap(selectButton);
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('selection_exit')),
    findsOneWidget,
    reason: 'tapping Select must enter selection mode',
  );
  expect(
    find.byType(Checkbox),
    findsWidgets,
    reason: 'selection mode must render checkboxes in the leading slot',
  );

  // Select all, then deselect all, drive the count.
  await tester.tap(find.byKey(const ValueKey('selection_select_all')));
  await tester.pumpAndSettle();
  final selectAllCount = _checkedCount(tester);
  expect(
    selectAllCount,
    greaterThan(0),
    reason: 'select all must check at least one row',
  );

  await tester.tap(find.byKey(const ValueKey('selection_deselect_all')));
  await tester.pumpAndSettle();
  expect(
    _checkedCount(tester),
    0,
    reason: 'deselect all must clear every checkbox',
  );
  expect(
    find.byKey(const ValueKey('selection_exit')),
    findsOneWidget,
    reason: 'an explicitly entered mode must survive deselect all',
  );

  // Tapping a row toggles it.
  await tester.tap(firstRow);
  await tester.pumpAndSettle();
  expect(
    _checkedCount(tester),
    1,
    reason: 'tapping a row in selection mode must check it',
  );

  // Escape exits.
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('selection_exit')),
    findsNothing,
    reason: 'Escape must exit selection mode',
  );

  // Filtering prunes the selection to what remains visible.
  await tester.tap(selectButton);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('selection_select_all')));
  await tester.pumpAndSettle();

  await applyFilter(tester);
  await tester.pumpAndSettle();
  expect(
    _checkedCount(tester),
    lessThanOrEqualTo(visibleAfterFilter),
    reason: 'filtering must prune checked ids that left the visible set',
  );
}

int _checkedCount(WidgetTester tester) {
  return tester
      .widgetList<Checkbox>(find.byType(Checkbox))
      .where((c) => c.value == true)
      .length;
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze test/helpers/selection_contract.dart`
Expected: no issues. The helper is not invoked until Task 15.

- [ ] **Step 3: Commit**

```bash
dart format test/helpers/selection_contract.dart
git add test/helpers/selection_contract.dart
git commit -m "test(selection): add the shared selection contract helper"
```

---

### Task 10: Dive tiles gain two independent state channels

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_item.dart`
- Modify: `lib/features/dive_log/presentation/widgets/compact_dive_list_tile.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart` (`DiveListTile`)
- Test: `test/features/dive_log/presentation/widgets/dive_list_item_channels_test.dart`

**Interfaces:**
- Consumes: `SelectionLeading` (Task 6).
- Produces: `DiveListItem`, `CompactDiveListTile` and `DiveListTile` all take
  `bool isSelectionMode`, `bool isChecked`, `bool isHighlighted` — replacing the
  overloaded `isSelected`.

Before writing code, read all three files and every call site of `DiveListItem`
(`dive_list_content.dart`, `recent_dives_card.dart`, `trip_story_day_card.dart`) so
the rename is complete rather than partial.

- [ ] **Step 1: Write the failing test**

Create
`test/features/dive_log/presentation/widgets/dive_list_item_channels_test.dart`.
Model the provider setup on the existing
`test/features/dive_log/presentation/widgets/dive_list_selection_test.dart` — read
it first and reuse its `summary()` builder and `mock_providers.dart` helpers rather
than inventing new fakes.

```dart
// Imports: mirror dive_list_selection_test.dart, plus:
// import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';

  group('DiveListItem state channels', () {
    testWidgets('checked and highlighted render together and differ', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildItem(isSelectionMode: true, isChecked: true, isHighlighted: true),
      );
      await tester.pumpAndSettle();

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue, reason: 'checked renders as a checkbox');
      expect(
        find.byKey(const ValueKey('dive_row_highlight')),
        findsOneWidget,
        reason: 'highlight renders on its own channel, not as the checkbox',
      );
    });

    testWidgets('highlighted alone shows no checkbox outside selection mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildItem(isSelectionMode: false, isChecked: false, isHighlighted: true),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Checkbox), findsNothing);
      expect(find.byKey(const ValueKey('dive_row_highlight')), findsOneWidget);
    });

    testWidgets('checked alone shows no highlight stripe', (tester) async {
      await tester.pumpWidget(
        buildItem(isSelectionMode: true, isChecked: true, isHighlighted: false),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      expect(find.byKey(const ValueKey('dive_row_highlight')), findsNothing);
    });
  });
```

Write a local `buildItem({required bool isSelectionMode, required bool isChecked,
required bool isHighlighted})` helper in the test that wraps `DiveListItem` in the
same `ProviderScope` and `MaterialApp` setup the existing selection test uses.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_item_channels_test.dart`
Expected: FAIL — `No named parameter with the name 'isChecked'`.

- [ ] **Step 3: Rename and split the channels**

In `dive_list_item.dart`:

- Rename the field `isSelected` to `isChecked` and update the constructor.
- Delete the `resolvedSelected` computation at lines 94-96 entirely. It folded
  highlight into checked, which is exactly the conflation being removed.
- Pass `isChecked: isChecked` and `isHighlighted: isHighlighted` through to both
  `CompactDiveListTile` and `DiveListTile`.

In `compact_dive_list_tile.dart` and `DiveListTile` in `dive_list_page.dart`:

- Rename the `isSelected` parameter to `isChecked`.
- Add a `bool isHighlighted = false` parameter.
- Replace the hand-rolled `Checkbox` in the leading slot with:

```dart
SelectionLeading(
  isSelectionMode: isSelectionMode,
  isChecked: isChecked,
  onChanged: (_) => onTap?.call(),
  child: <the tile's existing leading widget>,
)
```

- Render the highlight on its own channel by wrapping the tile's root container
  with a leading-edge stripe, keyed so tests can find it:

```dart
Container(
  key: isHighlighted ? const ValueKey('dive_row_highlight') : null,
  decoration: isHighlighted
      ? BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
          ),
        )
      : null,
  child: <existing tile body>,
)
```

- The checked background tint stays on the existing selected-background code path,
  now driven by `isChecked` instead of `resolvedSelected`.

Update all three `DiveListItem` call sites. In `recent_dives_card.dart` and
`trip_story_day_card.dart` — read-only lists that never enter selection mode — pass
the previous `isSelected` value as `isHighlighted`, since that is what it meant
there.

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/features/dive_log/presentation/widgets/dive_list_item_channels_test.dart
flutter test test/features/dive_log/
flutter test test/features/trips/ test/features/home/
```
Expected: PASS. Existing tests that passed `isSelected:` must be updated to the new
names as part of this task.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib test
flutter analyze
git add lib test
git commit -m "refactor(dives): split isSelected into isChecked and isHighlighted"
```

---

### Task 11: Dives adopts SelectionController

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`

**Interfaces:**
- Consumes: `SelectionController` (Tasks 1-3), `SelectableListScope` (Task 8).
- Produces: `_DiveListContentState` holds a `SelectionController _selection` in
  place of `_isSelectionMode`, `_selectedIds` and `_anchorId`.

- [ ] **Step 1: Write the failing test**

Add to `test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`:

```dart
    testWidgets('changing the search query prunes the selection', (
      tester,
    ) async {
      // Build the dive list with three dives whose site names differ, enter
      // selection mode by long-press, check all three, then type a query that
      // matches only one. Assert exactly one checkbox remains checked.
      //
      // Reuse this file's existing pump helper and provider overrides rather
      // than writing new ones.
    });
```

Replace the comment with a concrete body following the pumping pattern already used
by the two tests in this file.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`
Expected: FAIL — all three stay checked, because nothing prunes today.

- [ ] **Step 3: Replace the local state machine**

In `_DiveListContentState`:

- Delete the fields `_isSelectionMode`, `_selectedIds`, `_selectionFromList` is
  unrelated and stays, and `_anchorId`.
- Add `final SelectionController _selection = SelectionController();` and dispose it
  in `dispose()` alongside `_scrollController`.
- Delete `_enterSelectionMode`, `_exitSelectionMode`, `_toggleSelection`,
  `_isShiftPressed`, `_selectRangeTo`, `_selectAll`, `_deselectAll`, and the
  top-level `rangeIds` function at lines 43-49. `idsInRange` in the shared package
  replaces `rangeIds`.
- Keep `inDateRange` — it is dive-specific and still used by the date-range action.
- Replace every read of `_isSelectionMode` with `_selection.value.isActive`, and
  every read of `_selectedIds` with `_selection.value.checkedIds`.
- Where `_enterSelectionMode(id)` was called from a long-press, call
  `_selection.enterImplicit(id)`. Preserve the existing side effect of clearing
  `highlightedDiveIdProvider` when entering.
- Wrap the built subtree in `SelectableListScope(controller: _selection,
  selectableIds: <visible dive ids>, child: ...)`.
- After the dive list rebuilds, call `_selection.pruneTo(visibleIds)` from a
  post-frame callback so pruning follows filter, search and sort changes.
- Rebuild on selection changes by wrapping the list and bar in a
  `ValueListenableBuilder(valueListenable: _selection, ...)`.

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/features/dive_log/presentation/widgets/dive_list_selection_test.dart
flutter test test/features/dive_log/
```
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib test
flutter analyze
git add lib test
git commit -m "refactor(dives): move selection state into SelectionController"
```

---

### Task 12: Dives adopts SelectionAppBar

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`

**Interfaces:**
- Consumes: `SelectionAppBar`, `SelectionBarShell`, `BulkAction` (Tasks 5, 7).
- Produces: `List<BulkAction> _bulkActions(List<DiveSummary> dives)` on
  `_DiveListContentState`.

- [ ] **Step 1: Write the failing test**

Add to `dive_list_selection_test.dart`:

```dart
    testWidgets('the pane shell offers the same actions as the full bar', (
      tester,
    ) async {
      // Pump DiveListContent twice: once with showAppBar: true and once with
      // showAppBar: false. Enter selection mode and check two dives in each.
      // Collect the set of action ids reachable inline plus in the overflow
      // menu, and assert the two sets are equal.
      //
      // This is the regression guard for the bug where the pane variant
      // permanently dropped combine, compare and export.
    });
```

Replace the comment with a concrete body.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`
Expected: FAIL — the two action sets differ.

- [ ] **Step 3: Replace both bar builders**

- Delete `_buildSelectionAppBar` and `_buildSelectionBar` and
  `_buildSelectionOverflowMenu`.
- Add:

```dart
  /// Dive-specific extras. The baseline select-all, deselect-all and delete
  /// controls come from SelectionAppBar, so they are deliberately absent here.
  List<BulkAction> _bulkActions(List<DiveSummary> dives) {
    final count = _selection.value.count;
    return [
      BulkAction(
        id: 'combine',
        icon: Icons.merge_type,
        label: context.l10n.diveLog_combine_action,
        minCount: 2,
        onInvoke: _combineSelected,
      ),
      BulkAction(
        id: 'compare3d',
        icon: Icons.view_in_ar,
        label: context.l10n.diveLog_compare3d_action,
        minCount: 2,
        onInvoke: _compareSelectedIn3D,
      ),
      BulkAction(
        id: 'export',
        icon: Icons.ios_share,
        label: context.l10n.diveLog_export_action,
        onInvoke: _showExportSheet,
      ),
      BulkAction(
        id: 'bulk_edit',
        icon: Icons.edit_outlined,
        label: context.l10n.diveLog_bulkEdit_action,
        onInvoke: _bulkEditSelected,
      ),
      BulkAction(
        id: 'date_range',
        icon: Icons.date_range,
        label: context.l10n.diveLog_selectByDateRange_action,
        minCount: 0,
        onInvoke: () => _selectByDateRange(dives),
      ),
    ];
  }
```

Use the l10n keys that already back the existing buttons; read the deleted builders
to find their exact names rather than guessing. `count` is available if an action
needs it for its label.

`date_range` is declared `alwaysEnabled: true` rather than with a `minCount`,
because it operates on the visible list rather than on the current selection and is
legitimately useful with nothing checked. The flag is defined in Task 5.

- Render the bar in both shells from one call:

```dart
  PreferredSizeWidget? _selectionAppBar(List<DiveSummary> dives) {
    if (!_selection.value.isActive) return null;
    return SelectionAppBar(
      controller: _selection,
      selectableIds: dives.map((d) => d.id).toList(),
      actions: _bulkActions(dives),
      shell: SelectionBarShell.appBar,
      onDelete: _confirmAndDelete,
    );
  }
```

and the `SelectionBarShell.pane` equivalent where the compact bar used to render.

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/shared/selection/
flutter test test/features/dive_log/
```
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib test
flutter analyze
git add lib test
git commit -m "refactor(dives): render selection chrome via SelectionAppBar"
```

---

### Task 13: The discoverable Select button

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`

**Interfaces:**
- Consumes: Tasks 11-12.
- Produces: an `IconButton` keyed `ValueKey('enter_selection')` in both the full and
  compact app bars.

- [ ] **Step 1: Write the failing test**

```dart
    testWidgets('a visible Select button enters selection mode', (tester) async {
      // Pump the dive list without any gesture. Assert
      // find.byKey(const ValueKey('enter_selection')) finds one widget, tap it,
      // and assert the selection bar appears with zero selected.
    });

    testWidgets('Select then deselect all keeps the mode active', (
      tester,
    ) async {
      // Tap Select, tap select-all, tap deselect-all, and assert the selection
      // bar is still present. This is the explicit-entry rule.
    });
```

Replace the comments with concrete bodies.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`
Expected: FAIL — no widget with that key.

- [ ] **Step 3: Add the button**

In both `_buildAppBar` and `_buildCompactAppBar`, immediately before the existing
overflow `PopupMenuButton`, add:

```dart
IconButton(
  key: const ValueKey('enter_selection'),
  icon: const Icon(Icons.checklist),
  tooltip: context.l10n.common_selection_enterTooltip,
  onPressed: _selection.enterExplicit,
),
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib test
flutter analyze
git add lib test
git commit -m "feat(dives): add a discoverable Select button to the app bar"
```

---

### Task 14: Modifier-click and range selection in list and table modes

**Files:**
- Modify: `lib/features/dive_log/presentation/widgets/dive_list_content.dart`
- Modify: `lib/features/dive_log/presentation/widgets/dive_table_view.dart`
- Test: `test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`

**Interfaces:**
- Consumes: `SelectableListScope.isModifierPressed`,
  `SelectableListScope.isShiftPressed` (Task 8), `SelectionController.extendTo`
  (Task 2).
- Produces: `void _handleRowTap(String id, List<DiveSummary> dives)` on
  `_DiveListContentState`, used by both the list tiles and the table view.

This task also fixes the defect at `dive_list_content.dart:1308`, where table mode
passed `const []` so select-all and select-by-date-range silently did nothing.

- [ ] **Step 1: Write the failing test**

```dart
    testWidgets('ctrl-click enters selection mode and checks the row', (
      tester,
    ) async {
      // With the list pumped and NOT in selection mode, hold controlLeft, tap
      // the second dive row, release. Assert the selection bar appears with
      // one selected.
    });

    testWidgets('shift-click ranges from the highlighted row', (tester) async {
      // Tap dive 1 normally so it becomes highlighted. Hold shiftLeft, tap
      // dive 3, release. Assert three checkboxes are checked.
    });

    testWidgets('table mode select-all checks every visible dive', (
      tester,
    ) async {
      // Pump with ListViewMode.table, enter selection mode, tap select-all,
      // and assert the checked count equals the number of dives, not zero.
      // Regression guard for the empty-list defect.
    });
```

Replace the comments with concrete bodies.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`
Expected: FAIL on all three.

- [ ] **Step 3: Implement**

Add the shared tap handler:

```dart
  /// One tap policy for every dive row, in every view mode.
  ///
  /// Outside selection mode a modifier turns a tap into an implicit entry, so
  /// desktop users never need to discover long-press.
  void _handleRowTap(String id, List<DiveSummary> dives) {
    final orderedIds = dives.map((d) => d.id).toList();

    if (SelectableListScope.isShiftPressed()) {
      _selection.extendTo(
        id,
        orderedIds,
        fallbackAnchorId: ref.read(highlightedDiveIdProvider),
      );
      return;
    }
    if (SelectableListScope.isModifierPressed()) {
      _selection.enterImplicit(id);
      return;
    }
    if (_selection.value.isActive) {
      _selection.toggle(id);
      return;
    }
    _openDive(id);
  }
```

Replace the existing inline tap logic in the card, compact, dense and table branches
with calls to `_handleRowTap`. Keep table mode's double-tap-to-open behavior; only
its single-tap path routes through the handler.

At line 1308, pass the real dive list instead of `const []` so the pane bar receives
the same `selectableIds` as the full bar. With Task 12 in place this is a single
argument change.

In `dive_table_view.dart`, replace the row's `onTap` plumbing so it forwards the
dive id to the same handler, and remove its private checkbox column in favor of
`SelectionLeading`.

- [ ] **Step 4: Run tests to verify they pass**

```bash
flutter test test/features/dive_log/
flutter test test/shared/selection/
```
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib test
flutter analyze
git add lib test
git commit -m "feat(dives): add modifier-click selection and fix table-mode select-all"
```

---

### Task 15: Run the contract against Dives

**Files:**
- Modify: `test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`

**Interfaces:**
- Consumes: `verifySelectionContract` (Task 9), the converted dive list
  (Tasks 10-14).
- Produces: nothing new. This task proves the contract helper works before four more
  surfaces adopt it in the next plan.

- [ ] **Step 1: Add the contract test**

```dart
    testWidgets('satisfies the shared selection contract', (tester) async {
      await verifySelectionContract(
        tester,
        build: () => buildDiveList(dives: [
          summary('a', DateTime(2026, 1, 1)),
          summary('b', DateTime(2026, 2, 1)),
          summary('c', DateTime(2026, 3, 1)),
        ]),
        selectButton: find.byKey(const ValueKey('enter_selection')),
        firstRow: find.text('a').first,
        applyFilter: (tester) async {
          // Enter a search query that matches exactly one of the three dives,
          // using this file's existing search plumbing.
        },
        visibleAfterFilter: 1,
      );
    });
```

Use whatever the file's existing list-building helper is actually called; read it
first. Replace the `applyFilter` comment with a concrete body.

- [ ] **Step 2: Run it**

Run: `flutter test test/features/dive_log/presentation/widgets/dive_list_selection_test.dart`
Expected: PASS. If any assertion inside the helper fails, the defect is in the Dives
conversion or in the helper's assumptions — fix the cause, do not weaken the
assertion.

- [ ] **Step 3: Run the full suite**

```bash
dart format .
flutter analyze
flutter test
```
Expected: no formatting changes, no analyzer output, all tests pass.

- [ ] **Step 4: Commit**

```bash
git add test
git commit -m "test(dives): assert the shared selection contract"
```

---

## Definition of Done

- `dart format .` produces no changes.
- `flutter analyze` is silent.
- `flutter test` passes in full.
- The Dives list can be put into selection mode without a long-press, on every
  view mode including table.
- Escape, Ctrl/Cmd-A, Ctrl/Cmd-click, shift-click and Android back all behave as the
  contract specifies.
- The pane and full-width selection bars offer identical action sets.
- `verifySelectionContract` passes against Dives.

## Follow-up plans

- **Phase 3:** convert Sites, Buddies, Tags and Dive media; each ends with a
  `verifySelectionContract` call.
- **Phases 4-5:** extend to Trips, Equipment, Courses, Certifications, Dive centers,
  then Devices, Service kinds, Cylinder configs, Species, Media storage.
- **Partial-failure reporting.** The spec requires bulk actions to report which
  items survived a partial failure and keep the failures checked for retry. Dives
  already has undoable bulk delete, and no current repository surfaces per-item
  failure, so this needs a repository-level change first. Deliberately deferred out
  of this plan rather than dropped.
- **Phase 6:** wire or delete `TableModeLayout`'s unused selection API, delete
  `DenseDiveListTile`, correct `codemaps/frontend.md:234`, and register the Escape
  and Ctrl/Cmd-A entries in `app_shortcuts.dart` so the shortcuts help dialog stops
  advertising a binding that does not exist.
