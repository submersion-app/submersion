import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_3d/application/tissue_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

List<DecoStatus> statuses() => BuhlmannAlgorithm().processProfile(
  depths: const [0, 30, 30, 30, 0],
  timestamps: const [0, 120, 600, 1200, 1400],
);

/// A status carrying no tissue compartments - the shape the deco engine can
/// emit when an analysis lacks per-compartment data. buildResult bails on these
/// (empty scene/grid), so the provider must report them as null.
DecoStatus _emptyCompartmentsStatus() => const DecoStatus(
  compartments: [],
  ndlSeconds: 0,
  ceilingMeters: 0,
  ttsSeconds: 0,
  gfLow: 0.3,
  gfHigh: 0.85,
  decoStops: [],
  currentDepthMeters: 0,
  ambientPressureBar: 1.0,
);

void main() {
  test('tissueSurfaceProvider builds scene and grid from statuses', () async {
    final container = ProviderContainer(
      overrides: [
        tissueDecoStatusesProvider(
          'd1',
        ).overrideWith((ref) async => statuses()),
        tissueColorSchemeProvider.overrideWithValue(
          TissueColorScheme.values.first,
        ),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(tissueSurfaceProvider('d1').future);
    expect(result, isNotNull);
    expect(result!.scene.layers.length, 2);
    expect(result.grid.columns, greaterThan(1));

    final grid = await container.read(tissueSurfaceGridProvider('d1').future);
    expect(grid, isNotNull);
    expect(grid!.compartments, 16);

    final scene = await container.read(tissue3dSceneProvider('d1').future);
    expect(scene, isNotNull);
    expect(scene!.layers.length, 2);
  });

  test('tissueSurfaceProvider is null for < 2 statuses', () async {
    final container = ProviderContainer(
      overrides: [
        tissueDecoStatusesProvider('d1').overrideWith((ref) async => const []),
        tissueColorSchemeProvider.overrideWithValue(
          TissueColorScheme.values.first,
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(tissueSurfaceProvider('d1').future), isNull);
    expect(
      await container.read(tissueSurfaceGridProvider('d1').future),
      isNull,
    );
  });

  test('tissueSurfaceProvider is null when statuses carry no compartments '
      '(matches buildResult bail-out)', () async {
    final container = ProviderContainer(
      overrides: [
        tissueDecoStatusesProvider('d1').overrideWith(
          (ref) async => [
            _emptyCompartmentsStatus(),
            _emptyCompartmentsStatus(),
          ],
        ),
        tissueColorSchemeProvider.overrideWithValue(
          TissueColorScheme.values.first,
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(tissueSurfaceProvider('d1').future), isNull);
    expect(
      await container.read(tissueSurfaceGridProvider('d1').future),
      isNull,
    );
  });
}
