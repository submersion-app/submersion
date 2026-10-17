import 'package:equatable/equatable.dart';

/// How a data feature is doing, most severe first (issues #3390, #3394).
enum HealthLevel {
  /// Configured and broken: the data may not be protected.
  failing,

  /// Works, but needs the diver: a recommended setting is off, a copy is
  /// overdue, writes are held.
  attention,

  /// Configured and working.
  healthy,

  /// Not in use, or not available here. Neutral, never a nag.
  notSetUp;

  int get severity => switch (this) {
    HealthLevel.failing => 3,
    HealthLevel.attention => 2,
    HealthLevel.healthy => 1,
    HealthLevel.notSetUp => 0,
  };
}

/// The four Settings > Data features the health model covers.
enum DataFeature { backup, sync, sharedLibraries, media }

/// Why a feature has its level. Widgets turn these into localized text.
enum HealthReason {
  ok,
  notSetUp,
  backupAutoOff,
  backupFailed,
  backupOverdue,
  backupNever,
  backupCloudCopyMissing,
  backupNoOffDeviceCopy,
  syncCustomFolder,
  syncOff,
  syncNeedsPassphrase,
  syncAwaitingAdoption,
  syncSignedOut,
  syncFailed,
  syncOffline,
  syncConflicts,
  syncPeersHeld,
  syncAutoOff,
  syncNeverSynced,
  librariesFailed,
  librariesEditsHeld,
  mediaFinishSetup,
  mediaTransfersPaused,
}

/// One feature's health: its level, the reason behind it, and any values the
/// reason's text needs.
class FeatureHealth extends Equatable {
  const FeatureHealth({
    required this.feature,
    required this.level,
    required this.reason,
    this.when,
    this.count,
    this.name,
  });

  final DataFeature feature;
  final HealthLevel level;
  final HealthReason reason;

  /// When the reason happened (a failure, the last success).
  final DateTime? when;

  /// How many of something (conflicts, failing libraries).
  final int? count;

  /// The thing the reason is about (a library's name).
  final String? name;

  @override
  List<Object?> get props => [feature, level, reason, when, count, name];
}

/// The most severe of [candidates]; ties go to the earliest. With none, the
/// feature is healthy.
FeatureHealth pickHealth(DataFeature feature, List<FeatureHealth> candidates) {
  var best = FeatureHealth(
    feature: feature,
    level: HealthLevel.healthy,
    reason: HealthReason.ok,
  );
  for (final candidate in candidates) {
    if (candidate.level.severity > best.level.severity) best = candidate;
  }
  return best;
}
