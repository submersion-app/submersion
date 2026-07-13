import 'package:equatable/equatable.dart';
import 'package:submersion/core/constants/enums.dart';

/// Dive trip entity - represents a group of dives at a destination
class Trip extends Equatable {
  final String id;
  final String? diverId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String? location;
  final String? resortName;
  final String? liveaboardName;
  final TripType tripType;
  final String notes;
  final bool isShared;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Trip({
    required this.id,
    this.diverId,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.location,
    this.resortName,
    this.liveaboardName,
    this.tripType = TripType.shore,
    this.notes = '',
    this.isShared = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Duration of the trip in days.
  ///
  /// Counted in calendar days (UTC date-only) so a trip spanning a local DST
  /// spring-forward isn't undercounted: `Duration.inDays` floors elapsed hours,
  /// and a 23-hour calendar day would otherwise drop a day (e.g. Mar 7-10 is
  /// 71 local hours -> 3 instead of 4).
  int get durationDays => _calendarDaysBetween(startDate, endDate) + 1;

  /// Check if this is a liveaboard trip
  bool get isLiveaboard => tripType == TripType.liveaboard;

  /// Check if this is a resort-based trip
  bool get isResort => tripType == TripType.resort;

  /// Get display subtitle (resort, liveaboard, or location)
  String? get subtitle {
    if (isLiveaboard) return liveaboardName;
    if (isResort) return resortName;
    return location;
  }

  /// Check if a date falls within this trip
  bool containsDate(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !dateOnly.isBefore(start) && !dateOnly.isAfter(end);
  }

  /// Whether this trip is upcoming or currently underway (date-only
  /// comparison, same normalization as [containsDate]).
  bool get isUpcoming {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !end.isBefore(today);
  }

  /// Whether the trip has started but not yet ended (date-only).
  bool get isInProgress {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !start.isAfter(today) && !end.isBefore(today);
  }

  /// Calendar days until the trip starts (0 when started or starting today).
  ///
  /// Counted in UTC date-only so a DST spring-forward between today and the
  /// start date can't shave a day off the countdown (a local 23-hour day would
  /// make `Duration.inDays` truncate 47 hours to 1 day instead of 2).
  int get daysUntilStart {
    final diff = _calendarDaysBetween(DateTime.now(), startDate);
    return diff < 0 ? 0 : diff;
  }

  Trip copyWith({
    String? id,
    String? diverId,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    Object? location = _undefined,
    Object? resortName = _undefined,
    Object? liveaboardName = _undefined,
    TripType? tripType,
    String? notes,
    bool? isShared,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      diverId: diverId ?? this.diverId,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location == _undefined ? this.location : location as String?,
      resortName: resortName == _undefined
          ? this.resortName
          : resortName as String?,
      liveaboardName: liveaboardName == _undefined
          ? this.liveaboardName
          : liveaboardName as String?,
      tripType: tripType ?? this.tripType,
      notes: notes ?? this.notes,
      isShared: isShared ?? this.isShared,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    diverId,
    name,
    startDate,
    endDate,
    location,
    resortName,
    liveaboardName,
    tripType,
    notes,
    isShared,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();

/// Whole calendar days from [from] to [to], computed in UTC date-only so the
/// result is DST-immune (UTC has no daylight-saving transitions, so every day
/// is exactly 24 hours). Negative when [to] is before [from].
int _calendarDaysBetween(DateTime from, DateTime to) {
  final a = DateTime.utc(from.year, from.month, from.day);
  final b = DateTime.utc(to.year, to.month, to.day);
  return b.difference(a).inDays;
}

/// Trip with computed statistics
class TripWithStats extends Equatable {
  final Trip trip;
  final int diveCount;
  final int totalBottomTime; // seconds
  final double? maxDepth;
  final double? avgDepth;

  const TripWithStats({
    required this.trip,
    this.diveCount = 0,
    this.totalBottomTime = 0,
    this.maxDepth,
    this.avgDepth,
  });

  /// Total bottom time formatted as hours:minutes
  String get formattedBottomTime {
    final hours = totalBottomTime ~/ 3600;
    final minutes = (totalBottomTime % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  @override
  List<Object?> get props => [
    trip,
    diveCount,
    totalBottomTime,
    maxDepth,
    avgDepth,
  ];
}
