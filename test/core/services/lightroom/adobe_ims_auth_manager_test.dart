import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';
import 'package:submersion/core/services/oauth/oauth_pkce.dart';

import '../../../support/fake_keychain_storage.dart';

void main() {
  AdobeImsAuthManager manager(MockClient mock, {LightroomAuthStore? store}) =>
      AdobeImsAuthManager(
        store: store ?? LightroomAuthStore(storage: InMemoryKeychain()),
        httpClient: mock,
        now: () => DateTime.utc(2026, 7, 11, 12),
        verifierGenerator: () => 'a' * 43,
      );

  final tokenOk = http.Response(
    jsonEncode({
      'access_token': 'at1',
      'refresh_token': 'rt1',
      'expires_in': 3600,
    }),
    200,
  );

  final tokenNoRefresh = http.Response(
    jsonEncode({'access_token': 'at1', 'expires_in': 3600}),
    200,
  );

  test('beginAuthorization builds IMS PKCE URL', () {
    final m = manager(MockClient((_) async => http.Response('', 500)));
    final uri = m.beginAuthorization(clientId: 'cid');
    expect(uri.host, 'ims-na1.adobelogin.com');
    expect(uri.path, '/ims/authorize/v2');
    expect(uri.queryParameters['client_id'], 'cid');
    expect(uri.queryParameters['response_type'], 'code');
    expect(
      uri.queryParameters['redirect_uri'],
      AdobeImsAuthManager.redirectUri,
    );
    expect(uri.queryParameters['scope'], AdobeImsAuthManager.scopes);
    expect(uri.queryParameters['code_challenge'], codeChallengeS256('a' * 43));
    expect(uri.queryParameters['code_challenge_method'], 'S256');
  });

  test('beginAuthorization rejects an empty client id', () {
    final m = manager(MockClient((_) async => tokenOk));
    expect(
      () => m.beginAuthorization(clientId: ''),
      throwsA(isA<CloudStorageException>()),
    );
  });

  test('extractAuthorizationCode handles raw code and redirect URL', () {
    expect(AdobeImsAuthManager.extractAuthorizationCode('abc123'), 'abc123');
    expect(
      AdobeImsAuthManager.extractAuthorizationCode(
        'https://submersion.app/lightroom/callback?code=xyz&state=1',
      ),
      'xyz',
    );
    expect(AdobeImsAuthManager.extractAuthorizationCode('   '), isNull);
    expect(
      AdobeImsAuthManager.extractAuthorizationCode(
        'https://submersion.app/lightroom/callback?error=access_denied',
      ),
      isNull,
    );
  });

  test(
    'completeAuthorization exchanges code with verifier and persists',
    () async {
      final requests = <http.Request>[];
      final mock = MockClient((req) async {
        requests.add(req);
        return tokenOk;
      });
      final keychain = InMemoryKeychain();
      final m = manager(mock, store: LightroomAuthStore(storage: keychain));
      m.beginAuthorization(clientId: 'cid', clientSecret: 'sec');
      final data = await m.completeAuthorization(
        'https://submersion.app/lightroom/callback?code=thecode',
      );
      expect(data.refreshToken, 'rt1');
      expect(data.clientId, 'cid');
      expect(data.clientSecret, 'sec');
      final body = Uri.splitQueryString(requests.single.body);
      expect(body['grant_type'], 'authorization_code');
      expect(body['code'], 'thecode');
      expect(body['code_verifier'], 'a' * 43);
      expect(body['client_id'], 'cid');
      expect(body['client_secret'], 'sec');
      expect(body['redirect_uri'], AdobeImsAuthManager.redirectUri);
      expect(await m.loadAuth(), isNotNull);
    },
  );

  test('completeAuthorization throws without beginAuthorization', () {
    final m = manager(MockClient((_) async => tokenOk));
    expect(m.completeAuthorization('c'), throwsA(isA<CloudStorageException>()));
  });

  test('completeAuthorization rejects input without a code', () async {
    final m = manager(MockClient((_) async => tokenOk));
    m.beginAuthorization(clientId: 'cid');
    await expectLater(
      m.completeAuthorization(
        'https://submersion.app/lightroom/callback?error=denied',
      ),
      throwsA(isA<CloudStorageException>()),
    );
  });

  test(
    'getAccessToken refreshes with stored token, caches, single-flights',
    () async {
      var calls = 0;
      final mock = MockClient((req) async {
        calls++;
        final body = Uri.splitQueryString(req.body);
        expect(body['grant_type'], 'refresh_token');
        expect(body['refresh_token'], 'rt0');
        expect(body['client_id'], 'cid');
        return http.Response(
          jsonEncode({'access_token': 'at1', 'expires_in': 3600}),
          200,
        );
      });
      final store = LightroomAuthStore(storage: InMemoryKeychain());
      await store.save(
        const LightroomAuthData(clientId: 'cid', refreshToken: 'rt0'),
      );
      final m = manager(mock, store: store);
      final results = await Future.wait([
        m.getAccessToken(),
        m.getAccessToken(),
      ]);
      expect(results, ['at1', 'at1']);
      expect(calls, 1);
      expect(await m.getAccessToken(), 'at1');
      expect(calls, 1);
    },
  );

  test('rotated refresh token from IMS is persisted', () async {
    final mock = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'access_token': 'at2',
          'refresh_token': 'rt-rotated',
          'expires_in': 3600,
        }),
        200,
      ),
    );
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(
      const LightroomAuthData(clientId: 'cid', refreshToken: 'rt0'),
    );
    final m = manager(mock, store: store);
    await m.getAccessToken();
    expect((await store.load())!.refreshToken, 'rt-rotated');
  });

  test('4xx refresh throws but preserves stored blob', () async {
    final mock = MockClient((_) async => http.Response('denied', 400));
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(
      const LightroomAuthData(clientId: 'cid', refreshToken: 'rt0'),
    );
    final m = manager(mock, store: store);
    await expectLater(
      m.getAccessToken(),
      throwsA(isA<CloudStorageException>()),
    );
    expect(await store.load(), isNotNull);
  });

  test(
    'failed refresh clears in-flight guard so a retry can recover',
    () async {
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('oops', 503);
        return http.Response(
          jsonEncode({'access_token': 'at9', 'expires_in': 3600}),
          200,
        );
      });
      final store = LightroomAuthStore(storage: InMemoryKeychain());
      await store.save(
        const LightroomAuthData(clientId: 'cid', refreshToken: 'rt0'),
      );
      final m = manager(mock, store: store);
      await expectLater(
        m.getAccessToken(),
        throwsA(isA<CloudStorageException>()),
      );
      expect(await m.getAccessToken(), 'at9');
    },
  );

  test('getAccessToken throws when not connected', () {
    final m = manager(MockClient((_) async => tokenOk));
    expect(m.getAccessToken(), throwsA(isA<CloudStorageException>()));
  });

  test('disconnect clears store', () async {
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(
      const LightroomAuthData(clientId: 'cid', refreshToken: 'rt0'),
    );
    final m = manager(
      MockClient((_) async => http.Response('', 200)),
      store: store,
    );
    await m.disconnect();
    expect(await store.load(), isNull);
  });

  test('completeAuthorization succeeds with no refresh token and no '
      'secret', () async {
    final requests = <http.Request>[];
    final mock = MockClient((req) async {
      requests.add(req);
      return tokenNoRefresh;
    });
    final m = manager(
      mock,
      store: LightroomAuthStore(storage: InMemoryKeychain()),
    );
    m.beginAuthorization(
      clientId: 'cid',
      redirectUri: 'adobe+hash://adobeid/cid',
    );
    final data = await m.completeAuthorization(
      'adobe+hash://adobeid/cid?code=thecode',
    );
    expect(data.refreshToken, isNull);
    expect(data.redirectUri, 'adobe+hash://adobeid/cid');
    final body = Uri.splitQueryString(requests.single.body);
    expect(body.containsKey('client_secret'), isFalse);
    expect(body['redirect_uri'], 'adobe+hash://adobeid/cid');
    expect(await m.loadAuth(), isNotNull);
  });

  test('getAccessToken caches the access token from a refresh-less '
      'exchange', () async {
    final m = manager(MockClient((_) async => tokenNoRefresh));
    m.beginAuthorization(
      clientId: 'cid',
      redirectUri: 'adobe+hash://adobeid/cid',
    );
    await m.completeAuthorization('adobe+hash://adobeid/cid?code=thecode');
    expect(await m.getAccessToken(), 'at1');
  });

  test('getAccessToken raises reauth-required when expired with no refresh '
      'token', () async {
    final store = LightroomAuthStore(storage: InMemoryKeychain());
    await store.save(const LightroomAuthData(clientId: 'cid'));
    final m = manager(MockClient((_) async => tokenNoRefresh), store: store);
    await expectLater(
      m.getAccessToken(),
      throwsA(isA<LightroomReauthRequiredException>()),
    );
  });
}
