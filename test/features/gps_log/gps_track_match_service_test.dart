import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late GpsTrackRepository trackRepo;
  late GpsTrackMatchService service;

  setUp(() async {
    db = await setUpTestDatabase();
    trackRepo = GpsTrackRepository();
    service = GpsTrackMatchService(
      trackRepository: trackRepo,
      diveRepository: DiveRepository(),
    );
  });

  tearDown(tearDownTestDatabase);

  /// Track from wall-clock seconds 1000 to 2000, moving lat 10 -> 11 and
  /// lon 20 -> 21 (finalized).
  Future<String> seedTrack() async {
    final id = await trackRepo.startTrack(
      startTimeMs: 1000000,
      tzOffsetMinutes: 0,
    );
    await trackRepo.appendBufferPoint(
      id,
      const GpsTrackPoint(timestamp: 1000, latitude: 10, longitude: 20),
    );
    await trackRepo.appendBufferPoint(
      id,
      const GpsTrackPoint(timestamp: 2000, latitude: 11, longitude: 21),
    );
    await trackRepo.finalizeTrack(id, endTimeMs: 2000000);
    return id;
  }

  Future<void> seedDive(
    String id,
    int diveDateTimeMs, {
    int? exitTimeMs,
    double? entryLatitude,
    double? entryLongitude,
    double? exitLatitude,
    double? exitLongitude,
  }) async {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: diveDateTimeMs,
            exitTime: Value(exitTimeMs),
            entryLatitude: Value(entryLatitude),
            entryLongitude: Value(entryLongitude),
            exitLatitude: Value(exitLatitude),
            exitLongitude: Value(exitLongitude),
            createdAt: diveDateTimeMs,
            updatedAt: diveDateTimeMs,
          ),
        );
  }

  Future<Dive> readDive(String id) async =>
      (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();

  test('sweep stamps entry and exit GPS on a dive inside a track', () async {
    await seedTrack();
    // Dive starts at second 1500 (midpoint), ends at 1800.
    await seedDive('dive-1', 1500000, exitTimeMs: 1800000);

    final stamped = await service.sweep();
    expect(stamped, ['dive-1']);

    final dive = await readDive('dive-1');
    expect(dive.entryLatitude, closeTo(10.5, 1e-9));
    expect(dive.entryLongitude, closeTo(20.5, 1e-9));
    expect(dive.exitLatitude, closeTo(10.8, 1e-9));
    expect(dive.exitLongitude, closeTo(20.8, 1e-9));
  });

  test('sweep skips dives that already have GPS', () async {
    await seedTrack();
    await seedDive(
      'dive-has-gps',
      1500000,
      entryLatitude: 50.0,
      entryLongitude: 60.0,
    );

    final stamped = await service.sweep();
    expect(stamped, isEmpty);

    final dive = await readDive('dive-has-gps');
    expect(dive.entryLatitude, 50.0);
    expect(dive.entryLongitude, 60.0);
  });

  test('sweep skips dives outside all track windows', () async {
    await seedTrack();
    // Hours after the track ends (beyond the 30-min tolerance).
    await seedDive('dive-far', 20000000);

    expect(await service.sweep(), isEmpty);
    final dive = await readDive('dive-far');
    expect(dive.entryLatitude, isNull);
  });

  test('sweep never overwrites an existing exit fix', () async {
    await seedTrack();
    // Missing entry GPS (so it is a candidate) but carrying a
    // computer-provided exit fix that must survive the stamp.
    await seedDive(
      'dive-exit-fix',
      1500000,
      exitTimeMs: 1800000,
      exitLatitude: 50.0,
      exitLongitude: 60.0,
    );

    final stamped = await service.sweep();
    expect(stamped, ['dive-exit-fix']);

    final dive = await readDive('dive-exit-fix');
    expect(dive.entryLatitude, closeTo(10.5, 1e-9));
    expect(dive.entryLongitude, closeTo(20.5, 1e-9));
    expect(dive.exitLatitude, 50.0);
    expect(dive.exitLongitude, 60.0);
  });

  test('sweep respects limitToIds', () async {
    await seedTrack();
    await seedDive('dive-a', 1200000);
    await seedDive('dive-b', 1600000);

    final stamped = await service.sweep(limitToIds: ['dive-a']);
    expect(stamped, ['dive-a']);

    expect((await readDive('dive-a')).entryLatitude, isNotNull);
    expect((await readDive('dive-b')).entryLatitude, isNull);
  });
}
