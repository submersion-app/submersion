import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media_store/data/media_stores_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late MediaStoresRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = MediaStoresRepository();
  });

  tearDown(tearDownTestDatabase);

  test('upsertActive records the account', () async {
    await repo.upsertActive(
      storeId: 's1',
      providerType: 's3',
      displayHint: 'media @ minio',
      accountId: 'acct-1',
    );
    expect((await repo.getActive())!.accountId, 'acct-1');
  });

  test('a later announce with no account keeps the recorded one', () async {
    await repo.upsertActive(
      storeId: 's1',
      providerType: 's3',
      displayHint: 'media @ minio',
      accountId: 'acct-1',
    );
    await repo.upsertActive(
      storeId: 's1',
      providerType: 's3',
      displayHint: 'media @ minio',
    );
    expect((await repo.getActive())!.accountId, 'acct-1');
  });

  test('a store announced before accounts were recorded reads null', () async {
    await repo.upsertActive(
      storeId: 's1',
      providerType: 's3',
      displayHint: 'media @ minio',
    );
    expect((await repo.getActive())!.accountId, isNull);
  });
}
