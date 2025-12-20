import 'package:equatable/equatable.dart';

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
  final String notes;
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
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Duration of the trip in days
  int get durationDays => endDate.difference(startDate).inDays + 1;

  /// Check if this is a liveaboard trip
  bool get isLiveaboard => liveaboardName != null && liveaboardName!.isNotEmpty;

  /// Check if this is a resort-based trip
  bool get isResort => resortName != null && resortName!.isNotEmpty;

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

  Trip copyWith({
    String? id,
    String? diverId,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    Object? location = _undefined,
    Object? resortName = _undefined,
    Object? liveaboardName = _undefined,
    String? notes,
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
      resortName: resortName == _undefined ? this.resortName : resortName as String?,
      liveaboardName: liveaboardName == _undefined ? this.liveaboardName : liveaboardName as String?,
      notes: notes ?? this.notes,
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
        notes,
        createdAt,
        updatedAt,
      ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();

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
