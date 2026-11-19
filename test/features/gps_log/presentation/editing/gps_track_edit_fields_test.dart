import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/editing/gps_track_edit_fields.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The GPS track's values a sitting edits (issue #4527, phase 3).
void main() {
  const track = GpsTrack(
    id: 't1',
    startTime: 1000,
    endTime: 9000,
    name: 'Morning swim',
    trimStartTime: 2000,
    trimEndTime: 8000,
    deviceName: 'Phone',
    sourceRef: 'swim.gpx',
    source: 'gpx',
    pointCount: 3,
  );

  test('a blank name stores null', () {
    final session = EditSession(track)..set(gpsTrackNameField, '   ');

    expect(session.applyTo(track).name, isNull);
    expect(session.changedCardIds, {'header'});
  });

  test('a name is stored trimmed', () {
    final session = EditSession(track)..set(gpsTrackNameField, '  Reef  ');

    expect(session.applyTo(track).name, 'Reef');
  });

  test('Reset trim sets both bounds to null in one change', () {
    final session = EditSession(track)
      ..set(gpsTrackTrimField, (startMs: null, endMs: null));

    final applied = session.applyTo(track);
    expect(applied.trimStartTime, isNull);
    expect(applied.trimEndTime, isNull);
    expect(session.changedCardIds, {'trim'});
  });

  test('every other value is kept', () {
    final session = EditSession(track)
      ..set(gpsTrackNameField, null)
      ..set(gpsTrackTrimField, (startMs: null, endMs: null));

    final applied = session.applyTo(track);
    expect(applied.id, 't1');
    expect(applied.startTime, 1000);
    expect(applied.endTime, 9000);
    expect(applied.deviceName, 'Phone');
    expect(applied.sourceRef, 'swim.gpx');
    expect(applied.source, 'gpx');
    expect(applied.pointCount, 3);
  });

  test('setting the stored values back is no change', () {
    final session = EditSession(track)
      ..set(gpsTrackNameField, 'Other')
      ..set(gpsTrackNameField, 'Morning swim')
      ..set(gpsTrackTrimField, (startMs: 2000, endMs: 8000));

    expect(session.changedCardIds, isEmpty);
  });
}
