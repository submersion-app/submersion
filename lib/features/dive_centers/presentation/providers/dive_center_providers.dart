import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../divers/presentation/providers/diver_providers.dart';
import '../../data/repositories/dive_center_repository.dart';
import '../../domain/entities/dive_center.dart';

/// Repository provider
final diveCenterRepositoryProvider = Provider<DiveCenterRepository>((ref) {
  return DiveCenterRepository();
});

/// All dive centers provider
final allDiveCentersProvider = FutureProvider<List<DiveCenter>>((ref) async {
  final repository = ref.watch(diveCenterRepositoryProvider);
  final validatedDiverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  return repository.getAllDiveCenters(diverId: validatedDiverId);
});

/// Single dive center provider
final diveCenterByIdProvider =
    FutureProvider.family<DiveCenter?, String>((ref, id) async {
  final repository = ref.watch(diveCenterRepositoryProvider);
  return repository.getDiveCenterById(id);
});

/// Dive centers with coordinates (for map view)
final diveCentersWithCoordinatesProvider =
    FutureProvider<List<DiveCenter>>((ref) async {
  final repository = ref.watch(diveCenterRepositoryProvider);
  return repository.getDiveCentersWithCoordinates();
});

/// Dive center search provider
final diveCenterSearchProvider =
    FutureProvider.family<List<DiveCenter>, String>((ref, query) async {
  if (query.isEmpty) {
    return ref.watch(allDiveCentersProvider).value ?? [];
  }
  final repository = ref.watch(diveCenterRepositoryProvider);
  return repository.searchDiveCenters(query);
});

/// Dive centers by country provider
final diveCentersByCountryProvider =
    FutureProvider.family<List<DiveCenter>, String>((ref, country) async {
  final repository = ref.watch(diveCenterRepositoryProvider);
  return repository.getDiveCentersByCountry(country);
});

/// All countries with dive centers
final diveCenterCountriesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.watch(diveCenterRepositoryProvider);
  return repository.getCountries();
});

/// Dive count for a center
final diveCenterDiveCountProvider =
    FutureProvider.family<int, String>((ref, centerId) async {
  final repository = ref.watch(diveCenterRepositoryProvider);
  return repository.getDiveCountForCenter(centerId);
});

/// Dive center list notifier for mutations
class DiveCenterListNotifier extends StateNotifier<AsyncValue<List<DiveCenter>>> {
  final DiveCenterRepository _repository;
  final Ref _ref;
  String? _validatedDiverId;

  DiveCenterListNotifier(this._repository, this._ref)
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
    await _loadDiveCenters();
  }

  Future<void> _loadDiveCenters() async {
    state = const AsyncValue.loading();
    try {
      final centers = await _repository.getAllDiveCenters(diverId: _validatedDiverId);
      state = AsyncValue.data(centers);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    await _loadDiveCenters();
    _ref.invalidate(allDiveCentersProvider);
    _ref.invalidate(diveCentersWithCoordinatesProvider);
    _ref.invalidate(diveCenterCountriesProvider);
  }

  Future<DiveCenter> addDiveCenter(DiveCenter center) async {
    // Get fresh validated diver ID before creating
    final validatedId = await _ref.read(validatedCurrentDiverIdProvider.future);

    // Ensure diverId is set on new dive centers
    final centerWithDiver = center.diverId == null && validatedId != null
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
});
