import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/presentation/utils/exposure_interval_input.dart';

void main() {
  test('hour units accept decimals', () {
    expect(parseExposureInterval(ExposureUnit.saltHours, '150.5'), 150.5);
    expect(parseExposureInterval(ExposureUnit.o2Hours, '12'), 12.0);
  });

  test('count units accept whole numbers only', () {
    expect(parseExposureInterval(ExposureUnit.coldDives, '25'), 25.0);
    expect(parseExposureInterval(ExposureUnit.coldDives, '2.5'), isNull);
    expect(parseExposureInterval(ExposureUnit.deepCycles, '3.0'), 3.0);
    expect(parseExposureInterval(ExposureUnit.cycles, '0'), isNull);
  });

  test('blank and non-positive read as no trigger', () {
    expect(parseExposureInterval(ExposureUnit.saltHours, ''), isNull);
    expect(parseExposureInterval(ExposureUnit.saltHours, '-4'), isNull);
    expect(parseExposureInterval(ExposureUnit.coldDives, 'abc'), isNull);
  });

  test('the map keeps only the units that parsed', () {
    final map = parseExposureIntervals({
      ExposureUnit.coldDives: '25',
      ExposureUnit.deepCycles: '1.5',
      ExposureUnit.saltHours: '',
      ExposureUnit.o2Hours: '40.25',
    });
    expect(map, {ExposureUnit.coldDives: 25.0, ExposureUnit.o2Hours: 40.25});
  });
}
