/// Which gas-consumption lane a value belongs to.
///
/// SAC is a tank-pressure drop rate (bar/min or psi/min) read from one
/// reference cylinder. RMV is the surface gas volume breathed per minute
/// (L/min or cuft/min) summed across every cylinder with a volume. They are
/// not unit conversions of each other on multi-tank dives (discussions #354
/// and #803).
enum GasConsumptionLane { sac, rmv }

/// Which lanes the single-value surfaces (detail summary, list cards, chart
/// tooltip, statistics) show. Replaces the retired SacUnit preference, which
/// treated the two lanes as one value with a unit toggle.
enum GasConsumptionDisplay {
  sac,
  rmv,
  both;

  bool get showsSac => this != rmv;
  bool get showsRmv => this != sac;

  /// Lanes in render order; SAC first when both are shown.
  List<GasConsumptionLane> get lanes => [
    if (showsSac) GasConsumptionLane.sac,
    if (showsRmv) GasConsumptionLane.rmv,
  ];

  /// Resolves a stored or synced name. The two retired SacUnit spellings map
  /// onto the lane they meant so a value written by an older build keeps the
  /// diver on the lane they were seeing; anything else lands on [both].
  static GasConsumptionDisplay fromName(String? name) => switch (name) {
    'sac' || 'pressurePerMin' => sac,
    'rmv' || 'litersPerMin' => rmv,
    _ => both,
  };
}
