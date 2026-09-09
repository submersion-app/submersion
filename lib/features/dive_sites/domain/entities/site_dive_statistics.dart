import 'package:equatable/equatable.dart';

/// Auto-computed dive statistics for a single site, aggregated over the
/// dives actually logged there (submersion-app/submersion#1018, #1038).
///
/// Distinct from [DiveSite.minDepth]/[DiveSite.maxDepth] (site
/// characteristics, manually entered via `DiveInfoSection`) - this holds
/// values derived from `Dives.maxDepth` and dive duration, never written
/// back to the site row. Depths are stored in metres and durations in
/// seconds; convert at the display edge.
///
/// Each aggregate that comes from one identifiable dive also carries that
/// dive's id, so the statistics card can link the number to the dive it was
/// taken from. `averageDurationSeconds` has no anchor: no single dive holds
/// the mean. An anchor is null whenever the aggregate beside it is null,
/// which includes the case where every dive at the site lacks the underlying
/// column - a dive with no recorded depth contributes to neither
/// [maxDepthReached] nor [deepestDiveId].
class SiteDiveStatistics extends Equatable {
  final int diveCount;
  final double? maxDepthReached;
  final double? minDepthReached;
  final int? longestDiveSeconds;
  final double? averageDurationSeconds;
  final DateTime? firstDiveAt;
  final DateTime? lastDiveAt;

  /// The dive that reached [maxDepthReached].
  final String? deepestDiveId;

  /// The dive that reached [minDepthReached].
  final String? shallowestDiveId;

  /// The dive that ran for [longestDiveSeconds].
  final String? longestDiveId;

  /// The dive logged at [firstDiveAt].
  final String? firstDiveId;

  /// The dive logged at [lastDiveAt].
  final String? lastDiveId;

  const SiteDiveStatistics({
    required this.diveCount,
    this.maxDepthReached,
    this.minDepthReached,
    this.longestDiveSeconds,
    this.averageDurationSeconds,
    this.firstDiveAt,
    this.lastDiveAt,
    this.deepestDiveId,
    this.shallowestDiveId,
    this.longestDiveId,
    this.firstDiveId,
    this.lastDiveId,
  });

  static const empty = SiteDiveStatistics(diveCount: 0);

  bool get hasData => diveCount > 0;

  @override
  List<Object?> get props => [
    diveCount,
    maxDepthReached,
    minDepthReached,
    longestDiveSeconds,
    averageDurationSeconds,
    firstDiveAt,
    lastDiveAt,
    deepestDiveId,
    shallowestDiveId,
    longestDiveId,
    firstDiveId,
    lastDiveId,
  ];
}
