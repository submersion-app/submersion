import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Typing in the dive search row (#2773) re-runs the list on every pause;
/// a query-only change keeps the current rows on screen until the new ones
/// arrive instead of blanking the list behind a spinner.
void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    final diver = await DiverRepository().createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
    final diveRepo = DiveRepository();
    for (final (id, day, notes) in [
      ('a', 1, 'manta'),
      ('b', 2, 'reef'),
      ('c', 3, 'manta ray'),
    ]) {
      await diveRepo.createDive(
        Dive(
          id: id,
          diverId: diver.id,
          dateTime: DateTime(2026, 1, day),
          notes: notes,
          isFavorite: id == 'a',
        ),
      );
    }
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<(ProviderContainer, List<AsyncValue<PaginatedDiveListState>>)>
  loaded() async {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final seen = <AsyncValue<PaginatedDiveListState>>[];
    final sub = container.listen(
      paginatedDiveListProvider,
      (_, next) => seen.add(next),
      fireImmediately: true,
    );
    addTearDown(sub.close);
    await waitForIds(container, {'a', 'b', 'c'});
    seen.clear();
    return (container, seen);
  }

  test('a query-only change never shows a loading state', () async {
    final (container, seen) = await loaded();
    container.read(diveFilterProvider.notifier).state = DiveFilterState(
      query: TextNode(['manta']),
    );
    await waitForIds(container, {'a', 'c'});
    expect(seen.where((s) => s.isLoading), isEmpty);
  });

  test('toggling All dives is quiet too', () async {
    final (container, seen) = await loaded();
    final notifier = container.read(diveFilterProvider.notifier);
    notifier.state = DiveFilterState(
      favoritesOnly: true,
      query: TextNode(['manta']),
    );
    await waitForIds(container, {'a'});
    seen.clear();
    notifier.state = notifier.state.copyWith(axesSuspended: true);
    await waitForIds(container, {'a', 'c'});
    expect(seen.where((s) => s.isLoading), isEmpty);
  });

  // Code review: each typing pause queued its own load, and every queued
  // load re-ran the same latest filter.
  test('filter changes queued behind one load run it once', () async {
    final (container, seen) = await loaded();
    final notifier = container.read(diveFilterProvider.notifier);
    for (final word in ['manta', 'mant', 'ray']) {
      notifier.state = DiveFilterState(query: TextNode([word]));
    }
    await waitForIds(container, {'c'});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(seen.where((s) => s.hasValue && !s.isLoading), hasLength(1));
  });

  test('other filter changes still reload from the first page', () async {
    final (container, seen) = await loaded();
    container.read(diveFilterProvider.notifier).state = const DiveFilterState(
      favoritesOnly: true,
    );
    await waitForIds(container, {'a'});
    expect(seen.where((s) => s.isLoading), isNotEmpty);
  });
}

Future<void> waitForIds(ProviderContainer container, Set<String> ids) async {
  for (var i = 0; i < 300; i++) {
    final value = container.read(paginatedDiveListProvider).value;
    if (value != null && value.dives.map((d) => d.id).toSet().sameAs(ids)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail(
    'list never showed $ids: '
    '${container.read(paginatedDiveListProvider).value?.dives.map((d) => d.id)}',
  );
}

extension on Set<String> {
  bool sameAs(Set<String> other) =>
      length == other.length && this.containsAll(other);
}
