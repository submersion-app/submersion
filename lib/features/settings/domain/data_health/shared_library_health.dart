import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';

/// What the health rules read from one joined shared library.
class LibraryHealthInput {
  const LibraryHealthInput({
    required this.id,
    required this.name,
    required this.lastError,
    required this.rolesRejected,
    required this.pendingRolesWaiting,
    required this.readOnlyDetected,
    required this.listedRole,
  });

  /// The library's id, so its tile on the Shared libraries page carries its
  /// own mark (#4561).
  final String id;
  final String name;
  final String? lastError;
  final bool rolesRejected;
  final bool pendingRolesWaiting;
  final bool readOnlyDetected;

  /// This member's role in the library's trusted roles.
  final SharedLibraryRole listedRole;

  /// Edits made here go nowhere though this member is meant to write. A
  /// reader whose storage key refuses writes is set up as the owner
  /// intended, so `SharedLibrary.writesHeld` is not used as is.
  bool get editsHeld =>
      rolesRejected ||
      pendingRolesWaiting ||
      (readOnlyDetected && listedRole != SharedLibraryRole.reader);
}

/// Shared library health per the spec's library table.
FeatureHealth evaluateSharedLibraryHealth(List<LibraryHealthInput> libraries) {
  if (libraries.isEmpty) {
    return const FeatureHealth(
      feature: DataFeature.sharedLibraries,
      level: HealthLevel.notSetUp,
      reason: HealthReason.notSetUp,
    );
  }
  FeatureHealth finding(
    LibraryHealthInput l,
    HealthLevel level,
    HealthReason reason,
  ) => FeatureHealth(
    feature: DataFeature.sharedLibraries,
    level: level,
    reason: reason,
    name: l.name,
    subjectId: l.id,
  );
  // One finding per library, so each tile is marked on its own.
  final findings = List<FeatureHealth>.unmodifiable([
    for (final l in libraries)
      if (l.lastError != null)
        finding(l, HealthLevel.failing, HealthReason.librariesFailed),
    for (final l in libraries)
      if (l.editsHeld)
        finding(l, HealthLevel.attention, HealthReason.librariesEditsHeld),
  ]);
  final failed = libraries.where((l) => l.lastError != null).toList();
  if (failed.isNotEmpty) {
    return FeatureHealth(
      feature: DataFeature.sharedLibraries,
      level: HealthLevel.failing,
      reason: HealthReason.librariesFailed,
      name: failed.first.name,
      count: failed.length,
      findings: findings,
    );
  }
  for (final library in libraries) {
    if (library.editsHeld) {
      return FeatureHealth(
        feature: DataFeature.sharedLibraries,
        level: HealthLevel.attention,
        reason: HealthReason.librariesEditsHeld,
        name: library.name,
        findings: findings,
      );
    }
  }
  return FeatureHealth(
    feature: DataFeature.sharedLibraries,
    level: HealthLevel.healthy,
    reason: HealthReason.ok,
    count: libraries.length,
  );
}
