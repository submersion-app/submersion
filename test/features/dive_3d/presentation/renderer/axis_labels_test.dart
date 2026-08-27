import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/axis_labels.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

void main() {
  final result = SubsurfaceTissueBuilder.buildResult(
    BuhlmannAlgorithm().processProfile(
      depths: const [0, 30, 30, 30, 0],
      timestamps: const [0, 120, 600, 1200, 1400],
    ),
    colorFn: thermalColor,
  );

  AxisLabelSet build({int? runtimeSeconds}) => buildTissueAxisLabels(
    bounds: result.scene.bounds,
    grid: result.grid,
    referenceY: SubsurfaceTissueBuilder.referenceHeight,
    timeTitle: 'Time',
    saturationTitle: 'Saturation %',
    compartmentTitle: 'Compartment',
    runtimeSeconds: runtimeSeconds,
  );

  test('emits the three axis titles', () {
    final titles = build().labels
        .where((l) => l.kind == AxisLabelKind.title)
        .map((l) => l.text)
        .toList();
    expect(titles, containsAll(['Time', 'Saturation %', 'Compartment']));
  });

  test('emits Y ticks 0 / 50 / 100 at the right heights', () {
    final ticks = build().labels.where((l) => l.kind == AxisLabelKind.tick);
    final y100 = ticks.firstWhere((l) => l.text == '100');
    final y50 = ticks.firstWhere((l) => l.text == '50');
    expect(y100.y, SubsurfaceTissueBuilder.referenceHeight);
    expect(y50.y, SubsurfaceTissueBuilder.referenceHeight * 0.5);
    expect(ticks.any((l) => l.text == '0'), isTrue);
  });

  test('Y tick anchors interpolate from sceneMinY (not world 0), matching '
      'the AxisFrame tick geometry', () {
    // A tissue scene whose floor is offset from the world origin. AxisFrame
    // runs the saturation axis from y0=sceneMinY up to referenceY, so the
    // labels must anchor the same way or they float off their tick marks.
    const referenceY = 3.0;
    const y0 = 2.0; // nonzero floor
    const bounds = SceneBounds(
      durationSeconds: 1,
      maxDepthMeters: 1,
      sceneMinY: y0,
      sceneMaxY: referenceY,
    );
    final ticks = buildTissueAxisLabels(
      bounds: bounds,
      grid: result.grid,
      referenceY: referenceY,
      timeTitle: 'Time',
      saturationTitle: 'Saturation %',
      compartmentTitle: 'Compartment',
    ).labels.where((l) => l.kind == AxisLabelKind.tick);

    double tickY(String text) => ticks.firstWhere((l) => l.text == text).y;
    expect(tickY('0'), y0);
    expect(tickY('50'), y0 + (referenceY - y0) * 0.5);
    expect(tickY('100'), referenceY);
  });

  test('labels the fast, middle, and slow compartment numbers', () {
    final texts = build().labels.map((l) => l.text).toList();
    expect(texts, containsAll(['1', '8', '16']));
  });

  test('time ticks are minutes when runtime is known, absent otherwise', () {
    // 1400 s = ~23 min total; the 100% tick should read 23.
    final withRuntime = build(runtimeSeconds: 1400).labels.map((l) => l.text);
    expect(withRuntime, contains('23'));

    // With no runtime, no minute ticks along X (only Y/Z ticks + titles).
    final without = build();
    // The only numeric tick texts should be Y (0/50/100) and Z compartments.
    expect(without.labels.any((l) => l.text == '23'), isFalse);
  });
}
