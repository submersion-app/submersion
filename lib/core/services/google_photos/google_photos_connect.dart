import 'package:submersion/core/services/google_photos/google_photos_auth_manager.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_store.dart';
import 'package:submersion/core/services/google_photos/google_photos_client_config.dart';
import 'package:submersion/core/services/google_photos/google_photos_redirect_capture.dart';

/// The Google Photos OAuth connect step, behind a seam so the settings page
/// can be driven in a widget test without a real browser or a build-time
/// OAuth client.
abstract class GooglePhotosConnect {
  /// Whether this build carries a usable OAuth client + redirect. False in
  /// `flutter test` and in any build without the `GOOGLE_PHOTOS_*` defines,
  /// which is what disables the connect button.
  bool get isConfigured;

  /// Builds the authorize URL, opens an in-app auth session, and exchanges
  /// the redirect for tokens (persisted on the connect-time store key).
  Future<GooglePhotosAuthData> run();
}

/// Production connect: the bundled client from [GooglePhotosClientConfig],
/// the `flutter_web_auth_2` redirect capture, and [GooglePhotosAuthManager].
class DefaultGooglePhotosConnect implements GooglePhotosConnect {
  DefaultGooglePhotosConnect({
    required GooglePhotosAuthManager authManager,
    required GooglePhotosRedirectCapture capture,
  }) : _authManager = authManager,
       _capture = capture;

  final GooglePhotosAuthManager _authManager;
  final GooglePhotosRedirectCapture _capture;

  @override
  bool get isConfigured => GooglePhotosClientConfig.connectFlowConfigured;

  @override
  Future<GooglePhotosAuthData> run() => signInWithGooglePhotos(
    authManager: _authManager,
    capture: _capture,
    redirectUri: GooglePhotosClientConfig.redirectUri,
    redirectScheme: GooglePhotosClientConfig.redirectScheme,
  );
}

/// Runs the Google Photos OAuth dance: builds the authorize URL from the
/// bundled client, opens an in-app auth session via [capture], and exchanges
/// the returned redirect for tokens.
///
/// Tokens are persisted on [authManager]'s store (the connect-time key), so
/// the settings page's account-creation path runs next -- exactly like the
/// Lightroom embedded connect. [redirectUri] / [redirectScheme] default to
/// the compile-time config.
Future<GooglePhotosAuthData> signInWithGooglePhotos({
  required GooglePhotosAuthManager authManager,
  required GooglePhotosRedirectCapture capture,
  String? redirectUri,
  String? redirectScheme,
}) async {
  final uri = redirectUri ?? GooglePhotosClientConfig.redirectUri;
  final scheme = redirectScheme ?? GooglePhotosClientConfig.redirectScheme;
  if (uri.isEmpty || scheme.isEmpty) {
    throw const GooglePhotosAuthException(
      'Google Photos is not configured in this build.',
    );
  }
  final authorizeUrl = authManager.beginAuthorization(redirectUri: uri);
  final redirected = await capture.capture(
    authorizeUrl: authorizeUrl,
    callbackScheme: scheme,
  );
  return authManager.completeAuthorization(redirected);
}
