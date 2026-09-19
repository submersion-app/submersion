import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/sync/peer_device_name_store.dart';

void main() {
  late PeerDeviceNameStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = PeerDeviceNameStore(await SharedPreferences.getInstance());
  });

  tearDown(() => store.dispose());

  test('records and reads back a peer name', () async {
    expect(store.nameFor('dev-a'), isNull);
    await store.record('dev-a', "Eric's MacBook");
    expect(store.nameFor('dev-a'), "Eric's MacBook");
    expect(store.all(), {'dev-a': "Eric's MacBook"});
  });

  test('a later name replaces the earlier one', () async {
    await store.record('dev-a', 'old');
    await store.record('dev-a', 'new');
    expect(store.nameFor('dev-a'), 'new');
  });

  test('ignores an empty name', () async {
    await store.record('dev-a', '');
    expect(store.nameFor('dev-a'), isNull);
  });

  test('survives a new instance over the same preferences', () async {
    await store.record('dev-a', 'A');
    final again = PeerDeviceNameStore(await SharedPreferences.getInstance());
    addTearDown(again.dispose);
    expect(again.nameFor('dev-a'), 'A');
  });

  test('changes emits the full map after each record', () async {
    final seen = <Map<String, String>>[];
    final sub = store.changes.listen(seen.add);
    await store.record('dev-a', 'A');
    await store.record('dev-b', 'B');
    await store.record('dev-b', 'B'); // unchanged: no emission
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(seen, [
      {'dev-a': 'A'},
      {'dev-a': 'A', 'dev-b': 'B'},
    ]);
  });

  test('a corrupt preference reads as empty', () async {
    SharedPreferences.setMockInitialValues({
      PeerDeviceNameStore.prefsKey: 'not json',
    });
    final corrupt = PeerDeviceNameStore(await SharedPreferences.getInstance());
    addTearDown(corrupt.dispose);
    expect(corrupt.all(), isEmpty);
  });
}
