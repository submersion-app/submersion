import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_manager.dart';
import 'package:submersion/core/services/google_photos/google_photos_auth_store.dart';
import 'package:submersion/core/services/google_photos/google_photos_connect.dart';
import 'package:submersion/core/services/google_photos/google_photos_redirect_capture.dart';

import '../../../support/fake_keychain_storage.dart';

/// Records what it was handed and returns a canned redirect URL.
class _FakeCapture implements GooglePhotosRedirectCapture {
  Uri? authorizeUrl;
  String? callbackScheme;
  String result = 'app://oauth?code=4/redirect-code';

  @override
  Future<String> capture({
    required Uri authorizeUrl,
    required String callbackScheme,
  }) async {
    this.authorizeUrl = authorizeUrl;
    this.callbackScheme = callbackScheme;
    return result;
  }
}

void main() {
  test('signInWithGooglePhotos throws when the build has no redirect '
      'scheme', () async {
    // GOOGLE_PHOTOS_REDIRECT_SCHEME is unset under `flutter test`, so
    // GooglePhotosClientConfig.redirectUri is empty and the flow refuses
    // before opening any browser.
    final manager = GooglePhotosAuthManager(
      store: GooglePhotosAuthStore(storage: InMemoryKeychain()),
      httpClient: MockClient((_) async => http.Response('', 500)),
      clientId: 'cid',
      clientSecret: 'secret',
    );
    final capture = _FakeCapture();

    await expectLater(
      signInWithGooglePhotos(authManager: manager, capture: capture),
      throwsA(isA<GooglePhotosAuthException>()),
    );
    expect(capture.authorizeUrl, isNull, reason: 'no browser opened');
  });

  test('the auth manager drives begin -> capture -> complete', () async {
    // Exercised directly rather than through the config gate: build the
    // authorize URL, hand a redirect back, and confirm the exchange runs.
    final store = GooglePhotosAuthStore(storage: InMemoryKeychain());
    late String tokenGrantType;
    final manager = GooglePhotosAuthManager(
      store: store,
      clientId: 'cid',
      clientSecret: 'secret',
      httpClient: MockClient((req) async {
        tokenGrantType = Uri.splitQueryString(req.body)['grant_type'] ?? '';
        return http.Response(
          jsonEncode({
            'access_token': 'at',
            'refresh_token': 'rt',
            'expires_in': 3600,
          }),
          200,
        );
      }),
      verifierGenerator: () => 'a' * 43,
    );

    final url = manager.beginAuthorization(redirectUri: 'app://oauth');
    expect(url.host, 'accounts.google.com');

    final capture = _FakeCapture();
    final redirect = await capture.capture(
      authorizeUrl: url,
      callbackScheme: 'app',
    );
    final auth = await manager.completeAuthorization(redirect);

    expect(tokenGrantType, 'authorization_code');
    expect(auth.refreshToken, 'rt');
    expect((await store.load())!.refreshToken, 'rt');
  });
}
