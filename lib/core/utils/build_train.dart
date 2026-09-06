/// Which release train this binary came off.
///
/// Distinct from the two channel concepts that already exist:
/// `UpdateChannel` is the compile-time DISTRIBUTION channel (github, appstore,
/// playstore) and `ReleaseChannel` is the user's update PREFERENCE. Neither
/// says whether this particular binary was built by the beta workflow, which
/// is the fact a database written by a beta build needs to carry (issues
/// #1568, #1592).
///
/// Set by the beta build workflow as `--dart-define=BUILD_TRAIN=beta`.
/// Everything else defaults to stable, so no existing build changes.
class BuildTrain {
  BuildTrain._();

  /// The stable train, and the default for any build that sets nothing.
  static const String stable = 'stable';

  /// The beta train, published to `submersion-app/beta-builds`.
  static const String beta = 'beta';

  /// The compile-time define. Free text rather than an enum on purpose: it is
  /// recorded into a database that older builds have to read back, so a train
  /// added later must still round-trip through a build that predates it.
  static const String current = String.fromEnvironment(
    'BUILD_TRAIN',
    defaultValue: stable,
  );

  /// True when this binary was built by the beta workflow.
  static bool get isBeta => current == beta;
}
