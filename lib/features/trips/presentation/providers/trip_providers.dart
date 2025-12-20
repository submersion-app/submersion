import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../divers/presentation/providers/diver_providers.dart';
import '../../data/repositories/trip_repository.dart';
import '../../domain/entities/trip.dart';

/// Repository provider
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository();
});

/// All trips provider
final allTripsProvider = FutureProvider<List<Trip>>((ref) async {
  final repository = ref.watch(tripRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getAllTrips(diverId: validatedDiverId);
});

/// All trips with stats provider
final allTripsWithStatsProvider =
    FutureProvider<List<TripWithStats>>((ref) async {
  final repository = ref.watch(tripRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getAllTripsWithStats(diverId: validatedDiverId);
});

/// Single trip provider
final tripByIdProvider =
    FutureProvider.family<Trip?, String>((ref, id) async {
  final repository = ref.watch(tripRepositoryProvider);
  return repository.getTripById(id);
});

/// Trip with stats provider
final tripWithStatsProvider =
    FutureProvider.family<TripWithStats, String>((ref, tripId) async {
  final repository = ref.watch(tripRepositoryProvider);
  return repository.getTripWithStats(tripId);
});

/// Dives for a trip provider
final diveIdsForTripProvider =
    FutureProvider.family<List<String>, String>((ref, tripId) async {
  final repository = ref.watch(tripRepositoryProvider);
  return repository.getDiveIdsForTrip(tripId);
});

/// Trip search provider
final tripSearchProvider =
    FutureProvider.family<List<Trip>, String>((ref, query) async {
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  if (query.isEmpty) {
    return ref.watch(allTripsProvider).value ?? [];
  }
  final repository = ref.watch(tripRepositoryProvider);
  return repository.searchTrips(query, diverId: validatedDiverId);
});

/// Find trip for a specific date
final tripForDateProvider =
    FutureProvider.family<Trip?, DateTime>((ref, date) async {
  final repository = ref.watch(tripRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.findTripForDate(date, diverId: validatedDiverId);
});

/// Trip list notifier for mutations
class TripListNotifier extends StateNotifier<AsyncValue<List<TripWithStats>>> {
  final TripRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  TripListNotifier(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    _initializeAndLoad();

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadTrips();
  }

  Future<void> _loadTrips() async {
    state = const AsyncValue.loading();
    try {
      final trips = await _repository.getAllTripsWithStats(diverId: _validatedDiverId);
      state = AsyncValue.data(trips);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadTrips();
    _ref.invalidate(allTripsProvider);
    _ref.invalidate(allTripsWithStatsProvider);
  }

  Future<Trip> addTrip(Trip trip) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Ensure diverId is set on new trips
    final tripWithDiver = trip.diverId == null && validatedId != null
        ? trip.copyWith(diverId: validatedId)
        : trip;
    final newTrip = await _repository.createTrip(tripWithDiver);
    await refresh();
    return newTrip;
  }

  Future<void> updateTrip(Trip trip) async {
    await _repository.updateTrip(trip);
    await refresh();
    _ref.invalidate(tripByIdProvider(trip.id));
    _ref.invalidate(tripWithStatsProvider(trip.id));
  }

  Future<void> deleteTrip(String id) async {
    await _repository.deleteTrip(id);
    await refresh();
  }

  Future<void> assignDiveToTrip(String diveId, String tripId) async {
    await _repository.assignDiveToTrip(diveId, tripId);
    await refresh();
    _ref.invalidate(tripWithStatsProvider(tripId));
    _ref.invalidate(diveIdsForTripProvider(tripId));
  }

  Future<void> removeDiveFromTrip(String diveId, String tripId) async {
    await _repository.removeDiveFromTrip(diveId);
    await refresh();
    _ref.invalidate(tripWithStatsProvider(tripId));
    _ref.invalidate(diveIdsForTripProvider(tripId));
  }
}

final tripListNotifierProvider =
    StateNotifierProvider<TripListNotifier, AsyncValue<List<TripWithStats>>>(
        (ref) {
  final repository = ref.watch(tripRepositoryProvider);
  return TripListNotifier(repository, ref);
});
