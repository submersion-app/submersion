import 'dart:math';

import '../shape/dive_shape.dart';
import 'story_plan.dart';

/// What kind of dive a planned dive is: the shape kinds it wants, how deep
/// it goes, how many cylinders it carries and the card it needs.
typedef DiveSpec = ({
  Set<ShapeKind> kinds,
  double depth,
  int tanks,
  CertLevel? requires,
});

const _rec = {ShapeKind.recreational};

/// Whether technical diving happens at [d]: home, the cold seas and the wreck
/// destinations. Elsewhere a technical diver mostly dives recreationally.
bool isTechnicalDestination(Destination d) =>
    d.key == 'home' ||
    d.minPhase == StoryPhase.technicalOc ||
    d.waterTempC.$1 < 14;

/// The spec of dive [n] in [phase], on [course] when it is a training dive.
DiveSpec diveSpecFor(
  int n,
  StoryPhase phase,
  CertLevel? course,
  Destination destination,
  Random random,
  Map<CertLevel, (int, int)> courses,
) {
  double range(double lo, double hi) =>
      (lo + random.nextDouble() * (hi - lo)).roundToDouble();
  switch (course) {
    case CertLevel.openWater:
      return (kinds: _rec, depth: range(6, 12), tanks: 1, requires: null);
    case CertLevel.advanced:
      return (
        kinds: _rec,
        depth: range(16, 28),
        tanks: 1,
        requires: CertLevel.openWater,
      );
    case CertLevel.rescue:
      return (
        kinds: _rec,
        depth: range(5, 12),
        tanks: 1,
        requires: CertLevel.advanced,
      );
    case CertLevel.deep:
      return (
        kinds: _rec,
        depth: range(28, 38),
        tanks: 1,
        requires: CertLevel.advanced,
      );
    case CertLevel.decoProcedures:
      return (
        kinds: {ShapeKind.multiGasDeco},
        depth: range(30, 45),
        tanks: 2,
        requires: CertLevel.deep,
      );
    case CertLevel.trimix:
      return (
        kinds: {ShapeKind.deepOpenCircuit, ShapeKind.multiGasDeco},
        depth: range(50, 60),
        tanks: 3,
        requires: CertLevel.decoProcedures,
      );
    case CertLevel.ccr:
      return (
        kinds: {ShapeKind.ccr},
        depth: range(10, 30),
        tanks: 3,
        requires: CertLevel.decoProcedures,
      );
    case CertLevel.nitrox || null:
      break;
  }
  final deepCardFrom = courses[CertLevel.deep]!.$2 + 1;
  final advancedFrom = courses[CertLevel.advanced]!.$2 + 1;
  // Where the water is an overhead below a cavern's depth (the springs),
  // every dive is a recreational cavern dive.
  final cap = destination.maxDepthM;
  if (cap != null && phase != StoryPhase.rebreather) {
    return (
      kinds: _rec,
      depth: range(8, n < advancedFrom ? min(cap, 18.0) : cap),
      tanks: 1,
      requires: n < advancedFrom ? CertLevel.openWater : CertLevel.advanced,
    );
  }
  switch (phase) {
    case StoryPhase.recreational:
      final max = n < advancedFrom ? 18.0 : (n >= deepCardFrom ? 38.0 : 30.0);
      return (
        kinds: _rec,
        depth: range(10, max),
        tanks: 1,
        requires: n < advancedFrom
            ? CertLevel.openWater
            : (n >= deepCardFrom ? CertLevel.deep : CertLevel.advanced),
      );
    case StoryPhase.technicalOc:
      final roll = random.nextDouble();
      if (!isTechnicalDestination(destination) && roll < 0.8) {
        return (
          kinds: _rec,
          depth: range(15, 30),
          tanks: 1,
          requires: CertLevel.advanced,
        );
      }
      final trimixHeld = n > courses[CertLevel.trimix]!.$2;
      final deep = random.nextDouble();
      if (deep < 0.4) {
        return (
          kinds: {ShapeKind.deepOpenCircuit},
          depth: range(28, 40),
          tanks: 1,
          requires: CertLevel.deep,
        );
      }
      if (deep < 0.85 || !trimixHeld) {
        return (
          kinds: {ShapeKind.multiGasDeco},
          depth: range(35, 45),
          tanks: 2,
          requires: CertLevel.decoProcedures,
        );
      }
      return (
        kinds: {ShapeKind.deepOpenCircuit, ShapeKind.multiGasDeco},
        depth: range(50, 70),
        tanks: 3,
        requires: CertLevel.trimix,
      );
    case StoryPhase.rebreather:
      return (
        kinds: {ShapeKind.ccr},
        depth: range(20, 40),
        tanks: 3,
        requires: CertLevel.ccr,
      );
  }
}
