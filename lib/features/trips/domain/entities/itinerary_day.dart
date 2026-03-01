import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';

/// A single day in a trip itinerary
class ItineraryDay extends Equatable {
  final String id;
  final String tripId;
  final int dayNumber;
  final DateTime date;
  final DayType dayType;
  final String? portName;
  final double? latitude;
  final double? longitude;
  final String notes;
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
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  /// Generate itinerary days for a trip date range.
  /// Day 1 = embark, last day = disembark, middle days = diveDay.
  static List<ItineraryDay> generateForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    const uuid = Uuid();
    final now = DateTime.now();
    // Use calendar arithmetic to avoid DST issues
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final totalDays = (end.difference(start).inHours / 24).round() + 1;
    final days = <ItineraryDay>[];

    for (int i = 0; i < totalDays; i++) {
      final DayType type;
      if (i == 0) {
        type = DayType.embark;
      } else if (i == totalDays - 1) {
        type = DayType.disembark;
      } else {
        type = DayType.diveDay;
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
    createdAt,
    updatedAt,
  ];
}

// Sentinel value for distinguishing null from undefined in copyWith
const _undefined = Object();
