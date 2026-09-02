/// Thrown by [GarminConnectClient] operations against the undocumented
/// Garmin Connect mobile API.
///
/// Mirrors `CloudStorageException`'s `displayMessage` convention so callers
/// can surface [message] directly in a snackbar/dialog without a leading
/// `Exception:`/class-name prefix.
class GarminApiException implements Exception {
  const GarminApiException(this.message, {this.cause, this.statusCode});

  final String message;
  final Object? cause;
  final int? statusCode;

  /// True when the stored session is no longer accepted and the diver has to
  /// sign in again (as opposed to a transient network or server fault).
  bool get isAuthExpired => statusCode == 401 || statusCode == 403;

  String get displayMessage => cause == null ? message : '$message ($cause)';

  @override
  String toString() => 'GarminApiException: $displayMessage';
}

/// Thrown when Garmin answers the sign-in with a challenge this client
/// cannot satisfy programmatically -- currently a CAPTCHA.
///
/// Separate from the generic [GarminApiException] because the only useful
/// remedy is "sign in through the Garmin app or website once, then retry",
/// which the UI phrases differently from an ordinary failure.
class GarminChallengeException extends GarminApiException {
  const GarminChallengeException(super.message);
}
