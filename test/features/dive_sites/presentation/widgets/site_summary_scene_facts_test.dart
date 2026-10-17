import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_summary_scene_facts.dart';

/// The library site_summary_widget_test.dart pins the details view with.
final library = <SiteWithDiveCount>[
  SiteWithDiveCount(
    site: const DiveSite(
      id: 'a',
      name: 'Blue Hole',
      country: 'Malta',
      rating: 5,
    ),
    diveCount: 9,
    lastDivedAt: DateTime(2026, 8, 1),
  ),
  SiteWithDiveCount(
    site: const DiveSite(
      id: 'b',
      name: 'Cathedral',
      country: 'Malta',
      rating: 4,
    ),
    diveCount: 3,
    lastDivedAt: DateTime(2026, 9, 1),
  ),
  SiteWithDiveCount(
    site: const DiveSite(id: 'c', name: 'Wreck Alley', country: 'Mexico'),
    diveCount: 1,
    lastDivedAt: DateTime(2025, 2, 2),
  ),
  const SiteWithDiveCount(
    site: DiveSite(id: 'd', name: 'Someday Reef', country: 'Egypt'),
    diveCount: 0,
  ),
  const SiteWithDiveCount(
    site: DiveSite(id: 'e', name: 'Wishlist Wall', country: 'Egypt'),
    diveCount: 0,
  ),
];

void main() {
  test('counts sites, trimmed countries, GPS and never-dived sites as the '
      'widget does', () {
    final facts = SiteSceneFacts.from([
      ...library,
      const SiteWithDiveCount(
        site: DiveSite(
          id: 'f',
          name: 'Gozo Arch',
          country: 'Malta ',
          location: GeoPoint(36.05, 14.19),
        ),
        diveCount: 0,
      ),
      const SiteWithDiveCount(
        site: DiveSite(id: 'g', name: 'Nowhere', country: '  '),
        diveCount: 0,
      ),
    ]);

    expect(facts.siteCount, 7);
    expect(facts.countryCount, 3);
    expect(facts.withGps, 1);
    expect(facts.notDived, 4);
  });

  test('picks the most dived, best rated and last dived sites', () {
    final facts = SiteSceneFacts.from(library);

    expect(facts.mostDived?.site.id, 'a');
    expect(facts.bestRated?.site.id, 'a');
    expect(facts.lastDived?.site.id, 'b');
    expect([for (final s in facts.marked) s.site.id], ['a', 'b']);
  });

  test('one site in every role is marked once', () {
    final facts = SiteSceneFacts.from([library.first]);

    expect(facts.marked, hasLength(1));
  });

  test('a library with no dives and no ratings has no picks', () {
    final facts = SiteSceneFacts.from(library.sublist(3));

    expect(facts.mostDived, isNull);
    expect(facts.bestRated, isNull);
    expect(facts.lastDived, isNull);
    expect(facts.marked, isEmpty);
  });
}
