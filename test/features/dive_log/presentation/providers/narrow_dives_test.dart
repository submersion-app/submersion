import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/narrow_dives.dart';

/// The pure step behind filteredDivesProvider: the hydrated list narrowed by
/// the compiled query's id set, with the loading and error rules pinned.
void main() {
  final dives = [
    Dive(id: 'a', dateTime: DateTime(2026, 1, 1)),
    Dive(id: 'b', dateTime: DateTime(2026, 1, 2)),
  ];
  final loaded = AsyncValue.data(dives);
  List<String> idsOf(AsyncValue<List<Dive>> v) =>
      v.value!.map((d) => d.id).toList();

  test('no filter passes the list through', () {
    expect(idsOf(narrowDivesByIds(loaded, const AsyncValue.data(null))), [
      'a',
      'b',
    ]);
  });

  test('an id set narrows the list', () {
    expect(idsOf(narrowDivesByIds(loaded, const AsyncValue.data({'b'}))), [
      'b',
    ]);
  });

  test('a first load is loading', () {
    expect(
      narrowDivesByIds(loaded, const AsyncValue<Set<String>?>.loading()),
      isA<AsyncLoading<List<Dive>>>(),
    );
  });

  /// A provider whose first build yields {'a'} and whose second build
  /// runs [second], driven through a container so Riverpod itself attaches
  /// the previous value to the refreshing or failed state.
  Future<AsyncValue<Set<String>?>> afterRefresh(
    Future<Set<String>?> Function() second,
  ) async {
    var builds = 0;
    final ids = FutureProvider<Set<String>?>((ref) {
      builds++;
      return builds == 1 ? Future.value({'a'}) : second();
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(ids, (_, _) {});
    await container.read(ids.future);
    container.invalidate(ids);
    await Future<void>.delayed(Duration.zero);
    return container.read(ids);
  }

  test(
    'a refresh keeps the previous ids rather than blanking the list',
    () async {
      final refreshing = await afterRefresh(
        () => Completer<Set<String>?>().future,
      );
      expect(refreshing.isLoading, isTrue);
      expect(idsOf(narrowDivesByIds(loaded, refreshing)), ['a']);
    },
  );

  test(
    'a failed refresh is an error even when a previous set exists',
    () async {
      final failed = await afterRefresh(() async => throw StateError('locked'));
      expect(failed.hasError, isTrue);
      expect(
        failed.hasValue,
        isTrue,
        reason: 'Riverpod keeps the previous set',
      );
      final out = narrowDivesByIds(loaded, failed);
      expect(out.hasError, isTrue, reason: 'never show stale ids as truth');
    },
  );
}
