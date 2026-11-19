import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/species_id/data/services/suggestion_acceptor.dart';
import 'package:submersion/features/species_id/domain/entities/species_review.dart';
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
  }) : _tagging = tagging,
       _acceptor = acceptor,
       _dismiss = dismiss,
       _reconcile = reconcile;

  final SpeciesTaggingService _tagging;
  final SuggestionAcceptor _acceptor;
  final Future<void> Function(String, List<String>) _dismiss;
  final Future<void> Function(String) _reconcile;

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

  Future<void> _write(
    ReviewRow row,
    ReviewItem item,
    ReviewDecision decision,
  ) async {
    final mediaId = item.media.id;
    switch (decision) {
      case ReviewDecision.confirm:
        await _tagging.confirmTag(
          mediaId: mediaId,
          speciesId: item.tag!.speciesId,
        );
      case ReviewDecision.remove:
        await _tagging.rejectTag(
          mediaId: mediaId,
          speciesId: item.tag!.speciesId,
        );
      case ReviewDecision.add:
        // A row the app tagged already names its species; a row of
        // suggestions only resolves the candidate, as the sheet's Add does.
        final speciesId =
            row.speciesId ??
            (await _acceptor.resolve(item.suggestion!.top.candidate)).id;
        await _tagging.tagPhoto(mediaId: mediaId, speciesId: speciesId);
      case ReviewDecision.dismiss:
        await _dismiss(mediaId, item.suggestion!.identificationIds);
    }
  }
}
