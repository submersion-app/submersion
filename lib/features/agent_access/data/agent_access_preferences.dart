import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/agent_access/domain/agent_access_settings.dart';

/// Reads and writes [AgentAccessSettings] in SharedPreferences.
///
/// A stored port outside the bindable range reads back as the default so a
/// corrupt or hand-edited value can never make the server try a port it
/// cannot bind.
class AgentAccessPreferences {
  AgentAccessPreferences(this._prefs);

  static const enabledKey = 'agent_access_enabled';
  static const portKey = 'agent_access_port';
  static const confirmWritesKey = 'agent_access_confirm_writes';

  final SharedPreferences _prefs;

  AgentAccessSettings read() {
    const defaults = AgentAccessSettings();
    final stored = _prefs.get(portKey);
    final storedPort = stored is int ? stored : null;
    final port =
        storedPort != null &&
            storedPort >= kAgentAccessMinPort &&
            storedPort <= kAgentAccessMaxPort
        ? storedPort
        : defaults.port;
    return AgentAccessSettings(
      enabled: _prefs.getBool(enabledKey) ?? defaults.enabled,
      port: port,
      confirmWrites: _prefs.getBool(confirmWritesKey) ?? defaults.confirmWrites,
    );
  }

  Future<void> write(AgentAccessSettings settings) async {
    await _prefs.setBool(enabledKey, settings.enabled);
    await _prefs.setInt(portKey, settings.port);
    await _prefs.setBool(confirmWritesKey, settings.confirmWrites);
  }
}
