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
  Future<void> prepare(
    GeneratedDatabase db, {
    required DateTime now,
    required String photosDir,
    required String? deviceId,
    DemoUnitSettings? units,
  }) async {
    await db.transaction(() async {
      await _shiftDates(db, now);
      await _relinkPhotos(db, photosDir, deviceId);
      if (units != null) await _applyUnits(db, units);
      await db.customStatement('DELETE FROM scheduled_notifications');
    });
  }

  Future<void> _shiftDates(GeneratedDatabase db, DateTime now) async {
    final latest = await db
        .customSelect('SELECT MAX(dive_date_time) AS latest FROM dives')
        .getSingle();
    final latestMs = latest.read<int?>('latest');
    if (latestMs == null) return;

    // Dive times are wall-clock times stored as UTC, so the date the app
    // shows is the UTC date, whatever the device's time zone.
    final shift = demoShiftFor(
      latestDive: DateTime.fromMillisecondsSinceEpoch(latestMs, isUtc: true),
      now: now,
    );
    if (shift == Duration.zero) return;

    for (final c in demoDateColumnsOf(db)) {
      final amount = c.unit == DemoDateUnit.epochMillis
          ? shift.inMilliseconds
          : shift.inSeconds;
      await db.customUpdate(
        'UPDATE "${c.table}" SET "${c.column}" = "${c.column}" + ? '
        'WHERE "${c.column}" IS NOT NULL',
        variables: [Variable.withInt(amount)],
      );
    }
    for (final table in const ['gps_tracks', 'nav_tracks']) {
      await _shiftTrackPoints(db, table, shift.inSeconds);
    }
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
