import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/database/database.dart';
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
}
