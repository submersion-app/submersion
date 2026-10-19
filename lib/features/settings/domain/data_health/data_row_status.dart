import 'package:equatable/equatable.dart';

import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';

/// What the one-sentence subtitle under a Settings > Data row says.
///
/// Derived from the same inputs the health strip reads (issue #3482), so a
/// row can never contradict the strip. Pure data: the widget layer turns a
/// kind into localized text.
enum DataRowStatusKind {
  /// The row's inputs have not loaded yet; never read as "none".
  checking,
  backupsNever,
  backupsLocal,
  backupsCloud,
  backupsFolder,

  /// Backed up, with no claim about where: a file the diver saved, or a
  /// backup made before the app recorded destinations.
  backupsPlain,
  backupsFailed,
  syncOff,
  syncNever,

  /// Synced, with no peer names known. Not "only this device": a peer on an
  /// older build publishes no name.
  syncSynced,

  /// The database lives in a folder another service keeps in step.
  syncFolder,
  syncWithOne,
  syncWithMany,
  syncAttention,
  photosOff,
  photosOn,
  photosAttention,
  librariesNone,
  librariesSome,
  librariesSomeNever,
  librariesAttention,
  accountsNone,
  accountsListed,
  accountsNeedSignIn,

  /// The roster could not be read.
  accountsUnavailable,
}

class DataRowStatus extends Equatable {
  const DataRowStatus(
    this.kind, {
    this.when,
    this.name,
    this.count,
    this.health,
    this.offersSetUp = false,
  });

  final DataRowStatusKind kind;

  /// The time the text names (last backup, last sync).
  final DateTime? when;

  /// Account label, device name, store hint, or joined account labels.
  final String? name;

  /// Devices, libraries or accounts.
  final int? count;

  /// Set for the kinds whose text is the health reason line.
  final FeatureHealth? health;

  /// The row offers a "Set up" action under its status.
  final bool offersSetUp;

  /// Whether the row draws its feature's health mark beside the title.
  /// Lightroom alone reads healthy, but a photos-off row says no copies are
  /// kept and offers Set up; a healthy mark beside that would contradict it.
  bool get showsHealthMark => kind != DataRowStatusKind.photosOff;

  @override
  List<Object?> get props => [kind, when, name, count, health, offersSetUp];
}

/// The Backups row says where the LAST backup went ([destination]), never
/// where the current settings would send the next one: turning cloud backup
/// on writes nothing until a backup runs.
DataRowStatus backupsRowStatus({
  required FeatureHealth health,
  required DateTime? lastBackup,
  required LastBackupDestination? destination,
  required String? cloudAccountLabel,
}) {
  final offersSetUp = health.reason == HealthReason.backupAutoOff;
  if (health.reason == HealthReason.backupFailed) {
    return DataRowStatus(
      DataRowStatusKind.backupsFailed,
      when: health.when,
      offersSetUp: offersSetUp,
    );
  }
  if (lastBackup == null) {
    return DataRowStatus(
      DataRowStatusKind.backupsNever,
      offersSetUp: offersSetUp,
    );
  }
  return switch (destination) {
    LastBackupDestination.cloud => DataRowStatus(
      DataRowStatusKind.backupsCloud,
      when: lastBackup,
      name: cloudAccountLabel ?? '',
      offersSetUp: offersSetUp,
    ),
    LastBackupDestination.folder => DataRowStatus(
      DataRowStatusKind.backupsFolder,
      when: lastBackup,
      offersSetUp: offersSetUp,
    ),
    LastBackupDestination.device => DataRowStatus(
      DataRowStatusKind.backupsLocal,
      when: lastBackup,
      offersSetUp: offersSetUp,
    ),
    LastBackupDestination.file || null => DataRowStatus(
      DataRowStatusKind.backupsPlain,
      when: lastBackup,
      offersSetUp: offersSetUp,
    ),
  };
}

/// Reasons whose strip line is the row's status: sync is paused, or "in
/// step" would contradict what the strip says needs attention.
const _syncAttentionReasons = {
  HealthReason.syncNeedsPassphrase,
  HealthReason.syncAwaitingAdoption,
  HealthReason.syncSignedOut,
  HealthReason.syncFailed,
  HealthReason.syncConflicts,
  HealthReason.syncPeersHeld,
  HealthReason.syncOffline,
};

/// [customFolderIsDeviceOnly] is true where a custom database folder cannot
/// be a synced cloud folder (Android), so it means sync is simply off.
DataRowStatus syncRowStatus({
  required FeatureHealth health,
  required DateTime? lastSync,
  required List<String> peerNames,
  bool customFolderIsDeviceOnly = false,
}) {
  if (_syncAttentionReasons.contains(health.reason)) {
    return DataRowStatus(DataRowStatusKind.syncAttention, health: health);
  }
  // Dropbox, OneDrive or iCloud Drive keeps the folder in step on desktop
  // and iOS; the Sync page says the same.
  if (health.reason == HealthReason.syncCustomFolder &&
      !customFolderIsDeviceOnly) {
    return const DataRowStatus(DataRowStatusKind.syncFolder);
  }
  if (health.level == HealthLevel.notSetUp ||
      health.reason == HealthReason.syncOff) {
    return DataRowStatus(
      DataRowStatusKind.syncOff,
      offersSetUp: health.reason == HealthReason.syncOff,
    );
  }
  if (lastSync == null) {
    return const DataRowStatus(DataRowStatusKind.syncNever);
  }
  final names = peerNames.where((n) => n.trim().isNotEmpty).toList();
  if (names.isEmpty) {
    return DataRowStatus(DataRowStatusKind.syncSynced, when: lastSync);
  }
  if (names.length == 1) {
    return DataRowStatus(
      DataRowStatusKind.syncWithOne,
      when: lastSync,
      name: names.first,
    );
  }
  return DataRowStatus(
    DataRowStatusKind.syncWithMany,
    when: lastSync,
    count: names.length,
  );
}

DataRowStatus photosRowStatus({
  required FeatureHealth health,
  required String? storeHint,
  required bool storeAttachedHere,
}) {
  if (health.level == HealthLevel.notSetUp) {
    return const DataRowStatus(DataRowStatusKind.photosOff, offersSetUp: true);
  }
  if (health.level == HealthLevel.attention) {
    return DataRowStatus(DataRowStatusKind.photosAttention, health: health);
  }
  // Healthy with no store here means a photo source (Lightroom) is
  // connected, which keeps no copies.
  if (!storeAttachedHere) {
    return const DataRowStatus(DataRowStatusKind.photosOff, offersSetUp: true);
  }
  return DataRowStatus(DataRowStatusKind.photosOn, name: storeHint);
}

DataRowStatus librariesRowStatus({
  required FeatureHealth health,
  required int count,
  required DateTime? lastSync,
}) {
  if (count == 0) {
    return const DataRowStatus(DataRowStatusKind.librariesNone);
  }
  if (health.level == HealthLevel.attention ||
      health.level == HealthLevel.failing) {
    return DataRowStatus(
      DataRowStatusKind.librariesAttention,
      health: health,
      count: count,
    );
  }
  if (lastSync == null) {
    return DataRowStatus(DataRowStatusKind.librariesSomeNever, count: count);
  }
  return DataRowStatus(
    DataRowStatusKind.librariesSome,
    count: count,
    when: lastSync,
  );
}

DataRowStatus accountsRowStatus({
  required List<String> labels,
  required int needSignIn,
}) {
  if (needSignIn > 0) {
    return DataRowStatus(
      DataRowStatusKind.accountsNeedSignIn,
      count: needSignIn,
    );
  }
  if (labels.isEmpty) {
    return const DataRowStatus(DataRowStatusKind.accountsNone);
  }
  return DataRowStatus(
    DataRowStatusKind.accountsListed,
    name: labels.join(', '),
  );
}
