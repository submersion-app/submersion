import 'dart:async';

import 'package:clock/clock.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
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
/// itself at the fill deadline and at midnight (one timer). Auto-disposed:
/// a trip no longer on screen keeps no timer and no table subscriptions.
final tripFillForecastProvider = FutureProvider.autoDispose
    .family<FillForecast?, String>((ref, tripId) async {
      // The history and today's count read the dives and past trips tables
      // directly, outside the providers watched below.
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDivesChanges(),
      );
      ref.invalidateSelfWhen(
        ref.watch(tripRepositoryProvider).watchTripsChanges(),
      );
      final trip = await ref.watch(tripByIdProvider(tripId).future);
      // An unknown or ended trip has no forecast: skip every query below.
      if (trip == null || trip.endsBefore(clock.now())) return null;
      final states = await ref.watch(tripCylinderStatesProvider(tripId).future);
      if (states.isEmpty) return null;
      final itinerary = await ref.watch(itineraryDaysProvider(tripId).future);
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final now = clock.now();
      final history = await ref
          .watch(tripHistoryRepositoryProvider)
          .divesPerDiveDay(diverId: diverId, before: trip.startDate);
      final logged = await ref
          .watch(tripCylinderRepositoryProvider)
          .countTripDiveRoundsOn(tripId, now);
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
