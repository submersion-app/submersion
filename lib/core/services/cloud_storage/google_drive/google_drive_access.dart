import 'package:googleapis_auth/googleapis_auth.dart' as gauth;

/// What a diver is told when their Google sign-in carries no Drive access.
///
/// Google's granular consent screen gives the Drive scope a checkbox of its
/// own. Left unticked, the sign-in still succeeds with the account's identity
/// alone, so this is an ordinary thing to run into rather than a fault, and
/// ticking the box is the whole of the recovery.
const googleDriveAccessNotAllowed =
    'Google Drive access was not allowed. Sign in again and tick the Google '
    "Drive box on Google's consent page.";

/// Whether [error] is Drive refusing a token for lacking the Drive scope, as
/// opposed to the token being stale.
///
/// Every client the authenticators publish is a googleapis_auth client, which
/// raises [gauth.AccessDeniedException] itself for any response carrying
/// `www-authenticate`. Google sends that header on a 401 (`invalid_token`) and
/// on a 403 for a missing scope (`insufficient_scope`), so neither status
/// reaches the Drive API or the media store, and the challenge the exception
/// quotes is the only thing that tells the two apart.
///
/// The difference decides the response: a stale token is fixed by a silent
/// refresh, while a refresh for a scope that was never granted only mints
/// another token Drive refuses the same way.
bool isMissingDriveScope(Object error) =>
    error is gauth.AccessDeniedException &&
    error.message.contains('insufficient_scope');

/// True when [error] is Google's token endpoint refusing the refresh token
/// itself (revoked, expired, or issued to another client). Any other
/// token-endpoint failure, a 5xx or a malformed response, is an outage
/// rather than a dead grant and must not sign the user out.
bool isRevokedDriveGrant(Object error) =>
    error is gauth.ServerRequestFailedException &&
    switch (error.responseContent) {
      {'error': 'invalid_grant'} => true,
      _ => false,
    };
