import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/features/settings/domain/data_health/feature_health.dart';

/// What the health rules read from one joined shared library.
class LibraryHealthInput {
  const LibraryHealthInput({
    required this.name,
    required this.lastError,
    required this.rolesRejected,
    required this.pendingRolesWaiting,
    required this.readOnlyDetected,
    required this.listedRole,
  });

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
  final failed = libraries.where((l) => l.lastError != null).toList();
  if (failed.isNotEmpty) {
    return FeatureHealth(
      feature: DataFeature.sharedLibraries,
      level: HealthLevel.failing,
      reason: HealthReason.librariesFailed,
      name: failed.first.name,
      count: failed.length,
    );
  }
  for (final library in libraries) {
    if (library.editsHeld) {
      return FeatureHealth(
        feature: DataFeature.sharedLibraries,
        level: HealthLevel.attention,
        reason: HealthReason.librariesEditsHeld,
        name: library.name,
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
