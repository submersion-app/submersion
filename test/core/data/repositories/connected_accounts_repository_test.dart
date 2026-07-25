import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';

import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ConnectedAccountsRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ConnectedAccountsRepository();
  });

  tearDown(() => tearDownTestDatabase());

  test('create then getByKind round-trips secret-free fields', () async {
    final created = await repo.create(
      kind: AccountKind.s3,
      label: 'My MinIO',
      accountIdentifier: 'dive-media @ minio.local',
    );
    final loaded = await repo.getByKind(AccountKind.s3);
    expect(loaded!.id, created.id);
    expect(loaded.label, 'My MinIO');
    expect(loaded.accountIdentifier, 'dive-media @ minio.local');
    expect(loaded.kind, AccountKind.s3);
  });

  test(
    'create honors an explicit id (Lightroom adoption preserves ids)',
    () async {
      final created = await repo.create(
        kind: AccountKind.adobeLightroom,
        label: 'LR',
        id: 'preserved-id',
      );
      expect(created.id, 'preserved-id');
      expect((await repo.getById('preserved-id'))!.label, 'LR');
    },
  );

  test('create marks the record pending for sync and stamps an HLC', () async {
    final created = await repo.create(kind: AccountKind.dropbox, label: 'DB');

    final pending = await db
        .customSelect(
          "SELECT id FROM sync_records "
          "WHERE id = 'connectedAccounts_${created.id}'",
        )
        .get();
    expect(pending, hasLength(1), reason: 'row must be marked pending');

    final hlc = await db
        .customSelect(
          "SELECT hlc FROM connected_accounts WHERE id = '${created.id}'",
        )
        .getSingle();
    expect(hlc.data['hlc'], isNotNull, reason: 'HLC must be stamped');
  });

  test('getAll returns newest first; getByKind filters', () async {
    await repo.create(kind: AccountKind.s3, label: 'A');
    await repo.create(kind: AccountKind.dropbox, label: 'B');
    expect((await repo.getAll()).length, 2);
    expect((await repo.getByKind(AccountKind.dropbox))!.label, 'B');
    expect(await repo.getByKind(AccountKind.icloud), isNull);
  });

  test('updateLabels updates label and accountIdentifier only', () async {
    final created = await repo.create(kind: AccountKind.s3, label: 'Old');
    await repo.updateLabels(created.id, label: 'New', accountIdentifier: 'x');
    final loaded = await repo.getById(created.id);
    expect(loaded!.label, 'New');
    expect(loaded.accountIdentifier, 'x');
    expect(loaded.kind, AccountKind.s3);
  });

  test(
    'delete removes the row and logs a tombstone (not a pending mark)',
    () async {
      final created = await repo.create(kind: AccountKind.s3, label: 'X');
      await repo.delete(created.id);
      expect(await repo.getById(created.id), isNull);

      final tombstones = await db
          .customSelect(
            "SELECT record_id FROM deletion_log "
            "WHERE entity_type = 'connectedAccounts' "
            "AND record_id = '${created.id}'",
          )
          .get();
      expect(tombstones, hasLength(1), reason: 'deletions sync via tombstones');
    },
  );

  test('ensure is idempotent: two calls yield one row', () async {
    final first = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'minio.local|dive-media|media/',
      label: 'dive-media @ minio.local',
    );
    final second = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'minio.local|dive-media|media/',
      label: 'dive-media @ minio.local',
    );
    expect(second.id, first.id);
    expect((await repo.getAll()).length, 1);
  });

  test('ensure uses the deterministic id', () async {
    final account = await repo.ensure(
      kind: AccountKind.icloud,
      naturalKey: 'icloud',
      label: 'iCloud',
    );
    expect(
      account.id,
      accountIdFor(kind: AccountKind.icloud, naturalKey: 'icloud'),
    );
  });

  test('ensure refreshes a drifted label in place', () async {
    final first = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'minio.local|dive-media|media/',
      label: 'old label',
    );
    final second = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'minio.local|dive-media|media/',
      label: 'new label',
    );
    expect(second.id, first.id);
    expect(second.label, 'new label');
    final all = await repo.getAll();
    expect(all.length, 1);
    expect(all.single.label, 'new label');
  });

  test(
    'concurrent ensure calls do not collide on the deterministic id',
    () async {
      // Deterministic ids mean independent writers compute the SAME id, and
      // ensure's existence check is not atomic with its insert. Provider
      // re-derivation, a media-store connect and an inbound sync apply can all
      // be in flight at once; the loser of that race must not throw
      // SqliteException(1555).
      final results = await Future.wait([
        for (var i = 0; i < 4; i++)
          repo.ensure(
            kind: AccountKind.s3,
            naturalKey: 'minio.local|dive-media|media/',
            label: 'dive-media @ minio.local',
          ),
      ]);

      expect(results.map((a) => a.id).toSet(), hasLength(1));
      expect((await repo.getAll()).length, 1);
    },
  );

  test('ensure adopts a row an inbound sync apply already wrote', () async {
    final id = accountIdFor(
      kind: AccountKind.s3,
      naturalKey: 'minio.local|dive-media|media/',
    );
    // Mirrors sync_data_serializer's insertOnConflictUpdate for this table.
    await db
        .into(db.connectedAccounts)
        .insertOnConflictUpdate(
          ConnectedAccountsCompanion.insert(
            id: id,
            kind: AccountKind.s3.name,
            label: 'from peer',
            createdAt: 1,
            updatedAt: 1,
          ),
        );

    final account = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'minio.local|dive-media|media/',
      label: 'dive-media @ minio.local',
    );

    expect(account.id, id);
    expect(account.label, 'dive-media @ minio.local');
    expect((await repo.getAll()).length, 1);
  });

  test('ensure separates two prefixes in one bucket', () async {
    final sync = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'minio.local|shared|submersion-sync/',
      label: 'shared @ minio.local',
    );
    final media = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'minio.local|shared|media/',
      label: 'shared @ minio.local',
    );
    expect(media.id, isNot(sync.id));
    expect((await repo.getAll()).length, 2);
  });
}
