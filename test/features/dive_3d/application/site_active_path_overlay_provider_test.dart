import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import '../../../helpers/fake_hosts.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BathymetryGrid _smallGrid() => BathymetryGrid(
  originLat: 12.15,
  originLon: -68.30,
  cellSizeLatDeg: 0.001,
  cellSizeLonDeg: 0.001,
  rows: 2,
  cols: 2,
  depthsMeters: const [20, 30, 25, 35],
  sourceId: 'gmrt',
  resolutionMeters: 61,
  fetchedAt: DateTime.utc(2026, 7, 28),
);

const _siteId = 'site-1';
const _site = DiveSite(
  id: _siteId,
  name: 'Salt Pier',
  location: GeoPoint(12.151, -68.299),
  maxDepth: 30,
);

ReckonedPath _path({PathProvenance provenance = PathProvenance.measured}) =>
    ReckonedPath(
      points: const [
        ReckonedPoint(east: 0, north: 0, depth: 0, timeSeconds: 0),
        ReckonedPoint(east: 5, north: 0, depth: 8, timeSeconds: 60),
      ],
      provenance: provenance,
      minEast: 0,
      maxEast: 5,
      minNorth: 0,
      maxNorth: 0,
      maxDepth: 8,
      durationSeconds: 60,
    );

NavTrack _track({
  required String id,
  String? diveId,
  required int pointCount,
  List<NavTrackPoint> points = const [],
}) => NavTrack(
  id: id,
  diveId: diveId,
  source: NavTrackSource.seacraftEnc,
  startTime: 0,
  endTime: 60,
  pointCount: pointCount,
  points: points,
  createdAt: DateTime.utc(2026, 7, 28),
  updatedAt: DateTime.utc(2026, 7, 28),
);

void main() {
  setUp(() {
    serveFakeHost('tile.openstreetmap.org');
  });

  ProviderContainer container({
    ReckonedPath? divePath,
    NavTrack? linkedRoute,
    NavTrack? standaloneTrack,
  }) {
    final c = ProviderContainer(
      overrides: [
        siteProvider(_siteId).overrideWith((ref) async => _site),
        sitesProvider.overrideWith((ref) async => [_site]),
        divesProvider.overrideWith((ref) async => []),
        bathymetryGridProvider.overrideWith((ref, cell) async => _smallGrid()),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        spatialReckonedPathProvider.overrideWith(
          (ref, diveId) async => divePath,
        ),
        primaryNavTrackForDiveProvider.overrideWith(
          (ref, diveId) async => linkedRoute,
        ),
        diveProvider.overrideWith(
          (ref, diveId) async =>
              domain.Dive(id: 'dive-1', dateTime: DateTime.utc(2026, 7, 28)),
        ),
        navTrackByIdProvider.overrideWith(
          (ref, trackId) async => standaloneTrack,
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('dive source places the path and reports no linked route', () async {
    final c = container(divePath: _path());
    final result = await c.read(
      siteActivePathOverlayProvider((
        siteId: _siteId,
        pathId: 'dive-1',
        source: PathOverlaySource.dive,
      )).future,
    );

    expect(result, isNotNull);
    expect(result!.hasLinkedRoute, isFalse);
    expect(result.overlay.scrubPath.normalizedTimes, [0.0, 1.0]);
  });

  test('dive source reports a linked route when one exists', () async {
    final route = _track(
      id: 'route-1',
      diveId: 'dive-1',
      pointCount: 2,
      points: const [
        NavTrackPoint(timestamp: 0, north: 0, east: 0, depth: 2),
        NavTrackPoint(timestamp: 60, north: 5, east: 5, depth: 5),
      ],
    );
    final c = container(divePath: _path(), linkedRoute: route);
    final result = await c.read(
      siteActivePathOverlayProvider((
        siteId: _siteId,
        pathId: 'dive-1',
        source: PathOverlaySource.dive,
      )).future,
    );

    expect(result!.hasLinkedRoute, isTrue);
  });

  test('a dive with no usable path yields no overlay', () async {
    final c = container(divePath: null);
    final result = await c.read(
      siteActivePathOverlayProvider((
        siteId: _siteId,
        pathId: 'dive-1',
        source: PathOverlaySource.dive,
      )).future,
    );

    expect(result, isNull);
  });

  test('nav-track source never reports a linked route', () async {
    final track = _track(
      id: 'track-1',
      pointCount: 2,
      points: const [
        NavTrackPoint(timestamp: 0, north: 0, east: 0, depth: 2),
        NavTrackPoint(timestamp: 60, north: 5, east: 5, depth: 5),
      ],
    );
    final c = container(standaloneTrack: track);
    final result = await c.read(
      siteActivePathOverlayProvider((
        siteId: _siteId,
        pathId: 'track-1',
        source: PathOverlaySource.navTrack,
      )).future,
    );

    expect(result, isNotNull);
    expect(result!.hasLinkedRoute, isFalse);
  });
}
