import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Issue #3343: view_configs is unique on (diver_id, view_mode), but its rows
/// sync by id. A peer's row for a view this device already holds under
/// another id used to violate that index and fail the sync. Both devices now
/// keep the LOWER id, carrying whichever config was saved last, so the fleet
/// converges without tombstones (the rule tags already follow).
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'd1',
            name: 'Diver',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ViewConfig row(String id, String marker, int updatedAt, {String? hlc}) =>
      ViewConfig(
        id: id,
        diverId: 'd1',
        viewMode: 'table',
        configJson: '{"v":"$marker"}',
        updatedAt: updatedAt,
        hlc: hlc,
      );

  Future<void> seedLocal(ViewConfig local) =>
      db.into(db.viewConfigs).insert(local);

  Future<List<String>> tableRows() async {
    final rows = await (db.select(
      db.viewConfigs,
    )..where((t) => t.viewMode.equals('table'))).get();
    return [for (final r in rows) '${r.id}|${r.configJson}'];
  }

  for (final batch in [false, true]) {
    Future<void> apply(ViewConfig remote) => batch
        ? SyncDataSerializer().upsertRecords('viewConfigs', [remote.toJson()])
        : SyncDataSerializer().upsertRecord('viewConfigs', remote.toJson());

    group(batch ? 'upsertRecords' : 'upsertRecord', () {
      test(
        'a newer peer row with the lower id replaces the local one',
        () async {
          await seedLocal(row('b-local', 'local', 1000));

          await apply(row('a-remote', 'remote', 2000));

          expect(await tableRows(), ['a-remote|{"v":"remote"}']);
        },
      );

      test(
        'a newer peer row with the higher id lands on the local id',
        () async {
          await seedLocal(row('a-local', 'local', 1000));

          await apply(row('b-remote', 'remote', 2000));

          expect(await tableRows(), ['a-local|{"v":"remote"}']);
        },
      );

      test(
        'an older peer row keeps the local config on the lower id',
        () async {
          await seedLocal(row('b-local', 'local', 3000));

          await apply(row('a-remote', 'remote', 2000));

          expect(await tableRows(), ['a-remote|{"v":"local"}']);
        },
      );

      test('a local config kept over the peer row is queued for sync, so the '
          'peer learns it', () async {
        await seedLocal(row('b-local', 'local', 3000));

        await apply(row('a-remote', 'remote', 2000));

        final pending = await SyncRepository().getPendingRecords();
        expect(
          [
            for (final r in pending)
              if (r.entityType == 'viewConfigs') r.recordId,
          ],
          ['a-remote'],
        );
      });

      test('a peer config kept is not queued back to the peer', () async {
        await seedLocal(row('a-local', 'local', 1000));

        await apply(row('b-remote', 'remote', 2000));

        final pending = await SyncRepository().getPendingRecords();
        expect(pending.where((r) => r.entityType == 'viewConfigs'), isEmpty);
      });

      test('the newer clock wins over a later updatedAt', () async {
        await seedLocal(
          row('a-local', 'local', 3000, hlc: '000000000001000:000000:n1'),
        );

        await apply(
          row('b-remote', 'remote', 1000, hlc: '000000000002000:000000:n2'),
        );

        expect(await tableRows(), ['a-local|{"v":"remote"}']);
      });

      test('a row with a clock wins over a legacy row without one', () async {
        await seedLocal(row('a-local', 'local', 3000));

        await apply(
          row('b-remote', 'remote', 1000, hlc: '000000000001000:000000:n2'),
        );

        expect(await tableRows(), ['a-local|{"v":"remote"}']);
      });

      test('a peer row with no rival is stored as it is', () async {
        await apply(row('a-remote', 'remote', 2000));

        expect(await tableRows(), ['a-remote|{"v":"remote"}']);
      });
    });
  }
}
