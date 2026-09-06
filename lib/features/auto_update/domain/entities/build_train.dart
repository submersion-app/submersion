/// The release train that produced this binary: the stable release pipeline,
/// or the per-merge beta pipeline.
///
/// Deliberately distinct from the two channel concepts it sits beside:
///
/// - `ReleaseChannel` is the user's *preference* for which feed to update
///   from. A direct download from the beta-builds repository leaves it on
///   stable, so it never reveals that the running binary is a beta.
/// - `UpdateChannel` is the compile-time *distribution* channel
///   (github/appstore/playstore/...), which says how the binary was delivered,
///   not which train built it.
///
/// Neither answers "did this binary come off the beta train?", which is the
/// fact a user needs before a beta build upgrades their dive log's database
/// ahead of stable (#1568).
enum BuildTrain { stable, beta }

/// Reads the build train stamped into the artifact at compile time.
///
/// Mirrors `UpdateChannelConfig`: a `--dart-define` set by the release
/// workflow, defaulting to stable so a build that sets nothing (a local
/// `flutter run`, or any pipeline predating this define) is unchanged.
class BuildTrainConfig {
  BuildTrainConfig._();

  static const _raw = String.fromEnvironment(
    'BUILD_TRAIN',
    defaultValue: 'stable',
  );

  /// The train this binary was built on, parsed from the BUILD_TRAIN
  /// compile-time environment variable.
  static BuildTrain get current => fromName(_raw);

  /// Parses a train name, falling back to [BuildTrain.stable] for null or
  /// unrecognised values.
  ///
  /// Stable is the fallback for the same reason it is in
  /// `ReleaseChannel.fromName`: only the release pipeline ever sets this, so a
  /// value that fails to parse is a misconfigured build rather than a user
  /// choice, and the quiet outcome is preferable to a stable build that
  /// announces itself as a beta.
  static BuildTrain fromName(String? name) {
    for (final train in BuildTrain.values) {
      if (train.name == name) return train;
    }
    return BuildTrain.stable;
  }
}
