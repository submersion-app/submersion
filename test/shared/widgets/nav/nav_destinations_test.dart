import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

void main() {
  group('kNavDestinations', () {
    test('has exactly 18 entries (17 routable + more sentinel)', () {
      expect(kNavDestinations.length, 18);
    });

    test('exactly two entries are pinned (dashboard and more)', () {
      final pinned = kNavDestinations.where((d) => d.isPinned).toList();
      expect(pinned.length, 2);
      expect(pinned.map((d) => d.id).toSet(), {'dashboard', 'more'});
    });

    test('ids are unique', () {
      final ids = kNavDestinations.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('ids match kebab-case pattern', () {
      final pattern = RegExp(r'^[a-z][a-z-]*$');
      for (final d in kNavDestinations) {
        expect(pattern.hasMatch(d.id), isTrue, reason: 'bad id: ${d.id}');
      }
    });

    test('contains the expected 17 routable ids plus more sentinel', () {
      expect(kNavDestinations.map((d) => d.id).toList(), [
        'dashboard',
        'dives',
        'sites',
        'trips',
        'media',
        'equipment',
        'buddies',
        'dive-centers',
        'certifications',
        'courses',
        'species',
        'statistics',
        'connections',
        'planning',
        'transfer',
        'gps-log',
        'settings',
        'more',
      ]);
    });

    test(
      'routable destinations have non-empty route; more sentinel has empty route',
      () {
        for (final d in kNavDestinations) {
          if (d.id == 'more') {
            expect(d.route, '');
          } else {
            expect(d.route, isNotEmpty);
          }
        }
      },
    );
  });

  group('movableNavIds', () {
    test('is kNavDestinations minus dashboard and more, in order', () {
      expect(movableNavIds, [
        'dives',
        'sites',
        'trips',
        'media',
        'equipment',
        'buddies',
        'dive-centers',
        'certifications',
        'courses',
        'species',
        'statistics',
        'connections',
        'planning',
        'transfer',
        'gps-log',
        'settings',
      ]);
    });

    test('has exactly 16 entries', () {
      expect(movableNavIds.length, 16);
    });

    test('connections is routable and movable', () {
      final d = kNavDestinations.singleWhere((d) => d.id == 'connections');
      expect(d.route, '/connections');
      expect(d.isPinned, isFalse);
      expect(movableNavIds, contains('connections'));
    });
  });
}
