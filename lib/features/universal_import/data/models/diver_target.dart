import 'package:equatable/equatable.dart';

/// Where the import wizard's Divers step sends one source diver's records
/// (issue #1893).
sealed class DiverTarget extends Equatable {
  const DiverTarget();

  /// Payload map key stamped on every item of an expanded payload with the
  /// [targetKey] of the profile it will be imported into.
  static const itemKey = '_targetKey';

  static const _existingPrefix = 'diver:';
  static const _newPrefix = 'new:';

  /// The [itemKey] value for items going to this target; null when the
  /// records are left out of the import.
  String? get targetKey;

  /// The existing profile id [targetKey] names, or null for a new profile.
  static String? diverIdOf(String targetKey) =>
      targetKey.startsWith(_existingPrefix)
      ? targetKey.substring(_existingPrefix.length)
      : null;

  /// The source diver key a new-profile [targetKey] names, or null.
  static String? newSourceKeyOf(String targetKey) =>
      targetKey.startsWith(_newPrefix)
      ? targetKey.substring(_newPrefix.length)
      : null;
}

/// Import into an existing Submersion profile.
final class ExistingDiverTarget extends DiverTarget {
  const ExistingDiverTarget(this.diverId);

  final String diverId;

  @override
  String get targetKey => '${DiverTarget._existingPrefix}$diverId';

  @override
  List<Object?> get props => [diverId];
}

/// Import into a profile the import creates, seeded from the source diver.
final class NewDiverTarget extends DiverTarget {
  const NewDiverTarget(this.sourceKey);

  final String sourceKey;

  @override
  String get targetKey => '${DiverTarget._newPrefix}$sourceKey';

  @override
  List<Object?> get props => [sourceKey];
}

/// Leave this source diver's records out of the import.
final class SkipDiverTarget extends DiverTarget {
  const SkipDiverTarget();

  @override
  String? get targetKey => null;

  @override
  List<Object?> get props => const [];
}
