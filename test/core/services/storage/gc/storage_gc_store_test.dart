import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/storage/gc/cloud_usage_measure.dart';
import 'package:submersion/core/services/storage/gc/storage_gc_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round-trips every field', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = StorageGcStore(prefs);
    final at = DateTime(2026, 10, 17, 12);

    expect(store.lastDeviceRun, isNull);
    expect(store.cloudUsage, isNull);
    expect(store.postRestoreCloudPending, isFalse);

    await store.setLastDeviceRun(at);
    await store.setLastCloudMeasure(at);
    await store.setLastCloudAttempt(at);
    await store.setLastDeviceAttempt(at);
    await store.setLastDeviceResult(AreaResult(bytes: 10, items: 2, at: at));
    await store.setLastCloudResult(AreaResult(bytes: 30, items: 3, at: at));
    await store.setCloudUsage(CloudUsage(scannedAt: at, mediaBytes: 5));

    final again = StorageGcStore(prefs);
    expect(again.lastDeviceRun, at);
    expect(again.lastCloudMeasure, at);
    expect(again.lastCloudAttempt, at);
    expect(again.lastDeviceAttempt, at);
    expect(again.lastDeviceResult!.bytes, 10);
    expect(again.lastDeviceResult!.items, 2);
    expect(again.lastCloudResult!.bytes, 30);
    expect(again.lastCloudResult!.at, at);
    expect(again.cloudUsage!.mediaBytes, 5);
  });

  test('markRestored arms both post-restore flags', () async {
    final prefs = await SharedPreferences.getInstance();
    final at = DateTime(2026, 10, 17, 12);

    await StorageGcStore.markRestored(prefs, at);

    final store = StorageGcStore(prefs);
    expect(store.lastRestoreAt, at);
    expect(store.postRestorePendingSince, at);
    expect(store.postRestoreCloudPending, isTrue);

    await store.clearPostRestorePending();
    await store.setPostRestoreCloudPending(false);
    expect(store.postRestorePendingSince, isNull);
    expect(store.postRestoreCloudPending, isFalse);
    expect(store.lastRestoreAt, at, reason: 'the restore time stays');
  });

  test('a malformed stored value reads as absent', () async {
    SharedPreferences.setMockInitialValues({
      'storage_gc_cloud_usage': '{',
      'storage_gc_last_device_result': 'x',
    });
    final store = StorageGcStore(await SharedPreferences.getInstance());
    expect(store.cloudUsage, isNull);
    expect(store.lastDeviceResult, isNull);
  });
}
