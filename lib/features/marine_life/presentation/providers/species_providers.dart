import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../data/repositories/species_repository.dart';
import '../../domain/entities/species.dart';

/// Repository provider
final speciesRepositoryProvider = Provider<SpeciesRepository>((ref) {
  return SpeciesRepository();
});

/// All species provider
final allSpeciesProvider = FutureProvider<List<Species>>((ref) async {
  final repository = ref.watch(speciesRepositoryProvider);
  return repository.getAllSpecies();
});

/// Species by category provider
final speciesByCategoryProvider =
    FutureProvider.family<List<Species>, SpeciesCategory>(
        (ref, category) async {
  final repository = ref.watch(speciesRepositoryProvider);
  return repository.getSpeciesByCategory(category);
});

/// Species search provider
final speciesSearchProvider =
    FutureProvider.family<List<Species>, String>((ref, query) async {
  if (query.isEmpty) {
    return ref.watch(allSpeciesProvider).value ?? [];
  }
  final repository = ref.watch(speciesRepositoryProvider);
  return repository.searchSpecies(query);
});

/// Single species provider
final speciesProvider =
    FutureProvider.family<Species?, String>((ref, id) async {
  final repository = ref.watch(speciesRepositoryProvider);
  return repository.getSpeciesById(id);
});

/// Sightings for a dive provider
final diveSightingsProvider =
    FutureProvider.family<List<Sighting>, String>((ref, diveId) async {
  final repository = ref.watch(speciesRepositoryProvider);
  return repository.getSightingsForDive(diveId);
});

/// Sightings notifier for managing sightings on a dive
class SightingsNotifier extends StateNotifier<List<Sighting>> {
  final SpeciesRepository _repository;
  final String? _diveId;

  SightingsNotifier(this._repository, this._diveId) : super([]) {
    if (_diveId != null) {
      _loadSightings();
    }
  }

  Future<void> _loadSightings() async {
    if (_diveId == null) return;
    final sightings = await _repository.getSightingsForDive(_diveId);
    state = sightings;
  }

  Future<void> addSighting({
    required String speciesId,
    required String speciesName,
    SpeciesCategory? speciesCategory,
    int count = 1,
    String notes = '',
  }) async {
    if (_diveId == null) {
      // For new dives, just add to local state
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      final sighting = Sighting(
        id: tempId,
        diveId: '',
        speciesId: speciesId,
        speciesName: speciesName,
        speciesCategory: speciesCategory,
        count: count,
        notes: notes,
      );
      state = [...state, sighting];
    } else {
      // For existing dives, save to database
      final sighting = await _repository.addSighting(
        diveId: _diveId,
        speciesId: speciesId,
        count: count,
        notes: notes,
      );
      state = [...state, sighting];
    }
  }

  Future<void> updateSighting(Sighting sighting) async {
    if (_diveId != null) {
      await _repository.updateSighting(sighting);
    }
    state = state.map((s) => s.id == sighting.id ? sighting : s).toList();
  }

  Future<void> removeSighting(String id) async {
    if (_diveId != null) {
      await _repository.deleteSighting(id);
    }
    state = state.where((s) => s.id != id).toList();
  }

  void setSightings(List<Sighting> sightings) {
    state = sightings;
  }

  /// Save all sightings for a new dive
  Future<void> saveForDive(String diveId) async {
    for (final sighting in state) {
      await _repository.addSighting(
        diveId: diveId,
        speciesId: sighting.speciesId,
        count: sighting.count,
        notes: sighting.notes,
      );
    }
  }
}

/// Sightings notifier provider (for editing)
final sightingsNotifierProvider =
    StateNotifierProvider.family<SightingsNotifier, List<Sighting>, String?>(
        (ref, diveId) {
  final repository = ref.watch(speciesRepositoryProvider);
  return SightingsNotifier(repository, diveId);
});

/// Initialize species database with common species
final seedSpeciesProvider = FutureProvider<void>((ref) async {
  final repository = ref.watch(speciesRepositoryProvider);
  await repository.seedCommonSpecies();
});
