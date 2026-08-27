import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Per-site aggregate over the dives table: how many dives were logged at
/// the site, when the most recent one was, and the deepest depth reached.
/// Depths are stored in metres; convert at the display edge.
class SiteDiveAggregate extends Equatable {
  final int diveCount;
  final DateTime? lastDivedAt;
  final double? maxDepthReached;

  const SiteDiveAggregate({
    required this.diveCount,
    this.lastDivedAt,
    this.maxDepthReached,
  });

  @override
  List<Object?> get props => [diveCount, lastDivedAt, maxDepthReached];
}

/// A [DiveSite] paired with the aggregates the list surfaces render.
///
/// [featureTypes] holds the distinct `site_features.type` names placed on
/// the site, ordered by first creation, so a list card can draw one chip
/// per feature kind without a per-row query. The aggregates are optional
/// so callers that only know a count (the maps) keep constructing this.
class SiteWithDiveCount extends Equatable {
  final DiveSite site;
  final int diveCount;
  final DateTime? lastDivedAt;
  final double? maxDepthReached;
  final List<String> featureTypes;

  const SiteWithDiveCount({
    required this.site,
    required this.diveCount,
    this.lastDivedAt,
    this.maxDepthReached,
    this.featureTypes = const [],
  });

  SiteWithDiveCount copyWith({
    DiveSite? site,
    int? diveCount,
    DateTime? lastDivedAt,
    double? maxDepthReached,
    List<String>? featureTypes,
  }) {
    return SiteWithDiveCount(
      site: site ?? this.site,
      diveCount: diveCount ?? this.diveCount,
      lastDivedAt: lastDivedAt ?? this.lastDivedAt,
      maxDepthReached: maxDepthReached ?? this.maxDepthReached,
      featureTypes: featureTypes ?? this.featureTypes,
    );
  }

  @override
  List<Object?> get props => [
    site,
    diveCount,
    lastDivedAt,
    maxDepthReached,
    featureTypes,
  ];
}
