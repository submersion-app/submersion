import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/dive_time_wall_clock_shift.dart';

import '../../helpers/test_database.dart';

/// A zone like Australia/Sydney: UTC+10 in the southern winter, UTC+11
/// from October to April. Pinning it keeps these tests meaningful on a CI
/// runner in UTC, where every offset is zero and the bug cannot show.
Duration _sydneyLikeOffsetAt(int epochMs) {
  final month = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).month;
  final summer = month >= 10 || month <= 3;
  return Duration(hours: summer ? 11 : 10);
}

/// The local epoch of a clock reading in the zone above.
int _sydneyLikeLocalEpoch(DateTime wallClock) {
  final asUtc = DateTime.utc(
    wallClock.year,
    wallClock.month,
    wallClock.day,
    wallClock.hour,
    wallClock.minute,
  ).millisecondsSinceEpoch;
  return asUtc - _sydneyLikeOffsetAt(asUtc).inMilliseconds;
}

void main() {
  group('Dive time migration', () {
    // Issue #3656: the shift used today's offset, so in a daylight saving
    // zone a dive from the other half of the year moved by an hour. Both
    // halves are checked so the test fails in every such zone on every date.
    for (final manualDt in [
      DateTime(2024, 6, 15, 8, 42),
      DateTime(2024, 12, 15, 8, 42),
    ]) {
      test('manual dive on ${manualDt.month}/${manualDt.day} keeps its '
          'wall-clock reading as UTC in the device zone', () {
        final migratedDt = DateTime.fromMillisecondsSinceEpoch(
          localEpochToWallClockUtc(manualDt.millisecondsSinceEpoch),
          isUtc: true,
        );

        expect(migratedDt.month, manualDt.month);
        expect(migratedDt.day, manualDt.day);
        expect(migratedDt.hour, manualDt.hour);
        expect(migratedDt.minute, manualDt.minute);
      });
    }

    test('uses the offset in force at the dive, not the current one', () {
      final winter = _sydneyLikeLocalEpoch(DateTime(2024, 6, 15, 8, 42));
      final summer = _sydneyLikeLocalEpoch(DateTime(2024, 12, 15, 8, 42));

      expect(
        localEpochToWallClockUtc(winter, offsetAt: _sydneyLikeOffsetAt),
        DateTime.utc(2024, 6, 15, 8, 42).millisecondsSinceEpoch,
      );
      expect(
        localEpochToWallClockUtc(summer, offsetAt: _sydneyLikeOffsetAt),
        DateTime.utc(2024, 12, 15, 8, 42).millisecondsSinceEpoch,
      );
    });
  });

  group('shiftLocalDiveTimesToWallClockUtc', () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });
    tearDown(() async {
      await db.close();
    });

    Future<void> insertDive(
      String id, {
      required int diveDateTime,
      int? entryTime,
      int? exitTime,
      int? importVersion,
    }) async {
      await db.customStatement(
        'INSERT INTO dives (id, dive_date_time, entry_time, exit_time, '
        'import_version, created_at, updated_at) '
        'VALUES (?, ?, ?, ?, ?, 0, 0)',
        [id, diveDateTime, entryTime, exitTime, importVersion],
      );
    }

    Future<Map<String, Object?>> readDive(String id) async {
      final row = await db
          .customSelect(
            'SELECT dive_date_time, entry_time, exit_time, import_version '
            'FROM dives WHERE id = ?',
            variables: [Variable.withString(id)],
          )
          .getSingle();
      return row.data;
    }

    test('shifts each timestamp by the offset at its own instant', () async {
      await insertDive(
        'winter',
        diveDateTime: _sydneyLikeLocalEpoch(DateTime(2024, 6, 15, 8, 42)),
        entryTime: _sydneyLikeLocalEpoch(DateTime(2024, 6, 15, 8, 42)),
        exitTime: _sydneyLikeLocalEpoch(DateTime(2024, 6, 15, 9, 30)),
      );
      await insertDive(
        'summer',
        diveDateTime: _sydneyLikeLocalEpoch(DateTime(2024, 12, 15, 8, 42)),
      );

      final changed = await shiftLocalDiveTimesToWallClockUtc(
        db,
        offsetAt: _sydneyLikeOffsetAt,
      );

      expect(changed, 2);
      expect(await readDive('winter'), {
        'dive_date_time': DateTime.utc(
          2024,
          6,
          15,
          8,
          42,
        ).millisecondsSinceEpoch,
        'entry_time': DateTime.utc(2024, 6, 15, 8, 42).millisecondsSinceEpoch,
        'exit_time': DateTime.utc(2024, 6, 15, 9, 30).millisecondsSinceEpoch,
        'import_version': 1,
      });
      expect(await readDive('summer'), {
        'dive_date_time': DateTime.utc(
          2024,
          12,
          15,
          8,
          42,
        ).millisecondsSinceEpoch,
        'entry_time': null,
        'exit_time': null,
        'import_version': 1,
      });
    });

    test('leaves dives that already have an import version alone', () async {
      final epoch = DateTime.utc(2024, 6, 15, 8, 42).millisecondsSinceEpoch;
      await insertDive('computer', diveDateTime: epoch, importVersion: 1);

      final changed = await shiftLocalDiveTimesToWallClockUtc(
        db,
        offsetAt: _sydneyLikeOffsetAt,
      );

      expect(changed, 0);
      expect((await readDive('computer'))['dive_date_time'], epoch);
    });
  });
}
