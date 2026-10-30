import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3340: dives are bucketed by sunrise and sunset at the site.
void main() {
  late AppDatabase db;
  late InsightsRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = InsightsRepository();
  });
  tearDown(() async => tearDownTestDatabase());

  Future<void> site(String id, {double? latitude, double? longitude}) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          latitude: Value(latitude),
          longitude: Value(longitude),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  /// Bonaire: sunrise near 06:49 and sunset near 18:42 on 1 March 2025.
  Future<void> bonaire() => site('bonaire', latitude: 12.15, longitude: -68.27);

  int clock(int hour, int minute, {int month = 3, int day = 1}) =>
      DateTime.utc(2025, month, day, hour, minute).millisecondsSinceEpoch;

  Future<void> dive(
    String id, {
    required int start,
    bool startIsEntry = true,
    int? exit,
    int? runtime,
    int? bottomTime,
    String? siteId,
    String? diverId,
    bool excluded = false,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diverId: Value(diverId),
          diveDateTime: Value(start),
          entryTime: Value(startIsEntry ? start : null),
          exitTime: Value(exit),
          runtime: Value(runtime),
          bottomTime: Value(bottomTime),
          siteId: Value(siteId),
          excludedFromStats: Value(excluded),
          createdAt: const Value(0),
          updatedAt: const Value(0),
        ),
      );

  Future<Map<String, int>> counts() async => {
    for (final s in (await repository.getDivesByTimeOfDay()).segments)
      s.label: s.count,
  };

  test('no dives is an empty distribution', () async {
    final result = await repository.getDivesByTimeOfDay();
    expect(result.segments, isEmpty);
    expect(result.divesWithoutLocation, 0);
  });

  test('buckets against the sunrise and sunset at the site', () async {
    await bonaire();
    // Each of these would land in another bucket on fixed 06:00 / 18:00.
    await dive(
      'dawn',
      start: clock(6, 20),
      exit: clock(7, 10),
      siteId: 'bonaire',
    );
    await dive(
      'still-night',
      start: clock(6, 5),
      exit: clock(6, 35),
      siteId: 'bonaire',
    );
    await dive(
      'still-afternoon',
      start: clock(18, 5),
      exit: clock(18, 30),
      siteId: 'bonaire',
    );
    await dive(
      'dusk',
      start: clock(18, 10),
      exit: clock(19, 0),
      siteId: 'bonaire',
    );

    final result = await repository.getDivesByTimeOfDay();
    expect(
      {for (final s in result.segments) s.label: s.count},
      {'Dawn': 1, 'Afternoon': 1, 'Dusk': 1, 'Night': 1},
    );
    expect(result.divesWithoutLocation, 0);
  });

  test('segments come in the order of the day with their shares', () async {
    await bonaire();
    await dive(
      'night',
      start: clock(20, 0),
      exit: clock(20, 45),
      siteId: 'bonaire',
    );
    await dive(
      'morning-1',
      start: clock(9, 0),
      exit: clock(9, 45),
      siteId: 'bonaire',
    );
    await dive(
      'morning-2',
      start: clock(10, 0, day: 2),
      exit: clock(10, 45, day: 2),
      siteId: 'bonaire',
    );
    await dive(
      'dawn',
      start: clock(6, 20),
      exit: clock(7, 10),
      siteId: 'bonaire',
    );

    final segments = (await repository.getDivesByTimeOfDay()).segments;
    expect(segments.map((s) => s.label), ['Dawn', 'Morning', 'Night']);
    expect(segments.map((s) => s.count), [1, 2, 1]);
    expect(segments.map((s) => s.percentage), [25, 50, 25]);
  });

  test('a missing exit is the entry plus the dive time', () async {
    await bonaire();
    // 18:10 plus 50 minutes crosses the 18:42 sunset.
    await dive(
      'runtime',
      start: clock(18, 10),
      runtime: 3000,
      siteId: 'bonaire',
    );
    // Bottom time is the last resort for a dive time.
    await dive(
      'bottom-time',
      start: clock(6, 20, day: 2),
      bottomTime: 3000,
      siteId: 'bonaire',
    );
    expect(await counts(), {'Dawn': 1, 'Dusk': 1});
  });

  test('a stored exit that is not after the entry is ignored', () async {
    await bonaire();
    await dive(
      'bad-exit',
      start: clock(18, 10),
      exit: clock(18, 10),
      runtime: 3000,
      siteId: 'bonaire',
    );
    expect(await counts(), {'Dusk': 1});
  });

  test('with no exit and no dive time the entry alone decides', () async {
    await bonaire();
    await dive('entry-only', start: clock(18, 10), siteId: 'bonaire');
    await dive('before-sunrise', start: clock(6, 20), siteId: 'bonaire');
    expect(await counts(), {'Afternoon': 1, 'Night': 1});
  });

  test('the dive date stands in for a missing entry time', () async {
    await bonaire();
    await dive(
      'date-only',
      start: clock(18, 10),
      startIsEntry: false,
      runtime: 3000,
      siteId: 'bonaire',
    );
    expect(await counts(), {'Dusk': 1});
  });

  test('dives with no site location use 06:00 and 18:00', () async {
    await site('unplaced');
    await dive('no-site', start: clock(17, 30), exit: clock(18, 30));
    await dive(
      'no-coordinates',
      start: clock(5, 30, day: 2),
      exit: clock(6, 30, day: 2),
      siteId: 'unplaced',
    );
    await dive(
      'no-site-midday',
      start: clock(12, 0, day: 3),
      exit: clock(12, 40, day: 3),
    );

    final result = await repository.getDivesByTimeOfDay();
    expect(
      {for (final s in result.segments) s.label: s.count},
      {'Dawn': 1, 'Afternoon': 1, 'Dusk': 1},
    );
    expect(result.divesWithoutLocation, 3);
  });

  test('a polar dive falls back but is not counted as unplaced', () async {
    await site('tromso', latitude: 69.65, longitude: 18.96);
    await dive(
      'polar-night',
      start: clock(12, 30, month: 12, day: 21),
      exit: clock(13, 10, month: 12, day: 21),
      siteId: 'tromso',
    );

    final result = await repository.getDivesByTimeOfDay();
    expect(
      {for (final s in result.segments) s.label: s.count},
      {'Afternoon': 1},
    );
    expect(result.divesWithoutLocation, 0);
  });

  test('excluded dives and other divers are out of scope', () async {
    for (final id in ['a', 'b']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: Value(id),
              name: Value(id),
              medicalNotes: const Value(''),
              notes: const Value(''),
              isDefault: const Value(false),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
    await dive('mine', start: clock(9, 0), exit: clock(9, 45), diverId: 'a');
    await dive(
      'theirs',
      start: clock(14, 0),
      exit: clock(14, 45),
      diverId: 'b',
    );
    await dive(
      'excluded',
      start: clock(20, 0),
      exit: clock(20, 45),
      diverId: 'a',
      excluded: true,
    );

    final result = await repository.getDivesByTimeOfDay(diverId: 'a');
    expect({for (final s in result.segments) s.label: s.count}, {'Morning': 1});
    expect(result.divesWithoutLocation, 1);
  });

  test('a site at 0,0 counts as having no location', () async {
    // 0,0 is the stand-in devices write for no fix, so the dive uses the
    // default times and is named in the footnote.
    await site('null-island', latitude: 0, longitude: 0);
    await dive(
      'placeholder',
      start: clock(17, 40),
      exit: clock(18, 30),
      siteId: 'null-island',
    );

    final result = await repository.getDivesByTimeOfDay();
    expect({for (final s in result.segments) s.label: s.count}, {'Dusk': 1});
    expect(result.divesWithoutLocation, 1);
  });
}
