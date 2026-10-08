import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';

/// The most dives a diver can plan on one day: the cylinder planning board's
/// stepper stops here, and the day sheet refuses more (#2876).
const int kMaxPlannedDivesPerDay = 12;

/// A single day in a trip itinerary
class ItineraryDay extends Equatable {
  final String id;
  final String tripId;

  /// As stored, the day's number from the trip's start when the row was
  /// written; a later move of the start leaves it stale (#2664). Display
  /// numbers come from numberItineraryDays, which derives them from [date].
  final int dayNumber;
  final DateTime date;
  final DayType dayType;
  final String? portName;
  final double? latitude;
  final double? longitude;
  final String notes;

  /// Planned dives on this day for the fill forecast (v249). Null derives
  /// it; an explicit 0 is a rest day.
  final int? plannedDives;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ItineraryDay({
    required this.id,
    required this.tripId,
    required this.dayNumber,
    required this.date,
    required this.dayType,
    this.portName,
    this.latitude,
    this.longitude,
    this.notes = '',
    this.plannedDives,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Generate itinerary days for a trip date range. A liveaboard opens with
  /// Embark and closes with Disembark; every other type travels on its first
  /// and last day, with Dive days between. A land trip of one or two days has
  /// no middle to travel around, so it gets Dive days only.
  static List<ItineraryDay> generateForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    TripType tripType = TripType.liveaboard,
  }) {
    const uuid = Uuid();
    final now = DateTime.now();
    // Use calendar arithmetic to avoid DST issues
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final totalDays = (end.difference(start).inHours / 24).round() + 1;
    final liveaboard = tripType == TripType.liveaboard;
    final days = <ItineraryDay>[];

    for (int i = 0; i < totalDays; i++) {
      final first = i == 0;
      final last = i == totalDays - 1;
      final DayType type;
      if (liveaboard) {
        type = first
            ? DayType.embark
            : last
            ? DayType.disembark
            : DayType.diveDay;
      } else if (totalDays <= 2) {
        type = DayType.diveDay;
      } else {
        type = first || last ? DayType.travel : DayType.diveDay;
      }

      days.add(
        ItineraryDay(
          id: uuid.v4(),
          tripId: tripId,
          dayNumber: i + 1,
          date: DateTime(start.year, start.month, start.day + i),
          dayType: type,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return days;
  }

  ItineraryDay copyWith({
    String? id,
    String? tripId,
    int? dayNumber,
    DateTime? date,
    DayType? dayType,
    Object? portName = _undefined,
    Object? latitude = _undefined,
    Object? longitude = _undefined,
    String? notes,
    Object? plannedDives = _undefined,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItineraryDay(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      dayNumber: dayNumber ?? this.dayNumber,
      date: date ?? this.date,
      dayType: dayType ?? this.dayType,
      portName: portName == _undefined ? this.portName : portName as String?,
      latitude: latitude == _undefined ? this.latitude : latitude as double?,
      longitude: longitude == _undefined
          ? this.longitude
          : longitude as double?,
      notes: notes ?? this.notes,
      plannedDives: plannedDives == _undefined
          ? this.plannedDives
          : plannedDives as int?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripId,
    dayNumber,
    date,
    dayType,
    portName,
    latitude,
    longitude,
    notes,
    plannedDives,
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
