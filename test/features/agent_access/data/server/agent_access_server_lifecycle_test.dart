import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:submersion/features/agent_access/data/server/agent_access_server.dart';

McpServer _fakeFactory() =>
    McpServer(const Implementation(name: 'fake', version: '0'));

void main() {
  tearDown(() => AgentAccessServer.instance.stop());

  group('AgentAccessServer lifecycle', () {
    test('reports port in use and stays stopped', () async {
      final blocker = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(blocker.close);
      await AgentAccessServer.instance.start(
        port: blocker.port,
        token: () => 't',
        serverFactory: _fakeFactory,
      );
      final status = AgentAccessServer.instance.status;
      expect(status.listening, isFalse);
      expect(status.port, blocker.port);
      expect(status.error, contains('${blocker.port}'));
      expect(status.error, contains('in use'));
    });

    test('start waits for a pending stop on the same port', () async {
      final server = AgentAccessServer.instance;
      await server.start(
        port: 0,
        token: () => 't',
        serverFactory: _fakeFactory,
      );
      final port = server.status.port;
      expect(server.status.listening, isTrue);
      final stopping = server.stop(); // deliberately not awaited first
      await server.start(
        port: port,
        token: () => 't',
        serverFactory: _fakeFactory,
      );
      expect(server.status.listening, isTrue);
      expect(server.status.port, port);
      expect(server.status.error, isNull);
      await stopping;
    });

    test('stop is idempotent and publishes a stopped status', () async {
      final server = AgentAccessServer.instance;
      await server.start(
        port: 0,
        token: () => 't',
        serverFactory: _fakeFactory,
      );
      final seen = <bool>[];
      final sub = server.statusStream.listen((s) => seen.add(s.listening));
      addTearDown(sub.cancel);
      await server.stop();
      await server.stop();
      expect(server.status.listening, isFalse);
      expect(seen, contains(false));
    });
  });
}
