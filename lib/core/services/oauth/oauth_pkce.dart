import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// RFC 7636 PKCE helpers, shared by OAuth flows (Dropbox, Adobe IMS).

/// A 43-character code verifier: 32 random bytes, base64url, no padding.
/// [random] is injectable for tests; defaults to a cryptographic source.
String generateCodeVerifier({Random? random}) {
  final rng = random ?? Random.secure();
  final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

/// The S256 code challenge for [verifier]:
/// base64url(SHA-256(ascii(verifier))) without padding.
String codeChallengeS256(String verifier) {
  final digest = sha256.convert(ascii.encode(verifier));
  return base64UrlEncode(digest.bytes).replaceAll('=', '');
}
