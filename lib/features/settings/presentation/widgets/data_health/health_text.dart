import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The page each feature's strip item, attention line and row opens.
String dataFeatureRoute(DataFeature feature) => switch (feature) {
  DataFeature.backup => '/settings/backup',
  DataFeature.sync => '/settings/cloud-sync',
  DataFeature.sharedLibraries => '/settings/shared-libraries',
  DataFeature.media => '/settings/photos-media',
};

String dataFeatureLabel(AppLocalizations l10n, DataFeature feature) =>
    switch (feature) {
      DataFeature.backup => l10n.dataHealth_feature_backup,
      DataFeature.sync => l10n.dataHealth_feature_sync,
      DataFeature.sharedLibraries => l10n.dataHealth_feature_libraries,
      DataFeature.media => l10n.dataHealth_feature_media,
    };

String healthLevelLabel(AppLocalizations l10n, HealthLevel level) =>
    switch (level) {
      HealthLevel.healthy => l10n.dataHealth_level_healthy,
      HealthLevel.attention => l10n.dataHealth_level_attention,
      HealthLevel.failing => l10n.dataHealth_level_failing,
      HealthLevel.notSetUp => l10n.dataHealth_level_notSetUp,
    };

/// "Backup: Needs attention", read by screen readers for a strip item and a
/// row mark alike.
String healthSemanticsLabel(AppLocalizations l10n, FeatureHealth health) =>
    l10n.dataHealth_semantics(
      dataFeatureLabel(l10n, health.feature),
      healthLevelLabel(l10n, health.level),
    );

/// "3h ago" style relative time, shared with the backup row's subtitle.
String relativeAgo(AppLocalizations l10n, DateTime at, DateTime now) {
  final diff = now.difference(at);
  if (diff.inMinutes < 1) return l10n.backup_time_justNow;
  if (diff.inHours < 1) return l10n.backup_time_minutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.backup_time_hoursAgo(diff.inHours);
  return l10n.backup_time_daysAgo(diff.inDays);
}

/// The one-line reason shown under the strip for a feature that is failing
/// or needs attention. Healthy and not set up have no line, so they read as
/// an empty string.
String healthReasonText(
  AppLocalizations l10n,
  FeatureHealth health,
  DateTime now,
) {
  String ago() => health.when == null
      ? l10n.backup_time_justNow
      : relativeAgo(l10n, health.when!, now);
  final count = health.count ?? 0;
  final name = health.name ?? '';
  return switch (health.reason) {
    HealthReason.ok ||
    HealthReason.notSetUp ||
    HealthReason.syncCustomFolder => '',
    HealthReason.backupAutoOff => l10n.dataHealth_backup_autoOff,
    HealthReason.backupFailed => l10n.dataHealth_backup_failed(ago()),
    HealthReason.backupOverdue => l10n.dataHealth_backup_overdue(ago()),
    HealthReason.backupNever => l10n.dataHealth_backup_never,
    HealthReason.backupCloudCopyMissing =>
      l10n.dataHealth_backup_cloudCopyMissing,
    HealthReason.backupNoOffDeviceCopy =>
      l10n.dataHealth_backup_noOffDeviceCopy,
    HealthReason.syncOff => l10n.dataHealth_sync_off,
    HealthReason.syncNeedsPassphrase => l10n.dataHealth_sync_needsPassphrase,
    HealthReason.syncAwaitingAdoption => l10n.dataHealth_sync_awaitingAdoption,
    HealthReason.syncSignedOut => l10n.dataHealth_sync_signedOut,
    HealthReason.syncFailed => l10n.dataHealth_sync_failed(ago()),
    HealthReason.syncOffline => l10n.dataHealth_sync_offline(ago()),
    HealthReason.syncConflicts => l10n.dataHealth_sync_conflicts(count),
    HealthReason.syncPeersHeld => l10n.dataHealth_sync_peersHeld,
    HealthReason.syncAutoOff => l10n.dataHealth_sync_autoOff,
    HealthReason.syncNeverSynced => l10n.dataHealth_sync_neverSynced,
    HealthReason.librariesFailed =>
      count > 1
          ? l10n.dataHealth_libraries_failedMany(count)
          : l10n.dataHealth_libraries_failed(name),
    HealthReason.librariesEditsHeld => l10n.dataHealth_libraries_editsHeld(
      name,
    ),
    HealthReason.mediaFinishSetup => l10n.dataHealth_media_finishSetup,
    HealthReason.mediaTransfersPaused => l10n.dataHealth_media_transfersPaused,
  };
}
