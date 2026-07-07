import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_recorder.dart';

import '../../helpers/test_database.dart';

Position fix({
  required double lat,
  required double lon,
  double accuracy = 5,
  DateTime? time,
}) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: time ?? DateTime.now().toUtc(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late AppDatabase db;
  late GpsTrackRepository repo;
  late StreamController<Position> controller;
  late GpsTrackRecorder recorder;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = GpsTrackRepository();
    controller = StreamController<Position>();
    recorder = GpsTrackRecorder(
      repository: repo,
      positionStreamFactory: (_) => controller.stream,
    );
  });

  tearDown(() async {
    await recorder.stop();
    await controller.close();
    await tearDownTestDatabase();
  });

  test('start creates an active track and buffers incoming fixes', () async {
    await recorder.start(notificationTitle: 't', notificationText: 'x');
    expect(recorder.isRecording, isTrue);
    controller.add(fix(lat: 10, lon: 20));
    controller.add(fix(lat: 10.001, lon: 20.001));
    await pumpEventQueue();
    expect(recorder.state.pointCount, 2);
    final buffered = await repo.getBufferPoints(recorder.state.trackId!);
    expect(buffered, hasLength(2));
  });

  test('drops fixes with accuracy worse than 100 m', () async {
    await recorder.start(notificationTitle: 't', notificationText: 'x');
    controller.add(fix(lat: 10, lon: 20, accuracy: 250));
    await pumpEventQueue();
    expect(recorder.state.pointCount, 0);
    expect(await repo.getBufferPoints(recorder.state.trackId!), isEmpty);
  });

  test('stop finalizes the track and resets to idle', () async {
    await recorder.start(notificationTitle: 't', notificationText: 'x');
    controller.add(fix(lat: 10, lon: 20));
    await pumpEventQueue();
    final trackId = recorder.state.trackId!;
    await recorder.stop();
    expect(recorder.isRecording, isFalse);
    expect(recorder.state.trackId, isNull);
    final track = await repo.getTrack(trackId);
    expect(track!.endTime, isNotNull);
    expect(track.pointCount, 1);
    expect(await repo.getBufferPoints(trackId), isEmpty);
  });

  test('stop invokes onTrackFinalized with the track id', () async {
    String? finalized;
    final r = GpsTrackRecorder(
      repository: repo,
      positionStreamFactory: (_) => controller.stream,
      onTrackFinalized: (id) async => finalized = id,
    );
    await r.start(notificationTitle: 't', notificationText: 'x');
    controller.add(fix(lat: 10, lon: 20));
    await pumpEventQueue();
    final trackId = r.state.trackId;
    await r.stop();
    expect(finalized, trackId);
  });

  test('stop on an empty session discards the track', () async {
    await recorder.start(notificationTitle: 't', notificationText: 'x');
    final trackId = recorder.state.trackId!;
    await recorder.stop();
    expect(await repo.getTrack(trackId), isNull);
  });

  test('start while recording is a no-op', () async {
    await recorder.start(notificationTitle: 't', notificationText: 'x');
    final id = recorder.state.trackId;
    await recorder.start(notificationTitle: 't', notificationText: 'x');
    expect(recorder.state.trackId, id);
  });

  test('position stream errors are absorbed and recording continues', () async {
    await recorder.start(notificationTitle: 't', notificationText: 'x');
    controller.addError(StateError('provider lost'));
    controller.add(fix(lat: 10, lon: 20));
    await pumpEventQueue();
    expect(recorder.isRecording, isTrue);
    expect(recorder.state.pointCount, 1);
  });

  test('keepalive re-records the last position while fixes are fresh, '
      'then stops after provider loss', () async {
    final r = GpsTrackRecorder(
      repository: repo,
      positionStreamFactory: (_) => controller.stream,
      keepaliveInterval: const Duration(milliseconds: 40),
      checkpointInterval: const Duration(milliseconds: 60),
    );
    await r.start(notificationTitle: 't', notificationText: 'x');
    controller.add(fix(lat: 10, lon: 20));
    await pumpEventQueue();
    expect(r.state.pointCount, 1);

    // Within 2x keepalive of the real fix: the first tick fabricates a
    // point from the last known position (and the checkpoint timer runs).
    await Future<void>.delayed(const Duration(milliseconds: 55));
    final fabricated = r.state.pointCount;
    expect(fabricated, greaterThanOrEqualTo(2));

    // Long after the last REAL fix: the provider-loss guard stops
    // fabricating (fabricated points must not refresh the guard).
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final afterLoss = r.state.pointCount;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(r.state.pointCount, afterLoss);
    await r.stop();
  });

  test('a failed point write is logged, not thrown', () async {
    // Local recorder: it is deliberately left un-stopped so the shared
    // tearDown does not try to finalize against the closed database.
    final r = GpsTrackRecorder(
      repository: repo,
      positionStreamFactory: (_) => controller.stream,
    );
    await r.start(notificationTitle: 't', notificationText: 'x');
    await db.close();
    controller.add(fix(lat: 10, lon: 20));
    await pumpEventQueue();
    // The write failed silently; state still shows no accepted point.
    expect(r.state.pointCount, 0);
  });

  test('state stream emits recording transitions', () async {
    final states = <GpsRecorderStatus>[];
    final sub = recorder.states.listen((s) => states.add(s.status));
    await recorder.start(notificationTitle: 't', notificationText: 'x');
    controller.add(fix(lat: 10, lon: 20));
    await pumpEventQueue();
    await recorder.stop();
    // Broadcast-stream delivery is a microtask; let the idle event land.
    await pumpEventQueue();
    await sub.cancel();
    expect(states.first, GpsRecorderStatus.recording);
    expect(states.last, GpsRecorderStatus.idle);
  });
}
