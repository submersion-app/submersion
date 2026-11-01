/// Why a tool call was refused, as the agent sees it.
enum AgentToolErrorCode {
  demoMode,
  appLocked,
  databaseUnavailable,
  invalidArgument,
  parseError,
  unknownDiver,
  notFound,
  tooManyIds,
  internal;

  /// The snake_case name carried in tool error payloads.
  String get wire => switch (this) {
    demoMode => 'demo_mode',
    appLocked => 'app_locked',
    databaseUnavailable => 'database_unavailable',
    invalidArgument => 'invalid_argument',
    parseError => 'parse_error',
    unknownDiver => 'unknown_diver',
    notFound => 'not_found',
    tooManyIds => 'too_many_ids',
    internal => 'internal',
  };
}

/// A refused tool call. The server turns it into an MCP error result.
class AgentToolException implements Exception {
  const AgentToolException(this.code, this.message, {this.details});

  final AgentToolErrorCode code;
  final String message;
  final Map<String, Object?>? details;

  Map<String, Object?> toJson() => {
    'error': code.wire,
    'message': message,
    'details': details,
  };

  @override
  String toString() => 'AgentToolException(${code.wire}: $message)';
}
