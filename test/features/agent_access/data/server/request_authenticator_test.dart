import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/agent_access/data/server/request_authenticator.dart';

void main() {
  const t = 'abcDEF123_-xyz';
  final auth = RequestAuthenticator(() => t);

  group('RequestAuthenticator', () {
    test('accepts the exact bearer token', () {
      expect(auth.accepts('Bearer $t'), isTrue);
    });

    test(
      'rejects missing header, wrong scheme, wrong token, prefix, suffix',
      () {
        expect(auth.accepts(null), isFalse);
        expect(auth.accepts(''), isFalse);
        expect(auth.accepts('Basic $t'), isFalse);
        expect(auth.accepts('Bearer nope'), isFalse);
        expect(auth.accepts('Bearer ${t.substring(0, t.length - 1)}'), isFalse);
        expect(auth.accepts('Bearer ${t}x'), isFalse);
        expect(auth.accepts(t), isFalse);
      },
    );

    test('reads the expected token on every call so a rotation applies', () {
      var current = 'one';
      final rotating = RequestAuthenticator(() => current);
      expect(rotating.accepts('Bearer one'), isTrue);
      current = 'two';
      expect(rotating.accepts('Bearer one'), isFalse);
      expect(rotating.accepts('Bearer two'), isTrue);
    });
  });
}
