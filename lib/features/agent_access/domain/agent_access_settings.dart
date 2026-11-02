/// The loopback port the MCP server binds when the diver has not chosen one.
const kAgentAccessDefaultPort = 47831;

/// Lowest port a non-privileged process may bind.
const kAgentAccessMinPort = 1024;

/// Highest TCP port.
const kAgentAccessMaxPort = 65535;

/// Per-device agent access settings.
///
/// These live in SharedPreferences, never in the synced diver settings: a
/// device's listening state and port must not travel to other devices.
class AgentAccessSettings {
  const AgentAccessSettings({
    this.enabled = false,
    this.port = kAgentAccessDefaultPort,
    this.confirmWrites = true,
  });

  /// Whether the in-app MCP server runs while the app is open.
  final bool enabled;

  /// The loopback port the server binds.
  final int port;

  /// Whether `apply_changes` waits for the diver to confirm in Submersion.
  final bool confirmWrites;

  AgentAccessSettings copyWith({
    bool? enabled,
    int? port,
    bool? confirmWrites,
  }) {
    return AgentAccessSettings(
      enabled: enabled ?? this.enabled,
      port: port ?? this.port,
      confirmWrites: confirmWrites ?? this.confirmWrites,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AgentAccessSettings &&
        other.enabled == enabled &&
        other.port == port &&
        other.confirmWrites == confirmWrites;
  }

  @override
  int get hashCode => Object.hash(enabled, port, confirmWrites);

  @override
  String toString() =>
      'AgentAccessSettings(enabled: $enabled, port: $port, '
      'confirmWrites: $confirmWrites)';
}
