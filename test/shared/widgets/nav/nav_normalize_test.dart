import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

void main() {
  group('normalizeNavPrimaryIds', () {
    test('empty stored -> defaults', () {
      expect(
        normalizeNavPrimaryIds(
          stored: const [],
          movableIds: movableNavIds,
          defaults: kDefaultPrimaryIds,
        ),
        kDefaultPrimaryIds,
      );
    });

    test('already-valid stored list is returned unchanged', () {
      expect(
        normalizeNavPrimaryIds(
          stored: const ['sites', 'dives', 'trips'],
          movableIds: movableNavIds,
          defaults: kDefaultPrimaryIds,
        ),
        ['sites', 'dives', 'trips'],
      );
    });

    test('unknown ids are dropped and slot is padded from defaults', () {
      expect(
        normalizeNavPrimaryIds(
          stored: const ['not-a-real-id', 'sites'],
          movableIds: movableNavIds,
          defaults: kDefaultPrimaryIds,
        ),
        // 'sites' kept, then pad with defaults skipping 'sites'
        ['sites', 'dives', 'trips'],
      );
    });

    test('duplicates are removed while preserving first-occurrence order', () {
      expect(
        normalizeNavPrimaryIds(
          stored: const ['sites', 'sites', 'dives'],
          movableIds: movableNavIds,
          defaults: kDefaultPrimaryIds,
        ),
        ['sites', 'dives', 'trips'],
      );
    });

    test('too-long stored list is truncated to first 3 valid ids', () {
      expect(
        normalizeNavPrimaryIds(
          stored: const [
            'equipment',
            'buddies',
            'statistics',
            'planning',
            'transfer',
          ],
          movableIds: movableNavIds,
          defaults: kDefaultPrimaryIds,
        ),
        ['equipment', 'buddies', 'statistics'],
      );
    });

    test('pinned ids (dashboard, more) are dropped and padded', () {
      expect(
        normalizeNavPrimaryIds(
          stored: const ['dashboard', 'more', 'equipment'],
          movableIds: movableNavIds,
          defaults: kDefaultPrimaryIds,
        ),
        ['equipment', 'dives', 'sites'],
      );
    });

    test('returns exactly 3 ids in all cases', () {
      for (final input in const [
        <String>[],
        ['a'],
        ['a', 'b'],
        ['a', 'b', 'c'],
        ['a', 'b', 'c', 'd', 'e'],
      ]) {
        final result = normalizeNavPrimaryIds(
          stored: input,
          movableIds: movableNavIds,
          defaults: kDefaultPrimaryIds,
        );
        expect(result.length, 3, reason: 'input=$input');
      }
    });

    test('all returned ids are in movableIds', () {
      final result = normalizeNavPrimaryIds(
        stored: const ['dashboard', 'more', 'unknown'],
        movableIds: movableNavIds,
        defaults: kDefaultPrimaryIds,
      );
      for (final id in result) {
        expect(movableNavIds.contains(id), isTrue);
      }
    });
  });
}
