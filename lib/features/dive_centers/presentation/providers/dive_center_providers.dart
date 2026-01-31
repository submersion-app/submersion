import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/data/services/dive_center_api_service.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Repository provider
final diveCenterRepositoryProvider = Provider<DiveCenterRepository>((ref) {
  return DiveCenterRepository();
});

/// All dive centers provider
final allDiveCentersProvider = FutureProvider<List<DiveCenter>>((ref) async {
  final repository = ref.watch(diveCenterRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getAllDiveCenters(diverId: validatedDiverId);
});

/// Dive center sort state provider
final diveCenterSortProvider = StateProvider<SortState<DiveCenterSortField>>(
  (ref) => const SortState(
    field: DiveCenterSortField.name,
    direction: SortDirection.descending,
  ),
);

/// Apply sorting to a list of dive centers
/// Note: diveCount sorting defaults to name since it's not in the basic entity
List<DiveCenter> applyDiveCenterSorting(
  List<DiveCenter> centers,
  SortState<DiveCenterSortField> sort,
) {
  final sorted = List<DiveCenter>.from(centers);

  sorted.sort((a, b) {
    int comparison;
    // For text fields, invert direction (user expects descending = A→Z)
    final invertForText = sort.field == DiveCenterSortField.name;

    switch (sort.field) {
      case DiveCenterSortField.name:
        comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case DiveCenterSortField.diveCount:
        // Dive count not available in basic entity, sort by name as fallback
        comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
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

/// Single dive center provider
final diveCenterByIdProvider = FutureProvider.family<DiveCenter?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(diveCenterRepositoryProvider);
  return repository.getDiveCenterById(id);
});

/// Dive centers with coordinates (for map view)
final diveCentersWithCoordinatesProvider = FutureProvider<List<DiveCenter>>((
  ref,
) async {
  final repository = ref.watch(diveCenterRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getDiveCentersWithCoordinates(diverId: validatedDiverId);
});

/// Dive center search provider
final diveCenterSearchProvider =
    FutureProvider.family<List<DiveCenter>, String>((ref, query) async {
      final validatedDiverId = await ref.watch(
        validatedCurrentDiverIdProvider.future,
      );
      if (query.isEmpty) {
        return ref.watch(allDiveCentersProvider).value ?? [];
      }
      final repository = ref.watch(diveCenterRepositoryProvider);
      return repository.searchDiveCenters(query, diverId: validatedDiverId);
    });

/// Dive centers by country provider
final diveCentersByCountryProvider =
    FutureProvider.family<List<DiveCenter>, String>((ref, country) async {
      final repository = ref.watch(diveCenterRepositoryProvider);
      final validatedDiverId = await ref.watch(
        validatedCurrentDiverIdProvider.future,
      );
      return repository.getDiveCentersByCountry(
        country,
        diverId: validatedDiverId,
      );
    });

/// All countries with dive centers
final diveCenterCountriesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(diveCenterRepositoryProvider);
  final validatedDiverId = await ref.watch(
    validatedCurrentDiverIdProvider.future,
  );
  return repository.getCountries(diverId: validatedDiverId);
});

/// Dive count for a center
final diveCenterDiveCountProvider = FutureProvider.family<int, String>((
  ref,
  centerId,
) async {
  final repository = ref.watch(diveCenterRepositoryProvider);
  return repository.getDiveCountForCenter(centerId);
});

/// Dive center list notifier for mutations
class DiveCenterListNotifier
    extends StateNotifier<AsyncValue<List<DiveCenter>>> {
  final DiveCenterRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  DiveCenterListNotifier(this._repository, this._ref)
    : super(const AsyncValue.loading()) {
    _initializeAndLoad();

    // Listen for diver changes and reload
    _ref.listen<String?>(currentDiverIdProvider, (previous, next) {
      if (previous != next) {
        state = const AsyncValue.loading();
        _ref.invalidate(validatedCurrentDiverIdProvider);
        _ref.invalidate(allDiveCentersProvider);
        _initializeAndLoad();
      }
    });
  }

  Future<void> _initializeAndLoad() async {
    state = const AsyncValue.loading();
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadDiveCenters();
  }

  Future<void> _loadDiveCenters() async {
    state = const AsyncValue.loading();
    try {
      final centers = await _repository.getAllDiveCenters(
        diverId: _validatedDiverId,
      );
      state = AsyncValue.data(centers);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    // Get fresh validated diver ID before loading
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);
    _validatedDiverId = validatedId;
    await _loadDiveCenters();
    _ref.invalidate(allDiveCentersProvider);
    _ref.invalidate(diveCentersWithCoordinatesProvider);
    _ref.invalidate(diveCenterCountriesProvider);
  }

  Future<DiveCenter> addDiveCenter(DiveCenter center) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Always set diverId to the current validated diver for new items
    final centerWithDiver = validatedId != null
        ? center.copyWith(diverId: validatedId)
        : center;
    final newCenter = await _repository.createDiveCenter(centerWithDiver);
    await refresh();
    return newCenter;
  }

  Future<void> updateDiveCenter(DiveCenter center) async {
    await _repository.updateDiveCenter(center);
    await refresh();
    _ref.invalidate(diveCenterByIdProvider(center.id));
  }

  Future<void> deleteDiveCenter(String id) async {
    await _repository.deleteDiveCenter(id);
    await refresh();
  }
}

final diveCenterListNotifierProvider =
    StateNotifierProvider<DiveCenterListNotifier, AsyncValue<List<DiveCenter>>>(
      (ref) {
        final repository = ref.watch(diveCenterRepositoryProvider);
        return DiveCenterListNotifier(repository, ref);
      },
    );

// =============================================================================
// External Dive Center Import Providers
// =============================================================================

/// API service provider for external dive centers
final diveCenterApiServiceProvider = Provider<DiveCenterApiService>((ref) {
  return DiveCenterApiService();
});

/// State for external dive center search
class ExternalCenterSearchState {
  final bool isLoading;
  final String query;
  final List<ExternalDiveCenter> centers;
  final List<DiveCenter> localCenters;
  final String? errorMessage;

  const ExternalCenterSearchState({
    this.isLoading = false,
    this.query = '',
    this.centers = const [],
    this.localCenters = const [],
    this.errorMessage,
  });

  bool get hasResults => centers.isNotEmpty || localCenters.isNotEmpty;
  bool get hasExternalResults => centers.isNotEmpty;
  bool get hasLocalResults => localCenters.isNotEmpty;
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;

  ExternalCenterSearchState copyWith({
    bool? isLoading,
    String? query,
    List<ExternalDiveCenter>? centers,
    List<DiveCenter>? localCenters,
    String? errorMessage,
  }) {
    return ExternalCenterSearchState(
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
      centers: centers ?? this.centers,
      localCenters: localCenters ?? this.localCenters,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier for external dive center search
class ExternalCenterSearchNotifier extends StateNotifier<ExternalCenterSearchState> {
  final DiveCenterApiService _apiService;
  final DiveCenterRepository _repository;
  final Ref _ref;

  ExternalCenterSearchNotifier(this._apiService, this._repository, this._ref)
      : super(const ExternalCenterSearchState());

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const ExternalCenterSearchState();
      return;
    }

    state = state.copyWith(isLoading: true, query: query, errorMessage: null);

    try {
      // Search both local and external in parallel
      final validatedDiverId = await _ref.read(
        validatedCurrentDiverIdProvider.future,
      );
      final localFuture = _repository.searchDiveCenters(
        query,
        diverId: validatedDiverId,
      );
      final externalFuture = _apiService.searchCenters(query);

      final results = await Future.wait([localFuture, externalFuture]);
      final localResults = results[0] as List<DiveCenter>;
      final externalResult = results[1] as DiveCenterSearchResult;

      state = state.copyWith(
        isLoading: false,
        localCenters: localResults,
        centers: externalResult.centers,
        errorMessage: externalResult.errorMessage,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Search failed: $e',
      );
    }
  }

  Future<DiveCenter?> importCenter(ExternalDiveCenter external) async {
    try {
      final validatedDiverId = await _ref.read(
        validatedCurrentDiverIdProvider.future,
      );
      final center = external.toDiveCenter(diverId: validatedDiverId);
      final notifier = _ref.read(diveCenterListNotifierProvider.notifier);
      final imported = await notifier.addDiveCenter(center);
      return imported;
    } catch (e) {
      return null;
    }
  }

  void clear() {
    state = const ExternalCenterSearchState();
  }
}

/// Provider for external dive center search
final externalCenterSearchProvider =
    StateNotifierProvider<ExternalCenterSearchNotifier, ExternalCenterSearchState>(
      (ref) {
        final apiService = ref.watch(diveCenterApiServiceProvider);
        final repository = ref.watch(diveCenterRepositoryProvider);
        return ExternalCenterSearchNotifier(apiService, repository, ref);
      },
    );
