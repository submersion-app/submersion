/// A per-dive value Dive focus can rank or threshold on. Each reuses the
/// trend chart series of the same name, so a dive's value here is exactly
/// its value on that chart.
enum FocusMetric {
  rmv,
  sac,
  maxDepth,
  bottomTime,
  weight,
  waterTemp;

  /// Gas consumption is better when lower; the other metrics have no better
  /// end, so their modes read "lowest" and "highest".
  bool get lowerIsBetter => this == rmv || this == sac;
}
