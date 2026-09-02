import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/garmin_connect/garmin_oauth1_signer.dart';

/// Expected signatures were generated with `oauthlib` 3.3.1 (a mature,
/// independent OAuth 1.0a implementation) using the same pinned nonce and
/// timestamp, so these assert cross-implementation agreement rather than
/// re-deriving this implementation's own output.
void main() {
  const consumerKey = 'fc3e99d2-118c-44b8-8ae3-03370dde24c0';
  const consumerSecret = 'E08WAR897WEy2knn7aFBrvegVAf0AFdWBBF';
  const nonce = '0123456789abcdef';
  const timestamp = '1700000000';

  String signatureOf(String header) {
    final match = RegExp(r'oauth_signature="([^"]*)"').firstMatch(header);
    return Uri.decodeComponent(match!.group(1)!);
  }

  test('signs a consumer-only GET with query params (preauthorized)', () {
    const signer = GarminOAuth1Signer(
      consumerKey: consumerKey,
      consumerSecret: consumerSecret,
    );

    final header = signer.authorizationHeader(
      method: 'GET',
      url: Uri.parse(
        'https://connectapi.garmin.com/oauth-service/oauth/preauthorized'
        '?ticket=ST-0-abc123-cas'
        '&login-url=https://mobile.integration.garmin.com/gcm/android'
        '&accepts-mfa-tokens=true',
      ),
      nonce: nonce,
      timestamp: timestamp,
    );

    expect(signatureOf(header), 'l/Ho4VoLppeg0QAvNZXPi8Ye7A0=');
    expect(header, contains('oauth_signature_method="HMAC-SHA1"'));
    expect(header, contains('oauth_version="1.0"'));
    expect(header, isNot(contains('oauth_token=')));
  });

  test('signs a token-bearing POST with a form body (exchange)', () {
    const signer = GarminOAuth1Signer(
      consumerKey: consumerKey,
      consumerSecret: consumerSecret,
      token: 'ro-token-xyz',
      tokenSecret: 'ro-secret-xyz',
    );

    final header = signer.authorizationHeader(
      method: 'POST',
      url: Uri.parse(
        'https://connectapi.garmin.com/oauth-service/oauth/exchange/user/2.0',
      ),
      bodyParams: const {'audience': 'GARMIN_CONNECT_MOBILE_ANDROID_DI'},
      nonce: nonce,
      timestamp: timestamp,
    );

    expect(signatureOf(header), 'JJp1FvOGAeywmDYkI5aZMSPz97o=');
    expect(header, contains('oauth_token="ro-token-xyz"'));
  });

  test('folds a non-default port into the signature base string, unlike the '
      'default port for the scheme', () {
    const signer = GarminOAuth1Signer(
      consumerKey: consumerKey,
      consumerSecret: consumerSecret,
    );

    String sign(String url) => signatureOf(
      signer.authorizationHeader(
        method: 'GET',
        url: Uri.parse(url),
        nonce: nonce,
        timestamp: timestamp,
      ),
    );

    final defaultPortImplicit = sign('https://connectapi.garmin.com/path');
    final defaultPortExplicit = sign('https://connectapi.garmin.com:443/path');
    final nonDefaultPort = sign('https://connectapi.garmin.com:8443/path');

    // The default port is normalized away, so leaving it implicit or
    // spelling it out produces an identical signature base string...
    expect(defaultPortImplicit, defaultPortExplicit);
    // ...but a non-default port is part of the authority and must change
    // the signature.
    expect(nonDefaultPort, isNot(defaultPortImplicit));
  });
}
