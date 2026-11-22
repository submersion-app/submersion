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
  List<String> Function(EditSession<_Rec> session)? invalidCards,
}) {
  final controller = RecordEditController<_Rec>(
    onSave: onSave ?? (_) async {},
    invalidCards: invalidCards,
  );
  addTearDown(controller.dispose);
  return controller;
}

/// What a sitting does with its cards: values one card owns and another
/// shows, the layout held while a card is open, unreadable input, a save
/// in progress, and asking for a card to be shown.
void main() {
  // A card that is not open shows the page's copy of the record. If it
  // shows a value another card owns, typing there has to redraw it.
  group('a value shown on a card that does not own it', () {
    final shared = EditField<_Rec, int>(
      id: 'shared',
      cardId: 'details',
      alsoShownOn: const {'summary'},
      read: (r) => r.depth,
      write: (r, v) => r.copyWith(depth: v),
    );

    test('typing it notifies while the card that shows it is closed', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('details');
      var told = 0;
      controller.addListener(() => told++);

      controller.session!.set(shared, 1);
      controller.session!.set(shared, 12);
      controller.session!.set(shared, 123);

      expect(told, 3);
    });

    test('with both cards open nothing is owed to the page', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('details')
        ..openCard('summary');
      controller.session!.set(shared, 1);
      var told = 0;
      controller.addListener(() => told++);

      controller.session!.set(shared, 12);

      expect(told, 0);
    });
  });

  // Which cards the page shows depends on what the record holds. Typing can
  // change that, and a card must not appear above an editor and push it
  // down the page. So the page lays itself out from the record as it was
  // when the first card opened, until every card is closed again.
  group('the record the page is laid out from', () {
    test('is none while no card is open', () {
      final controller = _controller()..unlock(const _Rec(notes: 'a'));
      controller.session!.set(_notes, 'b');

      expect(controller.layoutRecord, isNull);
    });

    test('is the working record as the first card opened', () {
      final controller = _controller()..unlock(const _Rec(notes: 'a'));
      controller.session!.set(_notes, 'b');

      controller.openCard('notes');
      controller.session!
        ..set(_notes, 'c')
        ..set(_depth, 9);

      expect(controller.layoutRecord, const _Rec(notes: 'b'));
    });

    test('is kept while any card stays open, and dropped with the last', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('notes');
      controller.session!.set(_notes, 'b');

      controller.openCard('details');
      expect(controller.layoutRecord, const _Rec(), reason: 'not retaken');

      controller.closeCard('notes');
      expect(controller.layoutRecord, const _Rec());

      controller.closeCard('details');
      expect(controller.layoutRecord, isNull);
    });

    test('is taken for a card added from the strip, and dropped on lock', () {
      final controller = _controller()..unlock(const _Rec(notes: 'a'));

      controller.addCard('tags');
      expect(controller.layoutRecord, const _Rec(notes: 'a'));

      controller.lock();
      expect(controller.layoutRecord, isNull);
    });
  });

  // Text that is not a value ('1.2.3') never reaches the session, so the
  // controller is told about it and keeps the card that holds it open.
  group('unreadable input', () {
    test('an invalid card cannot be closed', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('notes')
        ..setFieldInvalid('notes', 'notes', invalid: true);

      controller.closeCard('notes');

      expect(controller.openCardIds, {'notes'});
      expect(controller.invalidCardIds, {'notes'});
      expect(controller.revealRequest!.cardId, 'notes');
    });

    test('a refused close names the unreadable field', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('details')
        ..setFieldInvalid('details', 'time', invalid: true)
        ..setFieldInvalid('details', 'depth', invalid: true);

      controller.closeCard('details');

      // The first field of the card that became unreadable.
      expect(controller.revealRequest!.cardId, 'details');
      expect(controller.revealRequest!.fieldId, 'time');
    });

    test('a refused save names the unreadable field', () async {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('notes')
        ..setFieldInvalid('notes', 'notes', invalid: true);

      await controller.save();

      expect(controller.revealRequest!.cardId, 'notes');
      expect(controller.revealRequest!.fieldId, 'notes');
    });

    test('an added card is asked for as a whole, with no field', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..addCard('tags');

      expect(controller.revealRequest!.cardId, 'tags');
      expect(controller.revealRequest!.fieldId, isNull);
    });

    test('a refused close notifies, so the card can scroll into view', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('notes')
        ..setFieldInvalid('notes', 'notes', invalid: true);
      var told = 0;
      controller.addListener(() => told++);

      controller.closeCard('notes');

      expect(told, 1);
    });

    test('other cards open and close while another card is unreadable', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('details')
        ..setFieldInvalid('details', 'depth', invalid: true)
        ..openCard('notes');

      expect(controller.openCardIds, {'details', 'notes'});

      controller.closeCard('notes');

      expect(controller.openCardIds, {'details'});
    });

    test('save is refused while a card is invalid', () async {
      var calls = 0;
      final controller = _controller(onSave: (_) async => calls++)
        ..unlock(const _Rec())
        ..openCard('notes');
      controller.session!.set(_notes, 'b');
      controller.setFieldInvalid('notes', 'notes', invalid: true);

      expect(await controller.save(), isFalse);

      expect(calls, 0);
      expect(controller.refusedForInvalidInput, isTrue);
      expect(controller.saveError, isNull);
      expect(controller.isSaving, isFalse);
      expect(controller.isUnlocked, isTrue);
      expect(controller.session!.valueOf(_notes), 'b');
      expect(controller.revealRequest!.cardId, 'notes');
    });

    test(
      'a refused save asks for the card that became invalid first',
      () async {
        final controller = _controller()
          ..unlock(const _Rec())
          ..openCard('notes')
          ..openCard('details')
          ..setFieldInvalid('details', 'depth', invalid: true)
          ..setFieldInvalid('notes', 'notes', invalid: true);

        await controller.save();

        expect(controller.revealRequest!.cardId, 'details');
      },
    );

    test('a card is valid again once every field of it is', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('details')
        ..setFieldInvalid('details', 'depth', invalid: true)
        ..setFieldInvalid('details', 'time', invalid: true)
        ..setFieldInvalid('details', 'depth', invalid: false);
      expect(controller.invalidCardIds, {'details'});

      controller.setFieldInvalid('details', 'time', invalid: false);
      expect(controller.invalidCardIds, isEmpty);

      controller.closeCard('details');
      expect(controller.openCardIds, isEmpty);
    });

    test('a save after the input is fixed goes through', () async {
      var calls = 0;
      final controller = _controller(onSave: (_) async => calls++)
        ..unlock(const _Rec())
        ..openCard('notes');
      controller.session!.set(_notes, 'b');
      controller.setFieldInvalid('notes', 'notes', invalid: true);
      await controller.save();

      controller.setFieldInvalid('notes', 'notes', invalid: false);

      expect(await controller.save(), isTrue);
      expect(calls, 1);
      expect(controller.refusedForInvalidInput, isFalse);
      expect(controller.isUnlocked, isFalse);
    });

    test(
      'a save that then fails is not reported as unreadable input',
      () async {
        var fail = true;
        final controller =
            _controller(
                onSave: (_) async {
                  if (fail) throw StateError('no');
                },
              )
              ..unlock(const _Rec())
              ..openCard('notes');
        controller.session!.set(_notes, 'b');
        controller.setFieldInvalid('notes', 'notes', invalid: true);
        await controller.save();
        controller.setFieldInvalid('notes', 'notes', invalid: false);

        expect(await controller.save(), isFalse);

        expect(controller.refusedForInvalidInput, isFalse);
        expect(controller.saveError, isA<StateError>());
        fail = false;
      },
    );

    test('lock forgets invalid input', () async {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('notes')
        ..setFieldInvalid('notes', 'notes', invalid: true);
      await controller.save();
      expect(controller.refusedForInvalidInput, isTrue);

      controller
        ..lock()
        ..unlock(const _Rec());

      expect(controller.invalidCardIds, isEmpty);
      expect(controller.refusedForInvalidInput, isFalse);
      expect(controller.revealRequest, isNull);
    });

    test('asking twice for the same card gives a new serial', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('notes')
        ..setFieldInvalid('notes', 'notes', invalid: true);

      controller.closeCard('notes');
      final first = controller.revealRequest!.serial;
      controller.closeCard('notes');

      expect(controller.revealRequest!.serial, greaterThan(first));
    });

    test('a serial is never reused by a later sitting', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('notes')
        ..setFieldInvalid('notes', 'notes', invalid: true);
      controller.closeCard('notes');
      final first = controller.revealRequest!.serial;

      controller
        ..lock()
        ..unlock(const _Rec())
        ..openCard('notes')
        ..setFieldInvalid('notes', 'notes', invalid: true);
      controller.closeCard('notes');

      expect(controller.revealRequest!.serial, greaterThan(first));
    });

    // A field reports from its text listener and from its dispose, where a
    // page rebuild is not allowed. Nothing on the page draws the mark.
    test('marking a field does not notify', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('notes');
      var told = 0;
      controller.addListener(() => told++);

      controller
        ..setFieldInvalid('notes', 'notes', invalid: true)
        ..setFieldInvalid('notes', 'notes', invalid: false);

      expect(told, 0);
    });

    test('nothing is marked while locked', () {
      final controller = _controller()
        ..setFieldInvalid('notes', 'notes', invalid: true);

      expect(controller.invalidCardIds, isEmpty);
    });
  });

  // The write takes a moment. Nothing about the sitting may move under it.
  // A card's own check, asked of every card at Save whether it is open or
  // not: a value another card changed can leave a closed card invalid.
  group('a card that fails its own check', () {
    List<String> negativeDepth(EditSession<_Rec> s) => [
      if (s.valueOf(_depth) < 0) 'details',
    ];

    test('save refuses while a closed card is invalid, opens it and asks '
        'for its reveal', () async {
      var saves = 0;
      final c = _controller(
        onSave: (_) async => saves++,
        invalidCards: negativeDepth,
      )..unlock(const _Rec());
      c.session!.set(_depth, -1);

      expect(await c.save(), isFalse);
      expect(saves, 0);
      expect(c.refusedForInvalidInput, isTrue);
      expect(c.openCardIds, contains('details'));
      expect(c.revealRequest?.cardId, 'details');
      expect(c.revealRequest?.fieldId, isNull);
      expect(c.isUnlocked, isTrue);
    });

    test('save goes through once the card is valid again', () async {
      var saves = 0;
      final c = _controller(
        onSave: (_) async => saves++,
        invalidCards: negativeDepth,
      )..unlock(const _Rec());
      c.session!.set(_depth, -1);
      await c.save();
      c.session!.set(_depth, 4);

      expect(await c.save(), isTrue);
      expect(saves, 1);
      expect(c.refusedForInvalidInput, isFalse);
    });

    test('Done refuses for a card whose own check fails', () {
      final c = _controller(invalidCards: negativeDepth)
        ..unlock(const _Rec())
        ..openCard('details');
      c.session!.set(_depth, -1);

      c.closeCard('details');

      expect(c.openCardIds, contains('details'));
      expect(c.revealRequest?.cardId, 'details');
    });

    test('Done closes a card whose check passes', () {
      final c = _controller(invalidCards: negativeDepth)
        ..unlock(const _Rec())
        ..openCard('notes');
      c.session!.set(_depth, -1);

      c.closeCard('notes');

      expect(c.openCardIds, isNot(contains('notes')));
    });

    test('work that lands while save waits for it is checked too', () async {
      var saves = 0;
      final c = _controller(
        onSave: (_) async => saves++,
        invalidCards: negativeDepth,
      )..unlock(const _Rec());
      final s = c.session!..set(_notes, 'x');
      final gate = Completer<void>();
      s.track(gate.future.then((_) => s.set(_depth, -1)));

      final saving = c.save();
      gate.complete();

      expect(await saving, isFalse);
      expect(saves, 0);
      expect(c.refusedForInvalidInput, isTrue);
      expect(c.isSaving, isFalse);
      expect(c.openCardIds, contains('details'));
      expect(s.isFrozen, isFalse);
    });

    test(
      'a record stored while save waited, then refused, is followed',
      () async {
        final c = _controller(invalidCards: negativeDepth)
          ..unlock(const _Rec(notes: 'old'));
        final s = c.session!..set(_depth, 3);
        final gate = Completer<void>();
        s.track(gate.future.then((_) => s.set(_depth, -1)));

        final saving = c.save();
        // A sync lands while the save waits: the sitting is kept frozen out
        // of it until the save is done.
        c.storedChanged(const _Rec(notes: 'synced'));
        gate.complete();

        expect(await saving, isFalse);
        expect(s.stored.notes, 'synced');
        expect(s.valueOf(_notes), 'synced');
        expect(s.valueOf(_depth), -1);
      },
    );

    test('onStart is told of each sitting as unlock starts it', () {
      final started = <EditSession<_Rec>>[];
      final c = RecordEditController<_Rec>(
        onSave: (_) async {},
        onStart: started.add,
      );
      addTearDown(c.dispose);

      c.unlock(const _Rec());
      c.unlock(const _Rec(depth: 2));

      expect(started, [same(c.session)]);
      c.lock();
      c.unlock(const _Rec(depth: 3));
      expect(started, hasLength(2));
      expect(started.last, same(c.session));
    });

    test('the page is told of the sitting even when onStart fails', () {
      var told = 0;
      final c = RecordEditController<_Rec>(
        onSave: (_) async {},
        onStart: (_) => throw StateError('no repository'),
      )..addListener(() => told++);
      addTearDown(c.dispose);

      expect(() => c.unlock(const _Rec()), throwsStateError);

      expect(c.isUnlocked, isTrue);
      expect(told, 1);
    });

    test('a sitting with no changes locks though a stored value fails a '
        'check: there is nothing to write', () async {
      var saves = 0;
      final c = _controller(
        onSave: (_) async => saves++,
        invalidCards: negativeDepth,
      )..unlock(const _Rec(depth: -1));

      expect(await c.save(), isTrue);
      expect(saves, 0);
      expect(c.refusedForInvalidInput, isFalse);
      expect(c.isUnlocked, isFalse);
    });

    test('with no invalidCards, save is as before', () async {
      var saves = 0;
      final c = _controller(onSave: (_) async => saves++)..unlock(const _Rec());
      c.session!.set(_depth, -1);

      expect(await c.save(), isTrue);
      expect(saves, 1);
    });
  });

  group('while a save is running', () {
    test('the sitting cannot change', () async {
      final gate = Completer<void>();
      String? written;
      final controller =
          _controller(
              onSave: (session) async {
                await gate.future;
                written = session.working.notes;
              },
            )
            ..unlock(const _Rec(notes: 'a'))
            ..openCard('notes');
      controller.session!.set(_notes, 'b');

      final saving = controller.save();
      expect(controller.isSaving, isTrue);
      expect(controller.session!.isFrozen, isTrue);
      controller.session!.set(_notes, 'typed during the save');
      gate.complete();

      expect(await saving, isTrue);
      expect(written, 'b');
    });

    test('cards cannot be opened, closed or added', () async {
      final gate = Completer<void>();
      final controller = _controller(onSave: (_) => gate.future)
        ..unlock(const _Rec(notes: 'a'))
        ..openCard('notes');
      controller.session!.set(_notes, 'b');
      final saving = controller.save();
      var told = 0;
      controller.addListener(() => told++);

      controller
        ..openCard('tags')
        ..addCard('details')
        ..closeCard('notes');

      expect(controller.openCardIds, {'notes'});
      expect(controller.addedCardIds, isEmpty);
      expect(told, 0);

      gate.complete();
      await saving;
    });

    // lock() discards a sitting. While its write is running that would
    // leave the write going with nothing tracking it, and let a new sitting
    // start underneath it.
    test('the sitting cannot be locked, nor another started', () async {
      final gate = Completer<void>();
      final controller = _controller(onSave: (_) => gate.future)
        ..unlock(const _Rec(notes: 'a'));
      controller.session!.set(_notes, 'b');
      final saving = controller.save();
      var told = 0;
      controller.addListener(() => told++);

      controller
        ..lock()
        ..unlock(const _Rec(notes: 'z'));

      expect(controller.isUnlocked, isTrue);
      expect(controller.isSaving, isTrue);
      expect(controller.session!.valueOf(_notes), 'b');
      expect(told, 0);

      gate.complete();
      expect(await saving, isTrue);
      expect(controller.isUnlocked, isFalse);
      expect(controller.isSaving, isFalse);
    });

    test('a save that fails gives the sitting back, editable', () async {
      final controller =
          _controller(onSave: (_) async => throw StateError('no'))
            ..unlock(const _Rec(notes: 'a'))
            ..openCard('notes');
      controller.session!.set(_notes, 'b');

      expect(await controller.save(), isFalse);

      expect(controller.session!.isFrozen, isFalse);
      controller.session!.set(_notes, 'c');
      expect(controller.session!.valueOf(_notes), 'c');
      controller.closeCard('notes');
      expect(controller.openCardIds, isEmpty);
    });

    // The sitting is frozen meanwhile, so it cannot follow the stored
    // record as it arrives. Given back, it must catch up, or the cards the
    // diver never touched would show what is no longer stored.
    test(
      'a save that fails catches up with what was stored meanwhile',
      () async {
        final gate = Completer<void>();
        final controller = _controller(
          onSave: (_) async {
            await gate.future;
            throw StateError('no');
          },
        )..unlock(const _Rec(notes: 'a', depth: 1));
        controller.session!.set(_notes, 'b');
        final saving = controller.save();

        controller.storedChanged(const _Rec(notes: 'a', depth: 7));
        gate.complete();
        expect(await saving, isFalse);

        expect(controller.session!.stored, const _Rec(notes: 'a', depth: 7));
        expect(controller.session!.working, const _Rec(notes: 'b', depth: 7));
      },
    );

    test(
      'what arrived during one save is not applied after a later one',
      () async {
        Completer<void>? gate = Completer<void>();
        var fail = false;
        final controller = _controller(
          onSave: (_) async {
            await gate?.future;
            if (fail) throw StateError('no');
          },
        )..unlock(const _Rec(notes: 'a', depth: 1));
        controller.session!.set(_notes, 'b');
        final first = controller.save();
        controller.storedChanged(const _Rec(notes: 'b', depth: 7));
        gate.complete();
        expect(await first, isTrue);

        gate = null;
        fail = true;
        controller.unlock(const _Rec(notes: 'b', depth: 9));
        controller.session!.set(_notes, 'c');
        expect(await controller.save(), isFalse);

        expect(controller.session!.stored, const _Rec(notes: 'b', depth: 9));
      },
    );
  });

  // A card brought in from the Add strip can land below the fold. The
  // controller asks for it to be shown, and its frame scrolls to it.
  group('asking for a card to be shown', () {
    test('addCard asks, with a serial that goes up each time', () {
      final controller = _controller()..unlock(const _Rec());
      expect(controller.revealRequest, isNull);

      controller.addCard('tags');
      final first = controller.revealRequest!;
      expect(first.cardId, 'tags');

      controller.addCard('details');

      expect(controller.revealRequest!.cardId, 'details');
      expect(controller.revealRequest!.serial, greaterThan(first.serial));
    });

    test('adding a card that is already there does not ask again', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..addCard('tags');
      final first = controller.revealRequest!.serial;

      controller.addCard('tags');

      expect(controller.revealRequest!.serial, first);
    });

    test('opening a card from its pencil does not ask', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..openCard('notes');

      expect(controller.revealRequest, isNull);
    });

    test('a request is withdrawn once it has been answered', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..addCard('tags');
      final serial = controller.revealRequest!.serial;
      var told = 0;
      controller.addListener(() => told++);

      controller.revealHandled(serial - 1);
      expect(controller.revealRequest, isNotNull, reason: 'not this one');

      controller.revealHandled(serial);

      expect(controller.revealRequest, isNull);
      expect(told, 0);
    });

    test('lock withdraws a request nobody answered', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..addCard('tags')
        ..lock();

      expect(controller.revealRequest, isNull);
    });

    test('a serial is never reused by a later sitting', () {
      final controller = _controller()
        ..unlock(const _Rec())
        ..addCard('tags');
      final first = controller.revealRequest!.serial;

      controller
        ..lock()
        ..unlock(const _Rec())
        ..addCard('tags');

      expect(controller.revealRequest!.serial, greaterThan(first));
    });
  });
}
