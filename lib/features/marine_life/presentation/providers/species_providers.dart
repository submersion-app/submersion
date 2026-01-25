import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

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
    FutureProvider.family<List<Species>, SpeciesCategory>((
      ref,
      category,
    ) async {
      final repository = ref.watch(speciesRepositoryProvider);
      return repository.getSpeciesByCategory(category);
    });

/// Species search provider
final speciesSearchProvider = FutureProvider.family<List<Species>, String>((
  ref,
  query,
) async {
  if (query.isEmpty) {
    return ref.watch(allSpeciesProvider).value ?? [];
  }
  final repository = ref.watch(speciesRepositoryProvider);
  return repository.searchSpecies(query);
});

/// Single species provider
final speciesProvider = FutureProvider.family<Species?, String>((
  ref,
  id,
) async {
  final repository = ref.watch(speciesRepositoryProvider);
  return repository.getSpeciesById(id);
});

/// Sightings for a dive provider
final diveSightingsProvider = FutureProvider.family<List<Sighting>, String>((
  ref,
  diveId,
) async {
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
    StateNotifierProvider.family<SightingsNotifier, List<Sighting>, String?>((
      ref,
      diveId,
    ) {
      final repository = ref.watch(speciesRepositoryProvider);
      return SightingsNotifier(repository, diveId);
    });

/// Initialize species database with common species
final seedSpeciesProvider = FutureProvider<void>((ref) async {
  final repository = ref.watch(speciesRepositoryProvider);
  await repository.seedCommonSpecies();
});

// ===========================================================================
// Site Marine Life Providers (for Common Marine Life feature)
// ===========================================================================

/// Species spotted at a site (derived from dive sightings)
final siteSpottedSpeciesProvider =
    FutureProvider.family<List<SiteSpeciesSummary>, String>((
      ref,
      siteId,
    ) async {
      final repository = ref.watch(speciesRepositoryProvider);
      return repository.getSpeciesSpottedAtSite(siteId);
    });

/// Expected species at a site (manually curated)
final siteExpectedSpeciesProvider =
    FutureProvider.family<List<SiteSpeciesEntry>, String>((ref, siteId) async {
      final repository = ref.watch(speciesRepositoryProvider);
      return repository.getExpectedSpeciesForSite(siteId);
    });

/// Notifier for managing expected species at a site
class SiteExpectedSpeciesNotifier
    extends StateNotifier<List<SiteSpeciesEntry>> {
  final SpeciesRepository _repository;
  final String _siteId;

  SiteExpectedSpeciesNotifier(this._repository, this._siteId) : super([]) {
    _loadExpectedSpecies();
  }

  Future<void> _loadExpectedSpecies() async {
    final entries = await _repository.getExpectedSpeciesForSite(_siteId);
    state = entries;
  }

  Future<void> addSpecies(String speciesId) async {
    final entry = await _repository.addExpectedSpecies(
      siteId: _siteId,
      speciesId: speciesId,
    );
    state = [...state, entry];
  }

  Future<void> removeSpecies(String speciesId) async {
    await _repository.removeExpectedSpecies(_siteId, speciesId);
    state = state.where((e) => e.speciesId != speciesId).toList();
  }

  Future<void> setSpecies(List<String> speciesIds) async {
    // Remove all existing
    await _repository.removeAllExpectedSpeciesForSite(_siteId);

    // Add new ones
    final entries = <SiteSpeciesEntry>[];
    for (final speciesId in speciesIds) {
      final entry = await _repository.addExpectedSpecies(
        siteId: _siteId,
        speciesId: speciesId,
      );
      entries.add(entry);
    }

    state = entries;
  }

  void refresh() {
    _loadExpectedSpecies();
  }
}

/// Provider for managing expected species at a site
final siteExpectedSpeciesNotifierProvider =
    StateNotifierProvider.family<
      SiteExpectedSpeciesNotifier,
      List<SiteSpeciesEntry>,
      String
    >((ref, siteId) {
      final repository = ref.watch(speciesRepositoryProvider);
      return SiteExpectedSpeciesNotifier(repository, siteId);
    });
