import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/scratch/scratch_session.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/domain/value_objects/media_attach_target.dart';
import 'package:submersion/features/species_id/data/repositories/identification_crop_repository.dart';
import 'package:submersion/features/species_id/data/repositories/identification_embedding_repository.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';

final _log = LoggerService.forClass(ScratchKeeper);

/// A file kept from the Identify viewer could not be read any more: it was
/// moved or deleted since it was opened.
class ScratchFileGone implements Exception {
  const ScratchFileGone(this.name);

  final String name;

  @override
  String toString() => 'ScratchFileGone($name)';
}

/// What a keep did: the new row's id per scratch id kept, and why each of
/// the rest failed.
class KeepResult {
  const KeepResult({required this.keptIds, required this.failures});

  final Map<String, String> keptIds;
  final Map<String, Object> failures;
}

/// Keeps files from the Identify viewer in the diver's logbook (issue
/// #5122): the row, with the place chosen, then what the session found on
/// it (the run, its identifications with the diver's decisions, their
/// embeddings and crops), the species it uses that the logbook lacks, and
/// the species the diver tagged.
class ScratchKeeper {
  ScratchKeeper({
    required ScratchSession session,
    required MediaRepository media,
    required MediaIdentificationRepository identifications,
    required IdentificationEmbeddingRepository embeddings,
    required IdentificationCropStore crops,
    required SpeciesRepository species,
    required SpeciesTaggingService tagging,
    required Future<MediaItem> Function(MediaItem scratchItem) linkFile,
    Future<void> Function(MediaItem kept)? afterKeep,
  }) : _session = session,
       _media = media,
       _identifications = identifications,
       _embeddings = embeddings,
       _crops = crops,
       _species = species,
       _tagging = tagging,
       _linkFile = linkFile,
       _afterKeep = afterKeep,
       _scratchIdentifications = MediaIdentificationRepository(
         database: session.logbook,
       ),
       _scratchEmbeddings = IdentificationEmbeddingRepository(
         database: session.cache,
       ),
       _scratchSpecies = SpeciesRepository(database: session.logbook);

  final ScratchSession _session;
  final MediaRepository _media;
  final MediaIdentificationRepository _identifications;
  final IdentificationEmbeddingRepository _embeddings;
  final IdentificationCropStore _crops;
  final SpeciesRepository _species;
  final SpeciesTaggingService _tagging;
  final Future<MediaItem> Function(MediaItem scratchItem) _linkFile;
  final Future<void> Function(MediaItem kept)? _afterKeep;
  final MediaIdentificationRepository _scratchIdentifications;
  final IdentificationEmbeddingRepository _scratchEmbeddings;
  final SpeciesRepository _scratchSpecies;

  late final IdentificationCropStore _scratchCrops = IdentificationCropStore(
    supportPath: () async => _session.cropRoot.path,
    table: IdentificationCropRepository(database: _session.logbook),
  );

  /// Keeps each of [scratchIds] at [target] with the species in [tags]. One
  /// failing (its file gone, say) never stops the rest.
  Future<KeepResult> keep(
    List<String> scratchIds,
    MediaAttachTarget target,
    Map<String, List<SpeciesTagChip>> tags,
  ) async {
    final kept = <String, String>{};
    final failures = <String, Object>{};
    for (final id in scratchIds) {
      final item = _session.items.where((i) => i.id == id).firstOrNull;
      if (item == null || _session.isKept(id)) continue;
      try {
        kept[id] = await _keepOne(item, target, tags[id] ?? const []);
        _session.markKept(id);
      } catch (error, stackTrace) {
        _log.error('Could not keep $id', error: error, stackTrace: stackTrace);
        failures[id] = error;
      }
    }
    return KeepResult(keptIds: kept, failures: failures);
  }

  Future<String> _keepOne(
    MediaItem item,
    MediaAttachTarget target,
    List<SpeciesTagChip> tags,
  ) async {
    final linked = await _linkFile(item);
    final saved = await _media.createMedia(
      linked.copyWith(
        id: '',
        diveId: switch (target) {
          DiveAttachTarget(:final diveId) => diveId,
          _ => null,
        },
        siteId: switch (target) {
          SiteAttachTarget(:final siteId) => siteId,
          _ => null,
        },
        retainInLibrary: target is UnplacedAttachTarget,
      ),
    );

    final run = await _scratchIdentifications.runFor(item.id);
    final rows = await _scratchIdentifications.forMedia(item.id);
    await _ensureSpecies({
      for (final chip in tags) chip.speciesId,
      for (final row in rows) ?row.decidedSpeciesId,
    });
    if (run != null) {
      await _identifications.storeRun(
        run.copyWith(mediaId: saved.id),
        insert: [for (final row in rows) row.copyWith(mediaId: saved.id)],
        deleteIds: const [],
      );
      final embeddings = await _scratchEmbeddings.get([
        for (final row in rows) row.id,
      ], classifierId: run.classifierId);
      if (embeddings.isNotEmpty) {
        await _embeddings.put(embeddings, classifierId: run.classifierId);
      }
    }
    for (final row in rows) {
      final crop = await _scratchCrops.read(item.id, row.id);
      final bytes = switch (crop) {
        CropBytes(:final bytes) => bytes,
        CropFile(:final file) => await file.readAsBytes(),
        null => null,
      };
      if (bytes == null) continue;
      await _crops.write(saved.id, row.id, bytes, named: crop is CropBytes);
    }
    for (final chip in tags) {
      await _tagging.tagPhoto(mediaId: saved.id, speciesId: chip.speciesId);
    }
    await _afterKeep?.call(saved);
    return saved.id;
  }

  /// Creates in the logbook each of [ids] that only the session has: a
  /// species the diver accepted that the catalogue lacked. Same id, so the
  /// tags and decisions copied across point at it.
  Future<void> _ensureSpecies(Set<String> ids) async {
    for (final id in ids) {
      if (await _species.getSpeciesById(id) != null) continue;
      final found = await _scratchSpecies.getSpeciesById(id);
      if (found == null) continue;
      await _species.createSpecies(
        id: found.id,
        commonName: found.commonName,
        scientificName: found.scientificName,
        category: found.category,
        taxonomyClass: found.taxonomyClass,
        description: found.description,
      );
    }
  }
}
