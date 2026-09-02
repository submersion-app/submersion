import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/profile_series_pack.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_field_table.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';

import '../../helpers/legacy_profile_fixtures.dart';

/// Every sample-bearing column of the v181 `dive_profiles` table, with a
/// value distinct from every other value in the map.
///
/// `profileSampleOf` is the ONLY decode path of the v182/v183 migration and
/// it reads by column name, yielding null for a name it gets wrong. Without
/// a fixture that carries every column and a test that asserts every value
/// survives, a single mistyped name would silently drop that field for
/// every upgrading user while the suite stayed green.
const Map<String, Object?> everyProfileColumn = {
  'timestamp': 7,
  'depth': 12.25,
  'pressure': 201.5,
  'temperature': 18.75,
  'heart_rate': 132,
  'ascent_rate': 9.5,
  'ceiling': 3.5,
  'ndl': 1234,
  'setpoint': 1.3,
  'pp_o2': 1.21,
  'o2_sensor1': 1.01,
  'o2_sensor2': 1.02,
  'o2_sensor3': 1.03,
  'o2_sensor4': 1.04,
  'o2_sensor5': 1.05,
  'o2_sensor6': 1.06,
  'cns': 42.5,
  'tts': 360,
  'rbt': 900,
  'deco_type': 2,
  'heart_rate_source': 'garmin',
  'heading': 271.5,
  'o2_sensor_mv1': 51,
  'o2_sensor_mv2': 52,
  'o2_sensor_mv3': 53,
  'o2_sensor_mv4': 54,
  'o2_sensor_mv5': 55,
  'o2_sensor_mv6': 56,
};

Set<String> columnNames(sqlite3.Database rawDb, String table) {
  return rawDb
      .select('PRAGMA table_info($table)')
      .map((row) => row['name'] as String)
      .toSet();
}

void main() {
  test('the legacy fixture declares every column the codec packs', () {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    createLegacyProfileTables(raw);

    expect(
      columnNames(raw, 'dive_profiles'),
      containsAll(kProfileFieldTableV1.map((field) => field.name)),
      reason:
          'a column the fixture omits reads as null through '
          'profileSampleOf, so no test can catch a mistyped name for it',
    );
    expect(
      columnNames(raw, 'dive_profiles'),
      containsAll(const {'id', 'dive_id', 'computer_id', 'source_id'}),
    );
    expect(
      columnNames(raw, 'tank_pressure_profiles'),
      containsAll(const {
        'id',
        'dive_id',
        'tank_id',
        'timestamp',
        'pressure',
        'computer_id',
      }),
    );
  });

  test('every legacy profile column survives the pack', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    legacyDdlAt180(raw, userVersion: 182);
    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    createLegacyProfileTables(raw);
    seedParents(raw);

    final columns = [
      'id',
      'dive_id',
      'computer_id',
      'source_id',
      'is_primary',
      ...everyProfileColumn.keys,
    ];
    final values = <Object?>[
      'p1',
      'd1',
      'c1',
      's1',
      1,
      ...everyProfileColumn.values,
    ];
    raw.execute(
      'INSERT INTO dive_profiles (${columns.join(', ')}) '
      'VALUES (${List.filled(columns.length, '?').join(', ')})',
      values,
    );

    final report = await packLegacyProfileRows(db, nowMs: 1700000000000);
    expect(report.profileSeries, 1);
    expect(report.skippedRows, 0);

    final row = await db
        .customSelect('SELECT samples FROM dive_profile_series')
        .getSingle();
    final samples = const ProfileSeriesCodec().decode(
      row.data['samples']! as Uint8List,
    );
    expect(samples, hasLength(1));
    final sample = samples.single;

    expect(sample.timestamp, everyProfileColumn['timestamp']);
    expect(sample.depth, everyProfileColumn['depth']);
    expect(sample.pressure, everyProfileColumn['pressure']);
    expect(sample.temperature, everyProfileColumn['temperature']);
    expect(sample.heartRate, everyProfileColumn['heart_rate']);
    expect(sample.ascentRate, everyProfileColumn['ascent_rate']);
    expect(sample.ceiling, everyProfileColumn['ceiling']);
    expect(sample.ndl, everyProfileColumn['ndl']);
    expect(sample.setpoint, everyProfileColumn['setpoint']);
    expect(sample.ppO2, everyProfileColumn['pp_o2']);
    expect(sample.o2Sensor1, everyProfileColumn['o2_sensor1']);
    expect(sample.o2Sensor2, everyProfileColumn['o2_sensor2']);
    expect(sample.o2Sensor3, everyProfileColumn['o2_sensor3']);
    expect(sample.o2Sensor4, everyProfileColumn['o2_sensor4']);
    expect(sample.o2Sensor5, everyProfileColumn['o2_sensor5']);
    expect(sample.o2Sensor6, everyProfileColumn['o2_sensor6']);
    expect(sample.cns, everyProfileColumn['cns']);
    expect(sample.tts, everyProfileColumn['tts']);
    expect(sample.rbt, everyProfileColumn['rbt']);
    expect(sample.decoType, everyProfileColumn['deco_type']);
    expect(sample.heartRateSource, everyProfileColumn['heart_rate_source']);
    expect(sample.heading, everyProfileColumn['heading']);
    expect(sample.o2SensorMv1, everyProfileColumn['o2_sensor_mv1']);
    expect(sample.o2SensorMv2, everyProfileColumn['o2_sensor_mv2']);
    expect(sample.o2SensorMv3, everyProfileColumn['o2_sensor_mv3']);
    expect(sample.o2SensorMv4, everyProfileColumn['o2_sensor_mv4']);
    expect(sample.o2SensorMv5, everyProfileColumn['o2_sensor_mv5']);
    expect(sample.o2SensorMv6, everyProfileColumn['o2_sensor_mv6']);
  });

  test('every legacy tank pressure column survives the pack', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    addTearDown(raw.close);
    legacyDdlAt180(raw, userVersion: 182);
    final db = AppDatabase(
      NativeDatabase.opened(raw, closeUnderlyingOnClose: false),
    );
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    createLegacyProfileTables(raw);
    seedParents(raw);

    raw.execute(
      'INSERT INTO tank_pressure_profiles (id, dive_id, tank_id, timestamp, '
      "pressure, computer_id) VALUES ('q1', 'd1', 't1', 42, 187.5, 'c1')",
    );

    final report = await packLegacyProfileRows(db, nowMs: 1700000000000);
    expect(report.tankSeries, 1);
    expect(report.skippedRows, 0);

    final row = await db
        .customSelect(
          'SELECT tank_id, computer_id, samples FROM tank_pressure_series',
        )
        .getSingle();
    expect(row.data['tank_id'], 't1');
    expect(row.data['computer_id'], 'c1');
    final samples = const TankPressureSeriesCodec().decode(
      row.data['samples']! as Uint8List,
    );
    expect(samples, hasLength(1));
    expect(samples.single.timestamp, 42);
    expect(samples.single.pressure, 187.5);
  });
}
