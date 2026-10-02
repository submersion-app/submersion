import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/insights_place_dives.dart';

import '../../../helpers/test_database.dart';

/// Issue #2623: a country or region row opens the dives behind it, and the
/// dive list it opens holds exactly the dives the row counted.
void main() {
  ConditionNode site(String column, QueryOp op, [QueryValue? value]) =>
      ConditionNode(FieldPath(['site', column]), op, value);

  group('the filters', () {
    test('a country keeps the Insights scope and adds the country', () {
      final filter = countryDivesFilter(
        const DiveFilterState(minDepth: 20, favoritesOnly: true),
        'Bonaire',
      );

      expect(filter.minDepth, 20);
      expect(filter.favoritesOnly, isTrue);
      expect(
        filter.query,
        site('country', QueryOp.eq, const StringValue('Bonaire')),
      );
    });

    test('an advanced query in the scope is ANDed, not replaced', () {
      final scopeQuery = ConditionNode(
        FieldPath(const ['maxDepth']),
        QueryOp.gt,
        const NumberValue(30, null),
      );

      final filter = countryDivesFilter(
        DiveFilterState(query: scopeQuery),
        'Mexico',
      );

      expect(
        filter.query,
        AndNode([
          scopeQuery,
          site('country', QueryOp.eq, const StringValue('Mexico')),
        ]),
      );
    });

    test('a region pins its country', () {
      final filter = regionDivesFilter(
        const DiveFilterState(),
        region: 'Yucatan',
        country: 'Mexico',
      );

      expect(
        filter.query,
        AndNode([
          site('region', QueryOp.eq, const StringValue('Yucatan')),
          site('country', QueryOp.eq, const StringValue('Mexico')),
        ]),
      );
    });

    test('a region with no country keeps only sites without one', () {
      final filter = regionDivesFilter(
        const DiveFilterState(),
        region: 'Red Sea',
        country: null,
      );

      expect(
        filter.query,
        AndNode([
          site('region', QueryOp.eq, const StringValue('Red Sea')),
          site('country', QueryOp.isEmpty),
        ]),
      );
    });
  });

  group('each row opens exactly the dives it counted', () {
    late AppDatabase db;
    late InsightsRepository repository;
    final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;
    var diveSeq = 0;

    setUp(() async {
      db = await setUpTestDatabase();
      repository = InsightsRepository();
    });
    tearDown(() async {
      await tearDownTestDatabase();
    });

    Future<void> siteWithDives(
      String id, {
      String? country,
      String? region,
      required int dives,
      double maxDepth = 10,
    }) async {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion(
              id: Value(id),
              name: Value('Site $id'),
              country: Value(country),
              region: Value(region),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      for (var i = 0; i < dives; i++) {
        await db
            .into(db.dives)
            .insert(
              DivesCompanion(
                id: Value('dive-${diveSeq++}'),
                siteId: Value(id),
                maxDepth: Value(maxDepth),
                diveDateTime: Value(now),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }
    }

    Future<int> divesOpenedBy(DiveFilterState filter) async {
      final f = buildFilteredDiveIdSubquery(filter);
      final rows = await db
          .customSelect(
            f.subquery,
            variables: [for (final p in f.params) Variable(p)],
          )
          .get();
      return rows.length;
    }

    test('countries, including a spelling with stray whitespace', () async {
      await siteWithDives('a', country: 'Mexico', dives: 3);
      // Imported with a trailing no-break space: the same country to the
      // location chips and the dive query, so the same row here too.
      await siteWithDives('b', country: 'Mexico ', dives: 2);
      // Differently cased: the dive query matches text case-insensitively,
      // so the ranking counts it in the same row.
      await siteWithDives('f', country: 'mexico', dives: 1);
      await siteWithDives('c', country: 'Bonaire', dives: 1);
      await siteWithDives('d', country: '   ', dives: 4);
      await siteWithDives('e', dives: 5);

      final rows = await repository.getCountriesVisited();

      expect(
        [for (final r in rows) (r.name, r.count)],
        [('Mexico', 6), ('Bonaire', 1)],
      );
      for (final row in rows) {
        expect(
          await divesOpenedBy(
            countryDivesFilter(const DiveFilterState(), row.name),
          ),
          row.count,
          reason: row.name,
        );
      }
    });

    test('regions, split by country and with no country', () async {
      await siteWithDives('a', region: 'North', country: 'Fiji', dives: 3);
      await siteWithDives('b', region: 'North ', country: 'Fiji', dives: 1);
      await siteWithDives('c', region: 'North', country: 'Palau', dives: 2);
      await siteWithDives('g', region: 'north', country: 'FIJI', dives: 2);
      await siteWithDives('d', region: 'North', dives: 2);
      await siteWithDives('e', region: 'North', country: ' ', dives: 1);

      final rows = await repository.getRegionsExplored();

      expect(
        [for (final r in rows) (r.name, r.subtitle, r.count)],
        unorderedEquals([
          ('North', 'FIJI', 6),
          ('North', 'Palau', 2),
          ('North', null, 3),
        ]),
      );
      for (final row in rows) {
        expect(
          await divesOpenedBy(
            regionDivesFilter(
              const DiveFilterState(),
              region: row.name,
              country: row.subtitle,
            ),
          ),
          row.count,
          reason: '${row.name} / ${row.subtitle}',
        );
      }
    });

    test('under an Insights filter, the scope carries through', () async {
      await siteWithDives('a', country: 'Fiji', dives: 2, maxDepth: 40);
      await siteWithDives('b', country: 'Fiji', dives: 3, maxDepth: 12);
      const scope = DiveFilterState(minDepth: 30);

      final rows = await repository.getCountriesVisited(filter: scope);

      expect([for (final r in rows) (r.name, r.count)], [('Fiji', 2)]);
      expect(await divesOpenedBy(countryDivesFilter(scope, 'Fiji')), 2);
    });
  });
}
