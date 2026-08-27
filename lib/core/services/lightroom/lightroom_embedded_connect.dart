import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';
import 'package:submersion/core/services/lightroom/lightroom_embedded_credential.dart';
import 'package:submersion/core/services/lightroom/lightroom_redirect_capture.dart';

/// Signs in with Submersion's bundled Native App credential: builds the IMS
/// authorize URL, opens an in-app auth session via [capture], and exchanges
/// the returned redirect for tokens. Tokens are persisted on [authManager]'s
/// store (the legacy connect-time key), exactly like the BYO copy-paste
/// dialog, so the settings page's existing account-creation path runs next.
Future<LightroomAuthData> signInWithEmbeddedCredential({
  required AdobeImsAuthManager authManager,
  required LightroomRedirectCapture capture,
}) async {
  final authorizeUrl = authManager.beginAuthorization(
    clientId: LightroomEmbeddedCredential.clientId,
    redirectUri: LightroomEmbeddedCredential.redirectUri,
  );
  final redirected = await capture.capture(
    authorizeUrl: authorizeUrl,
    callbackScheme: LightroomEmbeddedCredential.callbackScheme,
  );
  return authManager.completeAuthorization(redirected);
}
