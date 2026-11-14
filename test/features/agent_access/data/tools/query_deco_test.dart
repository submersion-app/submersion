import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/tools/query_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

import '../../../../helpers/test_database.dart';
import '../records/record_harness.dart';

/// `deco` reads the analysis's verdicts for dives that record no deco data
/// (#4461), mirrored into a cache the app fills on demand: the tool has the
/// app bring it up to date before it answers.
void main() {
  late AppDatabase db;
  const t = kSeedTime;

  QueryTool tool(List<(String, Set<String>)> prepared) => QueryTool(
    loader: DiverContextLoader(
      db: () => db,
      divers: DiverRepository(),
      settings: DiverSettingsRepository(),
      localeTag: 'en',
      activeDiverId: () async => kDiverA,
    ),
    catalog: RecordCatalog(RecordRepositories()),
    prepareCaches: (diverId, tables) async {
      prepared.add((diverId, tables));
      // What the app's writer would leave behind for this diver.
      await db
          .into(db.diveDecoStatus)
          .insertOnConflictUpdate(
            DiveDecoStatusCompanion.insert(
              diveId: 'bare',
              hadDeco: true,
              computedAt: t,
            ),
          );
    },
  );

  AgentToolContext ctx() => AgentToolContext(db: db, clientName: 'test');

  setUp(() async {
    db = await setUpTestDatabase();
    await seedTwoDivers(db);
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'bare',
            diverId: const Value(kDiverA),
            diveDateTime: t,
            createdAt: t,
            updatedAt: t,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  test('a deco query answers once the deco cache is prepared', () async {
    final prepared = <(String, Set<String>)>[];
    final out = await tool(
      prepared,
    ).call({'root': 'dives', 'query': 'deco = true'}, ctx());
    expect(out['ids'], ['bare']);
    expect(prepared.single.$1, kDiverA);
    expect(prepared.single.$2, contains(kDiveDecoStatusTable));
  });

  test('a query that reads no cache prepares nothing', () async {
    final prepared = <(String, Set<String>)>[];
    await tool(prepared).call({'root': 'dives', 'query': 'depth > 1'}, ctx());
    expect(prepared.expand((p) => p.$2), isNot(contains(kDiveDecoStatusTable)));
  });
}
