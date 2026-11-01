import 'dart:async';

import 'package:clock/clock.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/providers/no_fly_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Forward-looking dive window for one trip's return flight, or null when
/// the trip has no flight set (or it already departed). Its times are true
/// UTC instants.
///
/// Category floor is repetitive: a trip is multi-day diving by definition,
/// so the single-dive interval would overstate the window. A deco dive in
/// the lookback escalates to the deco interval.
final tripFlightWindowProvider =
    FutureProvider.family<FlightWindowStatus?, String>((ref, tripId) async {
      final tripRepository = ref.watch(tripRepositoryProvider);
      ref.invalidateSelfWhen(tripRepository.watchTripsChanges());

      final trip = await tripRepository.getTripById(tripId);
      final flightAt = trip?.returnFlightAt;
      if (flightAt == null) return null;

      final diveRepository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(diveRepository.watchDivesChanges());

      final preset = ref.watch(settingsProvider.select((s) => s.noFlyPreset));
      final diverId = ref.watch(currentDiverIdProvider);

      // The flight is stored wall-clock-as-UTC. Read it in the device's zone
      // to get a real instant before taking a guideline interval off it, as
      // activeNoFlyStatus does for dive end times: interval arithmetic on
      // clock digits is an hour off across a DST change (issue #3926).
      final now = clock.now().toUtc();

      // Asked directly, not by watching noFlyStatusProvider: a dependency
      // change is a reload, which hides the card and banner on every dive
      // write, where the self-invalidation above is a refresh.
      final current = diverId == null
          ? null
          : await activeNoFlyStatus(
              diveRepository,
              diverId: diverId,
              preset: preset,
              now: now,
            );

      final category = current?.category == NoFlyCategory.deco
          ? NoFlyCategory.deco
          : NoFlyCategory.repetitive;
      final status = const NoFlyService().flightWindow(
        flightAt: fromWallClockUtc(flightAt).toUtc(),
        preset: preset,
        prospectiveCategory: category,
        currentNoFlyUntil: current?.until,
        now: now,
      );

      // State flips (open -> closed at the deadline, gone at departure)
      // happen without any table write; self-invalidate just past the next
      // boundary, mirroring noFlyStatusProvider's expiry timer.
      if (status != null) {
        final boundary = now.isBefore(status.deadline)
            ? status.deadline
            : status.flightAt;
        final untilBoundary = boundary.difference(now);
        if (untilBoundary > Duration.zero) {
          final timer = Timer(
            untilBoundary + const Duration(seconds: 1),
            ref.invalidateSelf,
          );
          ref.onDispose(timer.cancel);
        }
      }
      return status;
    });

/// Flight window for the trip containing today, or null. Feeds the
/// dashboard gauge and the No-Fly page.
final activeTripFlightWindowProvider = FutureProvider<FlightWindowStatus?>((
  ref,
) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final trip = await ref.watch(tripForDateProvider(today).future);
  if (trip == null || trip.returnFlightAt == null) return null;
  return ref.watch(tripFlightWindowProvider(trip.id).future);
});
