import 'package:equatable/equatable.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// Lightweight dive entity optimized for list display.
///
/// Contains only the fields needed by DiveListTile, avoiding the overhead
/// of loading full DiveSite, DiveCenter, Trip, tanks, equipment, and profile
/// objects. Used with paginated queries to support 5000+ dives efficiently.
class DiveSummary extends Equatable {
  final String id;
  final int? diveNumber;
  final String? name;
  final DateTime dateTime;
  final DateTime? entryTime;
  final double? maxDepth;
  final Duration? bottomTime;
  final Duration? runtime;
  final double? waterTemp;
  final int? rating;
  final bool isFavorite;
  final List<String> diveTypeIds;
  final List<Tag> tags;

  // Site fields (from LEFT JOIN, avoids loading full DiveSite object)
  final String? siteName;
  final String? siteCountry;
  final String? siteRegion;
  final double? siteLatitude;
  final double? siteLongitude;

  // Cursor field for pagination: COALESCE(entry_time, dive_date_time)
  final int sortTimestamp;

  /// Count of non-dismissed safety review findings (drives the quiet
  /// list badge). Zero when unanalyzed or clean.
  final int safetyFindingCount;

  const DiveSummary({
    required this.id,
    this.diveNumber,
    this.name,
    required this.dateTime,
    this.entryTime,
    this.maxDepth,
    this.bottomTime,
    this.runtime,
    this.waterTemp,
    this.rating,
    this.isFavorite = false,
    this.diveTypeIds = const ['recreational'],
    this.tags = const [],
    this.siteName,
    this.siteCountry,
    this.siteRegion,
    this.siteLatitude,
    this.siteLongitude,
    required this.sortTimestamp,
    this.safetyFindingCount = 0,
  });

  /// Creates a DiveSummary from a full Dive entity.
  ///
  /// Used for optimistic UI updates — when a mutation returns a full Dive,
  /// we convert it to a DiveSummary to update the paginated list in-memory
  /// without reloading from the database.
  factory DiveSummary.fromDive(Dive dive) {
    final ts = dive.entryTime ?? dive.dateTime;
    return DiveSummary(
      id: dive.id,
      diveNumber: dive.diveNumber,
      name: dive.name,
      dateTime: dive.dateTime,
      entryTime: dive.entryTime,
      maxDepth: dive.maxDepth,
      bottomTime: dive.bottomTime,
      runtime: dive.runtime,
      waterTemp: dive.waterTemp,
      rating: dive.rating,
      isFavorite: dive.isFavorite,
      diveTypeIds: dive.diveTypeIds,
      tags: dive.tags,
      siteName: dive.site?.name,
      siteCountry: dive.site?.country,
      siteRegion: dive.site?.region,
      siteLatitude: dive.site?.location?.latitude,
      siteLongitude: dive.site?.location?.longitude,
      sortTimestamp: ts.millisecondsSinceEpoch,
      // Optimistic conversions can't know the count; the next DB read
      // corrects it.
      safetyFindingCount: 0,
    );
  }

  /// User-defined name, normalized for display: trimmed, with empty or
  /// whitespace-only values treated as unset (null). Mirrors
  /// [Dive.effectiveName].
  String? get effectiveName {
    final trimmed = name?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Formatted location string matching DiveSite.locationString
  String? get siteLocation {
    final parts = <String>[];
    if (siteRegion != null && siteRegion!.isNotEmpty) {
      parts.add(siteRegion!);
    }
    if (siteCountry != null && siteCountry!.isNotEmpty) {
      parts.add(siteCountry!);
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Representative (first) dive type slug. Always present (>= 1 invariant).
  String get diveTypeId =>
      diveTypeIds.isEmpty ? 'recreational' : diveTypeIds.first;

  DiveSummary copyWith({
    String? id,
    int? diveNumber,
    String? name,
    DateTime? dateTime,
    DateTime? entryTime,
    double? maxDepth,
    Duration? bottomTime,
    Duration? runtime,
    double? waterTemp,
    int? rating,
    bool? isFavorite,
    List<String>? diveTypeIds,
    List<Tag>? tags,
    String? siteName,
    String? siteCountry,
    String? siteRegion,
    double? siteLatitude,
    double? siteLongitude,
    int? sortTimestamp,
    int? safetyFindingCount,
  }) {
    return DiveSummary(
      id: id ?? this.id,
      diveNumber: diveNumber ?? this.diveNumber,
      name: name ?? this.name,
      dateTime: dateTime ?? this.dateTime,
      entryTime: entryTime ?? this.entryTime,
      maxDepth: maxDepth ?? this.maxDepth,
      bottomTime: bottomTime ?? this.bottomTime,
      runtime: runtime ?? this.runtime,
      waterTemp: waterTemp ?? this.waterTemp,
      rating: rating ?? this.rating,
      isFavorite: isFavorite ?? this.isFavorite,
      diveTypeIds: diveTypeIds ?? this.diveTypeIds,
      tags: tags ?? this.tags,
      siteName: siteName ?? this.siteName,
      siteCountry: siteCountry ?? this.siteCountry,
      siteRegion: siteRegion ?? this.siteRegion,
      siteLatitude: siteLatitude ?? this.siteLatitude,
      siteLongitude: siteLongitude ?? this.siteLongitude,
      sortTimestamp: sortTimestamp ?? this.sortTimestamp,
      safetyFindingCount: safetyFindingCount ?? this.safetyFindingCount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveNumber,
    name,
    dateTime,
    entryTime,
    maxDepth,
    bottomTime,
    runtime,
    waterTemp,
    rating,
    isFavorite,
    diveTypeIds,
    tags,
    siteName,
    siteCountry,
    siteRegion,
    siteLatitude,
    siteLongitude,
    sortTimestamp,
    safetyFindingCount,
  ];
}

/// Cursor for paginated dive queries.
///
/// Uses a triple of (sortTimestamp, diveNumber, id) to uniquely identify
/// the position in the sorted result set. This is more robust than offset-based
/// pagination since it handles insertions/deletions between pages.
class DiveSummaryCursor extends Equatable {
  final int sortTimestamp;
  final int diveNumber;
  final String id;

  const DiveSummaryCursor({
    required this.sortTimestamp,
    required this.diveNumber,
    required this.id,
  });

  @override
  List<Object?> get props => [sortTimestamp, diveNumber, id];
}

/// State for the paginated dive list.
class PaginatedDiveListState extends Equatable {
  final List<DiveSummary> dives;
  final bool isLoadingMore;
  final bool hasMore;
  final DiveSummaryCursor? nextCursor;
  final int totalCount;

  const PaginatedDiveListState({
    this.dives = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
    this.nextCursor,
    this.totalCount = 0,
  });

  PaginatedDiveListState copyWith({
    List<DiveSummary>? dives,
    bool? isLoadingMore,
    bool? hasMore,
    DiveSummaryCursor? nextCursor,
    int? totalCount,
    bool clearNextCursor = false,
  }) {
    return PaginatedDiveListState(
      dives: dives ?? this.dives,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: clearNextCursor ? null : (nextCursor ?? this.nextCursor),
      totalCount: totalCount ?? this.totalCount,
    );
  }

  @override
  List<Object?> get props => [
    dives,
    isLoadingMore,
    hasMore,
    nextCursor,
    totalCount,
  ];
}
