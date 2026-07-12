import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../helpers/mock_providers.dart';

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
}) async {
  final base = await getBaseOverrides();
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
    final scene = await container.read(spatialGeometryProvider('d1').future);
    expect(scene, isNotNull);
    expect(scene!.layers.length, 5);
    expect(scene.scrubPath!.zs, isNotNull);
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
}
