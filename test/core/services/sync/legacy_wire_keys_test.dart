import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/legacy_wire_keys.dart';

void main() {
  group('withCurrentWireKeys', () {
    test('renames a legacy key to the current one', () {
      expect(withCurrentWireKeys('serviceRecords', {'serviceType': 'repair'}), {
        'serviceCategory': 'repair',
      });
    });

    test('the current key wins when a payload carries both', () {
      expect(
        withCurrentWireKeys('serviceRecords', {
          'serviceType': 'repair',
          'serviceCategory': 'cleaning',
        }),
        {'serviceCategory': 'cleaning'},
      );
    });

    test('leaves another entity type alone', () {
      final data = {'serviceType': 'repair'};
      expect(withCurrentWireKeys('dives', data), same(data));
    });

    test('leaves a payload without legacy keys alone', () {
      final data = {'serviceCategory': 'repair'};
      expect(withCurrentWireKeys('serviceRecords', data), same(data));
    });

    test('does not change the map it was given', () {
      final data = {'serviceType': 'repair'};
      withCurrentWireKeys('serviceRecords', data);
      expect(data, {'serviceType': 'repair'});
    });
  });

  group('withCurrentWireSpelling', () {
    for (final (legacy, lane) in [
      ('litersPerMin', 'rmv'),
      ('pressurePerMin', 'sac'),
    ]) {
      test('maps the legacy SAC unit $legacy to the $lane lane', () {
        expect(withCurrentWireSpelling('diverSettings', {'sacUnit': legacy}), {
          'gasConsumptionDisplay': lane,
        });
      });
    }

    test('keeps a current gas-consumption lane', () {
      expect(
        withCurrentWireSpelling('diverSettings', {
          'gasConsumptionDisplay': 'both',
        }),
        {'gasConsumptionDisplay': 'both'},
      );
    });

    test('renames without remapping for another entity type', () {
      expect(
        withCurrentWireSpelling('serviceRecords', {'serviceType': 'repair'}),
        {'serviceCategory': 'repair'},
      );
    });
  });
}
