import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/tools/agent_tool_registry.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const t = 1700000000000;

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
        db: db,
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
  }

  group('AgentToolRegistry', () {
    test('standard registry exposes list_divers, query and get_records', () {
      expect(
        registry().tools.map((t) => t.name),
        unorderedEquals(['list_divers', 'query', 'get_records']),
      );
    });

    test(
      'standard registry exposes the query-language and units resources',
      () {
        expect(
          registry().resources.map((r) => r.uri),
          unorderedEquals([
            'submersion://query-language',
            'submersion://units',
          ]),
        );
      },
    );

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
