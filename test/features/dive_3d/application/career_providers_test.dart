import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_3d/application/career_providers.dart';
import 'package:submersion/features/dive_3d/domain/career/career_dive_shape.dart';
import 'package:submersion/features/dive_3d/domain/career/career_geometry_service.dart';
import 'package:submersion/features/dive_3d/domain/career/career_scene_data.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import 'career_terrain_fixture.dart';

/// The career terrain's set, read from the database the way the page reads
/// it: a bounded metadata query and one batched primary-profile read
/// (issue #3857), with the set semantics the in-memory filter had before.
void main() {
  late AppDatabase db;
  late CareerTerrainFixture fx;

  setUp(() async {
    db = await setUpTestDatabase();
    fx = CareerTerrainFixture(db);
    await fx.addSite('s1');
    await fx.addSite('s2');
  });

  tearDown(tearDownTestDatabase);

  final base = DateTime.utc(2026, 1, 1, 9);

  Future<void> diveAt(
    String id,
    DateTime start, {
    String? siteId,
    String? diverId,
    bool withProfile = true,
    bool withEntryTime = true,
    double maxDepth = 18,
  }) async {
    await fx.addDive(
      id,
      start,
      siteId: siteId,
      diverId: diverId,
      withEntryTime: withEntryTime,
    );
    if (withProfile) await fx.addProfile(id, maxDepth: maxDepth);
  }

  ProviderContainer makeContainer({String? diverId}) {
    final diver = MockCurrentDiverIdNotifier();
    if (diverId != null) diver.setCurrentDiver(diverId);
    final container = ProviderContainer(
      overrides: [currentDiverIdProvider.overrideWith((ref) => diver)],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<CareerSceneData?> sceneFor(CareerQuery query, {String? diverId}) =>
      makeContainer(
        diverId: diverId,
      ).read(careerSceneDataProvider(query).future);

  test('site query gathers only that site\'s dives, oldest-first', () async {
    await diveAt('a', base, siteId: 's1');
    await diveAt('b', base.add(const Duration(days: 1)), siteId: 's2');
    await diveAt('c', base.add(const Duration(days: 2)), siteId: 's1');

    final data = await sceneFor(careerSiteQuery('s1'));

    expect(data, isNotNull);
    expect(
      [for (final d in data!.dives) d.date],
      [base, base.add(const Duration(days: 2))],
    );
    expect([for (final d in data.dives) d.index], [0, 1]);
  });

  test('date range query filters by start, falling back to the dive date '
      'when the entry time is unknown', () async {
    await diveAt('a', base);
    await diveAt('b', base.add(const Duration(days: 5)), withEntryTime: false);
    await diveAt('c', base.add(const Duration(days: 30)));

    final data = await sceneFor(
      careerRangeQuery(base, base.add(const Duration(days: 10))),
    );

    expect(
      [for (final d in data!.dives) d.date],
      [base, base.add(const Duration(days: 5))],
    );
  });

  test('cap keeps the newest dives', () async {
    for (var i = 0; i < 5; i++) {
      await diveAt('d$i', base.add(Duration(days: i)), siteId: 's1');
    }

    final data = await sceneFor(careerSiteQuery('s1', cap: 3));

    expect(data!.dives.length, 3);
    // Oldest kept is d2 (days 2,3,4 are the newest three).
    expect(data.dives.first.date, base.add(const Duration(days: 2)));
  });

  test('only the active diver\'s dives are in the set', () async {
    await fx.addDiver('me');
    await fx.addDiver('buddy');
    await diveAt('mine', base, siteId: 's1', diverId: 'me');
    await diveAt(
      'theirs',
      base.add(const Duration(days: 1)),
      siteId: 's1',
      diverId: 'buddy',
    );

    final mine = await sceneFor(careerSiteQuery('s1'), diverId: 'me');
    expect([for (final d in mine!.dives) d.date], [base]);

    final everyone = await sceneFor(careerSiteQuery('s1'));
    expect(everyone!.dives.length, 2, reason: 'no diver selected: every dive');
  });

  test('a dive without a profile or with a single sample is skipped and the '
      'rest re-indexed', () async {
    await diveAt('manual', base, siteId: 's1', withProfile: false);
    await fx.addDive(
      'one-sample',
      base.add(const Duration(days: 1)),
      siteId: 's1',
    );
    await fx.addProfile(
      'one-sample',
      samples: const [ProfileSample(timestamp: 0, depth: 5)],
    );
    await diveAt('full', base.add(const Duration(days: 2)), siteId: 's1');

    final data = await sceneFor(careerSiteQuery('s1'));

    expect(data!.dives.length, 1);
    expect(data.dives.single.index, 0);
    expect(data.dives.single.date, base.add(const Duration(days: 2)));
  });

  test('null when the matched dives have nothing to draw', () async {
    await diveAt('manual', base, siteId: 's1', withProfile: false);

    expect(await sceneFor(careerSiteQuery('s1')), isNull);
  });

  test('a dense profile is reduced to the mini-profile budget, keeping its '
      'endpoints and deepest sample', () async {
    await fx.addDive('deep', base, siteId: 's1');
    await fx.addProfile('deep', samples: denseProfile(maxDepth: 30));

    final data = await sceneFor(careerSiteQuery('s1'));
    final dive = data!.dives.single;

    expect(dive.times.length, lessThanOrEqualTo(kCareerPointsPerDive));
    expect(dive.times.length, dive.depths.length);
    expect(dive.times.first, 0);
    expect(dive.times.last, 599);
    expect(dive.depths.reduce((a, b) => a > b ? a : b), 30);
    expect(dive.maxDepthMeters, 30);
  });

  test(
    'draws the primary source\'s profile, not another computer\'s',
    () async {
      await fx.addComputer('dc-a');
      await fx.addComputer('dc-b');
      await fx.addDive('two', base, siteId: 's1');
      await fx.addDataSource(
        'src-a',
        diveId: 'two',
        computerId: 'dc-a',
        isPrimary: true,
      );
      await fx.addDataSource(
        'src-b',
        diveId: 'two',
        computerId: 'dc-b',
        isPrimary: false,
        createdAt: DateTime.utc(2026, 1, 2),
      );
      await fx.addProfile('two', computerId: 'dc-a', maxDepth: 20);
      await fx.addProfile(
        'two',
        computerId: 'dc-b',
        isPrimary: false,
        maxDepth: 40,
      );

      final data = await sceneFor(careerSiteQuery('s1'));

      expect(data!.dives.single.maxDepthMeters, 20);
    },
  );

  test('geometry provider builds a scene from the set', () async {
    await diveAt('a', base, siteId: 's1');
    await diveAt('b', base.add(const Duration(days: 1)), siteId: 's1');

    final scene = await makeContainer().read(
      careerGeometryProvider((
        query: careerSiteQuery('s1'),
        colorMode: CareerColorMode.recency,
      )).future,
    );

    expect(scene, isNotNull);
    expect(scene!.layers.length, 2);
  });

  test('null when no dive matches', () async {
    await diveAt('a', base, siteId: 's2');

    expect(await sceneFor(careerSiteQuery('nope')), isNull);
  });
}
