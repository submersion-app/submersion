import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';

void main() {
  const base = SiteFeature(
    id: 'f-1',
    siteId: 's-1',
    typeName: 'wreck',
    latitude: 12.15,
    longitude: -68.3,
  );

  test('known type decodes; unknown type survives and decodes null', () {
    expect(base.type, SiteFeatureType.wreck);
    final future = base.copyWith(typeName: 'lavaTube');
    expect(future.type, isNull);
    expect(future.typeName, 'lavaTube');
    // copyWith without typeName preserves the raw unknown name.
    expect(future.copyWith(name: 'x').typeName, 'lavaTube');
  });

  test('copyWith clears nullables only via flags', () {
    final f = base.copyWith(bearingDeg: 45, depthMeters: 18);
    expect(f.copyWith().bearingDeg, 45);
    expect(f.copyWith(clearBearing: true).bearingDeg, isNull);
    expect(f.copyWith(clearDepth: true).depthMeters, isNull);
  });
}
