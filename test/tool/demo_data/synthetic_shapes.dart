import 'dart:math';

import '../../../tool/demo_data/src/shape/dive_shape.dart';

/// Shapes built from easing curves, for CI: synthetic, so committing and
/// running them involves no real diver's data. One family per kind the story
/// asks for, at a spread of depths.
List<DiveShape> syntheticShapes() {
  final shapes = <DiveShape>[];
  var n = 0;
  DiveShape make({
    required double depth,
    required int minutes,
    required Set<ShapeKind> kinds,
    String mode = 'oc',
    List<ShapeTank> tanks = const [],
    bool heartRate = false,
    int computers = 1,
  }) {
    final dur = minutes * 60;
    final samples = <ShapeSample>[];
    for (var t = 0; t <= dur; t += 10) {
      final f = t / dur;
      final d = f < 0.08
          ? depth * f / 0.08
          : f < 0.7
          ? depth * (1 - 0.15 * sin(f * 9))
          : f < 0.92
          ? depth * (1 - (f - 0.7) / 0.22) * 0.9 + 5 * ((f - 0.7) / 0.22)
          : max(0.0, 5 * (1 - (f - 0.92) / 0.08));
      samples.add(
        ShapeSample(
          t: t,
          depth: double.parse(d.toStringAsFixed(2)),
          temp: 24 - d / 10,
          heartRate: heartRate ? 70 + (d / 2).round() : null,
          ppO2: mode == 'ccr' && d > 2 ? 1.3 : null,
          setpoint: mode == 'ccr' ? (d > 6 ? 1.3 : 0.7) : null,
          cells: mode == 'ccr' ? [1.29, 1.31, 1.3] : null,
        ),
      );
    }
    final withPressure = [
      for (final tank in tanks)
        ShapeTank(
          o2: tank.o2,
          he: tank.he,
          role: tank.role,
          volumeL: tank.volumeL,
          startBar: tank.startBar,
          endBar: tank.endBar,
          pressures: [
            for (var t = 0; t <= dur; t += 30)
              (t, tank.startBar! - (tank.startBar! - tank.endBar!) * t / dur),
          ],
        ),
    ];
    return DiveShape(
      id: 'synthetic-${n++}',
      kinds: {...kinds, if (tanks.isNotEmpty) ShapeKind.tankPressure},
      diveMode: mode,
      sampleIntervalSec: 10,
      samples: samples,
      tanks: withPressure,
      computerCount: computers,
    );
  }

  const air = ShapeTank(
    o2: 21,
    he: 0,
    role: 'backGas',
    volumeL: 11.1,
    startBar: 200,
    endBar: 60,
  );
  const ean50 = ShapeTank(
    o2: 50,
    he: 0,
    role: 'deco',
    volumeL: 7,
    startBar: 200,
    endBar: 140,
  );
  const tx = ShapeTank(
    o2: 21,
    he: 35,
    role: 'backGas',
    volumeL: 24,
    startBar: 220,
    endBar: 90,
  );
  const o2 = ShapeTank(
    o2: 100,
    he: 0,
    role: 'oxygenSupply',
    volumeL: 3,
    startBar: 200,
    endBar: 120,
  );
  const dil = ShapeTank(
    o2: 21,
    he: 35,
    role: 'diluent',
    volumeL: 3,
    startBar: 200,
    endBar: 150,
  );
  const bail = ShapeTank(
    o2: 21,
    he: 35,
    role: 'bailout',
    volumeL: 11.1,
    startBar: 200,
    endBar: 195,
  );

  for (var i = 0; i < 90; i++) {
    shapes.add(
      make(
        depth: 8.0 + (i % 14) * 2.2,
        minutes: 35 + (i % 20),
        kinds: {ShapeKind.recreational},
        tanks: [air],
        heartRate: i.isEven,
        computers: i % 4 == 0 ? 2 : 1,
      ),
    );
  }
  for (var i = 0; i < 45; i++) {
    shapes.add(
      make(
        depth: 40.0 + (i % 6) * 3,
        minutes: 55 + (i % 9) * 4,
        kinds: {ShapeKind.deepOpenCircuit, ShapeKind.multiGasDeco},
        tanks: [air, ean50],
      ),
    );
  }
  for (var i = 0; i < 25; i++) {
    shapes.add(
      make(
        depth: 50.0 + (i % 5) * 4,
        minutes: 70 + (i % 6) * 5,
        kinds: {
          ShapeKind.trimix,
          ShapeKind.deepOpenCircuit,
          ShapeKind.multiGasDeco,
        },
        tanks: [tx, ean50],
      ),
    );
  }
  for (var i = 0; i < 14; i++) {
    shapes.add(
      make(
        depth: 12.0 + (i % 5) * 10,
        minutes: 60 + i * 10,
        kinds: {ShapeKind.ccr},
        mode: 'ccr',
        tanks: [o2, dil, bail],
      ),
    );
  }
  return shapes;
}
