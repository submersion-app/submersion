import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/data/repositories/service_schedule_repository.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_exposure_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_history_repository.dart';
import 'package:submersion/features/trips/domain/entities/scrubber_margin.dart';
import 'package:submersion/features/trips/domain/services/scrubber_margin_service.dart';
import 'package:submersion/features/trips/presentation/providers/liveaboard_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

/// The built-in service kind whose newest record marks the last repack.
const scrubberRepackKindId = 'scrubber-repack';

/// The rebreather attribute carrying the rated scrubber duration in hours.
const scrubberDurationHoursKey = 'scrubber_duration_h';

final tripHistoryRepositoryProvider = Provider<TripHistoryRepository>(
  (ref) => TripHistoryRepository(),
);

/// One margin per active rebreather of the trip's diver, computed as of
/// the trip start: loop minutes since the newest repack record, the
/// diver's own overrides on the trip, and the medians of recent history
/// (see [computeScrubberMargin]). Empty for an unknown trip or a diver
/// with no active rebreather. A provider, never a stored finding.
final tripScrubberMarginsProvider =
    FutureProvider.family<List<ScrubberMargin>, String>((ref, tripId) async {
      final equipment = ref.watch(equipmentRepositoryProvider);
      final records = ref.watch(serviceRecordRepositoryProvider);
      final schedules = ref.watch(serviceScheduleRepositoryProvider);
      final trips = ref.watch(tripRepositoryProvider);
      final itinerary = ref.watch(itineraryDayRepositoryProvider);
      ref.invalidateSelfWhen(equipment.watchEquipmentChanges());
      // The rated duration is an attribute (scrubber_duration_h).
      ref.invalidateSelfWhen(equipment.watchAttributeChanges());
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchDiveDetailChanges(),
      );
      ref.invalidateSelfWhen(records.watchServiceRecordsChanges());
      ref.invalidateSelfWhen(schedules.watchSchedulesChanges());
      // The rated duration falls back to the repack KIND's interval, and
      // the built-ins are re-seeded on open and can arrive by sync, so a
      // stale kind would keep an old rating alive.
      ref.invalidateSelfWhen(
        ref.watch(serviceKindRepositoryProvider).watchServiceKindsChanges(),
      );
      ref.invalidateSelfWhen(trips.watchTripsChanges());
      ref.invalidateSelfWhen(itinerary.watchItineraryChanges());

      final trip = await ref.watch(tripByIdProvider(tripId).future);
      if (trip == null) return const [];
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      final rebreathers = (await equipment.getActiveEquipment(
        diverId: diverId,
      )).where((e) => e.type == EquipmentType.rebreather).toList();
      if (rebreathers.isEmpty) return const [];

      final start = trip.startDate;
      final kinds = await ref
          .watch(serviceKindRepositoryProvider)
          .getAllKinds();
      final repackKind = kinds
          .where((k) => k.id == scrubberRepackKindId)
          .firstOrNull;
      final days = await itinerary.getByTripId(trip.id);
      final diveDays = days.where((d) => d.dayType == DayType.diveDay).length;
      final history = ref.watch(tripHistoryRepositoryProvider);
      final divesPerDay = await history.divesPerDiveDay(
        diverId: diverId,
        before: start,
      );
      final loopFigures = await history.recentRebreatherFigures(
        diverId: diverId,
        before: start,
      );
      final summaries = ref.watch(diveSensorSummaryRepositoryProvider);

      final margins = <ScrubberMargin>[];
      for (final item in rebreathers) {
        final rated = await _ratedMinutes(item, repackKind, schedules);
        final itemRecords = await records.getRecordsForEquipment(item.id);
        final repack = itemRecords
            .where(
              (r) =>
                  r.serviceKindId == scrubberRepackKindId &&
                  // Inclusive: service dates come from a date picker, so
                  // a repack logged on the day the trip starts is the last
                  // one as of that start, not one that happened after it.
                  !r.serviceDate.isAfter(start),
            )
            .firstOrNull;
        final inputs = await ref.watch(
          equipmentExposureInputsProvider(item.id).future,
        );
        // By calendar day: dives are wall clock in UTC, the trip and
        // service dates local midnights.
        final diveStart = asDiveWallClockDate(start);
        final repackFrom = repack == null
            ? null
            : asDiveWallClockDate(repack.serviceDate);
        final loopDives = [
          for (final s in inputs?.samples ?? const [])
            if ((s.diveMode == DiveMode.ccr || s.diveMode == DiveMode.scr) &&
                s.date.isBefore(diveStart) &&
                (repackFrom == null || !s.date.isBefore(repackFrom)))
              s,
        ];
        final byDive = await summaries.getSummaries([
          for (final s in loopDives) s.diveId,
        ]);
        var consumed = 0.0;
        for (final s in loopDives) {
          consumed +=
              byDive[s.diveId]?.scrubberConsumedMinutes ??
              s.durationSeconds / 60.0;
        }
        margins.add(
          computeScrubberMargin(
            ScrubberMarginInputs(
              item: item,
              ratedMinutes: rated,
              consumedMinutes: consumed,
              expectedDivesOverride: trip.expectedDives,
              // Only a missing itinerary falls back to the calendar: one
              // with no dive days (a crossing, a port stay) expects none.
              itineraryDiveDays: days.isEmpty ? trip.durationDays : diveDays,
              divesPerDiveDayHistory: divesPerDay,
              runtimeMinutesOverride: trip.expectedRuntimeMinutes,
              scrubberMinutesHistory: [
                for (final f in loopFigures) ?f.scrubberMinutes,
              ],
              rebreatherRuntimeMinutesHistory: [
                for (final f in loopFigures) ?f.runtimeMinutes,
              ],
            ),
          ),
        );
      }
      return margins;
    });

/// `scrubber_duration_h` times 60, else the repack schedule's hours
/// interval times 60, else null.
Future<double?> _ratedMinutes(
  EquipmentItem item,
  ServiceKind? repackKind,
  ServiceScheduleRepository schedules,
) async {
  final hours = item.attrNum(scrubberDurationHoursKey);
  if (hours != null && hours > 0) return hours * 60;
  if (repackKind == null) return null;
  final list = await schedules.getSchedulesForEquipment(item.id);
  for (final schedule in list) {
    if (schedule.serviceKindId != scrubberRepackKindId) continue;
    // A paused clock is off for the clocks engine; it rates nothing here.
    if (!schedule.enabled) continue;
    final interval = schedule.intervalFor(ExposureUnit.hours, repackKind);
    if (interval != null && interval > 0) return interval * 60;
  }
  return null;
}
