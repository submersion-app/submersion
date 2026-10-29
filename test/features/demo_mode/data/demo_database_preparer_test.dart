import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/demo_mode/data/demo_database_preparer.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 10, 26, 12);
  // The sample logbook's latest dive: 2026-03-04, a Wednesday.
  final latest = DateTime(2026, 3, 4, 9);
  final ms = latest.millisecondsSinceEpoch;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('d1', 'Alex', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO diver_settings (id, diver_id, created_at, updated_at) '
      "VALUES ('s1', 'd1', 0, 0)",
    );
    for (final (id, at) in [('a', ms - 86400000 * 30), ('b', ms)]) {
      await db.customStatement(
        'INSERT INTO dives (id, diver_id, dive_date_time, entry_time, '
        'bottom_time, runtime, created_at, updated_at) '
        "VALUES ('$id', 'd1', $at, $at, 2400, 2700, $at, $at)",
      );
    }
    await db.customStatement(
      'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
      'created_at, updated_at) '
      "VALUES ('t1', 'd1', 'Trip', ${ms - 86400000 * 3}, $ms, 0, 0)",
    );
  });

  tearDown(() => db.close());

  Future<int> intOf(String sql) async =>
      (await db.customSelect(sql).getSingle()).data.values.first as int;

  test('prepare shifts dives and trips by the same whole weeks', () async {
    await DemoDatabasePreparer().prepare(
      db,
      now: now,
      photosDir: '/demo/photos',
      deviceId: 'device-1',
    );

    final shiftedLatest = DateTime.fromMillisecondsSinceEpoch(
      await intOf("SELECT dive_date_time FROM dives WHERE id = 'b'"),
    );
    final shift = shiftedLatest.difference(latest);
    expect(shift.inDays % 7, 0);
    expect(now.difference(shiftedLatest).inDays, inInclusiveRange(6, 13));
    expect(
      await intOf("SELECT start_date FROM trips WHERE id = 't1'"),
      ms - 86400000 * 3 + shift.inMilliseconds,
    );
    expect(
      await intOf("SELECT dive_date_time FROM dives WHERE id = 'a'"),
      ms - 86400000 * 30 + shift.inMilliseconds,
    );
  });

  test(
    'the latest dive lands 7 to 13 days back by the date the app shows',
    () async {
      // Dive times are wall-clock times stored as UTC, so the app shows this
      // one on 12 October whatever the device's time zone. Late in the
      // evening, a reading in local time would land on another day far
      // from UTC (run with TZ=Pacific/Kiritimati to see it).
      final lateEvening = DateTime.utc(2026, 10, 12, 23, 30);
      await db.customStatement(
        'INSERT INTO dives (id, diver_id, dive_date_time, created_at, '
        "updated_at) VALUES ('c', 'd1', "
        '${lateEvening.millisecondsSinceEpoch}, 0, 0)',
      );

      await DemoDatabasePreparer().prepare(
        db,
        now: now,
        photosDir: '/demo/photos',
        deviceId: null,
      );

      final shown = DateTime.fromMillisecondsSinceEpoch(
        await intOf("SELECT dive_date_time FROM dives WHERE id = 'c'"),
        isUtc: true,
      );
      final days = DateTime.utc(
        now.year,
        now.month,
        now.day,
      ).difference(DateTime.utc(shown.year, shown.month, shown.day)).inDays;
      expect(days, inInclusiveRange(7, 13));
    },
  );

  test('prepare reports each step, growing to the total', () async {
    final progress = <(int, int)>[];

    await DemoDatabasePreparer().prepare(
      db,
      now: now,
      photosDir: '/demo/photos',
      deviceId: 'device-1',
      onProgress: (done, total) => progress.add((done, total)),
    );

    final total = progress.first.$2;
    expect(progress.map((e) => e.$2), everyElement(total));
    expect(progress.map((e) => e.$1), [for (var i = 1; i <= total; i++) i]);
    // One step per date column at least, so the bar moves in many steps.
    expect(total, greaterThan(10));
  });

  test(
    'prepare still reaches its total when there is nothing to shift',
    () async {
      await db.customStatement('DELETE FROM dives');
      final progress = <(int, int)>[];

      await DemoDatabasePreparer().prepare(
        db,
        now: now,
        photosDir: '/demo/photos',
        deviceId: 'device-1',
        onProgress: (done, total) => progress.add((done, total)),
      );

      final total = progress.first.$2;
      expect(progress.map((e) => e.$1), [for (var i = 1; i <= total; i++) i]);
    },
  );

  test('prepare leaves durations alone', () async {
    await DemoDatabasePreparer().prepare(
      db,
      now: now,
      photosDir: '/demo/photos',
      deviceId: null,
    );

    expect(await intOf("SELECT bottom_time FROM dives WHERE id = 'b'"), 2400);
    expect(await intOf("SELECT runtime FROM dives WHERE id = 'b'"), 2700);
  });

  test('prepare shifts the timestamps inside a GPS track', () async {
    final points = gzip.encode(
      utf8.encode(
        jsonEncode([
          [ms ~/ 1000, 1.0, 2.0, 5.0],
        ]),
      ),
    );
    await db.customInsert(
      'INSERT INTO gps_tracks (id, start_time, points, created_at, updated_at) '
      "VALUES ('g1', $ms, ?, 0, 0)",
      variables: [Variable.withBlob(Uint8List.fromList(points))],
    );

    await DemoDatabasePreparer().prepare(
      db,
      now: now,
      photosDir: '/demo/photos',
      deviceId: null,
    );

    final row = await db
        .customSelect(
          "SELECT start_time, points FROM gps_tracks WHERE id = 'g1'",
        )
        .getSingle();
    final start = row.read<int>('start_time');
    final decoded =
        jsonDecode(utf8.decode(gzip.decode(row.read<Uint8List>('points'))))
            as List;
    expect((decoded.first as List).first, start ~/ 1000);
  });

  test(
    'prepare relinks local photos into photosDir and stamps this device',
    () async {
      await db.customStatement(
        'INSERT INTO media (id, dive_id, file_path, local_path, source_type, '
        'origin_device_id, created_at, updated_at) '
        "VALUES ('m1', 'b', '/build/photos/reef.jpg', '/build/photos/reef.jpg', "
        "'localFile', 'builder', 0, 0)",
      );

      await DemoDatabasePreparer().prepare(
        db,
        now: now,
        photosDir: p.join('demo', 'photos'),
        deviceId: 'device-1',
      );

      final row = await db
          .customSelect(
            "SELECT file_path, local_path, origin_device_id FROM media WHERE id = 'm1'",
          )
          .getSingle();
      expect(
        row.read<String>('local_path'),
        p.join('demo', 'photos', 'reef.jpg'),
      );
      expect(
        row.read<String>('file_path'),
        p.join('demo', 'photos', 'reef.jpg'),
      );
      expect(row.read<String?>('origin_device_id'), 'device-1');
    },
  );

  test('prepare copies the unit settings onto the demo diver', () async {
    await DemoDatabasePreparer().prepare(
      db,
      now: now,
      photosDir: '/demo/photos',
      deviceId: null,
      units: const DemoUnitSettings({
        'depth_unit': 'feet',
        'temperature_unit': 'fahrenheit',
        'not_a_unit_column': 'ignored',
      }),
    );

    final row = await db
        .customSelect(
          "SELECT depth_unit, temperature_unit FROM diver_settings WHERE id = 's1'",
        )
        .getSingle();
    expect(row.read<String>('depth_unit'), 'feet');
    expect(row.read<String>('temperature_unit'), 'fahrenheit');
  });

  test('prepare clears scheduled notifications', () async {
    // The reminder's equipment row is irrelevant here.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement(
      'INSERT INTO scheduled_notifications (id, equipment_id, scheduled_date, '
      'reminder_days_before, notification_id, created_at) '
      "VALUES ('n1', 'e1', $ms, 7, 1, 0)",
    );

    await DemoDatabasePreparer().prepare(
      db,
      now: now,
      photosDir: '/demo/photos',
      deviceId: null,
    );

    expect(await intOf('SELECT COUNT(*) FROM scheduled_notifications'), 0);
  });
}
