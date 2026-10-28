import 'story_plan.dart';

/// The first dive of the technical phase, the deco course's first dive.
const techStartDive = 250;

/// The nitrox card is issued a few days before this dive.
const nitroxDive = 50;

/// The courses and the dive numbers of their training dives, for a
/// [diveCount] dive story with [ccrCount] rebreather dives at the end.
Map<CertLevel, (int, int)> courseDives(int diveCount, int ccrCount) {
  final ccrStart = diveCount - ccrCount + 1;
  return {
    CertLevel.openWater: (1, 4),
    CertLevel.advanced: (25, 29),
    CertLevel.rescue: (90, 91),
    CertLevel.deep: (150, 153),
    CertLevel.decoProcedures: (techStartDive, techStartDive + 3),
    CertLevel.trimix: (380, 383),
    CertLevel.ccr: (ccrStart, ccrStart + 4),
  };
}
