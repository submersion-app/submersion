import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/gps_log/data/services/gps_track_match_service.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';

const _log = LoggerService('ImportTrackStamp');

/// Every dive [result] wrote: the active profile's, or each profile's when
/// the import wrote to several (a download sent to another profile reports
/// its dives only through [UnifiedImportResult.diverOutcomes]), and the
/// dives already in the log that it merged a download into.
List<String> _writtenDiveIdsOf(UnifiedImportResult result) => {
  ...result.importedDiveIds,
  for (final outcome in result.diverOutcomes) ...outcome.diveIds,
  ...result.updatedExistingDiveIds,
}.toList();

/// Stamps entry and exit GPS from recorded surface tracks onto the dives
/// [result] wrote (issue #3704), so the summary's site matching sees them.
/// Like every sweep, it fills only dives with no entry position. Returns the
/// ids of the dives it positioned.
///
/// Best-effort: never throws, because the dives are already imported and a
/// later sweep (Stop logging, sync, or Match on the Tracks page) retries.
Future<List<String>> stampImportedDivesFromTracks(
  GpsTrackMatchService service,
  UnifiedImportResult result,
) async {
  final diveIds = _writtenDiveIdsOf(result);
  if (diveIds.isEmpty) return const [];
  try {
    return await service.sweep(limitToIds: diveIds);
  } catch (e, stackTrace) {
    _log.warning(
      'GPS track stamping failed after import',
      error: e,
      stackTrace: stackTrace,
    );
    return const [];
  }
}
