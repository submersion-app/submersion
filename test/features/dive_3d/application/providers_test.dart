import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/providers.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

import '../../../helpers/mock_providers.dart';

DiveProfilePoint point(int t, double d, {double? temp}) =>
    DiveProfilePoint(timestamp: t, depth: d, temperature: temp);

Future<ProviderContainer> makeContainer({
  Map<String, SourceProfile> sourceProfiles = const {},
}) async {
  final base = await getBaseOverrides();
  final container = ProviderContainer(
    overrides: [
      ...base,
      sourceProfilesProvider('d1').overrideWith((ref) async => sourceProfiles),
      tankPressuresProvider('d1').overrideWith((ref) async => const {}),
      gasSwitchesProvider('d1').overrideWith((ref) async => const []),
      diveComputerEventsProvider('d1').overrideWith((ref) async => const []),
      mediaForDiveProvider('d1').overrideWith((ref) async => const []),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('assembles scene data from the primary source profile', () async {
    final container = await makeContainer(
      sourceProfiles: {
        'src-primary': SourceProfile(
          sourceId: 'src-primary',
          computerId: 'c1',
          isEdited: false,
          points: [point(0, 0), point(60, 18), point(120, 0)],
        ),
        'src-other': SourceProfile(
          sourceId: 'src-other',
          computerId: 'c2',
          isEdited: false,
          points: [point(0, 0), point(60, 99)],
        ),
      },
    );
    final data = await container.read(dive3dSceneDataProvider('d1').future);
    expect(data, isNotNull);
    // Null active source means primary; sourceProfiles orders primary
    // first, so the 18m profile wins over the 99m one.
    expect(data!.maxDepthMeters, 18);
    expect(data.times.length, 3);
  });

  test('returns null when no source has a usable profile', () async {
    final container = await makeContainer(
      sourceProfiles: {
        'src-primary': SourceProfile(
          sourceId: 'src-primary',
          computerId: 'c1',
          isEdited: false,
          points: [point(0, 0)], // single sample: not a profile
        ),
      },
    );
    final data = await container.read(dive3dSceneDataProvider('d1').future);
    expect(data, isNull);
  });

  test('geometry provider is null for profileless dives and builds '
      'synchronously for small profiles', () async {
    final empty = await makeContainer();
    expect(
      await empty.read(
        dive3dGeometryProvider((
          diveId: 'd1',
          colorMetric: SceneMetric.depth,
          zMetric: null,
        )).future,
      ),
      isNull,
    );

    final container = await makeContainer(
      sourceProfiles: {
        'src': SourceProfile(
          sourceId: 'src',
          computerId: null,
          isEdited: false,
          points: [point(0, 0), point(60, 10), point(120, 0)],
        ),
      },
    );
    final scene = await container.read(
      dive3dGeometryProvider((
        diveId: 'd1',
        colorMetric: SceneMetric.depth,
        zMetric: null,
      )).future,
    );
    expect(scene, isNotNull);
    // Ribbon (last structural layer): 3 samples x 2 vertices.
    expect(
      scene!.layers.lastWhere((l) => l.overlay == null).mesh.vertexCount,
      12,
    );
    expect(scene.layers.last.overlay, isNull); // the path
    expect(scene.scrubPath, isNotNull);
  });

  test('a Z metric puts shadows in the scene and exposes its axis', () async {
    final container = await makeContainer(
      sourceProfiles: {
        'src': SourceProfile(
          sourceId: 'src',
          computerId: null,
          isEdited: false,
          points: [
            point(0, 0, temp: 22),
            point(60, 10, temp: 14),
            point(120, 0, temp: 20),
          ],
        ),
      },
    );
    await container.read(dive3dSceneDataProvider('d1').future);
    final axis = container.read(
      dive3dZAxisProvider((diveId: 'd1', zMetric: SceneMetric.temperature)),
    );
    expect(axis!.spec.symbol, '°C');
    final scene = await container.read(
      dive3dGeometryProvider((
        diveId: 'd1',
        colorMetric: SceneMetric.depth,
        zMetric: SceneMetric.temperature,
      )).future,
    );
    expect(
      scene!.layers.where((l) => l.overlay == SceneOverlay.shadows),
      hasLength(2),
    );
  });
}
