/// Distance thresholds (metres) controlling auto-match confidence.
class MatchThresholds {
  /// A match within this distance with no close competitor is auto-applied.
  final double innerRadiusMeters;

  /// Candidates within this distance are shown as suggestions.
  final double outerRadiusMeters;

  /// The runner-up must be at least this much farther than the nearest for
  /// the nearest to count as a clear (auto) match.
  final double separationMeters;

  const MatchThresholds({
    required this.innerRadiusMeters,
    required this.outerRadiusMeters,
    required this.separationMeters,
  });
}
