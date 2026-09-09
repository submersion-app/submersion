import 'package:submersion/core/services/google_photos/google_photos_auth_manager.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_store.dart';
import 'package:submersion/core/services/google_photos/google_photos_client_config.dart';
import 'package:submersion/core/services/google_photos/google_photos_redirect_capture.dart';

/// Runs the Google Photos OAuth dance: builds the authorize URL from the
/// bundled client, opens an in-app auth session via [capture], and exchanges
/// the returned redirect for tokens.
///
/// Tokens are persisted on [authManager]'s store (the connect-time key), so
/// the settings page's account-creation path runs next -- exactly like the
/// Lightroom embedded connect.
Future<GooglePhotosAuthData> signInWithGooglePhotos({
  required GooglePhotosAuthManager authManager,
  required GooglePhotosRedirectCapture capture,
}) async {
  final redirectUri = GooglePhotosClientConfig.redirectUri;
  if (redirectUri.isEmpty) {
    throw const GooglePhotosAuthException(
      'Google Photos is not configured in this build.',
    );
  }
  final authorizeUrl = authManager.beginAuthorization(redirectUri: redirectUri);
  final redirected = await capture.capture(
    authorizeUrl: authorizeUrl,
    callbackScheme: GooglePhotosClientConfig.redirectScheme,
  );
  return authManager.completeAuthorization(redirected);
}
