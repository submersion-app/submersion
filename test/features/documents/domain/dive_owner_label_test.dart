import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/documents/domain/dive_owner_label.dart';

void main() {
  final date = DateTime.utc(2026, 10, 12, 9);

  group('display', () {
    test('number, site and date', () {
      expect(
        DiveOwnerLabel(
          number: 142,
          siteName: 'Blue Hole',
          date: date,
        ).display('12 Oct 2026'),
        '#142 · Blue Hole · 12 Oct 2026',
      );
    });

    test('an unnumbered dive goes by site and date', () {
      expect(
        DiveOwnerLabel(siteName: 'Blue Hole', date: date).display('12 Oct'),
        'Blue Hole · 12 Oct',
      );
    });

    test('a dive with no site keeps number and date', () {
      expect(
        DiveOwnerLabel(number: 142, date: date).display('12 Oct'),
        '#142 · 12 Oct',
      );
    });

    test('a blank site name counts as no site', () {
      expect(
        DiveOwnerLabel(number: 142, siteName: '  ', date: date).display('x'),
        '#142 · x',
      );
    });
  });

  group('folderName', () {
    test('uses single spaces and an ISO date', () {
      expect(
        DiveOwnerLabel(
          number: 142,
          siteName: 'Blue Hole',
          date: date,
        ).folderName(),
        '#142 Blue Hole 2026-10-12',
      );
    });

    test('an unnumbered dive', () {
      expect(
        DiveOwnerLabel(siteName: 'Blue Hole', date: date).folderName(),
        'Blue Hole 2026-10-12',
      );
    });
  });
}
