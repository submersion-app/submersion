import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/device_local_fields.dart';

void main() {
  group('withoutDeviceLocalColumns', () {
    test('drops the device-local keys of the entity type', () {
      final stripped = withoutDeviceLocalColumns('diveComputers', {
        'id': 'c1',
        'name': 'Perdix',
        'bluetoothAddress': 'AA:BB',
      });
      expect(stripped, {'id': 'c1', 'name': 'Perdix'});
    });

    test('returns the same map when there is nothing to strip', () {
      final data = {'id': 'c1', 'name': 'Perdix'};
      expect(
        identical(withoutDeviceLocalColumns('diveComputers', data), data),
        isTrue,
      );
      final dive = {'id': 'd1', 'bluetoothAddress': 'kept'};
      expect(
        identical(withoutDeviceLocalColumns('dives', dive), dive),
        isTrue,
        reason: 'only the listed entity type loses the key',
      );
    });
  });

  test('isDeviceLocalColumn matches SQL column names', () {
    expect(isDeviceLocalColumn('diveComputers', 'bluetooth_address'), isTrue);
    expect(isDeviceLocalColumn('diveComputers', 'name'), isFalse);
    expect(isDeviceLocalColumn('dives', 'bluetooth_address'), isFalse);
  });

  test('active_diver_id is a device-local settings key', () {
    expect(deviceLocalSettingsKeys, contains('active_diver_id'));
  });

  test('the notification settings and theme mode are device-local', () {
    expect(deviceLocalSyncColumns['diverSettings'], {
      'notificationsEnabled',
      'serviceReminderDays',
      'reminderTime',
      'tripServiceLeadDays',
      'themeMode',
    });
    expect(isDeviceLocalColumn('diverSettings', 'theme_mode'), isTrue);
    expect(isDeviceLocalColumn('diverSettings', 'theme_preset'), isFalse);
    expect(isDeviceLocalColumn('diverSettings', 'map_style'), isFalse);
    expect(isDeviceLocalColumn('diverSettings', 'locale'), isFalse);
  });

  test('the nav layout keys are device-local settings keys', () {
    expect(
      deviceLocalSettingsKeys,
      containsAll(<String>[
        'nav_primary_ids',
        'nav_rail_ids',
        'nav_always_hide_labels',
      ]),
    );
  });

  test('isDeviceLocalRecord matches only device-local settings keys', () {
    expect(isDeviceLocalRecord('settings', 'nav_primary_ids'), isTrue);
    expect(isDeviceLocalRecord('settings', 'active_diver_id'), isTrue);
    expect(
      isDeviceLocalRecord('settings', 'share_new_records_by_default'),
      isFalse,
    );
    expect(isDeviceLocalRecord('dives', 'nav_primary_ids'), isFalse);
  });
}
