// Only Value is needed; a bare drift import collides with matcher's isNull.
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

import '../../helpers/test_database.dart';

/// Every write path must stamp `hlc`, because _exportGpsTracks selects on
/// `hlc > hlcSince` and SQL NULL is never greater than anything. A row with a
/// null hlc silently never rides an incremental changeset - it looks saved
/// locally and simply does not exist on any other device.
///
/// updatedAt is NOT a substitute: the export never reads it.
void main() {
  late GpsTrackRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = GpsTrackRepository();
  });

  tearDown(tearDownTestDatabase);

  Future<String?> hlcOf(String id) async {
    final db = DatabaseService.instance.database;
    final row = await (db.select(
      db.gpsTracks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.hlc;
  }

  List<GpsTrackPoint> points(int count) => [
    for (var i = 0; i < count; i++)
      GpsTrackPoint(
        timestamp: 1700000000 + i * 3600,
        latitude: 20.0 + i * 0.01,
        longitude: -87.0,
      ),
  ];

  Future<String> seedRecorded() async {
    final id = await repo.startTrack(
      startTimeMs: 1700000000000,
      tzOffsetMinutes: 0,
    );
    for (final p in points(5)) {
      await repo.appendBufferPoint(id, p);
    }
    await repo.finalizeTrack(id, endTimeMs: 1700014400000);
    return id;
  }

  test('an imported track is stamped pending', () async {
    final id = await repo.insertImportedTrack(
      points: points(3),
      startTimeMs: 1700000000000,
      endTimeMs: 1700007200000,
      tzOffsetMinutes: -300,
      source: 'gpx',
      sourceRef: 'day3.gpx',
    );
    expect(await hlcOf(id), isNotNull);
  });

  test('setTrimBounds stamps pending', () async {
    final id = await seedRecorded();
    final db = DatabaseService.instance.database;
    // Clear the hlc left by finalizeTrack so the trim's own stamp is what
    // this assertion observes.
    await (db.update(db.gpsTracks)..where((t) => t.id.equals(id))).write(
      const GpsTracksCompanion(hlc: Value(null)),
    );
    expect(await hlcOf(id), isNull);

    await repo.setTrimBounds(id, startMs: 1700003600000);
    expect(await hlcOf(id), isNotNull);
  });

  test('clearTrim stamps pending, so an undo replicates too', () async {
    final id = await seedRecorded();
    await repo.setTrimBounds(id, startMs: 1700003600000);
    final db = DatabaseService.instance.database;
    await (db.update(db.gpsTracks)..where((t) => t.id.equals(id))).write(
      const GpsTracksCompanion(hlc: Value(null)),
    );

    await repo.clearTrim(id);
    expect(await hlcOf(id), isNotNull);
  });

  test('both split children are stamped pending', () async {
    final id = await seedRecorded();
    final (firstId, secondId) = await repo.splitTrack(id, 1700007200000);

    // The parent tombstone always replicated; without a stamp on the
    // children, a peer would apply the deletion and receive nothing.
    expect(await hlcOf(firstId), isNotNull);
    expect(await hlcOf(secondId), isNotNull);
  });
}
