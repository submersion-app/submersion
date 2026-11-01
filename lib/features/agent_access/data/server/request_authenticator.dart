import 'dart:convert';

/// Checks the `Authorization: Bearer <token>` header on every request.
///
/// The expected token is read through a function on each call, so a
/// regenerated token applies to the next request without a restart. The
/// comparison walks every byte regardless of where the first mismatch is, so
/// response time does not leak how much of a guess was right.
class RequestAuthenticator {
  RequestAuthenticator(this._expectedToken);

  static const _scheme = 'Bearer ';

  final String Function() _expectedToken;

  bool accepts(String? authorizationHeader) {
    // The scheme name is case-insensitive (RFC 7235); the token is not.
    if (authorizationHeader == null ||
        authorizationHeader.length <= _scheme.length ||
        authorizationHeader.substring(0, _scheme.length).toLowerCase() !=
            _scheme.toLowerCase()) {
      return false;
    }
    final presented = utf8.encode(
      authorizationHeader.substring(_scheme.length),
    );
    final expected = utf8.encode(_expectedToken());
    // No token configured means nothing is accepted, whatever was presented.
    if (expected.isEmpty) return false;
    return _constantTimeEquals(presented, expected);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    var diff = a.length ^ b.length;
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      diff |= x ^ y;
    }
    return diff == 0;
  }
}
