import 'dart:async';

import 'package:clock/clock.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/domain/services/fill_forecast.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/scrubber_margin_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// The trip's fill forecast, or null for an unknown trip, an ended one or
/// one with no slots. Rebuilds when the trip, its slots, its dives (through
/// the slot states), its itinerary or the fill station change, and by
/// itself at the fill deadline and at midnight (one timer).
final tripFillForecastProvider = FutureProvider.family<FillForecast?, String>((
  ref,
  tripId,
) async {
  final trip = await ref.watch(tripByIdProvider(tripId).future);
  if (trip == null) return null;
  final states = await ref.watch(tripCylinderStatesProvider(tripId).future);
  final itinerary = await ref.watch(itineraryDaysProvider(tripId).future);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  final now = clock.now();
  final history = await ref
      .watch(tripHistoryRepositoryProvider)
      .divesPerDiveDay(diverId: diverId, before: trip.startDate);
  final logged = await ref
      .watch(tripCylinderRepositoryProvider)
      .countTripDivesOn(tripId, now);
  final centerId = lastTripFillCenter(states);
  final center = centerId == null
      ? null
      : await ref.watch(diveCenterByIdProvider(centerId).future);
  final counts = tripCylinderCounts(states);
  final forecast = computeFillForecast(
    FillForecastInputs(
      now: now,
      tripStart: trip.startDate,
      tripEnd: trip.endDate,
      slotCount: states.length,
      fullCount: counts.full,
      partialCount: counts.partial,
      itinerary: itinerary,
      divesPerDayTarget: trip.divesPerDayTarget,
      expectedDives: trip.expectedDives,
      divesPerDiveDayHistory: history,
      diversSharing: trip.diversSharingCylinders,
      divesLoggedToday: logged,
      fillOpensAt: center?.fillOpensAt,
      fillClosesAt: center?.fillClosesAt,
    ),
  );
  if (forecast != null) {
    final timer = Timer(
      fillForecastNextRefresh(now, forecast).difference(now),
      ref.invalidateSelf,
    );
    ref.onDispose(timer.cancel);
  }
  return forecast;
});
