import 'dart:typed_data';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/species_id/domain/services/float16.dart';

/// Each marine life crop's embedding, on this device only (issue #4668).
/// Stored in half precision: naming needs no more, and it halves the size.
class IdentificationEmbeddingRepository {
  IdentificationEmbeddingRepository({LocalCacheDatabase? database})
    : _database = database;

  final LocalCacheDatabase? _database;

  LocalCacheDatabase get _db =>
      _database ?? LocalCacheDatabaseService.instance.database;

  Future<void> put(
    Map<String, Float32List> byIdentificationId, {
    required String classifierId,
  }) => _db.batch((batch) {
    for (final entry in byIdentificationId.entries) {
      batch.insert(
        _db.identificationEmbeddings,
        IdentificationEmbeddingsCompanion.insert(
          identificationId: entry.key,
          classifierId: classifierId,
          embedding: encodeFloat16(entry.value),
        ),
        mode: InsertMode.insertOrReplace,
      );
    }
  });

  /// The stored embeddings of [ids] made by [classifierId]. One made by
  /// another model is left out: its numbers mean nothing to this one.
  Future<Map<String, Float32List>> get(
    List<String> ids, {
    required String classifierId,
  }) async {
    if (ids.isEmpty) return const {};
    final table = _db.identificationEmbeddings;
    final rows =
        await (_db.select(table)..where(
              (r) =>
                  r.identificationId.isIn(ids) &
                  r.classifierId.equals(classifierId),
            ))
            .get();
    return {
      for (final row in rows)
        row.identificationId: decodeFloat16(row.embedding),
    };
  }

  Future<void> delete(List<String> ids) async {
    if (ids.isEmpty) return;
    await (_db.delete(
      _db.identificationEmbeddings,
    )..where((r) => r.identificationId.isIn(ids))).go();
  }

  Future<void> deleteAll() => _db.delete(_db.identificationEmbeddings).go();
}
