import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A storage account's nickname (issue #3522): written by the diver, marked
/// pending so it reaches every device, and never touched by a connect path
/// refreshing the technical label.
void main() {
  late ConnectedAccountsRepository repo;
  late SyncRepository sync;

  setUp(() async {
    await setUpTestDatabase();
    sync = SyncRepository();
    repo = ConnectedAccountsRepository(syncRepository: sync);
  });

  tearDown(tearDownTestDatabase);

  Future<bool> isPending(String id) async => (await sync.getPendingRecords())
      .any((r) => r.entityType == 'connectedAccounts' && r.recordId == id);

  test('setNickname stores a trimmed name and marks the row pending', () async {
    final a = await repo.create(kind: AccountKind.s3, label: 'dives @ x');
    await sync.clearPendingRecords();

    await repo.setNickname(a.id, '  Club bucket  ');

    final loaded = (await repo.getById(a.id))!;
    expect(loaded.nickname, 'Club bucket');
    expect(loaded.displayName, 'Club bucket');
    expect(await isPending(a.id), isTrue);
  });

  test('a blank nickname clears it back to the short label', () async {
    final a = await repo.create(
      kind: AccountKind.s3,
      label: 'dives @ s3.eu-west-1.amazonaws.com',
    );
    await repo.setNickname(a.id, 'Club bucket');

    await repo.setNickname(a.id, '   ');

    final loaded = (await repo.getById(a.id))!;
    expect(loaded.nickname, isNull);
    expect(loaded.displayName, 'dives @ Amazon S3');
  });

  test('an unchanged nickname writes nothing', () async {
    final a = await repo.create(kind: AccountKind.s3, label: 'dives @ x');
    await repo.setNickname(a.id, 'Club');
    final before = (await repo.getById(a.id))!.updatedAt;
    await sync.clearPendingRecords();

    await repo.setNickname(a.id, ' Club ');

    expect((await repo.getById(a.id))!.updatedAt, before);
    expect(await isPending(a.id), isFalse);
  });

  test('a connect refreshing the label keeps the nickname', () async {
    final a = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'k',
      label: 'dives @ old.host',
    );
    await repo.setNickname(a.id, 'Club');

    final refreshed = await repo.ensure(
      kind: AccountKind.s3,
      naturalKey: 'k',
      label: 'dives @ new.host',
    );

    expect(refreshed.nickname, 'Club');
    expect((await repo.getById(a.id))!.nickname, 'Club');
  });

  group('sync', () {
    late SyncDataSerializer serializer;

    setUp(() => serializer = SyncDataSerializer());

    test('the nickname travels with the roster row', () async {
      final a = await repo.create(kind: AccountKind.s3, label: 'dives @ x');
      await repo.setNickname(a.id, 'Club');
      final fetched = (await serializer.fetchRecord(
        'connectedAccounts',
        a.id,
      ))!;
      expect(fetched['nickname'], 'Club');

      await serializer.deleteRecord('connectedAccounts', a.id);
      await serializer.upsertRecord('connectedAccounts', fetched);

      expect((await repo.getById(a.id))!.nickname, 'Club');
    });

    test('a row from a peer that predates the column keeps the local '
        'nickname', () async {
      final a = await repo.create(kind: AccountKind.s3, label: 'dives @ x');
      await repo.setNickname(a.id, 'Club');
      final fetched = (await serializer.fetchRecord(
        'connectedAccounts',
        a.id,
      ))!;
      final fromOlderPeer = {...fetched, 'label': 'dives @ y'}
        ..remove('nickname');

      await serializer.upsertRecord('connectedAccounts', fromOlderPeer);

      final account = (await repo.getById(a.id))!;
      expect(account.label, 'dives @ y');
      expect(account.nickname, 'Club');
    });
  });
}
