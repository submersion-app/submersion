import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';

/// Hand-built series fixtures so painter tests never depend on the engine.
PlanCanvasSeries ndlSeries() => const PlanCanvasSeries(
  profile: [
    CanvasPoint(0, 0),
    CanvasPoint(100, 30),
    CanvasPoint(1300, 30),
    CanvasPoint(1500, 0),
  ],
  ceiling: [],
  gasSwitches: [],
  stopLabels: [],
  maxTimeSeconds: 1500,
  maxDepth: 30,
);

PlanCanvasSeries decoSeries() => const PlanCanvasSeries(
  profile: [
    CanvasPoint(0, 0),
    CanvasPoint(150, 45),
    CanvasPoint(1500, 45),
    CanvasPoint(1660, 21),
    CanvasPoint(1720, 21),
    CanvasPoint(1780, 12),
    CanvasPoint(1960, 12),
    CanvasPoint(1990, 9),
    CanvasPoint(2290, 9),
    CanvasPoint(2320, 6),
    CanvasPoint(3040, 6),
    CanvasPoint(3100, 0),
  ],
  ceiling: [
    CanvasPoint(1500, 19),
    CanvasPoint(1720, 14),
    CanvasPoint(1960, 9),
    CanvasPoint(2290, 5),
    CanvasPoint(3040, 0),
  ],
  gasSwitches: [CanvasMarker(1660, 21, 'EAN50')],
  stopLabels: [
    CanvasMarker(1660, 21, '', durationSeconds: 60),
    CanvasMarker(1780, 12, '', durationSeconds: 180),
    CanvasMarker(1990, 9, '', durationSeconds: 300),
    CanvasMarker(2320, 6, '', durationSeconds: 720),
  ],
  maxTimeSeconds: 3100,
  maxDepth: 45,
);

PlanCanvasSeries denseDecoSeries() {
  final profile = <CanvasPoint>[
    const CanvasPoint(0, 0),
    const CanvasPoint(200, 75),
    const CanvasPoint(1400, 75),
  ];
  final stops = <CanvasMarker>[];
  var t = 1400.0;
  for (var depth = 45.0; depth >= 3; depth -= 3) {
    t += 60;
    profile.add(CanvasPoint(t, depth));
    stops.add(CanvasMarker(t, depth, '', durationSeconds: 120));
    t += 120;
    profile.add(CanvasPoint(t, depth));
  }
  profile.add(CanvasPoint(t + 30, 0));
  return PlanCanvasSeries(
    profile: profile,
    ceiling: const [],
    gasSwitches: const [],
    stopLabels: stops,
    maxTimeSeconds: t + 30,
    maxDepth: 75,
  );
}
