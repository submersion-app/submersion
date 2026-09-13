import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/import_wizard/domain/models/import_notice.dart';

const _log = LoggerService('diveNumberConflictNotice');

/// The notice for imported dives that kept a source dive number another dive
/// already uses, or null when there is nothing to report.
///
/// Only a run with "Retain source dive numbers" on can produce a clash: auto
/// numbering always takes the next free number. Retained numbers are kept as
/// the diver asked rather than silently changed, so the summary says which
/// dives clash instead (issue #1832).
///
/// Best-effort: it runs after the dives are saved, so a failed check is
/// logged and dropped rather than turning a successful import into an error.
Future<ImportNotice?> diveNumberConflictNotice({
  required bool retainSourceDiveNumbers,
  required DiveRepository diveRepository,
  required List<String> importedDiveIds,
}) async {
  if (!retainSourceDiveNumbers || importedDiveIds.isEmpty) return null;
  final int clashes;
  try {
    clashes = await diveRepository.countDivesSharingDiveNumber(importedDiveIds);
  } catch (e, stackTrace) {
    _log.warning(
      'Could not check imported dives for clashing dive numbers',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
  if (clashes == 0) return null;
  return ImportNotice(
    kind: ImportNoticeKind.diveNumberConflict,
    affectedDives: clashes,
  );
}
