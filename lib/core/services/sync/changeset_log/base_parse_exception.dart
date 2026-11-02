/// Thrown when the base parse worker cannot be used: it failed to start,
/// died, went silent, or reported a bad file.
class BaseParseException implements Exception {
  BaseParseException(this.message);
  final String message;
  @override
  String toString() => 'BaseParseException: $message';
}
