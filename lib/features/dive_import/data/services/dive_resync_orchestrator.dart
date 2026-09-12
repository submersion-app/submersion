import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_import/data/services/dive_reimport_service.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
import 'package:submersion/features/dive_import/domain/dive_resync_failure.dart';
import 'package:submersion/features/dive_import/domain/resyncable_import_formats.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';

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
/// The stored file may be a multi-dive logbook, so the parsed dive that
/// matches the target dive is found by content, not by position -- this
/// reuses the same [DiveMatcher] scorer the import wizard already uses to
/// flag duplicates, rather than inventing a second matching algorithm.
class DiveResyncOrchestrator {
  final AppDatabase db;
  final ImportedFileRepository importedFiles;
  final ImportParser Function(ImportFormat) parserFor;
  final DiveReimportService _writer;
  static const _matcher = DiveMatcher();

  DiveResyncOrchestrator({
    required this.db,
    ImportedFileRepository? importedFiles,
    ImportParser Function(ImportFormat)? parserFor,
    DiveReimportService? writer,
  }) : importedFiles = importedFiles ?? ImportedFileRepository(),
       parserFor = parserFor ?? parserForFormat,
       _writer = writer ?? DiveReimportService(db: db);

  Future<DiveResyncOutcome> resync(String diveId) async {
    final dive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    if (dive == null) {
      return const DiveResyncOutcome.failure(DiveResyncFailure.diveMissing);
    }

    final source =
        await (db.select(db.diveDataSources)
              ..where((t) => t.diveId.equals(diveId))
              ..where((t) => t.isPrimary.equals(true))
              ..limit(1))
            .getSingleOrNull();
    final storedFileId = source?.importedFileId;
    if (source == null || storedFileId == null) {
      return const DiveResyncOutcome.failure(DiveResyncFailure.noStoredFile);
    }

    final format = ImportFormat.values.asNameMap()[source.sourceFileFormat];
    if (format == null || !resyncableImportFormats.contains(format)) {
      return const DiveResyncOutcome.failure(
        DiveResyncFailure.unsupportedFormat,
      );
    }

    final bytes = await importedFiles.read(storedFileId);
    if (bytes == null) {
      return const DiveResyncOutcome.failure(
        DiveResyncFailure.storedFileMissing,
      );
    }

    final payload = await parserFor(format).parse(bytes);
    final candidates = payload.entitiesOf(ImportEntityType.dives);

    // Scoring quirk worth knowing before touching thresholds: maxDepth
    // carries 30% of the weight, so a parser fix to a depth bug (the classic
    // ft/m conversion) can itself push the score under the 0.70 threshold and
    // refuse the resync it exists to deliver. The duration weight is the only
    // margin left for that, so both sides of it must measure the same
    // quantity: the candidate's total time (`runtime`, else the `duration` the
    // parsers that fill only that one emit) against the dive's own total time.
    // `dives.bottomTime` is profile-derived and excludes the ascent and every
    // stop, so scoring a total time against it spends the margin on a
    // difference that is not a disagreement. It is still the fallback, because
    // a dive imported before `runtime` was filled has nothing else.
    Map<String, dynamic>? best;
    var bestScore = 0.0;
    for (final candidate in candidates) {
      final candidateTime = candidate['dateTime'] as DateTime?;
      if (candidateTime == null) continue;
      final candidateDepth = (candidate['maxDepth'] as num?)?.toDouble() ?? 0.0;
      final candidateDuration =
          ((candidate['runtime'] ?? candidate['duration']) as Duration?)
              ?.inSeconds ??
          0;
      final score = _matcher.calculateMatchScore(
        wearableStartTime: candidateTime,
        wearableMaxDepth: candidateDepth,
        wearableDurationSeconds: candidateDuration,
        existingStartTime: DateTime.fromMillisecondsSinceEpoch(
          dive.diveDateTime,
        ),
        existingMaxDepth: dive.maxDepth ?? 0.0,
        existingDurationSeconds: dive.runtime ?? dive.bottomTime ?? 0,
      );
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    if (best == null || !_matcher.isProbableDuplicate(bestScore)) {
      return const DiveResyncOutcome.failure(DiveResyncFailure.noMatchingDive);
    }

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
