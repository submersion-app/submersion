import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/species_review_rules.dart';

/// Gathers what Species to review shows (issue #4727): the app's
/// unconfirmed tags, which sync and so are here on every device, and the
/// open suggestions, which only a device that analysed the media holds.
class SpeciesReviewRepository {
  SpeciesReviewRepository({
    required MediaSpeciesRepository tags,
    required MediaIdentificationRepository identifications,
    required MediaRepository media,
    required SpeciesRepository species,
    required DiveRepository dives,
    AppDatabase? database,
  }) : _database = database,
       _tags = tags,
       _identifications = identifications,
       _media = media,
       _species = species,
       _dives = dives;

  final MediaSpeciesRepository _tags;
  final MediaIdentificationRepository _identifications;
  final MediaRepository _media;
  final SpeciesRepository _species;
  final DiveRepository _dives;
  final AppDatabase? _database;

  AppDatabase get _db => _database ?? DatabaseService.instance.database;

  /// Ticks on any write the review reads: tags, identifications, media,
  /// species and dives.
  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.onAllTables([
      _db.mediaSpecies,
      _db.mediaIdentifications,
      _db.media,
      _db.species,
      _db.dives,
    ]),
  );

  /// What [scope] has to review. [withSuggestions] is false where marine
  /// life identification is off: the app's tags are still listed.
  Future<List<ReviewGroup>> load(
    ReviewScope scope, {
    required bool withSuggestions,
  }) async {
    final diveId = switch (scope) {
      DiveReviewScope(:final diveId) => diveId,
      LogReviewScope() => null,
    };
    final unconfirmed = await _tags.unconfirmedTags(diveId: diveId);
    final suggestible = withSuggestions
        ? (await _identifications.mediaIdsWithSuggestions()).toSet()
        : const <String>{};

    final items = <MediaItem>[];
    if (diveId != null) {
      items.addAll(await _media.getMediaForDive(diveId));
    } else {
      final ids = {for (final t in unconfirmed) t.mediaId, ...suggestible};
      for (final id in ids) {
        final item = await _media.getMediaById(id);
        if (item != null) items.add(item);
      }
    }

    final unconfirmedByMedia = <String, List<MediaSpeciesTag>>{};
    for (final t in unconfirmed) {
      unconfirmedByMedia.putIfAbsent(t.mediaId, () => []).add(t);
    }
    final suggestionsByMedia = <String, List<SpeciesSuggestion>>{};
    final tagEvidence = <String, ({double score, String identificationId})>{};
    for (final item in items) {
      final open = suggestible.contains(item.id);
      final appTags = unconfirmedByMedia[item.id] ?? const [];
      if (!open && appTags.isEmpty) continue;
      final found = await _identifications.forMedia(item.id);
      if (found.isEmpty) continue;
      if (open) {
        suggestionsByMedia[item.id] = groupSuggestions(
          found,
          await _identifications.taggedSpecies(item.id),
        );
      }
      for (final tag in appTags) {
        final evidence = _evidenceFor(tag, found);
        if (evidence != null) tagEvidence[tag.id] = evidence;
      }
    }

    final speciesIds = {for (final t in unconfirmed) t.speciesId};
    final species = speciesIds.isEmpty
        ? const []
        : await _species.getAllSpecies(ids: speciesIds.toList());

    final media = <ReviewMedia>[];
    final dives = <String, ({int? number, DateTime? time, String? site})>{};
    for (final item in items) {
      final id = item.diveId;
      if (id != null && !dives.containsKey(id)) {
        final dive = await _dives.getDiveById(id);
        dives[id] = (
          number: dive?.diveNumber,
          time: dive?.effectiveEntryTime,
          site: dive?.site?.name,
        );
      }
      final dive = id == null ? null : dives[id];
      media.add(
        ReviewMedia(
          item: item,
          diveNumber: dive?.number,
          diveTime: dive?.time,
          siteName: dive?.site,
        ),
      );
    }

    return buildReviewGroups(
      media: media,
      unconfirmedByMedia: unconfirmedByMedia,
      suggestionsByMedia: suggestionsByMedia,
      speciesById: {for (final s in species) s.id: s},
      tagEvidence: tagEvidence,
    );
  }

  /// The accepted identification of [tag]'s species that scored best.
  ({double score, String identificationId})? _evidenceFor(
    MediaSpeciesTag tag,
    List<MediaIdentification> found,
  ) {
    MediaIdentification? best;
    for (final i in found) {
      if (i.decision != IdentificationDecision.accepted ||
          i.decidedSpeciesId != tag.speciesId ||
          i.top == null) {
        continue;
      }
      if (best == null || i.top!.score > best.top!.score) best = i;
    }
    return best == null
        ? null
        : (score: best.top!.score, identificationId: best.id);
  }
}
