import 'package:path/path.dart' as p;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_pin_markers.dart';
import 'package:submersion/features/backup/data/services/cloud_backup_history.dart';

/// Which backups in the shared cloud folder a cross-device prune removes
/// (issue #3503). Pure: it reads a folder listing and decides; the
/// `BackupService` part that calls it does the deleting.
///
/// Every device with the switch on applies its own keep count to the whole
/// folder, so the folder settles at the smallest count among them. No lock is
/// needed between devices: each removes only files outside the newest N it
/// can see, and the folder's newest N are inside every device's newest N.

/// Nothing younger than this is removed, whatever its rank, and no pin
/// marker younger than this is treated as an orphan.
///
/// Names carry the writing device's local time, so two devices can read a
/// backup's age wrongly by up to 26 hours (UTC+14 against UTC-12). The
/// modified time, which the cloud service stamps, is checked too, so a
/// backup just uploaded is inside the grace whatever its name says. Beyond
/// the grace the skew can still order two backups from different zones the
/// wrong way round, keeping the older; the spec accepts that for a sort key
/// every device agrees on.
const Duration crossDeviceRetentionGrace = Duration(hours: 24);

/// One backup a plan removes.
class RetentionCandidate {
  final CloudFileInfo file;

  /// The timestamp in the name, else the file's modified time.
  final DateTime timestamp;

  /// Who wrote it, from the device tag in its name.
  final BackupOwnership ownership;

  const RetentionCandidate({
    required this.file,
    required this.timestamp,
    required this.ownership,
  });
}

/// What a cross-device prune with [keepCount] would remove right now.
class CrossDeviceRetentionPlan {
  final int keepCount;

  /// Newest first, so the oldest backup is last.
  final List<RetentionCandidate> toDelete;

  /// Markers whose backup is no longer in the folder.
  final List<CloudFileInfo> orphanMarkers;

  /// Backups left alone because a device has them pinned.
  final int pinnedKept;

  const CrossDeviceRetentionPlan({
    required this.keepCount,
    required this.toDelete,
    required this.orphanMarkers,
    required this.pinnedKept,
  });

  int get totalBytes =>
      toDelete.fold(0, (sum, c) => sum + (c.file.sizeBytes ?? 0));

  bool get isEmpty => toDelete.isEmpty;
}

/// Plans a prune of [listing] down to the newest [keepCount] unpinned
/// backups. A backup is pinned when any device's marker names it, or when
/// this device's history has it pinned ([locallyPinnedStems] by name,
/// [locallyPinnedFileIds] by cloud id).
CrossDeviceRetentionPlan planCrossDeviceRetention({
  required Iterable<CloudFileInfo> listing,
  required int keepCount,
  required Set<String> locallyPinnedStems,
  required Set<String> locallyPinnedFileIds,
  required String thisDeviceId,
  required DateTime now,
}) {
  final seen = <String>{};
  final backups = <CloudFileInfo>[];
  final markers = <(CloudFileInfo, PinMarker)>[];
  for (final file in listing) {
    if (!seen.add(file.id)) continue;
    final marker = parsePinMarker(file.name);
    if (marker != null) {
      markers.add((file, marker));
    } else if (_isBackup(file.name)) {
      backups.add(file);
    }
  }

  final markedStems = {for (final (_, m) in markers) m.backupStem};
  final pinnedStems = {...markedStems, ...locallyPinnedStems};
  bool pinned(CloudFileInfo f) =>
      pinnedStems.contains(backupStem(f.name)) ||
      locallyPinnedFileIds.contains(f.id);

  final unpinned = [
    for (final f in backups)
      if (!pinned(f))
        RetentionCandidate(
          file: f,
          timestamp: backupTimestampFromName(f.name) ?? f.modifiedTime,
          ownership: classifyBackupFile(
            filename: f.name,
            thisDeviceId: thisDeviceId,
          ),
        ),
  ]..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  bool inGrace(RetentionCandidate c) =>
      now.difference(c.timestamp) < crossDeviceRetentionGrace ||
      now.difference(c.file.modifiedTime) < crossDeviceRetentionGrace;

  // Any backup-like name counts here, not only the strict ones the rule
  // manages: a pinned conflicted copy keeps its marker.
  final listedStems = {
    for (final f in listing)
      if (f.name.startsWith(backupFilePrefix) &&
          backupFileExtensions.contains(p.extension(f.name)))
        backupStem(f.name),
  };
  return CrossDeviceRetentionPlan(
    keepCount: keepCount,
    toDelete: [
      for (final c in unpinned.skip(keepCount))
        if (!inGrace(c)) c,
    ],
    // A young marker may have arrived before its backup (a sync-folder
    // backend delivers the empty file first), so only an old one is gone.
    orphanMarkers: [
      for (final (file, m) in markers)
        if (!listedStems.contains(m.backupStem) &&
            now.difference(file.modifiedTime) >= crossDeviceRetentionGrace)
          file,
    ],
    pinnedKept: backups.length - unpinned.length,
  );
}

/// Exactly the names this app writes: the timestamp, an optional device tag,
/// and a backup extension. Stricter than the history listing on purpose: a
/// sync client's `(conflicted copy)` or a hand-renamed file is left for the
/// diver to judge, never removed by a rule.
final RegExp _backupName = RegExp(
  '^$backupFilePrefix\\d{4}-\\d{2}-\\d{2}_\\d{6}(__d[0-9a-f]{16})?\$',
);

bool _isBackup(String name) =>
    backupFileExtensions.contains(p.extension(name)) &&
    _backupName.hasMatch(p.basenameWithoutExtension(name));
