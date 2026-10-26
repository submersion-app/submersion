import 'package:equatable/equatable.dart';

import 'package:submersion/core/services/accounts/account_kind.dart';

/// How often automatic backups should run
enum BackupFrequency { daily, weekly, monthly }

/// Where the most recent backup was written, so Settings > Data can say
/// where the copy is without guessing from settings changed since.
enum LastBackupDestination {
  /// The app's own backups folder on this device.
  device,

  /// A backup folder the diver chose.
  folder,

  /// This device, plus a copy that reached the cloud.
  cloud,

  /// A file the diver saved somewhere with Save to file.
  file,
}

/// User-configurable backup settings
class BackupSettings extends Equatable {
  final bool enabled;
  final BackupFrequency frequency;
  final int retentionCount;
  final DateTime? lastBackupTime;
  final bool cloudBackupEnabled;
  final String? backupLocation;
  final bool backupEncryptionEnabled;

  /// When the last scheduled (automatic) backup failed, if it did. Counts
  /// only while newer than [lastBackupTime]: any later success clears it.
  final DateTime? lastScheduledFailureAt;
  final String? lastScheduledFailureMessage;

  /// Cloud backup is on but the most recent backup did not reach the cloud.
  final bool lastCloudCopyMissing;

  /// Where the most recent backup went, or null before the first backup
  /// made by a version that records it.
  final LastBackupDestination? lastBackupDestination;

  /// The connected account driving sync when the last backup reached the
  /// cloud, so Settings > Data names the account the copy is in, not the
  /// one that syncs today. Null for any other destination.
  final String? lastBackupCloudAccountId;

  /// The roster row the cloud copy goes to, with its kind; both null means
  /// the copy goes to the same account as sync (spec section 7.3). The kind
  /// travels with the id so the scheduled backup, which has no database
  /// registry, can still build the provider.
  final String? copyAccountId;
  final AccountKind? copyAccountKind;

  /// The cloud folder the "count backups from all devices" switch was
  /// confirmed for (issue #3503): its account id, or `provider:<id>` when the
  /// account is unknown; null when the switch is off. Kept as the folder
  /// rather than a flag so a different backup folder reads as off until the
  /// diver confirms it too.
  final String? crossDeviceRetentionAccount;

  const BackupSettings({
    this.enabled = false,
    this.frequency = BackupFrequency.weekly,
    this.retentionCount = 10,
    this.lastBackupTime,
    this.cloudBackupEnabled = false,
    this.backupLocation,
    this.backupEncryptionEnabled = false,
    this.lastScheduledFailureAt,
    this.lastScheduledFailureMessage,
    this.lastCloudCopyMissing = false,
    this.lastBackupDestination,
    this.lastBackupCloudAccountId,
    this.copyAccountId,
    this.copyAccountKind,
    this.crossDeviceRetentionAccount,
  });

  BackupSettings copyWith({
    bool? enabled,
    BackupFrequency? frequency,
    int? retentionCount,
    DateTime? lastBackupTime,
    bool? cloudBackupEnabled,
    String? backupLocation,
    bool? backupEncryptionEnabled,
    DateTime? lastScheduledFailureAt,
    String? lastScheduledFailureMessage,
    bool? lastCloudCopyMissing,
    LastBackupDestination? lastBackupDestination,
    String? lastBackupCloudAccountId,
    String? copyAccountId,
    AccountKind? copyAccountKind,
    String? crossDeviceRetentionAccount,
  }) {
    return BackupSettings(
      enabled: enabled ?? this.enabled,
      frequency: frequency ?? this.frequency,
      retentionCount: retentionCount ?? this.retentionCount,
      lastBackupTime: lastBackupTime ?? this.lastBackupTime,
      cloudBackupEnabled: cloudBackupEnabled ?? this.cloudBackupEnabled,
      backupLocation: backupLocation ?? this.backupLocation,
      backupEncryptionEnabled:
          backupEncryptionEnabled ?? this.backupEncryptionEnabled,
      lastScheduledFailureAt:
          lastScheduledFailureAt ?? this.lastScheduledFailureAt,
      lastScheduledFailureMessage:
          lastScheduledFailureMessage ?? this.lastScheduledFailureMessage,
      lastCloudCopyMissing: lastCloudCopyMissing ?? this.lastCloudCopyMissing,
      lastBackupDestination:
          lastBackupDestination ?? this.lastBackupDestination,
      lastBackupCloudAccountId:
          lastBackupCloudAccountId ?? this.lastBackupCloudAccountId,
      copyAccountId: copyAccountId ?? this.copyAccountId,
      copyAccountKind: copyAccountKind ?? this.copyAccountKind,
      crossDeviceRetentionAccount:
          crossDeviceRetentionAccount ?? this.crossDeviceRetentionAccount,
    );
  }

  /// Duration between backups for the configured frequency
  Duration get frequencyDuration {
    switch (frequency) {
      case BackupFrequency.daily:
        return const Duration(days: 1);
      case BackupFrequency.weekly:
        return const Duration(days: 7);
      case BackupFrequency.monthly:
        return const Duration(days: 30);
    }
  }

  /// Whether a backup is due based on lastBackupTime and frequency
  bool get isBackupDue {
    if (!enabled) return false;
    if (lastBackupTime == null) return true;
    return DateTime.now().difference(lastBackupTime!) >= frequencyDuration;
  }

  /// Whether the cross-device rule applies to the cloud folder [folderKey]
  /// names (`BackupServiceRetention.crossDeviceRetentionAccountKey`).
  bool crossDeviceRetentionFor(String folderKey) =>
      crossDeviceRetentionAccount == folderKey;

  @override
  List<Object?> get props => [
    enabled,
    frequency,
    retentionCount,
    lastBackupTime,
    cloudBackupEnabled,
    backupLocation,
    backupEncryptionEnabled,
    lastScheduledFailureAt,
    lastScheduledFailureMessage,
    lastCloudCopyMissing,
    lastBackupDestination,
    lastBackupCloudAccountId,
    copyAccountId,
    copyAccountKind,
    crossDeviceRetentionAccount,
  ];
}
