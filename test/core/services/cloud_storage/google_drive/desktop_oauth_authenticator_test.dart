import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/auth_io.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/desktop_oauth_authenticator.dart';
import 'package:submersion/core/services/cloud_storage/google_drive/google_drive_token_store.dart';

class _MemoryTokenStore implements GoogleDriveTokenStore {
  gauth.AccessCredentials? stored;
  int saves = 0;

  @override
  Future<gauth.AccessCredentials?> load() async => stored;

  @override
  Future<void> save(gauth.AccessCredentials credentials) async {
    stored = credentials;
    saves++;
  }

  @override
  Future<void> clear() async => stored = null;
}

/// The authenticator only uses credentialUpdates, close(), and passes the
/// client through as an http.Client; nothing sends real requests in tests.
class _FakeRefreshingClient extends Fake
    implements gauth.AutoRefreshingAuthClient {
  _FakeRefreshingClient(this.credentials);

  @override
  final gauth.AccessCredentials credentials;

  final StreamController<gauth.AccessCredentials> updates =
      StreamController<gauth.AccessCredentials>.broadcast();

  bool closed = false;

  @override
  Stream<gauth.AccessCredentials> get credentialUpdates => updates.stream;

  @override
  void close() => closed = true;
}

String idTokenWithEmail(String email) {
  final payload = base64Url.encode(utf8.encode(jsonEncode({'email': email})));
  return 'header.$payload.signature';
}

gauth.AccessCredentials creds({String? refreshToken, String? idToken}) =>
    gauth.AccessCredentials(
      gauth.AccessToken('Bearer', 'at-1', DateTime.utc(2026, 7, 2, 12)),
      refreshToken,
      DesktopOAuthAuthenticator.scopes,
      idToken: idToken,
    );

void main() {
  late _MemoryTokenStore store;
  late List<http.Request> revokeRequests;

  MockClient baseClient() => MockClient((request) async {
    revokeRequests.add(request);
    return http.Response('{}', 200);
  });

  setUp(() {
    store = _MemoryTokenStore();
    revokeRequests = [];
  });

  DesktopOAuthAuthenticator authenticator({
    gauth.AccessCredentials? consentResult,
    List<_FakeRefreshingClient>? builtClients,
  }) => DesktopOAuthAuthenticator(
    tokenStore: store,
    obtainConsent: (clientId, scopes, client, prompt) async {
      if (consentResult == null) {
        throw Exception('consent should not run in this test');
      }
      prompt('https://accounts.google.com/o/oauth2/auth?fake');
      return consentResult;
    },
    buildClient: (clientId, credentials, base) {
      final fake = _FakeRefreshingClient(credentials);
      builtClients?.add(fake);
      return fake;
    },
    baseClientFactory: baseClient,
    launchBrowser: (url) async {},
  );

  test('attemptSilentAuth returns false with no stored credentials', () async {
    final auth = authenticator();
    expect(await auth.attemptSilentAuth(), isFalse);
    expect(auth.authClient, isNull);
  });

  test('attemptSilentAuth returns false without a refresh token', () async {
    store.stored = creds(refreshToken: null);
    final auth = authenticator();
    expect(await auth.attemptSilentAuth(), isFalse);
  });

  test('attemptSilentAuth installs a client from stored credentials', () async {
    store.stored = creds(
      refreshToken: 'rt-1',
      idToken: idTokenWithEmail('diver@example.com'),
    );
    final built = <_FakeRefreshingClient>[];
    final auth = authenticator(builtClients: built);

    expect(await auth.attemptSilentAuth(), isTrue);
    expect(auth.authClient, isNotNull);
    expect(built, hasLength(1));
    expect(await auth.userEmail, 'diver@example.com');
  });

  test('authenticate stores credentials and installs a client', () async {
    final auth = authenticator(
      consentResult: creds(
        refreshToken: 'rt-9',
        idToken: idTokenWithEmail('new@example.com'),
      ),
    );

    await auth.authenticate();

    expect(store.stored?.refreshToken, 'rt-9');
    expect(auth.authClient, isNotNull);
    expect(await auth.userEmail, 'new@example.com');
  });

  test('a credential update from the refreshing client is persisted', () async {
    store.stored = creds(refreshToken: 'rt-1');
    final built = <_FakeRefreshingClient>[];
    final auth = authenticator(builtClients: built);
    await auth.attemptSilentAuth();

    built.single.updates.add(creds(refreshToken: 'rt-2'));
    await Future<void>.delayed(Duration.zero);

    expect(store.stored?.refreshToken, 'rt-2');
    expect(store.saves, greaterThanOrEqualTo(1));
  });

  test('consent failure surfaces as CloudStorageException', () async {
    final auth = DesktopOAuthAuthenticator(
      tokenStore: store,
      obtainConsent: (clientId, scopes, client, prompt) async =>
          throw Exception('user closed browser'),
      buildClient: (clientId, credentials, base) =>
          _FakeRefreshingClient(credentials),
      baseClientFactory: baseClient,
      launchBrowser: (url) async {},
    );

    expect(auth.authenticate(), throwsA(isA<CloudStorageException>()));
  });

  test('signOut revokes the token and clears the store', () async {
    store.stored = creds(refreshToken: 'rt-1');
    final auth = authenticator();
    await auth.attemptSilentAuth();

    await auth.signOut();

    expect(store.stored, isNull);
    expect(auth.authClient, isNull);
    expect(revokeRequests, hasLength(1));
    expect(revokeRequests.single.url.host, 'oauth2.googleapis.com');
    expect(revokeRequests.single.url.path, '/revoke');
  });

  test('signOut percent-encodes the token in the revocation body', () async {
    // Google refresh tokens contain '/' and other characters that must be
    // percent-encoded in an application/x-www-form-urlencoded body.
    store.stored = creds(refreshToken: '1//0g-token/with+special=chars');
    final auth = authenticator();
    await auth.attemptSilentAuth();

    await auth.signOut();

    expect(
      revokeRequests.single.body,
      'token=${Uri.encodeQueryComponent('1//0g-token/with+special=chars')}',
    );
    // The raw token must not appear unencoded in the body.
    expect(revokeRequests.single.body, isNot(contains('1//0g-token')));
  });

  test('signOut still clears local state when revocation throws', () async {
    store.stored = creds(refreshToken: 'rt-1');
    final auth = DesktopOAuthAuthenticator(
      tokenStore: store,
      obtainConsent: (clientId, scopes, client, prompt) async =>
          throw Exception('unused'),
      buildClient: (clientId, credentials, base) =>
          _FakeRefreshingClient(credentials),
      baseClientFactory: () =>
          MockClient((request) async => throw Exception('offline')),
      launchBrowser: (url) async {},
    );
    await auth.attemptSilentAuth();

    await auth.signOut();

    expect(store.stored, isNull);
    expect(auth.authClient, isNull);
  });

  test(
    'handleAuthFailure clears the client, stored credentials, and email',
    () async {
      store.stored = creds(
        refreshToken: 'rt-1',
        idToken: idTokenWithEmail('diver@example.com'),
      );
      final auth = authenticator();
      await auth.attemptSilentAuth();
      expect(await auth.userEmail, isNotNull);

      await auth.handleAuthFailure();

      expect(auth.authClient, isNull);
      expect(store.stored, isNull);
      expect(await auth.userEmail, isNull);
    },
  );
}
