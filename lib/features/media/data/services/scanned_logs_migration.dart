import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';

/// What one run of [ScannedLogsMigration] did.
enum ScannedLogsMigrationOutcome {
  /// No legacy folder on disk. The common case: a fresh install, a mobile
  /// platform, or a machine that already migrated on an earlier launch.
  noLegacyData,

  /// The legacy folder was found and processed. The counts say what
  /// happened to each page; all zero means the folder held no pages and has
  /// simply been removed.
  migrated,

  /// Nothing was moved: the documents directory could not be resolved, the
  /// destination could not be created, or every page failed. The legacy
  /// folder is untouched.
  failed,
}

/// The result of one migration run, with the paths involved so a debug log
/// can show exactly which directories were considered.
class ScannedLogsMigrationReport {
  const ScannedLogsMigrationReport({
    required this.outcome,
    this.moved = 0,
    this.skipped = 0,
    this.failed = 0,
    this.legacyPath,
    this.targetPath,
    this.error,
  });

  final ScannedLogsMigrationOutcome outcome;

  /// Pages now at the destination with their rows relinked and the legacy
  /// copy gone.
  final int moved;

  /// Pages left in the legacy folder because a DIFFERENT file already sits
  /// at their destination name. Neither copy is touched.
  final int skipped;

  /// Pages left in the legacy folder because the copy or the row relink
  /// threw. The next launch retries them.
  final int failed;

  final String? legacyPath;
  final String? targetPath;
  final Object? error;

  @override
  String toString() =>
      'ScannedLogsMigrationReport(${outcome.name}, moved: $moved, '
      'skipped: $skipped, failed: $failed, legacy: $legacyPath, '
      'target: $targetPath${error == null ? '' : ', error: $error'})';
}

/// One-time move of scanned logbook pages from `<documents>/scanned_logs/`
/// into `<documents>/Submersion/scanned_logs/` (issue #1645).
///
/// Through the release that introduced OCR import, scans were copied
/// directly under the platform documents directory. On Windows and Linux
/// that is the user's own Documents folder, so the app left a
/// `scanned_logs` folder among their personal files. Every other file the
/// app owns there sits one level down in `Submersion`; new scans now go
/// there too, and this pass brings the existing ones along.
///
/// Each page is copied, its media rows are relinked through [relocateRows],
/// and only then is the legacy copy deleted, so an interruption at any point
/// leaves the page readable from wherever its rows still point. A page whose
/// destination name is already taken by a different file is skipped rather
/// than clobbered; an identical file there is a resumed move.
///
/// Never throws. This runs fire-and-forget at startup and a failure here
/// must not break a scan or a read, so every problem is folded into the
/// report and logged.
class ScannedLogsMigration {
  ScannedLogsMigration({
    required Future<int> Function(String from, String to) relocateRows,
    Future<Directory> Function()? documentsDirectory,
    String subdirectory = kScannedLogsSubdirectory,
  }) : _relocateRows = relocateRows,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _subdirectory = subdirectory;

  /// Rewrites every media row referencing the file at `from` to `to` and
  /// returns how many it touched. `MediaRepository.relocateLocalFile` in
  /// production; a recorder in tests.
  final Future<int> Function(String from, String to) _relocateRows;
  final Future<Directory> Function() _documentsDirectory;
  final String _subdirectory;
  final _log = LoggerService.forClass(ScannedLogsMigration);

  Future<ScannedLogsMigrationReport> run() async {
    String? legacyPath;
    String? targetPath;
    try {
      final docs = await _documentsDirectory();
      final legacy = Directory(p.join(docs.path, _subdirectory));
      final target = MediaImportService.destinationDirectory(
        docs,
        _subdirectory,
      );
      legacyPath = legacy.path;
      targetPath = target.path;

      if (!await legacy.exists()) {
        return ScannedLogsMigrationReport(
          outcome: ScannedLogsMigrationOutcome.noLegacyData,
          legacyPath: legacyPath,
          targetPath: targetPath,
        );
      }

      await target.create(recursive: true);

      var moved = 0;
      var skipped = 0;
      var failed = 0;
      await for (final entity in legacy.list(followLinks: false)) {
        // Only the flat page copies the import wrote. Anything else under
        // the legacy folder was not put there by the app.
        if (entity is! File) continue;
        switch (await _movePage(entity, target)) {
          case _PageResult.moved:
            moved++;
          case _PageResult.skipped:
            skipped++;
          case _PageResult.failed:
            failed++;
        }
      }

      if (await legacy.list(followLinks: false).isEmpty) {
        await _deleteQuietly(legacy);
      }

      final report = ScannedLogsMigrationReport(
        outcome: moved == 0 && skipped == 0 && failed > 0
            ? ScannedLogsMigrationOutcome.failed
            : ScannedLogsMigrationOutcome.migrated,
        moved: moved,
        skipped: skipped,
        failed: failed,
        legacyPath: legacyPath,
        targetPath: targetPath,
      );
      _log.info('Scanned logs migration: $report');
      return report;
    } catch (e, stackTrace) {
      _log.error(
        'Scanned logs migration failed',
        error: e,
        stackTrace: stackTrace,
      );
      return ScannedLogsMigrationReport(
        outcome: ScannedLogsMigrationOutcome.failed,
        legacyPath: legacyPath,
        targetPath: targetPath,
        error: e,
      );
    }
  }

  Future<_PageResult> _movePage(File page, Directory target) async {
    final from = page.path;
    final to = p.join(target.path, p.basename(from));
    final dest = File(to);
    var copiedNow = false;
    try {
      if (await dest.exists()) {
        if (!await _sameBytes(page, dest)) {
          _log.warning(
            'Scanned page $from skipped: a different file is already at $to',
          );
          return _PageResult.skipped;
        }
        // An earlier launch copied this page and was interrupted before it
        // deleted the source. Finish that move rather than stranding the
        // legacy folder forever.
      } else {
        await page.copy(to);
        copiedNow = true;
      }

      try {
        await _relocateRows(from, to);
      } catch (_) {
        // The rows still point at the legacy copy, which is intact, so the
        // page stays readable. Drop the half-made destination so the next
        // launch starts this page clean.
        if (copiedNow) await _deleteQuietly(dest);
        rethrow;
      }

      await page.delete();
      return _PageResult.moved;
    } catch (e, stackTrace) {
      _log.error(
        'Scanned page $from could not be moved to $to',
        error: e,
        stackTrace: stackTrace,
      );
      return _PageResult.failed;
    }
  }

  /// Byte-for-byte comparison. Pages are a handful of camera JPEGs and this
  /// runs once per install, so reading both fully is cheaper than being
  /// clever about it.
  Future<bool> _sameBytes(File a, File b) async {
    if (await a.length() != await b.length()) return false;
    const eq = ListEquality<int>();
    return eq.equals(await a.readAsBytes(), await b.readAsBytes());
  }

  Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) await entity.delete();
    } catch (_) {
      // A leftover is harmless; the next launch sees it again.
    }
  }
}

enum _PageResult { moved, skipped, failed }
