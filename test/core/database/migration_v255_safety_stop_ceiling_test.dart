import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

/// v255: a dive computer's safety stop is not a decompression ceiling
/// (#2550). Imports before the fix stored a safety stop's depth as the
/// sample ceiling, so the profile drew a deco stop band on a no-deco dive.
/// The rung drops those ceilings from every stored series and recomputes
/// the series' has_positive_ceiling. Deco and deep stop ceilings, and the
/// ceilings of sources that record no deco type, stay as they are. The sync
/// stamp does not move: every device runs the same rewrite, so they agree
/// without a sync round. 254 is #2595 (dive_tanks.role_source).
void main() {
  const codec = ProfileSeriesCodec();

  const ndl = ProfileSample(timestamp: 0, depth: 10.0, ndl: 1800, decoType: 0);
  const safety = ProfileSample(
    timestamp: 60,
    depth: 5.0,
    ceiling: 5.0,
    decoType: 1,
  );
  const deco = ProfileSample(
    timestamp: 30,
    depth: 20.0,
    ceiling: 6.0,
    decoType: 2,
  );
  const deep = ProfileSample(
    timestamp: 40,
    depth: 21.0,
    ceiling: 15.0,
    decoType: 3,
  );
  const untyped = ProfileSample(timestamp: 30, depth: 12.0, ceiling: 3.0);

  /// The series rows the stranded file holds, by id.
  final seeded = <String, List<ProfileSample>>{
    // A no-deco dive whose only ceiling is the safety stop.
    's-safety-only': [ndl, safety],
    // A deco dive that also logged a safety stop at the end.
    's-deco-and-safety': [ndl, deco, deep, safety],
    // A source with no deco types (Subsurface style) only writes a stop
    // depth during deco; it is not touched.
    's-untyped': [ndl, untyped],
  };

  Uint8List bytesOf(List<ProfileSample> samples) => codec.encode(samples).bytes;

  /// A file stranded at [userVersion] holding [seeded] plus one series
  /// whose blob does not decode.
  NativeDatabase strandedAt(int userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute(
        'CREATE TABLE dive_profile_series (id TEXT NOT NULL PRIMARY KEY, '
        'dive_id TEXT NOT NULL, sample_count INTEGER NOT NULL, '
        'start_timestamp INTEGER NOT NULL, end_timestamp INTEGER NOT NULL, '
        'max_depth REAL NOT NULL, first_depth REAL NOT NULL, '
        'last_depth REAL NOT NULL, has_deco_type INTEGER NOT NULL, '
        'has_deco_stop INTEGER NOT NULL, '
        'has_positive_ceiling INTEGER NOT NULL, '
        'codec_version INTEGER NOT NULL, samples BLOB NOT NULL, '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, hlc TEXT)',
      );
      final insert = rawDb.prepare(
        'INSERT INTO dive_profile_series VALUES '
        '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      );
      void add(String id, Uint8List bytes, List<ProfileSample> samples) {
        final encoded = codec.encode(samples);
        final summary = encoded.summary;
        insert.execute([
          id,
          'dive-$id',
          summary.sampleCount,
          summary.startTimestamp,
          summary.endTimestamp,
          summary.maxDepth,
          summary.firstDepth,
          summary.lastDepth,
          summary.hasDecoType ? 1 : 0,
          summary.hasDecoStop ? 1 : 0,
          summary.hasPositiveCeiling ? 1 : 0,
          encoded.codecVersion,
          bytes,
          1000,
          2000,
          'hlc-$id',
        ]);
      }

      for (final entry in seeded.entries) {
        add(entry.key, bytesOf(entry.value), entry.value);
      }
      add('s-corrupt', Uint8List.fromList([1, 2, 3]), [ndl, safety]);
      insert.close();
    },
  );

  Future<Map<String, Map<String, Object?>>> rows(AppDatabase db) async {
    final result = await db
        .customSelect(
          'SELECT id, samples, has_positive_ceiling, has_deco_type, '
          'has_deco_stop, updated_at, hlc FROM dive_profile_series',
        )
        .get();
    return {for (final r in result) r.read<String>('id'): r.data};
  }

  List<ProfileSample> decoded(Map<String, Object?> row) =>
      codec.decode(row['samples']! as Uint8List);

  test('v255 is at or below the current schema version and in the ladder', () {
    // Relaxed once v256 (computer tissue, #1977) landed on top; the newest
    // rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(255));
    expect(AppDatabase.migrationVersions, contains(255));
    // 254 (dive_tanks.role_source, #2595) sits directly below this rung,
    // and 253 (safety review inputs, #2592) below that.
    expect(AppDatabase.migrationVersions, containsAll([253, 254]));
    final above255 = AppDatabase.migrationStepCount(255);
    expect(AppDatabase.migrationStepCount(254), above255 + 1);
    expect(AppDatabase.migrationStepCount(252), above255 + 3);
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a database at v252 loses its safety stop ceilings and keeps every '
      'other ceiling', () async {
    final db = AppDatabase(strandedAt(252));
    addTearDown(db.close);
    final after = await rows(db);

    final safetyOnly = after['s-safety-only']!;
    expect(decoded(safetyOnly), [ndl, safety.withoutSafetyStopCeiling()]);
    expect(safetyOnly['has_positive_ceiling'], 0);
    expect(safetyOnly['has_deco_type'], 1);
    expect(safetyOnly['has_deco_stop'], 0);

    final mixed = after['s-deco-and-safety']!;
    expect(decoded(mixed), [
      ndl,
      deco,
      deep,
      safety.withoutSafetyStopCeiling(),
    ]);
    expect(mixed['has_positive_ceiling'], 1);
    expect(mixed['has_deco_stop'], 1);

    final untypedRow = after['s-untyped']!;
    expect(untypedRow['samples'], bytesOf(seeded['s-untyped']!));
    expect(untypedRow['has_positive_ceiling'], 1);
  });

  test('the rewrite leaves the sync stamp alone and steps over a blob it '
      'cannot read', () async {
    final db = AppDatabase(strandedAt(252));
    addTearDown(db.close);
    final after = await rows(db);

    for (final id in ['s-safety-only', 's-deco-and-safety']) {
      expect(after[id]!['updated_at'], 2000, reason: id);
      expect(after[id]!['hlc'], 'hlc-$id', reason: id);
    }
    final corrupt = after['s-corrupt']!;
    expect(corrupt['samples'], Uint8List.fromList([1, 2, 3]));
    expect(corrupt['has_positive_ceiling'], 1);
  });

  test('a database already at v255 is not rewritten again', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    final after = await rows(db);
    expect(
      after['s-safety-only']!['samples'],
      bytesOf(seeded['s-safety-only']!),
    );
    expect(after['s-safety-only']!['has_positive_ceiling'], 1);
  });
}
