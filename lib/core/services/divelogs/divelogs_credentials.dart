import 'dart:convert';

/// Keychain payload for a divelogs.de account.
///
/// The password is stored because divelogs.de issues expiring JWTs with no
/// refresh grant; re-login is the only renewal path.
class DivelogsCredentials {
  final String username;
  final String password;
  final String? bearerToken;

  const DivelogsCredentials({
    required this.username,
    required this.password,
    this.bearerToken,
  });

  DivelogsCredentials copyWith({String? bearerToken}) => DivelogsCredentials(
    username: username,
    password: password,
    bearerToken: bearerToken ?? this.bearerToken,
  );

  String toJsonString() => jsonEncode({
    'username': username,
    'password': password,
    if (bearerToken != null) 'bearerToken': bearerToken,
  });

  static DivelogsCredentials? fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final username = decoded['username'] as String?;
    final password = decoded['password'] as String?;
    if (username == null || password == null) return null;
    return DivelogsCredentials(
      username: username,
      password: password,
      bearerToken: decoded['bearerToken'] as String?,
    );
  }
}
