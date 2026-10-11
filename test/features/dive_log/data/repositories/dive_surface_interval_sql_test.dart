import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_times_sql.dart';

import '../../../../helpers/test_database.dart';

/// The one surface interval definition (#2984) the dive table, the
/// `surfaceInterval` query field and Insights all read.
void main() {
  late AppDatabase db;

  setUp(() async => db = await setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  final base = DateTime.utc(2026, 4, 1, 10).millisecondsSinceEpoch;
  const minute = 60 * 1000;

  Future<void> insert(
    String id, {
    int? entry,
    int? exit,
    int? dateTime,
    int? runtimeSeconds,
    int? storedSi,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(dateTime ?? entry ?? base),
            entryTime: Value(entry),
            exitTime: Value(exit),
            runtime: Value(runtimeSeconds),
            surfaceIntervalSeconds: Value(storedSi),
            createdAt: Value(base),
            updatedAt: Value(base),
          ),
        );
  }

  /// Each dive's interval and its SQLite type.
  Future<Map<String, (int?, String)>> intervals() async {
    final rows = await db
        .customSelect(
          'SELECT d.id AS id, ${diveSurfaceIntervalSecondsSql('d')} AS si, '
          "typeof(${diveSurfaceIntervalSecondsSql('d')}) AS t FROM dives d",
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('id'): (r.readNullable<int>('si'), r.read<String>('t')),
    };
  }

  test('first dive has no interval', () async {
    await insert('a', entry: base, exit: base + 40 * minute);
    expect((await intervals())['a'], (null, 'null'));
  });

  test(
    'gap runs from the previous exit to this entry, as an integer',
    () async {
      await insert('a', entry: base, exit: base + 40 * minute + 500);
      await insert('b', entry: base + 120 * minute, exit: base + 160 * minute);
      // 80 min minus the 500 ms the previous exit ran over, truncated.
      expect((await intervals())['b'], (80 * 60 - 1, 'integer'));
    },
  );

  test('a stored interval wins over the computed gap', () async {
    await insert('a', entry: base, exit: base + 40 * minute);
    await insert('b', entry: base + 120 * minute, storedSi: 3600);
    expect((await intervals())['b'], (3600, 'integer'));
  });

  test('previous exit falls back to its start plus its runtime', () async {
    await insert('a', entry: base, runtimeSeconds: 50 * 60);
    await insert('b', entry: base + 120 * minute);
    expect((await intervals())['b'], (70 * 60, 'integer'));
  });

  test('an overlapping dive clamps to zero', () async {
    await insert('a', entry: base, exit: base + 60 * minute);
    await insert('b', entry: base + 30 * minute);
    expect((await intervals())['b'], (0, 'integer'));
  });

  test('a dive with an entry time ranks above a later one without', () async {
    // getPreviousDiveTimes orders by entry_time DESC, so a null-entry dive
    // is the previous one only when no dive with an entry time precedes.
    await insert('a', entry: base, exit: base + 10 * minute);
    await insert('legacy', dateTime: base + 60 * minute);
    await insert('b', entry: base + 120 * minute);
    expect((await intervals())['b'], (110 * 60, 'integer'));
  });

  test('a null-entry dive is the previous one when nothing else is', () async {
    await insert('legacy', dateTime: base);
    await insert('b', entry: base + 30 * minute);
    expect((await intervals())['b'], (30 * 60, 'integer'));
  });

  test('previousScope narrows the previous dive', () async {
    await insert('a', entry: base, exit: base + 10 * minute);
    await insert('skip', entry: base + 60 * minute, exit: base + 70 * minute);
    await insert('b', entry: base + 120 * minute);
    const scope = " AND $kSurfaceIntervalPreviousAlias.id != 'skip'";
    final row = await db
        .customSelect(
          'SELECT ${diveSurfaceIntervalSecondsSql('d', previousScope: scope)} '
          "AS si FROM dives d WHERE d.id = 'b'",
        )
        .getSingle();
    expect(row.read<int>('si'), 110 * 60);
  });
}
