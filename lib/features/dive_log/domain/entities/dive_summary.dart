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
  final DateTime dateTime;
  final DateTime? entryTime;
  final double? maxDepth;
  final Duration? duration;
  final double? waterTemp;
  final int? rating;
  final bool isFavorite;
  final String diveTypeId;
  final double? otu;
  final double? maxPpO2;
  final List<Tag> tags;

  // Site fields (from LEFT JOIN, avoids loading full DiveSite object)
  final String? siteName;
  final String? siteCountry;
  final String? siteRegion;
  final double? siteLatitude;
  final double? siteLongitude;

  // Cursor field for pagination: COALESCE(entry_time, dive_date_time)
  final int sortTimestamp;

  const DiveSummary({
    required this.id,
    this.diveNumber,
    required this.dateTime,
    this.entryTime,
    this.maxDepth,
    this.duration,
    this.waterTemp,
    this.rating,
    this.isFavorite = false,
    this.diveTypeId = 'recreational',
    this.otu,
    this.maxPpO2,
    this.tags = const [],
    this.siteName,
    this.siteCountry,
    this.siteRegion,
    this.siteLatitude,
    this.siteLongitude,
    required this.sortTimestamp,
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
      dateTime: dive.dateTime,
      entryTime: dive.entryTime,
      maxDepth: dive.maxDepth,
      duration: dive.duration,
      waterTemp: dive.waterTemp,
      rating: dive.rating,
      isFavorite: dive.isFavorite,
      diveTypeId: dive.diveTypeId,
      // otu and maxPpO2 are computed from dive_profiles in the paginated query;
      // they are not available on the Dive entity, so card coloring will be
      // absent during optimistic UI updates until the next database refresh.
      otu: null,
      maxPpO2: null,
      tags: dive.tags,
      siteName: dive.site?.name,
      siteCountry: dive.site?.country,
      siteRegion: dive.site?.region,
      siteLatitude: dive.site?.location?.latitude,
      siteLongitude: dive.site?.location?.longitude,
      sortTimestamp: ts.millisecondsSinceEpoch,
    );
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

  DiveSummary copyWith({
    String? id,
    int? diveNumber,
    DateTime? dateTime,
    DateTime? entryTime,
    double? maxDepth,
    Duration? duration,
    double? waterTemp,
    int? rating,
    bool? isFavorite,
    String? diveTypeId,
    double? otu,
    double? maxPpO2,
    List<Tag>? tags,
    String? siteName,
    String? siteCountry,
    String? siteRegion,
    double? siteLatitude,
    double? siteLongitude,
    int? sortTimestamp,
  }) {
    return DiveSummary(
      id: id ?? this.id,
      diveNumber: diveNumber ?? this.diveNumber,
      dateTime: dateTime ?? this.dateTime,
      entryTime: entryTime ?? this.entryTime,
      maxDepth: maxDepth ?? this.maxDepth,
      duration: duration ?? this.duration,
      waterTemp: waterTemp ?? this.waterTemp,
      rating: rating ?? this.rating,
      isFavorite: isFavorite ?? this.isFavorite,
      diveTypeId: diveTypeId ?? this.diveTypeId,
      otu: otu ?? this.otu,
      maxPpO2: maxPpO2 ?? this.maxPpO2,
      tags: tags ?? this.tags,
      siteName: siteName ?? this.siteName,
      siteCountry: siteCountry ?? this.siteCountry,
      siteRegion: siteRegion ?? this.siteRegion,
      siteLatitude: siteLatitude ?? this.siteLatitude,
      siteLongitude: siteLongitude ?? this.siteLongitude,
      sortTimestamp: sortTimestamp ?? this.sortTimestamp,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diveNumber,
    dateTime,
    entryTime,
    maxDepth,
    duration,
    waterTemp,
    rating,
    isFavorite,
    diveTypeId,
    otu,
    maxPpO2,
    tags,
    siteName,
    siteCountry,
    siteRegion,
    siteLatitude,
    siteLongitude,
    sortTimestamp,
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
