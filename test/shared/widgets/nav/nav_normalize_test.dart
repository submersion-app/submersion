import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';
import 'package:submersion/shared/widgets/nav/nav_id_aliases.dart';

void main() {
  group('normalizeNavOrder', () {
    test('empty stored -> canonical movable order', () {
      expect(
        normalizeNavOrder(stored: const [], movableIds: movableNavIds),
        movableNavIds,
      );
    });

    test('a fully specified stored order is returned unchanged', () {
      final reversed = movableNavIds.reversed.toList();
      expect(
        normalizeNavOrder(stored: reversed, movableIds: movableNavIds),
        reversed,
      );
    });

    test('an old-schema 3-id value keeps those slots and appends the rest', () {
      // Values written before the order was widened held only the three phone
      // bottom-bar slots. Those must stay slots 1-3 so the bar survives the
      // upgrade unchanged.
      final result = normalizeNavOrder(
        stored: const ['equipment', 'buddies', 'insights'],
        movableIds: movableNavIds,
      );

      expect(result.take(3).toList(), ['equipment', 'buddies', 'insights']);
      expect(
        result.skip(3).toList(),
        movableNavIds
            .where(
              (id) => !const ['equipment', 'buddies', 'insights'].contains(id),
            )
            .toList(),
      );
    });

    test('unknown ids are dropped', () {
      final result = normalizeNavOrder(
        stored: const ['not-a-real-id', 'sites'],
        movableIds: movableNavIds,
      );

      expect(result.first, 'sites');
      expect(result, isNot(contains('not-a-real-id')));
    });

    test('duplicates are removed while preserving first-occurrence order', () {
      final result = normalizeNavOrder(
        stored: const ['sites', 'sites', 'dives'],
        movableIds: movableNavIds,
      );

      expect(result.take(2).toList(), ['sites', 'dives']);
      expect(result.where((id) => id == 'sites').length, 1);
    });

    test('pinned ids (dashboard, more) are dropped', () {
      final result = normalizeNavOrder(
        stored: const ['dashboard', 'more', 'equipment'],
        movableIds: movableNavIds,
      );

      expect(result.first, 'equipment');
      expect(result, isNot(contains('dashboard')));
      expect(result, isNot(contains('more')));
    });

    test('returns every movable id exactly once for any input', () {
      for (final input in const [
        <String>[],
        ['sites'],
        ['dashboard', 'more', 'unknown'],
        ['sites', 'sites', 'sites'],
        ['gps-log', 'settings', 'species', 'dives'],
      ]) {
        final result = normalizeNavOrder(
          stored: input,
          movableIds: movableNavIds,
        );
        expect(
          result.toSet(),
          movableNavIds.toSet(),
          reason: 'input=$input dropped or invented ids',
        );
        expect(
          result.length,
          movableNavIds.length,
          reason: 'input=$input produced duplicates',
        );
      }
    });

    test('kDefaultPrimaryIds is the first three of the default order', () {
      expect(kDefaultPrimaryIds, kDefaultNavOrder.take(3).toList());
      expect(kDefaultPrimaryIds, ['dives', 'sites', 'trips']);
    });
  });

  group('normalizeNavOrder with shortcuts (#2936)', () {
    const known = ['shortcut:gas-blender', 'shortcut:insights-gas'];

    test('known shortcuts keep their stored position', () {
      final result = normalizeNavOrder(
        stored: ['shortcut:gas-blender', 'dives'],
        movableIds: movableNavIds,
        shortcutOrderIds: known,
      );
      expect(result.take(2), ['shortcut:gas-blender', 'dives']);
      expect(
        result.where((id) => !id.startsWith('shortcut:')).toSet(),
        movableNavIds.toSet(),
      );
    });

    test('unknown and duplicate shortcuts are dropped', () {
      final result = normalizeNavOrder(
        stored: [
          'shortcut:retired',
          'shortcut:gas-blender',
          'shortcut:gas-blender',
        ],
        movableIds: movableNavIds,
        shortcutOrderIds: known,
      );
      expect(result.where((id) => id.startsWith('shortcut:')), [
        'shortcut:gas-blender',
      ]);
    });

    test('missing shortcuts are never appended', () {
      final result = normalizeNavOrder(
        stored: const [],
        movableIds: movableNavIds,
        shortcutOrderIds: known,
      );
      expect(result, movableNavIds);
    });

    test('legacy ids pass shortcut ids through untouched', () {
      expect(withLegacyNavIds(['shortcut:gas-blender', 'insights']), [
        'shortcut:gas-blender',
        'insights',
        'statistics',
      ]);
    });
  });
}
