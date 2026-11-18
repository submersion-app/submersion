import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// A record's child rows held in a sitting as one change (issue #4527,
/// plan 6).
void main() {
  late List<String> stored;
  late int reads;
  late List<({String record, List<String> loaded, List<String> current})>
  writes;
  Completer<List<String>>? gate;

  SittingList<String, String> rows({
    bool Function(List<String> a, List<String> b)? same,
    String key = 'rows',
    Future<void> Function()? onWrite,
  }) => SittingList<String, String>(
    key: key,
    cardId: 'card',
    read: (record) async {
      reads++;
      final waiting = gate;
      if (waiting != null) return waiting.future;
      return stored;
    },
    write: (record, loaded, current) async {
      writes.add((record: record, loaded: loaded, current: current));
      await onWrite?.call();
      return null;
    },
    same: same,
  );

  late EditSession<String> session;

  setUp(() {
    stored = ['a', 'b'];
    reads = 0;
    writes = [];
    gate = null;
    session = EditSession<String>('dive');
  });

  tearDown(() {
    if (!session.isDisposed) session.dispose();
  });

  test('load reads once per open while unchanged, and an unchanged list writes '
      'nothing', () async {
    final list = rows();
    list.load(session);
    await session.settled();
    expect(list.loaded(session), ['a', 'b']);
    expect(list.current(session), ['a', 'b']);
    expect(session.isDirty, isFalse);

    // Stored since: an untouched list reads again when its card opens.
    stored = ['a', 'b', 'c'];
    list.load(session);
    await session.settled();
    expect(reads, 2);
    expect(list.current(session), ['a', 'b', 'c']);

    await session.runHeldWrites();
    expect(writes, isEmpty);
  });

  test(
    'set holds one change of the card; setting it back releases it',
    () async {
      final list = rows();
      list.load(session);
      await session.settled();
      var told = 0;
      session.addListener(() => told++);

      list.set(session, ['a']);
      expect(list.isChanged(session), isTrue);
      expect(list.current(session), ['a']);
      expect(session.isDirty, isTrue);
      expect(session.changedCardIds, {'card'});
      expect(told, 1);

      list.set(session, ['a', 'b']);
      expect(list.isChanged(session), isFalse);
      expect(list.current(session), ['a', 'b']);
      expect(session.isDirty, isFalse);
      expect(told, 2);
    },
  );

  // An editor shows the failure, not a spinner that never ends, and can
  // ask again.
  test('a read that fails is told, and a read asked again clears it', () async {
    final list = rows();
    gate = Completer<List<String>>()..completeError(StateError('locked db'));
    list.load(session);
    await session.settled();
    expect(list.loaded(session), isNull);
    expect(list.failed(session), isTrue);

    gate = null;
    list.load(session);
    await session.settled();
    expect(list.failed(session), isFalse);
    expect(list.current(session), ['a', 'b']);
  });

  test("a changed list is not read again: the diver's list stays", () async {
    final list = rows();
    list.load(session);
    await session.settled();
    list.set(session, ['b']);

    stored = ['x'];
    list.load(session);
    await session.settled();
    expect(reads, 1);
    expect(list.current(session), ['b']);
    expect(list.loaded(session), ['a', 'b']);
  });

  test('the held write gets the loaded and current lists as they are when it '
      'runs', () async {
    final list = rows();
    list.load(session);
    await session.settled();
    list.set(session, ['a']);
    list.set(session, ['a', 'c']);

    await session.runHeldWrites();
    expect(writes, hasLength(1));
    expect(writes.single.record, 'dive');
    expect(writes.single.loaded, ['a', 'b']);
    expect(writes.single.current, ['a', 'c']);
  });

  test('a read answering after the list was changed is dropped', () async {
    final list = rows();
    list.load(session);
    await session.settled();
    list.set(session, ['a']);
    // Changed back, so the next open reads again; the diver changes it
    // once more before that read answers.
    list.set(session, ['a', 'b']);
    gate = Completer<List<String>>();
    list.load(session);
    list.set(session, ['b']);
    gate!.complete(['z']);
    await session.settled();

    expect(list.loaded(session), ['a', 'b']);
    expect(list.current(session), ['b']);
  });

  test('a read answering after the sitting ended sets nothing', () async {
    final list = rows();
    gate = Completer<List<String>>();
    list.load(session);
    session.dispose();
    gate!.complete(['a']);
    await Future<void>.delayed(Duration.zero);

    expect(list.loaded(session), isNull);
  });

  test('set before the load does nothing', () {
    final list = rows();
    list.set(session, ['a']);
    expect(list.isChanged(session), isFalse);
    expect(session.isDirty, isFalse);
  });

  test('a custom same: the same rows in another order are no change', () async {
    final list = rows(same: (a, b) => setEquals(a.toSet(), b.toSet()));
    list.load(session);
    await session.settled();

    list.set(session, ['b', 'a']);
    expect(list.isChanged(session), isFalse);
    expect(session.isDirty, isFalse);
  });

  test('a write that throws stops the save; nothing after it runs', () async {
    final first = rows(
      key: 'first',
      onWrite: () async => throw StateError('disk full'),
    );
    final second = rows(key: 'second');
    first.load(session);
    second.load(session);
    await session.settled();
    first.set(session, ['a']);
    second.set(session, ['b']);

    await expectLater(session.runHeldWrites(), throwsStateError);
    expect(writes.map((w) => w.current), [
      ['a'],
    ]);
  });

  test('sameIdSets compares by id, in any order', () {
    String id(String s) => s.split(':').first;
    expect(sameIdSets(['a:1', 'b:2'], ['b:9', 'a:8'], id), isTrue);
    expect(sameIdSets(['a:1'], ['a:1', 'b:2'], id), isFalse);
    expect(sameIdSets(['a:1', 'a:2'], ['a:3', 'b:4'], id), isFalse);
  });
}
