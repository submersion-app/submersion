import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/nav/nav_destinations.dart';

/// Locks the wide-screen rail contract. Before the rail was driven from
/// [kNavDestinations] it hardcoded these 14 destinations, and two hardcoded
/// switch statements mapped index <-> route. This test encodes that exact
/// mapping so the refactor cannot silently reorder or reroute navigation.
void main() {
  test('kNavDestinations order matches the wide-screen rail contract', () {
    final rail = kNavDestinations.where((d) => d.id != 'more').toList();
    final expected = <(String, String)>[
      ('dashboard', '/dashboard'),
      ('dives', '/dives'),
      ('sites', '/sites'),
      ('trips', '/trips'),
      ('equipment', '/equipment'),
      ('buddies', '/buddies'),
      ('dive-centers', '/dive-centers'),
      ('certifications', '/certifications'),
      ('courses', '/courses'),
      ('statistics', '/statistics'),
      ('planning', '/planning'),
      ('transfer', '/transfer'),
      ('gps-log', '/gps-log'),
      ('settings', '/settings'),
    ];
    expect(rail.length, expected.length);
    for (var i = 0; i < expected.length; i++) {
      expect(
        (rail[i].id, rail[i].route),
        expected[i],
        reason: 'rail index $i must map to ${expected[i]}',
      );
    }
  });
}
