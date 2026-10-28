import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/trips/data/repositories/side_trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

final sideTripRepositoryProvider = Provider<SideTripRepository>(
  (ref) => SideTripRepository(),
);

/// The side trips of a trip the active profile can see, earliest first
/// (issue #3658).
final sideTripsProvider = FutureProvider.family<List<Trip>, String>((
  ref,
  tripId,
) async {
  final repository = ref.watch(sideTripRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  ref.invalidateSelfWhen(repository.watchChanges());
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
  ref.invalidateSelfWhen(repository.watchChanges());
  return repository.getParentTrip(tripId, diverId: diverId);
});

/// Whether any profile's trip is a side trip of a trip: one that has side
/// trips cannot become one itself, whoever owns them (issue #3658). Not
/// scoped to the active profile, so reading it resolves no profile.
final hasSideTripsProvider = FutureProvider.family<bool, String>((
  ref,
  tripId,
) async {
  final repository = ref.watch(sideTripRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchChanges());
  return (await repository.getSideTrips(tripId)).isNotEmpty;
});
