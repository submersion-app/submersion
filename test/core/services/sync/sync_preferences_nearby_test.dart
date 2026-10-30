import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('nearbyAutoEnabled defaults to true and persists false', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = SyncPreferences(prefs);
    expect(store.nearbyAutoEnabled, isTrue);
    await store.setNearbyAutoEnabled(false);
    expect(SyncPreferences(prefs).nearbyAutoEnabled, isFalse);
    expect(prefs.getBool('sync_nearby_auto'), isFalse);
  });

  test('the nearby switch is independent of cloud auto sync', () async {
    SharedPreferences.setMockInitialValues({'sync_auto_enabled': false});
    final store = SyncPreferences(await SharedPreferences.getInstance());
    expect(store.autoSyncEnabled, isFalse);
    expect(store.nearbyAutoEnabled, isTrue);
  });
}
