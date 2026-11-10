import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/sql/sql_window_runner.dart';
import 'package:submersion/features/agent_access/data/tools/agent_tool_registry.dart';
import 'package:submersion/features/agent_access/data/writes/agent_write_services.dart';
import 'package:submersion/features/agent_access/data/writes/write_plan_store.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/agent_access/domain/write_confirmer.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

import '../../../../helpers/test_database.dart';
import '../sql/sql_window_fixture.dart';

class _Allow implements WriteConfirmer {
  @override
  Future<bool> confirm(WriteConfirmation request) async => true;
}

void main() {
  late AppDatabase db;
  late SqlWindowFixture sqlFixture;
  const t = 1700000000000;

  setUpAll(() async {
    sqlFixture = await SqlWindowFixture.create();
  });
  tearDownAll(() => sqlFixture.dispose());

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
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  AgentToolRegistry registry() {
    final divers = DiverRepository();
    final settings = DiverSettingsRepository();
    return AgentToolRegistry.standard(
      loader: DiverContextLoader(
        db: () => db,
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
      followOf: (_) async => null,
      planCaveat: () => 'Check it.',
      writes: AgentWriteServices(
        records: RecordRepositories(),
        plans: WritePlanStore(),
        confirmer: _Allow(),
        confirmEnabled: () => true,
      ),
    );
  }

  group('AgentToolRegistry', () {
    test('standard registry exposes the read and write tools', () {
      expect(
        registry().tools.map((t) => t.name),
        unorderedEquals([
          'list_divers',
          'query',
          'get_records',
          'list_records',
          'sql_query',
          'compute_plan',
          'preview_changes',
          'apply_changes',
          'revert_operation',
        ]),
      );
    });

    test('standard registry exposes the query-language, units and schema '
        'resources', () {
      expect(
        registry().resources.map((r) => r.uri),
        unorderedEquals([
          'submersion://query-language',
          'submersion://units',
          'submersion://schema',
        ]),
      );
    });

    test('toolNamed throws not_found for unknown names', () {
      expect(
        () => registry().toolNamed('nope'),
        throwsA(
          isA<AgentToolException>().having(
            (e) => e.code,
            'code',
            AgentToolErrorCode.notFound,
          ),
        ),
      );
      expect(registry().toolNamed('query').name, 'query');
    });

    test('every tool schema is a JSON object schema', () {
      for (final tool in registry().tools) {
        expect(tool.inputSchema['type'], 'object', reason: tool.name);
        expect(tool.inputSchema['properties'], isA<Map>(), reason: tool.name);
        expect(tool.description, isNotEmpty, reason: tool.name);
      }
    });

    test('units resource lists every profile as JSON', () async {
      final units = registry().resources.singleWhere(
        (r) => r.uri == 'submersion://units',
      );
      expect(units.mimeType, 'application/json');
      final text = await units.read(
        AgentToolContext(db: db, clientName: 'test'),
      );
      final decoded = jsonDecode(text) as List;
      expect(decoded, hasLength(1));
      final row = decoded.single as Map;
      expect(row['diver_id'], 'd1');
      expect((row['units'] as Map)['depth'], 'm');
      expect(row['date_format'], isA<String>());
      expect(row['time_format'], '12h');
    });
  });
}
