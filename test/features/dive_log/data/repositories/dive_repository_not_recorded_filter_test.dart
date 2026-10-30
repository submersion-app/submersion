import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../../helpers/test_database.dart';

/// The "not recorded" filters find exactly the dives the insights charts
/// count in their Not recorded slice (issue #3806): nothing on the dive, and
/// nothing usable on its site.
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    final sites = SiteRepository();
    final saltSite = await sites.createSite(
      const DiveSite(id: '', name: 'Reef', waterType: WaterType.salt),
    );
    final shoreSite = await sites.createSite(
      const DiveSite(id: '', name: 'Pier', entryMethods: [EntryMethod.shore]),
    );
    // A list says nothing about which method a given dive used.
    final eitherSite = await sites.createSite(
      const DiveSite(
        id: '',
        name: 'Wall',
        entryMethods: [EntryMethod.shore, EntryMethod.boat],
      ),
    );
    final date = DateTime.utc(2026, 6, 8);
    Future<void> dive(
      String id, {
      DiveSite? site,
      WaterType? waterType,
      EntryMethod? entryMethod,
    }) => repository.createDive(
      domain.Dive(
        id: id,
        dateTime: date,
        site: site,
        waterType: waterType,
        entryMethod: entryMethod,
      ),
    );
    await dive('own', waterType: WaterType.salt, entryMethod: EntryMethod.boat);
    await dive('saltSite', site: saltSite);
    await dive('shoreSite', site: shoreSite);
    await dive('eitherSite', site: eitherSite);
    await dive(
      'override',
      site: shoreSite,
      waterType: WaterType.fresh,
      entryMethod: EntryMethod.boat,
    );
    await dive('unknown');
  });
  tearDown(() async => tearDownTestDatabase());

  Future<Set<String>> matching(DiveFilterState filter) async {
    final results = await repository.getDiveSummaries(filter: filter);
    return results.map((d) => d.id).toSet();
  }

  QueryNode entryIs(String name) =>
      ConditionNode(FieldPath(['entryMethod']), QueryOp.eq, EnumValue(name));

  group('water type', () {
    test('finds dives with none on the dive or its site', () async {
      expect(await matching(const DiveFilterState(noWaterType: true)), {
        'shoreSite',
        'eitherSite',
        'unknown',
      });
    });

    test('combines with listed types as either-or', () async {
      expect(
        await matching(
          const DiveFilterState(
            waterTypes: [WaterType.fresh],
            noWaterType: true,
          ),
        ),
        {'override', 'shoreSite', 'eitherSite', 'unknown'},
      );
    });

    test('matches the chart Not recorded slice', () async {
      final chart = await InsightsRepository().getWaterTypeDistribution();
      final slice = chart.singleWhere(
        (s) => s.label == kNotRecordedDistributionKey,
      );
      final ids = await repository.getDiveIdsMatching(
        const DiveFilterState(noWaterType: true),
      );
      expect(ids.length, slice.count);
    });
  });

  group('entry method', () {
    test(
      'a dive with no entry method matches by its single-method site',
      () async {
        expect(await matching(DiveFilterState(query: entryIs('shore'))), {
          'shoreSite',
        });
      },
    );

    test('the dive own entry method wins over the site one', () async {
      expect(await matching(DiveFilterState(query: entryIs('boat'))), {
        'own',
        'override',
      });
    });

    test(
      'finds dives with none, counting a many-method site as none',
      () async {
        expect(await matching(const DiveFilterState(noEntryMethodOnly: true)), {
          'saltSite',
          'eitherSite',
          'unknown',
        });
      },
    );

    test('matches the chart Not recorded slice', () async {
      final chart = await InsightsRepository().getEntryMethodDistribution();
      final slice = chart.singleWhere(
        (s) => s.label == kNotRecordedDistributionKey,
      );
      final ids = await repository.getDiveIdsMatching(
        const DiveFilterState(noEntryMethodOnly: true),
      );
      expect(ids.length, slice.count);
    });

    test('an entry method query re-ticks on site changes', () {
      final q = compileQuery(
        entryIs('shore'),
        appQueryRegistry.entityFor(QuerySubject.dives),
        appQueryRegistry,
      );
      expect(q.tablesTouched, contains('dive_sites'));
    });
  });
}
