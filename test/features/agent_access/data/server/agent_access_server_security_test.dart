import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/agent_access/data/agent_tool_gate.dart';
import 'package:submersion/features/agent_access/data/server/agent_access_server.dart';
import 'package:submersion/features/agent_access/data/server/mcp_server_builder.dart';
import 'package:submersion/features/agent_access/data/tools/agent_tool_registry.dart';

import '../../../../helpers/test_database.dart';

const _token = 'test-token-0123456789-abcdefghijklmnopqrstu';

const _initialize = {
  'jsonrpc': '2.0',
  'id': 1,
  'method': 'initialize',
  'params': {
    'protocolVersion': '2025-06-18',
    'capabilities': <String, Object?>{},
    'clientInfo': {'name': 'raw-test', 'version': '1.0.0'},
  },
};

/// Sends one HTTP/1.1 request over a raw socket so every header, including
/// Host, is under the test's control. Returns (status code, headers, body).
Future<(int, Map<String, String>, String)> rawRequest(
  int port, {
  String? host,
  String? origin,
  String? auth,
  Map<String, Object?> body = _initialize,
  Map<String, String> extraHeaders = const {},
}) async {
  final payload = utf8.encode(jsonEncode(body));
  final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
  final lines = <String>[
    'POST /mcp HTTP/1.1',
    'Host: ${host ?? '127.0.0.1:$port'}',
    'Content-Type: application/json',
    'Accept: application/json, text/event-stream',
    if (origin != null) 'Origin: $origin',
    if (auth != null) 'Authorization: $auth',
    for (final e in extraHeaders.entries) '${e.key}: ${e.value}',
    'Content-Length: ${payload.length}',
    'Connection: close',
    '',
    '',
  ];
  socket.add(utf8.encode(lines.join('\r\n')));
  socket.add(payload);
  await socket.flush();
  final response = await socket
      .fold<List<int>>([], (acc, chunk) => acc..addAll(chunk))
      .timeout(const Duration(seconds: 10));
  socket.destroy();
  final text = utf8.decode(response, allowMalformed: true);
  final headerEnd = text.indexOf('\r\n\r\n');
  final head = headerEnd < 0 ? text : text.substring(0, headerEnd);
  final responseBody = headerEnd < 0 ? '' : text.substring(headerEnd + 4);
  final headLines = head.split('\r\n');
  final status = int.parse(headLines.first.split(' ')[1]);
  final headers = <String, String>{};
  for (final line in headLines.skip(1)) {
    final i = line.indexOf(':');
    if (i > 0) {
      headers[line.substring(0, i).trim().toLowerCase()] = line
          .substring(i + 1)
          .trim();
    }
  }
  return (status, headers, responseBody);
}

void main() {
  late int port;

  setUp(() async {
    await setUpTestDatabase();
    await AgentAccessServer.instance.start(
      port: 0,
      token: () => _token,
      serverFactory: () => buildMcpServer(
        registry: AgentToolRegistry(tools: const [], resources: const []),
        gate: AgentToolGate(isLocked: () => false),
        appVersion: 'test',
      ),
    );
    expect(AgentAccessServer.instance.status.listening, isTrue);
    port = AgentAccessServer.instance.status.port;
  });

  tearDown(() async {
    await AgentAccessServer.instance.stop();
    await tearDownTestDatabase();
  });

  group('AgentAccessServer security', () {
    test('accepts a loopback initialize with the token', () async {
      final (status, headers, body) = await rawRequest(
        port,
        auth: 'Bearer $_token',
      );
      expect(status, 200, reason: body);
      expect(body, contains('"serverInfo"'));
      expect(headers['mcp-session-id'], isNotNull);
    });

    test('refuses a foreign Host header', () async {
      final (status, _, _) = await rawRequest(
        port,
        host: 'evil.example:$port',
        auth: 'Bearer $_token',
      );
      expect(status, 403);
    });

    test('refuses a non-loopback Origin', () async {
      final (status, _, _) = await rawRequest(
        port,
        origin: 'https://evil.example',
        auth: 'Bearer $_token',
      );
      expect(status, 403);
    });

    test('accepts a loopback Origin', () async {
      final (status, _, body) = await rawRequest(
        port,
        origin: 'http://localhost:$port',
        auth: 'Bearer $_token',
      );
      expect(status, 200, reason: body);
    });

    // Without OAuth protected-resource metadata the package answers every
    // authentication failure with 403 rather than a 401 bearer challenge;
    // either way the request is refused before any handler runs.
    test('refuses initialize without a token', () async {
      final (status, _, _) = await rawRequest(port);
      expect(status, 403);
    });

    test('refuses a wrong token', () async {
      final (status, _, _) = await rawRequest(port, auth: 'Bearer nope');
      expect(status, 403);
    });

    test(
      'a tool call without a token is refused even with a session',
      () async {
        final (_, headers, _) = await rawRequest(port, auth: 'Bearer $_token');
        final session = headers['mcp-session-id']!;
        final (status, _, _) = await rawRequest(
          port,
          body: const {'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'},
          extraHeaders: {
            'Mcp-Session-Id': session,
            'MCP-Protocol-Version': '2025-06-18',
          },
        );
        expect(status, 403);
      },
    );

    // The test harness refuses every non-loopback socket, so the proof that
    // the listener is not on a wildcard address is indirect: it was bound
    // with the IPv4 loopback literal, and the IPv6 loopback (which a
    // dual-stack wildcard would answer) refuses the connection.
    test('server is bound to the IPv4 loopback address only', () async {
      expect(AgentAccessServer.instance.boundHost, '127.0.0.1');
      await expectLater(
        Socket.connect(
          InternetAddress.loopbackIPv6,
          port,
          timeout: const Duration(seconds: 3),
        ),
        throwsA(isA<SocketException>()),
      );
    });

    test('status reports the last request time', () async {
      expect(AgentAccessServer.instance.status.lastRequestAt, isNull);
      await rawRequest(port, auth: 'Bearer $_token');
      expect(AgentAccessServer.instance.status.lastRequestAt, isNotNull);
    });
  });
}
