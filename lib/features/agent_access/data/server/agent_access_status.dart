/// What the settings page shows about the server.
class AgentAccessStatus {
  const AgentAccessStatus({
    required this.listening,
    required this.port,
    this.error,
    this.portInUse = false,
    this.lastRequestAt,
  });

  final bool listening;
  final int port;

  /// Why the server is not listening, in English, for logs and as a last
  /// resort on the settings page.
  final String? error;

  /// True when [error] is a bind failure on [port], which the settings page
  /// can say in the diver's language.
  final bool portInUse;
  final DateTime? lastRequestAt;

  String get url => 'http://127.0.0.1:$port/mcp';

  AgentAccessStatus copyWith({
    bool? listening,
    int? port,
    String? error,
    bool? portInUse,
    DateTime? lastRequestAt,
  }) => AgentAccessStatus(
    listening: listening ?? this.listening,
    port: port ?? this.port,
    error: error ?? this.error,
    portInUse: portInUse ?? this.portInUse,
    lastRequestAt: lastRequestAt ?? this.lastRequestAt,
  );
}
