import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/trips/data/repositories/trip_cylinder_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';

final tripCylinderRepositoryProvider = Provider<TripCylinderRepository>(
  (ref) => TripCylinderRepository(),
);

/// The slots of a trip in board order.
final tripCylindersProvider = FutureProvider.family<List<TripCylinder>, String>(
  (ref, tripId) async {
    final repository = ref.watch(tripCylinderRepositoryProvider);
    ref.invalidateSelfWhen(repository.watchTripCylinderChanges());
    return repository.getCylindersForTrip(tripId);
  },
);

/// Every slot of a trip with its derived state: the ledger and the linked
/// tanks folded by [foldCylinderState]. Two lean queries beyond the slots
/// themselves; no dive is hydrated. Refreshes on any write to the slots,
/// their ledger, dive tanks or dives.
final tripCylinderStatesProvider =
    FutureProvider.family<List<TripCylinderState>, String>((ref, tripId) async {
      final repository = ref.watch(tripCylinderRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchTripCylinderChanges());

      final cylinders = await repository.getCylindersForTrip(tripId);
      if (cylinders.isEmpty) return const [];
      final events = await repository.getEventsForTrip(tripId);
      final uses = await repository.getTankUsesForTrip(tripId);
      return [
        for (final cylinder in cylinders)
          foldCylinderState(
            cylinder: cylinder,
            events: events[cylinder.id] ?? const [],
            uses: uses[cylinder.id] ?? const [],
          ),
      ];
    });
