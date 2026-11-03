import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_web_client_id_store.dart';

/// OAuth client configuration for Google Drive sync.
///
/// Only client IDs are committed. OAuth client IDs are public identifiers,
/// safe to commit; the Desktop client's secret is NOT committed and arrives
/// at build time (see [desktopClientSecret]).
///
/// The desktop flow uses PKCE on a loopback redirect (RFC 8252 / Google's
/// native-app OAuth). PKCE alone is not sufficient for Google: its token
/// endpoint authenticates Desktop-app clients with the client secret and
/// rejects the exchange with `invalid_request: client_secret is missing`
/// when it is absent OR sent empty, code_verifier notwithstanding. (Google's
/// iOS/Android client types are true public clients with no secret, which is
/// what the google_sign_in path uses.)
///
/// All clients must belong to the same Google Cloud project so every
/// platform shares the same Drive appDataFolder (it is scoped per project,
/// per user); that is what makes cross-device sync work.
class GoogleDriveClientConfig {
  /// OAuth 2.0 "Desktop app" client used by the loopback flow on Windows,
  /// Linux, and the Developer ID macOS build. Empty until the client is
  /// created in the Google Cloud console; an empty value disables Google
  /// Drive on desktop instead of crashing.
  static const String desktopClientId =
      '433819313354-eotqmtncg57b836gvc2bls3on5ppiu07.apps.googleusercontent.com';

  /// "Web application" client ID passed as serverClientId to
  /// google_sign_in on Android. Empty means initialize() is called without
  /// a serverClientId (sufficient for iOS/macOS, which read GIDClientID
  /// from Info.plist).
  static const String androidServerClientId =
      '433819313354-qughape9gt872m38lgtjam2u4qgbdv3o.apps.googleusercontent.com';

  /// Secret for [desktopClientId], supplied at build time by
  /// `--dart-define=GOOGLE_DRIVE_CLIENT_SECRET=...` and never committed
  /// (see release workflows and scripts/release/build_nosandbox_macos.sh).
  ///
  /// Google documents that an installed-app client secret is not treated as
  /// confidential -- it ships inside every desktop binary by design -- but it
  /// stays out of the repository so GitHub secret scanning has nothing to
  /// block and forks do not inherit this project's client.
  ///
  /// Empty in `flutter test` and in any build that omits the define, which
  /// closes [hasDesktopClient]. What that means differs by platform:
  ///
  /// - **Windows/Linux**: [isSupportedOnThisPlatform] goes false and the Drive
  ///   tile is hidden, since the loopback flow is the only option there.
  /// - **macOS**: the tile is still offered, because a sandboxed build signs
  ///   in through google_sign_in and needs no secret. Only the no-sandbox DMG
  ///   is stuck, and KeychainGatedAuthenticator detects exactly that case and
  ///   fails with a message naming this define instead of a keychain error.
  ///   Deciding availability up front would mean probing the keychain just to
  ///   render the settings list, for every macOS user including those who
  ///   never touch Drive.
  /// - **iOS/Android**: unaffected; they never use the Desktop client.
  static const String desktopClientSecret = String.fromEnvironment(
    'GOOGLE_DRIVE_CLIENT_SECRET',
  );

  /// True when BOTH halves of the Desktop-app client are present in this
  /// build. Split out from [hasDesktopClient] so the rule is testable without
  /// rebuilding under a --dart-define.
  @visibleForTesting
  static bool desktopClientConfigured(String id, String secret) =>
      id.isNotEmpty && secret.isNotEmpty;

  /// True when the Desktop-app client is fully configured in this build.
  static bool get hasDesktopClient =>
      desktopClientConfigured(desktopClientId, desktopClientSecret);

  /// Whether Google Drive can be offered on the current platform/build.
  ///
  /// Single source of truth for both [GoogleDriveStorageProvider.isAvailable]
  /// and the `supportsGoogleDrive` capability flag, so the two cannot drift:
  /// true on iOS/macOS/Android (OAuth config is compile-time), on
  /// Windows/Linux only when the Desktop-app client is compiled in, and in a
  /// browser on any OS, signing in with [webClientId] (issue #4121).
  static bool get isSupportedOnThisPlatform => supportedOn(
    web: HostPlatform.isWeb,
    loopbackPlatform: HostPlatform.isWindows || HostPlatform.isLinux,
    hasDesktopClient: hasDesktopClient,
  );

  /// The rule behind [isSupportedOnThisPlatform], testable on any host.
  @visibleForTesting
  static bool supportedOn({
    required bool web,
    required bool loopbackPlatform,
    required bool hasDesktopClient,
  }) => web || !loopbackPlatform || hasDesktopClient;

  /// Submersion's own "Web application" client (issue #4121), from the
  /// same Google Cloud project as the clients above, so a browser shares the
  /// Drive app folder the installed apps sync through. Build-time, with the
  /// addresses Google authorises it for: `GOOGLE_WEB_CLIENT_ID` and
  /// `GOOGLE_WEB_CLIENT_ORIGINS` (comma-separated), which
  /// `scripts/build_web.sh` passes on from the environment. Empty in every
  /// other build.
  static const String _builtInWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
  );
  static const String _builtInWebClientOrigins = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ORIGINS',
  );

  /// The built-in web client id when this page is served from an address it
  /// is authorised for, else null: anywhere else Google refuses it, and the
  /// page asks for a client id of the user's own instead.
  static String? get builtInWebClientId {
    if (!HostPlatform.isWeb) return null;
    return builtInWebClientIdFor(
      id: _builtInWebClientId,
      origins: _builtInWebClientOrigins,
      pageOrigin: Uri.base.origin,
    );
  }

  /// The rule behind [builtInWebClientId], testable on any host.
  @visibleForTesting
  static String? builtInWebClientIdFor({
    required String id,
    required String origins,
    required String pageOrigin,
  }) {
    if (id.isEmpty) return null;
    String normalized(String origin) {
      var trimmed = origin.trim().toLowerCase();
      while (trimmed.endsWith('/')) {
        trimmed = trimmed.substring(0, trimmed.length - 1);
      }
      return trimmed;
    }

    final page = normalized(pageOrigin);
    final authorised = origins.split(',').map(normalized);
    return authorised.any((o) => o.isNotEmpty && o == page) ? id : null;
  }

  /// The client id a browser signs in with: the built-in one where it
  /// applies, else the one the user entered, or null until they have.
  static Future<String?> webClientId() => resolveWebClientId(
    builtIn: builtInWebClientId,
    stored: GoogleWebClientIdStore().read,
  );

  /// The rule behind [webClientId]. The built-in id wins over one entered
  /// earlier: a client from another project cannot see the library the
  /// installed apps sync.
  @visibleForTesting
  static Future<String?> resolveWebClientId({
    required String? builtIn,
    required Future<String?> Function() stored,
  }) async => builtIn ?? await stored();
}
