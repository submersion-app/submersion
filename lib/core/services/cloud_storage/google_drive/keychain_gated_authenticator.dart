import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/desktop_oauth_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_client_config.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_sign_in_authenticator.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Builds one of the two concrete authenticators on demand.
typedef GoogleDriveAuthenticatorBuilder = GoogleDriveAuthenticator Function();

/// macOS authenticator that defers the choice between google_sign_in and the
/// loopback OAuth flow until the keychain's capabilities are known.
///
/// ## Why macOS needs a gate at all
///
/// GoogleSignIn hard-codes the **data-protection** keychain on macOS:
/// `GIDSignIn` builds its `GTMKeychainStore` with no attributes, and
/// GTMAppAuth's keychain query then always sets `kSecUseDataProtectionKeychain`.
/// The `useFileBasedKeychain` opt-out exists but is never passed, and the store
/// is private, so no app-side setting can redirect it.
///
/// That keychain refuses a process with no keychain access group. The
/// Developer ID DMG (ReleaseNoSandbox) has none and cannot get one: AMFI
/// SIGKILLs a Developer-ID-signed app that declares `keychain-access-groups`
/// without a provisioning profile to authorise it (this shipped once, as the
/// v1.5.2 launch failure). So on that build every sign-in completes in the
/// browser and then dies when the SDK saves the token, surfacing as
/// `GoogleSignInExceptionCode.providerConfigurationError` with the message
/// "keychain error" -- misleading, since nothing about the OAuth client is
/// misconfigured.
///
/// ## Why the probe is the right gate
///
/// The two builds' constraints line up exactly, so one measurement decides
/// both halves:
///
/// - **Non-sandboxed DMG**: data-protection keychain unavailable, so
///   google_sign_in cannot work; no sandbox, so the loopback listener binds
///   freely and [DesktopOAuthAuthenticator] persists its refresh token through
///   [FallbackSecureStorage]'s legacy-keychain fallback.
/// - **Sandboxed App Store / iOS**: the provisioning profile grants the access
///   group, so google_sign_in works; that build has no
///   `com.apple.security.network.server` entitlement, so a loopback listener
///   would fail anyway.
///
/// Probing the real capability rather than a build flag also means a future
/// signing change is picked up automatically instead of silently mismatching.
class KeychainGatedAuthenticator implements GoogleDriveAuthenticator {
  KeychainGatedAuthenticator({
    Future<bool> Function()? legacyKeychainRequired,
    bool Function()? desktopClientConfigured,
    GoogleDriveAuthenticatorBuilder? loopbackAuthenticator,
    GoogleDriveAuthenticatorBuilder? googleSignInAuthenticator,
  }) : _legacyKeychainRequired = legacyKeychainRequired ?? _probeKeychain,
       _desktopClientConfigured = desktopClientConfigured ?? _hasDesktopClient,
       _buildLoopback = loopbackAuthenticator ?? DesktopOAuthAuthenticator.new,
       _buildGoogleSignIn =
           googleSignInAuthenticator ?? GoogleSignInAuthenticator.new;

  static final _log = LoggerService.forClass(KeychainGatedAuthenticator);

  static Future<bool> _probeKeychain() => FallbackSecureStorage(
    const FlutterSecureStorage(),
  ).legacyKeychainRequired();

  static bool _hasDesktopClient() => GoogleDriveClientConfig.hasDesktopClient;

  final Future<bool> Function() _legacyKeychainRequired;
  final bool Function() _desktopClientConfigured;
  final GoogleDriveAuthenticatorBuilder _buildLoopback;
  final GoogleDriveAuthenticatorBuilder _buildGoogleSignIn;

  /// Set once [_resolve] completes; the sync [authClient] getter reads it.
  GoogleDriveAuthenticator? _delegate;

  /// Memoised resolution, shared by concurrent first callers so the keychain
  /// is probed at most once per process.
  Future<GoogleDriveAuthenticator>? _resolution;

  Future<GoogleDriveAuthenticator> _resolve() => _resolution ??= _select();

  Future<GoogleDriveAuthenticator> _select() async {
    final delegate = await _chooseDelegate();
    _delegate = delegate;
    return delegate;
  }

  Future<GoogleDriveAuthenticator> _chooseDelegate() async {
    bool needsLoopback;
    try {
      needsLoopback = await _legacyKeychainRequired();
    } catch (e, stackTrace) {
      // An unreadable keychain leaves the verdict unknown. Keep the
      // long-standing google_sign_in path rather than binding a socket a
      // sandboxed build could not bind, and memoise it: a single process must
      // never flap between two auth backends mid-session.
      _log.warning(
        'Keychain capability probe failed; keeping the google_sign_in flow',
        error: e,
        stackTrace: stackTrace,
      );
      return _buildGoogleSignIn();
    }

    if (!needsLoopback) return _buildGoogleSignIn();

    if (!_desktopClientConfigured()) {
      // Neither backend can work here: google_sign_in dies in the keychain
      // (above) and the loopback exchange has no client secret. Returning
      // google_sign_in anyway would reproduce the misleading "keychain error"
      // this gate exists to eliminate, so say what is actually wrong.
      _log.warning(
        'Data-protection keychain unavailable and the Desktop OAuth client is '
        'incomplete (needs --dart-define=GOOGLE_DRIVE_CLIENT_SECRET); Google '
        'Drive sign-in is disabled in this build',
      );
      return const _UnconfiguredDesktopAuthenticator();
    }

    _log.info(
      'Data-protection keychain unavailable (Developer ID build); using the '
      'loopback OAuth flow for Google Drive',
    );
    return _buildLoopback();
  }

  @override
  http.Client? get authClient => _delegate?.authClient;

  @override
  Future<void> authenticate() async => (await _resolve()).authenticate();

  @override
  Future<bool> attemptSilentAuth() async {
    try {
      return await (await _resolve()).attemptSilentAuth();
    } catch (e, stackTrace) {
      // The seam contract forbids throwing here; a failed resolution must
      // read as "not signed in", not as a crash on a cold launch.
      _log.warning(
        'Silent sign-in could not resolve an authenticator',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  @override
  Future<String?> get userEmail async => (await _resolve()).userEmail;

  @override
  Future<void> signOut() async => (await _resolve()).signOut();

  @override
  Future<void> handleAuthFailure() async =>
      (await _resolve()).handleAuthFailure();
}

/// Stands in when the build can use neither backend: the data-protection
/// keychain is unavailable (so google_sign_in cannot persist a token) and no
/// Desktop client secret was compiled in (so the loopback exchange cannot
/// complete).
///
/// Reports "not signed in" for every silent path and names the real cause on
/// the one path a user actually triggers, rather than deferring to a backend
/// known to fail with an unrelated message.
class _UnconfiguredDesktopAuthenticator implements GoogleDriveAuthenticator {
  const _UnconfiguredDesktopAuthenticator();

  static const String _message =
      'Google Drive is unavailable in this build: it was compiled without '
      'the Desktop OAuth client secret '
      '(--dart-define=GOOGLE_DRIVE_CLIENT_SECRET).';

  @override
  http.Client? get authClient => null;

  @override
  Future<void> authenticate() async =>
      throw const CloudStorageException(_message);

  /// False, never throwing: the seam contract forbids it, and a cold launch
  /// must read as "not signed in" rather than crash.
  @override
  Future<bool> attemptSilentAuth() async => false;

  @override
  Future<String?> get userEmail async => null;

  @override
  Future<void> signOut() async {}

  @override
  Future<void> handleAuthFailure() async {}
}
