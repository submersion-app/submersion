import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/util/wall_clock_utc.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
import 'package:submersion/features/dive_import/domain/dive_resync_failure.dart';
import 'package:submersion/features/dive_import/domain/resyncable_import_formats.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';

/// What [StoredSourceDiveFinder.find] found: the dive as the original file
/// parses it now, or why it could not be found.
class StoredSourceLookup {
  final Map<String, dynamic>? parsedDive;
  final DiveResyncFailure? failure;

  const StoredSourceLookup.found(Map<String, dynamic> this.parsedDive)
    : failure = null;
  const StoredSourceLookup.failed(DiveResyncFailure this.failure)
    : parsedDive = null;
}

/// Finds a file-imported dive inside the original file it came from (the
/// stored `imported_files` row its primary source names), parsed fresh.
///
/// Resync replays the result onto the dive (issue #478); the transmitter
/// slot matcher reads which slot each cylinder came from (issue #4347).
///
/// The stored file may be a multi-dive logbook, so the parsed dive that
/// matches is found by content, not by position, with the same [DiveMatcher]
/// scorer the import wizard flags duplicates with. A logbook shared by
/// several divers (MacDive, issue #1893) holds each buddy dive once per
/// diver and the copies score almost identically, so the source's stored
/// `sourceDiverKey` restricts the candidates; a source imported before that
/// key was stored is refused when more than one diver has a match (#1921).
class StoredSourceDiveFinder {
  StoredSourceDiveFinder({
    required this.db,
    ImportedFileRepository? importedFiles,
    ImportParser Function(ImportFormat)? parserFor,
  }) : importedFiles = importedFiles ?? ImportedFileRepository(),
       parserFor = parserFor ?? parserForFormat;

  final AppDatabase db;
  final ImportedFileRepository importedFiles;
  final ImportParser Function(ImportFormat) parserFor;
  static const _matcher = DiveMatcher();
  static final _log = LoggerService.forClass(StoredSourceDiveFinder);

  /// [diveId] as its stored file parses it now.
  Future<StoredSourceLookup> find(String diveId) => _find(diveId, null);

  /// Each of [diveIds] found in its stored file, keyed by dive id. Each file
  /// is read and parsed once however many of the dives it holds; a dive that
  /// cannot be found, or whose file fails to parse, is left out.
  Future<Map<String, Map<String, dynamic>>> findMany(
    Iterable<String> diveIds,
  ) async {
    final parsedFiles = <String, Future<List<Map<String, dynamic>>?>>{};
    final found = <String, Map<String, dynamic>>{};
    for (final id in diveIds.toSet()) {
      try {
        final lookup = await _find(id, parsedFiles);
        if (lookup.parsedDive case final dive?) found[id] = dive;
      } catch (e, st) {
        _log.warning(
          'Could not read the stored file of dive $id',
          error: e,
          stackTrace: st,
        );
      }
    }
    return found;
  }

  Future<StoredSourceLookup> _find(
    String diveId,
    Map<String, Future<List<Map<String, dynamic>>?>>? parsedFiles,
  ) async {
    final dive = await (db.select(
      db.dives,
    )..where((t) => t.id.equals(diveId))).getSingleOrNull();
    if (dive == null) {
      return const StoredSourceLookup.failed(DiveResyncFailure.diveMissing);
    }

    final source =
        await (db.select(db.diveDataSources)
              ..where((t) => t.diveId.equals(diveId))
              ..where((t) => t.isPrimary.equals(true))
              ..limit(1))
            .getSingleOrNull();
    final storedFileId = source?.importedFileId;
    if (source == null || storedFileId == null) {
      return const StoredSourceLookup.failed(DiveResyncFailure.noStoredFile);
    }

    final format = ImportFormat.values.asNameMap()[source.sourceFileFormat];
    if (format == null || !resyncableImportFormats.contains(format)) {
      return const StoredSourceLookup.failed(
        DiveResyncFailure.unsupportedFormat,
      );
    }

    Future<List<Map<String, dynamic>>?> parse() async {
      final bytes = await importedFiles.read(storedFileId);
      if (bytes == null) return null;
      final payload = await parserFor(format).parse(bytes);
      return payload.entitiesOf(ImportEntityType.dives);
    }

    final parsed = await (parsedFiles == null
        ? parse()
        : parsedFiles.putIfAbsent(
            '$storedFileId/${format.name}',
            // A file that fails to parse is logged once and then reads as
            // missing for every dive it holds, not once per dive.
            () => parse().catchError((Object e, StackTrace st) {
              _log.warning(
                'Could not parse stored file $storedFileId',
                error: e,
                stackTrace: st,
              );
              return null;
            }),
          ));
    if (parsed == null) {
      return const StoredSourceLookup.failed(
        DiveResyncFailure.storedFileMissing,
      );
    }

    final storedDiverKey = source.sourceDiverKey;
    final candidates = [
      for (final candidate in parsed)
        if (storedDiverKey == null ||
            candidate[SourceDiver.mapKey] == storedDiverKey)
          candidate,
    ];

    // Scoring quirk worth knowing before touching thresholds: maxDepth
    // carries 30% of the weight, so a parser fix to a depth bug (the classic
    // ft/m conversion) can itself push the score under the 0.70 threshold and
    // refuse the resync it exists to deliver. The duration weight is the only
    // margin left for that, so both sides of it must measure the same
    // quantity: the candidate's total time (`runtime`, else the `duration` the
    // parsers that fill only that one emit) against the dive's own total time.
    // `dives.bottomTime` is profile-derived and excludes the ascent and its
    // shallow stops, so scoring a total time against it spends the margin on a
    // difference that is not a disagreement. It is still the fallback, because
    // a dive imported before `runtime` was filled has nothing else.
    Map<String, dynamic>? best;
    var bestScore = 0.0;
    // Every diver key with a probable match, for the no-stored-key check.
    final matchingDivers = <String?>{};
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
        existingStartTime: wallClockUtcFromMillis(dive.diveDateTime),
        existingMaxDepth: dive.maxDepth ?? 0.0,
        existingDurationSeconds: dive.runtime ?? dive.bottomTime ?? 0,
      );
      if (_matcher.isProbableDuplicate(score)) {
        matchingDivers.add(candidate[SourceDiver.mapKey] as String?);
      }
      if (score > bestScore) {
        bestScore = score;
        best = candidate;
      }
    }

    if (best == null || !_matcher.isProbableDuplicate(bestScore)) {
      return const StoredSourceLookup.failed(DiveResyncFailure.noMatchingDive);
    }
    // With a stored key every candidate is already the same diver's, so the
    // set can only exceed one entry for a source that predates the key.
    if (matchingDivers.length > 1) {
      return const StoredSourceLookup.failed(DiveResyncFailure.ambiguousDiver);
    }
    return StoredSourceLookup.found(best);
  }
}
