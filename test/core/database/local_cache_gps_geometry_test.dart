import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';

void main() {
  late LocalCacheDatabase db;

  setUp(() {
    db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  test('schema version is at least 9', () {
    // greaterThanOrEqualTo: this ladder has had parallel-branch collisions
    // (bathymetry and reef both claimed v7).
    expect(db.schemaVersion, greaterThanOrEqualTo(9));
  });

  test('stores and reads back simplified geometry', () async {
    await db
        .into(db.gpsTrackGeometryCache)
        .insert(
          GpsTrackGeometryCacheCompanion.insert(
            trackId: 'track-1',
            lodLevel: 'thumbnail',
            status: 'ok',
            createdAt: 1700000000,
            points: Value(Uint8List.fromList([1, 2, 3])),
          ),
        );
    final row = await (db.select(
      db.gpsTrackGeometryCache,
    )..where((t) => t.trackId.equals('track-1'))).getSingle();
    expect(row.status, 'ok');
    expect(row.points, [1, 2, 3]);
  });

  test('caches a definitive empty result without a blob', () async {
    await db
        .into(db.gpsTrackGeometryCache)
        .insert(
          GpsTrackGeometryCacheCompanion.insert(
            trackId: 'track-2',
            lodLevel: 'detail',
            status: 'empty',
            createdAt: 1700000000,
          ),
        );
    final row = await (db.select(
      db.gpsTrackGeometryCache,
    )..where((t) => t.trackId.equals('track-2'))).getSingle();
    expect(row.status, 'empty');
    expect(row.points, isNull);
  });

  test('keys separate LOD levels for the same track independently', () async {
    for (final lod in ['thumbnail', 'overview', 'detail']) {
      await db
          .into(db.gpsTrackGeometryCache)
          .insert(
            GpsTrackGeometryCacheCompanion.insert(
              trackId: 'track-3',
              lodLevel: lod,
              status: 'ok',
              createdAt: 1700000000,
            ),
          );
    }
    final rows = await (db.select(
      db.gpsTrackGeometryCache,
    )..where((t) => t.trackId.equals('track-3'))).get();
    expect(rows.length, 3);
  });
}
