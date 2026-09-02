import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/logger_service.dart';

/// SharedPreferences key holding the last sweep's epoch millis.
///
/// Per-device by nature, so it lives in prefs rather than a synced column:
/// what this device has cleaned off its own disk is not news to a peer.
const String kScratchSweepStampKey = 'storage_scratch_sweep_last_run_ms';

/// Whether a scratch sweep is due. One run per day.
///
/// A stamp far in the future can only come from a broken clock, and must not
/// suppress sweeping until real time catches up: the same defence as
/// `shouldAutoScan` and `shouldAutoVerify`.
bool shouldSweepScratch({
  required DateTime? lastSweptAt,
  required DateTime now,
}) {
  if (lastSweptAt == null) return true;
  if (lastSweptAt.isAfter(now.add(const Duration(days: 1)))) return true;
  return now.difference(lastSweptAt) >= const Duration(days: 1);
}

/// What one sweep pass reclaimed.
class ScratchSweepReport {
  const ScratchSweepReport({
    required this.filesDeleted,
    required this.bytesReclaimed,
  });

  static const empty = ScratchSweepReport(filesDeleted: 0, bytesReclaimed: 0);

  final int filesDeleted;
  final int bytesReclaimed;

  bool get isEmpty => filesDeleted == 0;

  ScratchSweepReport operator +(ScratchSweepReport other) => ScratchSweepReport(
    filesDeleted: filesDeleted + other.filesDeleted,
    bytesReclaimed: bytesReclaimed + other.bytesReclaimed,
  );
}

/// Reclaims scratch files the app writes and never removes.
///
/// Deliberately narrow. It touches only directories this app owns and fills
/// with derived or transient data, and every target is either regenerable or
/// already-consumed debris:
///
/// - `<temp>/picked` holds full copies of SAF-picked files, including large
///   archives, made so an import can read a `content://` handle. Nothing has
///   ever deleted them.
/// - `media_cache/staging` holds files whose `put()` never completed.
/// - `media_cache/transcode` holds video renditions and `.tmp` debris that
///   `deleteTranscodeArtifacts` only removes for a video upload that reaches
///   `markDone`. An abandoned upload leaves a full-size video forever.
/// - The video and PDF thumbnail directories are keyed by content hash, so a
///   file that is edited or moved orphans its old thumbnail permanently and
///   there is no way to map a thumbnail back to a source to detect it.
///
/// What it does NOT touch, and why:
///
/// - The temp root itself. Other plugins write there, and this app's own share
///   files land loose among them under names it cannot distinguish.
/// - The Documents root. It holds the database and the user's exports, which
///   are visible in the Files app on iOS.
/// - The backups directory. Every file there is a full copy of the database.
/// - `media_cache/originals`, `thumbs` and `renditions`. Those are indexed and
///   governed by their own LRU caps, which age would fight rather than help.
///
/// Ages are generous on purpose. A file being written concurrently must never
/// be swept mid-flight, and the cost of keeping debris one more day is a day
/// of disk, while the cost of deleting a live file is a broken import.
class StorageScratchSweep {
  StorageScratchSweep({
    required Future<Directory> Function() temporaryDirectory,
    required Future<Directory> Function() supportDirectory,
  }) : _temporaryDirectory = temporaryDirectory,
       _supportDirectory = supportDirectory;

  final Future<Directory> Function() _temporaryDirectory;
  final Future<Directory> Function() _supportDirectory;
  final _log = LoggerService.forClass(StorageScratchSweep);

  /// Long enough that an import or a staged write in flight is never caught.
  static const Duration pickedMaxAge = Duration(hours: 24);
  static const Duration stagingMaxAge = Duration(hours: 24);

  /// A week, because an upload retrying across days must keep its rendition.
  static const Duration transcodeMaxAge = Duration(days: 7);

  /// A month. Thumbnails are pure derived artifacts and regenerate on demand,
  /// so the only cost of reclaiming one early is rendering it again.
  static const Duration thumbnailMaxAge = Duration(days: 30);

  static const String _appDir = 'Submersion';

  /// Throws on an I/O failure the caller should see; individual unreadable
  /// entries are skipped rather than aborting the pass.
  Future<ScratchSweepReport> run({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final temp = await _temporaryDirectory();
    final support = await _supportDirectory();

    Directory appPath(List<String> segments) =>
        Directory(p.joinAll([support.path, _appDir, ...segments]));

    var report = ScratchSweepReport.empty;
    report += await _sweep(
      Directory(p.join(temp.path, 'picked')),
      pickedMaxAge,
      at,
    );
    report += await _sweep(
      appPath(['media_cache', 'staging']),
      stagingMaxAge,
      at,
    );
    report += await _sweep(
      appPath(['media_cache', 'transcode']),
      transcodeMaxAge,
      at,
    );
    report += await _sweep(appPath(['video_thumbnails']), thumbnailMaxAge, at);
    report += await _sweep(appPath(['pdf_thumbnails']), thumbnailMaxAge, at);

    if (!report.isEmpty) {
      _log.info(
        'Scratch sweep reclaimed ${report.bytesReclaimed} bytes '
        'across ${report.filesDeleted} files',
      );
    }
    return report;
  }

  /// Deletes files under [dir] last modified before [maxAge], then prunes the
  /// directories it emptied. A directory that does not exist is a no-op.
  Future<ScratchSweepReport> _sweep(
    Directory dir,
    Duration maxAge,
    DateTime now,
  ) async {
    if (!await dir.exists()) return ScratchSweepReport.empty;

    final cutoff = now.subtract(maxAge);
    final emptied = <String>{};
    var files = 0;
    var bytes = 0;

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      try {
        final stat = await entity.stat();
        if (!stat.modified.isBefore(cutoff)) continue;
        final size = stat.size;
        await entity.delete();
        files++;
        bytes += size;
        emptied.addAll(_ancestorsWithin(dir, entity.parent));
      } on FileSystemException {
        // Skip an entry that vanished or is unreadable. A file being written
        // right now is exactly the case worth losing rather than fighting.
        continue;
      }
    }

    await _pruneEmptyDirectories(emptied);
    return ScratchSweepReport(filesDeleted: files, bytesReclaimed: bytes);
  }

  /// Every directory from [from] up to, but not including, [root].
  Iterable<String> _ancestorsWithin(Directory root, Directory from) sync* {
    final stop = p.canonicalize(root.path);
    var current = p.canonicalize(from.path);
    while (current != stop && p.isWithin(stop, current)) {
      yield current;
      current = p.dirname(current);
    }
  }

  /// Removes the directories this pass emptied, deepest first. The target
  /// root itself is never a candidate: the writers expect it to exist.
  ///
  /// Only what the sweep emptied is considered. An empty directory it did not
  /// empty is not abandoned scratch: `materializePickedFiles` creates a pick's
  /// directory before it opens the destination file, so pruning on emptiness
  /// alone could delete that directory out from under the writer and fail the
  /// very import the age gates exist to protect.
  Future<void> _pruneEmptyDirectories(Set<String> paths) async {
    final ordered = paths.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final path in ordered) {
      try {
        final directory = Directory(path);
        if (await directory.list().isEmpty) await directory.delete();
      } on FileSystemException {
        continue;
      }
    }
  }
}
