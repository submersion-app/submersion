import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/domain/entities/emergency_info.dart';

void main() {
  test('EmergencyRegion value equality (props)', () {
    const a = EmergencyRegion(
      id: 'us',
      name: 'DAN',
      phone: '1',
      countries: ['US'],
    );
    const same = EmergencyRegion(
      id: 'us',
      name: 'DAN',
      phone: '1',
      countries: ['US'],
    );
    const different = EmergencyRegion(
      id: 'eu',
      name: 'DAN',
      phone: '1',
      countries: ['US'],
    );
    expect(a, same);
    expect(a, isNot(different));
  });

  test('EmergencyChamber value equality (props)', () {
    const a = EmergencyChamber(
      id: 'c1',
      name: 'Chamber',
      country: 'US',
      phone: '1',
      isBuiltIn: true,
    );
    const same = EmergencyChamber(
      id: 'c1',
      name: 'Chamber',
      country: 'US',
      phone: '1',
      isBuiltIn: true,
    );
    final different =
        a ==
        const EmergencyChamber(
          id: 'c2',
          name: 'Chamber',
          country: 'US',
          phone: '1',
          isBuiltIn: true,
        );
    expect(a, same);
    expect(different, isFalse);
  });

  test('EmergencyChamber.fromBundledJson parses dates and coordinates', () {
    final c = EmergencyChamber.fromBundledJson({
      'id': 'au-1',
      'name': 'Unit',
      'country': 'AU',
      'city': 'Cairns',
      'phone': '+61',
      'latitude': -16.9,
      'longitude': 145.7,
      'lastVerified': '2026-07-01',
    });
    expect(c.isBuiltIn, isTrue);
    expect(c.latitude, -16.9);
    expect(c.lastVerified, DateTime.parse('2026-07-01'));
  });

  test(
    'hotlineFor falls back to the first region without a worldwide entry',
    () {
      const numbers = EmergencyNumbers(
        regions: [
          EmergencyRegion(
            id: 'us',
            name: 'DAN US',
            phone: '1',
            countries: ['US'],
          ),
          EmergencyRegion(
            id: 'eu',
            name: 'DAN EU',
            phone: '2',
            countries: ['DE'],
          ),
        ],
        defaultEms: '112',
        emsByCountry: {'US': '911'},
      );
      // No region with an empty country list, so an unknown country returns the
      // first region rather than a worldwide fallback.
      expect(numbers.hotlineFor('XX').id, 'us');
      expect(numbers.hotlineFor('US').id, 'us');
      expect(numbers.emsFor('US'), '911');
      expect(numbers.emsFor('XX'), '112');
    },
  );
}
