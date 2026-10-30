import 'package:submersion/features/settings/domain/data_health/data_row_status.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_text.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The one sentence a Settings > Data row shows for its [DataRowStatus].
///
/// Kinds that stand in for a health reason (sync paused, photos or
/// libraries needing attention) reuse the strip's attention line, so the
/// row and the strip read the same words.
String dataRowStatusText(
  AppLocalizations l10n,
  DataRowStatus status,
  DateTime now,
) {
  // Mid-sentence, so "just now" is lowercase, unlike the standalone label
  // relativeAgo gives the strip after a colon.
  String ago() {
    final when = status.when;
    if (when == null || now.difference(when).inMinutes < 1) {
      return l10n.settings_data_time_justNow;
    }
    return relativeAgo(l10n, when, now);
  }

  String reason() =>
      status.health == null ? '' : healthReasonText(l10n, status.health!, now);
  final name = status.name ?? '';
  final count = status.count ?? 0;
  return switch (status.kind) {
    DataRowStatusKind.checking => l10n.settings_data_status_checking,
    DataRowStatusKind.backupsNever => l10n.settings_data_backups_status_never,
    DataRowStatusKind.backupsLocal => l10n.settings_data_backups_status_local(
      ago(),
    ),
    DataRowStatusKind.backupsCloud =>
      name.trim().isEmpty
          ? l10n.settings_data_backups_status_cloudUnknown(ago())
          : l10n.settings_data_backups_status_cloud(ago(), name),
    DataRowStatusKind.backupsFolder => l10n.settings_data_backups_status_folder(
      ago(),
    ),
    DataRowStatusKind.backupsPlain => l10n.settings_data_backups_status_plain(
      ago(),
    ),
    // After a colon, like the strip's line, so the standalone form.
    DataRowStatusKind.backupsFailed => l10n.dataHealth_backup_failed(
      status.when == null
          ? l10n.backup_time_justNow
          : relativeAgo(l10n, status.when!, now),
    ),
    DataRowStatusKind.syncOff => l10n.settings_data_sync_status_off,
    DataRowStatusKind.syncNever => l10n.dataHealth_sync_neverSynced,
    DataRowStatusKind.syncSynced => l10n.settings_data_sync_status_synced(
      ago(),
    ),
    DataRowStatusKind.syncFolder => l10n.settings_data_sync_status_folder,
    DataRowStatusKind.syncWithOne => l10n.settings_data_sync_status_one(
      name,
      ago(),
    ),
    DataRowStatusKind.syncWithMany => l10n.settings_data_sync_status_many(
      count,
      ago(),
    ),
    DataRowStatusKind.syncAttention => reason(),
    DataRowStatusKind.photosOff => l10n.settings_data_photos_status_off,
    DataRowStatusKind.photosOn =>
      name.isEmpty
          ? l10n.settings_data_photos_status_onUnknown
          : l10n.settings_data_photos_status_on(name),
    DataRowStatusKind.photosAttention => reason(),
    DataRowStatusKind.librariesNone => l10n.settings_data_libraries_status_none,
    DataRowStatusKind.librariesSome => l10n.settings_data_libraries_status_some(
      count,
      ago(),
    ),
    DataRowStatusKind.librariesSomeNever =>
      l10n.settings_data_libraries_status_someNever(count),
    DataRowStatusKind.librariesAttention => reason(),
    DataRowStatusKind.accountsNone => l10n.settings_data_accounts_status_none,
    DataRowStatusKind.accountsListed => l10n.settings_data_accounts_status_list(
      name,
    ),
    DataRowStatusKind.accountsNeedSignIn =>
      l10n.settings_data_accounts_status_needSignIn(count),
    DataRowStatusKind.accountsUnavailable =>
      l10n.settings_connectedAccounts_loadError,
  };
}
