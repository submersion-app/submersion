import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/services/lightroom_connector_state.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LightroomConnectorState state;

  setUp(() async {
    db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    state = LightroomConnectorState(
      prefs: await SharedPreferences.getInstance(),
      accountId: 'acc-1',
    );
  });

  tearDown(() => tearDownTestDatabase());

  Future<String?> settingValue(String key) async {
    final row = await db
        .customSelect("SELECT value FROM settings WHERE key = '$key'")
        .getSingleOrNull();
    return row?.data['value'] as String?;
  }

  test(
    'setAlbumIds writes the synced settings row and marks it pending',
    () async {
      await state.setAlbumIds(['a1', 'a2']);
      expect(await state.albumIds(), ['a1', 'a2']);
      expect(await settingValue('lightroom_acc-1_album_ids'), '["a1","a2"]');

      final pending = await db
          .customSelect(
            "SELECT id FROM sync_records "
            "WHERE id = 'settings_lightroom_acc-1_album_ids'",
          )
          .get();
      expect(pending, hasLength(1));
    },
  );

  test('autoPoll round-trips through the settings table', () async {
    expect(await state.autoPollEnabled(), isTrue, reason: 'default on');
    await state.setAutoPollEnabled(false);
    expect(await state.autoPollEnabled(), isFalse);
    expect(await settingValue('lightroom_acc-1_auto_poll'), 'false');
  });

  test('pre-sync prefs values are honored until the next write', () async {
    SharedPreferences.setMockInitialValues({
      'lightroom_acc-1_album_ids': ['legacy'],
      'lightroom_acc-1_auto_poll': false,
    });
    final legacyState = LightroomConnectorState(
      prefs: await SharedPreferences.getInstance(),
      accountId: 'acc-1',
    );
    expect(await legacyState.albumIds(), ['legacy']);
    expect(await legacyState.autoPollEnabled(), isFalse);
  });

  test('a synced row from another device wins over local prefs', () async {
    SharedPreferences.setMockInitialValues({
      'lightroom_acc-1_album_ids': ['local'],
    });
    await db.customStatement(
      "INSERT INTO settings (key, value, updated_at) "
      "VALUES ('lightroom_acc-1_album_ids', '[\"remote\"]', 1)",
    );
    final s = LightroomConnectorState(
      prefs: await SharedPreferences.getInstance(),
      accountId: 'acc-1',
    );
    expect(await s.albumIds(), ['remote']);
  });

  test('a tombstoned key is honored over the legacy prefs fallback', () async {
    SharedPreferences.setMockInitialValues({
      'lightroom_acc-1_album_ids': ['legacy'],
      'lightroom_acc-1_auto_poll': false,
    });
    final s = LightroomConnectorState(
      prefs: await SharedPreferences.getInstance(),
      accountId: 'acc-1',
    );
    // Another device cleared the config: tombstones synced in, no row.
    for (final key in [
      'lightroom_acc-1_album_ids',
      'lightroom_acc-1_auto_poll',
    ]) {
      await db.customStatement(
        "INSERT INTO deletion_log (id, entity_type, record_id, deleted_at) "
        "VALUES ('tomb-$key', 'settings', '$key', 1)",
      );
    }

    expect(await s.albumIds(), isEmpty, reason: 'deletion wins over prefs');
    expect(
      await s.autoPollEnabled(),
      isTrue,
      reason: 'deletion restores the default, not the stale local false',
    );
  });

  test('a corrupt synced auto-poll value falls back instead of reading '
      'as false', () async {
    await db.customStatement(
      "INSERT INTO settings (key, value, updated_at) "
      "VALUES ('lightroom_acc-1_auto_poll', 'garbage', 1)",
    );
    expect(await state.autoPollEnabled(), isTrue);
  });

  test('clear removes the synced rows and tombstones them', () async {
    await state.setAlbumIds(['a1']);
    await state.setAutoPollEnabled(false);
    await state.clear();

    expect(await settingValue('lightroom_acc-1_album_ids'), isNull);
    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log WHERE entity_type = 'settings' "
          "AND record_id LIKE 'lightroom_acc-1_%'",
        )
        .get();
    expect(tombstones, hasLength(2));
  });
}
