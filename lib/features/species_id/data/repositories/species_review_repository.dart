import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart'
    as domain;
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/naming_level.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/services/naming_levels.dart';
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
  /// [diverId] keeps the log to that diver's dives and the media on no
  /// dive. [level] is the naming level in force, null for the pack's own
  /// bars (issue #4721), so the Suggested list matches the viewer's.
  /// [chosen] is the level the diver chose (issue #4876).
  Future<List<ReviewGroup>> load(
    ReviewScope scope, {
    required bool withSuggestions,
    String? diverId,
    LevelInForce? level,
    NamingLevel? chosen,
  }) async {
    final diveId = switch (scope) {
      DiveReviewScope(:final diveId) => diveId,
      LogReviewScope() => null,
    };
    final unconfirmed = await _tags.unconfirmedTags(
      diveId: diveId,
      diverId: diverId,
    );
    // The level the diver chose: a run that kept its pack's naming bars is
    // named by them at it, with or without a pack here (issue #4876).
    final choice = chosen ?? level?.level;
    final loose = choice != null && choice != NamingLevel.surer;
    final diveMedia = diveId == null
        ? null
        : await _media.getMediaForDive(diveId);
    final open = withSuggestions
        ? (await _identifications.mediaIdsWithSuggestions(
            anyUndecided: loose,
            among: diveMedia == null ? null : [for (final m in diveMedia) m.id],
            diverId: diveId == null ? diverId : null,
          )).toSet()
        : const <String>{};

    final unconfirmedByMedia = <String, List<MediaSpeciesTag>>{};
    for (final t in unconfirmed) {
      unconfirmedByMedia.putIfAbsent(t.mediaId, () => []).add(t);
    }
    final wanted = {...unconfirmedByMedia.keys, ...open};
    final items =
        diveMedia?.where((m) => wanted.contains(m.id)).toList() ??
        await _media.getMediaByIds(wanted.toList());
    final ids = [for (final m in items) m.id];

    // The runs and rows are read in one snapshot: at a looser level the
    // rows are named again by their run's pack (issue #4721), and the rows
    // shown are the run's own (issue #4876). No track paths: the review
    // reads names, scores and decisions only.
    final (runs, stored) = await _identifications.forMediaIdsWithRuns(
      ids,
      withPaths: false,
    );
    final found = {
      for (final e in stored.entries) e.key: visibleRows(runs[e.key], e.value),
    };
    final tagged = open.isEmpty
        ? const <String, List<TaggedSpecies>>{}
        : await _identifications.taggedSpeciesFor([
            for (final id in ids)
              if (open.contains(id)) id,
          ]);
    // Read before the evidence: a species outside the catalogue is matched
    // to a crop's names by its scientific name.
    final speciesIds = {for (final t in unconfirmed) t.speciesId};
    final species = speciesIds.isEmpty
        ? const <domain.Species>[]
        : await _species.getAllSpecies(ids: speciesIds.toList());
    final speciesById = {for (final s in species) s.id: s};

    final suggestionsByMedia = <String, List<SpeciesSuggestion>>{};
    final tagEvidence = <String, TagEvidence>{};
    for (final id in ids) {
      final rows = found[id];
      if (rows == null || rows.isEmpty) continue;
      if (open.contains(id)) {
        suggestionsByMedia[id] = groupSuggestions(
          applyChosenLevel(
            rows,
            run: runs[id],
            chosen: choice,
            installed: level,
          ),
          tagged[id] ?? const [],
        );
      }
      for (final tag in unconfirmedByMedia[id] ?? const <MediaSpeciesTag>[]) {
        final evidence = _evidenceFor(
          tag,
          rows,
          scientificName: speciesById[tag.speciesId]?.scientificName,
        );
        if (evidence != null) tagEvidence[tag.id] = evidence;
      }
    }

    // Headings only: number, time and name, so no profile samples.
    final dives = {
      for (final dive in await _dives.getDivesByIdsWithoutSamples([
        ...{for (final m in items) ?m.diveId},
      ]))
        dive.id: (
          number: dive.diveNumber,
          time: dive.effectiveEntryTime,
          // As the dive's pages title it (diveTitle): its own name first.
          name: dive.effectiveName ?? dive.site?.name,
        ),
    };
    final media = [
      for (final item in items)
        ReviewMedia(
          item: item,
          diveNumber: dives[item.diveId]?.number,
          diveTime: dives[item.diveId]?.time,
          diveName: dives[item.diveId]?.name,
        ),
    ];

    return buildReviewGroups(
      media: media,
      unconfirmedByMedia: unconfirmedByMedia,
      suggestionsByMedia: suggestionsByMedia,
      speciesById: speciesById,
      tagEvidence: tagEvidence,
    );
  }

  /// The accepted identification of [tag]'s species that scored it best,
  /// with the species' own score and key in it. That is usually the crop's
  /// top name, the one the app tagged, but not always: reconcile accepts
  /// the crop that ranks a species highest when no crop names it first,
  /// and a later pack can re-name a crop whose decision stands. A crop
  /// that no longer lists the species still shows the tag, with no score.
  TagEvidence? _evidenceFor(
    MediaSpeciesTag tag,
    List<MediaIdentification> found, {
    String? scientificName,
  }) {
    final tagged = TaggedSpecies(
      speciesId: tag.speciesId,
      scientificName: scientificName,
    );
    MediaIdentification? best;
    NamedCandidate? bestNamed;
    for (final i in found) {
      if (i.decision != IdentificationDecision.accepted ||
          i.decidedSpeciesId != tag.speciesId ||
          i.top == null) {
        continue;
      }
      final named = i.candidates
          .where((c) => candidateMatches(c.candidate, tagged))
          .firstOrNull;
      // A crop that lists the species beats one that does not; between two
      // that do not, the surer crop shows the tag more clearly.
      final better =
          best == null ||
          (named != null &&
              (bestNamed == null || named.score > bestNamed.score)) ||
          (named == null &&
              bestNamed == null &&
              i.top!.score > best.top!.score);
      if (better) {
        best = i;
        bestNamed = named;
      }
    }
    if (best == null) return null;
    return (
      score: bestNamed?.score,
      identificationId: best.id,
      gbifKey: bestNamed?.candidate.gbifKey,
    );
  }
}
