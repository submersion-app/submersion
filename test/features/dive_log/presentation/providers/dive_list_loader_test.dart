import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_list_snapshot.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_list_loader.dart';

typedef _SnapshotCall = ({
  String? diverId,
  DiveListSnapshot? previous,
  Completer<DiveListSnapshot> answer,
});

/// Answers each snapshot read only when the test says so, so that loads can
/// finish in any order. [DiveRepository]'s only public constructor is a
/// factory, so this implements rather than extends.
class _ScriptedRepository implements DiveRepository {
  final hydrationWrites = StreamController<void>.broadcast();
  final calls = <_SnapshotCall>[];

  @override
  Stream<void> watchDiveHydrationWrites() => hydrationWrites.stream;

  @override
  Future<DiveListSnapshot> getDiveListSnapshot({
    String? diverId,
    DiveListSnapshot? previous,
  }) {
    final answer = Completer<DiveListSnapshot>();
    calls.add((diverId: diverId, previous: previous, answer: answer));
    return answer.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DiveListSnapshot _snapshotOf(String id) =>
    const DiveListSnapshot.empty().advancedTo(
      [(id: id, digest: 1)],
      hydrated: [Dive(id: id, dateTime: DateTime(2026))],
    );

void main() {
  late _ScriptedRepository repository;
  late DiveListLoader loader;

  setUp(() {
    repository = _ScriptedRepository();
    loader = DiveListLoader(repository);
    addTearDown(loader.cancel);
    addTearDown(repository.hydrationWrites.close);
  });

  Future<DiveListSnapshot> settledSnapshot(String id) async {
    final snapshot = _snapshotOf(id);
    final load = loader.load(diverId: id);
    await pumpEventQueue();
    repository.calls.last.answer.complete(snapshot);
    await load;
    return snapshot;
  }

  test('a refresh after a load hands the snapshot back to reuse', () async {
    final held = await settledSnapshot('mine');

    final refresh = loader.refresh(diverId: 'mine');
    await pumpEventQueue();

    expect(repository.calls.last.previous, same(held));
    repository.calls.last.answer.complete(held);
    await refresh;
  });

  test('a load trusts nothing held', () async {
    await settledSnapshot('mine');

    final load = loader.load(diverId: 'mine');
    await pumpEventQueue();

    expect(repository.calls.last.previous, isNull);
    repository.calls.last.answer.complete(_snapshotOf('mine'));
    await load;
  });

  test('an unchanged list answers null', () async {
    final held = await settledSnapshot('mine');

    final refresh = loader.refresh(diverId: 'mine');
    await pumpEventQueue();
    repository.calls.last.answer.complete(held);

    expect(await refresh, isNull);
  });

  test('a changed list answers its dives', () async {
    await settledSnapshot('mine');
    final changed = _snapshotOf('edited');

    final refresh = loader.refresh(diverId: 'mine');
    await pumpEventQueue();
    repository.calls.last.answer.complete(changed);

    expect(await refresh, same(changed.dives));
  });

  group('a hydration write', () {
    test('before a refresh makes it trust nothing held', () async {
      await settledSnapshot('mine');

      repository.hydrationWrites.add(null);
      await pumpEventQueue();
      final refresh = loader.refresh(diverId: 'mine');
      await pumpEventQueue();

      expect(repository.calls.last.previous, isNull);
      repository.calls.last.answer.complete(_snapshotOf('mine'));
      await refresh;
    });

    test('during a load reads as unseen once the load lands', () async {
      final load = loader.load(diverId: 'mine');
      await pumpEventQueue();
      repository.hydrationWrites.add(null);
      await pumpEventQueue();
      repository.calls.last.answer.complete(_snapshotOf('mine'));
      await load;

      final refresh = loader.refresh(diverId: 'mine');
      await pumpEventQueue();

      expect(repository.calls.last.previous, isNull);
      repository.calls.last.answer.complete(_snapshotOf('mine'));
      await refresh;
    });

    test('reported just behind a refresh still counts', () async {
      await settledSnapshot('mine');

      final refresh = loader.refresh(diverId: 'mine');
      repository.hydrationWrites.add(null);
      await pumpEventQueue();

      expect(repository.calls.last.previous, isNull);
      repository.calls.last.answer.complete(_snapshotOf('mine'));
      await refresh;
    });
  });

  group('a load a newer one overtook', () {
    test('answers null and leaves the newer list in place', () async {
      final mine = loader.load(diverId: 'mine');
      await pumpEventQueue();
      final theirs = loader.load(diverId: 'theirs');
      await pumpEventQueue();
      final overtaken = repository.calls.first;
      final newest = repository.calls.last;
      final landed = _snapshotOf('theirs');

      newest.answer.complete(landed);
      expect(await theirs, same(landed.dives));
      overtaken.answer.complete(_snapshotOf('mine'));

      expect(await mine, isNull);
      final refresh = loader.refresh(diverId: 'theirs');
      await pumpEventQueue();
      expect(repository.calls.last.previous, same(landed));
      repository.calls.last.answer.complete(landed);
      await refresh;
    });

    test('that fails answers null rather than throwing', () async {
      final mine = loader.load(diverId: 'mine');
      await pumpEventQueue();
      final theirs = loader.load(diverId: 'theirs');
      await pumpEventQueue();
      final landed = _snapshotOf('theirs');
      repository.calls.last.answer.complete(landed);
      await theirs;

      repository.calls.first.answer.completeError(StateError('gone'));

      expect(await mine, isNull);
    });

    test('before it reached the database never reads', () async {
      final mine = loader.load(diverId: 'mine');
      final theirs = loader.load(diverId: 'theirs');
      await pumpEventQueue();

      expect(repository.calls.map((c) => c.diverId), ['theirs']);
      expect(await mine, isNull);
      repository.calls.last.answer.complete(_snapshotOf('theirs'));
      await theirs;
    });
  });

  test('cancel discards a load in flight', () async {
    final load = loader.load(diverId: 'mine');
    await pumpEventQueue();

    loader.cancel();
    repository.calls.last.answer.complete(_snapshotOf('mine'));

    expect(await load, isNull);
  });

  test('a failed load rethrows and leaves nothing to reuse', () async {
    await settledSnapshot('mine');

    final failing = loader.refresh(diverId: 'mine');
    await pumpEventQueue();
    repository.calls.last.answer.completeError(StateError('locked'));
    await expectLater(failing, throwsStateError);

    final retry = loader.refresh(diverId: 'mine');
    await pumpEventQueue();
    expect(repository.calls.last.previous, isNull);
    repository.calls.last.answer.complete(_snapshotOf('mine'));
    await retry;
  });

  group('latest', () {
    test('answers the list when it changed', () async {
      final changed = _snapshotOf('mine');

      final latest = loader.latest(diverId: 'mine');
      await pumpEventQueue();
      repository.calls.last.answer.complete(changed);

      expect(await latest, same(changed.dives));
    });

    test('answers the held list when nothing changed', () async {
      final held = await settledSnapshot('mine');

      final latest = loader.latest(diverId: 'mine');
      await pumpEventQueue();
      repository.calls.last.answer.complete(held);

      expect(await latest, same(held.dives));
    });
  });
}
