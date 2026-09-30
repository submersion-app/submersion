import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';
import 'package:submersion/features/trips/domain/services/trip_gas_record_builder.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';

/// The trip's gas record (spec "Phase 3 gas record"). Rebuilds when the
/// trip's slots, fills, dives, tanks or sites change, and when the diver's
/// gas model or default currency does. Auto-disposed: only the Record tab
/// reads it.
final tripGasRecordProvider = FutureProvider.autoDispose
    .family<TripGasRecord, String>((ref, tripId) async {
      final repository = ref.watch(tripCylinderRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripCylinderChanges());
      final gasModel = ref.watch(gasModelProvider);
      final currency = ref.watch(defaultCurrencyProvider);
      final (cylinders, events, tanks, unlinked) = await (
        repository.getCylindersForTrip(tripId),
        repository.getEventsForTrip(tripId),
        repository.getGasRecordTanksForTrip(tripId),
        repository.getUnlinkedTanksForTrip(tripId),
      ).wait;
      return buildTripGasRecord(
        cylinders: cylinders,
        eventsBySlot: events,
        tanks: tanks,
        unlinked: unlinked,
        gasModel: gasModel,
        defaultCurrency: currency,
      );
    });
