import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

void main() {
  group('kNavDestinations', () {
    test('has exactly 15 entries (14 routable + more sentinel)', () {
      expect(kNavDestinations.length, 15);
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

    test('contains the expected 14 routable ids plus more sentinel', () {
      expect(kNavDestinations.map((d) => d.id).toList(), [
        'dashboard',
        'dives',
        'sites',
        'trips',
        'equipment',
        'buddies',
        'dive-centers',
        'certifications',
        'courses',
        'statistics',
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
        'equipment',
        'buddies',
        'dive-centers',
        'certifications',
        'courses',
        'statistics',
        'planning',
        'transfer',
        'gps-log',
        'settings',
      ]);
    });

    test('has exactly 13 entries', () {
      expect(movableNavIds.length, 13);
    });
  });
}
