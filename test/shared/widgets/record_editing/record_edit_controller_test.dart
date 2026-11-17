import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

@immutable
class _Rec {
  const _Rec({this.notes = '', this.depth = 0});

  final String notes;
  final int depth;

  _Rec copyWith({String? notes, int? depth}) =>
      _Rec(notes: notes ?? this.notes, depth: depth ?? this.depth);

  @override
  bool operator ==(Object other) =>
      other is _Rec && other.notes == notes && other.depth == depth;

  @override
  int get hashCode => Object.hash(notes, depth);
}

final _notes = EditField<_Rec, String>(
  id: 'notes',
  cardId: 'notes',
  read: (r) => r.notes,
  write: (r, v) => r.copyWith(notes: v),
);

final _depth = EditField<_Rec, int>(
  id: 'depth',
  cardId: 'details',
  read: (r) => r.depth,
  write: (r, v) => r.copyWith(depth: v),
);

RecordEditController<_Rec> _controller({
  Future<void> Function(EditSession<_Rec> session)? onSave,
}) {
  final controller = RecordEditController<_Rec>(onSave: onSave ?? (_) async {});
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  test('starts locked with no session', () {
    final controller = _controller();

    expect(controller.isUnlocked, isFalse);
    expect(controller.session, isNull);
    expect(controller.isDirty, isFalse);
    expect(controller.isSaving, isFalse);
    expect(controller.saveError, isNull);
    expect(controller.openCardIds, isEmpty);
    expect(controller.addedCardIds, isEmpty);
  });

  test('unlock creates a clean session over the stored record', () {
    final controller = _controller();
    var told = 0;
    controller.addListener(() => told++);

    controller.unlock(const _Rec(notes: 'a'));

    expect(controller.isUnlocked, isTrue);
    expect(controller.session!.stored, const _Rec(notes: 'a'));
    expect(controller.isDirty, isFalse);
    expect(told, 1);
  });

  test('lock drops the session with its open and added cards', () {
    final controller = _controller()
      ..unlock(const _Rec())
      ..openCard('notes')
      ..addCard('tags');
    controller.session!.set(_notes, 'b');

    controller.lock();

    expect(controller.isUnlocked, isFalse);
    expect(controller.session, isNull);
    expect(controller.isDirty, isFalse);
    expect(controller.openCardIds, isEmpty);
    expect(controller.addedCardIds, isEmpty);
  });

  test('the controller notifies when the session changes', () {
    final controller = _controller()..unlock(const _Rec(notes: 'a'));
    var told = 0;
    controller.addListener(() => told++);

    controller.session!.set(_notes, 'b');

    expect(told, 1);
    expect(controller.isDirty, isTrue);
  });

  // A page rebuilds when its controller notifies. Typing must not do that
  // on every keystroke: only a change in which cards have changes does.
  // Typing happens in an open card, whose editor follows the session itself.
  test('more changes on an open card already changed do not notify again', () {
    final controller = _controller()
      ..unlock(const _Rec(notes: 'a'))
      ..openCard('notes');
    var told = 0;
    controller.addListener(() => told++);

    controller.session!.set(_notes, 'b');
    expect(told, 1);

    controller.session!.set(_notes, 'bc');
    controller.session!.set(_notes, 'bcd');
    expect(told, 1);

    controller.session!.set(_notes, 'a');
    expect(told, 2);
    expect(controller.isDirty, isFalse);
  });

  // A closed card shows the page's copy of the record. When a rule changes
  // it from outside (a weather fetch filling a pressure, a site choice), the
  // page has to draw it again even though it already carried a change.
  test('a change to a closed card that is already changed notifies', () {
    final controller = _controller()
      ..unlock(const _Rec())
      ..openCard('notes');
    controller.session!.set(_depth, 5);
    var told = 0;
    controller.addListener(() => told++);

    controller.session!.set(_depth, 6);

    expect(told, 1);
  });

  test('closing a card does not replay its own typing as a change', () {
    final controller = _controller()
      ..unlock(const _Rec())
      ..openCard('notes')
      ..openCard('details');
    controller.session!
      ..set(_depth, 5)
      ..set(_notes, 'b')
      ..set(_notes, 'bc')
      ..set(_notes, 'bcd');
    controller.closeCard('notes');
    var told = 0;
    controller.addListener(() => told++);

    // Typing in the card that is still open. Notes is closed now and was
    // typed in three times while open; closing it drew that, so nothing is
    // owed for it here.
    controller.session!.set(_depth, 6);

    expect(told, 0);
  });

  test('an open card changed from outside does not notify the page', () {
    final controller = _controller()
      ..unlock(const _Rec())
      ..openCard('details');
    controller.session!.set(_depth, 5);
    var told = 0;
    controller.addListener(() => told++);

    // Its editor follows the session itself.
    controller.session!.set(_depth, 6);

    expect(told, 0);
  });

  test('storedChanged notifies once when the stored record differs', () {
    final controller = _controller()..unlock(const _Rec(notes: 'a', depth: 1));
    var told = 0;
    controller.addListener(() => told++);

    controller.storedChanged(const _Rec(notes: 'a', depth: 1));
    expect(told, 0);

    controller.storedChanged(const _Rec(notes: 'a', depth: 2));
    expect(told, 1);
  });

  test('openCard and closeCard track the open cards', () {
    final controller = _controller()..unlock(const _Rec());

    controller.openCard('notes');
    expect(controller.openCardIds, {'notes'});

    controller.closeCard('notes');
    expect(controller.openCardIds, isEmpty);
  });

  test('cards cannot be opened or added while locked', () {
    final controller = _controller()
      ..openCard('notes')
      ..addCard('tags');

    expect(controller.openCardIds, isEmpty);
    expect(controller.addedCardIds, isEmpty);
  });

  test('addCard adds and opens; closing it unchanged removes it', () {
    final controller = _controller()..unlock(const _Rec());

    controller.addCard('tags');
    expect(controller.addedCardIds, {'tags'});
    expect(controller.openCardIds, {'tags'});

    controller.closeCard('tags');
    expect(controller.addedCardIds, isEmpty);
    expect(controller.openCardIds, isEmpty);
  });

  test('closing an added card that has a change keeps it added', () {
    final controller = _controller()
      ..unlock(const _Rec())
      ..addCard('notes');
    controller.session!.set(_notes, 'x');

    controller.closeCard('notes');

    expect(controller.addedCardIds, {'notes'});
    expect(controller.openCardIds, isEmpty);
  });

  test('save calls onSave once with the session, then locks', () async {
    final seen = <String>[];
    final controller = _controller(
      onSave: (session) async => seen.add(session.working.notes),
    )..unlock(const _Rec(notes: 'a'));
    controller.session!.set(_notes, 'b');

    expect(await controller.save(), isTrue);

    expect(seen, ['b']);
    expect(controller.isUnlocked, isFalse);
    expect(controller.isSaving, isFalse);
  });

  test('save while a save is running does nothing', () async {
    final gate = Completer<void>();
    var calls = 0;
    final controller = _controller(
      onSave: (_) {
        calls++;
        return gate.future;
      },
    )..unlock(const _Rec());
    controller.session!.set(_notes, 'b');

    final first = controller.save();
    final second = controller.save();
    expect(controller.isSaving, isTrue);
    gate.complete();

    expect(await first, isTrue);
    expect(await second, isFalse);
    expect(calls, 1);
  });

  test(
    'a failed save stays unlocked, keeps the changes and records the error',
    () async {
      final controller = _controller(
        onSave: (_) async => throw StateError('gone'),
      )..unlock(const _Rec());
      controller.session!.set(_notes, 'b');
      controller.openCard('notes');

      expect(await controller.save(), isFalse);

      expect(controller.isUnlocked, isTrue);
      expect(controller.session!.valueOf(_notes), 'b');
      expect(controller.openCardIds, {'notes'});
      expect(controller.saveError, isA<StateError>());
      expect(controller.isSaving, isFalse);
    },
  );

  test('the next save clears the last error', () async {
    var fail = true;
    final controller = _controller(
      onSave: (_) async {
        if (fail) throw StateError('gone');
      },
    )..unlock(const _Rec());
    controller.session!.set(_notes, 'b');
    await controller.save();
    expect(controller.saveError, isNotNull);

    fail = false;
    expect(await controller.save(), isTrue);

    expect(controller.saveError, isNull);
  });

  test('save with no changes locks without calling onSave', () async {
    var calls = 0;
    final controller = _controller(onSave: (_) async => calls++)
      ..unlock(const _Rec());

    expect(await controller.save(), isTrue);

    expect(calls, 0);
    expect(controller.isUnlocked, isFalse);
  });

  test('a controller disposed while saving finishes quietly', () async {
    final gate = Completer<void>();
    final controller = RecordEditController<_Rec>(onSave: (_) => gate.future)
      ..unlock(const _Rec());
    controller.session!.set(_notes, 'b');

    final saving = controller.save();
    controller.dispose();
    gate.complete();

    expect(await saving, isTrue);
  });

  // The page can go while its save is writing (a tap on the navigation
  // rail): the held writes still read the sitting, so it ends only once
  // the write has.
  test('a controller disposed while saving keeps the sitting until the write '
      'ends', () async {
    final gate = Completer<void>();
    late EditSession<_Rec> writing;
    var disposedDuringWrite = true;
    final controller = RecordEditController<_Rec>(
      onSave: (session) async {
        writing = session;
        await gate.future;
        disposedDuringWrite = session.isDisposed;
      },
    )..unlock(const _Rec());
    controller.session!.set(_notes, 'b');

    final saving = controller.save();
    controller.dispose();
    gate.complete();

    expect(await saving, isTrue);
    expect(disposedDuringWrite, isFalse);
    expect(writing.isDisposed, isTrue);
  });

  // Code review: the page can go before the write starts, while the save
  // still waits for tracked work; the sitting must still end.
  test('a controller disposed while a save waits for tracked work ends the '
      'sitting, and writes nothing', () async {
    var wrote = false;
    final controller = RecordEditController<_Rec>(
      onSave: (_) async => wrote = true,
    )..unlock(const _Rec());
    final session = controller.session!..set(_notes, 'b');
    final gate = Completer<void>();
    session.track(gate.future);

    final saving = controller.save();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    gate.complete();

    expect(await saving, isFalse);
    expect(wrote, isFalse);
    expect(session.isDisposed, isTrue);
  });

  test(
    'a controller disposed while a save fails ends the sitting after it',
    () async {
      final gate = Completer<void>();
      late EditSession<_Rec> writing;
      final controller = RecordEditController<_Rec>(
        onSave: (session) async {
          writing = session;
          await gate.future;
        },
      )..unlock(const _Rec());
      controller.session!.set(_notes, 'b');

      final saving = controller.save();
      controller.dispose();
      expect(writing.isDisposed, isFalse);
      gate.completeError(StateError('gone'));

      expect(await saving, isFalse);
      expect(writing.isDisposed, isTrue);
    },
  );

  test('a controller disposed while a save fails finishes quietly', () async {
    final gate = Completer<void>();
    final controller = RecordEditController<_Rec>(onSave: (_) => gate.future)
      ..unlock(const _Rec());
    controller.session!.set(_notes, 'b');

    final saving = controller.save();
    controller.dispose();
    gate.completeError(StateError('gone'));

    expect(await saving, isFalse);
  });

  test('save while locked does nothing', () async {
    var calls = 0;
    final controller = _controller(onSave: (_) async => calls++);

    expect(await controller.save(), isFalse);
    expect(calls, 0);
  });

  test('storedChanged rebases the session while unlocked', () {
    final controller = _controller()..unlock(const _Rec(notes: 'a', depth: 1));
    controller.session!.set(_notes, 'b');

    controller.storedChanged(const _Rec(notes: 'a', depth: 9));

    expect(controller.session!.working, const _Rec(notes: 'b', depth: 9));
  });

  test('storedChanged is ignored while locked', () {
    final controller = _controller();

    controller.storedChanged(const _Rec(notes: 'z'));

    expect(controller.isUnlocked, isFalse);
    expect(controller.session, isNull);
  });

  testWidgets('RecordEditScope hands the controller to its subtree', (
    tester,
  ) async {
    final controller = _controller();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RecordEditScope<_Rec>(
          controller: controller,
          child: Builder(
            builder: (context) {
              final found = RecordEditScope.maybeOf<_Rec>(context);
              return Text(found!.isUnlocked ? 'unlocked' : 'locked');
            },
          ),
        ),
      ),
    );
    expect(find.text('locked'), findsOneWidget);

    controller.unlock(const _Rec());
    await tester.pump();

    expect(find.text('unlocked'), findsOneWidget);
  });

  testWidgets('RecordEditScope.maybeOf is null with no scope above', (
    tester,
  ) async {
    RecordEditController<_Rec>? found;
    var built = false;

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          found = RecordEditScope.maybeOf<_Rec>(context);
          built = true;
          return const SizedBox.shrink();
        },
      ),
    );

    expect(built, isTrue);
    expect(found, isNull);
  });

  // Work the sitting started that a save depends on, such as the dive types
  // a picked site adds: the save writes what it brings (issue #4527, plan 4).
  test('save waits for tracked work before freezing', () async {
    _Rec? saved;
    final controller = _controller(
      onSave: (session) async => saved = session.working,
    )..unlock(const _Rec());
    final session = controller.session!..set(_notes, 'typed');
    final gate = Completer<void>();
    session.track(gate.future.then((_) => session.set(_depth, 12)));

    final saving = controller.save();
    await Future<void>.delayed(Duration.zero);
    expect(controller.isSaving, isTrue);
    expect(saved, isNull);

    gate.complete();
    expect(await saving, isTrue);
    expect(saved, const _Rec(notes: 'typed', depth: 12));
  });

  // Code review: a page that drew the sitting during the wait must hear
  // that it is now frozen, or it shows live controls through the write.
  test(
    'after waiting for tracked work, listeners hear the frozen sitting',
    () async {
      final writing = Completer<void>();
      final controller = _controller(onSave: (_) => writing.future)
        ..unlock(const _Rec());
      final session = controller.session!..set(_notes, 'typed');
      final gate = Completer<void>();
      session.track(gate.future);
      final frozenWhenTold = <bool>[];
      controller.addListener(() => frozenWhenTold.add(session.isFrozen));

      final saving = controller.save();
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future<void>.delayed(Duration.zero);

      expect(frozenWhenTold, contains(true));
      writing.complete();
      expect(await saving, isTrue);
    },
  );

  // Code review: tracked work that never answers must not hold the page
  // saving, with every input blocked, for ever.
  test('save stops waiting for tracked work after its time limit', () async {
    _Rec? saved;
    final controller = RecordEditController<_Rec>(
      onSave: (session) async => saved = session.working,
      trackedWorkTimeout: const Duration(milliseconds: 20),
    )..unlock(const _Rec());
    addTearDown(controller.dispose);
    controller.session!
      ..set(_notes, 'typed')
      ..track(Completer<void>().future);

    expect(await controller.save(), isTrue);
    expect(saved, const _Rec(notes: 'typed'));
  });

  test('a sitting whose only change is held is saved', () async {
    var saves = 0;
    final controller = _controller(onSave: (_) async => saves++)
      ..unlock(const _Rec());
    controller.session!.holdChange('k', cardId: 'header', write: () async {});

    expect(controller.isDirty, isTrue);
    expect(await controller.save(), isTrue);
    expect(saves, 1);
  });

  test('a sitting ended while its save waits is not saved', () async {
    var saves = 0;
    // Disposed by the test itself: the page went away mid-save.
    final controller = RecordEditController<_Rec>(onSave: (_) async => saves++)
      ..unlock(const _Rec());
    final session = controller.session!..set(_notes, 'typed');
    final gate = Completer<void>();
    session.track(gate.future);

    final saving = controller.save();
    await Future<void>.delayed(Duration.zero);
    controller.dispose();
    gate.complete();

    expect(await saving, isFalse);
    expect(saves, 0);
  });
}
