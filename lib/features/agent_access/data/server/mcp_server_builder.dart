import 'dart:convert';

import 'package:mcp_dart/mcp_dart.dart';

import 'package:submersion/features/agent_access/data/agent_tool_gate.dart';
import 'package:submersion/features/agent_access/data/resources/agent_resource.dart';
import 'package:submersion/features/agent_access/data/tools/agent_tool_registry.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';

/// Builds the MCP server for one session: every registry tool and resource,
/// each wrapped so the gate runs first and refusals come back as tool errors
/// rather than protocol failures.
///
/// This is the only file that speaks the protocol package's types; the tools
/// and resources know nothing about it.
McpServer buildMcpServer({
  required AgentToolRegistry registry,
  required AgentToolGate gate,
  required String appVersion,
}) {
  final server = McpServer(
    Implementation(name: 'submersion', version: appVersion),
  );
  for (final tool in registry.tools) {
    server.registerTool(
      tool.name,
      description: tool.description,
      inputSchema:
          JsonSchema.fromJson(Map<String, dynamic>.from(tool.inputSchema))
              as JsonObject,
      callback: (args, extra) => _runTool(server, gate, tool, args, extra),
    );
  }
  for (final resource in registry.resources) {
    server.registerResource(
      resource.name,
      resource.uri,
      null,
      (uri, extra) => _readResource(gate, resource),
    );
  }
  return server;
}

Future<CallToolResult> _runTool(
  McpServer server,
  AgentToolGate gate,
  AgentTool tool,
  Map<String, dynamic> args,
  RequestHandlerExtra extra,
) async {
  try {
    final db = gate.open();
    // A 2026 stateless request names its client in the request metadata; a
    // session that went through initialize names it on the server.
    final context = AgentToolContext(
      db: db,
      clientName:
          extra.clientInfo?.name ?? server.server.getClientVersion()?.name,
    );
    final result = await tool.call(Map<String, Object?>.from(args), context);
    return CallToolResult(
      content: [TextContent(text: jsonEncode(result))],
      structuredContent: result,
    );
  } on AgentToolException catch (e) {
    return _errorResult(e.toJson());
  } catch (e) {
    return _errorResult(
      AgentToolException(
        AgentToolErrorCode.internal,
        'The tool failed with ${e.runtimeType}.',
      ).toJson(),
    );
  }
}

Future<ReadResourceResult> _readResource(
  AgentToolGate gate,
  AgentResource resource,
) async {
  final db = gate.open();
  final text = await resource.read(AgentToolContext(db: db, clientName: null));
  return ReadResourceResult(
    contents: [
      TextResourceContents(
        uri: resource.uri,
        text: text,
        mimeType: resource.mimeType,
      ),
    ],
  );
}

CallToolResult _errorResult(Map<String, Object?> error) => CallToolResult(
  isError: true,
  content: [TextContent(text: jsonEncode(error))],
  structuredContent: error,
);
