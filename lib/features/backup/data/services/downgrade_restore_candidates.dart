import 'package:submersion/features/backup/data/services/backup_target.dart';
import 'package:submersion/features/backup/domain/entities/backup_record.dart';
import 'package:submersion/features/backup/domain/entities/backup_type.dart';

/// Backups this build could swap in when the database on disk was written by
/// a NEWER build, newest first.
///
/// The schema-mismatch screen is reached with the database closed and
/// unopenable, so the registry in SharedPreferences is the only inventory
/// available. Every pre-migration copy in it already records the schema it
/// was taken at, which makes the choice a pure predicate over data already in
/// memory rather than a filesystem hunt (issue #1589).
///
/// Deliberately narrower than the terminal failure screen's search
/// ([_loadRecoveryOptions] in `startup_page.dart`), which takes the newest
/// local backup of any kind:
///
/// - Only [BackupType.preMigration] records qualify. A manual backup carries
///   no schema stamp, so nothing here could tell whether this build can open
///   it, and offering a file that fails the same way the database just did is
///   the dead end this issue exists to remove.
/// - [BackupRecord.fromSchemaVersion] must be at or below
///   [supportedSchemaVersion]. On a multi-rung ratchet the NEWEST copy is
///   usually the one still out of reach, so ordering alone would pick wrong.
/// - The record must name a plain local file. `DatabaseService.restore`
///   stages a byte copy, which a cloud-only or SAF (`content://`) reference
///   cannot satisfy.
///
/// Callers still have to check the file itself. This function knows what the
/// registry claims; only opening the copy proves the claim, and the claim is
/// what the screen goes on to display. `_loadDowngradeOption` therefore
/// requires the file's own `user_version` to EQUAL the recorded
/// [BackupRecord.fromSchemaVersion], not merely to fall within the same
/// bound: a copy that opens but disagrees with its record would be offered
/// under the wrong description.
List<BackupRecord> downgradeRestoreCandidates(
  List<BackupRecord> history, {
  required int supportedSchemaVersion,
}) {
  final usable = history.where((record) {
    if (record.type != BackupType.preMigration) return false;
    final from = record.fromSchemaVersion;
    if (from == null || from > supportedSchemaVersion) return false;
    final path = record.localPath;
    if (path == null || isSafRef(path)) return false;
    return true;
  }).toList();

  // Newest first: the least data lost. Sorted here rather than relying on the
  // registry's insertion order, which a restore or a hand-edited preference
  // file can leave unordered.
  usable.sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return usable;
}
