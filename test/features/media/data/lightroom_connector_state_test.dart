import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/data/services/lightroom_connector_state.dart';

import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LightroomConnectorState state;

  setUp(() async {
    // Album filter and auto-poll are backed by the synced settings table.
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    state = LightroomConnectorState(prefs: prefs, accountId: 'acct1');
  });

  tearDown(() => tearDownTestDatabase());

  test(
    'defaults: no poll time, empty albums, auto-poll on, no error',
    () async {
      expect(await state.lastPollAt(), isNull);
      expect(await state.albumIds(), isEmpty);
      expect(await state.autoPollEnabled(), isTrue);
      expect(await state.lastError(), isNull);
    },
  );

  test('round-trips each field', () async {
    final t = DateTime.utc(2026, 7, 11, 8, 30);
    await state.setLastPollAt(t);
    await state.setAlbumIds(['al1', 'al2']);
    await state.setAutoPollEnabled(false);
    await state.setLastError('boom');

    expect(await state.lastPollAt(), t);
    expect(await state.albumIds(), ['al1', 'al2']);
    expect(await state.autoPollEnabled(), isFalse);
    expect(await state.lastError(), 'boom');
  });

  test('setLastError(null) clears the error', () async {
    await state.setLastError('boom');
    await state.setLastError(null);
    expect(await state.lastError(), isNull);
  });

  test('clear resets all fields', () async {
    await state.setLastPollAt(DateTime.utc(2026));
    await state.setAlbumIds(['al1']);
    await state.setAutoPollEnabled(false);
    await state.setLastError('boom');

    await state.clear();
    expect(await state.lastPollAt(), isNull);
    expect(await state.albumIds(), isEmpty);
    expect(await state.autoPollEnabled(), isTrue);
    expect(await state.lastError(), isNull);
  });

  test('different account ids do not collide', () async {
    final prefs = await SharedPreferences.getInstance();
    final other = LightroomConnectorState(prefs: prefs, accountId: 'acct2');
    await state.setAlbumIds(['al1']);
    expect(await other.albumIds(), isEmpty);
  });
}
