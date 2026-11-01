import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_3d/application/career_providers.dart';
import 'package:submersion/features/dive_3d/domain/career/career_scene_data.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import 'career_terrain_fixture.dart';

/// Counts the SQL a career terrain costs to open (issue #3857).
///
/// The terrain draws a site's newest dives as depth ribbons. It used to get
/// there by loading the whole logbook through `divesProvider`, hydrating
/// tanks, sites, trips, gear and tags for every dive the diver ever logged,
/// and then reading each kept dive's full source profiles one round trip at
/// a time. These tests pin the bounded shape instead: one metadata read of
/// the dives the query names, one batched series read, and nothing about
/// the dives the terrain does not draw.
///
/// Statements are counted, never log lines: a statement with a long `IN`
/// list reaches the print hook as more than one line.
void main() {
  late AppDatabase db;
  late CareerTerrainFixture fx;

  setUp(() async {
    db = await setUpStatementLoggingTestDatabase();
    fx = CareerTerrainFixture(db);
    await withoutStatementLog(() async {
      await fx.addSite('reef');
      await fx.addSite('elsewhere');
    });
  });

  tearDown(tearDownTestDatabase);

  final base = DateTime.utc(2026, 3, 1, 9);

  /// Three dives at the reef, each with a profile, as the terrain's set.
  Future<void> seedReefDives() => withoutStatementLog(() async {
    for (var i = 0; i < 3; i++) {
      final id = 'reef-$i';
      await fx.addDive(
        id,
        base.add(Duration(days: i)),
        siteId: 'reef',
        diveNumber: i + 1,
      );
      await fx.addProfile(id, samples: denseProfile(maxDepth: 20 + i * 2));
    }
  });

  /// [count] dives at another site, each with a profile: the rest of the
  /// logbook, which the reef's terrain never draws.
  Future<void> seedUnrelatedDives(int count) => withoutStatementLog(() async {
    for (var i = 0; i < count; i++) {
      final id = 'other-$i';
      await fx.addDive(
        id,
        base.add(Duration(days: 100 + i)),
        siteId: 'elsewhere',
        diveNumber: 100 + i,
      );
      await fx.addProfile(id, samples: denseProfile());
    }
  });

  /// Opens the reef's terrain and returns the statements drift sent for it.
  Future<List<String>> statementsToOpenReefTerrain() async {
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final logged = <String>[];
    CareerSceneData? data;
    await runZoned(
      () async {
        data = await container.read(
          careerSceneDataProvider(careerSiteQuery('reef')).future,
        );
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );
    expect(data, isNotNull, reason: 'the reef has three dives with profiles');
    expect(data!.dives.length, 3);
    return logged.where((l) => l.startsWith('Drift: Sent')).toList();
  }

  Iterable<String> reading(List<String> sent, String table) =>
      sent.where((s) => RegExp('FROM "?$table"?\\b').hasMatch(s));

  test('opening a site terrain reads its dives once and their series once, '
      'hydrating nothing the terrain does not draw', () async {
    await seedReefDives();
    await seedUnrelatedDives(4);

    final sent = await statementsToOpenReefTerrain();

    expect(
      reading(sent, 'dive_profile_series'),
      hasLength(1),
      reason:
          'the kept dives\' series come back in one batched statement, not '
          'one round trip per dive',
    );
    expect(
      reading(sent, 'dives'),
      hasLength(1),
      reason: 'one metadata read of the dives the query names',
    );
    for (final table in [
      'dive_tanks',
      'dive_tags',
      'dive_equipment',
      'trips',
    ]) {
      expect(
        reading(sent, table),
        isEmpty,
        reason: 'the terrain draws no $table, so it must not hydrate them',
      );
    }
  });

  test('a larger logbook outside the site costs no extra statement', () async {
    await seedReefDives();
    final small = await statementsToOpenReefTerrain();

    await seedUnrelatedDives(40);
    final large = await statementsToOpenReefTerrain();

    expect(large.length, small.length);
    expect(
      reading(large, 'dives'),
      everyElement(contains('site_id')),
      reason: 'the dive read is bounded to the site, never the whole logbook',
    );
  });
}
