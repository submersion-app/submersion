import 'dart:io';

/// OAuth client configuration for Google Drive sync.
///
/// Only client IDs are committed -- never a client secret. The desktop
/// flow uses PKCE on a loopback redirect (RFC 8252 / Google's native-app
/// OAuth), for which Google lists client_secret as optional; the token
/// exchange is authenticated by the PKCE code_verifier alone. OAuth client
/// IDs are public identifiers, safe to commit.
///
/// All clients must belong to the same Google Cloud project so every
/// platform shares the same Drive appDataFolder (it is scoped per project,
/// per user); that is what makes cross-device sync work.
class GoogleDriveClientConfig {
  /// OAuth 2.0 "Desktop app" client used by the Windows/Linux loopback
  /// flow (PKCE, no secret). Empty until the client is created in the
  /// Google Cloud console; an empty value disables Google Drive on desktop
  /// instead of crashing.
  static const String desktopClientId =
      '433819313354-eotqmtncg57b836gvc2bls3on5ppiu07.apps.googleusercontent.com';

  /// "Web application" client ID passed as serverClientId to
  /// google_sign_in on Android. Empty means initialize() is called without
  /// a serverClientId (sufficient for iOS/macOS, which read GIDClientID
  /// from Info.plist).
  static const String androidServerClientId =
      '433819313354-qughape9gt872m38lgtjam2u4qgbdv3o.apps.googleusercontent.com';

  /// True when the Desktop-app client is configured in this build.
  static bool get hasDesktopClient => desktopClientId.isNotEmpty;

  /// Whether Google Drive can be offered on the current platform/build.
  ///
  /// Single source of truth for both [GoogleDriveStorageProvider.isAvailable]
  /// and the `supportsGoogleDrive` capability flag, so the two cannot drift:
  /// true on iOS/macOS/Android (OAuth config is compile-time), and on
  /// Windows/Linux only when the Desktop-app client is compiled in.
  static bool get isSupportedOnThisPlatform =>
      !(Platform.isWindows || Platform.isLinux) || hasDesktopClient;
}
