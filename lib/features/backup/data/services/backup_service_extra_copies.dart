part of 'backup_service.dart';

/// The extra accounts a backup is also copied to (issue #3782), beside the
/// main copy in [_CloudCopy]. Each account is handled on its own: a failure
/// in one is logged and never reaches the backup, the main copy or the other
/// accounts.
extension _ExtraCopies on BackupService {
  /// Uploads [sourcePath] as [storedName] to every extra account, in order.
  /// Never throws. An account the main copy also goes to is skipped, so one
  /// account never receives the same backup twice; it is not missed either.
  /// [missed] holds the accounts that got no copy.
  Future<({List<ExtraCloudCopy> copies, List<String> missed})> _copyToExtras(
    String sourcePath,
    String storedName,
  ) async {
    if (_extraCopies.isEmpty) {
      return (copies: const <ExtraCloudCopy>[], missed: const <String>[]);
    }
    final mainAccountId = await _copyAccountIdOrNull();
    final copies = <ExtraCloudCopy>[];
    final missed = <String>[];
    for (final destination in _extraCopies) {
      final accountId = destination.accountId;
      if (accountId == mainAccountId) continue;
      final provider = destination.provider;
      if (provider == null) {
        _log.warning('Extra backup copy skipped, account unreachable');
        missed.add(accountId);
        continue;
      }
      try {
        final fileId = await _uploadToCloud(
          sourcePath,
          storedName,
          via: provider,
        );
        if (fileId == null) {
          missed.add(accountId);
        } else {
          copies.add(ExtraCloudCopy(accountId: accountId, fileId: fileId));
        }
      } catch (e, stack) {
        _log.error(
          'Extra backup copy failed, other copies unaffected',
          error: e,
          stackTrace: stack,
        );
        missed.add(accountId);
      }
    }
    return (copies: copies, missed: missed);
  }
}
