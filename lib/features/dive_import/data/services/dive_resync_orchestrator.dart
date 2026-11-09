import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/services/dive_reimport_service.dart';
import 'package:submersion/features/dive_import/data/services/stored_source_dive_finder.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
import 'package:submersion/features/dive_import/domain/dive_resync_failure.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/demo_mode/domain/demo_sealed_feature.dart';

class DiveResyncOutcome {
  final bool succeeded;

  /// Why the resync did not land, for the page to phrase in the diver's
  /// language. Null on success.
  final DiveResyncFailure? failureReason;

  /// See [DiveReimportResult.profilePreserved] -- the resync landed, but the
  /// profile was deliberately left as it was.
  final bool profilePreserved;

  const DiveResyncOutcome.success({this.profilePreserved = false})
    : succeeded = true,
      failureReason = null;
  const DiveResyncOutcome.failure(this.failureReason)
    : succeeded = false,
      profilePreserved = false;
}

/// Re-parses the file a dive was originally imported from (the stored
/// `imported_files` row) and applies the result through
/// [DiveReimportService].
///
/// [StoredSourceDiveFinder] finds the dive inside that file (by content, and
/// by the stored diver key for a logbook several divers share) and says why
/// when it cannot; this class adds the demo gate and the write.
class DiveResyncOrchestrator {
  final AppDatabase db;
  final ImportedFileRepository importedFiles;
  final ImportParser Function(ImportFormat) parserFor;
  final DiveReimportService _writer;

  DiveResyncOrchestrator({
    required this.db,
    ImportedFileRepository? importedFiles,
    ImportParser Function(ImportFormat)? parserFor,
    DiveReimportService? writer,
  }) : importedFiles = importedFiles ?? ImportedFileRepository(),
       parserFor = parserFor ?? parserForFormat,
       _writer = writer ?? DiveReimportService(db: db);

  Future<DiveResyncOutcome> resync(String diveId) async {
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.diveComputerDownload);
    final lookup = await StoredSourceDiveFinder(
      db: db,
      importedFiles: importedFiles,
      parserFor: parserFor,
    ).find(diveId);
    final best = lookup.parsedDive;
    if (best == null) return DiveResyncOutcome.failure(lookup.failure);

    final result = await _writer.applyReimport(
      diveId: diveId,
      diveData: best,
      now: DateTime.now(),
    );
    if (!result.updated) {
      return DiveResyncOutcome.failure(result.skippedReason);
    }
    return DiveResyncOutcome.success(profilePreserved: result.profilePreserved);
  }
}
