/// Thrown when the base parse worker cannot be used: it failed to start,
/// died, went silent, or reported a bad file.
class BaseParseException implements Exception {
  BaseParseException(this.message);
  final String message;
  @override
  String toString() => 'BaseParseException: $message';
}

/// Main-isolate client for the base-file parse worker. Spawns a worker that
/// reads + parses a serialized sync base document off the UI isolate and streams
/// decoded rows back, pull-backpressured (one ≤500-row batch per [nextDataBatch]).
/// Operations are sequential — one in flight at a time.
