import 'package:flutter_test/flutter_test.dart';

import '../../../tool/demo_data/src/shape/dive_shape.dart';
import '../../../tool/demo_data/src/shape/shape_budget.dart';
import '../../../tool/demo_data/src/story/story_plan.dart';
import '../../../tool/demo_data/src/story/story_planner.dart';

void main() {
  var shapeIds = 0;
  DiveShape shape(Set<ShapeKind> kinds, {String mode = 'oc'}) => DiveShape(
    id: 'shape-${shapeIds++}',
    kinds: kinds,
    diveMode: mode,
    sampleIntervalSec: 10,
    samples: const [
      ShapeSample(t: 0, depth: 0),
      ShapeSample(t: 600, depth: 20),
      ShapeSample(t: 1200, depth: 0),
    ],
    tanks: const [],
    computerCount: 1,
  );

  StoryPlan plan(List<(Set<ShapeKind>, String)> wanted, {double depth = 20}) =>
      StoryPlan(
        anchor: DateTime(2026, 10, 1),
        dives: [
          for (var i = 0; i < wanted.length; i++)
            PlannedDive(
              number: i + 1,
              start: DateTime(2026, 1, 1, 9).add(Duration(hours: 4 * i)),
              phase: StoryPhase.technicalOc,
              wantedKinds: wanted[i].$1,
              siteId: 'site',
              destination: StoryPlanner.home,
              targetMaxDepth: depth,
              diveMode: wanted[i].$2,
              tankCount: 1,
              buddyIds: const [],
              plannedDuration: const Duration(hours: 2),
              waterTempC: 12,
            ),
        ],
        trips: const [],
        certs: const [],
        courses: const [],
        sites: const [],
        centers: const [],
        people: const [],
        home: StoryPlanner.home,
      );

  test('a rebreather phase of 18 dives fits six rebreather shapes', () {
    final shapes = [
      for (var i = 0; i < 6; i++) shape({ShapeKind.ccr}, mode: 'ccr'),
    ];
    final dives = [
      for (var i = 0; i < 18; i++) ({ShapeKind.ccr}, 'ccr'),
    ];

    expect(shapeShortfalls(plan(dives), shapes), isEmpty);
  });

  test('a 19th rebreather dive is a shortfall', () {
    final shapes = [
      for (var i = 0; i < 6; i++) shape({ShapeKind.ccr}, mode: 'ccr'),
    ];
    final dives = [
      for (var i = 0; i < 19; i++) ({ShapeKind.ccr}, 'ccr'),
    ];

    final shortfalls = shapeShortfalls(plan(dives), shapes);

    expect(shortfalls, hasLength(1));
    expect(shortfalls.single.diveMode, 'ccr');
    expect(shortfalls.single.needed, 19);
    expect(shortfalls.single.available, 18);
  });

  test('a shape that fits two groups is counted once', () {
    final shapes = [
      shape({ShapeKind.deepOpenCircuit, ShapeKind.multiGasDeco}),
    ];
    final dives = [
      ({ShapeKind.deepOpenCircuit}, 'oc'),
      ({ShapeKind.deepOpenCircuit}, 'oc'),
      ({ShapeKind.multiGasDeco}, 'oc'),
      ({ShapeKind.multiGasDeco}, 'oc'),
    ];

    final shortfalls = shapeShortfalls(plan(dives), shapes);

    expect(shortfalls, hasLength(1));
    expect(shortfalls.single.needed, 4);
    expect(shortfalls.single.available, 3);
  });

  test('a recreational shape never covers a technical dive', () {
    final shapes = [
      for (var i = 0; i < 5; i++) shape({ShapeKind.recreational}),
    ];
    final dives = [
      ({ShapeKind.multiGasDeco}, 'oc'),
    ];

    final shortfalls = shapeShortfalls(plan(dives), shapes);

    expect(shortfalls.single.kinds, {ShapeKind.multiGasDeco});
    expect(shortfalls.single.available, 0);
  });

  test('a dive deeper than any shape can be stretched to is a shortfall', () {
    // Every shape goes to 20 m; the reshaper stretches depth by 1.15 at most.
    final shapes = [
      for (var i = 0; i < 5; i++) shape({ShapeKind.recreational}),
    ];
    final dives = [
      ({ShapeKind.recreational}, 'oc'),
    ];

    final shortfalls = shapeShortfalls(plan(dives, depth: 30), shapes);

    expect(shortfalls, hasLength(1));
    expect(shortfalls.single.needed, 1);
    expect(shortfalls.single.available, 0);
    expect(shortfalls.single.toString(), contains('at 30 to 30 m'));
    expect(shapeShortfalls(plan(dives, depth: 22), shapes), isEmpty);
  });
}
