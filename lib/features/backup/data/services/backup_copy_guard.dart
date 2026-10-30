import 'package:submersion/features/backup/domain/entities/backup_record.dart';

/// Whether [record]'s cloud copy can be reached through the provider of the
/// account the copy goes to now ([copyAccountId]).
///
/// A record from before accounts were noted went to the sync account. While
/// the copy [followsSync] it stays reachable, which is what every build did
/// with it; while the copy is pinned it is reachable only when the pinned
/// account is the sync account ([syncAccountId]), and not when that is
/// unknown. A copy in another account is never deleted, downloaded or
/// adopted through this one: a file id from one account can name nothing,
/// or something else, in another.
bool cloudCopyReachable(
  BackupRecord record, {
  required String? copyAccountId,
  required bool followsSync,
  String? syncAccountId,
}) {
  if (record.cloudFileId == null) return false;
  final account = record.cloudAccountId;
  if (account != null) return account == copyAccountId;
  return followsSync ||
      (syncAccountId != null && syncAccountId == copyAccountId);
}

/// A restore asked for a backup whose only copy is in an account the copy no
/// longer goes to.
class BackupCopyInOtherAccountException implements Exception {
  const BackupCopyInOtherAccountException(this.accountId);

  final String accountId;

  @override
  String toString() => 'BackupCopyInOtherAccountException: $accountId';
}
