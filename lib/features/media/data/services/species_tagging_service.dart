import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/app_tag_guards.dart';
import 'package:submersion/features/media/domain/value_objects/sighting_timing.dart';

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

  /// Tags [mediaId] by hand. A tag the app applied there for the species
  /// becomes the diver's (issue #4727), with its sighting, whichever came
  /// first: the diver named the species.
  Future<MediaSpeciesTag> tagPhoto({
    required String mediaId,
    required String speciesId,
  }) async {
    final item = await _media.getMediaById(mediaId);
    if (item == null) {
      throw StateError('Media $mediaId does not exist');
    }
    final existing = await _tags.findTag(mediaId, speciesId);
    if (existing != null && existing.unconfirmed) {
      await confirmTag(mediaId: mediaId, speciesId: speciesId);
      return (await _tags.findTag(mediaId, speciesId)) ?? existing;
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

  /// The tag linking [mediaId] and [speciesId], or null.
  Future<MediaSpeciesTag?> findTag(String mediaId, String speciesId) =>
      _tags.findTag(mediaId, speciesId);

  /// Tags [mediaId] the way the app does on its own (issue #4727): marked
  /// unconfirmed. With [SightingTiming.onConfirm] the tag only links a
  /// sighting the diver already logged; with [SightingTiming.straightAway]
  /// it finds or creates one, recording whether it created it.
  /// [createdSpecies] says the app created the species for this tag. An
  /// existing tag of the species is left as it is.
  Future<MediaSpeciesTag> applyAppTag({
    required String mediaId,
    required String speciesId,
    required SightingTiming timing,
    required bool createdSpecies,
  }) async {
    final existing = await _tags.findTag(mediaId, speciesId);
    if (existing != null) return existing;
    final item = await _media.getMediaById(mediaId);
    if (item == null) {
      throw StateError('Media $mediaId does not exist');
    }
    final diveId = item.diveId;
    String? sightingId;
    var createdSighting = false;
    if (diveId != null) {
      final logged = await _existingSightingId(diveId, speciesId);
      if (logged != null) {
        sightingId = logged;
      } else if (timing == SightingTiming.straightAway) {
        sightingId = (await _species.addSighting(
          diveId: diveId,
          speciesId: speciesId,
        )).id;
        createdSighting = true;
      }
    }
    return _tags.addTag(
      mediaId: mediaId,
      speciesId: speciesId,
      sightingId: sightingId,
      unconfirmed: true,
      createdSighting: createdSighting,
      createdSpecies: createdSpecies,
    );
  }

  /// Makes a tag the app applied the diver's own. Like a hand tag, a
  /// confirmed tag on a dive photo has the dive's sighting, so one is found
  /// or created and linked when the tag has none. A hand tag is left alone.
  Future<void> confirmTag({
    required String mediaId,
    required String speciesId,
  }) async {
    final tag = await _tags.findTag(mediaId, speciesId);
    if (tag == null || !tag.unconfirmed) return;
    String? sightingId;
    if (tag.sightingId == null) {
      final diveId = (await _media.getMediaById(mediaId))?.diveId;
      if (diveId != null) sightingId = await _sightingIdFor(diveId, speciesId);
    }
    await _tags.confirmTag(
      mediaId: mediaId,
      speciesId: speciesId,
      sightingId: sightingId,
    );
  }

  /// Removes a tag. When it was the app's and still unconfirmed, the
  /// sighting and the species it created go with it, each only when nothing
  /// else uses it and the diver has not changed it (see app_tag_guards).
  /// When other unconfirmed app tags still use them, the "created" mark
  /// passes to one of those instead, so the last of them to be rejected
  /// takes them; a confirmed or hand tag still using them keeps them, as
  /// the diver's. A confirmed tag is removed as a hand tag is: never its
  /// sighting.
  Future<void> rejectTag({
    required String mediaId,
    required String speciesId,
  }) async {
    final tag = await _tags.findTag(mediaId, speciesId);
    if (tag == null) return;
    await _tags.removeTag(mediaId: mediaId, speciesId: speciesId);
    if (!tag.unconfirmed) return;
    final sightingId = tag.sightingId;
    if (tag.createdSighting && sightingId != null) {
      await _removeCreatedSighting(tag, sightingId);
    }
    if (tag.createdSpecies) await _removeCreatedSpecies(tag);
  }

  Future<void> _removeCreatedSighting(
    MediaSpeciesTag tag,
    String sightingId,
  ) async {
    // By its id, not through the photo's dive: the photo may have moved to
    // another dive since, keeping its link to this sighting.
    final sighting = await _species.getSightingById(sightingId);
    if (sighting == null) return;
    final others = await _tags.tagsForSighting(sightingId);
    if (mayRemoveCreatedSighting(
      sighting: sighting,
      otherTagsPointingAtIt: others.length,
    )) {
      await _species.deleteSighting(sightingId);
      return;
    }
    // Still the app's own: unchanged, and only its unconfirmed tags use it.
    final unchanged = mayRemoveCreatedSighting(
      sighting: sighting,
      otherTagsPointingAtIt: 0,
    );
    if (unchanged && others.every((t) => t.unconfirmed)) {
      await _tags.handOverCreatedMarks(others.first.id, sighting: true);
    }
  }

  Future<void> _removeCreatedSpecies(MediaSpeciesTag tag) async {
    final species = await _species.getSpeciesById(tag.speciesId);
    if (species == null) return;
    final onSite = await _species.isSpeciesOnAnySite(species.id);
    final speciesHlc = await _species.hlcOf(species.id);
    final inUse = onSite || await _species.isSpeciesInUse(species.id);
    if (mayRemoveCreatedSpecies(
      species: species,
      speciesHlc: speciesHlc,
      tagHlc: tag.hlc,
      inUseElsewhere: inUse,
    )) {
      await _species.deleteSpecies(species.id);
      return;
    }
    // Still the app's own: unedited, on no site, and tagged only by its
    // unconfirmed tags (a sighting the app made goes with the last of them).
    final others = await _tags.tagsOfSpecies(species.id);
    final stillTheApps =
        !onSite &&
        others.isNotEmpty &&
        others.every((t) => t.unconfirmed) &&
        mayRemoveCreatedSpecies(
          species: species,
          speciesHlc: speciesHlc,
          tagHlc: tag.hlc,
          inUseElsewhere: false,
        );
    if (stillTheApps) {
      await _tags.handOverCreatedMarks(others.first.id, species: true);
    }
  }

  Future<String?> _existingSightingId(String diveId, String speciesId) async {
    final sightings = await _species.getSightingsForDive(diveId);
    for (final sighting in sightings) {
      if (sighting.speciesId == speciesId) return sighting.id;
    }
    return null;
  }

  Future<String> _sightingIdFor(String diveId, String speciesId) async {
    final existing = await _existingSightingId(diveId, speciesId);
    if (existing != null) return existing;
    final created = await _species.addSighting(
      diveId: diveId,
      speciesId: speciesId,
    );
    return created.id;
  }
}
