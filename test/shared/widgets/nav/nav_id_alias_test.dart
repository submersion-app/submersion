import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

void main() {
  group('renamed nav ids', () {
    // A build that already ships the new id; kRenamedNavIds records
    // statistics -> insights.
    const movable = ['dives', 'insights', 'sites', 'gear'];

    test('a renamed id keeps its stored slot under the new id', () {
      expect(
        normalizeNavOrder(
          stored: const ['sites', 'statistics', 'dives'],
          movableIds: movable,
        ),
        ['sites', 'insights', 'dives', 'gear'],
      );
    });

    test('the old and new id together collapse to one entry', () {
      expect(
        normalizeNavOrder(
          stored: const ['statistics', 'sites', 'insights'],
          movableIds: movable,
        ),
        ['insights', 'sites', 'dives', 'gear'],
      );
      expect(
        normalizeNavOrder(
          stored: const ['insights', 'sites', 'statistics'],
          movableIds: movable,
        ),
        ['insights', 'sites', 'dives', 'gear'],
      );
    });

    test('an alias never replaces an id the build still knows', () {
      // An older build that still ships the old id reads it as itself.
      const olderBuild = ['dives', 'statistics', 'sites'];
      expect(
        normalizeNavOrder(
          stored: const ['statistics', 'dives'],
          movableIds: olderBuild,
        ),
        ['statistics', 'dives', 'sites'],
      );
    });

    test('an unknown id with no alias is still dropped', () {
      expect(
        normalizeNavOrder(
          stored: const ['not-a-real-id', 'sites'],
          movableIds: movable,
        ),
        ['sites', 'dives', 'insights', 'gear'],
      );
    });
  });
}
