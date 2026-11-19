import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/data/repositories/track_geometry_cache_repository.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_edit_save_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/presentation/pages/gps_track_detail_page.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Five fixes an hour apart, from 08:00 to 12:00 (wall-clock-as-UTC).
final int gpsStartMs = DateTime.utc(2026, 5, 22, 8).millisecondsSinceEpoch;

GpsTrackPoint gpsFix(int hour) => GpsTrackPoint(
  timestamp: gpsStartMs ~/ 1000 + hour * 3600,
  latitude: 20.0 + hour * 0.01,
  longitude: -87.0,
);

/// The track the page shows, as stored: named, untrimmed.
GpsTrack gpsTrack({String? name = 'Morning swim', int? trimStart}) {
  final points = [for (var h = 0; h <= 4; h++) gpsFix(h)];
  return GpsTrack(
    id: 'track-1',
    startTime: gpsStartMs,
    endTime: gpsStartMs + 4 * 3600 * 1000,
    pointCount: points.length,
    points: points,
    source: 'gpx',
    name: name,
    trimStartTime: trimStart,
  );
}

/// Records each save the page asks for and stores its result where the
/// page reads the track from.
class FakeGpsTrackSave extends GpsTrackEditSaveService {
  FakeGpsTrackSave(this.stored) : super(GpsTrackRepository());

  final StateController<GpsTrack?> stored;
  final calls = <({GpsTrack after, Set<String> cards})>[];

  @override
  Future<({GpsTrack before, GpsTrack after})?> save({
    required String trackId,
    required GpsTrack Function(GpsTrack stored) apply,
    required Iterable<String> changedCardIds,
  }) async {
    final before = stored.state!;
    final after = apply(before);
    calls.add((after: after, cards: changedCardIds.toSet()));
    stored.state = after;
    return (before: before, after: after);
  }
}

/// What a test pumped: the fake save, the stored track, and the tracks
/// whose cached geometry was dropped.
class GpsTrackPageHarness {
  GpsTrackPageHarness(
    this.save,
    this.stored,
    this.evicted,
    this.splits,
    this.deleted,
    this.container,
  );

  final FakeGpsTrackSave save;
  final StateController<GpsTrack?> stored;
  final List<String> evicted;

  /// Each split asked for: the track and where.
  final List<(String, int)> splits;

  /// Each track deleted.
  final List<String> deleted;

  final ProviderContainer container;
}

/// Pushes [page] over a plain first route, so the page can pop.
class _Launcher extends StatefulWidget {
  const _Launcher({required this.page});

  final Widget page;

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => widget.page));
    });
  }

  @override
  Widget build(BuildContext context) => const Text('first route');
}

final _storedProvider = StateProvider<GpsTrack?>((ref) => null);

/// Pumps the GPS track page with the phase 3 switch on (unless
/// [unlockEditing] is false), at phone width. The map draws the stored
/// track's trimmed fixes, as the geometry cache would once evicted.
Future<GpsTrackPageHarness> pumpGpsTrackPage(
  WidgetTester tester, {
  GpsTrack? track,
  bool unlockEditing = true,
  List<Dive> dives = const [],
}) async {
  tester.view.physicalSize = const Size(600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final overrides = await getBaseOverrides();
  final evicted = <String>[];
  final splits = <(String, int)>[];
  final deleted = <String>[];
  final initial = track ?? gpsTrack();
  await tester.pumpWidget(
    testApp(
      overrides: [
        ...overrides,
        _storedProvider.overrideWith((ref) => initial),
        gpsTrackDetailProvider(
          initial.id,
        ).overrideWith((ref) async => ref.watch(_storedProvider)),
        gpsTrackGeometryProvider((initial.id, TrackLod.detail)).overrideWith(
          (ref) async => ref.watch(_storedProvider)!.effectivePoints,
        ),
        divesOnTrackProvider(initial.id).overrideWith(
          (ref) async => divesCoveredBy(ref.watch(_storedProvider)!, dives),
        ),
        divesProvider.overrideWith((ref) async => dives),
        gpsTrackEditSaveServiceProvider.overrideWith(
          (ref) => FakeGpsTrackSave(ref.watch(_storedProvider.notifier)),
        ),
        evictGpsTrackProvider.overrideWithValue((id) async => evicted.add(id)),
        splitTrackProvider.overrideWith(
          (ref) => (String id, int at) async {
            splits.add((id, at));
            ref.read(_storedProvider.notifier).state = null;
            return ('${id}a', '${id}b');
          },
        ),
        deleteTrackProvider.overrideWith(
          (ref) => (String id) async {
            deleted.add(id);
            ref.read(_storedProvider.notifier).state = null;
          },
        ),
      ],
      child: _Launcher(
        page: GpsTrackDetailPage(
          trackId: initial.id,
          unlockEditing: unlockEditing,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(GpsTrackDetailPage)),
  );
  return GpsTrackPageHarness(
    container.read(gpsTrackEditSaveServiceProvider) as FakeGpsTrackSave,
    container.read(_storedProvider.notifier),
    evicted,
    splits,
    deleted,
    container,
  );
}
