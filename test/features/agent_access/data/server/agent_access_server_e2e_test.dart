import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/agent_tool_gate.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/server/agent_access_server.dart';
import 'package:submersion/features/agent_access/data/server/mcp_server_builder.dart';
import 'package:submersion/features/agent_access/data/tools/agent_tool_registry.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

import '../../../../helpers/global_test_defaults.dart';
import '../../../../helpers/test_database.dart';

const _token = 'e2e-token-0123456789-abcdefghijklmnopqrstuv';

/// The tool's JSON payload: the structured content when the protocol carried
/// it, otherwise the same JSON from the text block (error results travel as
/// text only).
Map<String, Object?> payload(CallToolResult r) =>
    r.structuredContent ??
    (jsonDecode((r.content.single as TextContent).text) as Map)
        .cast<String, Object?>();

/// Echoes the client name the server put in the tool context.
class _EchoClientTool implements AgentTool {
  @override
  String get name => 'echo_client';
  @override
  String get description => 'test only';
  @override
  Map<String, Object?> get inputSchema => const {
    'type': 'object',
    'properties': <String, Object?>{},
  };
  @override
  Future<Map<String, Object?>> call(
    Map<String, Object?> args,
    AgentToolContext context,
  ) async => {'client': context.clientName};
}

void main() {
  late AppDatabase db;
  late McpClient client;
  const t = 1700000000000;

  AgentToolRegistry registry() {
    final divers = DiverRepository();
    final settings = DiverSettingsRepository();
    final standard = AgentToolRegistry.standard(
      loader: DiverContextLoader(
        db: () => DatabaseService.instance.database,
        divers: divers,
        settings: settings,
        localeTag: 'en',
        activeDiverId: () async => 'd1',
      ),
      divers: divers,
      settings: settings,
      dives: DiveRepository(),
      buddies: BuddyRepository(),
      species: SpeciesRepository(),
      media: MediaRepository(),
      diveTypes: DiveTypeRepository(),
    );
    return AgentToolRegistry(
      tools: [...standard.tools, _EchoClientTool()],
      resources: standard.resources,
    );
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'Diver One',
            createdAt: t,
            updatedAt: t,
            isDefault: const Value(true),
          ),
        );
    for (final (id, depth) in [('dive-20', 20.0), ('dive-40', 40.0)]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: t,
              createdAt: t,
              updatedAt: t,
              diverId: const Value('d1'),
              maxDepth: Value(depth),
            ),
          );
    }
    await AgentAccessServer.instance.start(
      port: 0,
      token: () => _token,
      serverFactory: () => buildMcpServer(
        registry: registry(),
        gate: AgentToolGate(isLocked: () => false),
        appVersion: '9.9.9-test',
      ),
    );
    final status = AgentAccessServer.instance.status;
    expect(status.listening, isTrue, reason: status.error);
    client = McpClient(
      const Implementation(name: 'agent-access-test', version: '1.0.0'),
    );
    await client.connect(
      StreamableHttpClientTransport(
        Uri.parse(status.url),
        opts: StreamableHttpClientTransportOptions(
          requestInit: {
            'headers': {'Authorization': 'Bearer $_token'},
          },
        ),
      ),
    );
  });

  tearDown(() async {
    await client.close();
    await AgentAccessServer.instance.stop();
    if (DatabaseService.instance.databaseOrNull != null) {
      await tearDownTestDatabase();
    }
    applyGlobalTestDefaults();
  });

  group('AgentAccessServer end to end', () {
    test('reports the app as the server implementation', () {
      final info = client.getServerVersion();
      expect(info?.name, 'submersion');
      expect(info?.version, '9.9.9-test');
    });

    test('lists the three tools and two resources', () async {
      final tools = await client.listTools();
      expect(
        tools.tools.map((t) => t.name),
        containsAll(['list_divers', 'query', 'get_records']),
      );
      final resources = await client.listResources();
      expect(
        resources.resources.map((r) => r.uri),
        unorderedEquals(['submersion://query-language', 'submersion://units']),
      );
    });

    test('query then get_records round trip', () async {
      final q = await client.callTool(
        const CallToolRequest(name: 'query', arguments: {'root': 'dives'}),
      );
      expect(q.isError, isFalse);
      final ids = (q.structuredContent!['ids'] as List).cast<String>();
      expect(ids, ['dive-20', 'dive-40']);
      final g = await client.callTool(
        CallToolRequest(
          name: 'get_records',
          arguments: {'entity': 'dives', 'ids': ids},
        ),
      );
      final records = (g.structuredContent!['records'] as List).cast<Map>();
      expect(records.first['max_depth_m'], 20.0);
      expect(records, hasLength(2));
      final text = (g.content.single as TextContent).text;
      expect(text, contains('"max_depth_m":20.0'));
    });

    test('reads the query language resource', () async {
      final r = await client.readResource(
        const ReadResourceRequest(uri: 'submersion://query-language'),
      );
      final text = (r.contents.single as TextResourceContents).text;
      expect(text, contains('query      := or'));
      expect(text, contains('## dives'));
    });

    test('tool error while database unavailable', () async {
      await tearDownTestDatabase();
      final r = await client.callTool(
        const CallToolRequest(name: 'list_divers', arguments: {}),
      );
      expect(r.isError, isTrue);
      expect(payload(r)['error'], 'database_unavailable');
    });

    test('demo mode refuses every tool', () async {
      DemoModeGate.instance.debugActive = true;
      const calls = {
        'list_divers': <String, Object?>{},
        'query': {'root': 'dives'},
        'get_records': {
          'entity': 'dives',
          'ids': ['x'],
        },
      };
      for (final MapEntry(key: name, value: args) in calls.entries) {
        final r = await client.callTool(
          CallToolRequest(name: name, arguments: args),
        );
        expect(r.isError, isTrue, reason: name);
        expect(payload(r)['error'], 'demo_mode', reason: name);
      }
    });

    test(
      'a semantically invalid argument is a tool error, not a crash',
      () async {
        final r = await client.callTool(
          const CallToolRequest(
            name: 'query',
            arguments: {'root': 'dives', 'diver_id': 'nobody'},
          ),
        );
        expect(r.isError, isTrue);
        expect(payload(r)['error'], 'unknown_diver');
      },
    );

    test('client name reaches the tool context', () async {
      final r = await client.callTool(
        const CallToolRequest(name: 'echo_client', arguments: {}),
      );
      expect(payload(r)['client'], 'agent-access-test');
    });
  });
}
