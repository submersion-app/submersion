import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/library_replace_intent.dart';
import 'package:submersion/core/services/sync/sync_device_metadata.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<LibraryEpochStore> store() async =>
      LibraryEpochStore(await SharedPreferences.getInstance());

  DeviceIdentityResolver identity({
    String id = 'device-1',
    String? name = 'Erics-MacBook-Pro',
    String? appVersion = '1.2.3',
  }) =>
      () async => (id: id, name: name, appVersion: appVersion);

  test('mint persists a pending replace marker the gate can read', () async {
    final epochStore = await store();
    final intent = LibraryReplaceIntent(identity(), epochStore);

    final marker = await intent.mint();

    expect(marker.epochId, isNotEmpty);
    expect(marker.deviceId, 'device-1');
    expect(marker.deviceName, 'Erics-MacBook-Pro');
    expect(marker.appVersion, '1.2.3');
    expect(marker.replacedAt, greaterThan(0));
    expect(epochStore.pendingReplace?.epochId, marker.epochId);
  });

  test('each mint produces a distinct epoch id', () async {
    final epochStore = await store();
    final intent = LibraryReplaceIntent(identity(), epochStore);

    final first = await intent.mint();
    final second = await intent.mint();

    expect(first.epochId, isNot(second.epochId));
  });

  test('an absent device name still mints a displayable marker', () async {
    final epochStore = await store();
    final intent = LibraryReplaceIntent(identity(name: null), epochStore);

    final marker = await intent.mint();

    expect(marker.deviceName, isNull);
    expect(marker.displayName, 'device-1');
  });
}
