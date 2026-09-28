import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/query/site_filter_query.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

import '../../../helpers/test_database.dart';

/// What each site filter axis selects through the compiled query (#2365),
/// against rows, including the location and classification rules
/// SiteFilterState.apply() once pinned in memory (#1373, #1765).
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
    // Location containment (issue #1373): exact values, never substrings.
    await site('sinai', diver: 'me', region: 'Sinai');
    await site('ssinai', diver: 'me', region: 'South Sinai');
    await site('congo', diver: 'me', country: 'Congo');
    await site('drc', diver: 'me', country: 'Democratic Republic of Congo');
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

  /// The visible sites (the list's rows) the filter's query selects.
  Future<Set<String>> selected(SiteFilterState f) async {
    final visible = await SiteRepository().getSitesWithDiveCounts(
      diverId: 'me',
    );
    final ids = await QueryIdSetRunner(db).ids(compileSiteFilter(f));
    return {
      for (final s in visible)
        if (ids.contains(s.site.id)) s.site.id,
    };
  }

  const everyVisible = {
    'bon',
    'cur',
    'shr',
    'plan',
    'sinai',
    'ssinai',
    'congo',
    'drc',
  };

  test('each axis selects its sites', () async {
    expect(await selected(const SiteFilterState()), everyVisible);
    expect(await selected(const SiteFilterState(country: 'Bonaire')), {
      'bon',
      'shr',
    });
    expect(
      await selected(
        const SiteFilterState(country: 'bonaire', region: 'Klein'),
      ),
      {'bon'},
    );
    expect(
      await selected(
        const SiteFilterState(difficulty: SiteDifficulty.advanced),
      ),
      {'bon'},
    );
    expect(await selected(const SiteFilterState(minDepth: 20)), {'bon'});
    expect(await selected(const SiteFilterState(maxDepth: 20)), {'cur'});
    expect(await selected(const SiteFilterState(minRating: 3)), {'bon'});
    expect(await selected(const SiteFilterState(hasCoordinates: true)), {
      'bon',
    });
    expect(
      await selected(const SiteFilterState(hasCoordinates: false)),
      everyVisible.difference({'bon'}),
    );
    expect(await selected(const SiteFilterState(siteTypeIds: {'my-arch'})), {
      'cur',
    });
    expect(await selected(const SiteFilterState(tagIds: {'t1'})), {'bon'});
    expect(
      await selected(
        const SiteFilterState(
          country: 'Bonaire',
          hasDives: true,
          tagIds: {'t1'},
        ),
      ),
      {'bon'},
    );
  });

  test('a trimmed country matches', () async {
    expect(
      await selected(const SiteFilterState(country: 'Bonaire')),
      containsAll(['bon', 'shr']),
    );
  });

  test('planned and excluded dives do not count', () async {
    expect(await selected(const SiteFilterState(hasDives: true)), {'bon'});
    expect(
      await selected(const SiteFilterState(hasDives: false)),
      everyVisible.difference({'bon'}),
    );
  });

  test('a location filter matches exactly, never a containing value', () async {
    expect(await selected(const SiteFilterState(region: 'Sinai')), {'sinai'});
    expect(await selected(const SiteFilterState(country: 'Congo')), {'congo'});
    // Case- and edge-whitespace-insensitive.
    expect(await selected(const SiteFilterState(region: ' sinai ')), {'sinai'});
  });

  test('type and tag filters combine with AND', () async {
    expect(
      await selected(
        const SiteFilterState(siteTypeIds: {'my-arch'}, tagIds: {'t1'}),
      ),
      isEmpty,
    );
  });

  test('empty sets are inactive and copyWith can clear them', () {
    expect(const SiteFilterState().hasActiveFilters, isFalse);
    const f = SiteFilterState(siteTypeIds: {'lake'}, tagIds: {'try'});
    expect(f.hasActiveFilters, isTrue);
    final cleared = f.copyWith(siteTypeIds: const {}, tagIds: const {});
    expect(cleared.hasActiveFilters, isFalse);
    expect(f.copyWith(country: 'Mexico').siteTypeIds, {'lake'});
  });
}
