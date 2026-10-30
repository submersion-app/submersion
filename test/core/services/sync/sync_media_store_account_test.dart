import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';

import '../../../helpers/test_database.dart';

/// v302 media_stores.account_id (issue #3482) travels with the store, so a
/// second device learns which account its copies live in.
void main() {
  late SyncDataSerializer serializer;
  late MediaStoresRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
    repo = MediaStoresRepository();
  });

  tearDown(tearDownTestDatabase);

  Future<void> announce({String? accountId}) => repo.upsertActive(
    storeId: 's1',
    providerType: 's3',
    displayHint: 'media @ minio',
    accountId: accountId,
  );

  test('a store\'s account travels with it', () async {
    await announce(accountId: 'acct-1');

    final fetched = (await serializer.fetchRecord('mediaStores', 's1'))!;
    expect(fetched['accountId'], 'acct-1');

    await serializer.deleteRecord('mediaStores', 's1');
    await serializer.upsertRecord('mediaStores', fetched);

    expect((await repo.getById('s1'))!.accountId, 'acct-1');
  });

  test('a row from a peer that predates the column keeps the local '
      'account', () async {
    await announce(accountId: 'acct-1');
    final fetched = (await serializer.fetchRecord('mediaStores', 's1'))!;
    final fromOlderPeer = {...fetched, 'displayHint': 'renamed'}
      ..remove('accountId');

    await serializer.upsertRecord('mediaStores', fromOlderPeer);

    final store = (await repo.getById('s1'))!;
    expect(store.displayHint, 'renamed');
    expect(store.accountId, 'acct-1');
  });

  test('a peer\'s null account keeps the local one', () async {
    await announce(accountId: 'acct-1');
    final fetched = (await serializer.fetchRecord('mediaStores', 's1'))!;
    final fromPeer = {...fetched, 'displayHint': 'renamed', 'accountId': null};

    await serializer.upsertRecord('mediaStores', fromPeer);
    await serializer.upsertRecords('mediaStores', [fromPeer]);

    expect((await repo.getById('s1'))!.accountId, 'acct-1');
  });
}
