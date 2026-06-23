import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_device_mapper.dart';

void main() {
  test('maps known Garmin dive product codes', () {
    expect(FitDeviceMapper.modelName(4223), 'Descent Mk3i');
    expect(FitDeviceMapper.modelName(4518), 'Descent X50i');
    expect(FitDeviceMapper.modelName(2859), 'Descent Mk1');
  });

  test('falls back for unknown or null product', () {
    expect(FitDeviceMapper.modelName(999999), 'Garmin Descent');
    expect(FitDeviceMapper.modelName(null), 'Garmin Descent');
  });
}
