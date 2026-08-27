import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

import '../../helpers/test_database.dart';

void main() {
  late GpsTrackRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = GpsTrackRepository();
  });

  tearDown(tearDownTestDatabase);

  /// Track from 08:00 to 12:00 with a fix on each hour (5 fixes).
  Future<String> seed() async {
    final startMs = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
    final id = await repo.startTrack(startTimeMs: startMs, tzOffsetMinutes: 0);
    for (var h = 0; h <= 4; h++) {
      await repo.appendBufferPoint(
        id,
        GpsTrackPoint(
          timestamp: startMs ~/ 1000 + h * 3600,
          latitude: 20.0 + h * 0.01,
          longitude: -87.0,
        ),
      );
    }
    await repo.finalizeTrack(
      id,
      endTimeMs: DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch,
    );
    return id;
  }

  Future<int> updatedAt(String id) async {
    final db = DatabaseService.instance.database;
    final row = await (db.select(
      db.gpsTracks,
    )..where((t) => t.id.equals(id))).getSingle();
    return row.updatedAt;
  }

  test('setTrimBounds narrows effectivePoints', () async {
    final id = await seed();
    await repo.setTrimBounds(
      id,
      startMs: DateTime.utc(2026, 5, 22, 9).millisecondsSinceEpoch,
      endMs: DateTime.utc(2026, 5, 22, 11).millisecondsSinceEpoch,
    );
    final track = await repo.getTrack(id);
    expect(track!.effectivePoints.length, 3);
  });

  test('trimming never rewrites the points blob', () async {
    final id = await seed();
    final before = (await repo.getTrack(id))!.points.length;

    await repo.setTrimBounds(
      id,
      startMs: DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );

    final after = await repo.getTrack(id);
    // The stored points are untouched; only the view of them narrows. This
    // is what makes trimming reversible and incapable of losing a fix.
    expect(after!.points.length, before);
    expect(after.effectivePoints.length, lessThan(before));
  });

  test('clearTrim restores every fix', () async {
    final id = await seed();
    await repo.setTrimBounds(
      id,
      startMs: DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );
    await repo.clearTrim(id);

    final track = await repo.getTrack(id);
    expect(track!.effectivePoints.length, 5);
    expect(track.trimStartTime, isNull);
    expect(track.trimEndTime, isNull);
  });

  test('a start-only trim leaves the end open', () async {
    final id = await seed();
    await repo.setTrimBounds(
      id,
      startMs: DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );
    final track = await repo.getTrack(id);
    expect(track!.trimEndTime, isNull);
    expect(track.effectivePoints.length, 3);
  });

  test('trimming bumps updatedAt so the change syncs', () async {
    final id = await seed();
    final before = await updatedAt(id);
    await Future<void>.delayed(const Duration(milliseconds: 5));

    await repo.setTrimBounds(
      id,
      startMs: DateTime.utc(2026, 5, 22, 10).millisecondsSinceEpoch,
    );

    expect(await updatedAt(id), greaterThan(before));
  });

  test(
    'a trim excluding everything yields no points but keeps the blob',
    () async {
      final id = await seed();
      await repo.setTrimBounds(
        id,
        startMs: DateTime.utc(2026, 5, 23).millisecondsSinceEpoch,
      );
      final track = await repo.getTrack(id);
      expect(track!.effectivePoints, isEmpty);
      expect(track.points, isNotEmpty);
    },
  );
}
