import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/demo_data/src/shape/dive_shape.dart';
import '../../../tool/demo_data/src/shape/shape_library.dart';
import 'synthetic_shapes.dart';

void main() {
  test('picks a shape of the wanted kind near the target depth', () {
    final library = ShapeLibrary(syntheticShapes(), Random(1));

    final rec = library.pick(
      kinds: const {ShapeKind.recreational},
      diveMode: 'oc',
      targetMaxDepth: 20,
    );
    final ccr = library.pick(
      kinds: const {ShapeKind.ccr},
      diveMode: 'ccr',
      targetMaxDepth: 40,
    );

    expect(rec.kinds, contains(ShapeKind.recreational));
    expect(rec.maxDepth, inInclusiveRange(20 / 1.15, 20 / 0.85));
    expect(ccr.diveMode, 'ccr');
  });

  test('no shape is used more than three times', () {
    final library = ShapeLibrary(syntheticShapes(), Random(2));
    final uses = <String, int>{};

    for (var i = 0; i < 40; i++) {
      final s = library.pick(
        kinds: const {ShapeKind.recreational},
        diveMode: 'oc',
        targetMaxDepth: 18,
      );
      uses[s.id] = (uses[s.id] ?? 0) + 1;
    }

    expect(uses.values.every((n) => n <= ShapeLibrary.maxUses), isTrue);
  });

  test('a trip never repeats a shape', () {
    final library = ShapeLibrary(syntheticShapes(), Random(3));
    final seen = <String>{};

    for (var i = 0; i < 10; i++) {
      final s = library.pick(
        kinds: const {ShapeKind.recreational},
        diveMode: 'oc',
        targetMaxDepth: 18,
        tripId: 'trip-1',
      );
      expect(seen.add(s.id), isTrue);
    }
  });

  test(
    'falls back to the nearest depth of the right mode when nothing fits',
    () {
      final library = ShapeLibrary(syntheticShapes(), Random(4));

      final s = library.pick(
        kinds: const {ShapeKind.trimix},
        diveMode: 'oc',
        targetMaxDepth: 90,
      );

      expect(s.kinds, contains(ShapeKind.trimix));
    },
  );

  DiveShape logged(String id, List<(int, double)> points) => DiveShape(
    id: id,
    kinds: const {ShapeKind.recreational},
    diveMode: 'oc',
    sampleIntervalSec: 60,
    samples: [for (final (t, d) in points) ShapeSample(t: t, depth: d)],
    tanks: const [
      ShapeTank(
        o2: 21,
        he: 0,
        role: 'backGas',
        pressures: [(0, 200.0), (3000, 60.0), (40000, 59.0)],
      ),
    ],
  );

  test('a shape logged for hours on end is never picked', () {
    // A source with a wrong time scale: 14 hours at depth.
    final library = ShapeLibrary([
      logged('endless', [(0, 0), (600, 20), (50000, 20), (50100, 0)]),
      logged('normal', [(0, 0), (600, 20), (2400, 20), (2700, 0)]),
    ], Random(1));

    for (var i = 0; i < 3; i++) {
      expect(
        library
            .pick(
              kinds: const {ShapeKind.recreational},
              diveMode: 'oc',
              targetMaxDepth: 20,
            )
            .id,
        'normal',
      );
    }
  });

  test('time logged at the surface after the dive is cut off', () {
    final library = ShapeLibrary([
      logged('tail', [
        (0, 0),
        (600, 20),
        (2400, 20),
        (3000, 0.5),
        (40000, 0.3),
      ]),
    ], Random(1));

    final shape = library.pick(
      kinds: const {ShapeKind.recreational},
      diveMode: 'oc',
      targetMaxDepth: 20,
    );

    // Two minutes after the last sample deeper than 1 m.
    expect(shape.durationSec, lessThanOrEqualTo(2400 + 120));
    expect(shape.tanks.single.pressures.last.$1, lessThanOrEqualTo(2400 + 120));
  });

  test('a dive wanting one kind takes a shape without extra kinds first', () {
    final library = ShapeLibrary(syntheticShapes(), Random(3));

    for (var i = 0; i < 30; i++) {
      final s = library.pick(
        kinds: const {ShapeKind.multiGasDeco},
        diveMode: 'oc',
        targetMaxDepth: 45,
      );
      expect(s.kinds, isNot(contains(ShapeKind.deepOpenCircuit)));
    }
  });

  test('a shape that reaches the planned depth comes before fewer extra '
      'kinds', () {
    DiveShape deco(String id, Set<ShapeKind> kinds, double depth) => DiveShape(
      id: id,
      kinds: kinds,
      diveMode: 'oc',
      sampleIntervalSec: 60,
      samples: [
        const ShapeSample(t: 0, depth: 0),
        ShapeSample(t: 600, depth: depth),
        ShapeSample(t: 2400, depth: depth),
        const ShapeSample(t: 2700, depth: 0),
      ],
      tanks: const [],
    );
    final library = ShapeLibrary([
      deco('shallow', {ShapeKind.multiGasDeco}, 20),
      deco('deep', {ShapeKind.multiGasDeco, ShapeKind.deepOpenCircuit}, 42),
    ], Random(1));

    final s = library.pick(
      kinds: const {ShapeKind.multiGasDeco},
      diveMode: 'oc',
      targetMaxDepth: 42,
    );

    expect(s.id, 'deep');
  });

  test('a rebreather shape reaches 0.7 of its depth, open circuit 0.85', () {
    DiveShape at(String mode, double depth) => DiveShape(
      id: mode,
      kinds: const {},
      diveMode: mode,
      sampleIntervalSec: 60,
      samples: [
        const ShapeSample(t: 0, depth: 0),
        ShapeSample(t: 600, depth: depth),
        const ShapeSample(t: 1200, depth: 0),
      ],
      tanks: const [],
    );

    expect(ShapeLibrary.reaches(at('ccr', 47.2), 33.1), isTrue);
    expect(ShapeLibrary.reaches(at('ccr', 47.2), 32.9), isFalse);
    expect(ShapeLibrary.reaches(at('oc', 47.2), 33.1), isFalse);
    expect(ShapeLibrary.reaches(at('oc', 47.2), 40.2), isTrue);
  });

  test('no shape of the wanted kinds for a technical dive is an error', () {
    final library = ShapeLibrary([
      for (final s in syntheticShapes())
        if (s.kinds.contains(ShapeKind.recreational)) s,
    ], Random(4));

    expect(
      () => library.pick(
        kinds: const {ShapeKind.multiGasDeco},
        diveMode: 'oc',
        targetMaxDepth: 45,
      ),
      throwsStateError,
    );
  });
}
