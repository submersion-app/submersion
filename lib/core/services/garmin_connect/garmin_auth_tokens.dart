/// The long-lived OAuth 1 resource-owner credential Garmin issues once, in
/// exchange for an SSO service ticket.
///
/// This is the credential worth persisting: it survives for roughly a year
/// and can be re-exchanged for a fresh [GarminOAuth2Token] whenever the
/// short-lived access token lapses, so the diver only signs in once.
class GarminOAuth1Token {
  const GarminOAuth1Token({
    required this.token,
    required this.tokenSecret,
    this.mfaToken,
  });

  final String token;
  final String tokenSecret;

  /// Present when the account uses multi-factor auth. Garmin requires it to
  /// be echoed back on the OAuth2 exchange, otherwise the exchange is
  /// rejected and the diver is asked for a code again on every refresh.
  final String? mfaToken;

  Map<String, Object?> toJson() => {
    'token': token,
    'tokenSecret': tokenSecret,
    'mfaToken': mfaToken,
  };

  factory GarminOAuth1Token.fromJson(Map<String, Object?> json) =>
      GarminOAuth1Token(
        token: json['token'] as String,
        tokenSecret: json['tokenSecret'] as String,
        mfaToken: json['mfaToken'] as String?,
      );
}

/// The short-lived bearer token used for actual Connect API calls.
///
/// Not persisted: it expires in about an hour, and re-deriving it from the
/// stored [GarminOAuth1Token] is a single request, so caching it to disk
/// would add a stale-credential failure mode for no benefit.
class GarminOAuth2Token {
  const GarminOAuth2Token({
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
  });

  final String accessToken;
  final String tokenType;
  final DateTime expiresAt;

  /// Treated as expired slightly early so a token is never presented within
  /// its final minute, which would otherwise race an in-flight request.
  bool isExpired({DateTime? now}) => !(now ?? DateTime.now()).isBefore(
    expiresAt.subtract(const Duration(minutes: 1)),
  );

  /// `Bearer <token>`, with the token type normalised -- Garmin returns it
  /// lowercased ("bearer"), which some proxies reject in an Authorization
  /// header.
  String get authorizationHeader {
    final type = tokenType.isEmpty
        ? 'Bearer'
        : tokenType[0].toUpperCase() + tokenType.substring(1).toLowerCase();
    return '$type $accessToken';
  }
}
