import 'package:equatable/equatable.dart';

/// Auto-computed dive statistics for a single site, aggregated over the
/// dives actually logged there (submersion-app/submersion#1018, #1038).
///
/// Distinct from [DiveSite.minDepth]/[DiveSite.maxDepth] (site
/// characteristics, manually entered via `DiveInfoSection`) - this holds
/// values derived from `Dives.maxDepth` and dive duration, never written
/// back to the site row. Depths are stored in metres and durations in
/// seconds; convert at the display edge.
class SiteDiveStatistics extends Equatable {
  final int diveCount;
  final double? maxDepthReached;
  final double? minDepthReached;
  final int? longestDiveSeconds;
  final double? averageDurationSeconds;
  final DateTime? firstDiveAt;
  final DateTime? lastDiveAt;

  const SiteDiveStatistics({
    required this.diveCount,
    this.maxDepthReached,
    this.minDepthReached,
    this.longestDiveSeconds,
    this.averageDurationSeconds,
    this.firstDiveAt,
    this.lastDiveAt,
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
  ];
}
