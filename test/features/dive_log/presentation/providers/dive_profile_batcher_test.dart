import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_profile_batcher.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

const _profile = [DiveProfilePoint(timestamp: 0, depth: 10)];

/// Answers profile batches itself; ids in [withoutProfile] have none.
class _ProfileRepository implements DiveRepository {
  final calls = <List<String>>[];
  final withoutProfile = <String>{};
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
        if (!withoutProfile.contains(id)) id: _profile,
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
