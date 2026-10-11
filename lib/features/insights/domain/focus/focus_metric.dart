/// Where a metric sits in the sentence builder's grouped menu.
enum FocusMetricGroup { gas, depthTime, conditions, exposure, kit }

/// A per-dive value Dive focus can rank or threshold on. Each reuses a
/// per-dive series the repository already computes, so a dive's value here
/// is exactly its value on the matching trend chart.
enum FocusMetric {
  rmv(FocusMetricGroup.gas, lowerIsBetter: true),
  sac(FocusMetricGroup.gas, lowerIsBetter: true),
  gasUsed(FocusMetricGroup.gas, lowerIsBetter: true),
  maxDepth(FocusMetricGroup.depthTime),
  avgDepth(FocusMetricGroup.depthTime),
  bottomTime(FocusMetricGroup.depthTime),
  surfaceInterval(FocusMetricGroup.depthTime),
  waterTemp(FocusMetricGroup.conditions),
  airTemp(FocusMetricGroup.conditions),
  visibility(FocusMetricGroup.conditions),
  altitude(FocusMetricGroup.conditions),
  cns(FocusMetricGroup.exposure),
  otu(FocusMetricGroup.exposure),
  weight(FocusMetricGroup.kit);

  const FocusMetric(this.group, {this.lowerIsBetter = false});

  final FocusMetricGroup group;

  /// Gas consumption is better when lower; the other metrics have no better
  /// end, so their modes read "lowest" and "highest".
  final bool lowerIsBetter;
}
