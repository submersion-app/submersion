import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';

void main() {
  group('HeatMapPoint', () {
    test('creates point with default weight', () {
      const point = HeatMapPoint(location: LatLng(25.0, -80.0));

      expect(point.weight, 1.0);
      expect(point.label, isNull);
    });

    test('creates point with custom weight and label', () {
      const point = HeatMapPoint(
        location: LatLng(25.0, -80.0),
        weight: 5.0,
        label: 'Cozumel',
      );

      expect(point.weight, 5.0);
      expect(point.label, 'Cozumel');
    });

    test('equality based on all properties', () {
      const point1 = HeatMapPoint(location: LatLng(25.0, -80.0), weight: 5.0);
      const point2 = HeatMapPoint(location: LatLng(25.0, -80.0), weight: 5.0);
      const point3 = HeatMapPoint(location: LatLng(25.0, -80.0), weight: 3.0);

      expect(point1, equals(point2));
      expect(point1, isNot(equals(point3)));
    });

    test('location coordinates are accessible', () {
      const point = HeatMapPoint(location: LatLng(25.5, -80.25));

      expect(point.location.latitude, 25.5);
      expect(point.location.longitude, -80.25);
    });

    test('different locations are not equal', () {
      const point1 = HeatMapPoint(location: LatLng(25.0, -80.0));
      const point2 = HeatMapPoint(location: LatLng(26.0, -80.0));

      expect(point1, isNot(equals(point2)));
    });
  });
}
