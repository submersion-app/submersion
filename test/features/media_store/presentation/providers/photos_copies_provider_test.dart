// The Using row names the store this device is attached to, never another
// store the library happens to announce (issue #3482 review).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late MediaStoreAttachState attachState;
  late MediaStoresRepository stores;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    attachState = MediaStoreAttachState(
      prefs: await SharedPreferences.getInstance(),
    );
    stores = MediaStoresRepository();
  });

  tearDown(tearDownTestDatabase);

  Future<PhotosCopies> read({bool groupsFail = false}) async {
    final container = ProviderContainer(
      overrides: [
        mediaStoreAttachStateProvider.overrideWithValue(attachState),
        mediaStoresRepositoryProvider.overrideWithValue(stores),
        accountGroupsProvider.overrideWith(
          (ref) async =>
              groupsFail ? throw StateError('keychain locked') : const [],
        ),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(photosCopiesProvider, (_, _) {});
    addTearDown(sub.close);
    return container.read(photosCopiesProvider.future);
  }

  test(
    'an attached store not announced yet is not named after another',
    () async {
      await stores.upsertActive(
        storeId: 'store-b',
        providerType: 'dropbox',
        displayHint: 'Dropbox',
      );
      await attachState.setAttached(
        'store-a',
        providerType: CloudProviderType.s3,
      );

      final copies = await read();

      expect(copies.attached, isTrue);
      expect(copies.store, isNull);
      expect(copies.label, isNull);
    },
  );

  test('a device not attached sees the announced store', () async {
    await stores.upsertActive(
      storeId: 'store-b',
      providerType: 'dropbox',
      displayHint: 'Dropbox',
    );

    final copies = await read();

    expect(copies.attached, isFalse);
    expect(copies.store?.id, 'store-b');
    expect(copies.label, 'Dropbox');
  });

  test(
    'an account probe failure still knows the copies are attached',
    () async {
      await stores.upsertActive(
        storeId: 'store-a',
        providerType: 'dropbox',
        displayHint: 'Dropbox',
      );
      await attachState.setAttached(
        'store-a',
        providerType: CloudProviderType.dropbox,
      );

      final copies = await read(groupsFail: true);

      expect(copies.attached, isTrue);
      expect(copies.group, isNull);
      expect(copies.label, 'Dropbox');
    },
  );
}
