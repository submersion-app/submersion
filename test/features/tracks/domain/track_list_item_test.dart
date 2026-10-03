import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/domain/track_list_item.dart';

NavTrack _route({
  String id = 'r1',
  int start = 1755856800000,
  int end = 1755860400000,
  int? durationSeconds,
  double? lat,
  double? lon,
}) => NavTrack(
  id: id,
  source: NavTrackSource.seacraftEnc,
  startTime: start,
  endTime: end,
  durationSeconds: durationSeconds,
  pointCount: 5,
  anchorLatitude: lat,
  anchorLongitude: lon,
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

void main() {
  group('TrackKindFilter', () {
    test('reads the kind query value', () {
      expect(TrackKindFilter.fromQuery('gps'), TrackKindFilter.gps);
      expect(
        TrackKindFilter.fromQuery('underwater'),
        TrackKindFilter.underwater,
      );
      expect(TrackKindFilter.fromQuery('all'), TrackKindFilter.all);
    });

    test('an absent or unknown value leaves the filter alone', () {
      expect(TrackKindFilter.fromQuery(null), isNull);
      expect(TrackKindFilter.fromQuery('bogus'), isNull);
    });

    test('admits only its own kind, or both for all', () {
      expect(TrackKindFilter.all.admits(TrackKind.gps), isTrue);
      expect(TrackKindFilter.all.admits(TrackKind.underwater), isTrue);
      expect(TrackKindFilter.gps.admits(TrackKind.underwater), isFalse);
      expect(TrackKindFilter.underwater.admits(TrackKind.gps), isFalse);
    });
  });

  group('GpsTrackItem', () {
    test('reads the trimmed window, always maps, and keys by kind', () {
      const track = GpsTrack(
        id: 't1',
        startTime: 1000,
        endTime: 9000,
        trimStartTime: 2000,
        trimEndTime: 5000,
      );
      const item = GpsTrackItem(track);
      expect(item.kind, TrackKind.gps);
      expect(item.startTime, 2000);
      expect(item.endTime, 5000);
      expect(item.isMappable, isTrue);
      expect(item.recordedTime, const Duration(seconds: 3));
      expect(item.selectionKey, 'gps:t1');
    });

    test('a track still recording has no recorded time', () {
      const item = GpsTrackItem(GpsTrack(id: 't1', startTime: 1000));
      expect(item.recordedTime, isNull);
    });
  });

  group('UnderwaterTrackItem', () {
    test('reads the recording window as stored', () {
      final item = UnderwaterTrackItem(_route(start: 1000, end: 9000));
      expect(item.id, 'r1');
      expect(item.startTime, 1000);
      expect(item.endTime, 9000);
    });

    test('maps only when anchored', () {
      expect(UnderwaterTrackItem(_route()).isMappable, isFalse);
      expect(
        UnderwaterTrackItem(_route(lat: 47.1, lon: 8.3)).isMappable,
        isTrue,
      );
    });

    test('recorded time prefers the stored duration', () {
      final item = UnderwaterTrackItem(_route(durationSeconds: 600));
      expect(item.recordedTime, const Duration(minutes: 10));
    });

    test('recorded time falls back to the raw span, never negative', () {
      expect(
        UnderwaterTrackItem(_route(start: 0, end: 90000)).recordedTime,
        const Duration(seconds: 90),
      );
      expect(
        UnderwaterTrackItem(_route(start: 5000, end: 1000)).recordedTime,
        Duration.zero,
      );
    });

    test('keys by kind so ids from two tables cannot collide', () {
      final item = UnderwaterTrackItem(_route(id: 'x'));
      expect(item.kind, TrackKind.underwater);
      expect(item.selectionKey, 'underwater:x');
      expect(
        item.selectionKey,
        isNot(const GpsTrackItem(GpsTrack(id: 'x', startTime: 0)).selectionKey),
      );
    });
  });
}
