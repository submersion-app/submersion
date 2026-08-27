import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test(
    'v84 schema includes sync_peer_cursors and local_publish_states',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final tables = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
          .get();
      final names = tables.map((r) => r.read<String>('name')).toSet();
      expect(names, containsAll(['sync_peer_cursors', 'local_publish_states']));
    },
  );

  test(
    'sync_peer_cursors round-trips a row keyed by (peer, provider)',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db
          .into(db.syncPeerCursors)
          .insert(
            const SyncPeerCursorsCompanion(
              peerDeviceId: Value('peer-1'),
              provider: Value('s3'),
              baseSeqApplied: Value(12),
              lastSeqApplied: Value(20),
              updatedAt: Value(111),
            ),
          );
      final row =
          await (db.select(db.syncPeerCursors)..where(
                (t) =>
                    t.peerDeviceId.equals('peer-1') & t.provider.equals('s3'),
              ))
              .getSingle();
      expect(row.lastSeqApplied, 20);
      expect(row.baseSeqApplied, 12);
    },
  );

  test(
    'local_publish_states defaults headSeq and changesetBytesSinceBase to 0',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await db
          .into(db.localPublishStates)
          .insert(
            const LocalPublishStatesCompanion(
              provider: Value('s3'),
              updatedAt: Value(1),
            ),
          );
      final row = await (db.select(
        db.localPublishStates,
      )..where((t) => t.provider.equals('s3'))).getSingle();
      expect(row.headSeq, 0);
      expect(row.changesetBytesSinceBase, 0);
      expect(row.baseSeq, isNull);
    },
  );

  test('v83 -> v84 upgrade creates both tables', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 83');
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);
    // Force the migration to run by touching the database.
    await db.customSelect('SELECT 1').get();

    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final names = tables.map((r) => r.read<String>('name')).toSet();
    expect(names, containsAll(['sync_peer_cursors', 'local_publish_states']));
  });
}
