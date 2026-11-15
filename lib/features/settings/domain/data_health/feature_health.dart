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

  /// The cloud copy is missing, and signing in again would help (#3811).
  backupCloudSignIn,

  /// The main copy arrived, but an extra account did not get its copy
  /// (#3782).
  backupExtraCopyMissing,
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

  /// A store attached here could not be opened with this device's keys
  /// (#4561).
  mediaStoreUnreachable,
}

/// One feature's health: its level, the reason behind it, and any values the
/// reason's text needs.
///
/// The headline is what the Settings > Data row shows; [findings] holds every
/// problem the evaluation found, the headline among them, so a feature's page
/// can mark each item that needs the diver (#4561).
class FeatureHealth extends Equatable {
  const FeatureHealth({
    required this.feature,
    required this.level,
    required this.reason,
    this.when,
    this.count,
    this.name,
    this.subjectId,
    this.findings = const [],
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

  /// The one item among siblings a finding is about (a library's id, an
  /// extra backup account's id, which media setup item), so only that tile
  /// is marked.
  final String? subjectId;

  /// Every problem found, in evaluation order (not by severity: use
  /// [findingFor] for the worst of some reasons). Empty when healthy or not
  /// set up.
  final List<FeatureHealth> findings;

  FeatureHealth copyWith({
    HealthLevel? level,
    HealthReason? reason,
    DateTime? when,
    int? count,
    String? name,
    String? subjectId,
    List<FeatureHealth>? findings,
  }) => FeatureHealth(
    feature: feature,
    level: level ?? this.level,
    reason: reason ?? this.reason,
    when: when ?? this.when,
    count: count ?? this.count,
    name: name ?? this.name,
    subjectId: subjectId ?? this.subjectId,
    findings: findings ?? this.findings,
  );

  @override
  List<Object?> get props => [
    feature,
    level,
    reason,
    when,
    count,
    name,
    subjectId,
    findings,
  ];
}

/// The most severe finding of [health] whose reason is one of [reasons];
/// ties go to the earliest. With [subjectId], only findings about that
/// subject count. Null when none matches.
FeatureHealth? findingFor(
  FeatureHealth health,
  Set<HealthReason> reasons, {
  String? subjectId,
}) {
  FeatureHealth? best;
  for (final f in health.findings) {
    if (!reasons.contains(f.reason)) continue;
    if (subjectId != null && f.subjectId != subjectId) continue;
    if (best == null || f.level.severity > best.level.severity) best = f;
  }
  return best;
}

/// Whether [health] is one that signing in again would fix (issue #3811).
bool offersSignInAgain(FeatureHealth health) =>
    health.reason == HealthReason.syncSignedOut ||
    health.reason == HealthReason.backupCloudSignIn;

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
  return best.copyWith(findings: List.unmodifiable(candidates));
}
