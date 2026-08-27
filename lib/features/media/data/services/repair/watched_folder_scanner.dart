import 'dart:io';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/media_repair_log_repository.dart';
import 'package:submersion/features/media/data/repositories/watched_folder_repository.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/data/services/repair/watched_folder_walk.dart';
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
    this.hashBudgetExhausted = false,
  });

  final int filesIndexed;
  final int rehashed;
  final int autoRepaired;

  /// True when at least one root ran out of hashing budget. The pass is still
  /// stamped, so the remainder is picked up on the next daily run -- every
  /// file hashed this pass is an unchanged file next pass, so the backlog
  /// only ever shrinks.
  final bool hashBudgetExhausted;
}

/// Walks one root and hashes what changed. Injected so tests can run the walk
/// in-process; production hands it to a background isolate.
typedef WatchedFolderWalk =
    Future<WatchedFolderWalkResult> Function(WatchedFolderWalkRequest request);

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
    WatchedFolderWalk? walk,
    this.hashBudget = kDefaultHashBudget,
  }) : walk = walk ?? walkWatchedFolderInIsolate;

  /// Where the listing, the per-file `stat` and the SHA-256 actually happen.
  ///
  /// Defaults to the background isolate. All of it used to run here, on the
  /// UI isolate, kicked from a widget `build()` (#1182).
  final WatchedFolderWalk walk;

  /// Ceiling on time spent hashing per root, per pass.
  final Duration hashBudget;

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
    var budgetExhausted = false;

    for (final root in await watched.getRoots()) {
      final dir = Directory(root);
      if (!await dir.exists()) {
        _log.warning('Watched root missing: $root');
        continue;
      }

      final stored = await watched.indexForRoot(root);

      // Everything expensive happens over there: the recursive listing, the
      // per-file stat and the SHA-256 of whatever changed. What comes back is
      // bounded by the CHANGES, not by the size of the tree, and every drift
      // write below stays on this isolate where the database lives.
      final result = await walk(
        WatchedFolderWalkRequest(
          rootPath: root,
          known: {
            for (final entry in stored.entries)
              entry.key: KnownFile(
                sizeBytes: entry.value.sizeBytes,
                mtimeMillis: entry.value.mtimeMillis,
                contentHash: entry.value.contentHash,
              ),
          },
          hashBudget: hashBudget,
        ),
      );

      filesIndexed += result.filesSeen;
      rehashed += result.hashedCount;
      if (!result.listingComplete) {
        _log.warning('Watched scan could not fully list $root');
      }
      if (result.hashBudgetExhausted) {
        budgetExhausted = true;
        _log.info(
          'Hash budget spent under $root; the rest is picked up next pass',
        );
      }

      for (final file in result.changed) {
        await watched.upsertIndexed(
          IndexedFile(
            rootPath: root,
            relativePath: file.relativePath,
            sizeBytes: file.sizeBytes,
            mtimeMillis: file.mtimeMillis,
            contentHash: file.contentHash,
          ),
        );
      }

      // Judged against the LISTING, not the hashing: the budget only ever
      // denies a hash, so a truncated pass still saw every file and pruning
      // stays safe. The walk already took the difference against `stored`, so
      // only the rows that need deleting crossed back.
      //
      // The `listingComplete` half is belt and braces -- the walk returns an
      // empty `vanished` for an incomplete listing -- but it keeps the rule
      // that governs a DESTRUCTIVE write visible at the site of that write,
      // rather than resting on a guarantee made in another isolate.
      if (result.listingComplete && result.vanished.isNotEmpty) {
        await watched.deleteIndexed(root, result.vanished);
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
        hashBudgetExhausted: budgetExhausted,
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
        hashBudgetExhausted: budgetExhausted,
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
      hashBudgetExhausted: budgetExhausted,
    );
  }
}
