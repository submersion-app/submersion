/// Thrown by [SuuntoCloudClient] operations against the undocumented
/// Suunto/Sports-Tracker cloud API (api.sports-tracker.com).
///
/// Mirrors `CloudStorageException`'s `displayMessage` convention so callers
/// can surface [message] directly in a snackbar/dialog without a leading
/// `Exception:`/class-name prefix.
class SuuntoApiException implements Exception {
  const SuuntoApiException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  /// True when the server rejected the current session key (HTTP 401):
  /// the caller must clear the cached session and prompt for sign-in again.
  bool get isSessionRejected => message.contains('session rejected');

  String get displayMessage => cause == null ? message : '$message ($cause)';

  @override
  String toString() => 'SuuntoApiException: $displayMessage';
}

/// The export is a Suunto activity, but not a dive (`ActivityType` is not
/// scuba). A subtype so existing `on SuuntoApiException` handlers still
/// catch it, while a file import can tell the diver why it was skipped.
class SuuntoNotADiveException extends SuuntoApiException {
  const SuuntoNotADiveException(super.message);
}
