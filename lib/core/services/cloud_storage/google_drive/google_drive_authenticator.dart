import 'package:http/http.dart' as http;

/// Authentication seam for GoogleDriveStorageProvider.
///
/// Two implementations exist: GoogleSignInAuthenticator (iOS/macOS/Android,
/// native google_sign_in flow) and DesktopOAuthAuthenticator (Windows/Linux,
/// loopback OAuth). The boundary is deliberately [http.Client] -- both auth
/// worlds produce an authorized client, and the provider builds its own
/// DriveApi from it, so neither leaks into the Drive REST code.
abstract class GoogleDriveAuthenticator {
  /// Interactive sign-in. May show UI (account sheet or system browser).
  /// Throws CloudStorageException on failure or user cancellation.
  Future<void> authenticate();

  /// Non-interactive re-auth from cached state (google_sign_in lightweight
  /// auth, or a stored refresh token). Never shows UI. Returns false when
  /// re-auth is not possible; must not throw.
  ///
  /// Implementations must not touch secure storage before the user has
  /// opted in by authenticating once (no keychain prompt before opt-in).
  Future<bool> attemptSilentAuth();

  /// The authorized HTTP client, or null when not authenticated.
  http.Client? get authClient;

  /// Signed-in account email, or null when unknown.
  Future<String?> get userEmail;

  /// Sign out and clear stored credentials.
  Future<void> signOut();

  /// Called after an API 401: drop the (stale or revoked) client state so
  /// the next attemptSilentAuth() rebuilds from scratch.
  Future<void> handleAuthFailure();
}
