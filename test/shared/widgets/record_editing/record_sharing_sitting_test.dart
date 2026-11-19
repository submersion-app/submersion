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
class _FakeAdapter implements RecordSharingAdapter<Set<String>> {
  _FakeAdapter(this.current);

  Set<String> current;
  final writes = <({String id, Set<String> sharing, String? actingDiverId})>[];
  bool refuse = false;
  bool failRead = false;
  Completer<void>? readGate;

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

  test('nothing is held before the read answers', () async {
    final gate = adapter.readGate = Completer<void>();
    final loading = _sharing.load(session, adapter);

    _sharing.set(session, {'alex'}, actingDiverId: 'me');

    expect(session.isDirty, isFalse);
    gate.complete();
    await loading;
  });
}
