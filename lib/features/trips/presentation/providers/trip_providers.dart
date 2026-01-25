import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// Filter state for trip list
class TripFilterState {
  final String? equipmentId;

  const TripFilterState({this.equipmentId});

  bool get hasActiveFilters => equipmentId != null;

  TripFilterState copyWith({
    String? equipmentId,
    bool clearEquipmentId = false,
  }) {
    return TripFilterState(
      equipmentId: clearEquipmentId ? null : (equipmentId ?? this.equipmentId),
    );
  }
}

/// Trip filter state provider
final tripFilterProvider = StateProvider<TripFilterState>(
  (ref) => const TripFilterState(),
);

/// Repository provider
final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository();
});

/// All trips provider
final allTripsProvider = FutureProvider<List<Trip>>((ref) async {
  final repository = ref.watch(tripRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getAllTrips(diverId: validatedDiverId);
});

/// All trips with stats provider
final allTripsWithStatsProvider = FutureProvider<List<TripWithStats>>((
  ref,
) async {
  final repository = ref.watch(tripRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getAllTripsWithStats(diverId: validatedDiverId);
});

/// Filtered trips provider - applies current filter to trip list
final filteredTripsProvider = FutureProvider<List<TripWithStats>>((ref) async {
  final filter = ref.watch(tripFilterProvider);
  final tripsAsync = ref.watch(tripListNotifierProvider);

  final trips = tripsAsync.valueOrNull ?? [];

  if (!filter.hasActiveFilters) {
    return trips;
  }

  // If filtering by equipment, get trip IDs that used this equipment
  if (filter.equipmentId != null) {
    final equipmentRepository = EquipmentRepository();
    final tripIds = await equipmentRepository.getTripIdsForEquipment(
      filter.equipmentId!,
    );
    final tripIdSet = tripIds.toSet();
    return trips.where((t) => tripIdSet.contains(t.trip.id)).toList();
  }

  return trips;
});

/// Trip sort state provider
final tripSortProvider = StateProvider<SortState<TripSortField>>(
  (ref) => const SortState(
    field: TripSortField.startDate,
    direction: SortDirection.descending,
  ),
);

/// Sorted and filtered trips provider
final sortedFilteredTripsProvider = Provider<AsyncValue<List<TripWithStats>>>((
  ref,
) {
  final tripsAsync = ref.watch(filteredTripsProvider);
  final sort = ref.watch(tripSortProvider);

  return tripsAsync.whenData((trips) => _applyTripSorting(trips, sort));
});

/// Apply sorting to a list of trips
List<TripWithStats> _applyTripSorting(
  List<TripWithStats> trips,
  SortState<TripSortField> sort,
) {
  final sorted = List<TripWithStats>.from(trips);

  sorted.sort((a, b) {
    int comparison;
    // For text fields, invert direction (user expects descending = A→Z)
    final invertForText = sort.field == TripSortField.name;

    switch (sort.field) {
      case TripSortField.startDate:
        comparison = a.trip.startDate.compareTo(b.trip.startDate);
      case TripSortField.endDate:
        comparison = a.trip.endDate.compareTo(b.trip.endDate);
      case TripSortField.name:
        comparison = a.trip.name.compareTo(b.trip.name);
    }

    if (invertForText) {
      return sort.direction == SortDirection.ascending
          ? -comparison
          : comparison;
    }
    return sort.direction == SortDirection.ascending ? comparison : -comparison;
  });

  return sorted;
}

/// Single trip provider
final tripByIdProvider = FutureProvider.family<Trip?, String>((ref, id) async {
  final repository = ref.watch(tripRepositoryProvider);
  return repository.getTripById(id);
});

/// Trip with stats provider
final tripWithStatsProvider = FutureProvider.family<TripWithStats, String>((
  ref,
  tripId,
) async {
  final repository = ref.watch(tripRepositoryProvider);
  return repository.getTripWithStats(tripId);
});

/// Dives for a trip provider (IDs only)
final diveIdsForTripProvider = FutureProvider.family<List<String>, String>((
  ref,
  tripId,
) async {
  final repository = ref.watch(tripRepositoryProvider);
  return repository.getDiveIdsForTrip(tripId);
});

/// Full dive entities for a trip provider
final divesForTripProvider = FutureProvider.family<List<domain.Dive>, String>((
  ref,
  tripId,
) async {
  final tripRepository = ref.watch(tripRepositoryProvider);
  final diveRepository = DiveRepository();
  final diveIds = await tripRepository.getDiveIdsForTrip(tripId);
  if (diveIds.isEmpty) return [];
  return diveRepository.getDivesByIds(diveIds);
});

/// Trip search provider
final tripSearchProvider = FutureProvider.family<List<Trip>, String>((
  ref,
  query,
) async {
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  if (query.isEmpty) {
    return ref.watch(allTripsProvider).value ?? [];
  }
  final repository = ref.watch(tripRepositoryProvider);
  return repository.searchTrips(query, diverId: validatedDiverId);
});

/// Find trip for a specific date
final tripForDateProvider = FutureProvider.family<Trip?, DateTime>((
  ref,
  date,
) async {
  final repository = ref.watch(tripRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
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
        // Invalidate the validated provider to ensure we get the fresh value
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    state = const AsyncValue.loading();
    try {
      final validatedId = await _ref.read(
        validatedCurrentDiverIdProvider.future,
      );
      _validatedDiverId = validatedId;
      await _loadTrips();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> _loadTrips() async {
    state = const AsyncValue.loading();
    try {
      final trips = await _repository.getAllTripsWithStats(
        diverId: _validatedDiverId,
      );
      state = AsyncValue.data(trips);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    try {
      // Get fresh validated diver ID before loading
      final validatedId = await _ref.read(
        validatedCurrentDiverIdProvider.future,
      );
      _validatedDiverId = validatedId;
      await _loadTrips();
      _ref.invalidate(allTripsProvider);
      _ref.invalidate(allTripsWithStatsProvider);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Trip> addTrip(Trip trip) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Always set diverId to the current validated diver for new trips
    // This ensures the trip's diverId matches the filter used to display it
    final tripWithDiver = validatedId != null
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
    StateNotifierProvider<TripListNotifier, AsyncValue<List<TripWithStats>>>((
      ref,
    ) {
      final repository = ref.watch(tripRepositoryProvider);
      return TripListNotifier(repository, ref);
    });
