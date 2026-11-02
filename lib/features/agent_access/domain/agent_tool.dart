import 'package:submersion/core/database/database.dart';

/// What a tool call knows about its caller: the live database handle the
/// gate resolved for this request, and the MCP client's name when it sent one.
class AgentToolContext {
  const AgentToolContext({required this.db, required this.clientName});

  final AppDatabase db;
  final String? clientName;
}

/// A tool an agent may call. Implementations know nothing about the MCP
/// protocol package: the server builder adapts them.
abstract interface class AgentTool {
  String get name;
  String get description;

  /// A JSON Schema object describing the arguments.
  Map<String, Object?> get inputSchema;

  /// Runs the tool. Throws [AgentToolException] for a refused call.
  Future<Map<String, Object?>> call(
    Map<String, Object?> args,
    AgentToolContext context,
  );
}
