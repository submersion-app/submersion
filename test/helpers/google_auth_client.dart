import 'package:googleapis_auth/googleapis_auth.dart' as gauth;
import 'package:http/http.dart' as http;

/// [base] behind the googleapis_auth client production publishes.
///
/// That client raises AccessDeniedException itself for any response carrying
/// www-authenticate, before the caller sees a status, so a Drive auth test
/// through a bare MockClient exercises a path production never takes.
http.Client googleAuthClient(http.Client base) => gauth.authenticatedClient(
  base,
  gauth.AccessCredentials(
    gauth.AccessToken(
      'Bearer',
      'token',
      DateTime.now().toUtc().add(const Duration(hours: 1)),
    ),
    null,
    const [],
  ),
);
