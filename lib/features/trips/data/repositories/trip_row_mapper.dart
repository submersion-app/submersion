import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart' as domain;

/// The domain trip for a Drift [row].
domain.Trip tripFromRow(Trip row) {
  return domain.Trip(
    id: row.id,
    diverId: row.diverId,
    name: row.name,
    startDate: DateTime.fromMillisecondsSinceEpoch(row.startDate),
    endDate: DateTime.fromMillisecondsSinceEpoch(row.endDate),
    location: row.location,
    resortName: row.resortName,
    liveaboardName: row.liveaboardName,
    notes: row.notes,
    tripType: TripType.fromName(row.tripType),
    isShared: row.isShared,
    // Wall-clock-as-UTC: decode with isUtc so the stored components are
    // preserved rather than shifted into the device's timezone.
    returnFlightAt: row.returnFlightAt != null
        ? DateTime.fromMillisecondsSinceEpoch(row.returnFlightAt!, isUtc: true)
        : null,
    expectedDives: row.expectedDives,
    expectedRuntimeMinutes: row.expectedRuntimeMinutes,
    diversSharingCylinders: row.diversSharingCylinders,
    divesPerDayTarget: row.divesPerDayTarget,
    parentTripId: row.parentTripId,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
  );
}

/// Shared mapper for customSelect rows (searchTrips, findTripForDate,
/// getAllTripsWithStats) so a new trips column cannot silently miss one
/// of the hand-written sites.
domain.Trip tripFromData(Map<String, Object?> data) {
  return domain.Trip(
    id: data['id'] as String,
    diverId: data['diver_id'] as String?,
    name: data['name'] as String,
    startDate: DateTime.fromMillisecondsSinceEpoch(data['start_date'] as int),
    endDate: DateTime.fromMillisecondsSinceEpoch(data['end_date'] as int),
    location: data['location'] as String?,
    resortName: data['resort_name'] as String?,
    liveaboardName: data['liveaboard_name'] as String?,
    notes: (data['notes'] as String?) ?? '',
    tripType: TripType.fromName((data['trip_type'] as String?) ?? 'shore'),
    isShared: (data['is_shared'] as int? ?? 0) != 0,
    // Wall-clock-as-UTC: decode with isUtc so the stored components are
    // preserved rather than shifted into the device's timezone.
    returnFlightAt: data['return_flight_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(
            data['return_flight_at'] as int,
            isUtc: true,
          )
        : null,
    expectedDives: data['expected_dives'] as int?,
    expectedRuntimeMinutes: data['expected_runtime_minutes'] as int?,
    diversSharingCylinders: (data['divers_sharing_cylinders'] as int?) ?? 1,
    divesPerDayTarget: data['dives_per_day_target'] as int?,
    parentTripId: data['parent_trip_id'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(data['updated_at'] as int),
  );
}
