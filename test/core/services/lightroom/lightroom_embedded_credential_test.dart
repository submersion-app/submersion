import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/lightroom/lightroom_embedded_credential.dart';

void main() {
  test('redirect uri begins with the callback scheme', () {
    expect(
      LightroomEmbeddedCredential.redirectUri.startsWith(
        '${LightroomEmbeddedCredential.callbackScheme}://',
      ),
      isTrue,
    );
  });

  test('client id appears in the redirect uri path', () {
    expect(
      LightroomEmbeddedCredential.redirectUri.contains(
        LightroomEmbeddedCredential.clientId,
      ),
      isTrue,
    );
  });
}
