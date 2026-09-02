import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';

/// A completed track, wall-clock-as-UTC milliseconds like the repository
/// hands back. List rows are hydrated without points, so none are given.
GpsTrack _track(
  String id, {
  required DateTime start,
  required DateTime end,
  DateTime? trimStart,
  DateTime? trimEnd,
}) => GpsTrack(
  id: id,
  startTime: start.millisecondsSinceEpoch,
  endTime: end.millisecondsSinceEpoch,
  pointCount: 2,
  trimStartTime: trimStart?.millisecondsSinceEpoch,
  trimEndTime: trimEnd?.millisecondsSinceEpoch,
);

Dive _dive(String id, DateTime entry) =>
    Dive(id: id, diveNumber: 1, dateTime: entry, maxDepth: 20.0);

ProviderContainer _container({
  required List<GpsTrack> tracks,
  required List<Dive> dives,
}) {
  final container = ProviderContainer(
    overrides: [
      gpsTracksProvider.overrideWith((ref) async => tracks),
      divesProvider.overrideWith((ref) async => dives),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  final day = DateTime.utc(2026, 5, 22);

  test('an empty library reports zero everything', () async {
    final container = _container(tracks: const [], dives: const []);

    final summary = await container.read(gpsLogSummaryProvider.future);

    expect(summary.trackCount, 0);
    expect(summary.recordedTime, Duration.zero);
    expect(summary.divesCovered, 0);
  });

  test('recorded time sums each track as trimmed', () async {
    final container = _container(
      tracks: [
        // Four hours recorded, trimmed to the two in the middle.
        _track(
          'trimmed',
          start: day.add(const Duration(hours: 8)),
          end: day.add(const Duration(hours: 12)),
          trimStart: day.add(const Duration(hours: 9)),
          trimEnd: day.add(const Duration(hours: 11)),
        ),
        _track(
          'whole',
          start: day.add(const Duration(hours: 14)),
          end: day.add(const Duration(hours: 15, minutes: 30)),
        ),
      ],
      dives: const [],
    );

    final summary = await container.read(gpsLogSummaryProvider.future);

    expect(summary.trackCount, 2);
    expect(summary.recordedTime, const Duration(hours: 3, minutes: 30));
  });

  test(
    'dives covered applies the matcher tolerance around the trimmed window',
    () async {
      final container = _container(
        tracks: [
          _track(
            't',
            start: day.add(const Duration(hours: 6)),
            end: day.add(const Duration(hours: 12)),
            // The drive to the marina is trimmed off: 06:00-08:00 no longer
            // counts, so a 07:00 dive must not be covered.
            trimStart: day.add(const Duration(hours: 8)),
          ),
        ],
        dives: [
          _dive('inTrimmedLeg', day.add(const Duration(hours: 7))),
          // 29 minutes before the trimmed start: inside the 30-min tolerance.
          _dive('edge', day.add(const Duration(hours: 7, minutes: 31))),
          _dive('inside', day.add(const Duration(hours: 10))),
          // 31 minutes after the end: outside the tolerance.
          _dive('late', day.add(const Duration(hours: 12, minutes: 31))),
        ],
      );

      final summary = await container.read(gpsLogSummaryProvider.future);

      expect(summary.divesCovered, 2);
    },
  );

  test('a dive covered by two overlapping tracks is counted once', () async {
    final container = _container(
      tracks: [
        _track(
          'phone',
          start: day.add(const Duration(hours: 8)),
          end: day.add(const Duration(hours: 12)),
        ),
        _track(
          'watch',
          start: day.add(const Duration(hours: 9)),
          end: day.add(const Duration(hours: 11)),
        ),
      ],
      dives: [_dive('d', day.add(const Duration(hours: 10)))],
    );

    final summary = await container.read(gpsLogSummaryProvider.future);

    expect(summary.divesCovered, 1);
  });
}
