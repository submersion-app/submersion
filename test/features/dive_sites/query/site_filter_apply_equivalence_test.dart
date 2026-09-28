import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/query/site_filter_query.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

import '../../../helpers/test_database.dart';

/// The compiled site query selects exactly what SiteFilterState.apply did,
/// axis by axis (#2365). Deleted with apply() once the list reads the query.
void main() {
  late AppDatabase db;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    Future<void> site(
      String id, {
      required String diver,
      String? country,
      String? region,
      String? difficulty,
      double? maxDepth,
      double? rating,
      double? lat,
      double? lon,
      bool shared = false,
    }) => db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            name: id,
            diverId: Value(diver),
            country: Value(country),
            region: Value(region),
            difficulty: Value(difficulty),
            maxDepth: Value(maxDepth),
            rating: Value(rating),
            latitude: Value(lat),
            longitude: Value(lon),
            isShared: Value(shared),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await site(
      'bon',
      diver: 'me',
      country: 'Bonaire ',
      region: 'Klein',
      difficulty: 'Advanced',
      maxDepth: 30,
      rating: 4,
      lat: 12.1,
      lon: -68.2,
    );
    await site(
      'cur',
      diver: 'me',
      country: 'curacao',
      difficulty: 'beginner',
      maxDepth: 12,
      rating: 2,
    );
    await site('shr', diver: 'other', country: 'Bonaire', shared: true);
    await site('hid', diver: 'other', country: 'Bonaire');
    await site('plan', diver: 'me');
    Future<void> dive(
      String id,
      String siteId, {
      String diver = 'me',
      bool planned = false,
      bool excluded = false,
    }) => db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: Value(diver),
            siteId: Value(siteId),
            isPlanned: Value(planned),
            excludedFromStats: Value(excluded),
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    // Another diver's dive: the site list's count is not diver-scoped.
    await dive('d-bon', 'bon', diver: 'other');
    await dive('d-plan1', 'plan', planned: true);
    await dive('d-plan2', 'plan', excluded: true);
    await db
        .into(db.siteTypes)
        .insert(
          SiteTypesCompanion.insert(
            id: 'my-arch',
            name: 'Rock arch',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.siteSiteTypes)
        .insert(
          SiteSiteTypesCompanion.insert(
            id: 'sst1',
            siteId: 'cur',
            siteTypeId: 'my-arch',
            createdAt: now,
          ),
        );
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 't1',
            name: 'Macro',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.siteTags)
        .insert(
          SiteTagsCompanion.insert(
            id: 'st1',
            siteId: 'bon',
            tagId: 't1',
            createdAt: now,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Future<void> expectSame(SiteFilterState f) async {
    final visible = await SiteRepository().getSitesWithDiveCounts(
      diverId: 'me',
    );
    final viaApply = {for (final s in f.apply(visible)) s.site.id};
    final ids = await QueryIdSetRunner(db).ids(compileSiteFilter(f));
    final viaSql = {
      for (final s in visible)
        if (ids.contains(s.site.id)) s.site.id,
    };
    expect(viaSql, viaApply, reason: '$f');
  }

  test('every axis selects what apply() selected', () async {
    for (final f in [
      const SiteFilterState(),
      const SiteFilterState(country: 'Bonaire'),
      const SiteFilterState(country: 'bonaire', region: 'Klein'),
      const SiteFilterState(difficulty: SiteDifficulty.advanced),
      const SiteFilterState(minDepth: 20),
      const SiteFilterState(maxDepth: 20),
      const SiteFilterState(minRating: 3),
      const SiteFilterState(hasCoordinates: true),
      const SiteFilterState(hasCoordinates: false),
      const SiteFilterState(hasDives: true),
      const SiteFilterState(hasDives: false),
      const SiteFilterState(siteTypeIds: {'my-arch'}),
      const SiteFilterState(tagIds: {'t1'}),
      const SiteFilterState(country: 'Bonaire', hasDives: true, tagIds: {'t1'}),
    ]) {
      await expectSame(f);
    }
  });

  test('a trimmed country matches', () async {
    final ids = await QueryIdSetRunner(
      db,
    ).ids(compileSiteFilter(const SiteFilterState(country: 'Bonaire')));
    expect(ids, containsAll(['bon', 'shr']));
  });

  test('planned and excluded dives do not count', () async {
    final ids = await QueryIdSetRunner(
      db,
    ).ids(compileSiteFilter(const SiteFilterState(hasDives: true)));
    expect(ids, isNot(contains('plan')));
    expect(ids, contains('bon'));
  });
}
