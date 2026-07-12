import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SyncRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = SyncRepository();
    await repo.getOrCreateMetadata();
  });

  tearDown(() => tearDownTestDatabase());

  test(
    'setSyncAccount writes both the account id and the provider name',
    () async {
      await repo.setSyncAccount(
        accountId: 'acc-1',
        providerType: CloudProviderType.s3,
      );
      expect(await repo.getSyncAccountId(), 'acc-1');
      expect(await repo.getCloudProvider(), CloudProviderType.s3);
    },
  );

  test('clearing the provider also clears the account id', () async {
    await repo.setSyncAccount(
      accountId: 'acc-1',
      providerType: CloudProviderType.dropbox,
    );
    await repo.setCloudProvider(null);
    expect(await repo.getSyncAccountId(), isNull);
    expect(await repo.getCloudProvider(), isNull);
  });

  test(
    'setCloudProvider alone leaves an existing account id in place',
    () async {
      await repo.setSyncAccount(
        accountId: 'acc-1',
        providerType: CloudProviderType.s3,
      );
      await repo.setCloudProvider(CloudProviderType.s3);
      expect(await repo.getSyncAccountId(), 'acc-1');
    },
  );
}
