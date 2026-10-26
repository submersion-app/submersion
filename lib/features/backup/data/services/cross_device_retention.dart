import 'dart:math';

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
/// folder, so the folder settles at the smallest count among them. Each
/// device's newest backup takes one of those N slots first (issue #3632). No
/// lock is needed between devices: every device ranks by the timestamp in the
/// name with the name breaking a tie, each removes only files outside what it
/// keeps of the folder it can see, and what the whole folder keeps is inside
/// what every device keeps.

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

/// A device's newest backup keeps a slot among the newest N only while it is
/// younger than this (issue #3632), going by its name like the ranking.
///
/// Every reinstall gets a new device tag and a retired device keeps its tag
/// for good, so a reservation that never ran out would hold a slot forever
/// for a device that is gone. Half a year covers a seasonal diver's laptop
/// sitting out the off-season. Past it, the backup is not removed outright:
/// it competes under the plain rule, so it stays until N newer ones exist.
const Duration deviceNewestReservation = Duration(days: 180);

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

  /// Backups kept as their device's newest that the plain newest N would
  /// have removed.
  final int deviceNewestKept;

  const CrossDeviceRetentionPlan({
    required this.keepCount,
    required this.toDelete,
    required this.orphanMarkers,
    required this.pinnedKept,
    required this.deviceNewestKept,
  });

  int get totalBytes =>
      toDelete.fold(0, (sum, c) => sum + (c.file.sizeBytes ?? 0));

  bool get isEmpty => toDelete.isEmpty;
}

/// Plans a prune of [listing] down to the newest [keepCount] unpinned
/// backups. A backup is pinned when any device's marker names it, or when
/// this device's history has it pinned ([locallyPinnedStems] by name,
/// [locallyPinnedFileIds] by cloud id).
///
/// Each device's newest backup takes one of the [keepCount] slots first, so
/// a device that backs up rarely is never left with none (issue #3632). A
/// device is the tag in the name; unattributed backups reserve nothing, nor
/// does a device whose newest is pinned (it is kept anyway) or older than
/// [deviceNewestReservation]. When the reserved backups alone reach
/// [keepCount], they are all kept and nothing else is.
///
/// Devices still agree without a lock: a listing missing a device's newer
/// backup reserves an older one of that device instead, which only keeps
/// more.
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

  // Ids are unique here, so each name is parsed once.
  final stamps = {
    for (final f in backups)
      f.id: backupTimestampFromName(f.name) ?? f.modifiedTime,
  };

  final unpinned = [
    for (final f in backups)
      if (!pinned(f))
        RetentionCandidate(
          file: f,
          timestamp: stamps[f.id]!,
          ownership: classifyBackupFile(
            filename: f.name,
            thisDeviceId: thisDeviceId,
          ),
        ),
  ]..sort((a, b) => _compareAge(b.file, a.file, stamps));

  // Pinned backups count here: a device whose newest is pinned already has
  // its recovery point, and reserves nothing more.
  final newestByDevice = <String, CloudFileInfo>{};
  for (final f in backups) {
    final tag = backupDeviceTagFromFilename(f.name);
    if (tag == null) continue;
    final current = newestByDevice[tag];
    if (current == null || _compareAge(f, current, stamps) > 0) {
      newestByDevice[tag] = f;
    }
  }
  final reserved = {
    for (final f in newestByDevice.values)
      if (!pinned(f) && now.difference(stamps[f.id]!) < deviceNewestReservation)
        f.id,
  };
  final rest = [
    for (final c in unpinned)
      if (!reserved.contains(c.file.id)) c,
  ];
  final openSlots = max(0, keepCount - reserved.length);

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
      for (final c in rest.skip(openSlots))
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
    deviceNewestKept: [
      for (final c in unpinned.skip(keepCount))
        if (reserved.contains(c.file.id) && !inGrace(c)) c,
    ].length,
  );
}

/// Above zero when [a] is newer than [b], by their [stamps] and then by
/// name, so every device ranks two backups stamped the same second alike,
/// whatever order its listing returned them in.
int _compareAge(
  CloudFileInfo a,
  CloudFileInfo b,
  Map<String, DateTime> stamps,
) {
  final byTime = stamps[a.id]!.compareTo(stamps[b.id]!);
  return byTime != 0 ? byTime : a.name.compareTo(b.name);
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
