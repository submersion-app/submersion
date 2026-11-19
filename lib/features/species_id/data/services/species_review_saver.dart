import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/species_id/data/services/suggestion_acceptor.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/domain/entities/pack_candidate.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
import 'package:submersion/features/species_id/domain/services/identification_rules.dart';
import 'package:submersion/features/species_id/domain/value_objects/species_review_edits.dart';

/// Writes what the diver decided on Species to review (issue #4727), all
/// as one History entry. The page holds its decisions until Save, like
/// bulk edit, so nothing here needs the record unlocked.
class SpeciesReviewSaver {
  SpeciesReviewSaver({
    required SpeciesTaggingService tagging,
    required SuggestionAcceptor acceptor,
    required Future<void> Function(String mediaId, List<String> ids) dismiss,
    required Future<void> Function(String mediaId) reconcile,
    required Future<List<TaggedSpecies>> Function(String mediaId) taggedSpecies,
  }) : _tagging = tagging,
       _acceptor = acceptor,
       _dismiss = dismiss,
       _reconcile = reconcile,
       _taggedSpecies = taggedSpecies;

  final SpeciesTaggingService _tagging;
  final SuggestionAcceptor _acceptor;
  final Future<void> Function(String, List<String>) _dismiss;
  final Future<void> Function(String) _reconcile;

  /// The species tagged on a media item now, to find the tag a suggestion's
  /// species has there.
  final Future<List<TaggedSpecies>> Function(String) _taggedSpecies;

  Future<void> save(SpeciesReviewEdits edits, List<ReviewGroup> groups) {
    if (edits.isEmpty) return Future.value();
    return ChangeLogScope.bulk(
      DatabaseService.instance.databaseOrNull,
      label: ChangeLogLabels.speciesReview,
      body: () async {
        final touched = <String>{};
        for (final group in groups) {
          for (final row in [...group.tagged, ...group.suggested]) {
            for (final item in row.items) {
              final decision = edits.decisionFor(row.key, item.media.id);
              if (decision == null) continue;
              await _write(row, item, decision);
              touched.add(item.media.id);
            }
          }
        }
        for (final mediaId in touched) {
          await _reconcile(mediaId);
        }
      },
    );
  }

  /// Writes what the diver meant, keep or drop, against the media item's
  /// tag of the species as it stands now. The page holds decisions while
  /// the app or a sync may tag that species meanwhile (an auto-apply turns
  /// a suggestion into the app's tag), and Save may come before the page
  /// has read it: a held Add then confirms the app's tag, and a held
  /// Dismiss removes it.
  Future<void> _write(
    ReviewRow row,
    ReviewItem item,
    ReviewDecision decision,
  ) async {
    final mediaId = item.media.id;
    final suggestion = item.suggestion;
    final speciesId =
        item.tag?.speciesId ??
        row.speciesId ??
        await _taggedMatching(mediaId, suggestion!.top.candidate);
    final current = speciesId == null
        ? null
        : await _tagging.findTag(mediaId, speciesId);
    final appTag = current != null && current.unconfirmed;
    if (decision.keeps) {
      if (appTag) {
        await _tagging.confirmTag(mediaId: mediaId, speciesId: speciesId!);
      } else if (current == null && suggestion != null) {
        // A row of suggestions only resolves its candidate, as the sheet's
        // Add does; a row the app tagged already names its species.
        final species =
            speciesId ?? (await _acceptor.resolve(suggestion.top.candidate)).id;
        await _tagging.tagPhoto(mediaId: mediaId, speciesId: species);
      }
      // A tag the diver confirmed meanwhile is theirs already.
      return;
    }
    // Only the app's tag goes: one confirmed elsewhere since is the
    // diver's now, whatever was held here, and a suggestion's Dismiss never
    // takes a tag.
    if (appTag) {
      await _tagging.rejectTag(mediaId: mediaId, speciesId: speciesId!);
    }
    if (suggestion != null) {
      await _dismiss(mediaId, suggestion.identificationIds);
    }
  }

  /// The species tagged on [mediaId] that [candidate] names, or null.
  Future<String?> _taggedMatching(
    String mediaId,
    PackCandidate candidate,
  ) async {
    for (final tagged in await _taggedSpecies(mediaId)) {
      if (candidateMatches(candidate, tagged)) return tagged.speciesId;
    }
    return null;
  }
}
