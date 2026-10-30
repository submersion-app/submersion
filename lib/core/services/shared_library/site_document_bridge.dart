import 'package:drift/drift.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/site_document.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_feature_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain;
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/site_types/data/repositories/site_type_repository.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;
import 'package:submersion/features/dive_sites/domain/entry_method_list.dart';

/// Turns a local library site into its document and a document back into
/// the row and children (issue #2567).
///
/// Vocabulary (site types, tags, species) travels by name and is resolved
/// against the subscribing diver's own vocabulary, created when missing.
/// Features keep the ids in the document. Nothing here calls
/// `markRecordPending('diveSites')`: a library row stays outside the
/// personal sync.
class SiteDocumentBridge {
  SiteDocumentBridge({
    SiteRepository? sites,
    SiteClassificationRepository? classification,
    SiteFeatureRepository? features,
    SpeciesRepository? species,
    SiteTypeRepository? siteTypes,
    TagRepository? tags,
  }) : _sites = sites ?? SiteRepository(),
       _classification = classification ?? SiteClassificationRepository(),
       _features = features ?? SiteFeatureRepository(),
       _species = species ?? SpeciesRepository(),
       _siteTypes = siteTypes ?? SiteTypeRepository(),
       _tags = tags ?? TagRepository();

  final SiteRepository _sites;
  final SiteClassificationRepository _classification;
  final SiteFeatureRepository _features;
  final SpeciesRepository _species;
  final SiteTypeRepository _siteTypes;
  final TagRepository _tags;

  AppDatabase get _db => DatabaseService.instance.database;

  /// The document for a local library site, from its row, children and
  /// the clocks in [state]. `deleted` is false; the publisher sets it.
  Future<SiteDocument> build(String siteId, SharedSiteState state) async {
    final site = await _sites.getSiteById(siteId);
    if (site == null) {
      throw StateError('site $siteId has no row to build a document from');
    }
    final types = await _classification.getTypesForSite(siteId);
    final tags = await _classification.getTagsForSite(siteId);
    final expected = await _species.getExpectedSpeciesForSite(siteId);
    final speciesList = <Map<String, Object?>>[];
    for (final entry in expected) {
      final species = await _species.getSpeciesById(entry.speciesId);
      speciesList.add({
        'name': species?.commonName ?? entry.speciesName,
        'scientificName': species?.scientificName,
      });
    }
    final features = await _features.getFeaturesForSite(siteId);
    final fields = <String, Object?>{
      for (final f in SiteDocument.fieldNames)
        if (!SiteDocument.listFields.contains(f)) f: fieldValue(site, f),
      'siteTypes': [for (final t in types) t.name],
      'tags': [for (final t in tags) t.name],
      'species': speciesList,
      'features': [
        for (final f in features)
          {
            'id': f.id,
            'type': f.typeName,
            'name': f.name,
            'latitude': f.latitude,
            'longitude': f.longitude,
            'bearingDeg': f.bearingDeg,
            'depthMeters': f.depthMeters,
            'notes': f.notes,
          },
      ],
    };
    return SiteDocument(
      id: siteId,
      deleted: state.deleted,
      fields: fields,
      clocks: Map.of(state.clocks),
    );
  }

  /// The document-form value of one scalar field of [site].
  static Object? fieldValue(domain.DiveSite site, String field) =>
      switch (field) {
        'name' => site.name,
        'description' => site.description,
        'latitude' => site.location?.latitude,
        'longitude' => site.location?.longitude,
        'minDepth' => site.minDepth,
        'maxDepth' => site.maxDepth,
        'difficulty' => site.difficulty?.name,
        'waterType' => site.waterType?.name,
        'bodyOfWater' => site.bodyOfWater,
        'city' => site.city,
        'island' => site.island,
        'country' => site.country,
        'region' => site.region,
        'rating' => site.rating,
        'notes' => site.notes,
        'hazards' => site.hazards,
        'accessNotes' => site.accessNotes,
        'mooringNumber' => site.mooringNumber,
        'parkingInfo' => site.parkingInfo,
        'altitude' => site.altitude,
        'entryMethod' => encodeEntryMethods(site.entryMethods),
        'exitMethod' => encodeEntryMethods(site.exitMethods),
        _ => null,
      };

  /// Writes the winning fields of [doc] into the row and children. Creates
  /// the row (diverId null, isShared false, sharedLibraryId = [libraryId])
  /// when it does not exist. [fields] limits the write to those names;
  /// null writes every field the document carries.
  Future<void> apply(
    SiteDocument doc, {
    required String libraryId,
    required String vocabularyDiverId,
    Set<String>? fields,
  }) async {
    final names = (fields ?? doc.fields.keys.toSet()).where(
      doc.fields.containsKey,
    );
    final scalars = names.where((f) => !SiteDocument.listFields.contains(f));
    final f = doc.fields;
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      final exists = await (_db.select(
        _db.diveSites,
      )..where((t) => t.id.equals(doc.id))).getSingleOrNull();

      Value<T> pick<T>(String field, T Function(Object?) convert) =>
          scalars.contains(field)
          ? Value(convert(f[field]))
          : const Value.absent();
      String str(Object? v) => (v as String?) ?? '';
      String? strOrNull(Object? v) => v as String?;
      double? dbl(Object? v) => (v as num?)?.toDouble();

      final companion = DiveSitesCompanion(
        id: Value(doc.id),
        sharedLibraryId: Value(libraryId),
        diverId: const Value(null),
        isShared: const Value(false),
        updatedAt: Value(now),
        createdAt: exists == null ? Value(now) : const Value.absent(),
        name: scalars.contains('name')
            ? Value(str(f['name']))
            : (exists == null ? const Value('') : const Value.absent()),
        description: pick('description', str),
        latitude: pick('latitude', dbl),
        longitude: pick('longitude', dbl),
        minDepth: pick('minDepth', dbl),
        maxDepth: pick('maxDepth', dbl),
        difficulty: pick('difficulty', strOrNull),
        waterType: pick('waterType', strOrNull),
        bodyOfWater: pick('bodyOfWater', strOrNull),
        city: pick('city', strOrNull),
        island: pick('island', strOrNull),
        country: pick('country', strOrNull),
        region: pick('region', strOrNull),
        rating: pick('rating', dbl),
        notes: pick('notes', str),
        hazards: pick('hazards', strOrNull),
        accessNotes: pick('accessNotes', strOrNull),
        mooringNumber: pick('mooringNumber', strOrNull),
        parkingInfo: pick('parkingInfo', strOrNull),
        altitude: pick('altitude', dbl),
        entryMethod: pick('entryMethod', strOrNull),
        exitMethod: pick('exitMethod', strOrNull),
      );
      if (exists == null) {
        await _db.into(_db.diveSites).insert(companion);
      } else {
        await (_db.update(
          _db.diveSites,
        )..where((t) => t.id.equals(doc.id))).write(companion);
      }

      if (names.contains('siteTypes')) {
        await _applyTypes(doc.id, _strings(f['siteTypes']), vocabularyDiverId);
      }
      if (names.contains('tags')) {
        await _applyTags(doc.id, _strings(f['tags']), vocabularyDiverId);
      }
      if (names.contains('species')) {
        await _applySpecies(doc.id, f['species']);
      }
      if (names.contains('features')) {
        await _applyFeatures(doc.id, f['features'], now);
      }
    });
  }

  static List<String> _strings(Object? raw) => raw is List
      ? raw
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList()
      : const [];

  static String _fold(String s) => s.trim().toLowerCase();

  Future<void> _applyTypes(
    String siteId,
    List<String> names,
    String diverId,
  ) async {
    final known = await _siteTypes.getAllSiteTypes(diverId: diverId);
    final byName = {for (final t in known) _fold(t.name): t.id};
    final ids = <String>[];
    for (final name in names) {
      var id = byName[_fold(name)];
      if (id == null) {
        final now = DateTime.now();
        final created = await _siteTypes.createSiteType(
          SiteTypeEntity(
            id: '',
            diverId: diverId,
            name: name,
            createdAt: now,
            updatedAt: now,
          ),
        );
        id = created.id;
        byName[_fold(name)] = id;
      }
      if (!ids.contains(id)) ids.add(id);
    }
    await _classification.replaceTypes(siteId, ids, notify: false);
  }

  Future<void> _applyTags(
    String siteId,
    List<String> names,
    String diverId,
  ) async {
    final known = await _tags.getAllTags(diverId: diverId);
    final byName = {for (final t in known) _fold(t.name): t.id};
    final ids = <String>[];
    for (final name in names) {
      var id = byName[_fold(name)];
      if (id == null) {
        final now = DateTime.now();
        final created = await _tags.createTag(
          domain.Tag(
            id: '',
            diverId: diverId,
            name: name,
            createdAt: now,
            updatedAt: now,
            scopes: const {domain.TagScope.sites},
          ),
        );
        id = created.id;
        byName[_fold(name)] = id;
      }
      if (!ids.contains(id)) ids.add(id);
    }
    await _classification.replaceTags(siteId, ids, notify: false);
  }

  Future<void> _applySpecies(String siteId, Object? raw) async {
    final wanted = <({String name, String? scientificName})>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final name = (item['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        wanted.add((
          name: name,
          scientificName: (item['scientificName'] as String?)?.trim(),
        ));
      }
    }
    final all = await _species.getAllSpecies();
    final byScientific = {
      for (final s in all)
        if (s.scientificName != null && s.scientificName!.trim().isNotEmpty)
          _fold(s.scientificName!): s.id,
    };
    final byCommon = {for (final s in all) _fold(s.commonName): s.id};
    final targetIds = <String>{};
    for (final w in wanted) {
      var id = w.scientificName == null || w.scientificName!.isEmpty
          ? null
          : byScientific[_fold(w.scientificName!)];
      id ??= byCommon[_fold(w.name)];
      if (id == null) {
        final created = await _species.createSpecies(
          commonName: w.name,
          scientificName: w.scientificName,
          category: SpeciesCategory.other,
        );
        id = created.id;
        byCommon[_fold(w.name)] = id;
      }
      targetIds.add(id);
    }
    final current = await _species.getExpectedSpeciesForSite(siteId);
    final currentIds = {for (final e in current) e.speciesId};
    // No stamp: the caller writes the clocks the document carries.
    for (final id in currentIds.difference(targetIds)) {
      await _species.removeExpectedSpecies(siteId, id, stampLibrary: false);
    }
    for (final id in targetIds.difference(currentIds)) {
      await _species.addExpectedSpecies(
        siteId: siteId,
        speciesId: id,
        stampLibrary: false,
      );
    }
  }

  Future<void> _applyFeatures(String siteId, Object? raw, int now) async {
    final keep = <String>{};
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final id = item['id'] as String?;
        final type = item['type'] as String?;
        final lat = (item['latitude'] as num?)?.toDouble();
        final lng = (item['longitude'] as num?)?.toDouble();
        if (id == null ||
            id.isEmpty ||
            type == null ||
            lat == null ||
            lng == null) {
          continue;
        }
        keep.add(id);
        final existing = await (_db.select(
          _db.siteFeatures,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        await _db
            .into(_db.siteFeatures)
            .insertOnConflictUpdate(
              SiteFeaturesCompanion.insert(
                id: id,
                siteId: siteId,
                type: type,
                name: Value((item['name'] as String?) ?? ''),
                latitude: lat,
                longitude: lng,
                bearingDeg: Value((item['bearingDeg'] as num?)?.toDouble()),
                depthMeters: Value((item['depthMeters'] as num?)?.toDouble()),
                notes: Value((item['notes'] as String?) ?? ''),
                createdAt: existing?.createdAt ?? now,
                updatedAt: now,
              ),
            );
      }
    }
    final delete = _db.delete(_db.siteFeatures)
      ..where((t) => t.siteId.equals(siteId));
    if (keep.isNotEmpty) delete.where((t) => t.id.isNotIn(keep.toList()));
    await delete.go();
  }
}
