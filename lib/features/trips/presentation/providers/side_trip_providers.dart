import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/data/repositories/side_trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';

final sideTripRepositoryProvider = Provider<SideTripRepository>(
  (ref) => SideTripRepository(),
);

/// The trips table, hides and shares changing: what every side-trip read
/// depends on.
Stream<void> _tripsChanges(Ref ref) =>
    ref.read(tripRepositoryProvider).watchTripsChanges();

/// The side trips of a trip the active profile can see, earliest first
/// (issue #3658).
final sideTripsProvider = FutureProvider.family<List<Trip>, String>((
  ref,
  tripId,
) async {
  final repository = ref.watch(sideTripRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(_tripsChanges(ref));
  return repository.getSideTrips(tripId, diverId: diverId);
});

/// The larger trip a trip is a side trip of, when the active profile can see
/// it; null for a trip of its own (issue #3658).
final parentTripProvider = FutureProvider.family<Trip?, String>((
  ref,
  tripId,
) async {
  final repository = ref.watch(sideTripRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(_tripsChanges(ref));
  return repository.getParentTrip(tripId, diverId: diverId);
});

/// A trip when the active profile can see it, else null: what the trip form
/// may name as a larger trip (issue #3658).
final visibleTripProvider = FutureProvider.family<Trip?, String>((
  ref,
  tripId,
) async {
  final repository = ref.watch(sideTripRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(_tripsChanges(ref));
  return repository.getVisibleTrip(tripId, diverId: diverId);
});

/// Whether any profile's trip is a side trip of a trip: one that has side
/// trips cannot become one itself, whoever owns them (issue #3658). Not
/// scoped to the active profile, so reading it resolves no profile.
final hasSideTripsProvider = FutureProvider.family<bool, String>((
  ref,
  tripId,
) async {
  final repository = ref.watch(sideTripRepositoryProvider);
  ref.invalidateSelfWhen(_tripsChanges(ref));
  return repository.hasSideTrips(tripId);
});
