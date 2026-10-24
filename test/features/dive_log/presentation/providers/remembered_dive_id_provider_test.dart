import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_scrubber_entry.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_scrubber_providers.dart';
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
    List<String> indexedIds = const [],
  }) {
    final container = ProviderContainer(
      overrides: [
        paginatedDiveListProvider.overrideWith((ref) => _FixedList(list)),
        diveScrubberIndexProvider.overrideWithValue(
          AsyncData(
            DiveScrubberIndex(
              entries: [
                for (final id in indexedIds)
                  DiveScrubberEntry(id: id, sortTimestamp: 0),
              ],
              diverId: null,
              filter: const DiveFilterState(),
              sort: const SortState(field: DiveSortField.date),
            ),
          ),
        ),
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

  // The list's scrubber index holds every dive the filter selects, in order,
  // so the search need not page blindly.
  test('a dive the full index does not hold ends the search at once', () {
    expect(
      remembered(
        highlighted: 'gone',
        list: AsyncData(PaginatedDiveListState(dives: _dives(50))),
        indexedIds: [for (var i = 0; i < 200; i++) 'd$i'],
      ),
      const AsyncData<String?>(null),
    );
  });

  test('a dive the index holds is paged for past the row limit', () {
    expect(
      remembered(
        highlighted: 'd1500',
        list: AsyncData(
          PaginatedDiveListState(dives: _dives(kRememberedDiveSearchLimit)),
        ),
        indexedIds: [for (var i = 0; i < 2000; i++) 'd$i'],
      ).isLoading,
      isTrue,
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
