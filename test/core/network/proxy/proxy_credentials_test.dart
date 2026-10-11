import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/network/proxy/proxy_credentials.dart';
import 'package:submersion/core/network/proxy/proxy_settings.dart';

void main() {
  group('http', () {
    ProxyCredentialsProblem? check(String u, String p) =>
        checkProxyCredentials(ProxyType.http, u, p);

    test('no credentials is fine', () => expect(check('', ''), isNull));
    test(
      'ordinary pair is fine',
      () => expect(check('ann', 's3cr:t@x'), isNull),
    );
    test('username needs a password', () {
      expect(check('ann', ''), ProxyCredentialsProblem.passwordRequired);
    });
    test(
      'password without username is ignored',
      () => expect(check('', 'x'), isNull),
    );
    test('username colon', () {
      expect(check('a:b', 'x'), ProxyCredentialsProblem.usernameHasColon);
    });
    test('username semicolon or edge whitespace', () {
      expect(check('a;b', 'x'), ProxyCredentialsProblem.usernameHasSemicolon);
      expect(
        check(' ann', 'x'),
        ProxyCredentialsProblem.usernameHasEdgeWhitespace,
      );
    });
    test('password semicolon', () {
      expect(check('a', 'x;y'), ProxyCredentialsProblem.passwordHasSemicolon);
    });
    test('password edge whitespace', () {
      expect(
        check('a', ' x'),
        ProxyCredentialsProblem.passwordHasEdgeWhitespace,
      );
      expect(
        check('a', 'x '),
        ProxyCredentialsProblem.passwordHasEdgeWhitespace,
      );
    });
  });

  test('username problems are the username field\'s', () {
    expect(ProxyCredentialsProblem.usernameHasColon.isUsernameProblem, isTrue);
    expect(
      ProxyCredentialsProblem.usernameHasSemicolon.isUsernameProblem,
      isTrue,
    );
    expect(
      ProxyCredentialsProblem.usernameHasEdgeWhitespace.isUsernameProblem,
      isTrue,
    );
    expect(ProxyCredentialsProblem.passwordRequired.isUsernameProblem, isFalse);
    expect(
      ProxyCredentialsProblem.passwordHasSemicolon.isUsernameProblem,
      isFalse,
    );
  });

  group('socks5', () {
    ProxyCredentialsProblem? check(String u, String p) =>
        checkProxyCredentials(ProxyType.socks5, u, p);

    test(
      'colon and semicolon are fine',
      () => expect(check('a:b', 'x;y'), isNull),
    );
    test('username needs a password', () {
      expect(check('a', ''), ProxyCredentialsProblem.passwordRequired);
    });
    test('255 UTF-8 bytes is the limit', () {
      expect(check('a' * 255, 'x'), isNull);
      expect(check('a' * 256, 'x'), ProxyCredentialsProblem.tooLong);
      // Two bytes per character in UTF-8: 128 of them is 256 bytes.
      expect(
        check('a', String.fromCharCode(0xe9) * 128),
        ProxyCredentialsProblem.tooLong,
      );
    });
  });
}
