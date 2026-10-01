import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/buddies/query/buddy_query_entity.dart';
import 'package:submersion/features/dive_centers/query/dive_center_query_entity.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/equipment/query/equipment_query_entity.dart';
import 'package:submersion/features/marine_life/query/species_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/trips/query/trip_query_entity.dart';

import '../../helpers/test_database.dart';

/// The derived fields every non-dive subject gains (Explore phase 3): a
/// count and a last-dived date over the subject's dives, inside the stats
/// scope, as the site list's own dive count is.
void main() {
  late AppDatabase db;
  final day = DateTime.utc(2024, 6, 1).millisecondsSinceEpoch;
  const dayMs = 24 * 60 * 60 * 1000;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(tearDownTestDatabase);

  Future<Set<String>> ids(QueryEntity root, QueryNode node) =>
      QueryIdSetRunner(db).ids(compileQuery(node, root, appQueryRegistry));

  ConditionNode c(String key, QueryOp op, [Object? v]) =>
      ConditionNode(FieldPath([key]), op, switch (v) {
        final num n => NumberValue(n.toDouble(), null),
        final DateTime d => DateValue(d),
        _ => null,
      });

  Future<void> site(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: Value(day),
          updatedAt: Value(day),
        ),
      );

  Future<void> dive(
    String id, {
    String? siteId,
    String? centerId,
    String? tripId,
    int at = 0,
    bool planned = false,
    bool excluded = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(day + at * dayMs),
          createdAt: Value(day),
          updatedAt: Value(day),
          siteId: Value(siteId),
          diveCenterId: Value(centerId),
          tripId: Value(tripId),
          isPlanned: Value(planned),
          excludedFromStats: Value(excluded),
        ),
      );

  group('sites', () {
    setUp(() async {
      await site('busy');
      await site('once');
      await site('never');
      await dive('a', siteId: 'busy', at: 0);
      await dive('b', siteId: 'busy', at: 10);
      await dive('c', siteId: 'busy', at: 20);
      await dive('d', siteId: 'once', at: 5);
      // Neither counts: planned, and excluded from statistics.
      await dive('p', siteId: 'never', planned: true);
      await dive('x', siteId: 'never', excluded: true);
    });

    test('diveCount counts only dives in the stats scope', () async {
      expect(await ids(siteQueryEntity, c('diveCount', QueryOp.gte, 2)), {
        'busy',
      });
      expect(await ids(siteQueryEntity, c('diveCount', QueryOp.eq, 1)), {
        'once',
      });
    });

    test('a site with no counted dive has a count of 0, not none', () async {
      expect(await ids(siteQueryEntity, c('diveCount', QueryOp.lte, 1)), {
        'once',
        'never',
      });
      expect(await ids(siteQueryEntity, c('diveCount', QueryOp.isEmpty)), {
        'never',
      });
    });

    test('lastDived is the newest counted dive', () async {
      expect(
        await ids(
          siteQueryEntity,
          c('lastDived', QueryOp.gt, DateTime.utc(2024, 6, 15)),
        ),
        {'busy'},
      );
      // Never dived: no date, so no bound matches it.
      expect(
        await ids(
          siteQueryEntity,
          c('lastDived', QueryOp.lt, DateTime.utc(2030)),
        ),
        {'busy', 'once'},
      );
    });
  });

  test('centers and trips count their dives', () async {
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion(
            id: const Value('c1'),
            name: const Value('Shop'),
            createdAt: Value(day),
            updatedAt: Value(day),
          ),
        );
    await db
        .into(db.trips)
        .insert(
          TripsCompanion.insert(
            id: 't1',
            name: 'Trip',
            startDate: day,
            endDate: day,
            createdAt: day,
            updatedAt: day,
          ),
        );
    await dive('a', centerId: 'c1', tripId: 't1');
    await dive('b', centerId: 'c1', tripId: 't1');
    expect(await ids(diveCenterQueryEntity, c('diveCount', QueryOp.gte, 2)), {
      'c1',
    });
    expect(await ids(tripQueryEntity, c('diveCount', QueryOp.gte, 2)), {'t1'});
  });

  test('a buddy counts the dives they are on', () async {
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion(
            id: const Value('ana'),
            name: const Value('Ana'),
            createdAt: Value(day),
            updatedAt: Value(day),
          ),
        );
    await dive('a');
    await dive('b', at: 3);
    for (final d in ['a', 'b']) {
      await db
          .into(db.diveBuddies)
          .insert(
            DiveBuddiesCompanion(
              id: Value('j-$d'),
              diveId: Value(d),
              buddyId: const Value('ana'),
              createdAt: Value(day),
            ),
          );
    }
    expect(await ids(buddyQueryEntity, c('diveCount', QueryOp.eq, 2)), {'ana'});
    expect(
      await ids(
        buddyQueryEntity,
        c('lastDived', QueryOp.gte, DateTime.utc(2024, 6, 4)),
      ),
      {'ana'},
    );
  });

  test('gear counts dives through the item and through a cylinder', () async {
    for (final id in ['reg', 'cyl']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: day,
              updatedAt: day,
            ),
          );
    }
    await dive('a');
    await db
        .into(db.diveEquipment)
        .insert(DiveEquipmentCompanion.insert(diveId: 'a', equipmentId: 'reg'));
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion.insert(
            id: 't',
            diveId: 'a',
          ).copyWith(equipmentId: const Value('cyl')),
        );
    expect(await ids(equipmentQueryEntity, c('diveCount', QueryOp.eq, 1)), {
      'reg',
      'cyl',
    });
  });

  test('species count dives with a sighting, first and last seen', () async {
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion.insert(
            id: 'turtle',
            commonName: 'Turtle',
            category: 'reptile',
          ),
        );
    await dive('a', at: 0);
    await dive('b', at: 30);
    for (final d in ['a', 'b']) {
      await db
          .into(db.sightings)
          .insert(
            SightingsCompanion.insert(
              id: 's-$d',
              diveId: d,
              speciesId: 'turtle',
            ),
          );
    }
    expect(await ids(speciesQueryEntity, c('diveCount', QueryOp.eq, 2)), {
      'turtle',
    });
    expect(
      await ids(
        speciesQueryEntity,
        c('firstSeen', QueryOp.lte, DateTime.utc(2024, 6, 1)),
      ),
      {'turtle'},
    );
    expect(
      await ids(
        speciesQueryEntity,
        c('lastSeen', QueryOp.gte, DateTime.utc(2024, 7, 1)),
      ),
      {'turtle'},
    );
  });

  test('nextServiceDue reads the service cache', () async {
    for (final id in ['soon', 'later', 'unknown']) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'regulator',
              createdAt: day,
              updatedAt: day,
            ),
          );
    }
    Future<void> due(String id, DateTime? at) => db
        .into(db.equipmentServiceStatus)
        .insert(
          EquipmentServiceStatusCompanion.insert(
            equipmentId: id,
            severity: 'ok',
            computedAt: day,
          ).copyWith(dueDate: Value(at?.millisecondsSinceEpoch)),
        );
    await due('soon', DateTime(2024, 6, 20));
    await due('later', DateTime(2025, 1, 1));
    await due('unknown', null);
    expect(
      await ids(
        equipmentQueryEntity,
        c('nextServiceDue', QueryOp.lte, DateTime(2024, 7, 1)),
      ),
      {'soon'},
    );
  });
}
