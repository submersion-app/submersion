import 'package:equatable/equatable.dart';

/// How often automatic backups should run
enum BackupFrequency { daily, weekly, monthly }

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
  ];
}
