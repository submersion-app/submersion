import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/features/media_store/domain/media_store_reconnect_situation.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_reconnect_provider.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late MediaStoreAttachState attachState;
  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    attachState = MediaStoreAttachState(
      prefs: await SharedPreferences.getInstance(),
    );
    container = ProviderContainer(
      overrides: [mediaStoreAttachStateProvider.overrideWithValue(attachState)],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('a detached device has nothing to reconnect', () async {
    final reconnect = container.read(mediaStoreReconnectProvider);

    expect(await reconnect.inspect(), isA<ReconnectDetached>());
  });

  test("looks the attachment's account up in the roster", () async {
    // An account id the roster does not hold: removed since it attached.
    await attachState.setAttached(
      'store-a',
      providerType: CloudProviderType.dropbox,
      accountId: 'removed-row',
    );

    final reconnect = container.read(mediaStoreReconnectProvider);

    expect(await reconnect.inspect(), isA<ReconnectNeedsAccount>());
  });
}
