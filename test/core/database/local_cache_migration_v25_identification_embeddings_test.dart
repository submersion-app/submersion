import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';

/// v25: the embedding of each marine life crop, kept on this device so a
/// pack update can name a fish again without the photo or the model (issue
/// #4668). Never synced or backed up; losing a row costs one re-analysis.

/// A local cache stamped [version] whose earlier tables exist (the backstop
/// creates any that are missing) but which has no embeddings table.
LocalCacheDatabase _existing(int version) => LocalCacheDatabase(
  NativeDatabase.memory(
    setup: (raw) => raw.execute('PRAGMA user_version = $version'),
  ),
);

Future<List<String>> _columns(LocalCacheDatabase db) async =>
    (await db
            .customSelect("PRAGMA table_info('identification_embeddings')")
            .get())
        .map((c) => c.read<String>('name'))
        .toList();

void main() {
  test('the local cache is at least version 25', () {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, greaterThanOrEqualTo(25));
  });

  test('a fresh database has the table', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _columns(db), [
      'identification_id',
      'classifier_id',
      'embedding',
    ]);
  });

  test('a version 24 database gains the table', () async {
    final db = _existing(24);
    addTearDown(db.close);

    await db
        .into(db.identificationEmbeddings)
        .insert(
          IdentificationEmbeddingsCompanion.insert(
            identificationId: 'i1',
            classifierId: 'clf',
            embedding: Uint8List.fromList([0, 60]),
          ),
        );
    expect(await db.select(db.identificationEmbeddings).get(), hasLength(1));
  });

  test('a database stamped 25 without the table is healed', () async {
    // A colliding branch's v25 that never created this table.
    final db = _existing(25);
    addTearDown(db.close);

    expect(await _columns(db), contains('embedding'));
  });
}
