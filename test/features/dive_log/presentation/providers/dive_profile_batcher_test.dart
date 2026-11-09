import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_profile_batcher.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

const _profile = [DiveProfilePoint(timestamp: 0, depth: 10)];

/// Answers profile batches itself; ids in [withoutProfile] have none, which
/// the repository reports as an empty list (#4112), and ids in [unreadable]
/// have a series it cannot read, which it leaves out.
class _ProfileRepository implements DiveRepository {
  final calls = <List<String>>[];
  final withoutProfile = <String>{};
  final unreadable = <String>{};
  Completer<void>? hold;
  bool fail = false;

  @override
  Future<Map<String, List<DiveProfilePoint>>> getBatchProfileSummaries(
    List<String> diveIds, {
    int maxSamples = 120,
  }) async {
    calls.add(diveIds);
    await hold?.future;
    if (fail) throw StateError('profiles failed');
    return {
      for (final id in diveIds)
        if (!unreadable.contains(id))
          id: withoutProfile.contains(id)
              ? const <DiveProfilePoint>[]
              : _profile,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _ProfileRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = _ProfileRepository();
    container = ProviderContainer(
      overrides: [diveRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() => container.dispose());

  DiveProfileBatcher batcher() => container.read(diveProfileBatcherProvider);
  Map<String, List<DiveProfilePoint>> cache() =>
      container.read(batchProfileCacheProvider);

  Future<void> flush() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('requests from one frame go out as one deduplicated batch', () async {
    batcher()
      ..request('a')
      ..request('b')
      ..request('a');
    await flush();

    expect(repo.calls, [
      ['a', 'b'],
    ]);
    expect(cache().keys.toSet(), {'a', 'b'});
  });

  test('a cached or already fetched dive is not requested again', () async {
    container.read(batchProfileCacheProvider.notifier).state = {'a': _profile};
    repo.withoutProfile.add('b');
    batcher()
      ..request('a')
      ..request('b');
    await flush();
    batcher().request('b');
    await flush();

    expect(repo.calls, [
      ['b'],
    ]);
  });

  // #4112: a dive cached as having no samples shows an estimated outline. A
  // list load or reload asks again, so a dive that has since gained a
  // profile (computer data imported onto a hand-logged dive) draws it; a
  // card's own request does not, or every profile-less card would refetch.
  test('a load asks again for a dive cached without samples', () async {
    container.read(batchProfileCacheProvider.notifier).state = {
      'a': _profile,
      'b': const [],
    };

    await batcher().load(['a', 'b']);

    expect(repo.calls, [
      ['b'],
    ]);
    expect(cache()['b'], _profile);
  });

  test('asking again for a dive still without samples leaves the cache '
      'alone', () async {
    repo.withoutProfile.add('b');
    await batcher().load(['b']);
    final before = cache();

    await batcher().load(['b']);

    expect(repo.calls, [
      ['b'],
      ['b'],
    ]);
    expect(identical(cache(), before), isTrue);
  });

  test('an empty answer landing after a profile does not replace it', () async {
    // The list and the dashboard can both be asking for a dive cached as
    // empty; the older read must not undo the newer one's profile.
    container.read(batchProfileCacheProvider.notifier).state = {'a': const []};
    repo
      ..withoutProfile.add('a')
      ..hold = Completer<void>();
    final stale = batcher().load(['a']);
    await flush();
    container.read(batchProfileCacheProvider.notifier).state = {'a': _profile};
    repo.hold!.complete();
    await stale;

    expect(cache()['a'], _profile);
  });

  // A dive cached as having no samples that a later read leaves out (its new
  // series is unreadable, or the read failed) may well have samples now, so
  // it must stop drawing the estimate.
  test('a dive cached without samples that a load leaves out loses its '
      'entry', () async {
    container.read(batchProfileCacheProvider.notifier).state = {
      'a': const [],
      'b': const [],
    };
    repo.unreadable.add('a');

    await batcher().load(['a', 'b']);

    expect(cache().containsKey('a'), isFalse);
    expect(cache()['b'], _profile);
  });

  test('a dive cached without samples loses its entry when the load '
      'throws', () async {
    container.read(batchProfileCacheProvider.notifier).state = {
      'a': const [],
      'z': const [],
    };
    repo.fail = true;

    await batcher().load(['a']);

    expect(cache().keys, ['z']);
  });

  test(
    'a load that leaves out a dive cached with samples keeps them',
    () async {
      container.read(batchProfileCacheProvider.notifier).state = {
        'a': const [],
      };
      repo
        ..unreadable.add('a')
        ..hold = Completer<void>();
      final stale = batcher().load(['a']);
      await flush();
      container.read(batchProfileCacheProvider.notifier).state = {
        'a': _profile,
      };
      repo.hold!.complete();
      await stale;

      expect(cache()['a'], _profile);
    },
  );

  test('a request for a dive being loaded waits for that load', () async {
    repo.hold = Completer<void>();
    unawaited(batcher().load(['a', 'b']));
    batcher()
      ..request('a')
      ..request('c');
    await flush();
    repo.hold!.complete();
    await flush();

    expect(repo.calls, [
      ['a', 'b'],
      ['c'],
    ]);
    expect(cache().keys.toSet(), {'a', 'b', 'c'});
  });

  test('a failed batch leaves the cache alone and throws nowhere', () async {
    repo.fail = true;
    batcher().request('a');
    await flush();

    expect(repo.calls, hasLength(1));
    expect(cache(), isEmpty);
  });

  test('a dive whose batch failed can be requested again', () async {
    repo.fail = true;
    batcher().request('a');
    await flush();
    repo.fail = false;
    batcher().request('a');
    await flush();

    expect(repo.calls, [
      ['a'],
      ['a'],
    ]);
    expect(cache().keys, ['a']);
  });
}
