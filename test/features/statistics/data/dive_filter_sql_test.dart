import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as dive_entity;
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });
  tearDown(() async {
    await tearDownTestDatabase();
  });

  final now = DateTime(2026, 6, 1).millisecondsSinceEpoch;

  Future<void> insertDive(
    String id, {
    DateTime? date,
    String? siteId,
    String? diveCenterId,
    String? tripId,
    double? maxDepth,
    int? rating,
    int? bottomTimeSeconds,
    bool favorite = false,
    String? computerSerial,
    String? buddy,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(
              (date ?? DateTime(2026, 6, 1)).millisecondsSinceEpoch,
            ),
            siteId: Value(siteId),
            diveCenterId: Value(diveCenterId),
            tripId: Value(tripId),
            maxDepth: Value(maxDepth),
            rating: Value(rating),
            bottomTime: Value(bottomTimeSeconds),
            isFavorite: Value(favorite),
            diveComputerSerial: Value(computerSerial),
            buddy: Value(buddy),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertSite(String id) async {
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: Value(id),
            name: Value('Site $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertTag(String id) async {
    await db
        .into(db.tags)
        .insert(
          TagsCompanion(
            id: Value(id),
            name: Value('Tag $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> linkTag(String diveId, String tagId) async {
    await db
        .into(db.diveTags)
        .insert(
          DiveTagsCompanion(
            id: Value('$diveId-$tagId'),
            diveId: Value(diveId),
            tagId: Value(tagId),
            createdAt: Value(now),
          ),
        );
  }

  Future<void> insertDiveCenter(String id) async {
    await db
        .into(db.diveCenters)
        .insert(
          DiveCentersCompanion(
            id: Value(id),
            name: Value('Center $id'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertTrip(String id) async {
    await db
        .into(db.trips)
        .insert(
          TripsCompanion(
            id: Value(id),
            name: Value('Trip $id'),
            startDate: Value(now),
            endDate: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertEquipment(String id) async {
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion(
            id: Value(id),
            name: Value('Equipment $id'),
            type: const Value('other'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> linkEquipment(String diveId, String equipmentId) async {
    await db
        .into(db.diveEquipment)
        .insert(
          DiveEquipmentCompanion(
            diveId: Value(diveId),
            equipmentId: Value(equipmentId),
          ),
        );
  }

  // dive_dive_types.dive_type_id carries no FK (see DiveDiveTypes in
  // database.dart), so arbitrary slug strings are valid without seeding a
  // dive_types row.
  Future<void> insertDiveType(String diveId, String diveTypeId) async {
    await db
        .into(db.diveDiveTypes)
        .insert(
          DiveDiveTypesCompanion(
            id: Value('$diveId-$diveTypeId'),
            diveId: Value(diveId),
            diveTypeId: Value(diveTypeId),
            createdAt: Value(now),
          ),
        );
  }

  Future<void> insertTank(
    String diveId,
    String tankId, {
    required double o2Percent,
  }) async {
    await db
        .into(db.diveTanks)
        .insert(
          DiveTanksCompanion(
            id: Value(tankId),
            diveId: Value(diveId),
            o2Percent: Value(o2Percent),
            hePercent: const Value(0.0),
            tankOrder: const Value(0),
          ),
        );
  }

  Future<void> insertCustomField(
    String diveId,
    String key,
    String value,
  ) async {
    await db
        .into(db.diveCustomFields)
        .insert(
          DiveCustomFieldsCompanion(
            id: Value('$diveId-$key'),
            diveId: Value(diveId),
            fieldKey: Value(key),
            fieldValue: Value(value),
            createdAt: Value(now),
          ),
        );
  }

  Future<Set<String>> idsMatching(DiveFilterState filter) async {
    final f = buildFilteredDiveIdSubquery(filter);
    final sql = f.subquery.isEmpty ? 'SELECT id FROM dives' : f.subquery;
    final rows = await db
        .customSelect(sql, variables: f.params.map((p) => Variable(p)).toList())
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  test('empty filter is a no-op (returns all dives)', () async {
    await insertDive('a');
    await insertDive('b');
    final f = buildFilteredDiveIdSubquery(const DiveFilterState());
    expect(f.subquery, '');
    expect(f.params, isEmpty);
    expect(await idsMatching(const DiveFilterState()), {'a', 'b'});
  });

  test('date range filters inclusively through the end day', () async {
    await insertDive('before', date: DateTime(2026, 1, 1));
    await insertDive('inside', date: DateTime(2026, 6, 15));
    await insertDive('endday', date: DateTime(2026, 6, 30, 23, 0));
    await insertDive('after', date: DateTime(2026, 8, 1));
    final filter = DiveFilterState(
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, 30),
    );
    expect(await idsMatching(filter), {'inside', 'endday'});
  });

  test('tag filter matches ANY selected tag', () async {
    await insertDive('a');
    await insertDive('b');
    await insertDive('c');
    await insertTag('dry');
    await insertTag('night');
    await linkTag('a', 'dry');
    await linkTag('b', 'night');
    expect(await idsMatching(const DiveFilterState(tagIds: ['dry'])), {'a'});
    expect(await idsMatching(const DiveFilterState(tagIds: ['dry', 'night'])), {
      'a',
      'b',
    });
  });

  test('site, depth, rating, favorites axes', () async {
    await insertSite('s1');
    await insertDive(
      'a',
      siteId: 's1',
      maxDepth: 30,
      rating: 5,
      favorite: true,
    );
    await insertDive('b', maxDepth: 10, rating: 2);
    expect(await idsMatching(const DiveFilterState(siteId: 's1')), {'a'});
    expect(await idsMatching(const DiveFilterState(minDepth: 20)), {'a'});
    expect(await idsMatching(const DiveFilterState(minRating: 4)), {'a'});
    expect(await idsMatching(const DiveFilterState(favoritesOnly: true)), {
      'a',
    });
  });

  test(
    'bottom-time filter truncates to whole minutes like Duration.inMinutes',
    () async {
      // 149s = 2 min (truncated); with maxBottomTimeMinutes: 2 it must pass.
      await insertDive('short', bottomTimeSeconds: 149);
      await insertDive('long', bottomTimeSeconds: 600);
      expect(
        await idsMatching(const DiveFilterState(maxBottomTimeMinutes: 2)),
        {'short'},
      );
      expect(
        await idsMatching(const DiveFilterState(minBottomTimeMinutes: 5)),
        {'long'},
      );
    },
  );

  test(
    'parity: apply() and the subquery agree on date + bottom-time edges',
    () async {
      // Build domain dives and matching DB rows, then assert both filter paths
      // return the same ids for the same filter.
      final cases = <(String, DateTime, int)>[
        ('a', DateTime(2026, 6, 30, 23, 0), 149),
        ('b', DateTime(2026, 7, 2), 600),
        ('c', DateTime(2026, 5, 1), 61),
      ];
      for (final (id, date, bt) in cases) {
        await db
            .into(db.dives)
            .insert(
              DivesCompanion(
                id: Value(id),
                diveDateTime: Value(date.millisecondsSinceEpoch),
                bottomTime: Value(bt),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }
      final domainDives = cases
          .map(
            (c) => dive_entity.Dive(
              id: c.$1,
              dateTime: c.$2,
              bottomTime: Duration(seconds: c.$3),
            ),
          )
          .toList();

      for (final filter in <DiveFilterState>[
        DiveFilterState(
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 6, 30),
        ),
        const DiveFilterState(maxBottomTimeMinutes: 2),
        const DiveFilterState(minBottomTimeMinutes: 2),
      ]) {
        final applied = filter.apply(domainDives).map((d) => d.id).toSet();
        final sqld = await idsMatching(filter);
        expect(sqld, applied, reason: 'mismatch for $filter');
      }
    },
  );

  test('broad parity: apply() and buildFilteredDiveIdSubquery agree across '
      'every implemented DiveFilterState axis (spec 9.3 invariant)', () async {
    // This is the general form of the two parity tests above: instead of
    // hand-rolling matching domain Dive + DB row pairs per axis, seed one
    // rich dataset into the real DB, hydrate the domain side the same way
    // production code does (DiveRepository().getAllDives()), and assert
    // DiveFilterState.apply() and buildFilteredDiveIdSubquery() select the
    // same ids for a battery of filters -- one per axis, plus a few
    // multi-axis combinations. That "SQL mirrors apply()" property is what
    // lets getStatistics/getSacVolumeTrend/etc. push filtering into SQL
    // instead of loading every dive into Dart.

    // --- Parents (FK=ON: must precede the dives that reference them) ---
    await insertSite('s1');
    await insertSite('s2');
    await insertSite('s3');
    await insertDiveCenter('c1');
    await insertDiveCenter('c2');
    await insertTrip('t1');
    await insertTag('dry');
    await insertTag('night');
    await insertEquipment('eq1');
    await insertEquipment('eq2');

    // --- Dives: deliberately varied so every axis below both includes and
    // excludes at least one dive (a filter that trivially matches
    // everything, or nothing, couldn't catch a real apply()/SQL mismatch).
    await insertDive(
      'd1',
      date: DateTime(2026, 1, 10),
      siteId: 's1',
      diveCenterId: 'c1',
      tripId: 't1',
      maxDepth: 18.0,
      rating: 3,
      bottomTimeSeconds: 2400, // 40 min
      buddy: 'Alice Diver',
    );
    await insertDive(
      'd2',
      date: DateTime(2026, 2, 5),
      siteId: 's2',
      diveCenterId: 'c1',
      maxDepth: 30.0,
      rating: 5,
      bottomTimeSeconds: 3300, // 55 min
      favorite: true,
      computerSerial: 'BBB222',
      buddy: 'Bob Buddy',
    );
    // d3: nulls across depth/rating/computerSerial, and no tanks/tags/
    // equipment/custom fields at all -- exercises every null-exclusion and
    // empty-membership branch on both sides.
    await insertDive(
      'd3',
      date: DateTime(2026, 3, 20),
      tripId: 't1',
      bottomTimeSeconds: 900, // 15 min
    );
    await insertDive(
      'd4',
      date: DateTime(2026, 4, 1),
      siteId: 's1',
      diveCenterId: 'c2',
      maxDepth: 45.0,
      rating: 2,
      bottomTimeSeconds: 1200, // 20 min
      computerSerial: 'AAA111',
    );
    // d5: two tanks (100% and 21%) so the O2 axis actually exercises
    // ANY-tank-matches semantics rather than a single-tank dive.
    await insertDive(
      'd5',
      date: DateTime(2026, 5, 15),
      siteId: 's3',
      diveCenterId: 'c2',
      maxDepth: 12.0,
      rating: 4,
      bottomTimeSeconds: 3600, // 60 min
      favorite: true,
      computerSerial: 'CCC333',
    );
    await insertDive(
      'd6',
      date: DateTime(2026, 6, 25, 23, 0),
      siteId: 's2',
      maxDepth: 25.0,
      bottomTimeSeconds: 480, // 8 min
      computerSerial: 'BBB222',
    );
    await insertDive(
      'd7',
      date: DateTime(2025, 12, 31),
      siteId: 's1',
      diveCenterId: 'c1',
      maxDepth: 5.0,
      rating: 1,
      bottomTimeSeconds: 6000, // 100 min
    );

    // dive_dive_types: no FK, so slugs need no parent row.
    await insertDiveType('d1', 'wreck');
    await insertDiveType('d2', 'cave');
    await insertDiveType('d3', 'training');
    await insertDiveType('d4', 'deep');
    await insertDiveType('d5', 'reef');
    await insertDiveType('d6', 'wreck');
    await insertDiveType('d7', 'training');

    // tags: multi-membership so single- and multi-tag (ANY) both discriminate.
    await linkTag('d1', 'dry');
    await linkTag('d2', 'dry');
    await linkTag('d2', 'night');
    await linkTag('d4', 'night');
    await linkTag('d5', 'dry');
    await linkTag('d7', 'night');

    // equipment: ANY-match axis.
    await linkEquipment('d1', 'eq1');
    await linkEquipment('d2', 'eq1');
    await linkEquipment('d2', 'eq2');
    await linkEquipment('d4', 'eq2');
    await linkEquipment('d6', 'eq1');

    // tanks: ANY-tank O2 axis. d3 has none (must be excluded once an O2
    // bound is set); d5 has two, only one of which clears a high bound.
    await insertTank('d1', 'tank-d1', o2Percent: 21.0);
    await insertTank('d2', 'tank-d2', o2Percent: 32.0);
    await insertTank('d4', 'tank-d4', o2Percent: 18.0);
    await insertTank('d5', 'tank-d5-a', o2Percent: 100.0);
    await insertTank('d5', 'tank-d5-b', o2Percent: 21.0);
    await insertTank('d6', 'tank-d6', o2Percent: 21.0);
    await insertTank('d7', 'tank-d7', o2Percent: 21.0);

    // custom fields: shared key with varied values so key-only and
    // key+value-substring both discriminate.
    await insertCustomField('d1', 'visMeters', '20');
    await insertCustomField('d2', 'visMeters', '5');
    await insertCustomField('d4', 'buddyCert', 'AOW');
    await insertCustomField('d6', 'visMeters', '15');

    // Hydrate the domain side exactly the way production code does.
    final domainDives = await DiveRepository().getAllDives();
    expect(domainDives.length, 7, reason: 'all seeded dives hydrated');

    final battery = <String, DiveFilterState>{
      'date range': DiveFilterState(
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 1),
      ),
      'siteId': const DiveFilterState(siteId: 's1'),
      'diveTypeId': const DiveFilterState(diveTypeId: 'wreck'),
      'diveCenterId': const DiveFilterState(diveCenterId: 'c1'),
      'tripId': const DiveFilterState(tripId: 't1'),
      'single tag': const DiveFilterState(tagIds: ['dry']),
      'multi tag (ANY)': const DiveFilterState(tagIds: ['dry', 'night']),
      'equipment (ANY)': const DiveFilterState(equipmentIds: ['eq1']),
      'minDepth (null-exclusion)': const DiveFilterState(minDepth: 20),
      'maxDepth (null-exclusion)': const DiveFilterState(maxDepth: 20),
      'favoritesOnly': const DiveFilterState(favoritesOnly: true),
      'buddyNameFilter': const DiveFilterState(buddyNameFilter: 'alice'),
      'diveIds': const DiveFilterState(diveIds: ['d1', 'd4']),
      'minO2Percent (any-tank)': const DiveFilterState(minO2Percent: 30),
      'maxO2Percent (any-tank)': const DiveFilterState(maxO2Percent: 20),
      'minRating (null-exclusion)': const DiveFilterState(minRating: 4),
      'minBottomTimeMinutes': const DiveFilterState(minBottomTimeMinutes: 30),
      'maxBottomTimeMinutes': const DiveFilterState(maxBottomTimeMinutes: 20),
      'computerSerial': const DiveFilterState(computerSerial: 'AAA111'),
      'customFieldKey only': const DiveFilterState(customFieldKey: 'visMeters'),
      'customFieldKey + value substring': const DiveFilterState(
        customFieldKey: 'visMeters',
        customFieldValue: '1',
      ),
      'combo: tag + O2': const DiveFilterState(
        tagIds: ['dry'],
        minO2Percent: 30,
      ),
      'combo: center + rating': const DiveFilterState(
        diveCenterId: 'c1',
        minRating: 3,
      ),
      'combo: equipment + favorites': const DiveFilterState(
        equipmentIds: ['eq1', 'eq2'],
        favoritesOnly: true,
      ),
    };

    for (final entry in battery.entries) {
      final filter = entry.value;
      final applied = filter.apply(domainDives).map((d) => d.id).toSet();
      final sqld = await idsMatching(filter);
      expect(
        sqld,
        applied,
        reason:
            '${entry.key}: buildFilteredDiveIdSubquery and '
            'DiveFilterState.apply() must select the same dive ids '
            '(filter: $filter)',
      );
    }

    // Hand-verified expected sets for the axes prioritized by the review
    // (O2 any-tank, equipment any-match, multi-tag, custom field
    // key/value, computerSerial, diveCenterId, depth/rating
    // null-exclusion), so a bug shared by BOTH apply() and the SQL builder
    // can't hide behind their mutual agreement.
    expect(await idsMatching(battery['siteId']!), {'d1', 'd4', 'd7'});
    expect(await idsMatching(battery['diveCenterId']!), {'d1', 'd2', 'd7'});
    expect(await idsMatching(battery['equipment (ANY)']!), {'d1', 'd2', 'd6'});
    expect(await idsMatching(battery['multi tag (ANY)']!), {
      'd1',
      'd2',
      'd4',
      'd5',
      'd7',
    });
    expect(
      await idsMatching(battery['minDepth (null-exclusion)']!),
      {'d2', 'd4', 'd6'},
      reason: 'd3 (null maxDepth) must be excluded once minDepth is set',
    );
    expect(
      await idsMatching(battery['minRating (null-exclusion)']!),
      {'d2', 'd5'},
      reason: 'd3/d6 (null rating) must be excluded once minRating is set',
    );
    expect(
      await idsMatching(battery['minO2Percent (any-tank)']!),
      {'d2', 'd5'},
      reason: 'ANY-tank semantics: d5 matches via its second (100%) tank',
    );
    expect(await idsMatching(battery['computerSerial']!), {'d4'});
    expect(
      await idsMatching(battery['customFieldKey + value substring']!),
      {'d6'},
      reason: "only d6's visMeters value ('15') contains '1'",
    );
    expect(await idsMatching(battery['combo: tag + O2']!), {'d2', 'd5'});
    expect(await idsMatching(battery['combo: center + rating']!), {'d1', 'd2'});
    expect(await idsMatching(battery['combo: equipment + favorites']!), {'d2'});
  });
}
