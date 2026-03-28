import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

/// Helper to create a minimal Dive for filter testing.
Dive _makeDive({
  String id = 'dive-1',
  DateTime? dateTime,
  double? maxDepth,
  String? diveTypeId,
  bool isFavorite = false,
  String? diveComputerSerial,
  int? rating,
  Duration? duration,
  String? tripId,
  List<DiveCustomField> customFields = const [],
}) {
  return Dive(
    id: id,
    dateTime: dateTime ?? DateTime(2026, 3, 19),
    maxDepth: maxDepth,
    diveTypeId: diveTypeId ?? 'recreational',
    isFavorite: isFavorite,
    diveComputerSerial: diveComputerSerial,
    rating: rating,
    bottomTime: duration,
    tripId: tripId,
    tanks: const [],
    profile: const [],
    equipment: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
    customFields: customFields,
  );
}

void main() {
  group('DiveFilterState', () {
    group('constructor defaults', () {
      test('all fields default to null or empty', () {
        const filter = DiveFilterState();

        expect(filter.startDate, isNull);
        expect(filter.endDate, isNull);
        expect(filter.diveTypeId, isNull);
        expect(filter.siteId, isNull);
        expect(filter.tripId, isNull);
        expect(filter.diveCenterId, isNull);
        expect(filter.minDepth, isNull);
        expect(filter.maxDepth, isNull);
        expect(filter.favoritesOnly, isNull);
        expect(filter.tagIds, isEmpty);
        expect(filter.equipmentIds, isEmpty);
        expect(filter.buddyNameFilter, isNull);
        expect(filter.buddyId, isNull);
        expect(filter.diveIds, isEmpty);
        expect(filter.minO2Percent, isNull);
        expect(filter.maxO2Percent, isNull);
        expect(filter.minRating, isNull);
        expect(filter.minBottomTimeMinutes, isNull);
        expect(filter.maxBottomTimeMinutes, isNull);
        expect(filter.computerSerial, isNull);
        expect(filter.customFieldKey, isNull);
        expect(filter.customFieldValue, isNull);
      });
    });

    group('hasActiveFilters', () {
      test('returns false for default empty state', () {
        const filter = DiveFilterState();

        expect(filter.hasActiveFilters, isFalse);
      });

      test('returns true when computerSerial is set', () {
        const filter = DiveFilterState(computerSerial: 'SN12345');

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when startDate is set', () {
        final filter = DiveFilterState(startDate: DateTime(2026, 1, 1));

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when minRating is set', () {
        const filter = DiveFilterState(minRating: 3);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when minBottomTimeMinutes is set', () {
        const filter = DiveFilterState(minBottomTimeMinutes: 30);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when maxBottomTimeMinutes is set', () {
        const filter = DiveFilterState(maxBottomTimeMinutes: 60);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when customFieldKey is set and non-empty', () {
        const filter = DiveFilterState(customFieldKey: 'visibility');

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns false when customFieldKey is empty string', () {
        const filter = DiveFilterState(customFieldKey: '');

        expect(filter.hasActiveFilters, isFalse);
      });

      test('returns true when favoritesOnly is true', () {
        const filter = DiveFilterState(favoritesOnly: true);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns false when favoritesOnly is false', () {
        const filter = DiveFilterState(favoritesOnly: false);

        expect(filter.hasActiveFilters, isFalse);
      });

      test('returns true when diveIds is non-empty', () {
        const filter = DiveFilterState(diveIds: ['d1', 'd2']);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when buddyNameFilter is set and non-empty', () {
        const filter = DiveFilterState(buddyNameFilter: 'John');

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns false when buddyNameFilter is empty string', () {
        const filter = DiveFilterState(buddyNameFilter: '');

        expect(filter.hasActiveFilters, isFalse);
      });
    });

    group('copyWith', () {
      test('sets computerSerial', () {
        const original = DiveFilterState();

        final updated = original.copyWith(computerSerial: 'SN999');

        expect(updated.computerSerial, 'SN999');
      });

      test('preserves computerSerial when not specified', () {
        const original = DiveFilterState(computerSerial: 'SN999');

        final updated = original.copyWith(minRating: 3);

        expect(updated.computerSerial, 'SN999');
        expect(updated.minRating, 3);
      });

      test('clears computerSerial with clearComputerSerial', () {
        const original = DiveFilterState(computerSerial: 'SN999');

        final updated = original.copyWith(clearComputerSerial: true);

        expect(updated.computerSerial, isNull);
      });

      test('clearComputerSerial takes precedence over new value', () {
        const original = DiveFilterState(computerSerial: 'SN999');

        final updated = original.copyWith(
          computerSerial: 'SN111',
          clearComputerSerial: true,
        );

        expect(updated.computerSerial, isNull);
      });

      test('sets and clears multiple fields simultaneously', () {
        const original = DiveFilterState(
          minRating: 3,
          computerSerial: 'SN999',
          minBottomTimeMinutes: 30,
        );

        final updated = original.copyWith(
          clearMinRating: true,
          maxBottomTimeMinutes: 60,
          clearComputerSerial: true,
        );

        expect(updated.minRating, isNull);
        expect(updated.computerSerial, isNull);
        expect(updated.minBottomTimeMinutes, 30);
        expect(updated.maxBottomTimeMinutes, 60);
      });
    });

    group('apply', () {
      test('returns all dives when no filters are active', () {
        const filter = DiveFilterState();
        final dives = [_makeDive(id: 'd1'), _makeDive(id: 'd2')];

        final result = filter.apply(dives);

        expect(result, hasLength(2));
      });

      test('filters by computerSerial', () {
        const filter = DiveFilterState(computerSerial: 'SN12345');
        final dives = [
          _makeDive(id: 'd1', diveComputerSerial: 'SN12345'),
          _makeDive(id: 'd2', diveComputerSerial: 'SN99999'),
          _makeDive(id: 'd3'), // no serial
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by minRating', () {
        const filter = DiveFilterState(minRating: 3);
        final dives = [
          _makeDive(id: 'd1', rating: 5),
          _makeDive(id: 'd2', rating: 2),
          _makeDive(id: 'd3'), // null rating
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by minBottomTimeMinutes', () {
        const filter = DiveFilterState(minBottomTimeMinutes: 30);
        final dives = [
          _makeDive(id: 'd1', duration: const Duration(minutes: 45)),
          _makeDive(id: 'd2', duration: const Duration(minutes: 20)),
          _makeDive(id: 'd3'), // null duration
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by maxBottomTimeMinutes', () {
        const filter = DiveFilterState(maxBottomTimeMinutes: 30);
        final dives = [
          _makeDive(id: 'd1', duration: const Duration(minutes: 20)),
          _makeDive(id: 'd2', duration: const Duration(minutes: 45)),
          _makeDive(id: 'd3'), // null duration
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by both minBottomTimeMinutes and maxBottomTimeMinutes', () {
        const filter = DiveFilterState(
          minBottomTimeMinutes: 20,
          maxBottomTimeMinutes: 40,
        );
        final dives = [
          _makeDive(id: 'd1', duration: const Duration(minutes: 30)),
          _makeDive(id: 'd2', duration: const Duration(minutes: 10)),
          _makeDive(id: 'd3', duration: const Duration(minutes: 50)),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by customFieldKey', () {
        const filter = DiveFilterState(customFieldKey: 'visibility');
        final dives = [
          _makeDive(
            id: 'd1',
            customFields: [
              const DiveCustomField(
                id: 'cf1',
                key: 'visibility',
                value: 'good',
              ),
            ],
          ),
          _makeDive(id: 'd2'),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by customFieldKey and customFieldValue', () {
        const filter = DiveFilterState(
          customFieldKey: 'visibility',
          customFieldValue: 'good',
        );
        final dives = [
          _makeDive(
            id: 'd1',
            customFields: [
              const DiveCustomField(
                id: 'cf1',
                key: 'visibility',
                value: 'good',
              ),
            ],
          ),
          _makeDive(
            id: 'd2',
            customFields: [
              const DiveCustomField(
                id: 'cf2',
                key: 'visibility',
                value: 'poor',
              ),
            ],
          ),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('customFieldValue match is case-insensitive', () {
        const filter = DiveFilterState(
          customFieldKey: 'visibility',
          customFieldValue: 'GOOD',
        );
        final dives = [
          _makeDive(
            id: 'd1',
            customFields: [
              const DiveCustomField(
                id: 'cf1',
                key: 'visibility',
                value: 'Good',
              ),
            ],
          ),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
      });

      test('filters by startDate and endDate', () {
        final filter = DiveFilterState(
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 3, 31),
        );
        final dives = [
          _makeDive(id: 'd1', dateTime: DateTime(2026, 3, 15)),
          _makeDive(id: 'd2', dateTime: DateTime(2026, 2, 15)),
          _makeDive(id: 'd3', dateTime: DateTime(2026, 4, 15)),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by diveIds', () {
        const filter = DiveFilterState(diveIds: ['d1', 'd3']);
        final dives = [
          _makeDive(id: 'd1'),
          _makeDive(id: 'd2'),
          _makeDive(id: 'd3'),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(2));
        expect(result.map((d) => d.id), containsAll(['d1', 'd3']));
      });

      test('combines multiple filters', () {
        const filter = DiveFilterState(computerSerial: 'SN12345', minRating: 3);
        final dives = [
          _makeDive(id: 'd1', diveComputerSerial: 'SN12345', rating: 5),
          _makeDive(id: 'd2', diveComputerSerial: 'SN12345', rating: 2),
          _makeDive(id: 'd3', diveComputerSerial: 'SN999', rating: 5),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by favoritesOnly', () {
        const filter = DiveFilterState(favoritesOnly: true);
        final dives = [
          _makeDive(id: 'd1', isFavorite: true),
          _makeDive(id: 'd2', isFavorite: false),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by depth range', () {
        const filter = DiveFilterState(minDepth: 10.0, maxDepth: 30.0);
        final dives = [
          _makeDive(id: 'd1', maxDepth: 20.0),
          _makeDive(id: 'd2', maxDepth: 5.0),
          _makeDive(id: 'd3', maxDepth: 40.0),
          _makeDive(id: 'd4'), // null depth
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by tripId', () {
        const filter = DiveFilterState(tripId: 'trip-1');
        final dives = [
          _makeDive(id: 'd1', tripId: 'trip-1'),
          _makeDive(id: 'd2', tripId: 'trip-2'),
          _makeDive(id: 'd3'),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });

      test('filters by diveTypeId', () {
        const filter = DiveFilterState(diveTypeId: 'technical');
        final dives = [
          _makeDive(id: 'd1', diveTypeId: 'technical'),
          _makeDive(id: 'd2', diveTypeId: 'recreational'),
        ];

        final result = filter.apply(dives);

        expect(result, hasLength(1));
        expect(result.first.id, 'd1');
      });
    });
  });
}
