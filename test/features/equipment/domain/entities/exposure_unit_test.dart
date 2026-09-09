import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';

void main() {
  test('decode reads known units and ignores unknown keys', () {
    final m = decodeExposureIntervals(
      '{"coldDives": 50, "o2Hours": 12.5, "bogus": 1}',
    );
    expect(m, {ExposureUnit.coldDives: 50.0, ExposureUnit.o2Hours: 12.5});
  });

  test('decode tolerates an empty, blank or corrupt column', () {
    expect(decodeExposureIntervals('{}'), isEmpty);
    expect(decodeExposureIntervals(''), isEmpty);
    expect(decodeExposureIntervals('not json'), isEmpty);
  });

  test('encode writes sorted keys and drops non-positive values', () {
    final json = encodeExposureIntervals({
      ExposureUnit.saltHours: 200,
      ExposureUnit.coldDives: 50,
      ExposureUnit.cycles: 0,
    });
    expect(json, '{"coldDives":50.0,"saltHours":200.0}');
  });

  test('mapUnits excludes the three legacy column units', () {
    expect(ExposureUnit.mapUnits, isNot(contains(ExposureUnit.days)));
    expect(ExposureUnit.mapUnits, isNot(contains(ExposureUnit.dives)));
    expect(ExposureUnit.mapUnits, isNot(contains(ExposureUnit.hours)));
    expect(ExposureUnit.mapUnits, hasLength(5));
  });
}
