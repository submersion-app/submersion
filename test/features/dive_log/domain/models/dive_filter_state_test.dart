import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';

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
        expect(filter.decoOnly, isNull);
        expect(filter.noBuddyOnly, isNull);
        expect(filter.tagIds, isEmpty);
        expect(filter.weekdays, isEmpty);
        expect(filter.equipmentIds, isEmpty);
        expect(filter.buddyNameFilter, isNull);
        expect(filter.buddyId, isNull);
        expect(filter.diveIds, isEmpty);
        expect(filter.minO2Percent, isNull);
        expect(filter.maxO2Percent, isNull);
        expect(filter.minRating, isNull);
        expect(filter.minBottomTimeMinutes, isNull);
        expect(filter.maxBottomTimeMinutes, isNull);
        expect(filter.computerId, isNull);
        expect(filter.customFieldKey, isNull);
        expect(filter.customFieldValue, isNull);
      });
    });

    group('hasActiveFilters', () {
      test('returns false for default empty state', () {
        const filter = DiveFilterState();

        expect(filter.hasActiveFilters, isFalse);
      });

      test('returns true when computerId is set', () {
        const filter = DiveFilterState(computerId: 'computer-a');

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

      test('returns true when decoOnly is true', () {
        const filter = DiveFilterState(decoOnly: true);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when decoOnly is false', () {
        const filter = DiveFilterState(decoOnly: false);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when noBuddyOnly is true', () {
        const filter = DiveFilterState(noBuddyOnly: true);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns false when noBuddyOnly is false', () {
        const filter = DiveFilterState(noBuddyOnly: false);

        expect(filter.hasActiveFilters, isFalse);
      });

      test('returns true when diveIds is non-empty', () {
        const filter = DiveFilterState(diveIds: ['d1', 'd2']);

        expect(filter.hasActiveFilters, isTrue);
      });

      test('returns true when weekdays is non-empty', () {
        const filter = DiveFilterState(weekdays: [1, 3]);

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
      test('sets computerId', () {
        const original = DiveFilterState();

        final updated = original.copyWith(computerId: 'computer-a');

        expect(updated.computerId, 'computer-a');
      });

      test('preserves computerId when not specified', () {
        const original = DiveFilterState(computerId: 'computer-a');

        final updated = original.copyWith(minRating: 3);

        expect(updated.computerId, 'computer-a');
        expect(updated.minRating, 3);
      });

      test('clears computerId with clearComputerId', () {
        const original = DiveFilterState(computerId: 'computer-a');

        final updated = original.copyWith(clearComputerId: true);

        expect(updated.computerId, isNull);
      });

      test('clearComputerId takes precedence over new value', () {
        const original = DiveFilterState(computerId: 'computer-a');

        final updated = original.copyWith(
          computerId: 'computer-b',
          clearComputerId: true,
        );

        expect(updated.computerId, isNull);
      });

      test('sets decoOnly', () {
        const original = DiveFilterState();

        final updated = original.copyWith(decoOnly: true);

        expect(updated.decoOnly, isTrue);
      });

      test('clears decoOnly with clearDecoOnly', () {
        const original = DiveFilterState(decoOnly: false);

        final updated = original.copyWith(clearDecoOnly: true);

        expect(updated.decoOnly, isNull);
      });

      test('sets noBuddyOnly', () {
        const original = DiveFilterState();

        final updated = original.copyWith(noBuddyOnly: true);

        expect(updated.noBuddyOnly, isTrue);
      });

      test('clears noBuddyOnly with clearNoBuddyOnly', () {
        const original = DiveFilterState(noBuddyOnly: true);

        final updated = original.copyWith(clearNoBuddyOnly: true);

        expect(updated.noBuddyOnly, isNull);
      });

      test('sets weekdays', () {
        const original = DiveFilterState();

        final updated = original.copyWith(weekdays: [1, 2]);

        expect(updated.weekdays, [1, 2]);
      });

      test('clears weekdays with clearWeekdays', () {
        const original = DiveFilterState(weekdays: [1, 2]);

        final updated = original.copyWith(clearWeekdays: true);

        expect(updated.weekdays, isEmpty);
      });

      test('sets and clears multiple fields simultaneously', () {
        const original = DiveFilterState(
          minRating: 3,
          computerId: 'computer-a',
          minBottomTimeMinutes: 30,
        );

        final updated = original.copyWith(
          clearMinRating: true,
          maxBottomTimeMinutes: 60,
          clearComputerId: true,
        );

        expect(updated.minRating, isNull);
        expect(updated.computerId, isNull);
        expect(updated.minBottomTimeMinutes, 30);
        expect(updated.maxBottomTimeMinutes, 60);
      });
    });

    group('equality', () {
      test('two filters with the same axes are equal', () {
        DiveFilterState make() => DiveFilterState(
          startDate: DateTime(2025, 1, 1),
          tagIds: const ['a', 'b'],
          weekdays: const [1],
          minDepth: 18,
          noBuddyOnly: true,
          query: ConditionNode(FieldPath(['weights']), QueryOp.isEmpty, null),
        );
        expect(make(), equals(make()));
        expect(make().hashCode, make().hashCode);
        expect(make(), isNot(equals(make().copyWith(minDepth: 19))));
        expect(
          make(),
          isNot(equals(make().copyWith(tagIds: const ['b', 'a']))),
          reason: 'list order is part of the value',
        );
        expect(const DiveFilterState(), const DiveFilterState());
      });
    });

    group('query (#2365)', () {
      test('copyWith sets and clears the advanced query', () {
        final node = ConditionNode(
          FieldPath(['weights']),
          QueryOp.isEmpty,
          null,
        );
        final withQuery = const DiveFilterState().copyWith(query: node);
        expect(withQuery.query, node);
        expect(withQuery.hasActiveFilters, isTrue);
        expect(withQuery.copyWith(clearQuery: true).query, isNull);
        expect(withQuery.copyWith(clearQuery: true).hasActiveFilters, isFalse);
      });
    });
  });
}
