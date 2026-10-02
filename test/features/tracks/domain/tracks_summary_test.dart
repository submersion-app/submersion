import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';
import 'package:submersion/features/tracks/domain/tracks_summary.dart';

final _day = DateTime.utc(2026, 5, 22);

GpsTrack _gps(String id, int fromHour, int toHour, {int? trimFromHour}) =>
    GpsTrack(
      id: id,
      startTime: _day.add(Duration(hours: fromHour)).millisecondsSinceEpoch,
      endTime: _day.add(Duration(hours: toHour)).millisecondsSinceEpoch,
      trimStartTime: trimFromHour == null
          ? null
          : _day.add(Duration(hours: trimFromHour)).millisecondsSinceEpoch,
    );

NavTrack _uw(String id, {String? diveId, int? durationSeconds}) => NavTrack(
  id: id,
  diveId: diveId,
  source: NavTrackSource.seacraftEnc,
  startTime: _day.add(const Duration(hours: 20)).millisecondsSinceEpoch,
  endTime: _day.add(const Duration(hours: 21)).millisecondsSinceEpoch,
  durationSeconds: durationSeconds,
  pointCount: 5,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Dive _dive(String id, int hour) => Dive(
  id: id,
  diveNumber: 1,
  dateTime: _day.add(Duration(hours: hour)),
  maxDepth: 20,
);

void main() {
  test('an empty list reports zero everything', () {
    final summary = summarizeTracks(const [], const []);
    expect(summary.trackCount, 0);
    expect(summary.recordedTime, Duration.zero);
    expect(summary.divesCovered, 0);
  });

  test('recorded time adds trimmed GPS time and underwater duration', () {
    final summary = summarizeTracks([
      // Four hours recorded, trimmed to the last two.
      GpsTrackItem(_gps('g', 8, 12, trimFromHour: 10)),
      UnderwaterTrackItem(_uw('u', durationSeconds: 600)),
      // No stored duration: the one-hour raw span counts.
      UnderwaterTrackItem(_uw('v')),
    ], const []);
    expect(summary.trackCount, 3);
    expect(summary.recordedTime, const Duration(hours: 3, minutes: 10));
  });

  test('a dive covered by a GPS window and linked to an underwater track '
      'counts once', () {
    final summary = summarizeTracks(
      [
        GpsTrackItem(_gps('g', 8, 12)),
        UnderwaterTrackItem(_uw('u', diveId: 'd1')),
      ],
      [_dive('d1', 10), _dive('d2', 11)],
    );
    expect(summary.divesCovered, 2);
  });

  test('a link to a dive outside the dive list is not counted', () {
    final summary = summarizeTracks(
      [UnderwaterTrackItem(_uw('u', diveId: 'someone-elses-dive'))],
      [_dive('d1', 3)],
    );
    expect(summary.divesCovered, 0);
  });
}
