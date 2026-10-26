// Issue #3482 phase 5: replace and join detaches this device from its photo
// store before it replaces the library, and puts the attachment back if the
// replace fails, so a failed replace leaves the device as it was.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';

void main() {
  late MediaStoreAttachState state;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = MediaStoreAttachState(prefs: await SharedPreferences.getInstance());
  });

  test('an attachment comes back as it was after a detach', () async {
    await state.setAttached(
      'store-a',
      providerType: CloudProviderType.dropbox,
      accountId: 'db-row',
    );
    await state.setMarkerMismatch(true);
    final snapshot = await state.snapshot();
    await state.clear();
    final generationBefore = await state.attachGeneration();

    await state.restore(snapshot);

    expect(await state.attachedStoreId(), 'store-a');
    expect(await state.attachedProviderType(), CloudProviderType.dropbox);
    expect(await state.attachedAccountId(), 'db-row');
    expect(await state.hasMarkerMismatch(), isTrue);
    expect(
      await state.attachGeneration(),
      greaterThan(generationBefore),
      reason: 'a runtime built before the restore is superseded',
    );
  });

  test('a detached snapshot restores to detached', () async {
    final snapshot = await state.snapshot();
    await state.setAttached('store-a', providerType: CloudProviderType.s3);

    await state.restore(snapshot);

    expect(await state.attachedStoreId(), isNull);
    expect(await state.attachedAccountId(), isNull);
  });
}
