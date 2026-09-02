import 'dart:io' show Platform;

/// Distribution channels for the application.
enum UpdateChannel { github, appstore, playstore, msstore, snapstore }

/// Configuration helper for determining the active update channel
/// and whether auto-update is available.
class UpdateChannelConfig {
  UpdateChannelConfig._();

  static const _raw = String.fromEnvironment(
    'UPDATE_CHANNEL',
    defaultValue: 'github',
  );

  /// The active update channel, parsed from the UPDATE_CHANNEL
  /// compile-time environment variable. Falls back to [UpdateChannel.github]
  /// when the value is unrecognised.
  static UpdateChannel get current {
    for (final channel in UpdateChannel.values) {
      if (channel.name == _raw) {
        return channel;
      }
    }
    return UpdateChannel.github;
  }

  /// Whether in-app update checking is enabled.
  ///
  /// iOS is the one genuinely store-only platform: every iOS build reaches a
  /// device through the App Store or TestFlight, both of which deliver
  /// updates themselves, so no compile-time channel can turn the updater on
  /// there. Every other platform follows [current], which store builds set
  /// via the UPDATE_CHANNEL dart-define.
  ///
  /// Android is deliberately not special-cased (#1258). The sideloaded APK is
  /// built with UPDATE_CHANNEL=github and polls GitHub Releases exactly as
  /// Linux does; the Play bundle is built with UPDATE_CHANNEL=playstore and
  /// turns the updater off. Treating Android as store-only left every APK
  /// install with no update path at all while Submersion is not on Play.
  static bool get isAutoUpdateEnabled =>
      isAutoUpdateEnabledFor(isIOS: Platform.isIOS, channel: current);

  /// The rule behind [isAutoUpdateEnabled], with the host platform and the
  /// distribution channel passed in rather than read from the environment.
  /// [isAutoUpdateEnabled] binds them to the running build; tests use this
  /// form to reach combinations the host platform cannot produce.
  static bool isAutoUpdateEnabledFor({
    required bool isIOS,
    required UpdateChannel channel,
  }) {
    if (isIOS) return false;
    return !isStoreChannel(channel);
  }

  /// Returns true for every channel except [UpdateChannel.github].
  /// Store channels manage their own update delivery.
  static bool isStoreChannel(UpdateChannel channel) {
    return channel != UpdateChannel.github;
  }
}
