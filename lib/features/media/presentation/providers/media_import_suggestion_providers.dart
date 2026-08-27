import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/services/dive_link_matcher.dart';
import 'package:submersion/features/media/domain/services/dive_photo_matcher.dart';

/// Match verdict for one capture timestamp, plus the dive number the review
/// row shows for a confident match.
class ImportSuggestion {
  const ImportSuggestion({required this.match, this.diveNumber});

  final TimestampMatch match;
  final int? diveNumber;
}

/// Suggestion for a capture timestamp (wall-clock UTC). Keyed by the
/// timestamp rather than a media id because nothing has been inserted yet:
/// the review runs BEFORE any row exists.
///
/// Subscribes to the DIVES tick: the verdict is a join of this timestamp
/// against the dives in its window, so it goes stale when the candidate set
/// moves underneath it (a consolidation, a bulk delete, a sync pull).
final importSuggestionProvider =
    FutureProvider.family<ImportSuggestion, DateTime>((ref, takenAt) async {
      final diveRepository = ref.watch(diveRepositoryProvider);
      ref.invalidateSelfWhen(diveRepository.watchDivesChanges());

      final dives = await diveRepository.getDivesInRange(
        takenAt.subtract(DiveLinkMatcher.window),
        takenAt.add(DiveLinkMatcher.window),
        diverId: ref.read(currentDiverIdProvider),
      );
      final match = DiveLinkMatcher.matchAgainst(
        takenAt: takenAt,
        candidateDives: dives,
      );
      final number = match.diveId == null
          ? null
          : dives.where((d) => d.id == match.diveId).firstOrNull?.diveNumber;
      return ImportSuggestion(match: match, diveNumber: number);
    });
