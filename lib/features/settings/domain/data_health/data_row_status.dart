import 'package:equatable/equatable.dart';

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
  backupsFailed,
  syncOff,
  syncNever,
  syncAlone,
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

  /// The row shows a trailing "Set up" button.
  final bool offersSetUp;

  @override
  List<Object?> get props => [kind, when, name, count, health, offersSetUp];
}

DataRowStatus backupsRowStatus({
  required FeatureHealth health,
  required DateTime? lastBackup,
  required bool cloudCopyOn,
  required String? cloudAccountLabel,
  required bool customFolder,
  required bool cloudCopyMissing,
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
  // The flag, not the winning health reason: the evaluator stops at the
  // first gate, so a missing copy hides behind "auto off" or "overdue".
  if (cloudCopyOn && !cloudCopyMissing) {
    return DataRowStatus(
      DataRowStatusKind.backupsCloud,
      when: lastBackup,
      name: cloudAccountLabel ?? '',
      offersSetUp: offersSetUp,
    );
  }
  if (customFolder) {
    return DataRowStatus(
      DataRowStatusKind.backupsFolder,
      when: lastBackup,
      offersSetUp: offersSetUp,
    );
  }
  return DataRowStatus(
    DataRowStatusKind.backupsLocal,
    when: lastBackup,
    offersSetUp: offersSetUp,
  );
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

DataRowStatus syncRowStatus({
  required FeatureHealth health,
  required DateTime? lastSync,
  required List<String> peerNames,
}) {
  if (_syncAttentionReasons.contains(health.reason)) {
    return DataRowStatus(DataRowStatusKind.syncAttention, health: health);
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
    return DataRowStatus(DataRowStatusKind.syncAlone, when: lastSync);
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
