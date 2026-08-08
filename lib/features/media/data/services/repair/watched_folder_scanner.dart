import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repair_log_repository.dart';
import 'package:submersion/features/media/data/repositories/watched_folder_repository.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';

/// Whether an automatic scan is due (Media section Phase 5).
///
/// One run per day. A stamp far in the future can only come from a broken
/// clock, and must not suppress scanning until real time catches up -- same
/// defense as the media store's `shouldAutoVerify`.
bool shouldAutoScan({required DateTime? lastScanAt, required DateTime now}) {
  if (lastScanAt == null) return true;
  if (lastScanAt.isAfter(now.add(const Duration(days: 1)))) return true;
  return now.difference(lastScanAt) >= const Duration(days: 1);
}

/// What one scan pass did.
class WatcherScanReport {
  const WatcherScanReport({
    required this.filesIndexed,
    required this.rehashed,
    required this.autoRepaired,
  });

  final int filesIndexed;
  final int rehashed;
  final int autoRepaired;
}

/// Maintains the watched-folder index and auto-repairs missing media whose
/// bytes turn up under a watched root (Media section Phase 5).
///
/// Only EXACT content-hash matches are applied without asking: identical
/// bytes at a new path is the one case where the answer cannot be wrong.
/// Everything else is left to the repair wizard, which shows its evidence.
class WatchedFolderScanner {
  WatchedFolderScanner({
    required this.watched,
    required this.repair,
    required this.loadMissingRows,
    required this.isAutoApplyEnabled,
  });

  final WatchedFolderRepository watched;
  final MediaRepairService repair;
  final Future<List<MediaItem>> Function() loadMissingRows;

  /// Whether exact-hash matches may be applied without asking, resolved when
  /// the scan runs rather than when the scanner is built.
  ///
  /// This is deliberately a callback: the setting lives in the database, and
  /// a scanner constructed from a not-yet-loaded default would silently
  /// auto-repair for someone who had opted out. When false the index still
  /// updates but nothing is repaired -- the spec's suggest-only mode.
  final Future<bool> Function() isAutoApplyEnabled;

  static const _log = LoggerService('WatchedFolderScanner');

  Future<WatcherScanReport> scan({required DateTime now}) async {
    var filesIndexed = 0;
    var rehashed = 0;

    for (final root in await watched.getRoots()) {
      final dir = Directory(root);
      if (!await dir.exists()) {
        _log.warning('Watched root missing: $root');
        continue;
      }

      final stored = await watched.indexForRoot(root);
      final seen = <String>{};
      var listingComplete = true;

      try {
        await for (final entity in dir.list(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is! File) continue;
          // p.relative handles the platform separator and a root written
          // with a trailing one. Hand-rolled prefix stripping produced the
          // whole absolute path on Windows, which then got written into
          // media.local_path as a healthy pointer to nothing.
          final relative = p.relative(entity.path, from: root);
          seen.add(relative);
          filesIndexed++;

          final stat = await entity.stat();
          final mtime = stat.modified.millisecondsSinceEpoch;
          final previous = stored[relative];
          final unchanged =
              previous != null &&
              previous.contentHash != null &&
              previous.sizeBytes == stat.size &&
              previous.mtimeMillis == mtime;
          if (unchanged) continue;

          // Changed, new, or never hashed: this is the only path that pays
          // for a full read.
          final digest = await sha256OfFile(entity);
          rehashed++;
          await watched.upsertIndexed(
            IndexedFile(
              rootPath: root,
              relativePath: relative,
              sizeBytes: digest.sizeBytes,
              mtimeMillis: mtime,
              contentHash: digest.hash,
            ),
          );
        }
      } on FileSystemException catch (e) {
        // Partial coverage is fine: an unreadable subtree just contributes
        // nothing this pass. But `seen` is now incomplete, so pruning
        // against it would delete index rows for files that still exist.
        listingComplete = false;
        _log.warning('Watched scan failed under $root: $e');
      }

      if (listingComplete) {
        await watched.deleteIndexed(root, stored.keys.toSet().difference(seen));
      }
      // Stamped even after a partial listing, on purpose. The stamp drives
      // the daily cadence, and the cadence gate treats a null stamp as
      // "due" -- so skipping it for a root that is permanently unreadable
      // would re-walk the whole archive every time the Media console
      // builds. Nothing is lost by stamping: everything reachable was
      // indexed, auto-repair still runs against it below, and the only
      // consequence of the skipped prune is that stale index rows survive
      // one more day.
      await watched.stampScanned(root, now);
    }

    if (!await isAutoApplyEnabled()) {
      return WatcherScanReport(
        filesIndexed: filesIndexed,
        rehashed: rehashed,
        autoRepaired: 0,
      );
    }

    final missingRows = await loadMissingRows();
    final wanted = {
      for (final row in missingRows)
        if (row.contentHash != null) row.contentHash!,
    };
    // Looked up by the hashes actually needed rather than loading the whole
    // index: memory stays bounded by the missing rows, not the archive.
    final byHash = await watched.pathsForHashes(wanted);
    final proposals = <RepairProposal>[];
    for (final row in missingRows) {
      final hash = row.contentHash;
      if (hash == null) continue;
      final found = byHash[hash];
      if (found == null) continue;
      // The index says these bytes are here; confirm the file before
      // rewriting a pointer that will be marked healthy.
      if (!await File(found).exists()) {
        _log.warning('Indexed path vanished before repair: $found');
        continue;
      }
      proposals.add(
        RepairProposal(
          item: row,
          confidence: RepairConfidence.exact,
          candidate: RepairCandidate.file(
            path: found,
            sizeBytes: row.contentSizeBytes,
            hash: hash,
          ),
        ),
      );
    }

    if (proposals.isEmpty) {
      return WatcherScanReport(
        filesIndexed: filesIndexed,
        rehashed: rehashed,
        autoRepaired: 0,
      );
    }

    final report = await repair.apply(
      proposals,
      source: RepairLogSource.watcher,
    );
    return WatcherScanReport(
      filesIndexed: filesIndexed,
      rehashed: rehashed,
      autoRepaired: report.relinked,
    );
  }
}
