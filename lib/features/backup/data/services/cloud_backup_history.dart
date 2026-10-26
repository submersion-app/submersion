import 'package:path/path.dart' as p;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/features/backup/data/services/backup_attribution.dart';
import 'package:submersion/features/backup/data/services/backup_pin_markers.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';

/// Cloud backups the local history has no record of (issue #3214).
///
/// The history is a SharedPreferences ledger, so a fresh install starts it
/// empty while the connected cloud folder still holds every backup the
/// previous install uploaded. These helpers turn that folder listing into
/// history rows for display.
///
/// The rows are never written back. Retention pruning works off the stored
/// history and deletes the cloud copy with the record, and the backup folder
/// is shared by every device on the account, so persisting what the listing
/// found would let the next backup on this device delete another device's
/// backups. A diver who wants one tracked pins it, which adopts it as a
/// pinned record (see `BackupService.pinRecord`).

const String _backupPrefix = 'submersion_backup_';

/// The prefix of the id given to a row built from a cloud listing.
const String cloudBackupIdPrefix = 'cloud:';

/// `submersion_backup_yyyy-MM-dd_HHmmss`, the timestamp every backup name
/// starts with, in the local time of the device that wrote it.
final RegExp _nameTimestamp = RegExp(
  r'^submersion_backup_(\d{4})-(\d{2})-(\d{2})_(\d{2})(\d{2})(\d{2})',
);

/// A history row for [file], or null when it is not a backup. [accountId]
/// is the account the listing came from.
///
/// Dive and site counts are left null: they lived only in the lost record,
/// and the file would have to be downloaded to recount them.
BackupRecord? backupRecordFromCloudFile(
  CloudFileInfo file, {
  String? accountId,
}) {
  final name = file.name;
  if (!name.startsWith(_backupPrefix)) return null;
  if (!backupFileExtensions.contains(p.extension(name))) return null;

  return BackupRecord(
    // Stable across listings, so a pinned (adopted) row keeps its identity.
    id: '$cloudBackupIdPrefix${file.id}',
    filename: name,
    timestamp: backupTimestampFromName(name) ?? file.modifiedTime,
    sizeBytes: file.sizeBytes ?? 0,
    location: BackupLocation.cloud,
    cloudFileId: file.id,
    cloudAccountId: accountId,
  );
}

/// [history] plus a row for every backup in [cloudFiles] it does not already
/// account for, newest first.
///
/// A cloud file is accounted for when a record names its id, or when a record
/// has the same name apart from the extension: with sync encryption on, a
/// local `X.db` is uploaded as `X.sbe`. Discovered rows note [accountId],
/// the account the listing came from.
List<BackupRecord> mergeCloudBackups(
  List<BackupRecord> history,
  Iterable<CloudFileInfo> cloudFiles, {
  String? accountId,
}) {
  final knownIds = {for (final r in history) ?r.cloudFileId};
  // A name says "this backup" only within one account: a record whose copy
  // is noted in another account cannot account for a file listed here.
  final knownStems = {
    for (final r in history)
      if (r.cloudAccountId == null || r.cloudAccountId == accountId)
        p.basenameWithoutExtension(r.filename),
  };

  // `add` returns false for an id already seen: a legacy Drive file with two
  // parents comes back from two of the duplicate-folder queries.
  final seenIds = <String>{};
  final discovered = [
    for (final file in cloudFiles)
      if (!knownIds.contains(file.id) &&
          !knownStems.contains(p.basenameWithoutExtension(file.name)) &&
          seenIds.add(file.id))
        ?backupRecordFromCloudFile(file, accountId: accountId),
  ];
  if (discovered.isEmpty) return history;

  return [...history, ...discovered]
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
}

/// [rows] with every cloud row another device has pinned marked as such
/// (issue #3503), read from the pin markers in [listing]. Only rows found in
/// the listing are marked: a row in this device's history stays pinnable
/// here, and a row pinned here already shows its own pin. When
/// [thisDeviceId] is unknown, a marker cannot be told apart from this
/// device's own, so none is read.
List<BackupRecord> markPinnedOnAnotherDevice(
  List<BackupRecord> rows,
  Iterable<CloudFileInfo> listing, {
  required String? thisDeviceId,
}) {
  if (thisDeviceId == null) return rows;
  final myTag = deviceTag(thisDeviceId);
  final elsewhere = {
    for (final f in listing)
      if (parsePinMarker(f.name) case final m? when m.deviceTag != myTag)
        m.backupStem,
  };
  if (elsewhere.isEmpty) return rows;
  return [
    for (final r in rows)
      !r.pinned &&
              r.id.startsWith(cloudBackupIdPrefix) &&
              elsewhere.contains(backupStem(r.filename))
          ? r.copyWith(pinnedOnAnotherDevice: true)
          : r,
  ];
}

/// The timestamp a backup's name starts with, in the local time of the device
/// that wrote it, or null when the name carries none.
DateTime? backupTimestampFromName(String name) {
  final match = _nameTimestamp.firstMatch(name);
  if (match == null) return null;
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  return DateTime(parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]);
}
