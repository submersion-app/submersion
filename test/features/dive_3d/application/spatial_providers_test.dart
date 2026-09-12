import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

import '../../../helpers/mock_providers.dart';

NavTrack _route({
  required List<NavTrackPoint> points,
  double? anchorLatitude,
  double? anchorLongitude,
}) {
  final now = DateTime(2026, 9, 10);
  return NavTrack(
    id: 'route-1',
    diveId: 'd1',
    source: NavTrackSource.seacraftEnc,
    startTime: points.isEmpty ? 0 : points.first.timestamp * 1000,
    endTime: points.isEmpty ? 0 : points.last.timestamp * 1000,
    pointCount: points.length,
    points: points,
    anchorLatitude: anchorLatitude,
    anchorLongitude: anchorLongitude,
    createdAt: now,
    updatedAt: now,
  );
}

Dive diveWithHeadings({bool withGps = true}) => Dive(
  id: 'd1',
  dateTime: DateTime.utc(2026, 1, 1),
  entryLocation: withGps ? const GeoPoint(10.0, 20.0) : null,
  exitLocation: withGps ? const GeoPoint(10.001, 20.001) : null,
  site: const DiveSite(id: 's1', name: 'Reef', maxDepth: 30),
);

SourceProfile headingProfile() {
  final points = <DiveProfilePoint>[];
  for (var i = 0; i <= 30; i++) {
    points.add(
      DiveProfilePoint(
        timestamp: i * 20,
        depth: i < 15 ? i * 2.0 : (30 - i) * 2.0,
        heading: (i * 6).toDouble() % 360,
      ),
    );
  }
  return SourceProfile(
    sourceId: 'src',
    computerId: null,
    isEdited: false,
    points: points,
  );
}

Future<ProviderContainer> makeContainer({
  required Dive? dive,
  SourceProfile? profile,
  NavTrack? route,
}) async {
  final base = await getBaseOverrides(primaryNavTrack: route);
  final container = ProviderContainer(
    overrides: [
      ...base,
      diveProvider('d1').overrideWith((ref) async => dive),
      sourceProfilesProvider('d1').overrideWith(
        (ref) async => profile == null ? const {} : {'src': profile},
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'reckons a path from profile headings and lands on the exit fix',
    () async {
      final container = await makeContainer(
        dive: diveWithHeadings(),
        profile: headingProfile(),
      );
      final path = await container.read(
        spatialReckonedPathProvider('d1').future,
      );
      expect(path, isNotNull);
      expect(path!.reconstructed, isTrue);
      expect(path.points.length, greaterThan(2));
    },
  );

  test('geometry provider builds the seascape scene', () async {
    final container = await makeContainer(
      dive: diveWithHeadings(),
      profile: headingProfile(),
    );
    final result = await container.read(spatialGeometryProvider('d1').future);
    expect(result, isNotNull);
    final scene = result!.scene;
    expect(scene.layers.length, 5);
    expect(scene.scrubPath!.zs, isNotNull);
    // No coordinates anywhere in this fixture -> synthesized terrain.
    expect(result.bathymetrySourceId, isNull);
  });

  test('null when the dive has no profile', () async {
    final container = await makeContainer(dive: diveWithHeadings());
    final scene = await container.read(spatialGeometryProvider('d1').future);
    expect(scene, isNull);
  });

  test('respects the diver-selected active (non-primary) source', () async {
    final base = await getBaseOverrides();
    // Primary 'src' has 31 points; the active secondary 'src2' has 3 -> the
    // reckoned path length tells us which source's profile was used.
    const secondary = SourceProfile(
      sourceId: 'src2',
      computerId: null,
      isEdited: false,
      points: [
        DiveProfilePoint(timestamp: 0, depth: 0),
        DiveProfilePoint(timestamp: 600, depth: 20),
        DiveProfilePoint(timestamp: 1200, depth: 0),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        ...base,
        diveProvider(
          'd1',
        ).overrideWith((ref) async => diveWithHeadings(withGps: false)),
        sourceProfilesProvider('d1').overrideWith(
          (ref) async => {'src': headingProfile(), 'src2': secondary},
        ),
        activeDiveSourceProvider('d1').overrideWith((ref) => 'src2'),
      ],
    );
    addTearDown(container.dispose);

    final path = await container.read(spatialReckonedPathProvider('d1').future);
    expect(path, isNotNull);
    expect(path!.points.length, 3); // used src2 (3 pts), not primary (31)
  });

  test('works without GPS via the straight-line fallback', () async {
    final container = await makeContainer(
      dive: diveWithHeadings(withGps: false),
      profile: const SourceProfile(
        sourceId: 'src',
        computerId: null,
        isEdited: false,
        points: [
          DiveProfilePoint(timestamp: 0, depth: 0),
          DiveProfilePoint(timestamp: 600, depth: 20),
          DiveProfilePoint(timestamp: 1200, depth: 0),
        ],
      ),
    );
    final scene = await container.read(spatialGeometryProvider('d1').future);
    expect(scene, isNotNull);
  });

  group('a linked underwater route', () {
    List<NavTrackPoint> pointsOf(int count) => [
      for (var i = 0; i < count; i++)
        NavTrackPoint(timestamp: i * 10, north: i * 5.0, east: 0, depth: 5),
    ];

    test('with >=2 points wins over dead reckoning', () async {
      final container = await makeContainer(
        dive: diveWithHeadings(),
        profile: headingProfile(),
        route: _route(points: pointsOf(3)),
      );

      final path = await container.read(
        spatialReckonedPathProvider('d1').future,
      );

      expect(path, isNotNull);
      expect(path!.provenance, PathProvenance.measured);
      expect(path.points, hasLength(3));
    });

    test('with fewer than 2 points falls back to the estimate', () async {
      final container = await makeContainer(
        dive: diveWithHeadings(),
        profile: headingProfile(),
        route: _route(points: pointsOf(1)),
      );

      final path = await container.read(
        spatialReckonedPathProvider('d1').future,
      );

      expect(path, isNotNull);
      expect(path!.provenance, PathProvenance.deadReckoned);
    });

    test('unlinking (null route) restores the estimate', () async {
      final container = await makeContainer(
        dive: diveWithHeadings(),
        profile: headingProfile(),
        // No route override at all: primaryNavTrackForDiveProvider defaults
        // to null via getBaseOverrides, as it would once a route is
        // unlinked.
      );

      final path = await container.read(
        spatialReckonedPathProvider('d1').future,
      );

      expect(path, isNotNull);
      expect(path!.provenance, PathProvenance.deadReckoned);
    });

    test('raw length >= 2 but the adapted (active-range) path drops below 2 '
        'points falls back to dead reckoning instead of a degenerate '
        'measured path', () async {
      // A route whose very first sample is already at the surface,
      // immediately followed by a qualifying GPS-fix jump (>50 m in <=5 s
      // at the surface): the segmenter puts the fix event at index 1, so
      // NavTrackPathAdapter's active range (up to but excluding the fix
      // event) keeps only index 0 -- one point, even though the raw
      // recording has two.
      final route = _route(
        points: const [
          NavTrackPoint(timestamp: 0, north: 0, east: 0, depth: 0),
          NavTrackPoint(timestamp: 2, north: 500, east: 20, depth: 0),
        ],
      );
      final container = await makeContainer(
        dive: diveWithHeadings(),
        profile: headingProfile(),
        route: route,
      );

      final path = await container.read(
        spatialReckonedPathProvider('d1').future,
      );

      expect(path, isNotNull);
      expect(
        path!.provenance,
        PathProvenance.deadReckoned,
        reason:
            'the raw route has >= 2 points, but the adapted path has '
            'only 1 after truncating to the active range -- that must '
            'fall back to dead reckoning, not render a 1-point '
            '"measured" path',
      );
    });
  });

  group(
    'a manually aligned, linked route\'s own anchor for terrain placement',
    () {
      BathymetryGrid grid() => BathymetryGrid(
        originLat: 10.0,
        originLon: 20.0,
        cellSizeLatDeg: 0.001, // ~111 m
        cellSizeLonDeg: 0.001,
        rows: 2,
        cols: 2,
        depthsMeters: const [20, 30, 25, 35],
        sourceId: 'gmrt',
        resolutionMeters: 61,
        fetchedAt: DateTime.utc(2026, 7, 28),
      );

      Future<ProviderContainer> containerFor(NavTrack route) async {
        final base = await getBaseOverrides(primaryNavTrack: route);
        final container = ProviderContainer(
          overrides: [
            ...base,
            diveProvider('d1').overrideWith(
              (ref) async => Dive(
                id: 'd1',
                dateTime: DateTime.utc(2026, 1, 1),
                // Far from both the site and the route's own anchor, offset
                // mostly in longitude (east) so the effect lands squarely on
                // the axisInputs.maxEast assertion below: the dive's entry
                // fix must NOT be used to place a measured, anchored route
                // in its own dive's 3D scene.
                entryLocation: const GeoPoint(10.0005, 20.01),
                site: const DiveSite(
                  id: 's1',
                  name: 'Reef',
                  location: GeoPoint(10.0005, 20.0005),
                  maxDepth: 30,
                ),
              ),
            ),
            sourceProfilesProvider(
              'd1',
            ).overrideWith((ref) async => {'src': headingProfile()}),
            bathymetryGridProvider.overrideWith((ref, cell) async => grid()),
          ],
        );
        addTearDown(container.dispose);
        return container;
      }

      final points = [
        for (var i = 0; i < 3; i++)
          NavTrackPoint(timestamp: i * 10, north: i * 5.0, east: 0, depth: 5),
      ];

      test(
        'uses the route\'s own anchor, not the dive\'s entry location',
        () async {
          final container = await containerFor(
            _route(
              points: points,
              // Right on the site's location: the anchor should place the
              // path there, not ~1.1 km away at the dive's entryLocation.
              anchorLatitude: 10.0005,
              anchorLongitude: 20.0005,
            ),
          );

          final result = await container.read(
            spatialGeometryProvider('d1').future,
          );

          expect(result, isNotNull);
          expect(result!.axisInputs, isNotNull);
          // The small grid spans roughly +/-111 m from its center. With the
          // bug, the scene frame would need to stretch to cover the dive's
          // entryLocation offset (~1.1 km away), pushing maxEast well past
          // that. Fixed, the route's own (near-zero) anchor keeps the frame
          // close to the terrain's own extent.
          expect(
            result.axisInputs!.maxEast.abs(),
            lessThan(500),
            reason:
                'the scene frame should stay anchored near the terrain '
                'and the route\'s own start point, not stretch out to the '
                'dive\'s entryLocation ~1.1 km away',
          );
        },
      );
    },
  );
}
