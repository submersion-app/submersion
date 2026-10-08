import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_device_mapper.dart';

void main() {
  test('maps known Garmin dive product codes', () {
    expect(FitDeviceMapper.modelName(4223), 'Descent Mk3i');
    expect(FitDeviceMapper.modelName(4518), 'Descent X50i');
    expect(FitDeviceMapper.modelName(2859), 'Descent Mk1');
  });

  test('tells the Descent Mk3 apart from the Mk3i', () {
    expect(FitDeviceMapper.modelName(4222), 'Descent Mk3');
  });

  test('maps every Fenix 8 variant to a Fenix 8, not a Descent (#1605)', () {
    expect(FitDeviceMapper.modelName(4532), 'Fenix 8 Solar');
    expect(FitDeviceMapper.modelName(4533), 'Fenix 8 Solar');
    expect(FitDeviceMapper.modelName(4534), 'Fenix 8');
    expect(FitDeviceMapper.modelName(4536), 'Fenix 8');
    expect(FitDeviceMapper.modelName(4631), 'Fenix 8 Pro');
  });

  test('maps the other dive-capable Garmin watch families', () {
    expect(FitDeviceMapper.modelName(4005), 'Descent G1');
    expect(FitDeviceMapper.modelName(4588), 'Descent G2');
    expect(FitDeviceMapper.modelName(3906), 'Fenix 7');
    expect(FitDeviceMapper.modelName(4375), 'Fenix 7 Pro Solar');
    expect(FitDeviceMapper.modelName(4313), 'Epix Pro (Gen 2)');
    expect(FitDeviceMapper.modelName(4575), 'Enduro 3');
    expect(FitDeviceMapper.modelName(4775), 'Tactix 8');
  });

  test('names an unknown product generically, never as a Descent', () {
    expect(FitDeviceMapper.modelName(999999), 'Garmin');
    expect(FitDeviceMapper.modelName(null), 'Garmin');
  });
}
