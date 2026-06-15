import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/services/sync/post_restore_sync_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PostRestoreSyncStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = PostRestoreSyncStore(await SharedPreferences.getInstance());
  });

  test('defaults to not pending', () {
    expect(store.pending, isFalse);
  });

  test('setPending then clear round-trips', () async {
    await store.setPending();
    expect(store.pending, isTrue);
    await store.clear();
    expect(store.pending, isFalse);
  });

  test('survives a new store instance over the same prefs (restore)', () async {
    await store.setPending();
    final reopened = PostRestoreSyncStore(await SharedPreferences.getInstance());
    expect(reopened.pending, isTrue);
  });
}
