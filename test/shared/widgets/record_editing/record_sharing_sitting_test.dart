import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_sharing_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

class _Rec {
  const _Rec(this.id, this.name);

  final String id;
  final String name;
}

/// Answers reads from [current], records writes, and refuses or fails on
/// demand.
class _FakeAdapter extends RecordSharingAdapter<Set<String>> {
  _FakeAdapter(this.current);

  Set<String> current;
  final writes = <({String id, Set<String> sharing, String? actingDiverId})>[];
  bool refuse = false;
  bool failRead = false;
  Completer<void>? readGate;

  /// Rows stored beside what [read] reports, which an owner's save clears.
  bool stale = false;
  bool failNeedsRewrite = false;
  bool failWrite = false;

  @override
  Future<bool> needsRewrite(String recordId) async {
    if (failNeedsRewrite) throw StateError('could not check the rows');
    return stale;
  }

  @override
  Future<Set<String>> read(String recordId) async {
    await readGate?.future;
    if (failRead) throw StateError('could not read');
    return current;
  }

  @override
  Future<bool> write(
    String recordId,
    Set<String> sharing, {
    required String? actingDiverId,
  }) async {
    writes.add((id: recordId, sharing: sharing, actingDiverId: actingDiverId));
    if (failWrite) throw StateError('could not write');
    if (refuse) return false;
    current = sharing;
    return true;
  }
}

const _sharing = RecordSharingSitting<_Rec, Set<String>>(
  key: 'rec.sharing',
  cardId: 'header',
  recordIdOf: _idOf,
);

String _idOf(_Rec record) => record.id;

void main() {
  late EditSession<_Rec> session;
  late _FakeAdapter adapter;

  setUp(() {
    session = EditSession(const _Rec('r1', 'Reef'));
    adapter = _FakeAdapter({'sam'});
  });
  tearDown(() => session.dispose());

  test('loads what the record is shared with', () async {
    await _sharing.load(session, adapter);

    expect(_sharing.loaded(session), {'sam'});
    expect(_sharing.inSitting(session), {'sam'});
    expect(_sharing.unread(session), isFalse);
  });

  test('a read that fails leaves it unread', () async {
    adapter.failRead = true;

    await _sharing.load(session, adapter);

    expect(_sharing.unread(session), isTrue);
    expect(_sharing.inSitting(session), isNull);
  });

  test('a choice is a change of its card', () async {
    await _sharing.load(session, adapter);

    _sharing.set(session, {'sam', 'alex'}, actingDiverId: 'me');

    expect(session.changedCardIds, {'header'});
    expect(_sharing.inSitting(session), {'sam', 'alex'});
  });

  test('back to what was read is no change', () async {
    await _sharing.load(session, adapter);

    _sharing.set(session, {'alex'}, actingDiverId: 'me');
    _sharing.set(session, {'sam'}, actingDiverId: 'me');

    expect(session.isDirty, isFalse);
    expect(_sharing.inSitting(session), {'sam'});
  });

  test('the held write writes the choice by the acting profile', () async {
    await _sharing.load(session, adapter);
    _sharing.set(session, {'alex'}, actingDiverId: 'me');

    await session.runHeldWrites();

    final write = adapter.writes.single;
    expect(write.id, 'r1');
    expect(write.sharing, {'alex'});
    expect(write.actingDiverId, 'me');
  });

  test('a refusal fails with the sharing message', () async {
    await _sharing.load(session, adapter);
    _sharing.set(session, {'alex'}, actingDiverId: 'me');
    adapter.refuse = true;

    await expectLater(
      session.runHeldWrites(),
      throwsA(isA<RecordSittingRefusal>()),
    );
  });

  // A trip shared with Everyone can also hold share rows from a sync race;
  // an owner's save clears them, as the trip form did (issue #4527).
  test('stale rows are rewritten with any save, and are no change', () async {
    adapter.stale = true;

    await _sharing.load(session, adapter, actingDiverId: 'me');

    expect(session.isDirty, isFalse);
    await session.runHeldWrites();
    final write = adapter.writes.single;
    expect(write.sharing, {'sam'});
    expect(write.actingDiverId, 'me');
  });

  test('a refused rewrite of stale rows does not fail the save', () async {
    adapter
      ..stale = true
      ..refuse = true;
    await _sharing.load(session, adapter, actingDiverId: 'sam');

    await session.runHeldWrites();

    expect(adapter.writes, hasLength(1));
  });

  test('a choice taken back still rewrites stale rows', () async {
    adapter.stale = true;
    await _sharing.load(session, adapter, actingDiverId: 'me');

    _sharing.set(session, {'alex'}, actingDiverId: 'me');
    _sharing.set(session, {'sam'}, actingDiverId: 'me');
    await session.runHeldWrites();

    expect(session.isDirty, isFalse);
    expect(adapter.writes.single.sharing, {'sam'});
  });

  // The rewrite is upkeep, not the diver's choice: a sharing that changed
  // after the sitting read it (another device's, synced in) is what it
  // rewrites, never the older value it read.
  test('a sharing changed underneath is rewritten as stored at Save', () async {
    adapter.stale = true;
    await _sharing.load(session, adapter, actingDiverId: 'me');
    adapter.current = {'alex'};

    await session.runHeldWrites();

    expect(adapter.writes.single.sharing, {'alex'});
  });

  test('rows cleared underneath are not rewritten', () async {
    adapter.stale = true;
    await _sharing.load(session, adapter, actingDiverId: 'me');
    adapter.stale = false;

    await session.runHeldWrites();

    expect(adapter.writes, isEmpty);
  });

  // Whether rows need clearing only decides upkeep: a check that fails
  // leaves the sharing as read, changeable, with no rewrite held.
  test('an upkeep check that fails leaves the sharing read', () async {
    adapter.failNeedsRewrite = true;

    await _sharing.load(session, adapter, actingDiverId: 'me');

    expect(_sharing.unread(session), isFalse);
    expect(_sharing.loaded(session), {'sam'});
    await session.runHeldWrites();
    expect(adapter.writes, isEmpty);
  });

  // Upkeep the diver never asked for must not cost them their edit: a
  // check or a write of it that fails at Save is left for the next Save.
  test('an upkeep that fails at Save fails nothing', () async {
    adapter.stale = true;
    await _sharing.load(session, adapter, actingDiverId: 'me');
    adapter.failNeedsRewrite = true;

    await session.runHeldWrites();

    adapter
      ..failNeedsRewrite = false
      ..failWrite = true;
    await session.runHeldWrites();
    expect(adapter.writes, hasLength(1));
  });

  test(
    "the diver's own choice that fails to write still fails the Save",
    () async {
      await _sharing.load(session, adapter);
      _sharing.set(session, {'alex'}, actingDiverId: 'me');
      adapter.failWrite = true;

      await expectLater(session.runHeldWrites(), throwsStateError);
    },
  );

  test('nothing is held before the read answers', () async {
    final gate = adapter.readGate = Completer<void>();
    final loading = _sharing.load(session, adapter);

    _sharing.set(session, {'alex'}, actingDiverId: 'me');

    expect(session.isDirty, isFalse);
    gate.complete();
    await loading;
  });
  test("a new record's sharing is the seed's, read from nowhere", () async {
    adapter.failRead = true;
    final fresh = EditSession(const _Rec('n1', ''), isNew: true);
    addTearDown(fresh.dispose);

    await _sharing.load(fresh, adapter, newRecordSharing: {'everyone'});

    expect(_sharing.loaded(fresh), {'everyone'});
    expect(_sharing.unread(fresh), isFalse);
    expect(fresh.isDirty, isFalse);
    _sharing.set(fresh, <String>{}, actingDiverId: 'me');
    expect(fresh.isDirty, isTrue);
    expect(fresh.changedCardIds, {'header'});
  });
}
