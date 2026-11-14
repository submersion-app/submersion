import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/unlock_editing_flag.dart';

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

RecordEditController<_Rec> _controller({
  Future<void> Function(EditSession<_Rec> session)? onSave,
}) {
  final controller = RecordEditController<_Rec>(onSave: onSave ?? (_) async {});
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  test('the switch is off unless the build turns it on', () {
    expect(kUnlockEditing, isFalse);
  });

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
  test('more changes on a card already changed do not notify again', () {
    final controller = _controller()..unlock(const _Rec(notes: 'a'));
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
}
