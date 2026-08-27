import 'dart:io';

import 'package:flutter/foundation.dart' show compute, immutable;
import 'package:path/path.dart' as p;

import 'package:submersion/core/services/media_store/store_keys.dart';

/// Default ceiling on time spent hashing in one pass (issue #1182).
///
/// Wall clock rather than a file count on purpose: a count that finishes in
/// seconds against a local SSD is an hour against a NAS export, so a count
/// cannot bound the thing that actually hurts. A deadline self-scales, and
/// fast hardware still finishes an ordinary library in a single pass.
const Duration kDefaultHashBudget = Duration(seconds: 60);

/// What the index already knows about one file, as the walk needs it.
///
/// A plain record rather than `IndexedFile` so nothing from the drift layer
/// has to be sendable to (or imported by) the background isolate.
@immutable
class KnownFile {
  const KnownFile({
    required this.sizeBytes,
    required this.mtimeMillis,
    required this.contentHash,
  });

  final int sizeBytes;
  final int mtimeMillis;

  /// Null when the file is known but has never been hashed, which forces a
  /// hash on the next pass regardless of its stat.
  final String? contentHash;
}

/// One root to walk, plus everything needed to decide what to hash.
@immutable
class WatchedFolderWalkRequest {
  const WatchedFolderWalkRequest({
    required this.rootPath,
    required this.known,
    required this.hashBudget,
  });

  final String rootPath;

  /// The stored index for this root, keyed by relative path. Passed in so the
  /// "unchanged, skip the hash" decision happens inside the isolate: sending
  /// every candidate back to be filtered would put the whole archive on the
  /// message channel.
  final Map<String, KnownFile> known;

  /// Ceiling on time spent hashing. See [kDefaultHashBudget].
  final Duration hashBudget;
}

/// One file the walk decided the index should change for.
@immutable
class WalkedFile {
  const WalkedFile({
    required this.relativePath,
    required this.sizeBytes,
    required this.mtimeMillis,
    required this.contentHash,
  });

  final String relativePath;
  final int sizeBytes;
  final int mtimeMillis;

  /// Null when the budget denied the hash. Only ever null for a file that
  /// was already indexed WITH a hash and has since changed: writing the new
  /// stat with a null hash retires a digest that no longer describes the
  /// bytes, which matters because the auto-repair pass rewrites
  /// `media.local_path` on an exact hash match. A null hash is inert there
  /// (`pathsForHashes` matches with SQL `IN`, which never matches NULL) and
  /// forces a re-hash next pass.
  final String? contentHash;
}

/// What one walk found.
@immutable
class WatchedFolderWalkResult {
  const WatchedFolderWalkResult({
    required this.changed,
    required this.vanished,
    required this.filesSeen,
    required this.listingComplete,
    required this.hashBudgetExhausted,
  });

  /// Index rows to write. Bounded by what actually changed, not by the size
  /// of the tree.
  final List<WalkedFile> changed;

  /// Index entries whose file was NOT found this pass: the prune list.
  ///
  /// Computed here rather than by returning every path seen. The caller needs
  /// `known.keys - seen`, and that difference is normally empty, whereas
  /// `seen` is the size of the whole tree -- which would cross the message
  /// channel and be deserialized ON THE UI ISOLATE, work proportional to the
  /// archive and exactly what moving the walk off it was meant to avoid.
  ///
  /// Always empty when [listingComplete] is false: a partial listing did not
  /// reach every file, so a path missing from it may still exist. Enforced
  /// here rather than left to the caller, both because the difference would
  /// be meaningless and because it would be unboundedly large.
  final Set<String> vanished;

  final int filesSeen;

  /// False when the listing threw part-way (an unreadable subtree, a root
  /// that vanished), which is why [vanished] is empty in that case: a file
  /// the listing never reached is not a file that is gone.
  final bool listingComplete;

  /// True when at least one file went un-hashed for want of budget. Does not
  /// affect pruning: the budget only ever denies a hash, never a listing.
  final bool hashBudgetExhausted;

  /// How many files were actually hashed this pass.
  int get hashedCount => changed.where((f) => f.contentHash != null).length;
}

/// Runs [walkWatchedFolder] on a background isolate.
///
/// The production seam. Before #1182 the walk, the per-file `stat` and the
/// SHA-256 of every new or changed file all ran on the UI isolate, kicked
/// from `MediaSectionPage.build()`. `sha256OfFile` yields between chunks so
/// it never blocked outright, but it competed for the same event loop as
/// every frame, and the recursive listing saturated the `dart:io` thread pool
/// that drift's SQLite depends on -- so a large watched tree took the
/// database down with the gallery.
///
/// `compute` with a single sendable argument follows the convention already
/// set by `ExifExtractor` and `ImageResizeJob`.
Future<WatchedFolderWalkResult> walkWatchedFolderInIsolate(
  WatchedFolderWalkRequest request,
) => compute(walkWatchedFolder, request);

/// Lists [WatchedFolderWalkRequest.rootPath], stats every file under it, and
/// hashes the ones that are new or whose stat has moved.
///
/// Top-level and free of drift, Riverpod and Flutter bindings so it can be a
/// `compute` entrypoint. Every database write the pass implies is left to the
/// caller, on the main isolate.
Future<WatchedFolderWalkResult> walkWatchedFolder(
  WatchedFolderWalkRequest request,
) async {
  final root = request.rootPath;
  final changed = <WalkedFile>[];
  final seen = <String>{};
  var filesSeen = 0;
  var listingComplete = true;
  var budgetExhausted = false;

  // Accumulates ONLY the time spent hashing. Budgeting the whole walk would
  // starve a large archive: re-statting the files already indexed would eat
  // the deadline before the pass reached anything new, so the same prefix
  // would be re-walked every day and the tail would never be indexed.
  // Charging the budget for hashing alone guarantees forward progress --
  // every file hashed becomes an unchanged file next pass.
  final hashing = Stopwatch();

  try {
    await for (final entity in Directory(
      root,
    ).list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      // p.relative handles the platform separator and a root written with a
      // trailing one. Hand-rolled prefix stripping produced the whole
      // absolute path on Windows, which then got written into
      // media.local_path as a healthy pointer to nothing.
      final relative = p.relative(entity.path, from: root);
      seen.add(relative);
      filesSeen++;

      final stat = await entity.stat();
      final mtime = stat.modified.millisecondsSinceEpoch;
      final previous = request.known[relative];
      final unchanged =
          previous != null &&
          previous.contentHash != null &&
          previous.sizeBytes == stat.size &&
          previous.mtimeMillis == mtime;
      if (unchanged) continue;

      if (hashing.elapsed >= request.hashBudget) {
        budgetExhausted = true;
        // A file already indexed WITH a hash has just been shown to have
        // changed. Retire that hash now even though there is no budget to
        // compute the new one -- see [WalkedFile.contentHash]. A file that
        // was never indexed has nothing stale to correct, so it is simply
        // left for the next pass.
        if (previous?.contentHash != null) {
          changed.add(
            WalkedFile(
              relativePath: relative,
              sizeBytes: stat.size,
              mtimeMillis: mtime,
              contentHash: null,
            ),
          );
        }
        continue;
      }

      // New, changed, or never hashed: the only path that pays for a full
      // read.
      hashing.start();
      final digest = await sha256OfFile(entity);
      hashing.stop();
      changed.add(
        WalkedFile(
          relativePath: relative,
          sizeBytes: digest.sizeBytes,
          mtimeMillis: mtime,
          contentHash: digest.hash,
        ),
      );
    }
  } on FileSystemException {
    // Partial coverage is fine: an unreadable subtree just contributes
    // nothing this pass. But the listing is now incomplete, so pruning
    // against it would delete index rows for files that still exist. The
    // caller reads [listingComplete] for exactly that.
    listingComplete = false;
  }

  return WatchedFolderWalkResult(
    changed: changed,
    // The difference is taken here, on this isolate, so only the rows that
    // actually need deleting travel back.
    //
    // Skipped entirely when the listing was cut short. An incomplete listing
    // has not shown that anything is gone, so the difference would be
    // meaningless -- and in the worst case (a root that threw immediately,
    // which is a watched folder on an unplugged drive) it is the ENTIRE
    // stored index, serialized across the boundary for the caller to
    // discard. That is the payload this walk exists to avoid, in the
    // commonest failure mode there is.
    vanished: listingComplete
        ? {
            for (final relative in request.known.keys)
              if (!seen.contains(relative)) relative,
          }
        : const <String>{},
    filesSeen: filesSeen,
    listingComplete: listingComplete,
    hashBudgetExhausted: budgetExhausted,
  );
}
