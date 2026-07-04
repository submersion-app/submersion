/// OAuth client configuration for Google Drive sync.
///
/// The desktop client ID and secret are committed to source intentionally:
/// Google classifies installed-app client secrets as non-confidential
/// (RFC 8252 section 8.5) -- they ship inside every desktop binary and can
/// not protect anything. Committing them matches standard practice for
/// open-source desktop applications (rclone, the Google Cloud SDK).
///
/// All clients must belong to the same Google Cloud project so every
/// platform shares the same Drive appDataFolder (it is scoped per project,
/// per user); that is what makes cross-device sync work.
class GoogleDriveClientConfig {
  /// OAuth 2.0 "Desktop app" client used by the Windows/Linux loopback
  /// flow. Empty until the client is created in the Google Cloud console;
  /// an empty value disables Google Drive on desktop instead of crashing.
  static const String desktopClientId =
      '433819313354-eotqmtncg57b836gvc2bls3on5ppiu07.apps.googleusercontent.com';
  static const String desktopClientSecret = '';

  /// "Web application" client ID passed as serverClientId to
  /// google_sign_in on Android. Empty means initialize() is called without
  /// a serverClientId (sufficient for iOS/macOS, which read GIDClientID
  /// from Info.plist).
  static const String androidServerClientId =
      '433819313354-qughape9gt872m38lgtjam2u4qgbdv3o.apps.googleusercontent.com';

  /// True when the Desktop-app client is configured in this build.
  static bool get hasDesktopClient =>
      desktopClientId.isNotEmpty && desktopClientSecret.isNotEmpty;
}
