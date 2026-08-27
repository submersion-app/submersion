import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const marker = LibraryEpochMarker(
    epochId: 'e1',
    replacedAt: 99,
    deviceId: 'd1',
    deviceName: 'Mac',
  );

  late LibraryEpochStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = LibraryEpochStore(await SharedPreferences.getInstance());
  });

  test('last accepted marker round-trips and clears', () async {
    expect(store.lastAcceptedMarker, isNull);
    expect(store.lastAcceptedEpochId, isNull);
    await store.setLastAccepted(marker);
    expect(store.lastAcceptedEpochId, 'e1');
    expect(store.lastAcceptedMarker?.deviceName, 'Mac');
    await store.setLastAccepted(null);
    expect(store.lastAcceptedMarker, isNull);
  });

  test('pending replace round-trips and clears', () async {
    expect(store.pendingReplace, isNull);
    await store.setPendingReplace(marker);
    expect(store.pendingReplace?.epochId, 'e1');
    await store.clearPendingReplace();
    expect(store.pendingReplace, isNull);
  });

  test(
    'clear() removes both the last-accepted and pending-replace markers',
    () async {
      await store.setLastAccepted(marker);
      await store.setPendingReplace(marker);

      await store.clear();

      expect(store.lastAcceptedMarker, isNull);
      expect(store.pendingReplace, isNull);
    },
  );

  test('corrupt stored JSON reads as null', () async {
    SharedPreferences.setMockInitialValues({
      'sync_last_accepted_epoch_marker': 'not json',
      'sync_pending_replace_marker': '{"replacedAt": 1}',
    });
    store = LibraryEpochStore(await SharedPreferences.getInstance());
    expect(store.lastAcceptedMarker, isNull);
    expect(store.pendingReplace, isNull);
  });
}
