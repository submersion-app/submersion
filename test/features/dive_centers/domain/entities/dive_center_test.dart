import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';

void main() {
  DiveCenter buildCenter({
    String? city,
    String? stateProvince,
    String? country,
  }) {
    final now = DateTime(2024, 1, 1);
    return DiveCenter(
      id: 'center-1',
      name: 'Test Center',
      city: city,
      stateProvince: stateProvince,
      country: country,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('fullLocationString', () {
    test('includes city, state/province, and country when all present', () {
      final center = buildCenter(
        city: 'Cozumel',
        stateProvince: 'Quintana Roo',
        country: 'Mexico',
      );

      expect(center.fullLocationString, 'Cozumel, Quintana Roo, Mexico');
    });

    test('omits state/province when absent', () {
      final center = buildCenter(city: 'Cozumel', country: 'Mexico');

      expect(center.fullLocationString, 'Cozumel, Mexico');
    });

    test('omits city when absent but keeps state/province and country', () {
      final center = buildCenter(
        stateProvince: 'Quintana Roo',
        country: 'Mexico',
      );

      expect(center.fullLocationString, 'Quintana Roo, Mexico');
    });
  });

  test('fill hours copy, clear and compare', () {
    final now = DateTime(2026);
    final center = DiveCenter(
      id: 'c1',
      name: 'Dive Friends',
      fillOpensAt: 480,
      fillClosesAt: 1020,
      createdAt: now,
      updatedAt: now,
    );
    expect(center.copyWith(name: 'x').fillClosesAt, 1020);
    expect(center.copyWith(fillOpensAt: null).fillOpensAt, isNull);
    expect(center.copyWith(fillClosesAt: 1080), isNot(center));
  });
}
