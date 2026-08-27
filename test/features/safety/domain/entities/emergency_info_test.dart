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

  group('EmergencyChamber capability and provenance', () {
    test(
      'parses capability, availability and provenance from a bundled row',
      () {
        final chamber = EmergencyChamber.fromBundledJson({
          'id': 'it-niguarda',
          'name': 'Ospedale Niguarda',
          'country': 'IT',
          'city': 'Milano',
          'phone': '+39-02-6444-1',
          'emergencyPhone': '+39-02-6444-2222',
          'latitude': 45.5065,
          'longitude': 9.1919,
          'capability': 'diving_emergency',
          'availability': 'h24',
          'verified': {
            'date': '2026-08-26',
            'via': 'facility',
            'url': 'https://example.org/iperbarico',
          },
        });

        expect(chamber.capability, ChamberCapability.divingEmergency);
        expect(chamber.availability, ChamberAvailability.h24);
        expect(chamber.emergencyPhone, '+39-02-6444-2222');
        expect(chamber.verifiedVia, ChamberVerification.facility);
        expect(chamber.verifiedUrl, 'https://example.org/iperbarico');
        expect(chamber.lastVerified, DateTime.parse('2026-08-26'));
        expect(chamber.isBuiltIn, isTrue);
      },
    );

    test('callNumber prefers the dedicated emergency line', () {
      final chamber = EmergencyChamber.fromBundledJson({
        'id': 'x',
        'name': 'X',
        'country': 'IT',
        'phone': '+39-02-6444-1',
        'emergencyPhone': '+39-02-6444-2222',
      });
      expect(chamber.callNumber, '+39-02-6444-2222');
    });

    test('callNumber falls back to the switchboard', () {
      final chamber = EmergencyChamber.fromBundledJson({
        'id': 'x',
        'name': 'X',
        'country': 'IT',
        'phone': '+39-02-6444-1',
      });
      expect(chamber.callNumber, '+39-02-6444-1');
    });

    test('rows predating the schema default to unknown', () {
      final chamber = EmergencyChamber.fromBundledJson({
        'id': 'us-duke',
        'name': 'Duke Center for Hyperbaric Medicine',
        'country': 'US',
        'phone': '+1-919-684-8111',
        'lastVerified': '2026-07-01',
      });

      expect(chamber.capability, ChamberCapability.unknown);
      expect(chamber.availability, ChamberAvailability.unknown);
      expect(chamber.verifiedVia, ChamberVerification.unknown);
      expect(chamber.emergencyPhone, isNull);
      expect(chamber.verifiedUrl, isNull);
      expect(chamber.lastVerified, DateTime.parse('2026-07-01'));
    });

    test('an unrecognised wire value degrades to unknown', () {
      final chamber = EmergencyChamber.fromBundledJson({
        'id': 'x',
        'name': 'X',
        'country': 'US',
        'phone': '+1-555-0100',
        'capability': 'wellness_spa',
        'availability': 'sometimes',
      });
      expect(chamber.capability, ChamberCapability.unknown);
      expect(chamber.availability, ChamberAvailability.unknown);
    });

    test('copyWith replaces only the named fields', () {
      const chamber = EmergencyChamber(
        id: 'x',
        name: 'X',
        country: 'US',
        phone: '+1-555-0100',
        isBuiltIn: true,
      );
      final updated = chamber.copyWith(
        capability: ChamberCapability.elective,
        city: 'Miami',
      );

      expect(updated.capability, ChamberCapability.elective);
      expect(updated.city, 'Miami');
      expect(updated.id, 'x');
      expect(updated.phone, '+1-555-0100');
      expect(updated.isBuiltIn, isTrue);
    });
  });
}
