import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/change_log/change_log_policy.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/device_local_fields.dart';
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

/// Keys no document may carry: credentials, and values that belong to one
/// device.
final Set<String> kForbiddenDocumentKeys = {
  ...changeLogCredentialColumns,
  for (final keys in deviceLocalSyncColumns.values)
    for (final key in keys) changeLogSqlName(key),
};

/// Fails on a forbidden key or on bytes anywhere inside [value]. Every read
/// the harness makes passes through here, so each family test covers it.
///
/// [expectWireResult] adds the check the server's `jsonEncode` makes.
void expectCleanDocument(Object? value, {String path = r'$'}) {
  switch (value) {
    case final Map<Object?, Object?> map:
      for (final entry in map.entries) {
        expect(
          kForbiddenDocumentKeys,
          isNot(contains(entry.key)),
          reason: 'forbidden key at $path',
        );
        expectCleanDocument(entry.value, path: '$path.${entry.key}');
      }
    case final Uint8List _:
      fail('bytes at $path');
    case final List<Object?> list:
      for (final (index, item) in list.indexed) {
        expectCleanDocument(item, path: '$path[$index]');
      }
    default:
      break;
  }
}

/// [expectCleanDocument] on a whole tool result, which must also encode.
void expectWireResult(Map<String, Object?> result) {
  expectCleanDocument(result);
  expect(() => jsonEncode(result), returnsNormally);
}

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
  }) async {
    final out = await GetRecordsTool(loader: _loader, catalog: catalog).call({
      'entity': entity,
      'ids': ids,
      'diver_id': ?diverId,
      'include': ?include,
      'profile_limit': ?profileLimit,
    }, _context);
    expectWireResult(out);
    return out;
  }

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
  }) async {
    final out = await ListRecordsTool(loader: _loader, catalog: catalog).call({
      'entity': entity,
      'diver_id': ?diverId,
      'parent_id': ?parentId,
      'limit': 500,
    }, _context);
    expectWireResult(out);
    return out;
  }
}
