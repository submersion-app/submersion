import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/dropbox/dropbox_pkce.dart';

void main() {
  group('codeChallengeS256', () {
    test('matches the RFC 7636 appendix B vector', () {
      // Vector computed independently (python3 hashlib/base64), not recalled.
      expect(
        codeChallengeS256('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('matches an independently computed vector', () {
      expect(
        codeChallengeS256('a' * 43),
        'ZtNPunH49FD35FWYhT5Tv8I7vRKQJ8uxMaL0_9eHjNA',
      );
    });

    test('produces no base64 padding characters', () {
      expect(codeChallengeS256(generateCodeVerifier()), isNot(contains('=')));
    });
  });

  group('generateCodeVerifier', () {
    test('is 43 chars of the unreserved base64url alphabet', () {
      final verifier = generateCodeVerifier();
      expect(verifier.length, 43);
      expect(RegExp(r'^[A-Za-z0-9\-_]{43}$').hasMatch(verifier), isTrue);
    });

    test('is deterministic for a seeded Random and unique otherwise', () {
      expect(
        generateCodeVerifier(random: Random(7)),
        generateCodeVerifier(random: Random(7)),
      );
      expect(generateCodeVerifier(), isNot(generateCodeVerifier()));
    });
  });
}
