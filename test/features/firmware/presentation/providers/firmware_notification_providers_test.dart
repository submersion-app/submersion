import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/notification_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';
import 'package:submersion/features/firmware/domain/firmware_status.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_notification_providers.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_status_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

/// One system notification per item and new firmware release (issue #5104).
void main() {
  FirmwareUpdateEntry update(String id, String version, {bool safety = false}) {
    final model = FirmwareModel(
      id: 'm-$id',
      manufacturer: 'Maker',
      model: 'Model $id',
      equipmentTypes: const {EquipmentType.computer},
      releases: [
        FirmwareRelease(version: version, safety: safety),
        const FirmwareRelease(version: 'old'),
      ],
    );
    return (
      item: EquipmentItem(
        id: id,
        name: 'Computer $id',
        type: EquipmentType.computer,
      ),
      status: FirmwareUpdateAvailable(model, [model.releases.first]),
    );
  }

  late List<FirmwareNotice> shown;

  Future<(ProviderContainer, SharedPreferences)> run(
    List<FirmwareUpdateEntry> updates, {
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final p = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(p),
        firmwareUpdatesProvider.overrideWith((ref) async => updates),
        firmwareNoticeSenderProvider.overrideWithValue(
          (notice) async => shown.add(notice),
        ),
        firmwareNoticeL10nProvider.overrideWithValue(AppLocalizationsEn()),
      ],
    );
    addTearDown(c.dispose);
    await c.read(firmwareNotificationSyncProvider.future);
    return (c, p);
  }

  setUp(() => shown = []);

  test('pure: only pairs not yet notified', () {
    final updates = [update('a', 'V95'), update('b', 'V40')];
    expect(firmwareUpdatesToNotify(updates, {'a|V95'}).map((u) => u.item.id), [
      'b',
    ]);
  });

  test('a new update is notified once, across restarts', () async {
    final (_, prefs) = await run([update('a', 'V95', safety: true)]);
    expect(shown, hasLength(1));
    expect(shown.single.equipmentId, 'a');
    expect(shown.single.title, 'Firmware update for Computer a');
    expect(shown.single.body, 'V95 is a safety update. Tap for release notes.');
    expect(prefs.getStringList(SettingsKeys.firmwareNotifiedPairs), ['a|V95']);

    shown = [];
    await run(
      [update('a', 'V95', safety: true)],
      prefs: {
        SettingsKeys.firmwareNotifiedPairs: ['a|V95'],
      },
    );
    expect(shown, isEmpty);
  });

  test('a later release is notified again', () async {
    await run(
      [update('a', 'V96')],
      prefs: {
        SettingsKeys.firmwareNotifiedPairs: ['a|V95'],
      },
    );
    expect(shown.single.body, 'V96 is available. Tap for release notes.');
  });

  test('more than three at once send one summary', () async {
    final (_, prefs) = await run([
      for (final id in ['a', 'b', 'c', 'd']) update(id, 'V1'),
    ]);
    expect(shown, hasLength(1));
    expect(shown.single.payload, kFirmwareUpdatesPayload);
    expect(shown.single.title, 'Firmware updates available');
    expect(
      prefs.getStringList(SettingsKeys.firmwareNotifiedPairs),
      unorderedEquals(['a|V1', 'b|V1', 'c|V1', 'd|V1']),
    );
  });

  test('with notifications off nothing is shown or stored', () async {
    final (_, prefs) = await run(
      [update('a', 'V95')],
      prefs: {SettingsKeys.firmwareNotificationsEnabled: false},
    );
    expect(shown, isEmpty);
    expect(prefs.getStringList(SettingsKeys.firmwareNotifiedPairs), isNull);
  });

  test('with checks off nothing is shown', () async {
    await run(
      [update('a', 'V95')],
      prefs: {SettingsKeys.firmwareChecksEnabled: false},
    );
    expect(shown, isEmpty);
  });

  test('the summary opens the equipment list', () {
    expect(notificationPayloadRoute(kFirmwareUpdatesPayload), '/equipment');
  });
  test('a re-run while a send is in flight does not send again', () async {
    SharedPreferences.setMockInitialValues({});
    final p = await SharedPreferences.getInstance();
    final gate = Completer<void>();
    var sends = 0;
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(p),
        firmwareUpdatesProvider.overrideWith(
          (ref) async => [update('a', 'V95')],
        ),
        firmwareNoticeSenderProvider.overrideWithValue((notice) async {
          sends++;
          await gate.future;
        }),
        firmwareNoticeL10nProvider.overrideWithValue(AppLocalizationsEn()),
      ],
    );
    addTearDown(c.dispose);
    final first = c.read(firmwareNotificationSyncProvider.future);
    await pumpEventQueue();
    c.invalidate(firmwareNotificationSyncProvider);
    final second = c.read(firmwareNotificationSyncProvider.future);
    await pumpEventQueue();
    gate.complete();
    await first;
    await second;
    expect(sends, 1);
  });
}
