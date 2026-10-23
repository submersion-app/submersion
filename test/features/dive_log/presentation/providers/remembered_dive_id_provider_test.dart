import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';

class _FixedList extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _FixedList(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveSummary> _dives(int count) => [
  for (var i = 0; i < count; i++)
    DiveSummary(
      id: 'd$i',
      dateTime: DateTime(2024, 1, 1 + i),
      sortTimestamp: DateTime(2024, 1, 1 + i).millisecondsSinceEpoch,
    ),
];

/// The dive list comes back to the dive last opened, paging forward to it
/// when it sits beyond the loaded rows (#3301).
void main() {
  AsyncValue<String?> remembered({
    required String? highlighted,
    required AsyncValue<PaginatedDiveListState> list,
  }) {
    final container = ProviderContainer(
      overrides: [
        paginatedDiveListProvider.overrideWith((ref) => _FixedList(list)),
      ],
    );
    addTearDown(container.dispose);
    container.read(highlightedDiveIdProvider.notifier).state = highlighted;
    return container.read(rememberedDiveIdProvider);
  }

  test('nothing highlighted resolves to null', () {
    expect(
      remembered(highlighted: null, list: const AsyncLoading()),
      const AsyncData<String?>(null),
    );
  });

  test('waits while the first page loads', () {
    expect(
      remembered(highlighted: 'd3', list: const AsyncLoading()).isLoading,
      isTrue,
    );
  });

  test('a loaded dive resolves to itself', () {
    expect(
      remembered(
        highlighted: 'd3',
        list: AsyncData(PaginatedDiveListState(dives: _dives(50))),
      ),
      const AsyncData<String?>('d3'),
    );
  });

  test('an unloaded dive with more pages to come keeps loading', () {
    expect(
      remembered(
        highlighted: 'd80',
        list: AsyncData(PaginatedDiveListState(dives: _dives(50))),
      ).isLoading,
      isTrue,
    );
  });

  test('a dive missing from the whole list resolves to null', () {
    expect(
      remembered(
        highlighted: 'gone',
        list: AsyncData(
          PaginatedDiveListState(dives: _dives(50), hasMore: false),
        ),
      ),
      const AsyncData<String?>(null),
    );
  });

  test('the search gives up at the row limit', () {
    expect(
      remembered(
        highlighted: 'gone',
        list: AsyncData(
          PaginatedDiveListState(dives: _dives(kRememberedDiveSearchLimit)),
        ),
      ),
      const AsyncData<String?>(null),
    );
  });

  test('a failed page load ends the search', () {
    expect(
      remembered(
        highlighted: 'gone',
        list: AsyncData(
          PaginatedDiveListState(dives: _dives(50), loadMoreFailed: true),
        ),
      ),
      const AsyncData<String?>(null),
    );
  });
}
