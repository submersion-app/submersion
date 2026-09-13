import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// Per-site aggregate over the dives table: how many dives were logged at
/// the site, the span they cover, and the depths and durations they reached.
/// Depths are stored in metres and durations in seconds; convert at the
/// display edge.
///
/// Every field here comes from one grouped query over `dives`, so a list of
/// several hundred sites costs the same single round trip it always did.
class SiteDiveAggregate extends Equatable {
  final int diveCount;
  final DateTime? lastDivedAt;
  final DateTime? firstDivedAt;
  final double? maxDepthReached;
  final double? averageDepthReached;
  final int? longestDiveSeconds;
  final double? averageDurationSeconds;

  const SiteDiveAggregate({
    required this.diveCount,
    this.lastDivedAt,
    this.firstDivedAt,
    this.maxDepthReached,
    this.averageDepthReached,
    this.longestDiveSeconds,
    this.averageDurationSeconds,
  });

  @override
  List<Object?> get props => [
    diveCount,
    lastDivedAt,
    firstDivedAt,
    maxDepthReached,
    averageDepthReached,
    longestDiveSeconds,
    averageDurationSeconds,
  ];
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
  final DateTime? firstDivedAt;
  final double? maxDepthReached;
  final double? averageDepthReached;
  final int? longestDiveSeconds;
  final double? averageDurationSeconds;
  final List<String> featureTypes;

  /// The site's types in the diver's chosen order (issue #1765).
  final List<SiteTypeEntity> siteTypes;

  /// The site's tags, by name (issue #1765).
  final List<Tag> tags;

  const SiteWithDiveCount({
    required this.site,
    required this.diveCount,
    this.lastDivedAt,
    this.firstDivedAt,
    this.maxDepthReached,
    this.averageDepthReached,
    this.longestDiveSeconds,
    this.averageDurationSeconds,
    this.featureTypes = const [],
    this.siteTypes = const [],
    this.tags = const [],
  });

  SiteWithDiveCount copyWith({
    DiveSite? site,
    int? diveCount,
    DateTime? lastDivedAt,
    DateTime? firstDivedAt,
    double? maxDepthReached,
    double? averageDepthReached,
    int? longestDiveSeconds,
    double? averageDurationSeconds,
    List<String>? featureTypes,
    List<SiteTypeEntity>? siteTypes,
    List<Tag>? tags,
  }) {
    return SiteWithDiveCount(
      site: site ?? this.site,
      diveCount: diveCount ?? this.diveCount,
      lastDivedAt: lastDivedAt ?? this.lastDivedAt,
      firstDivedAt: firstDivedAt ?? this.firstDivedAt,
      maxDepthReached: maxDepthReached ?? this.maxDepthReached,
      averageDepthReached: averageDepthReached ?? this.averageDepthReached,
      longestDiveSeconds: longestDiveSeconds ?? this.longestDiveSeconds,
      averageDurationSeconds:
          averageDurationSeconds ?? this.averageDurationSeconds,
      featureTypes: featureTypes ?? this.featureTypes,
      siteTypes: siteTypes ?? this.siteTypes,
      tags: tags ?? this.tags,
    );
  }

  @override
  List<Object?> get props => [
    site,
    diveCount,
    lastDivedAt,
    firstDivedAt,
    maxDepthReached,
    averageDepthReached,
    longestDiveSeconds,
    averageDurationSeconds,
    featureTypes,
    siteTypes,
    tags,
  ];
}
