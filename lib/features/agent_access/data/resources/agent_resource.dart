import 'package:submersion/features/agent_access/domain/agent_tool.dart';

/// A document an agent may read. Implementations know nothing about the MCP
/// protocol package: the server builder adapts them.
abstract interface class AgentResource {
  String get uri;
  String get name;
  String get mimeType;
  Future<String> read(AgentToolContext context);
}
