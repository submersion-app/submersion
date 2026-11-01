import 'package:drift/drift.dart' show Value;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/agent_access/data/diver_context.dart';
import 'package:submersion/features/agent_access/data/records/record_catalog.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/tools/get_records_tool.dart';
import 'package:submersion/features/agent_access/data/tools/list_records_tool.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/settings/data/repositories/diver_settings_repository.dart';

const kDiverA = 'diver-a';
const kDiverB = 'diver-b';
const kSeedTime = 1700000000000;

/// Two profiles, A the default and active one.
Future<void> seedTwoDivers(AppDatabase db) async {
  for (final (id, isDefault) in [(kDiverA, true), (kDiverB, false)]) {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: id,
            name: id,
            createdAt: kSeedTime,
            updatedAt: kSeedTime,
            isDefault: Value(isDefault),
          ),
        );
  }
}

/// Drives the real tools, so a family test covers the scope, the loader and
/// the mapper together.
class RecordHarness {
  RecordHarness(this.db);

  final AppDatabase db;

  DiverContextLoader get _loader => DiverContextLoader(
    db: () => db,
    divers: DiverRepository(),
    settings: DiverSettingsRepository(),
    localeTag: 'en',
    activeDiverId: () async => kDiverA,
  );

  AgentToolContext get _context => AgentToolContext(db: db, clientName: 'test');

  RecordCatalog get catalog => RecordCatalog(RecordRepositories());

  /// The `get_records` result for [ids].
  Future<Map<String, Object?>> get(
    String entity,
    List<String> ids, {
    String? diverId,
    List<String>? include,
    int? profileLimit,
  }) => GetRecordsTool(loader: _loader, catalog: catalog).call({
    'entity': entity,
    'ids': ids,
    'diver_id': ?diverId,
    'include': ?include,
    'profile_limit': ?profileLimit,
  }, _context);

  /// The one document [id] reads as, or null when it is missing.
  Future<Map<String, Object?>?> one(
    String entity,
    String id, {
    String? diverId,
    List<String>? include,
    int? profileLimit,
  }) async {
    final out = await get(
      entity,
      [id],
      diverId: diverId,
      include: include,
      profileLimit: profileLimit,
    );
    final records = (out['records'] as List).cast<Map<String, Object?>>();
    return records.isEmpty ? null : records.single;
  }

  /// The ids `list_records` returns.
  Future<List<String>> list(
    String entity, {
    String? diverId,
    String? parentId,
  }) async {
    final out = await listing(entity, diverId: diverId, parentId: parentId);
    return [
      for (final r in (out['records'] as List).cast<Map>()) r['id'] as String,
    ];
  }

  /// The full `list_records` result.
  Future<Map<String, Object?>> listing(
    String entity, {
    String? diverId,
    String? parentId,
  }) => ListRecordsTool(loader: _loader, catalog: catalog).call({
    'entity': entity,
    'diver_id': ?diverId,
    'parent_id': ?parentId,
    'limit': 500,
  }, _context);
}
