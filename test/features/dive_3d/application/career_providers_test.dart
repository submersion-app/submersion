import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/career_providers.dart';
import 'package:submersion/features/dive_3d/domain/career/career_geometry_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

import '../../../helpers/mock_providers.dart';

DiveSite site(String id) => DiveSite(id: id, name: 'Site $id');

Dive diveAt(
  String id,
  DateTime start, {
  String? siteId,
  double maxDepth = 20,
}) => Dive(
  id: id,
  dateTime: start,
  entryTime: start,
  exitTime: start.add(const Duration(minutes: 30)),
  maxDepth: maxDepth,
  site: siteId == null ? null : site(siteId),
);

SourceProfile profile() => const SourceProfile(
  sourceId: 'src',
  computerId: null,
  isEdited: false,
  points: [
    DiveProfilePoint(timestamp: 0, depth: 0),
    DiveProfilePoint(timestamp: 600, depth: 18),
    DiveProfilePoint(timestamp: 1200, depth: 0),
  ],
);

Future<ProviderContainer> makeContainer(List<Dive> dives) async {
  final base = await getBaseOverrides();
  final container = ProviderContainer(
    overrides: [
      ...base,
      divesProvider.overrideWith((ref) async => dives),
      for (final d in dives)
        sourceProfilesProvider(
          d.id,
        ).overrideWith((ref) async => {'src': profile()}),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  final base = DateTime.utc(2026, 1, 1);

  test('site query gathers only that site\'s dives, oldest-first', () async {
    final dives = [
      diveAt('a', base, siteId: 's1'),
      diveAt('b', base.add(const Duration(days: 1)), siteId: 's2'),
      diveAt('c', base.add(const Duration(days: 2)), siteId: 's1'),
    ];
    final container = await makeContainer(dives);
    final data = await container.read(
      careerSceneDataProvider(careerSiteQuery('s1')).future,
    );
    expect(data, isNotNull);
    expect(data!.dives.length, 2);
    expect(data.dives.first.date.isBefore(data.dives.last.date), isTrue);
  });

  test('date range query filters by entry time', () async {
    final dives = [
      diveAt('a', base),
      diveAt('b', base.add(const Duration(days: 5))),
      diveAt('c', base.add(const Duration(days: 30))),
    ];
    final container = await makeContainer(dives);
    final data = await container.read(
      careerSceneDataProvider(
        careerRangeQuery(base, base.add(const Duration(days: 10))),
      ).future,
    );
    expect(data!.dives.length, 2);
  });

  test('cap keeps the newest dives', () async {
    final dives = [
      for (var i = 0; i < 5; i++)
        diveAt('d$i', base.add(Duration(days: i)), siteId: 's1'),
    ];
    final container = await makeContainer(dives);
    final data = await container.read(
      careerSceneDataProvider(careerSiteQuery('s1', cap: 3)).future,
    );
    expect(data!.dives.length, 3);
    // Oldest kept is d2 (days 2,3,4 are the newest three).
    expect(data.dives.first.date, base.add(const Duration(days: 2)));
  });

  test('geometry provider builds a scene from the set', () async {
    final container = await makeContainer([
      diveAt('a', base, siteId: 's1'),
      diveAt('b', base.add(const Duration(days: 1)), siteId: 's1'),
    ]);
    final scene = await container.read(
      careerGeometryProvider((
        query: careerSiteQuery('s1'),
        colorMode: CareerColorMode.recency,
      )).future,
    );
    expect(scene, isNotNull);
    expect(scene!.layers.length, 2);
  });

  test('null when no dive matches', () async {
    final container = await makeContainer([diveAt('a', base, siteId: 's2')]);
    final data = await container.read(
      careerSceneDataProvider(careerSiteQuery('nope')).future,
    );
    expect(data, isNull);
  });
}
