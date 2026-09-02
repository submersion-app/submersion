import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// What [SpeciesTaggingService.tagPhotos] managed to do.
class TagPhotosResult {
  final int tagged;

  /// Media id to failure message, for the photos that could not be tagged.
  final Map<String, String> failures;

  const TagPhotosResult({required this.tagged, this.failures = const {}});
}

/// Tags photos with species and keeps the dive log consistent while doing
/// it: a photo is evidence, so a tag on a dive photo adds the dive's
/// sighting of that species when none exists yet. Untagging never removes
/// a sighting; the diver may have logged it independently.
class SpeciesTaggingService {
  final MediaSpeciesRepository _tags;
  final MediaRepository _media;
  final SpeciesRepository _species;

  SpeciesTaggingService({
    required MediaSpeciesRepository tags,
    required MediaRepository media,
    required SpeciesRepository species,
  }) : _tags = tags,
       _media = media,
       _species = species;

  Future<MediaSpeciesTag> tagPhoto({
    required String mediaId,
    required String speciesId,
  }) async {
    final item = await _media.getMediaById(mediaId);
    if (item == null) {
      throw StateError('Media $mediaId does not exist');
    }
    final diveId = item.diveId;
    // A site-only photo has no dive to log the sighting on.
    if (diveId == null) {
      return _tags.addTag(mediaId: mediaId, speciesId: speciesId);
    }
    final sightingId = await _sightingIdFor(diveId, speciesId);
    return _tags.addTag(
      mediaId: mediaId,
      speciesId: speciesId,
      sightingId: sightingId,
    );
  }

  /// [tagPhoto] over many photos; one failure never stops the rest.
  Future<TagPhotosResult> tagPhotos({
    required List<String> mediaIds,
    required String speciesId,
  }) async {
    var tagged = 0;
    final failures = <String, String>{};
    for (final mediaId in mediaIds) {
      try {
        await tagPhoto(mediaId: mediaId, speciesId: speciesId);
        tagged += 1;
      } catch (e) {
        failures[mediaId] = e.toString();
      }
    }
    return TagPhotosResult(tagged: tagged, failures: failures);
  }

  Future<void> untagPhoto({
    required String mediaId,
    required String speciesId,
  }) => _tags.removeTag(mediaId: mediaId, speciesId: speciesId);

  Future<String> _sightingIdFor(String diveId, String speciesId) async {
    final sightings = await _species.getSightingsForDive(diveId);
    for (final sighting in sightings) {
      if (sighting.speciesId == speciesId) return sighting.id;
    }
    final created = await _species.addSighting(
      diveId: diveId,
      speciesId: speciesId,
    );
    return created.id;
  }
}
