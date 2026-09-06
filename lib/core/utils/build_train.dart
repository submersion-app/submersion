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
  ///
  /// Defaulted, so this answers "which train should this build behave as" and
  /// NOT "which train was this build stamped with". Use [stamped] for the
  /// second question; see why the difference matters there.
  static const String current = String.fromEnvironment(
    'BUILD_TRAIN',
    defaultValue: stable,
  );

  /// Whether the build carries an explicit train stamp at all.
  static const bool isStamped = bool.hasEnvironment('BUILD_TRAIN');

  /// The train this build was actually STAMPED with, or null when it carries
  /// no stamp.
  ///
  /// The distinction from [current] is the whole point, and anything that
  /// RECORDS the train (rather than merely behaving as one) must use this.
  /// [current] cannot tell an unstamped build apart from one stamped
  /// `stable`, so writing it into a database would have every build claim the
  /// stable train, a beta build included -- and a beta-written dive log
  /// claiming `stable` sends a stranded diver to the stable releases page,
  /// which is exactly the dead end issue #1568 is about. A field that is
  /// absent says "unknown" honestly; a defaulted one lies with confidence.
  ///
  /// Until the beta workflow sets the define (issue #1592) this is null in
  /// every build, which is the correct answer for all of them.
  static String? get stamped => isStamped ? current : null;

  /// True when this binary was built by the beta workflow.
  static bool get isBeta => current == beta;
}
