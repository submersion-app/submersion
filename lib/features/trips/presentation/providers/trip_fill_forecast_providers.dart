import 'dart:async';

import 'package:clock/clock.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/trips/domain/entities/itinerary_day.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/fill_forecast.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_display.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// The trip's fill forecast, or null for an unknown trip, an ended one or
/// one with no slots. Rebuilds when the trip, its slots, its dives (through
/// the slot states), its itinerary or the fill station change, and by
/// itself at the fill deadline and at midnight (one timer). Auto-disposed:
/// a trip no longer on screen keeps no timer and no table subscriptions.
final tripFillForecastProvider = FutureProvider.autoDispose
    .family<FillForecast?, String>((ref, tripId) async {
      // Today's count reads the dives table directly, outside the providers
      // watched below.
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDivesChanges(),
      );
      final trip = await ref.watch(tripByIdProvider(tripId).future);
      // An unknown or ended trip has no forecast: skip every query below.
      if (trip == null || trip.endsBefore(clock.now())) return null;
      final states = await ref.watch(tripCylinderStatesProvider(tripId).future);
      if (states.isEmpty) return null;
      final itinerary = await ref.watch(itineraryDaysProvider(tripId).future);
      final now = clock.now();
      final logged = await ref
          .watch(tripCylinderRepositoryProvider)
          .countTripDiveRoundsOn(tripId, now);
      final centerId = lastTripFillCenter(states);
      final center = centerId == null
          ? null
          : await ref.watch(diveCenterByIdProvider(centerId).future);
      final forecast = tripFillForecastOf(
        trip: trip,
        states: states,
        itinerary: itinerary,
        loggedToday: logged,
        center: center,
        now: now,
      );
      // A build invalidated during an await above is already disposed: no
      // timer for it. The tick goes through invalidateSelfWhen, so a paused
      // provider refreshes on resume rather than being invalidated mid-pause.
      if (forecast != null && ref.mounted) {
        final tick = StreamController<void>();
        final timer = Timer(
          fillForecastNextRefresh(now, forecast).difference(now),
          () => tick.add(null),
        );
        ref.onDispose(() {
          timer.cancel();
          tick.close();
        });
        ref.invalidateSelfWhen(tick.stream);
      }
      return forecast;
    });

/// The fill forecast of [trip] with [states] on its board and [itinerary]
/// as its days, [loggedToday] dive rounds logged today and [center] the
/// station of the trip's last fill: what [tripFillForecastProvider] works
/// out, and what a trip's editing sitting works out from what it holds
/// (issue #4527).
FillForecast? tripFillForecastOf({
  required Trip trip,
  required List<TripCylinderState> states,
  required List<ItineraryDay> itinerary,
  required int loggedToday,
  required DiveCenter? center,
  required DateTime now,
}) {
  final counts = tripCylinderCounts(states);
  return computeFillForecast(
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
      diversSharing: trip.diversSharingCylinders,
      divesLoggedToday: loggedToday,
      fillOpensAt: center?.fillOpensAt,
      fillClosesAt: center?.fillClosesAt,
    ),
  );
}

/// The dive rounds of a trip logged on [day] (its calendar day), for a
/// forecast worked out from a sitting: keyed by the day, so asking on the
/// next day reads the next day's count. Refreshes when dives change.
final tripDiveRoundsOnProvider = FutureProvider.autoDispose
    .family<int, ({String tripId, DateTime day})>((ref, key) async {
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDivesChanges(),
      );
      return ref
          .watch(tripCylinderRepositoryProvider)
          .countTripDiveRoundsOn(key.tripId, key.day);
    });
