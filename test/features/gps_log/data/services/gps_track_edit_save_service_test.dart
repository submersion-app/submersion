import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_edit_save_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/editing/gps_track_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A GPS track page's sitting is written as one History entry, and writes
/// only the name and the trim (issue #4527, phase 3).
void main() {
  late AppDatabase db;
  late GpsTrackRepository tracks;
  late GpsTrackEditSaveService service;
  late String id;
  final changeLog = ChangeLogRepository();

  final startMs = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;
  final nineMs = DateTime.utc(2026, 5, 22, 9).millisecondsSinceEpoch;
  final elevenMs = DateTime.utc(2026, 5, 22, 11).millisecondsSinceEpoch;

  Future<GpsTrack> stored() async => (await tracks.getTrack(id))!;

  Future<GpsTrackRow> row() =>
      (db.select(db.gpsTracks)..where((t) => t.id.equals(id))).getSingle();

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  Future<({GpsTrack before, GpsTrack after})?> save(
    EditSession<GpsTrack> session,
  ) => service.save(
    trackId: id,
    apply: session.applyTo,
    changedCardIds: session.changedCardIds,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    tracks = GpsTrackRepository();
    service = GpsTrackEditSaveService(tracks);
    id = await tracks.insertImportedTrack(
      points: [
        for (var h = 0; h <= 4; h++)
          GpsTrackPoint(
            timestamp: startMs ~/ 1000 + h * 3600,
            latitude: 20.0 + h * 0.01,
            longitude: -87.0,
          ),
      ],
      startTimeMs: startMs,
      endTimeMs: DateTime.utc(2026, 5, 22, 12).millisecondsSinceEpoch,
      tzOffsetMinutes: 0,
      source: 'gpx',
      name: 'Morning swim',
    );
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('writes a trim as one History entry', () async {
    final hlcBefore = (await row()).hlc;
    final session = EditSession(await stored())
      ..set(gpsTrackTrimField, (startMs: nineMs, endMs: elevenMs));

    final result = await save(session);

    final track = await stored();
    expect(track.trimStartTime, nineMs);
    expect(track.trimEndTime, elevenMs);
    expect(result!.before.trimStartTime, isNull);
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['source'], 'manual');
    expect(ops.single['label'], 'record_edit:gps_tracks:$id:trim');
    // updatedAt alone does not replicate: the export filters on hlc.
    expect((await row()).hlc, isNot(hlcBefore));
  });

  test('a rename and a trim are one entry', () async {
    final session = EditSession(await stored())
      ..set(gpsTrackNameField, 'Shore dive')
      ..set(gpsTrackTrimField, (startMs: nineMs, endMs: null));

    await save(session);

    final track = await stored();
    expect(track.name, 'Shore dive');
    expect(track.trimStartTime, nineMs);
    expect(track.trimEndTime, isNull);
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['label'], 'record_edit:gps_tracks:$id:header,trim');
  });

  test('a name changed underneath survives a trim', () async {
    final session = EditSession(await stored())
      ..set(gpsTrackTrimField, (startMs: nineMs, endMs: elevenMs));
    await db.customStatement(
      "UPDATE gps_tracks SET name = 'Renamed elsewhere' WHERE id = '$id'",
    );

    await save(session);

    expect((await stored()).name, 'Renamed elsewhere');
  });

  test('a trim changed underneath survives a rename', () async {
    final session = EditSession(await stored())
      ..set(gpsTrackNameField, 'Shore dive');
    await tracks.setTrimBounds(id, startMs: nineMs);

    await save(session);

    final track = await stored();
    expect(track.name, 'Shore dive');
    expect(track.trimStartTime, nineMs);
  });

  test('the points blob is untouched', () async {
    final before = (await row()).points;
    final session = EditSession(await stored())
      ..set(gpsTrackNameField, 'Shore dive')
      ..set(gpsTrackTrimField, (startMs: nineMs, endMs: elevenMs));

    await save(session);

    expect((await row()).points, before);
    expect((await stored()).points, hasLength(5));
  });

  test('unchanged returns null and writes nothing', () async {
    final updatedBefore = (await row()).updatedAt;
    final session = EditSession(await stored())
      ..set(gpsTrackNameField, 'Shore dive');
    // Another device made the same change meanwhile.
    await db.customStatement(
      "UPDATE gps_tracks SET name = 'Shore dive' WHERE id = '$id'",
    );
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');

    final result = await save(session);

    expect(result, isNull);
    expect(await operations(), isEmpty);
    expect((await row()).updatedAt, updatedBefore);
  });

  test('a deleted track throws StateError', () async {
    final session = EditSession(await stored())
      ..set(gpsTrackNameField, 'Shore dive');
    await tracks.deleteTrack(id);

    await expectLater(save(session), throwsStateError);
  });
}
