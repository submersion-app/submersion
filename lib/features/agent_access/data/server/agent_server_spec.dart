import 'package:submersion/features/agent_access/data/agent_tool_gate.dart';
import 'package:submersion/features/agent_access/data/tools/agent_tool_registry.dart';

/// What one MCP session exposes: the tools and resources, the lock gate they
/// consult, and the app version the server introduces itself with.
///
/// Built by the provider without naming any MCP type, so the provider
/// compiles where the MCP server does not (the browser); the native listener
/// turns it into a server per session.
class AgentServerSpec {
  const AgentServerSpec({
    required this.registry,
    required this.gate,
    required this.appVersion,
  });

  final AgentToolRegistry registry;
  final AgentToolGate gate;
  final String appVersion;
}
