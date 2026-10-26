import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';

const _log = LoggerService('ImportTrackStamp');

/// Every dive [result] wrote: the active profile's, or each profile's when
/// the import wrote to several (a download sent to another profile reports
/// its dives only through [UnifiedImportResult.diverOutcomes]).
List<String> importedDiveIdsOf(UnifiedImportResult result) => {
  ...result.importedDiveIds,
  for (final outcome in result.diverOutcomes) ...outcome.diveIds,
}.toList();

/// Stamps entry and exit GPS from recorded surface tracks onto the dives
/// [result] wrote (issue #3704), so the summary's site matching sees them.
/// Like every sweep, it fills only dives with no entry position.
///
/// Best-effort: never throws, because the dives are already imported and a
/// later sweep (Stop logging, sync, or Match on the Tracks page) retries.
Future<void> stampImportedDivesFromTracks(
  GpsTrackMatchService service,
  UnifiedImportResult result,
) async {
  final diveIds = importedDiveIdsOf(result);
  if (diveIds.isEmpty) return;
  try {
    await service.sweep(limitToIds: diveIds);
  } catch (e, stackTrace) {
    _log.warning(
      'GPS track stamping failed after import',
      error: e,
      stackTrace: stackTrace,
    );
  }
}
