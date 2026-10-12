import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';

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
  expect(reloading.isLoading && reloading.hasValue, isTrue);
  return reloading;
}

/// A refresh that failed while holding its previous value, built the same
/// way as [_reloadingFrom].
Future<AsyncValue<List<String>>> _failedHolding(List<String> previous) async {
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
  container.read(rows);
  next.completeError(StateError('refresh failed'));
  await pumpEventQueue();
  final failed = container.read(rows);
  expect(failed.hasError && failed.hasValue, isTrue);
  return failed;
}

void main() {
  group('SelectionState', () {
    const base = SelectionState(
      checkedIds: {'a', 'b'},
      isActive: true,
      enteredExplicitly: true,
      anchorId: 'a',
    );

    // Equality gates every rebuild: ValueNotifier only notifies when the new
    // value differs, so a wrong == either spams rebuilds or swallows changes.
    test('compares checked ids by content, not identity', () {
      const other = SelectionState(
        checkedIds: {'b', 'a'},
        isActive: true,
        enteredExplicitly: true,
        anchorId: 'a',
      );
      expect(other, base);
      expect(other.hashCode, base.hashCode);
    });

    test('differs when any field differs', () {
      expect(base.copyWith(isActive: false), isNot(base));
      expect(base.copyWith(enteredExplicitly: false), isNot(base));
      expect(base.copyWith(anchorId: 'b'), isNot(base));
      expect(base.copyWith(checkedIds: {'a'}), isNot(base));
    });

    test('copyWith preserves untouched fields', () {
      final next = base.copyWith(checkedIds: {'c'});
      expect(next.checkedIds, {'c'});
      expect(next.isActive, isTrue);
      expect(next.enteredExplicitly, isTrue);
      expect(next.anchorId, 'a');
    });

    test('clearAnchor wins over an anchorId argument', () {
      expect(base.copyWith(anchorId: 'b', clearAnchor: true).anchorId, isNull);
    });

    test('exposes count and isChecked', () {
      expect(base.count, 2);
      expect(base.isChecked('a'), isTrue);
      expect(base.isChecked('z'), isFalse);
    });

    test('is not equal to an unrelated object', () {
      expect(base, isNot(equals('not a state')));
    });
  });

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

    test('enterImplicit checks the seed alongside the given id', () {
      final controller = SelectionController();
      controller.enterImplicit('c', seedId: 'a');
      expect(controller.value.checkedIds, {'a', 'c'});
      expect(
        controller.value.anchorId,
        'c',
        reason: 'the modifier-clicked row becomes the anchor, not the seed',
      );
      expect(controller.value.enteredExplicitly, isFalse);
    });

    test('enterImplicit ignores a seed equal to the id', () {
      final controller = SelectionController();
      controller.enterImplicit('a', seedId: 'a');
      expect(controller.value.checkedIds, {'a'});
    });

    test('enterImplicit ignores the seed once the mode is active', () {
      final controller = SelectionController();
      controller.enterImplicit('a');
      controller.enterImplicit('b', seedId: 'z');
      expect(controller.value.checkedIds, {'a', 'b'});
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

    test(
      'activates implicitly and checks the range from the fallback anchor',
      () {
        final controller = SelectionController();
        controller.extendTo('d', ordered, fallbackAnchorId: 'b');
        expect(controller.value.isActive, isTrue);
        expect(controller.value.enteredExplicitly, isFalse);
        expect(controller.value.checkedIds, {'b', 'c', 'd'});
        expect(controller.value.anchorId, 'b');
      },
    );

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
      // toggle moved the anchor to 'e', so the range runs e -> c and the
      // fallback anchor is ignored. 'a' survives because extendTo adds.
      controller.extendTo('c', ordered, fallbackAnchorId: 'b');
      expect(controller.value.checkedIds, {'a', 'c', 'd', 'e'});
    });

    test('ignores the fallback anchor once the controller has its own', () {
      final controller = SelectionController();
      controller.enterImplicit('d');
      controller.extendTo('e', ordered, fallbackAnchorId: 'a');
      expect(controller.value.checkedIds, {'d', 'e'});
    });

    test('ignores a target that is not in the visible list', () {
      final controller = SelectionController();
      controller.enterImplicit('a');
      controller.extendTo('zz', ordered);
      expect(controller.value.checkedIds, {'a'});
    });

    test('checks the target when the fallback anchor is stale', () {
      // The highlighted row can sit outside the visible list, for instance
      // after a filter change. The range is then empty, but shift-click must
      // still check the row the user actually clicked.
      final controller = SelectionController();
      controller.extendTo('c', ordered, fallbackAnchorId: 'gone');
      expect(controller.value.isActive, isTrue);
      expect(controller.value.checkedIds, {'c'});
      expect(controller.value.anchorId, 'c');
    });

    test('checks the target when the controller anchor is stale', () {
      final controller = SelectionController();
      controller.enterImplicit('a');
      // Simulate the visible list changing under a live selection.
      controller.extendTo('c', const ['c', 'd'], fallbackAnchorId: null);
      expect(controller.value.checkedIds, containsAll({'c'}));
      expect(controller.value.anchorId, 'c');
    });

    test('never activates with nothing checked', () {
      final controller = SelectionController();
      controller.extendTo('c', ordered, fallbackAnchorId: 'gone');
      expect(
        controller.value.count,
        greaterThan(0),
        reason: 'shift-click must never leave an empty active selection',
      );
    });
  });

  group('SelectionController bulk operations', () {
    test('selectAll activates explicitly and checks every selectable id', () {
      final controller = SelectionController();
      controller.selectAll(['a', 'b', 'c']);
      expect(controller.value.isActive, isTrue);
      expect(controller.value.enteredExplicitly, isTrue);
      expect(controller.value.checkedIds, {'a', 'b', 'c'});
    });

    test(
      'selectAll only checks the ids it is given, excluding disabled rows',
      () {
        final controller = SelectionController();
        controller.enterImplicit('a');
        // 'c' is non-selectable, so the surface omits it from the argument.
        controller.selectAll(['a', 'b']);
        expect(controller.value.checkedIds, {'a', 'b'});
      },
    );

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

  group('SelectionController.replaceChecked', () {
    test('activates implicitly when the mode was not already active', () {
      final controller = SelectionController();
      // A gesture layer that owns its own long-press cannot route through
      // enterImplicit, because it reports a whole set rather than one id.
      controller.replaceChecked(['b']);
      expect(controller.value.isActive, isTrue);
      expect(controller.value.enteredExplicitly, isFalse);
      expect(controller.value.checkedIds, {'b'});
      expect(controller.value.anchorId, 'b');
    });

    test('does not activate the mode on an empty set', () {
      final controller = SelectionController();
      controller.replaceChecked(const []);
      expect(controller.value.isActive, isFalse);
    });

    test('preserves an explicit entry, which selectAll would overwrite', () {
      final controller = SelectionController();
      controller.enterExplicit();
      controller.replaceChecked(['a', 'b']);
      expect(controller.value.enteredExplicitly, isTrue);
      expect(controller.value.checkedIds, {'a', 'b'});
    });

    test('preserves an implicit entry across further changes', () {
      final controller = SelectionController();
      controller.replaceChecked(['a']);
      controller.replaceChecked(['a', 'b']);
      expect(controller.value.enteredExplicitly, isFalse);
      expect(controller.value.checkedIds, {'a', 'b'});
    });

    test('keeps an explicit mode active when replaced with nothing', () {
      final controller = SelectionController();
      controller.enterExplicit();
      controller.replaceChecked(['a']);
      controller.replaceChecked(const []);
      expect(controller.value.isActive, isTrue);
      expect(controller.value.checkedIds, isEmpty);
    });

    test('ends an implicit mode when replaced with nothing', () {
      final controller = SelectionController();
      controller.replaceChecked(['a']);
      controller.replaceChecked(const []);
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
      // extendTo keeps the anchor on 'b' while also checking 'c', so pruning
      // 'b' away leaves a surviving selection with a stale anchor.
      controller.enterImplicit('b');
      controller.extendTo('c', ['a', 'b', 'c']);
      expect(controller.value.anchorId, 'b');

      controller.pruneTo(['a', 'c']);
      expect(controller.value.checkedIds, {'c'});
      expect(controller.value.anchorId, isNull);
    });

    test('ends an implicit mode when pruning empties the selection', () {
      final controller = SelectionController();
      controller.enterImplicit('b');
      controller.pruneTo(['a', 'c']);
      expect(controller.value.isActive, isFalse);
    });

    test(
      'keeps an explicit mode active when pruning empties the selection',
      () {
        final controller = SelectionController();
        controller.enterExplicit();
        controller.toggle('b');
        controller.pruneTo(['a', 'c']);
        expect(controller.value.isActive, isTrue);
        expect(controller.value.checkedIds, isEmpty);
      },
    );

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
  group('SelectionController.pruneToSettled', () {
    late SelectionController controller;
    setUp(() => controller = SelectionController()..selectAll(['a', 'b']));
    tearDown(() => controller.dispose());

    List<String> ids(List<String> rows) => rows;

    test('is settled before any rows are reported', () {
      expect(controller.rowsSettled.value, isTrue);
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

    test('an error holding its previous value prunes to that value', () async {
      final failed = await _failedHolding(['b']);
      controller.pruneToSettled(failed, ids);
      expect(controller.value.checkedIds, {'b'});
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

    test('derives no ids while the mode is inactive', () {
      final idle = SelectionController();
      addTearDown(idle.dispose);
      var derived = 0;
      idle.pruneToSettled(const AsyncLoading<List<String>>(), ids);
      idle.pruneToSettled(const AsyncData(['a']), (rows) {
        derived++;
        return rows;
      });
      expect(derived, 0);
      expect(idle.rowsSettled.value, isTrue);
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
}
