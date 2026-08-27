import 'dart:async';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// Forward-looking dive window for one trip's return flight, or null when
/// the trip has no flight set (or it already departed).
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

      final now = NoFlyService.wallClockNowUtc();
      const service = NoFlyService();

      NoFlyStatus? current;
      if (diverId != null) {
        final dives = await diveRepository.getNoFlyDiveInputs(
          since: now.subtract(NoFlyService.lookback),
          diverId: diverId,
        );
        current = service.evaluate(dives: dives, preset: preset, now: now);
      }

      final category = current?.category == NoFlyCategory.deco
          ? NoFlyCategory.deco
          : NoFlyCategory.repetitive;
      final status = service.flightWindow(
        flightAt: flightAt,
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
