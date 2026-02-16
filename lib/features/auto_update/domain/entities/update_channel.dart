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

  /// Whether in-app auto-update is enabled.
  /// Always false on iOS and Android (store-only platforms).
  /// Store-distributed builds rely on the store's own update mechanism.
  static bool get isAutoUpdateEnabled {
    if (Platform.isIOS || Platform.isAndroid) return false;
    return !isStoreChannel(current);
  }

  /// Returns true for every channel except [UpdateChannel.github].
  /// Store channels manage their own update delivery.
  static bool isStoreChannel(UpdateChannel channel) {
    return channel != UpdateChannel.github;
  }
}
