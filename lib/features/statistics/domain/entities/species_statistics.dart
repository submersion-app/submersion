import 'package:equatable/equatable.dart';

import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';

/// Per-species statistics aggregated from dive sightings
class SpeciesStatistics extends Equatable {
  final int totalSightings;
  final int diveCount;
  final double? minDepthMeters;
  final double? maxDepthMeters;
  final int siteCount;
  final List<RankingItem> topSites;
  final DateTime? firstSeen;
  final DateTime? lastSeen;

  const SpeciesStatistics({
    required this.totalSightings,
    required this.diveCount,
    this.minDepthMeters,
    this.maxDepthMeters,
    required this.siteCount,
    this.topSites = const [],
    this.firstSeen,
    this.lastSeen,
  });

  static const empty = SpeciesStatistics(
    totalSightings: 0,
    diveCount: 0,
    siteCount: 0,
  );

  bool get isEmpty => totalSightings == 0;

  @override
  List<Object?> get props => [
    totalSightings,
    diveCount,
    minDepthMeters,
    maxDepthMeters,
    siteCount,
    topSites,
    firstSeen,
    lastSeen,
  ];
}
