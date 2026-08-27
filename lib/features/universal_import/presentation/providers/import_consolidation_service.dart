import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/universal_import/data/services/import_duplicate_checker.dart';

const _log = LoggerService('ImportConsolidationService');

/// Result of [performConsolidations]: how many indices were folded
/// successfully vs. how many failed and were compensated.
class ConsolidationSummary {
  const ConsolidationSummary({
    required this.consolidated,
    required this.failed,
    this.removedDiveIds = const {},
  });

  /// Number of dives successfully folded into their matched dive.
  final int consolidated;

  /// Number of dives whose fold failed unexpectedly after having already
  /// been imported as a standalone dive. Each one was deleted (see
  /// [performConsolidations]) rather than left stranded.
  final int failed;

  /// The freshly-imported standalone dive ids that are NO LONGER present after
  /// this call -- each was either folded into its match (and tombstoned by
  /// [DiveConsolidationService.apply]) or removed by the compensating delete.
  ///
  /// A dive whose fold AND compensating delete both failed is intentionally
  /// absent: it is still standalone in the DB, so the caller must keep
  /// reporting it as imported instead of hiding a stranded duplicate.
  final Set<String> removedDiveIds;
}

/// Folds consolidate-flagged imported dives into their matched existing
/// dives.
///
/// The dives at [indices] have already been persisted as full standalone
/// dives (via `UddfEntityImporter.import`, in the same call as the rest of
/// the payload's dive selection, so cross-references to trips/sites/buddies
/// from this import resolve correctly) -- [diveIdByIndex] maps each source
/// index to the id that import produced. This function folds each of those
/// freshly-imported dives into the dive matched by [duplicateResult] via
/// [DiveConsolidationService.apply], which carries over every sample
/// column, tank, pressure, and event with attribution, then tombstones the
/// now-redundant standalone dive.
///
/// The import (above, before this function runs) and the fold are not part
/// of the same transaction. If [DiveConsolidationService.apply] throws for
/// one index, the freshly-imported standalone dive at that index is deleted
/// via [DiveRepository.bulkDeleteDives] (tombstone-honoring) so it doesn't
/// strand as a bare, unconsolidated duplicate, and the loop continues with
/// the remaining indices rather than aborting the whole import.
Future<ConsolidationSummary> performConsolidations({
  required Set<int> indices,
  required Map<int, String> diveIdByIndex,
  required ImportDuplicateResult? duplicateResult,
  required DiveConsolidationService consolidationService,
  required DiveRepository diveRepository,
}) async {
  var consolidated = 0;
  var failed = 0;
  final removedDiveIds = <String>{};

  for (final index in indices) {
    final matchResult = duplicateResult?.diveMatchFor(index);
    if (matchResult == null) continue;

    final newDiveId = diveIdByIndex[index];
    if (newDiveId == null) continue;

    try {
      await consolidationService.apply(
        targetDiveId: matchResult.diveId,
        secondaryDiveIds: [newDiveId],
      );
      consolidated++;
      // The fold tombstoned the standalone dive.
      removedDiveIds.add(newDiveId);
    } catch (e, st) {
      _log.error(
        'Consolidation fold failed for dive into ${matchResult.diveId}',
        error: e,
        stackTrace: st,
      );
      try {
        await diveRepository.bulkDeleteDives([newDiveId]);
        // The compensating delete removed the standalone dive.
        removedDiveIds.add(newDiveId);
      } catch (deleteError, deleteStack) {
        // The compensating delete failed too -- log it and continue rather
        // than rethrow, so the remaining indices are still processed instead
        // of aborting the whole import. The dive is deliberately left OUT of
        // [removedDiveIds] because it is still standalone in the DB; the caller
        // must keep counting it as imported rather than hiding a duplicate.
        _log.error(
          'Compensating delete failed for orphaned dive $newDiveId',
          error: deleteError,
          stackTrace: deleteStack,
        );
      }
      failed++;
    }
  }

  return ConsolidationSummary(
    consolidated: consolidated,
    failed: failed,
    removedDiveIds: removedDiveIds,
  );
}
