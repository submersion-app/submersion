/// Dives grouped by the exposure suit linked to them, for the Suit Thickness
/// chart (issue #1824).
///
/// [byThickness] holds wetsuits with a recorded primary thickness, ascending.
/// A drysuit has no thickness in the attribute catalog and keeps a diver warm
/// through its undersuit rather than its shell, so drysuit dives get a bucket
/// of their own ([drysuitCount]) instead of being folded into a millimetre
/// bar. [unknownThicknessCount] holds dives whose linked wetsuit carries no
/// numeric thickness.
///
/// Each count is a number of distinct dives, but a dive linked to more than
/// one suit is counted once in every bucket it reaches.
typedef SuitThicknessStats = ({
  List<({double mm, int count})> byThickness,
  int unknownThicknessCount,
  int drysuitCount,
});
