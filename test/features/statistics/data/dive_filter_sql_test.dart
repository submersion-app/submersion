import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/statistics/data/dive_filter_sql.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ProfileSeriesRepository seriesRepository;

  setUp(() async {
    db = await setUpTestDatabase();
    seriesRepository = ProfileSeriesRepository();
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
    String? computerId,
    String? buddy,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            // dive_date_time holds a wall clock flagged as UTC (the digits
            // on the computer face, stored verbatim), so the fixture has to
            // write the same frame the app does. Passing a LOCAL DateTime's
            // raw epoch would shift the stored wall clock by the machine's
            // UTC offset and quietly move these dives to another day under
            // any non-UTC zone (issue #1368).
            diveDateTime: Value(
              asWallClockUtc(
                date ?? DateTime(2026, 6, 1),
              ).millisecondsSinceEpoch,
            ),
            siteId: Value(siteId),
            diveCenterId: Value(diveCenterId),
            tripId: Value(tripId),
            maxDepth: Value(maxDepth),
            rating: Value(rating),
            bottomTime: Value(bottomTimeSeconds),
            isFavorite: Value(favorite),
            computerId: Value(computerId),
            buddy: Value(buddy),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  /// Registers a dive computer. Issue #1064: these carry no serial number,
  /// mirroring the firmware that never reports one -- attribution must still
  /// work.
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

  Future<void> insertBuddy(String id, String name) async {
    await db
        .into(db.buddies)
        .insert(
          BuddiesCompanion(
            id: Value(id),
            name: Value(name),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> linkBuddy(String diveId, String buddyId) async {
    await db
        .into(db.diveBuddies)
        .insert(
          DiveBuddiesCompanion(
            id: Value('$diveId-$buddyId'),
            diveId: Value(diveId),
            buddyId: Value(buddyId),
            createdAt: Value(now),
          ),
        );
  }

  // dive_dive_types.dive_type_id carries no FK (see DiveDiveTypes in
  // database.dart), so arbitrary slug strings are valid without seeding a
  // dive_types row.
  Future<void> insertProfilePoint(
    String diveId,
    String id, {
    int timestamp = 0,
    double depth = 30,
    int? decoType,
    double? ceiling,
  }) async {
    await seriesRepository.insertSeries(
      diveId: diveId,
      id: id,
      samples: [
        ProfileSample(
          timestamp: timestamp,
          depth: depth,
          decoType: decoType,
          ceiling: ceiling,
        ),
      ],
      now: now,
    );
  }

  Future<void> insertProfileEvent(
    String diveId,
    String id, {
    String eventType = 'decoStopStart',
  }) async {
    await db
        .into(db.diveProfileEvents)
        .insert(
          DiveProfileEventsCompanion(
            id: Value(id),
            diveId: Value(diveId),
            timestamp: const Value(0),
            eventType: Value(eventType),
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

  test('an active axis yields a self-contained fq-aliased subquery', () {
    final s = buildFilteredDiveIdSubquery(const DiveFilterState(siteId: 's1'));
    expect(s.subquery, startsWith('SELECT fq.id FROM dives fq WHERE'));
    expect(s.params, ['s1']);
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

  test('weekday filter matches ANY selected weekday', () async {
    // 28 days apart (4 whole weeks) guarantees the same weekday regardless
    // of which actual day of the week these calendar dates land on.
    final mondayA = DateTime(2026, 6, 8);
    final mondayB = DateTime(2026, 7, 6);
    final tuesday = DateTime(2026, 6, 9);
    await insertDive('mon-a', date: mondayA);
    await insertDive('mon-b', date: mondayB);
    await insertDive('tue', date: tuesday);

    expect(await idsMatching(DiveFilterState(weekdays: [mondayA.weekday])), {
      'mon-a',
      'mon-b',
    });
    expect(
      await idsMatching(
        DiveFilterState(weekdays: [mondayA.weekday, tuesday.weekday]),
      ),
      {'mon-a', 'mon-b', 'tue'},
    );
  });

  test('weekday filter ANDs with date range when both are set', () async {
    final mondayInRange = DateTime(2026, 6, 8);
    final mondayOutOfRange = DateTime(2026, 7, 6);
    final tuesdayInRange = DateTime(2026, 6, 9);
    await insertDive('mon-in', date: mondayInRange);
    await insertDive('mon-out', date: mondayOutOfRange);
    await insertDive('tue-in', date: tuesdayInRange);

    final filter = DiveFilterState(
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 6, 30),
      weekdays: [mondayInRange.weekday],
    );
    expect(await idsMatching(filter), {'mon-in'});
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
    'decoOnly axis: recorded signal (stop, no-stop, ceiling-only, event-only, '
    'unrecorded)',
    () async {
      await insertDive('stop'); // deco: a deco_type = 2 point
      await insertDive('noStop'); // no-deco: has deco_type, none is 2
      await insertDive('ceilingOnly'); // deco: positive ceiling, no deco_type
      await insertDive('eventOnly'); // deco: decoStopStart event only
      await insertDive('none'); // unrecorded: no profile data at all

      await insertProfilePoint('stop', 'p-stop-1', decoType: 0);
      await insertProfilePoint('stop', 'p-stop-2', decoType: 2);

      await insertProfilePoint('noStop', 'p-noStop-1', decoType: 0);

      await insertProfilePoint('ceilingOnly', 'p-ceiling-1', ceiling: 3.0);

      await insertProfilePoint('eventOnly', 'p-event-1');
      await insertProfileEvent('eventOnly', 'e-event-1');

      expect(await idsMatching(const DiveFilterState(decoOnly: true)), {
        'stop',
        'ceilingOnly',
        'eventOnly',
      });
      expect(await idsMatching(const DiveFilterState(decoOnly: false)), {
        'noStop',
      });
    },
  );

  test(
    'noBuddyOnly excludes both legacy and junction-linked buddies',
    () async {
      await insertDive('legacy', buddy: 'Alice');
      await insertDive('none');
      await insertDive('empty', buddy: '');
      await insertBuddy('b1', 'Bob Buddy');
      await insertDive('linked');
      await linkBuddy('linked', 'b1');

      expect(await idsMatching(const DiveFilterState(noBuddyOnly: true)), {
        'none',
        'empty',
      });
    },
  );

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
                diveDateTime: Value(
                  asWallClockUtc(date).millisecondsSinceEpoch,
                ),
                bottomTime: Value(bt),
                createdAt: Value(now),
                updatedAt: Value(now),
              ),
            );
      }

      for (final filter in <DiveFilterState>[
        DiveFilterState(
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 6, 30),
        ),
        const DiveFilterState(maxBottomTimeMinutes: 2),
        const DiveFilterState(minBottomTimeMinutes: 2),
      ]) {
        final applied = await DiveRepository().getDiveIdsMatching(filter);
        final sqld = await idsMatching(filter);
        expect(sqld, applied, reason: 'mismatch for $filter');
      }
    },
  );
}
