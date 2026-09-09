import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_manager.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_store.dart';
import 'package:submersion/core/services/oauth/oauth_pkce.dart';

import '../../../support/fake_keychain_storage.dart';

const _redirect = 'http://127.0.0.1:8723/oauth';

String _idToken(Map<String, Object?> claims) {
  String seg(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${seg({'alg': 'none'})}.${seg(claims)}.sig';
}

void main() {
  GooglePhotosAuthManager manager(
    MockClient mock, {
    GooglePhotosAuthStore? store,
  }) => GooglePhotosAuthManager(
    store: store ?? GooglePhotosAuthStore(storage: InMemoryKeychain()),
    httpClient: mock,
    clientId: 'cid',
    clientSecret: 'secret',
    now: () => DateTime.utc(2026, 9, 9, 12),
    verifierGenerator: () => 'a' * 43,
  );

  http.Response tokenResponse(Map<String, Object?> body) =>
      http.Response(jsonEncode(body), 200);

  group('beginAuthorization', () {
    test('builds a Google PKCE URL with offline access and forced '
        'consent', () {
      final m = manager(MockClient((_) async => http.Response('', 500)));
      final uri = m.beginAuthorization(redirectUri: _redirect);
      expect(uri.host, 'accounts.google.com');
      expect(uri.path, '/o/oauth2/v2/auth');
      expect(uri.queryParameters['client_id'], 'cid');
      expect(uri.queryParameters['redirect_uri'], _redirect);
      expect(uri.queryParameters['response_type'], 'code');
      expect(
        uri.queryParameters['scope'],
        contains(
          'https://www.googleapis.com/auth/photospicker.mediaitems.readonly',
        ),
      );
      expect(
        uri.queryParameters['code_challenge'],
        codeChallengeS256('a' * 43),
      );
      expect(uri.queryParameters['code_challenge_method'], 'S256');
      expect(uri.queryParameters['access_type'], 'offline');
      expect(uri.queryParameters['prompt'], 'consent');
    });

    test('rejects an unconfigured build (empty client id)', () {
      final m = GooglePhotosAuthManager(
        store: GooglePhotosAuthStore(storage: InMemoryKeychain()),
        httpClient: MockClient((_) async => http.Response('', 500)),
        clientId: '',
        clientSecret: '',
      );
      expect(
        () => m.beginAuthorization(redirectUri: _redirect),
        throwsA(isA<GooglePhotosAuthException>()),
      );
    });
  });

  group('extractAuthorizationCode', () {
    test('handles a raw code, a redirect URL, and an error redirect', () {
      expect(
        GooglePhotosAuthManager.extractAuthorizationCode('4/abc'),
        '4/abc',
      );
      expect(
        GooglePhotosAuthManager.extractAuthorizationCode(
          '$_redirect?code=4/xyz&scope=email',
        ),
        '4/xyz',
      );
      expect(
        GooglePhotosAuthManager.extractAuthorizationCode(
          '$_redirect?error=access_denied',
        ),
        isNull,
      );
      expect(GooglePhotosAuthManager.extractAuthorizationCode('  '), isNull);
    });
  });

  group('completeAuthorization', () {
    test('exchanges the code, persists the refresh token, and labels the '
        'account from the id_token', () async {
      final store = GooglePhotosAuthStore(storage: InMemoryKeychain());
      late http.Request captured;
      final m = manager(
        MockClient((req) async {
          captured = req;
          return tokenResponse({
            'access_token': 'at1',
            'refresh_token': 'rt1',
            'expires_in': 3600,
            'id_token': _idToken({'email': 'diver@example.com'}),
          });
        }),
        store: store,
      );
      m.beginAuthorization(redirectUri: _redirect);
      final auth = await m.completeAuthorization('$_redirect?code=4/abc');

      expect(auth.refreshToken, 'rt1');
      expect(auth.email, 'diver@example.com');
      expect((await store.load())!.refreshToken, 'rt1');

      final form = Uri.splitQueryString(captured.body);
      expect(form['grant_type'], 'authorization_code');
      expect(form['code'], '4/abc');
      expect(form['code_verifier'], 'a' * 43);
      expect(form['client_secret'], 'secret');
      expect(form['redirect_uri'], _redirect);

      // The freshly cached access token is served without another call.
      expect(await m.getAccessToken(), 'at1');
    });

    test('fails when Google returns no refresh token', () async {
      final m = manager(
        MockClient(
          (_) async =>
              tokenResponse({'access_token': 'at1', 'expires_in': 3600}),
        ),
      );
      m.beginAuthorization(redirectUri: _redirect);
      await expectLater(
        m.completeAuthorization('$_redirect?code=4/abc'),
        throwsA(isA<GooglePhotosAuthException>()),
      );
    });

    test('requires a prior beginAuthorization', () async {
      final m = manager(MockClient((_) async => http.Response('', 500)));
      await expectLater(
        m.completeAuthorization('$_redirect?code=4/abc'),
        throwsA(isA<GooglePhotosAuthException>()),
      );
    });
  });

  group('getAccessToken', () {
    Future<GooglePhotosAuthStore> connectedStore() async {
      final store = GooglePhotosAuthStore(storage: InMemoryKeychain());
      await store.save(const GooglePhotosAuthData(refreshToken: 'rt1'));
      return store;
    }

    test('refreshes through the stored refresh token and caches the '
        'result', () async {
      var calls = 0;
      final m = manager(
        MockClient((req) async {
          calls++;
          final form = Uri.splitQueryString(req.body);
          expect(form['grant_type'], 'refresh_token');
          expect(form['refresh_token'], 'rt1');
          return tokenResponse({'access_token': 'at2', 'expires_in': 3600});
        }),
        store: await connectedStore(),
      );
      expect(await m.getAccessToken(), 'at2');
      expect(await m.getAccessToken(), 'at2');
      expect(calls, 1);
    });

    test('concurrent callers share one refresh request', () async {
      var calls = 0;
      final m = manager(
        MockClient((_) async {
          calls++;
          return tokenResponse({'access_token': 'at3', 'expires_in': 3600});
        }),
        store: await connectedStore(),
      );
      final results = await Future.wait([
        m.getAccessToken(),
        m.getAccessToken(),
        m.getAccessToken(),
      ]);
      expect(results, everyElement('at3'));
      expect(calls, 1);
    });

    test('a rejected refresh grant surfaces as reauth-required', () async {
      final m = manager(
        MockClient(
          (_) async => http.Response('{"error":"invalid_grant"}', 400),
        ),
        store: await connectedStore(),
      );
      await expectLater(
        m.getAccessToken(),
        throwsA(isA<GooglePhotosReauthRequiredException>()),
      );
    });

    test('a 5xx on refresh is a plain auth exception, not reauth-'
        'required', () async {
      final m = manager(
        MockClient((_) async => http.Response('nope', 503)),
        store: await connectedStore(),
      );
      await expectLater(
        m.getAccessToken(),
        throwsA(
          isA<GooglePhotosAuthException>().having(
            (e) => e is GooglePhotosReauthRequiredException,
            'is reauth-required',
            isFalse,
          ),
        ),
      );
    });

    test('throws when the account is not connected', () async {
      final m = manager(MockClient((_) async => http.Response('', 500)));
      await expectLater(
        m.getAccessToken(),
        throwsA(isA<GooglePhotosAuthException>()),
      );
    });
  });

  group('disconnect', () {
    test('revokes the token with Google and clears local state', () async {
      final store = GooglePhotosAuthStore(storage: InMemoryKeychain());
      await store.save(const GooglePhotosAuthData(refreshToken: 'rt1'));
      Uri? revoked;
      final m = manager(
        MockClient((req) async {
          if (req.url.path == '/revoke') {
            revoked = req.url;
            return http.Response('', 200);
          }
          return tokenResponse({'access_token': 'at', 'expires_in': 3600});
        }),
        store: store,
      );
      await m.disconnect();
      expect(revoked?.host, 'oauth2.googleapis.com');
      expect(await store.load(), isNull);
    });

    test('still clears local state when the revoke call fails', () async {
      final store = GooglePhotosAuthStore(storage: InMemoryKeychain());
      await store.save(const GooglePhotosAuthData(refreshToken: 'rt1'));
      final m = manager(
        MockClient((_) async => throw http.ClientException('offline')),
        store: store,
      );
      await m.disconnect();
      expect(await store.load(), isNull);
    });
  });
}
