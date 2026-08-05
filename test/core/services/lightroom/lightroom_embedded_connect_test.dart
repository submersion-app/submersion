import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/services/lightroom/adobe_ims_auth_manager.dart';
import 'package:submersion/core/services/lightroom/lightroom_auth_store.dart';
import 'package:submersion/core/services/lightroom/lightroom_embedded_connect.dart';
import 'package:submersion/core/services/lightroom/lightroom_embedded_credential.dart';
import 'package:submersion/core/services/lightroom/lightroom_redirect_capture.dart';

import '../../../support/fake_keychain_storage.dart';

class _FakeCapture implements LightroomRedirectCapture {
  _FakeCapture(this.result);
  final String result;
  Uri? seenUrl;
  String? seenScheme;
  @override
  Future<String> capture({
    required Uri authorizeUrl,
    required String callbackScheme,
  }) async {
    seenUrl = authorizeUrl;
    seenScheme = callbackScheme;
    return result;
  }
}

void main() {
  test('embedded sign-in authorizes with the bundled credential and persists '
      'tokens', () async {
    final requests = <http.Request>[];
    final mock = MockClient((req) async {
      requests.add(req);
      return http.Response(
        jsonEncode({'access_token': 'at1', 'expires_in': 3600}),
        200,
      );
    });
    final manager = AdobeImsAuthManager(
      store: LightroomAuthStore(storage: InMemoryKeychain()),
      httpClient: mock,
      now: () => DateTime.utc(2026, 7, 17, 12),
      verifierGenerator: () => 'a' * 43,
    );
    final capture = _FakeCapture(
      '${LightroomEmbeddedCredential.redirectUri}?code=thecode',
    );

    final data = await signInWithEmbeddedCredential(
      authManager: manager,
      capture: capture,
    );

    expect(
      capture.seenUrl!.queryParameters['client_id'],
      LightroomEmbeddedCredential.clientId,
    );
    expect(capture.seenScheme, LightroomEmbeddedCredential.callbackScheme);
    expect(data.clientId, LightroomEmbeddedCredential.clientId);
    expect(data.redirectUri, LightroomEmbeddedCredential.redirectUri);
    final body = Uri.splitQueryString(requests.single.body);
    expect(body['code'], 'thecode');
    expect(body['redirect_uri'], LightroomEmbeddedCredential.redirectUri);
  });
}
