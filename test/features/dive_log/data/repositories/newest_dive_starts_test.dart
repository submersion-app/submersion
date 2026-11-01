import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';

/// `getNewestDiveStarts`: the bounded, ordered dive window the career
/// terrain opens from (issue #3857).
void main() {
  late AppDatabase db;
  late DiveRepository repository;

  final now = DateTime.utc(2026, 1, 1).millisecondsSinceEpoch;
  final base = DateTime.utc(2026, 3, 1, 9);

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    for (final site in ['reef', 'wall']) {
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion(
              id: Value(site),
              name: Value(site),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }
    for (final diver in ['me', 'buddy']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: diver,
              name: diver,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  Future<void> dive(
    String id, {
    required DateTime date,
    DateTime? entry,
    String? siteId,
    String? diverId,
    int? number,
  }) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          siteId: Value(siteId),
          diverId: Value(diverId),
          diveNumber: Value(number),
          diveDateTime: Value(date.millisecondsSinceEpoch),
          entryTime: Value(entry?.millisecondsSinceEpoch),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );

  List<String> ids(List<({String id, DateTime start})> starts) => [
    for (final s in starts) s.id,
  ];

  test('newest first by entry time, else dive date, capped', () async {
    await dive('a', date: base, entry: base, siteId: 'reef');
    // A legacy row: no entry time, so its dive date orders it.
    await dive('b', date: base.add(const Duration(days: 2)), siteId: 'reef');
    await dive(
      'c',
      date: base,
      entry: base.add(const Duration(days: 1)),
      siteId: 'reef',
    );
    await dive(
      'd',
      date: base.add(const Duration(days: 3)),
      entry: base.add(const Duration(days: 3)),
      siteId: 'reef',
    );

    final starts = await repository.getNewestDiveStarts(
      siteId: 'reef',
      limit: 3,
    );

    expect(ids(starts), ['d', 'b', 'c']);
    expect(starts[1].start, base.add(const Duration(days: 2)));
    expect(starts[1].start.isUtc, isTrue, reason: 'stored wall clock as UTC');
  });

  test('ties on start fall to the higher dive number', () async {
    await dive('low', date: base, entry: base, siteId: 'reef', number: 7);
    await dive('high', date: base, entry: base, siteId: 'reef', number: 8);

    final starts = await repository.getNewestDiveStarts(
      siteId: 'reef',
      limit: 10,
    );

    expect(ids(starts), ['high', 'low']);
  });

  test('a site query reads that site only, whatever the dates', () async {
    await dive('reef', date: base, entry: base, siteId: 'reef');
    await dive('wall', date: base, entry: base, siteId: 'wall');
    await dive('nowhere', date: base, entry: base);

    final starts = await repository.getNewestDiveStarts(
      siteId: 'reef',
      from: base.add(const Duration(days: 1)),
      to: base.add(const Duration(days: 2)),
      limit: 10,
    );

    expect(ids(starts), ['reef']);
  });

  test('a date window is inclusive at both ends and open when a bound is '
      'missing', () async {
    await dive('before', date: base.subtract(const Duration(seconds: 1)));
    await dive('from', date: base);
    await dive('to', date: base.add(const Duration(days: 1)));
    await dive('after', date: base.add(const Duration(days: 1, seconds: 1)));

    expect(
      ids(
        await repository.getNewestDiveStarts(
          from: base,
          to: base.add(const Duration(days: 1)),
          limit: 10,
        ),
      ),
      ['to', 'from'],
    );
    expect(ids(await repository.getNewestDiveStarts(from: base, limit: 10)), [
      'after',
      'to',
      'from',
    ]);
    expect(ids(await repository.getNewestDiveStarts(to: base, limit: 10)), [
      'from',
      'before',
    ]);
  });

  test('a diver id scopes the read; null reads every diver', () async {
    await dive('mine', date: base, siteId: 'reef', diverId: 'me');
    await dive('theirs', date: base, siteId: 'reef', diverId: 'buddy');
    await dive('nobodys', date: base, siteId: 'reef');

    expect(
      ids(
        await repository.getNewestDiveStarts(
          diverId: 'me',
          siteId: 'reef',
          limit: 10,
        ),
      ),
      ['mine'],
    );
    expect(
      (await repository.getNewestDiveStarts(siteId: 'reef', limit: 10)).length,
      3,
    );
  });

  test('empty when nothing matches', () async {
    await dive('wall', date: base, siteId: 'wall');

    expect(
      await repository.getNewestDiveStarts(siteId: 'reef', limit: 10),
      isEmpty,
    );
  });
}
