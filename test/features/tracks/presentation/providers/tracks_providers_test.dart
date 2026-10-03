import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_log_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/domain/tracks_query.dart';
import 'package:submersion/features/tracks/presentation/providers/tracks_providers.dart';

GpsTrack _gps(String id, DateTime start) => GpsTrack(
  id: id,
  startTime: start.millisecondsSinceEpoch,
  endTime: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
);

NavTrack _uw(String id, DateTime start, {String? diveId}) => NavTrack(
  id: id,
  diveId: diveId,
  source: NavTrackSource.seacraftEnc,
  startTime: start.millisecondsSinceEpoch,
  endTime: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
  durationSeconds: 600,
  pointCount: 5,
  anchorLatitude: 47.1,
  anchorLongitude: 8.3,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

ProviderContainer _container({
  required List<GpsTrack> gps,
  required List<NavTrack> underwater,
  List<Dive> dives = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      gpsTracksProvider.overrideWith((ref) async => gps),
      allNavTracksProvider.overrideWith((ref) async => underwater),
      divesProvider.overrideWith((ref) async => dives),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  final june = DateTime.utc(2026, 6, 15);
  final july = DateTime.utc(2026, 7, 20);

  test('the list follows the kind and date filters', () async {
    final container = _container(
      gps: [_gps('g', july)],
      underwater: [_uw('u', june)],
    );
    expect((await container.read(tracksListProvider.future)).length, 2);

    container.read(trackKindFilterProvider.notifier).state =
        TrackKindFilter.underwater;
    expect(
      [
        for (final i in await container.read(tracksListProvider.future))
          i.selectionKey,
      ],
      ['underwater:u'],
    );

    container.read(trackKindFilterProvider.notifier).state =
        TrackKindFilter.all;
    container.read(trackDateFilterProvider.notifier).state = DateTimeRange(
      start: DateTime.utc(2026, 7, 1),
      end: DateTime.utc(2026, 7, 31),
    );
    expect(
      [
        for (final i in await container.read(tracksListProvider.future))
          i.selectionKey,
      ],
      ['gps:g'],
    );

    // Clearing the date filter restores every track.
    container.read(trackDateFilterProvider.notifier).state = null;
    expect((await container.read(tracksListProvider.future)).length, 2);
  });

  test(
    'narrowing the filter below the cap clears the truncation notice',
    () async {
      final start = DateTime.utc(2026, 1, 1);
      final container = _container(
        gps: [
          for (var i = 0; i < kTracksOverviewLimit + 5; i++)
            _gps('g$i', start.add(Duration(days: -i))),
        ],
        underwater: const [],
      );
      expect(
        (await container.read(tracksOverviewProvider.future)).length,
        kTracksOverviewLimit,
      );
      expect(container.read(tracksOverviewTruncatedProvider), isTrue);

      container.read(trackDateFilterProvider.notifier).state = DateTimeRange(
        start: DateTime.utc(2025, 12, 29),
        end: DateTime.utc(2026, 1, 1),
      );
      expect((await container.read(tracksOverviewProvider.future)).length, 4);
      expect(container.read(tracksOverviewTruncatedProvider), isFalse);
    },
  );

  test('the summary follows the kind filter', () async {
    final container = _container(
      gps: [_gps('g', july)],
      underwater: [_uw('u', june, diveId: 'd1')],
      dives: [Dive(id: 'd1', diveNumber: 1, dateTime: june, maxDepth: 20)],
    );
    expect(
      (await container.read(tracksSummaryProvider.future)).divesCovered,
      1,
    );

    container.read(trackKindFilterProvider.notifier).state =
        TrackKindFilter.gps;
    final summary = await container.read(tracksSummaryProvider.future);
    expect(summary.trackCount, 1);
    expect(summary.divesCovered, 0);
  });

  test('a failing source surfaces its own error, not a wrapper', () async {
    final container = ProviderContainer(
      overrides: [
        gpsTracksProvider.overrideWith((ref) async => const <GpsTrack>[]),
        allNavTracksProvider.overrideWith(
          (ref) async => throw StateError('nav table locked'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await expectLater(
      container.read(tracksListProvider.future),
      throwsA(isA<StateError>()),
    );
  });
}
