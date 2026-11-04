import 'package:submersion/core/services/cloud_storage/google_drive/desktop_oauth_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_sign_in_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/keychain_gated_authenticator.dart';

/// Picks the Drive authenticator for a platform, without reading `Platform`,
/// which is what makes the choice testable on any host.
///
/// macOS is the interesting case: it can use either flow, and which one
/// works depends on how the build is signed rather than on the platform.
/// [KeychainGatedAuthenticator] measures that and decides. A page cannot
/// open the loopback listener, whatever OS the browser reports, so a
/// browser signs in through google_sign_in's web implementation
/// (issue #4121).
GoogleDriveAuthenticator googleDriveAuthenticatorFor({
  bool isWeb = false,
  required bool isLoopbackPlatform,
  required bool isMacOS,
}) {
  if (isWeb) return GoogleSignInAuthenticator();
  if (isLoopbackPlatform) return DesktopOAuthAuthenticator();
  if (isMacOS) return KeychainGatedAuthenticator();
  return GoogleSignInAuthenticator();
}
