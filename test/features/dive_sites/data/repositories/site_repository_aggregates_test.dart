import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

Future<void> _insertDive(
  db.AppDatabase database, {
  required String id,
  required String siteId,
  required DateTime at,
  double? maxDepth,
  int? runtime,
  int? bottomTime,
}) async {
  final ms = at.millisecondsSinceEpoch;
  await database
      .into(database.dives)
      .insert(
        db.DivesCompanion(
          id: Value(id),
          diveDateTime: Value(ms),
          siteId: Value(siteId),
          maxDepth: Value(maxDepth),
          runtime: Value(runtime),
          bottomTime: Value(bottomTime),
          createdAt: Value(ms),
          updatedAt: Value(ms),
        ),
      );
}

Future<void> _insertFeature(
  db.AppDatabase database, {
  required String id,
  required String siteId,
  required String type,
  required int createdAt,
}) async {
  await database
      .into(database.siteFeatures)
      .insert(
        db.SiteFeaturesCompanion(
          id: Value(id),
          siteId: Value(siteId),
          type: Value(type),
          latitude: const Value(0),
          longitude: const Value(0),
          createdAt: Value(createdAt),
          updatedAt: Value(createdAt),
        ),
      );
}

void main() {
  late SiteRepository repository;
  late db.AppDatabase database;

  setUp(() async {
    await setUpTestDatabase();
    repository = SiteRepository();
    database = DatabaseService.instance.database;
    await repository.createSite(const DiveSite(id: 'site-a', name: 'A'));
    await repository.createSite(const DiveSite(id: 'site-b', name: 'B'));
    await repository.createSite(const DiveSite(id: 'site-c', name: 'C'));
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  group('getDiveAggregatesBySite', () {
    test('counts, last-dived and deepest depth per site', () async {
      await _insertDive(
        database,
        id: 'd1',
        siteId: 'site-a',
        at: DateTime(2024, 1, 10),
        maxDepth: 18,
      );
      await _insertDive(
        database,
        id: 'd2',
        siteId: 'site-a',
        at: DateTime(2024, 3, 5),
        maxDepth: 31.5,
      );
      await _insertDive(
        database,
        id: 'd3',
        siteId: 'site-b',
        at: DateTime(2023, 6, 1),
      );

      final aggregates = await repository.getDiveAggregatesBySite();

      expect(aggregates.keys, unorderedEquals(['site-a', 'site-b']));
      expect(aggregates['site-a']!.diveCount, 2);
      expect(aggregates['site-a']!.lastDivedAt, DateTime(2024, 3, 5));
      expect(aggregates['site-a']!.maxDepthReached, 31.5);
      expect(aggregates['site-b']!.diveCount, 1);
      expect(aggregates['site-b']!.maxDepthReached, isNull);
    });

    test('getDiveCountsBySite still returns plain counts', () async {
      await _insertDive(
        database,
        id: 'd1',
        siteId: 'site-a',
        at: DateTime(2024, 1, 10),
      );

      expect(await repository.getDiveCountsBySite(), {'site-a': 1});
    });
  });

  group('getFeatureTypesBySite', () {
    test('lists distinct type names ordered by first creation', () async {
      await _insertFeature(
        database,
        id: 'f1',
        siteId: 'site-a',
        type: 'wreck',
        createdAt: 100,
      );
      await _insertFeature(
        database,
        id: 'f2',
        siteId: 'site-a',
        type: 'mooring',
        createdAt: 200,
      );
      await _insertFeature(
        database,
        id: 'f3',
        siteId: 'site-a',
        type: 'wreck',
        createdAt: 300,
      );
      await _insertFeature(
        database,
        id: 'f4',
        siteId: 'site-b',
        type: 'swimThrough',
        createdAt: 50,
      );

      final types = await repository.getFeatureTypesBySite();

      expect(types['site-a'], ['wreck', 'mooring']);
      expect(types['site-b'], ['swimThrough']);
      expect(types.containsKey('site-c'), isFalse);
    });
  });

  group('getSitesWithDiveCounts', () {
    test('assembles aggregates and feature types per site', () async {
      await _insertDive(
        database,
        id: 'd1',
        siteId: 'site-a',
        at: DateTime(2024, 3, 5),
        maxDepth: 31.5,
      );
      await _insertFeature(
        database,
        id: 'f1',
        siteId: 'site-a',
        type: 'wreck',
        createdAt: 100,
      );

      final sites = await repository.getSitesWithDiveCounts();
      final a = sites.singleWhere((s) => s.site.id == 'site-a');
      final c = sites.singleWhere((s) => s.site.id == 'site-c');

      expect(a.diveCount, 1);
      expect(a.lastDivedAt, DateTime(2024, 3, 5));
      expect(a.maxDepthReached, 31.5);
      expect(a.featureTypes, ['wreck']);
      expect(c.diveCount, 0);
      expect(c.lastDivedAt, isNull);
      expect(c.maxDepthReached, isNull);
      expect(c.featureTypes, isEmpty);
    });
  });
  group('getDiveAggregatesBySite richer per-site figures', () {
    test('carries first dived, average depth and duration per site', () async {
      await _insertDive(
        database,
        id: 'd1',
        siteId: 'site-a',
        at: DateTime(2026, 1, 5),
        maxDepth: 10,
        runtime: 1800,
      );
      await _insertDive(
        database,
        id: 'd2',
        siteId: 'site-a',
        at: DateTime(2026, 6, 5),
        maxDepth: 30,
        runtime: 3600,
      );

      final aggregates = await repository.getDiveAggregatesBySite();
      final site = aggregates['site-a']!;

      expect(site.firstDivedAt, equals(DateTime(2026, 1, 5)));
      expect(site.averageDepthReached, equals(20));
      expect(site.longestDiveSeconds, equals(3600));
      expect(site.averageDurationSeconds, equals(2700));
    });

    test('falls back to bottom time when a dive has no runtime', () async {
      await _insertDive(
        database,
        id: 'd3',
        siteId: 'site-b',
        at: DateTime(2026, 2, 2),
        maxDepth: 12,
        bottomTime: 2400,
      );

      final aggregates = await repository.getDiveAggregatesBySite();

      expect(aggregates['site-b']!.longestDiveSeconds, equals(2400));
      expect(aggregates['site-b']!.averageDurationSeconds, equals(2400));
    });

    test('leaves the new figures null when no dive records them', () async {
      await _insertDive(
        database,
        id: 'd4',
        siteId: 'site-c',
        at: DateTime(2026, 3, 3),
      );

      final aggregates = await repository.getDiveAggregatesBySite();
      final site = aggregates['site-c']!;

      expect(site.diveCount, equals(1));
      expect(site.averageDepthReached, isNull);
      expect(site.longestDiveSeconds, isNull);
      expect(site.averageDurationSeconds, isNull);
      // The date is always recorded, so first dived is always known.
      expect(site.firstDivedAt, equals(DateTime(2026, 3, 3)));
    });
  });
}
