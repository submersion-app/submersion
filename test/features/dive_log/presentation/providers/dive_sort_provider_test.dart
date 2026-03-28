import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

void main() {
  Dive makeDive({
    required String id,
    Duration? bottomTime,
    DateTime? dateTime,
  }) {
    return Dive(
      id: id,
      dateTime: dateTime ?? DateTime(2026, 3, 28),
      bottomTime: bottomTime,
      tanks: const [],
      profile: const [],
      equipment: const [],
      notes: '',
      photoIds: const [],
      sightings: const [],
      weights: const [],
      tags: const [],
    );
  }

  group('sortedFilteredDivesProvider', () {
    test('sorts dives by bottomTime ascending', () {
      final dives = [
        makeDive(id: 'd1', bottomTime: const Duration(minutes: 60)),
        makeDive(id: 'd2', bottomTime: const Duration(minutes: 20)),
        makeDive(id: 'd3', bottomTime: const Duration(minutes: 45)),
      ];

      final container = ProviderContainer(
        overrides: [
          filteredDivesProvider.overrideWith((ref) => AsyncValue.data(dives)),
          diveSortProvider.overrideWith(
            (ref) => const SortState(
              field: DiveSortField.bottomTime,
              direction: SortDirection.ascending,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(sortedFilteredDivesProvider);

      expect(result.value?.map((d) => d.id).toList(), ['d2', 'd3', 'd1']);
    });

    test('sorts dives by bottomTime descending', () {
      final dives = [
        makeDive(id: 'd1', bottomTime: const Duration(minutes: 20)),
        makeDive(id: 'd2', bottomTime: const Duration(minutes: 60)),
        makeDive(id: 'd3', bottomTime: const Duration(minutes: 45)),
      ];

      final container = ProviderContainer(
        overrides: [
          filteredDivesProvider.overrideWith((ref) => AsyncValue.data(dives)),
          diveSortProvider.overrideWith(
            (ref) => const SortState(
              field: DiveSortField.bottomTime,
              direction: SortDirection.descending,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(sortedFilteredDivesProvider);

      expect(result.value?.map((d) => d.id).toList(), ['d2', 'd3', 'd1']);
    });

    test('handles null bottomTime in sort', () {
      final dives = [
        makeDive(id: 'd1', bottomTime: const Duration(minutes: 30)),
        makeDive(id: 'd2'), // null bottomTime
        makeDive(id: 'd3', bottomTime: const Duration(minutes: 60)),
      ];

      final container = ProviderContainer(
        overrides: [
          filteredDivesProvider.overrideWith((ref) => AsyncValue.data(dives)),
          diveSortProvider.overrideWith(
            (ref) => const SortState(
              field: DiveSortField.bottomTime,
              direction: SortDirection.ascending,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(sortedFilteredDivesProvider);

      // null bottomTime treated as 0 minutes, so d2 comes first
      expect(result.value?.first.id, 'd2');
      expect(result.value?.last.id, 'd3');
    });
  });
}
