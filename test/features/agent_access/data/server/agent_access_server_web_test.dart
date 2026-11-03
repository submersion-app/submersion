import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/agent_access/data/agent_tool_gate.dart';
import 'package:submersion/features/agent_access/data/server/agent_access_server_web.dart';
import 'package:submersion/features/agent_access/data/server/agent_server_spec.dart';
import 'package:submersion/features/agent_access/data/tools/agent_tool_registry.dart';

/// The browser variant of the MCP listener, imported directly.
void main() {
  AgentServerSpec spec() => AgentServerSpec(
    registry: AgentToolRegistry(tools: const [], resources: const []),
    gate: AgentToolGate(isLocked: () => false),
    appVersion: '0',
  );

  test('web agent access server refuses to start and stays stopped', () async {
    final server = AgentAccessServer.instance;
    expect(server.status.listening, isFalse);
    await expectLater(
      server.start(port: 0, token: () => 'token', serverSpec: spec),
      throwsUnsupportedError,
    );
    expect(server.status.listening, isFalse);
    expect(server.boundHost, isNull);
    await server.stop();
    expect(server.status.listening, isFalse);
  });

  test('web agent access server still publishes errors', () async {
    final server = AgentAccessServer.instance;
    final next = server.statusStream.first;
    server.publishError('no token');
    expect((await next).error, 'no token');
  });
}
