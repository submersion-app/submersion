import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// A small record, so these tests do not depend on any real entity.
@immutable
class _Rec {
  const _Rec({this.notes = '', this.tags = const [], this.depth = 0});

  final String notes;
  final List<String> tags;
  final int depth;

  _Rec copyWith({String? notes, List<String>? tags, int? depth}) => _Rec(
    notes: notes ?? this.notes,
    tags: tags ?? this.tags,
    depth: depth ?? this.depth,
  );

  @override
  bool operator ==(Object other) =>
      other is _Rec &&
      other.notes == notes &&
      listEquals(other.tags, tags) &&
      other.depth == depth;

  @override
  int get hashCode => Object.hash(notes, Object.hashAll(tags), depth);
}

final _notes = EditField<_Rec, String>(
  id: 'notes',
  cardId: 'notes',
  read: (r) => r.notes,
  write: (r, v) => r.copyWith(notes: v),
);

final _tags = EditField<_Rec, List<String>>(
  id: 'tags',
  cardId: 'tags',
  read: (r) => r.tags,
  write: (r, v) => r.copyWith(tags: v),
  equals: (a, b) => a.toSet().containsAll(b) && b.toSet().containsAll(a),
);

final _depth = EditField<_Rec, int>(
  id: 'depth',
  cardId: 'details',
  read: (r) => r.depth,
  write: (r, v) => r.copyWith(depth: v),
);

void main() {
  test('a new session is clean and working equals stored', () {
    const stored = _Rec(notes: 'a', depth: 10);
    final session = EditSession(stored);

    expect(session.stored, stored);
    expect(session.working, stored);
    expect(session.isDirty, isFalse);
    expect(session.changedCardIds, isEmpty);
    expect(session.valueOf(_notes), 'a');
  });

  test('set changes working, marks dirty and names the card', () {
    final session = EditSession(const _Rec(notes: 'a'));

    session.set(_notes, 'b');

    expect(session.working.notes, 'b');
    expect(session.stored.notes, 'a');
    expect(session.isDirty, isTrue);
    expect(session.changedCardIds, {'notes'});
    expect(session.valueOf(_notes), 'b');
  });

  test('changes on two cards are both named', () {
    final session = EditSession(const _Rec(notes: 'a', depth: 10))
      ..set(_notes, 'b')
      ..set(_depth, 20);

    expect(session.changedCardIds, {'notes', 'details'});
    expect(session.working, const _Rec(notes: 'b', depth: 20));
  });

  test('setting a value back to the stored one clears the change', () {
    final session = EditSession(const _Rec(notes: 'a'))
      ..set(_notes, 'b')
      ..set(_notes, 'a');

    expect(session.isDirty, isFalse);
    expect(session.changedCardIds, isEmpty);
    expect(session.working.notes, 'a');
  });

  test('equals decides sameness: tags in another order are not a change', () {
    final session = EditSession(const _Rec(tags: ['x', 'y']));

    session.set(_tags, ['y', 'x']);

    expect(session.isDirty, isFalse);

    session.set(_tags, ['y']);

    expect(session.isDirty, isTrue);
    expect(session.changedCardIds, {'tags'});
  });

  test('rebase: an untouched field follows the new stored record', () {
    final session = EditSession(const _Rec(notes: 'a', depth: 10))
      ..set(_notes, 'b');

    session.rebase(const _Rec(notes: 'a', depth: 25));

    expect(session.stored.depth, 25);
    expect(session.working.depth, 25);
    expect(session.working.notes, 'b');
    expect(session.isDirty, isTrue);
  });

  test('rebase: a pending change equal to the new stored value is dropped', () {
    final session = EditSession(const _Rec(notes: 'a'))..set(_notes, 'b');

    session.rebase(const _Rec(notes: 'b'));

    expect(session.isDirty, isFalse);
    expect(session.changedCardIds, isEmpty);
  });

  test('applyTo writes only the pending changes onto a fresh record', () {
    final session = EditSession(const _Rec(notes: 'a', depth: 10))
      ..set(_notes, 'b');

    final merged = session.applyTo(
      const _Rec(notes: 'a', depth: 99, tags: ['x']),
    );

    expect(merged.notes, 'b');
    expect(merged.depth, 99);
    expect(merged.tags, ['x']);
  });

  test('applyTo with no pending changes returns the fresh record as it is', () {
    final session = EditSession(const _Rec(notes: 'a'));
    const fresh = _Rec(notes: 'z', depth: 5);

    expect(session.applyTo(fresh), fresh);
  });

  test('listeners are told on a change and not on a no-op', () {
    final session = EditSession(const _Rec(notes: 'a'));
    var told = 0;
    session.addListener(() => told++);

    session.set(_notes, 'b');
    expect(told, 1);

    session.set(_notes, 'b');
    expect(told, 1);

    session.set(_notes, 'a');
    expect(told, 2);

    // Stored equals what it was and nothing is pending: nothing to tell.
    session.rebase(const _Rec(notes: 'a'));
    expect(told, 2);

    session.rebase(const _Rec(notes: 'a', depth: 3));
    expect(told, 3);
  });

  test('revisionOf counts changes to a card and ignores no-ops', () {
    final session = EditSession(const _Rec(notes: 'a'));
    expect(session.revisionOf('notes'), 0);

    session.set(_notes, 'b');
    session.set(_notes, 'b');
    session.set(_notes, 'c');

    expect(session.revisionOf('notes'), 2);
    expect(session.revisionOf('details'), 0);
  });

  test('revisionOf counts a change typed back to the stored value', () {
    final session = EditSession(const _Rec(notes: 'a'))
      ..set(_notes, 'b')
      ..set(_notes, 'a');

    expect(session.isDirty, isFalse);
    expect(session.revisionOf('notes'), 2);
  });

  // A sitting can owe a write to another record (the altitude a lookup
  // found, copied back to the site). It is held here and run by Save.
  group('held writes', () {
    test('run in the order first held, and a key replaces', () async {
      final ran = <String>[];
      final session = EditSession(const _Rec())
        ..holdWrite('site', () async => ran.add('site, first'))
        ..holdWrite('other', () async => ran.add('other'))
        ..holdWrite('site', () async => ran.add('site, second'));
      expect(session.hasHeldWrites, isTrue);

      await session.runHeldWrites();

      expect(ran, ['site, second', 'other']);
    });

    test('each is awaited before the next starts', () async {
      final ran = <String>[];
      final session = EditSession(const _Rec())
        ..holdWrite('slow', () async {
          await Future<void>.delayed(Duration.zero);
          ran.add('slow');
        })
        ..holdWrite('fast', () async => ran.add('fast'));

      await session.runHeldWrites();

      expect(ran, ['slow', 'fast']);
    });

    test('do not make the session dirty or notify', () {
      final session = EditSession(const _Rec());
      var told = 0;
      session
        ..addListener(() => told++)
        ..holdWrite('site', () async {});

      expect(session.isDirty, isFalse);
      expect(session.changedCardIds, isEmpty);
      expect(told, 0);
    });

    // A save that failed is tried again, and must write everything again.
    test('are kept after running, so a save can be retried', () async {
      var ran = 0;
      final session = EditSession(const _Rec())
        ..holdWrite('site', () async => ran++);

      await session.runHeldWrites();
      await session.runHeldWrites();

      expect(ran, 2);
      expect(session.hasHeldWrites, isTrue);
    });

    test('a failing write stops the rest and is rethrown', () async {
      final ran = <String>[];
      final session = EditSession(const _Rec())
        ..holdWrite('bad', () async => throw StateError('no'))
        ..holdWrite('after', () async => ran.add('after'));

      await expectLater(session.runHeldWrites(), throwsStateError);

      expect(ran, isEmpty);
    });

    test('none is taken while the session is frozen', () {
      final session = EditSession(const _Rec())..freeze();

      session.holdWrite('site', () async {});

      expect(session.hasHeldWrites, isFalse);
    });

    test('a session with none runs nothing', () async {
      final session = EditSession(const _Rec());

      expect(session.hasHeldWrites, isFalse);
      await session.runHeldWrites();
    });
  });

  // Work that outlives a card (a lookup, a fetch) asks before writing here.
  test('isDisposed turns true when the sitting ends', () {
    final session = EditSession(const _Rec());
    expect(session.isDisposed, isFalse);

    session.dispose();

    expect(session.isDisposed, isTrue);
  });

  // A sitting is frozen while it is being written, so what is saved is
  // what the diver saw when they tapped Save.
  test('a frozen session drops changes, and takes them again once thawed', () {
    final session = EditSession(const _Rec(notes: 'a'))..set(_notes, 'b');
    var told = 0;
    session
      ..addListener(() => told++)
      ..freeze();
    expect(session.isFrozen, isTrue);

    session
      ..set(_notes, 'late')
      ..set(_depth, 9);

    expect(session.valueOf(_notes), 'b');
    expect(session.changedCardIds, {'notes'});
    expect(told, 0);

    session
      ..thaw()
      ..set(_notes, 'c');

    expect(session.isFrozen, isFalse);
    expect(session.valueOf(_notes), 'c');
    expect(told, 1);
  });

  // A value can show on a card that does not own it: surface pressure is
  // edited on the Altitude card and shown on Environment too.
  test('a field shown on another card moves that card as well', () {
    final shared = EditField<_Rec, int>(
      id: 'shared',
      cardId: 'details',
      alsoShownOn: const {'summary'},
      read: (r) => r.depth,
      write: (r, v) => r.copyWith(depth: v),
    );
    final session = EditSession(const _Rec())..set(shared, 4);

    expect(session.revisionOf('details'), 1);
    expect(session.revisionOf('summary'), 1);
    expect(session.revisedCardIds, {'details', 'summary'});
    // Showing a value is not owning it: the change is still Details'.
    expect(session.changedCardIds, {'details'});
  });

  test('revisionOf is counted per card', () {
    final session = EditSession(const _Rec(notes: 'a'))
      ..set(_notes, 'b')
      ..set(_depth, 4)
      ..set(_depth, 5);

    expect(session.revisionOf('notes'), 1);
    expect(session.revisionOf('details'), 2);
  });

  // A card's editor is built anew each time the card opens. What it does
  // once in a sitting, it asks the sitting about.
  test('firstTime is true once for each key', () {
    final session = EditSession(const _Rec());

    expect(session.firstTime('lookup'), isTrue);
    expect(session.firstTime('lookup'), isFalse);
    expect(session.firstTime('another'), isTrue);
  });

  // A card's editor keeps its session for a frame after the sitting has
  // ended. A keystroke that arrives then is dropped, not thrown.
  test('a disposed session ignores what is set on it', () {
    final session = EditSession(const _Rec(notes: 'a'))..dispose();

    session
      ..set(_notes, 'late')
      ..rebase(const _Rec(notes: 'z'));

    expect(session.valueOf(_notes), 'a');
    expect(session.isDirty, isFalse);
  });

  // A write to another table can be the diver's change in its own right: a
  // dismissed suggestion, a location added to a site. No record value moves,
  // yet the sitting has something to save (issue #4527, plan 4).
  group('held changes', () {
    test('make the session dirty and name their card', () {
      final session = EditSession(const _Rec())
        ..holdChange('k', cardId: 'header', write: () async {});

      expect(session.isDirty, isTrue);
      expect(session.changedCardIds, {'header'});
      expect(session.isHeld('k'), isTrue);
      expect(session.hasHeldChanges, isTrue);
      expect(session.hasHeldWrites, isTrue);
    });

    test('move their card, so a closed card is redrawn', () {
      final session = EditSession(const _Rec());
      var told = 0;
      session.addListener(() => told++);

      session.holdChange('k', cardId: 'header', write: () async {});

      expect(told, 1);
      expect(session.revisionOf('header'), 1);
    });

    test('released, leave the session clean, and notify', () {
      final session = EditSession(const _Rec())
        ..holdChange('k', cardId: 'header', write: () async {});
      var told = 0;
      session.addListener(() => told++);

      session.releaseWrite('k');

      expect(session.isDirty, isFalse);
      expect(session.changedCardIds, isEmpty);
      expect(session.isHeld('k'), isFalse);
      expect(told, 1);
    });

    test('run with held writes, in the order first held', () async {
      final ran = <String>[];
      final session = EditSession(const _Rec())
        ..holdWrite('a', () async => ran.add('a'))
        ..holdChange('b', cardId: 'header', write: () async => ran.add('b'))
        ..holdWrite('c', () async => ran.add('c'));

      await session.runHeldWrites();

      expect(ran, ['a', 'b', 'c']);
    });

    test('none is taken or released while frozen', () {
      final session = EditSession(const _Rec())
        ..holdChange('k', cardId: 'header', write: () async {})
        ..freeze();

      session
        ..holdChange('other', cardId: 'header', write: () async {})
        ..releaseWrite('k');

      expect(session.isHeld('k'), isTrue);
      expect(session.isHeld('other'), isFalse);
    });

    test('a disposed session takes none', () {
      final session = EditSession(const _Rec())..dispose();

      session.holdChange('k', cardId: 'header', write: () async {});

      expect(session.isHeld('k'), isFalse);
    });

    // Code review: a release arriving after the sitting ended must not
    // notify a disposed session.
    test('a disposed session releases nothing, and does not notify', () {
      final session = EditSession(const _Rec())
        ..holdChange('k', cardId: 'header', write: () async {})
        ..dispose();

      expect(() => session.releaseWrite('k'), returnsNormally);
    });
  });

  test('a change held before the record runs only in its own phase', () async {
    final ran = <String>[];
    final s = EditSession(const _Rec())
      ..holdChange(
        'after',
        cardId: 'tanks',
        write: () async => ran.add('after'),
      )
      ..holdChange(
        'before',
        cardId: 'tanks',
        beforeRecord: true,
        write: () async => ran.add('before'),
      );

    expect(s.hasHeldWritesBeforeRecord, isTrue);
    await s.runHeldWrites(beforeRecord: true);
    expect(ran, ['before']);
    await s.runHeldWrites();
    expect(ran, ['before', 'after']);
  });

  test('a released held write is not run at save', () async {
    final ran = <String>[];
    final session = EditSession(const _Rec())
      ..holdWrite('a', () async => ran.add('a'))
      ..holdWrite('b', () async => ran.add('b'))
      ..releaseWrite('a');

    await session.runHeldWrites();

    expect(ran, ['b']);
    expect(session.isHeld('a'), isFalse);
  });

  test('releasing a held write does not notify', () {
    final session = EditSession(const _Rec())..holdWrite('a', () async {});
    var told = 0;
    session.addListener(() => told++);

    session
      ..releaseWrite('a')
      ..releaseWrite('never held');

    expect(told, 0);
  });

  test('a note is recalled, is no change, and does not notify', () {
    final session = EditSession(const _Rec());
    var told = 0;
    session.addListener(() => told++);

    session.remember('siteAdded', <String>{'wreck'});

    expect(session.recall<Set<String>>('siteAdded'), {'wreck'});
    expect(session.recall<Object>('missing'), isNull);
    expect(session.isDirty, isFalse);
    expect(told, 0);
  });

  group('tracked work', () {
    test('settled waits for it', () async {
      final session = EditSession(const _Rec());
      final gate = Completer<void>();
      session.track(gate.future);

      var done = false;
      unawaited(session.settled().then((_) => done = true));
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(done, isTrue);
    });

    test('an error in it does not escape settled', () async {
      final session = EditSession(const _Rec())
        ..track(Future<void>.error(StateError('lookup failed')));

      await expectLater(session.settled(), completes);
    });

    test('with none, settled completes at once', () async {
      await expectLater(EditSession(const _Rec()).settled(), completes);
    });
  });
}
