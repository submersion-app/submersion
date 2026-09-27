import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/connections/data/repositories/connection_map_repository.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';
import 'package:submersion/features/connections/domain/views/connection_presets.dart';
import 'package:submersion/features/connections/domain/views/kind_link.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late db.AppDatabase d;
  late ConnectionMapRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    d = DatabaseService.instance.database;
    repo = ConnectionMapRepository();
    for (final id in ['me', 'other']) {
      await d
          .into(d.divers)
          .insert(
            db.DiversCompanion(
              id: Value(id),
              name: Value(id),
              createdAt: const Value(1),
              updatedAt: const Value(1),
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  test('create, list per diver, rename, update, delete', () async {
    final travel = ConnectionPresets.byId('travel')!.spec;
    final a = await repo.create(diverId: 'me', name: 'Bonaire', spec: travel);
    await repo.create(diverId: 'other', name: 'Theirs', spec: travel);
    expect((await repo.getAll('me')).map((m) => m.name), ['Bonaire']);

    await repo.rename(a.id, 'Bonaire 2025');
    final edited = travel.toggleLink(
      KindLink(ConnectionKind.buddy, ConnectionKind.site),
    );
    await repo.updateSpec(a.id, edited);
    final got = (await repo.getAll('me')).single;
    expect(got.name, 'Bonaire 2025');
    expect(got.spec, edited);

    await repo.delete(a.id);
    expect(await repo.getAll('me'), isEmpty);
    await repo.restore(got);
    expect((await repo.getAll('me')).single.id, a.id);
  });

  test('a row with an unknown kind is skipped but kept', () async {
    await d
        .into(d.connectionMaps)
        .insert(
          const db.ConnectionMapsCompanion(
            id: Value('future'),
            diverId: Value('me'),
            name: Value('From a newer build'),
            spec: Value('{"kinds":["hologram"],"links":[],"min":1}'),
            createdAt: Value(1),
            updatedAt: Value(1),
          ),
        );
    expect(await repo.getAll('me'), isEmpty);
    final rows = await d.select(d.connectionMaps).get();
    expect(rows.map((r) => r.id), ['future']);
  });

  test('writes mark the row pending for sync', () async {
    final m = await repo.create(
      diverId: 'me',
      name: 'X',
      spec: ConnectionPresets.byId('where')!.spec,
    );
    final row = await (d.select(
      d.connectionMaps,
    )..where((t) => t.id.equals(m.id))).getSingle();
    expect(row.hlc, isNotNull, reason: 'markRecordPending stamps the hlc');
  });

  test('undo after delete clears the tombstone', () async {
    final m = await repo.create(
      diverId: 'me',
      name: 'Undo me',
      spec: ConnectionPresets.byId('where')!.spec,
    );
    await repo.delete(m.id);
    await repo.restore(m);
    final tombstones = await (d.select(
      d.deletionLog,
    )..where((t) => t.recordId.equals(m.id))).get();
    expect(tombstones, isEmpty);
    expect((await repo.getAll('me')).single.id, m.id);
  });

  test('renaming or updating a missing map records nothing pending', () async {
    await repo.rename('gone', 'New name');
    await repo.updateSpec('gone', ConnectionPresets.byId('where')!.spec);
    final pending = await (d.select(
      d.syncRecords,
    )..where((t) => t.recordId.equals('gone'))).get();
    expect(pending, isEmpty);
  });
}
