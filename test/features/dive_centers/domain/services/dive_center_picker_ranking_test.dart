import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/domain/services/dive_center_picker_ranking.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The dive center picker's nearby-first order (#3379).
void main() {
  const origin = GeoPoint(0, 0);
  // Metres per degree of latitude, from the same formula the code uses, so
  // the distances below are what the ranking will measure.
  final metresPerDegree = distanceMeters(origin, const GeoPoint(1, 0));
  GeoPoint north(double metres) => GeoPoint(metres / metresPerDegree, 0);

  DiveCenter center(String name, {GeoPoint? at, bool closed = false}) {
    final now = DateTime(2026);
    return DiveCenter(
      id: name,
      name: name,
      latitude: at?.latitude,
      longitude: at?.longitude,
      isPermanentlyClosed: closed,
      createdAt: now,
      updatedAt: now,
    );
  }

  List<String> names(Iterable<DiveCenter> centers) => [
    for (final c in centers) c.name,
  ];

  group('resolveDiveCenterPickerReference', () {
    const entry = GeoPoint(1, 1);
    const exit = GeoPoint(2, 2);
    const device = GeoPoint(3, 3);
    const siteWithCoords = DiveSite(
      id: 's1',
      name: 'Salt Pier',
      location: GeoPoint(12.08, -68.28),
    );
    const siteWithoutCoords = DiveSite(id: 's2', name: 'Unknown Reef');

    test('the site comes first and names the section', () {
      final ref = resolveDiveCenterPickerReference(
        site: siteWithCoords,
        entryLocation: entry,
        exitLocation: exit,
        deviceLocation: device,
      );
      expect(ref!.point, siteWithCoords.location);
      expect(ref.siteName, 'Salt Pier');
    });

    test('a site without coordinates falls back to the entry GPS', () {
      final ref = resolveDiveCenterPickerReference(
        site: siteWithoutCoords,
        entryLocation: entry,
        exitLocation: exit,
        deviceLocation: device,
      );
      expect(ref!.point, entry);
      expect(ref.siteName, isNull);
    });

    test('then the exit GPS, then the device', () {
      expect(
        resolveDiveCenterPickerReference(
          exitLocation: exit,
          deviceLocation: device,
        )!.point,
        exit,
      );
      final fromDevice = resolveDiveCenterPickerReference(
        deviceLocation: device,
      );
      expect(fromDevice!.point, device);
      expect(fromDevice.siteName, isNull);
      expect(fromDevice.source, DiveCenterReferenceSource.device);
      expect(
        resolveDiveCenterPickerReference(entryLocation: entry)!.source,
        DiveCenterReferenceSource.dive,
      );
      expect(
        resolveDiveCenterPickerReference(site: siteWithCoords)!.source,
        DiveCenterReferenceSource.site,
      );
    });

    test('a site with a blank name heads the section as "this dive"', () {
      final ref = resolveDiveCenterPickerReference(
        site: const DiveSite(id: 's3', name: '  ', location: GeoPoint(1, 1)),
      );
      expect(ref!.point, const GeoPoint(1, 1));
      expect(ref.siteName, isNull);
    });

    test('nothing to measure from gives no reference', () {
      expect(resolveDiveCenterPickerReference(), isNull);
      expect(resolveDiveCenterPickerReference(site: siteWithoutCoords), isNull);
    });
  });

  group('rankDiveCentersForPicker', () {
    const reference = DiveCenterPickerReference(
      point: origin,
      siteName: 'Salt Pier',
    );

    test('the radius is 50 km', () {
      expect(kNearbyDiveCenterRadiusMeters, 50000);
    });

    test('nearby centers come nearest first, with their distance', () {
      final sections = rankDiveCentersForPicker([
        center('Far', at: north(30000)),
        center('Near', at: north(1000)),
        center('Middle', at: north(9000)),
      ], reference: reference);

      expect(names(sections.nearby.map((n) => n.center)), [
        'Near',
        'Middle',
        'Far',
      ]);
      expect(sections.nearby.first.distanceMeters, closeTo(1000, 1));
      expect(sections.others, isEmpty);
    });

    test('equal distances are ordered by name, whatever order they arrive', () {
      // East and west of the point by the same amount: the same distance.
      final sections = rankDiveCentersForPicker([
        center('Zed Divers', at: const GeoPoint(0, 0.05)),
        center('Alpha Divers', at: const GeoPoint(0, -0.05)),
      ], reference: reference);

      expect(names(sections.nearby.map((n) => n.center)), [
        'Alpha Divers',
        'Zed Divers',
      ]);
    });

    test('just inside 50 km is nearby, just outside is not', () {
      final sections = rankDiveCentersForPicker([
        center('Inside', at: north(49999)),
        center('Outside', at: north(50001)),
      ], reference: reference);

      expect(names(sections.nearby.map((n) => n.center)), ['Inside']);
      expect(names(sections.others), ['Outside']);
    });

    test('a closed center is never nearby and sits last in the rest', () {
      final sections = rankDiveCentersForPicker([
        center('Aardvark Divers', at: north(500), closed: true),
        center('Beta Divers'),
        center('Gamma Divers', at: north(900000)),
        center('Near Divers', at: north(2000)),
      ], reference: reference);

      expect(names(sections.nearby.map((n) => n.center)), ['Near Divers']);
      expect(names(sections.others), [
        'Beta Divers',
        'Gamma Divers',
        'Aardvark Divers',
      ]);
    });

    test('without a reference nothing is nearby, closed centers last', () {
      final sections = rankDiveCentersForPicker([
        center('Aardvark Divers', at: north(500), closed: true),
        center('Beta Divers', at: north(1000)),
        center('Gamma Divers'),
      ]);

      expect(sections.nearby, isEmpty);
      expect(names(sections.others), [
        'Beta Divers',
        'Gamma Divers',
        'Aardvark Divers',
      ]);
    });

    test('every center appears exactly once', () {
      final input = [
        center('A', at: north(100)),
        center('B', closed: true),
        center('C'),
        center('D', at: north(80000)),
      ];
      final sections = rankDiveCentersForPicker(input, reference: reference);
      final all = [
        ...sections.nearby.map((n) => n.center.id),
        ...sections.others.map((c) => c.id),
      ];
      expect(all, hasLength(input.length));
      expect(all.toSet(), {'A', 'B', 'C', 'D'});
    });
  });
}
