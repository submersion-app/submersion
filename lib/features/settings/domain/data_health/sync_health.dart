import 'package:submersion/features/settings/domain/data_health/feature_health.dart';

/// Whether a failed sync was the network (normal offline life on a
/// liveaboard) or something else.
enum SyncFailureKind { network, other }

/// The last failed sync attempt, persisted so it survives a restart.
class SyncFailureRecord {
  const SyncFailureRecord({
    required this.providerId,
    required this.at,
    required this.kind,
    required this.message,
  });

  final String providerId;
  final DateTime at;
  final SyncFailureKind kind;
  final String message;
}

/// What the cloud sync health rules read.
class SyncHealthInputs {
  const SyncHealthInputs({
    required this.customFolder,
    required this.providerSelected,
    required this.providerId,
    required this.needsPassphrase,
    required this.awaitingAdoption,
    required this.authenticated,
    required this.lastFailure,
    required this.lastSyncAt,
    required this.conflicts,
    required this.peersHeld,
    required this.autoSyncEnabled,
  });

  final bool customFolder;
  final bool providerSelected;
  final String? providerId;
  final bool needsPassphrase;
  final bool awaitingAdoption;
  final bool authenticated;
  final SyncFailureRecord? lastFailure;
  final DateTime? lastSyncAt;
  final int conflicts;
  final bool peersHeld;
  final bool autoSyncEnabled;
}

/// A week offline is when a network failure turns amber.
const offlineGrace = Duration(days: 7);

/// Cloud sync health per the spec's sync table. A network failure alone is
/// never red: being offline is normal for divers.
FeatureHealth evaluateSyncHealth(SyncHealthInputs i, DateTime now) {
  FeatureHealth health(
    HealthLevel level,
    HealthReason reason, {
    DateTime? at,
    int? count,
  }) => FeatureHealth(
    feature: DataFeature.sync,
    level: level,
    reason: reason,
    when: at,
    count: count,
  );

  if (i.customFolder) {
    return health(HealthLevel.notSetUp, HealthReason.syncCustomFolder);
  }
  if (!i.providerSelected) {
    return health(HealthLevel.attention, HealthReason.syncOff);
  }

  final lastSync = i.lastSyncAt;
  final failure = i.lastFailure;
  final currentFailure =
      failure != null &&
          failure.providerId == i.providerId &&
          (lastSync == null || failure.at.isAfter(lastSync))
      ? failure
      : null;

  final candidates = [
    if (i.needsPassphrase)
      health(HealthLevel.failing, HealthReason.syncNeedsPassphrase),
    if (i.awaitingAdoption)
      health(HealthLevel.failing, HealthReason.syncAwaitingAdoption),
    if (!i.authenticated)
      health(HealthLevel.failing, HealthReason.syncSignedOut),
    if (currentFailure != null && currentFailure.kind == SyncFailureKind.other)
      health(
        HealthLevel.failing,
        HealthReason.syncFailed,
        at: currentFailure.at,
      ),
    if (currentFailure != null &&
        currentFailure.kind == SyncFailureKind.network &&
        lastSync != null &&
        now.difference(lastSync) > offlineGrace)
      health(HealthLevel.attention, HealthReason.syncOffline, at: lastSync),
    if (i.conflicts > 0)
      health(
        HealthLevel.attention,
        HealthReason.syncConflicts,
        count: i.conflicts,
      ),
    if (i.peersHeld) health(HealthLevel.attention, HealthReason.syncPeersHeld),
    if (!i.autoSyncEnabled)
      health(HealthLevel.attention, HealthReason.syncAutoOff),
    if (lastSync == null)
      health(HealthLevel.attention, HealthReason.syncNeverSynced),
  ];
  if (candidates.isEmpty) {
    return health(HealthLevel.healthy, HealthReason.ok, at: lastSync);
  }
  return pickHealth(DataFeature.sync, candidates);
}
