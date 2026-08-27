import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_point_codec.dart';

enum GpsRecorderStatus { idle, recording }

class GpsRecorderState {
  final GpsRecorderStatus status;
  final String? trackId;
  final int pointCount;

  /// Real UTC, for elapsed-time display.
  final DateTime? startedAt;

  /// Real UTC time of the last accepted fix.
  final DateTime? lastFixAt;
  final double? lastFixAccuracy;

  const GpsRecorderState({
    this.status = GpsRecorderStatus.idle,
    this.trackId,
    this.pointCount = 0,
    this.startedAt,
    this.lastFixAt,
    this.lastFixAccuracy,
  });
}

/// Records a GPS surface track via a continuous geolocator stream.
///
/// Foreground-started; both platforms keep the stream alive in the
/// background under While-In-Use permission (iOS blue indicator via the
/// location background mode, Android foreground-service notification
/// supplied through [AndroidSettings.foregroundNotificationConfig]).
class GpsTrackRecorder {
  static const double maxAccuracyMeters = 100;
  static const int distanceFilterMeters = 20;

  final GpsTrackRepository _repository;
  final Stream<Position> Function(LocationSettings) _positionStreamFactory;
  final Duration _keepaliveInterval;
  final Duration _checkpointInterval;
  final Future<void> Function(String trackId)? _onTrackFinalized;

  final _log = LoggerService.forClass(GpsTrackRecorder);
  final _stateController = StreamController<GpsRecorderState>.broadcast();
  GpsRecorderState _state = const GpsRecorderState();
  StreamSubscription<Position>? _subscription;
  Timer? _keepaliveTimer;
  Timer? _checkpointTimer;
  Position? _lastPosition;

  /// When the last REAL fix arrived from the position stream. The keepalive
  /// guard must check this, not [GpsRecorderState.lastFixAt]: fabricated
  /// keepalive points refresh lastFixAt, which would keep the guard from
  /// ever tripping after provider loss.
  DateTime? _lastRealFixAt;

  /// Serializes point writes so [stop] can await the tail of the queue
  /// before finalizing (a write racing finalize could land buffer rows
  /// after the finalize clears them).
  Future<void> _lastRecord = Future<void>.value();

  GpsTrackRecorder({
    required GpsTrackRepository repository,
    Stream<Position> Function(LocationSettings)? positionStreamFactory,
    Duration keepaliveInterval = const Duration(minutes: 5),
    Duration checkpointInterval = const Duration(minutes: 10),
    Future<void> Function(String trackId)? onTrackFinalized,
  }) : _repository = repository,
       _positionStreamFactory =
           positionStreamFactory ??
           ((settings) =>
               Geolocator.getPositionStream(locationSettings: settings)),
       _keepaliveInterval = keepaliveInterval,
       _checkpointInterval = checkpointInterval,
       _onTrackFinalized = onTrackFinalized;

  GpsRecorderState get state => _state;
  Stream<GpsRecorderState> get states => _stateController.stream;
  bool get isRecording => _state.status == GpsRecorderStatus.recording;

  Future<void> start({
    required String notificationTitle,
    required String notificationText,
  }) async {
    if (isRecording) return;
    final now = DateTime.now();
    final trackId = await _repository.startTrack(
      startTimeMs: toWallClockEpochSeconds(now.toUtc()) * 1000,
      tzOffsetMinutes: now.timeZoneOffset.inMinutes,
    );
    _setState(
      GpsRecorderState(
        status: GpsRecorderStatus.recording,
        trackId: trackId,
        startedAt: now.toUtc(),
      ),
    );
    _subscription =
        _positionStreamFactory(
          buildSettings(notificationTitle, notificationText),
        ).listen(
          _onPosition,
          onError: (Object e, StackTrace stackTrace) {
            // Keep the session alive (fixes may resume), but leave a trail: a
            // silent stream failure looks like a recorder that just stopped
            // getting fixes. The UI surfaces the growing last-fix age.
            _log.error(
              'Position stream error',
              error: e,
              stackTrace: stackTrace,
            );
          },
        );
    _keepaliveTimer = Timer.periodic(_keepaliveInterval, (_) {
      final last = _lastPosition;
      final lastRealAt = _lastRealFixAt;
      if (last == null || lastRealAt == null) return;
      // Provider-loss guard: if no real fix has arrived in two keepalive
      // intervals, stop fabricating coverage from the stale position. The
      // UI surfaces the growing fix age; matching treats the hole via the
      // interior-gap rule in GpsTrackMatcher.
      if (DateTime.now().toUtc().difference(lastRealAt) >
          _keepaliveInterval * 2) {
        return;
      }
      // Re-record the last known position with a fresh timestamp so a
      // moored boat still produces continuous track coverage.
      _enqueueRecord(last, timestampOverride: DateTime.now().toUtc());
    });
    _checkpointTimer = Timer.periodic(_checkpointInterval, (_) {
      final id = _state.trackId;
      if (id != null) unawaited(_repository.checkpoint(id));
    });
  }

  Future<void> stop() async {
    final trackId = _state.trackId;
    await _subscription?.cancel();
    _keepaliveTimer?.cancel();
    _checkpointTimer?.cancel();
    _subscription = null;
    _keepaliveTimer = null;
    _checkpointTimer = null;
    _lastPosition = null;
    _lastRealFixAt = null;
    // Let any in-flight point write land before finalizing so the last fix
    // makes it into the blob and cannot repopulate the buffer afterwards.
    await _lastRecord;
    if (trackId != null) {
      // Stamp the session end from the actual stop time, not the last fix.
      // A mostly-stationary device stops emitting fixes once the distance
      // filter is unmet, so the last point can lag the true stop by many
      // minutes; deriving endTime from it collapses the displayed duration.
      // (Orphan recovery keeps the last-point default: the true stop time is
      // unknown there.)
      final endTimeMs = toWallClockEpochSeconds(DateTime.now().toUtc()) * 1000;
      await _repository.finalizeTrack(trackId, endTimeMs: endTimeMs);
      try {
        await _onTrackFinalized?.call(trackId);
      } catch (e, stackTrace) {
        // Matching is best-effort; a sweep failure must not prevent the
        // recorder from returning to idle.
        _log.error(
          'Post-stop GPS match sweep failed',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    _setState(const GpsRecorderState());
  }

  void _onPosition(Position position) {
    if (position.accuracy > maxAccuracyMeters) return;
    _lastPosition = position;
    _lastRealFixAt = DateTime.now().toUtc();
    _enqueueRecord(position);
  }

  /// Chains a point write onto the queue. Errors are logged, never thrown:
  /// a failed write must not surface as an unhandled async error from the
  /// stream or the keepalive timer, and must not break the chain.
  void _enqueueRecord(Position position, {DateTime? timestampOverride}) {
    _lastRecord = _lastRecord
        .then((_) => _record(position, timestampOverride: timestampOverride))
        .catchError((Object e, StackTrace stackTrace) {
          _log.error(
            'Failed to record GPS point',
            error: e,
            stackTrace: stackTrace,
          );
        });
  }

  Future<void> _record(Position position, {DateTime? timestampOverride}) async {
    final trackId = _state.trackId;
    if (trackId == null) return;
    final timestamp = timestampOverride ?? position.timestamp;
    await _repository.appendBufferPoint(
      trackId,
      GpsTrackPoint(
        timestamp: toWallClockEpochSeconds(timestamp),
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
      ),
    );
    // The session may have stopped while the append was in flight.
    if (_state.trackId != trackId) return;
    _setState(
      GpsRecorderState(
        status: GpsRecorderStatus.recording,
        trackId: trackId,
        pointCount: _state.pointCount + 1,
        startedAt: _state.startedAt,
        lastFixAt: timestamp,
        lastFixAccuracy: position.accuracy,
      ),
    );
  }

  /// Per-platform stream settings. Uses [defaultTargetPlatform] (not
  /// dart:io) so tests can exercise every branch via
  /// [debugDefaultTargetPlatformOverride].
  @visibleForTesting
  LocationSettings buildSettings(String title, String text) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterMeters,
          foregroundNotificationConfig: ForegroundNotificationConfig(
            notificationTitle: title,
            notificationText: text,
            enableWakeLock: true,
          ),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterMeters,
          allowBackgroundLocationUpdates: true,
          showBackgroundLocationIndicator: true,
          pauseLocationUpdatesAutomatically: false,
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: distanceFilterMeters,
        );
    }
  }

  void _setState(GpsRecorderState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }
}
