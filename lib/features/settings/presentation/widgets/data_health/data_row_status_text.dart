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
  String ago() => status.when == null
      ? l10n.backup_time_justNow
      : relativeAgo(l10n, status.when!, now);
  String reason() =>
      status.health == null ? '' : healthReasonText(l10n, status.health!, now);
  final name = status.name ?? '';
  final count = status.count ?? 0;
  return switch (status.kind) {
    DataRowStatusKind.backupsNever => l10n.settings_data_backups_status_never,
    DataRowStatusKind.backupsLocal => l10n.settings_data_backups_status_local(
      ago(),
    ),
    DataRowStatusKind.backupsCloud => l10n.settings_data_backups_status_cloud(
      ago(),
      name,
    ),
    DataRowStatusKind.backupsFolder => l10n.settings_data_backups_status_folder(
      ago(),
    ),
    DataRowStatusKind.backupsFailed => l10n.dataHealth_backup_failed(ago()),
    DataRowStatusKind.syncOff => l10n.settings_data_sync_status_off,
    DataRowStatusKind.syncNever => l10n.dataHealth_sync_neverSynced,
    DataRowStatusKind.syncAlone => l10n.settings_data_sync_status_alone(ago()),
    DataRowStatusKind.syncWithOne => l10n.settings_data_sync_status_one(
      name,
      ago(),
    ),
    DataRowStatusKind.syncWithMany => l10n.settings_data_sync_status_many(
      count,
      ago(),
    ),
    DataRowStatusKind.syncPaused => reason(),
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
    DataRowStatusKind.accountsSignedIn =>
      l10n.settings_data_accounts_status_signedIn(name),
    DataRowStatusKind.accountsNeedSignIn =>
      l10n.settings_data_accounts_status_needSignIn(count),
  };
}
