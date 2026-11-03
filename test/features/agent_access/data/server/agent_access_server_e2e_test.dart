import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/agent_tool_gate.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/server/agent_access_server.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/sql/sql_window_runner.dart';
import 'package:submersion/features/agent_access/data/tools/agent_tool_registry.dart';
import 'package:submersion/features/agent_access/data/writes/agent_write_services.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan_store.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

import '../../../../helpers/global_test_defaults.dart';
import '../../../../helpers/test_database.dart';
import '../sql/sql_window_fixture.dart';

const _token = 'e2e-token-0123456789-abcdefghijklmnopqrstuv';

/// The tool's JSON payload: the structured content when the protocol carried
/// it, otherwise the same JSON from the text block (error results travel as
/// text only).
Map<String, Object?> payload(CallToolResult r) =>
    r.structuredContent ??
    (jsonDecode((r.content.single as TextContent).text) as Map)
        .cast<String, Object?>();

class _Allow implements WriteConfirmer {
  @override
  Future<bool> confirm(WriteConfirmation request) async => true;
}

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
  late SqlWindowFixture sqlFixture;
  final plans = WritePlanStore();
  const t = 1700000000000;

  setUpAll(() async {
    sqlFixture = await SqlWindowFixture.create();
  });
  tearDownAll(() => sqlFixture.dispose());

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
      records: RecordRepositories(),
      sql: SqlWindowRunner(
        file: () async => SqlDatabaseFile(path: sqlFixture.path),
      ),
      writes: AgentWriteServices(
        records: RecordRepositories(),
        plans: plans,
        confirmer: _Allow(),
        confirmEnabled: () => true,
        afterDiveWrites: (_) {},
      ),
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
      serverSpec: () => AgentServerSpec(
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
        opts: const StreamableHttpClientTransportOptions(
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

    test('lists every tool and three resources', () async {
      final tools = await client.listTools();
      expect(
        tools.tools.map((t) => t.name),
        unorderedEquals([
          'list_divers',
          'query',
          'get_records',
          'list_records',
          'sql_query',
          'preview_changes',
          'apply_changes',
          'revert_operation',
          // This test's own probe for the client name.
          'echo_client',
        ]),
      );
      final resources = await client.listResources();
      expect(
        resources.resources.map((r) => r.uri),
        unorderedEquals([
          'submersion://query-language',
          'submersion://units',
          'submersion://schema',
        ]),
      );
    });

    test('a change previews, applies and reverts over loopback', () async {
      Future<Map<String, Object?>> call(
        String tool,
        Map<String, dynamic> arguments,
      ) async {
        final out = await client.callTool(
          CallToolRequest(name: tool, arguments: arguments),
        );
        expect(out.isError, isFalse, reason: '$tool: ${payload(out)}');
        return payload(out);
      }

      Future<Object?> depth() async {
        final out = await call('get_records', {
          'entity': 'dives',
          'ids': ['dive-20'],
        });
        return ((out['records']! as List).single as Map)['max_depth_m'];
      }

      final plan = await call('preview_changes', {
        'label': 'Correct the depth',
        'operations': [
          {
            'op': 'update',
            'entity': 'dives',
            'id': 'dive-20',
            'fields': {'max_depth_m': 22.5},
          },
        ],
      });
      expect(plan['applicable'], isTrue);
      expect(await depth(), 20.0);

      final applied = await call('apply_changes', {'plan_id': plan['plan_id']});
      expect(await depth(), 22.5);

      final operation = (applied['operations']! as List).single as Map;
      await call('revert_operation', {
        'operation_id': operation['operation_id'],
      });
      expect(await depth(), 20.0);
    });

    test('every write tool refuses in demo mode', () async {
      DemoModeGate.instance.debugActive = true;
      addTearDown(() => DemoModeGate.instance.debugActive = false);

      for (final (tool, arguments) in [
        (
          'preview_changes',
          <String, dynamic>{
            'label': 'x',
            'operations': [
              {'op': 'delete', 'entity': 'dives', 'id': 'dive-20'},
            ],
          },
        ),
        ('apply_changes', <String, dynamic>{'plan_id': 'p'}),
        ('revert_operation', <String, dynamic>{'operation_id': 'o'}),
      ]) {
        final out = await client.callTool(
          CallToolRequest(name: tool, arguments: arguments),
        );
        expect(out.isError, isTrue, reason: tool);
        expect(payload(out)['error'], 'demo_mode', reason: tool);
      }
    });

    test('list_records over loopback', () async {
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 'tank-1', diveId: 'dive-20'));
      final out = await client.callTool(
        const CallToolRequest(
          name: 'list_records',
          arguments: {'entity': 'dive_tanks', 'parent_id': 'dive-20'},
        ),
      );
      expect(out.isError, isFalse);
      expect(out.structuredContent!['total'], 1);
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

    test('sql_query over loopback, with a bound parameter', () async {
      final r = await client.callTool(
        const CallToolRequest(
          name: 'sql_query',
          arguments: {
            'sql': 'SELECT ? AS answer',
            'params': [42],
          },
        ),
      );
      expect(r.isError, isNot(true));
      expect(r.structuredContent!['rows'], [
        [42],
      ]);
    });

    test('sql_query refuses a denied table with its code', () async {
      final r = await client.callTool(
        const CallToolRequest(
          name: 'sql_query',
          arguments: {'sql': 'SELECT * FROM connected_accounts'},
        ),
      );
      expect(r.isError, true);
      final text = (r.content.single as TextContent).text;
      expect(text, contains('sql_refused'));
      expect(text, contains('connected_accounts'));
    });

    test('reads the schema resource', () async {
      final r = await client.readResource(
        const ReadResourceRequest(uri: 'submersion://schema'),
      );
      final text = (r.contents.single as TextResourceContents).text;
      expect(text, contains('## dives'));
      expect(text, isNot(contains('connected_accounts')));
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

    test('a resource read in demo mode names the refusal', () async {
      DemoModeGate.instance.debugActive = true;
      await expectLater(
        client.readResource(
          const ReadResourceRequest(uri: 'submersion://units'),
        ),
        throwsA(
          isA<McpError>().having(
            (e) => e.message,
            'message',
            contains('demo_mode'),
          ),
        ),
      );
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
