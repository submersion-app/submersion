import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_manager.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_auth_store.dart';
import 'package:submersion/core/services/oauth/oauth_pkce.dart';

import '../../../../support/fake_keychain_storage.dart';

void main() {
  late InMemoryKeychain keychain;
  late DropboxAuthStore store;

  setUp(() {
    keychain = InMemoryKeychain();
    store = DropboxAuthStore(storage: keychain);
  });

  DropboxAuthManager manager(MockClient mock, {String appKey = 'test-key'}) =>
      DropboxAuthManager(
        appKey: appKey,
        store: store,
        httpClient: mock,
        now: () => DateTime.utc(2026, 7, 2, 12),
        verifierGenerator: () => 'a' * 43,
      );

  http.Response tokenResponse({String access = 'at-1'}) => http.Response(
    jsonEncode({
      'access_token': access,
      'refresh_token': 'rt-1',
      'expires_in': 14400,
    }),
    200,
    headers: {'content-type': 'application/json'},
  );

  http.Response accountResponse() => http.Response(
    jsonEncode({
      'email': 'diver@example.com',
      'name': {'display_name': 'Diver'},
    }),
    200,
    headers: {'content-type': 'application/json'},
  );

  group('beginAuthorization', () {
    test('builds the PKCE authorize URL without a redirect_uri', () {
      final uri = manager(
        MockClient((_) async => http.Response('', 500)),
      ).beginAuthorization();
      expect(uri.host, 'www.dropbox.com');
      expect(uri.path, '/oauth2/authorize');
      expect(uri.queryParameters['client_id'], 'test-key');
      expect(uri.queryParameters['response_type'], 'code');
      expect(uri.queryParameters['token_access_type'], 'offline');
      expect(uri.queryParameters['code_challenge_method'], 'S256');
      expect(
        uri.queryParameters['code_challenge'],
        codeChallengeS256('a' * 43),
      );
      expect(uri.queryParameters.containsKey('redirect_uri'), isFalse);
    });

    test('throws CloudStorageException when the app key is empty', () {
      final m = manager(
        MockClient((_) async => http.Response('', 500)),
        appKey: '',
      );
      expect(m.beginAuthorization, throwsA(isA<CloudStorageException>()));
    });
  });

  group('completeAuthorization', () {
    test('exchanges code+verifier, fetches account, persists auth', () async {
      final requests = <http.Request>[];
      final mock = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/oauth2/token') return tokenResponse();
        if (request.url.path == '/2/users/get_current_account') {
          return accountResponse();
        }
        return http.Response('unexpected', 500);
      });
      final m = manager(mock);
      m.beginAuthorization();
      final auth = await m.completeAuthorization('the-code');

      final tokenReq = requests.first;
      expect(tokenReq.url.host, 'api.dropboxapi.com');
      final body = Uri.splitQueryString(tokenReq.body);
      expect(body['code'], 'the-code');
      expect(body['grant_type'], 'authorization_code');
      expect(body['code_verifier'], 'a' * 43);
      expect(body['client_id'], 'test-key');
      expect(body.containsKey('redirect_uri'), isFalse);

      expect(auth.refreshToken, 'rt-1');
      expect(auth.email, 'diver@example.com');
      expect(auth.displayName, 'Diver');
      expect((await store.load())!.refreshToken, 'rt-1');
    });

    test('throws when called with no authorization in progress', () async {
      final m = manager(MockClient((_) async => http.Response('', 500)));
      await expectLater(
        m.completeAuthorization('code'),
        throwsA(isA<CloudStorageException>()),
      );
    });

    test('wraps a rejected code as CloudStorageException and does not '
        'persist', () async {
      final mock = MockClient(
        (_) async => http.Response(jsonEncode({'error': 'invalid_grant'}), 400),
      );
      final m = manager(mock);
      m.beginAuthorization();
      await expectLater(
        m.completeAuthorization('bad-code'),
        throwsA(isA<CloudStorageException>()),
      );
      expect(await store.load(), isNull);
    });

    test('wraps a 200 non-JSON token body as CloudStorageException', () async {
      final mock = MockClient(
        (_) async => http.Response('<html>gateway error</html>', 200),
      );
      final m = manager(mock);
      m.beginAuthorization();
      await expectLater(
        m.completeAuthorization('the-code'),
        throwsA(isA<CloudStorageException>()),
      );
      expect(await store.load(), isNull);
    });

    test(
      'still connects when the account response has wrong-typed fields',
      () async {
        final mock = MockClient((request) async {
          if (request.url.path == '/oauth2/token') return tokenResponse();
          if (request.url.path == '/2/users/get_current_account') {
            return http.Response(
              jsonEncode({'email': 42, 'name': 'not-a-map'}),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('unexpected', 500);
        });
        final m = manager(mock);
        m.beginAuthorization();
        final auth = await m.completeAuthorization('the-code');

        expect(auth.refreshToken, 'rt-1');
        expect(auth.email, isNull);
        expect(auth.displayName, isNull);
        expect((await store.load())!.refreshToken, 'rt-1');
      },
    );
  });

  group('getAccessToken', () {
    test('refreshes with the stored refresh token', () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-stored'));
      late http.Request seen;
      final mock = MockClient((request) async {
        seen = request;
        return tokenResponse(access: 'at-fresh');
      });
      expect(await manager(mock).getAccessToken(), 'at-fresh');
      final body = Uri.splitQueryString(seen.body);
      expect(body['grant_type'], 'refresh_token');
      expect(body['refresh_token'], 'rt-stored');
      expect(body['client_id'], 'test-key');
    });

    test('caches the access token across calls', () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-stored'));
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        return tokenResponse();
      });
      final m = manager(mock);
      await m.getAccessToken();
      await m.getAccessToken();
      expect(calls, 1);
    });

    test('concurrent calls share one refresh (single-flight)', () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-stored'));
      var calls = 0;
      final gate = Completer<void>();
      final mock = MockClient((_) async {
        calls++;
        await gate.future;
        return tokenResponse();
      });
      final m = manager(mock);
      final first = m.getAccessToken();
      final second = m.getAccessToken();
      gate.complete();
      expect(await first, 'at-1');
      expect(await second, 'at-1');
      expect(calls, 1);
    });

    test('invalidateAccessToken forces a new refresh', () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-stored'));
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        return tokenResponse(access: 'at-$calls');
      });
      final m = manager(mock);
      expect(await m.getAccessToken(), 'at-1');
      m.invalidateAccessToken();
      expect(await m.getAccessToken(), 'at-2');
      expect(calls, 2);
    });

    test('throws CloudStorageException when not connected', () async {
      final m = manager(MockClient((_) async => http.Response('', 500)));
      await expectLater(
        m.getAccessToken(),
        throwsA(isA<CloudStorageException>()),
      );
    });

    test(
      'a revoked refresh token throws but preserves the stored blob',
      () async {
        await store.save(DropboxAuthData(refreshToken: 'rt-revoked'));
        final mock = MockClient(
          (_) async =>
              http.Response(jsonEncode({'error': 'invalid_grant'}), 400),
        );
        await expectLater(
          manager(mock).getAccessToken(),
          throwsA(isA<CloudStorageException>()),
        );
        expect((await store.load())!.refreshToken, 'rt-revoked');
      },
    );

    test('a failed refresh clears the in-flight guard so the next call '
        'retries', () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-stored'));
      var calls = 0;
      final mock = MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('down', 503);
        return tokenResponse(access: 'at-recovered');
      });
      final m = manager(mock);
      await expectLater(
        m.getAccessToken(),
        throwsA(isA<CloudStorageException>()),
      );
      expect(await m.getAccessToken(), 'at-recovered');
    });
  });

  group('disconnect', () {
    test('revokes best-effort and clears the store', () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-stored'));
      final paths = <String>[];
      final mock = MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path == '/oauth2/token') return tokenResponse();
        return http.Response('', 200);
      });
      await manager(mock).disconnect();
      expect(paths, contains('/2/auth/token/revoke'));
      expect(await store.load(), isNull);
    });

    test('clears the store even when revoke fails', () async {
      await store.save(DropboxAuthData(refreshToken: 'rt-stored'));
      final mock = MockClient((_) async => http.Response('down', 503));
      await manager(mock).disconnect();
      expect(await store.load(), isNull);
    });
  });
}
