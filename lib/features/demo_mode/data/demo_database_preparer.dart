import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/features/demo_mode/data/demo_date_columns.dart';

/// The `diver_settings` columns that follow the user into demo mode, so the
/// sample logbook reads in units and formats they already know.
const demoUnitSettingColumns = {
  'depth_unit',
  'temperature_unit',
  'pressure_unit',
  'volume_unit',
  'weight_unit',
  'altitude_unit',
  'distance_unit',
  'coordinate_format',
  'time_format',
  'date_format',
  'theme_mode',
};

/// Values for [demoUnitSettingColumns], keyed by column name. Other keys are
/// ignored.
class DemoUnitSettings {
  const DemoUnitSettings(this.values);

  final Map<String, Object?> values;
}

/// Makes a freshly opened sample logbook fit this device and this day.
///
/// The published file is built once, so its dates would grow stale and its
/// photo paths point at the build machine. [prepare] moves every instant by
/// the same whole number of weeks, relinks the photos into the downloaded
/// photo folder, applies the user's units, and drops device-local
/// notification rows the app rebuilds itself.
class DemoDatabasePreparer {
  static const _trackTables = ['gps_tracks', 'nav_tracks'];

  /// [onProgress] hears each step done, out of the total: one per date
  /// column and per track table, then the photos, units and notifications.
  Future<void> prepare(
    GeneratedDatabase db, {
    required DateTime now,
    required String photosDir,
    required String? deviceId,
    DemoUnitSettings? units,
    void Function(int done, int total)? onProgress,
  }) async {
    final columns = demoDateColumnsOf(db);
    final total = columns.length + _trackTables.length + 3;
    var done = 0;
    void step() => onProgress?.call(++done, total);

    await db.transaction(() async {
      await _shiftDates(db, now, columns, step);
      await _relinkPhotos(db, photosDir, deviceId);
      step();
      if (units != null) await _applyUnits(db, units);
      step();
      await db.customStatement('DELETE FROM scheduled_notifications');
      step();
    });
  }

  /// Steps through every column and track table even when nothing moves, so
  /// the progress still reaches its total.
  Future<void> _shiftDates(
    GeneratedDatabase db,
    DateTime now,
    List<DemoDateColumn> columns,
    void Function() step,
  ) async {
    final shift = await _shiftFor(db, now);
    for (final c in columns) {
      if (shift != Duration.zero) {
        final amount = c.unit == DemoDateUnit.epochMillis
            ? shift.inMilliseconds
            : shift.inSeconds;
        await db.customUpdate(
          'UPDATE "${c.table}" SET "${c.column}" = "${c.column}" + ? '
          'WHERE "${c.column}" IS NOT NULL',
          variables: [Variable.withInt(amount)],
        );
      }
      step();
    }
    for (final table in _trackTables) {
      if (shift != Duration.zero) {
        await _shiftTrackPoints(db, table, shift.inSeconds);
      }
      step();
    }
  }

  /// How far to move every instant: zero for a logbook without dives.
  Future<Duration> _shiftFor(GeneratedDatabase db, DateTime now) async {
    final latest = await db
        .customSelect('SELECT MAX(dive_date_time) AS latest FROM dives')
        .getSingle();
    final latestMs = latest.read<int?>('latest');
    if (latestMs == null) return Duration.zero;

    // Dive times are wall-clock times stored as UTC, so the date the app
    // shows is the UTC date, whatever the device's time zone.
    return demoShiftFor(
      latestDive: DateTime.fromMillisecondsSinceEpoch(latestMs, isUtc: true),
      now: now,
    );
  }

  /// Track points are gzipped JSON arrays whose first element is the fix's
  /// wall-clock epoch seconds.
  Future<void> _shiftTrackPoints(
    GeneratedDatabase db,
    String table,
    int seconds,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT id, points FROM "$table" WHERE points IS NOT NULL',
        )
        .get();
    for (final row in rows) {
      final points =
          jsonDecode(utf8.decode(gzip.decode(row.read<Uint8List>('points'))))
              as List;
      final shifted = [
        for (final point in points)
          if (point is List && point.isNotEmpty && point.first is num)
            [(point.first as num) + seconds, ...point.skip(1)]
          else
            point,
      ];
      await db.customUpdate(
        'UPDATE "$table" SET points = ? WHERE id = ?',
        variables: [
          Variable.withBlob(
            Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(shifted)))),
          ),
          Variable.withString(row.read<String>('id')),
        ],
      );
    }
  }

  Future<void> _relinkPhotos(
    GeneratedDatabase db,
    String photosDir,
    String? deviceId,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT id, file_path, local_path FROM media '
          "WHERE source_type = 'localFile'",
        )
        .get();
    for (final row in rows) {
      final old =
          row.read<String?>('local_path') ?? row.read<String>('file_path');
      final path = p.join(photosDir, p.basename(old.replaceAll(r'\', '/')));
      await db.customUpdate(
        'UPDATE media SET file_path = ?, local_path = ?, origin_device_id = ? '
        'WHERE id = ?',
        variables: [
          Variable.withString(path),
          Variable.withString(path),
          Variable(deviceId),
          Variable.withString(row.read<String>('id')),
        ],
      );
    }
  }

  Future<void> _applyUnits(GeneratedDatabase db, DemoUnitSettings units) async {
    final entries = units.values.entries
        .where((e) => demoUnitSettingColumns.contains(e.key) && e.value != null)
        .toList();
    if (entries.isEmpty) return;
    await db.customUpdate(
      'UPDATE diver_settings SET '
      '${entries.map((e) => '"${e.key}" = ?').join(', ')}',
      variables: [for (final e in entries) Variable(e.value)],
    );
  }
}
