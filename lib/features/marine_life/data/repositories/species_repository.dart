import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as domain;

class SpeciesRepository {
  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();

  /// Get all species
  Future<List<domain.Species>> getAllSpecies() async {
    final query = _db.select(_db.species)
      ..orderBy([
        (t) => OrderingTerm.asc(t.category),
        (t) => OrderingTerm.asc(t.commonName),
      ]);

    final rows = await query.get();
    return rows.map((row) => _mapRowToSpecies(row)).toList();
  }

  /// Get species by category
  Future<List<domain.Species>> getSpeciesByCategory(
    SpeciesCategory category,
  ) async {
    final query = _db.select(_db.species)
      ..where((t) => t.category.equals(category.name))
      ..orderBy([(t) => OrderingTerm.asc(t.commonName)]);

    final rows = await query.get();
    return rows.map((row) => _mapRowToSpecies(row)).toList();
  }

  /// Search species by name
  Future<List<domain.Species>> searchSpecies(String query) async {
    final searchTerm = '%${query.toLowerCase()}%';

    final results = await _db
        .customSelect(
          '''
      SELECT * FROM species
      WHERE LOWER(common_name) LIKE ?
         OR LOWER(scientific_name) LIKE ?
      ORDER BY category ASC, common_name ASC
      LIMIT 50
    ''',
          variables: [
            Variable.withString(searchTerm),
            Variable.withString(searchTerm),
          ],
        )
        .get();

    return results.map((row) {
      return domain.Species(
        id: row.data['id'] as String,
        commonName: row.data['common_name'] as String,
        scientificName: row.data['scientific_name'] as String?,
        category: SpeciesCategory.values.firstWhere(
          (c) => c.name == row.data['category'],
          orElse: () => SpeciesCategory.other,
        ),
        description: row.data['description'] as String?,
        photoPath: row.data['photo_path'] as String?,
      );
    }).toList();
  }

  /// Get species by ID
  Future<domain.Species?> getSpeciesById(String id) async {
    final query = _db.select(_db.species)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _mapRowToSpecies(row) : null;
  }

  /// Create or get species (creates if doesn't exist with that name)
  Future<domain.Species> getOrCreateSpecies({
    required String commonName,
    String? scientificName,
    required SpeciesCategory category,
  }) async {
    // Try to find existing species with same name
    final existing = await _db
        .customSelect(
          '''
      SELECT * FROM species
      WHERE LOWER(common_name) = ?
      LIMIT 1
    ''',
          variables: [Variable.withString(commonName.toLowerCase())],
        )
        .getSingleOrNull();

    if (existing != null) {
      return domain.Species(
        id: existing.data['id'] as String,
        commonName: existing.data['common_name'] as String,
        scientificName: existing.data['scientific_name'] as String?,
        category: SpeciesCategory.values.firstWhere(
          (c) => c.name == existing.data['category'],
          orElse: () => SpeciesCategory.other,
        ),
        description: existing.data['description'] as String?,
        photoPath: existing.data['photo_path'] as String?,
      );
    }

    // Create new species
    final id = _uuid.v4();
    await _db
        .into(_db.species)
        .insert(
          SpeciesCompanion(
            id: Value(id),
            commonName: Value(commonName),
            scientificName: Value(scientificName),
            category: Value(category.name),
          ),
        );
    final now = DateTime.now().millisecondsSinceEpoch;
    await _syncRepository.markRecordPending(
      entityType: 'species',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();

    return domain.Species(
      id: id,
      commonName: commonName,
      scientificName: scientificName,
      category: category,
    );
  }

  /// Add sighting to a dive
  Future<domain.Sighting> addSighting({
    required String diveId,
    required String speciesId,
    int count = 1,
    String notes = '',
  }) async {
    final id = _uuid.v4();
    await _db
        .into(_db.sightings)
        .insert(
          SightingsCompanion(
            id: Value(id),
            diveId: Value(diveId),
            speciesId: Value(speciesId),
            count: Value(count),
            notes: Value(notes),
          ),
        );
    final now = DateTime.now().millisecondsSinceEpoch;
    await _syncRepository.markRecordPending(
      entityType: 'sightings',
      recordId: id,
      localUpdatedAt: now,
    );
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();

    final species = await getSpeciesById(speciesId);
    return domain.Sighting(
      id: id,
      diveId: diveId,
      speciesId: speciesId,
      speciesName: species?.commonName ?? 'Unknown',
      speciesCategory: species?.category,
      count: count,
      notes: notes,
    );
  }

  /// Get sightings for a dive
  Future<List<domain.Sighting>> getSightingsForDive(String diveId) async {
    final results = await _db
        .customSelect(
          '''
      SELECT s.*, sp.common_name, sp.category
      FROM sightings s
      JOIN species sp ON s.species_id = sp.id
      WHERE s.dive_id = ?
      ORDER BY sp.category ASC, sp.common_name ASC
    ''',
          variables: [Variable.withString(diveId)],
        )
        .get();

    return results.map((row) {
      return domain.Sighting(
        id: row.data['id'] as String,
        diveId: row.data['dive_id'] as String,
        speciesId: row.data['species_id'] as String,
        speciesName: row.data['common_name'] as String,
        speciesCategory: SpeciesCategory.values.firstWhere(
          (c) => c.name == row.data['category'],
          orElse: () => SpeciesCategory.other,
        ),
        count: row.data['count'] as int,
        notes: (row.data['notes'] as String?) ?? '',
      );
    }).toList();
  }

  /// Update sighting
  Future<void> updateSighting(domain.Sighting sighting) async {
    await (_db.update(
      _db.sightings,
    )..where((t) => t.id.equals(sighting.id))).write(
      SightingsCompanion(
        count: Value(sighting.count),
        notes: Value(sighting.notes),
      ),
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    await _syncRepository.markRecordPending(
      entityType: 'sightings',
      recordId: sighting.id,
      localUpdatedAt: now,
    );
    await (_db.update(_db.dives)..where((t) => t.id.equals(sighting.diveId)))
        .write(DivesCompanion(updatedAt: Value(now)));
    await _syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: sighting.diveId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Delete sighting
  Future<void> deleteSighting(String id) async {
    final existing = await (_db.select(
      _db.sightings,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    await (_db.delete(_db.sightings)..where((t) => t.id.equals(id))).go();
    if (existing != null) {
      await _syncRepository.logDeletion(
        entityType: 'sightings',
        recordId: existing.id,
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.dives)..where((t) => t.id.equals(existing.diveId)))
          .write(DivesCompanion(updatedAt: Value(now)));
      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: existing.diveId,
        localUpdatedAt: now,
      );
    }
    SyncEventBus.notifyLocalChange();
  }

  /// Delete all sightings for a dive
  Future<void> deleteSightingsForDive(String diveId) async {
    final existing = await (_db.select(
      _db.sightings,
    )..where((t) => t.diveId.equals(diveId))).get();
    await (_db.delete(
      _db.sightings,
    )..where((t) => t.diveId.equals(diveId))).go();
    for (final row in existing) {
      await _syncRepository.logDeletion(
        entityType: 'sightings',
        recordId: row.id,
      );
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.dives)..where((t) => t.id.equals(diveId))).write(
      DivesCompanion(updatedAt: Value(now)),
    );
    await _syncRepository.markRecordPending(
      entityType: 'dives',
      recordId: diveId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Seed common species data
  Future<void> seedCommonSpecies() async {
    final count = await _db
        .customSelect('SELECT COUNT(*) as count FROM species')
        .getSingle();
    if ((count.data['count'] as int) > 0) return; // Already seeded

    final commonSpecies = [
      // Fish
      ('Clownfish', 'Amphiprion ocellaris', SpeciesCategory.fish),
      ('Blue Tang', 'Paracanthurus hepatus', SpeciesCategory.fish),
      ('Parrotfish', 'Scaridae', SpeciesCategory.fish),
      ('Lionfish', 'Pterois', SpeciesCategory.fish),
      ('Angelfish', 'Pomacanthidae', SpeciesCategory.fish),
      ('Butterflyfish', 'Chaetodontidae', SpeciesCategory.fish),
      ('Grouper', 'Epinephelinae', SpeciesCategory.fish),
      ('Moray Eel', 'Muraenidae', SpeciesCategory.fish),
      ('Barracuda', 'Sphyraena', SpeciesCategory.fish),
      ('Tuna', 'Thunnus', SpeciesCategory.fish),

      // Sharks
      ('Whale Shark', 'Rhincodon typus', SpeciesCategory.shark),
      ('Reef Shark', 'Carcharhinus', SpeciesCategory.shark),
      ('Hammerhead Shark', 'Sphyrna', SpeciesCategory.shark),
      ('Nurse Shark', 'Ginglymostoma cirratum', SpeciesCategory.shark),
      ('Bull Shark', 'Carcharhinus leucas', SpeciesCategory.shark),

      // Rays
      ('Manta Ray', 'Manta birostris', SpeciesCategory.ray),
      ('Eagle Ray', 'Myliobatidae', SpeciesCategory.ray),
      ('Stingray', 'Dasyatis', SpeciesCategory.ray),

      // Mammals
      ('Dolphin', 'Delphinidae', SpeciesCategory.mammal),
      ('Sea Lion', 'Otariinae', SpeciesCategory.mammal),
      ('Whale', 'Cetacea', SpeciesCategory.mammal),
      ('Manatee', 'Trichechus', SpeciesCategory.mammal),

      // Turtles
      ('Green Sea Turtle', 'Chelonia mydas', SpeciesCategory.turtle),
      ('Hawksbill Turtle', 'Eretmochelys imbricata', SpeciesCategory.turtle),
      ('Loggerhead Turtle', 'Caretta caretta', SpeciesCategory.turtle),

      // Invertebrates
      ('Octopus', 'Octopoda', SpeciesCategory.invertebrate),
      ('Squid', 'Teuthida', SpeciesCategory.invertebrate),
      ('Lobster', 'Nephropidae', SpeciesCategory.invertebrate),
      ('Sea Cucumber', 'Holothuroidea', SpeciesCategory.invertebrate),
      ('Jellyfish', 'Medusozoa', SpeciesCategory.invertebrate),
      ('Starfish', 'Asteroidea', SpeciesCategory.invertebrate),
      ('Crab', 'Brachyura', SpeciesCategory.invertebrate),
      ('Shrimp', 'Caridea', SpeciesCategory.invertebrate),
      ('Nudibranch', 'Nudibranchia', SpeciesCategory.invertebrate),
      ('Sea Anemone', 'Actiniaria', SpeciesCategory.invertebrate),

      // Coral
      ('Brain Coral', 'Diploria', SpeciesCategory.coral),
      ('Staghorn Coral', 'Acropora cervicornis', SpeciesCategory.coral),
      ('Fan Coral', 'Gorgonia', SpeciesCategory.coral),
      ('Table Coral', 'Acropora', SpeciesCategory.coral),
    ];

    for (final (name, scientificName, category) in commonSpecies) {
      await _db
          .into(_db.species)
          .insert(
            SpeciesCompanion(
              id: Value(_uuid.v4()),
              commonName: Value(name),
              scientificName: Value(scientificName),
              category: Value(category.name),
            ),
          );
    }
  }

  // ===========================================================================
  // Site Species Methods (for Common Marine Life feature)
  // ===========================================================================

  /// Get species spotted at a site (derived from actual dive sightings)
  Future<List<domain.SiteSpeciesSummary>> getSpeciesSpottedAtSite(
    String siteId,
  ) async {
    final results = await _db
        .customSelect(
          '''
      SELECT
        sp.id as species_id,
        sp.common_name,
        sp.category,
        COUNT(*) as sighting_count,
        COUNT(DISTINCT d.id) as dive_count
      FROM sightings s
      JOIN species sp ON s.species_id = sp.id
      JOIN dives d ON s.dive_id = d.id
      WHERE d.site_id = ?
      GROUP BY sp.id
      ORDER BY sighting_count DESC, sp.common_name ASC
    ''',
          variables: [Variable.withString(siteId)],
        )
        .get();

    return results.map((row) {
      return domain.SiteSpeciesSummary(
        speciesId: row.data['species_id'] as String,
        speciesName: row.data['common_name'] as String,
        category: SpeciesCategory.values.firstWhere(
          (c) => c.name == row.data['category'],
          orElse: () => SpeciesCategory.other,
        ),
        sightingCount: row.data['sighting_count'] as int,
        diveCount: row.data['dive_count'] as int,
      );
    }).toList();
  }

  /// Get expected species for a site (manually curated)
  Future<List<domain.SiteSpeciesEntry>> getExpectedSpeciesForSite(
    String siteId,
  ) async {
    final results = await _db
        .customSelect(
          '''
      SELECT ss.*, sp.common_name, sp.category
      FROM site_species ss
      JOIN species sp ON ss.species_id = sp.id
      WHERE ss.site_id = ?
      ORDER BY sp.category ASC, sp.common_name ASC
    ''',
          variables: [Variable.withString(siteId)],
        )
        .get();

    return results.map((row) {
      return domain.SiteSpeciesEntry(
        id: row.data['id'] as String,
        siteId: row.data['site_id'] as String,
        speciesId: row.data['species_id'] as String,
        speciesName: row.data['common_name'] as String,
        category: SpeciesCategory.values.firstWhere(
          (c) => c.name == row.data['category'],
          orElse: () => SpeciesCategory.other,
        ),
        notes: (row.data['notes'] as String?) ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.data['created_at'] as int,
        ),
      );
    }).toList();
  }

  /// Add expected species to a site
  Future<domain.SiteSpeciesEntry> addExpectedSpecies({
    required String siteId,
    required String speciesId,
    String notes = '',
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db
        .into(_db.siteSpecies)
        .insert(
          SiteSpeciesCompanion(
            id: Value(id),
            siteId: Value(siteId),
            speciesId: Value(speciesId),
            notes: Value(notes),
            createdAt: Value(now),
          ),
        );

    await _syncRepository.markRecordPending(
      entityType: 'site_species',
      recordId: id,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();

    final species = await getSpeciesById(speciesId);
    return domain.SiteSpeciesEntry(
      id: id,
      siteId: siteId,
      speciesId: speciesId,
      speciesName: species?.commonName ?? 'Unknown',
      category: species?.category ?? SpeciesCategory.other,
      notes: notes,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  /// Remove expected species from a site
  Future<void> removeExpectedSpecies(String siteId, String speciesId) async {
    final existing = await _db
        .customSelect(
          'SELECT id FROM site_species WHERE site_id = ? AND species_id = ?',
          variables: [
            Variable.withString(siteId),
            Variable.withString(speciesId),
          ],
        )
        .getSingleOrNull();

    if (existing != null) {
      final id = existing.data['id'] as String;
      await (_db.delete(_db.siteSpecies)..where((t) => t.id.equals(id))).go();
      await _syncRepository.logDeletion(
        entityType: 'site_species',
        recordId: id,
      );
      SyncEventBus.notifyLocalChange();
    }
  }

  /// Remove all expected species from a site
  Future<void> removeAllExpectedSpeciesForSite(String siteId) async {
    final existing = await (_db.select(
      _db.siteSpecies,
    )..where((t) => t.siteId.equals(siteId))).get();

    await (_db.delete(
      _db.siteSpecies,
    )..where((t) => t.siteId.equals(siteId))).go();

    for (final row in existing) {
      await _syncRepository.logDeletion(
        entityType: 'site_species',
        recordId: row.id,
      );
    }
    if (existing.isNotEmpty) {
      SyncEventBus.notifyLocalChange();
    }
  }

  /// Check if a species is already expected at a site
  Future<bool> isSpeciesExpectedAtSite(String siteId, String speciesId) async {
    final result = await _db
        .customSelect(
          'SELECT COUNT(*) as count FROM site_species WHERE site_id = ? AND species_id = ?',
          variables: [
            Variable.withString(siteId),
            Variable.withString(speciesId),
          ],
        )
        .getSingle();
    return (result.data['count'] as int) > 0;
  }

  domain.Species _mapRowToSpecies(Specy row) {
    return domain.Species(
      id: row.id,
      commonName: row.commonName,
      scientificName: row.scientificName,
      category: SpeciesCategory.values.firstWhere(
        (c) => c.name == row.category,
        orElse: () => SpeciesCategory.other,
      ),
      description: row.description,
      photoPath: row.photoPath,
    );
  }
}
