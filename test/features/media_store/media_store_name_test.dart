import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import '../../helpers/test_database.dart';

/// mediaStoreName (issue #3522): a store reads by the nickname of the
/// account this device attached it through, and only while attached to it.
void main() {
  const r2 =
      'photos @ 149b84f66d5479265f3e4d4ad4740926.r2.cloudflarestorage.com';

  late ConnectedAccountsRepository accounts;
  late MediaStoreAttachState attachState;
  late String accountId;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    attachState = MediaStoreAttachState(
      prefs: await SharedPreferences.getInstance(),
    );
    accounts = ConnectedAccountsRepository();
    final account = await accounts.create(kind: AccountKind.s3, label: r2);
    accountId = account.id;
    await accounts.setNickname(accountId, 'Dive photos');
  });

  tearDown(tearDownTestDatabase);

  MediaStoreDescriptor store(String id) =>
      (id: id, providerType: 's3', displayHint: r2, lastSweepAt: null);

  test('the attached store reads by its account nickname', () async {
    await attachState.setAttached(
      'store-a',
      providerType: CloudProviderType.s3,
      accountId: accountId,
    );
    expect(
      await mediaStoreName(
        store('store-a'),
        attachState: attachState,
        accounts: accounts,
      ),
      'Dive photos',
    );
  });

  test('another store never borrows the attached account nickname', () async {
    await attachState.setAttached(
      'store-a',
      providerType: CloudProviderType.s3,
      accountId: accountId,
    );
    expect(
      await mediaStoreName(
        store('store-b'),
        attachState: attachState,
        accounts: accounts,
      ),
      'photos @ Cloudflare R2',
    );
  });
}
