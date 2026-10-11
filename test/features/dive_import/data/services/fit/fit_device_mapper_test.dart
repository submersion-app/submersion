import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_import/data/services/fit/fit_device_mapper.dart';

/// The model a Garmin file with [product] gets.
String? garminModel(int? product) =>
    FitDeviceMapper.modelFor(manufacturer: 1, product: product);

void main() {
  test('maps known Garmin dive product codes', () {
    expect(garminModel(4223), 'Descent Mk3i');
    expect(garminModel(4518), 'Descent X50i');
    expect(garminModel(2859), 'Descent Mk1');
  });

  test('tells the Descent Mk3 apart from the Mk3i', () {
    expect(garminModel(4222), 'Descent Mk3');
  });

  test('maps every Fenix 8 variant to a Fenix 8, not a Descent (#1605)', () {
    expect(garminModel(4532), 'Fenix 8 Solar');
    expect(garminModel(4533), 'Fenix 8 Solar');
    expect(garminModel(4534), 'Fenix 8');
    expect(garminModel(4536), 'Fenix 8');
    expect(garminModel(4631), 'Fenix 8 Pro');
  });

  test('maps the other dive-capable Garmin watch families', () {
    expect(garminModel(4005), 'Descent G1');
    expect(garminModel(4588), 'Descent G2');
    expect(garminModel(3906), 'Fenix 7');
    expect(garminModel(4375), 'Fenix 7 Pro Solar');
    expect(garminModel(4313), 'Epix Pro (Gen 2)');
    expect(garminModel(4575), 'Enduro 3');
    expect(garminModel(4775), 'Tactix 8');
  });

  test('names an unknown product generically, never as a Descent', () {
    expect(garminModel(999999), 'Garmin');
    expect(garminModel(null), 'Garmin');
  });

  group('modelFor (#3045)', () {
    test('a Garmin file keeps the product table name', () {
      expect(
        FitDeviceMapper.modelFor(
          manufacturer: 1,
          manufacturerName: 'Garmin',
          product: 4223,
          productName: 'Some Other Name',
        ),
        'Descent Mk3i',
      );
    });

    test('a Garmin file with an unknown code ignores product_name', () {
      // The Garmin cloud import matches a serial against the stored model,
      // so a device already registered as "Garmin" must keep that name.
      expect(
        FitDeviceMapper.modelFor(
          manufacturer: 1,
          manufacturerName: 'Garmin',
          product: 999999,
          productName: 'Garmin Descent S1',
        ),
        'Garmin',
      );
    });

    test('a Garmin file with neither a known code nor a name is "Garmin"', () {
      expect(
        FitDeviceMapper.modelFor(
          manufacturer: 1,
          manufacturerName: 'Garmin',
          product: 999999,
        ),
        'Garmin',
      );
    });

    test('a Suunto Nautic S is named from product_name, not as a Garmin', () {
      expect(
        FitDeviceMapper.modelFor(
          manufacturer: 23,
          manufacturerName: 'Suunto',
          product: 73,
          productName: 'Suunto Nautic S',
        ),
        'Nautic S',
      );
    });

    test('a Suunto product code names the model without product_name', () {
      expect(
        FitDeviceMapper.modelFor(
          manufacturer: 23,
          manufacturerName: 'Suunto',
          product: 73,
        ),
        'Nautic S',
      );
    });

    test('an unknown Suunto product falls back to "Suunto"', () {
      expect(
        FitDeviceMapper.modelFor(
          manufacturer: 23,
          manufacturerName: 'Suunto',
          product: 9999,
        ),
        'Suunto',
      );
    });

    test('another manufacturer uses product_name verbatim', () {
      expect(
        FitDeviceMapper.modelFor(manufacturer: 255, productName: ' Petrel 3 '),
        'Petrel 3',
      );
    });

    test('another manufacturer without product_name has no model', () {
      expect(FitDeviceMapper.modelFor(manufacturer: 255, product: 73), isNull);
      expect(
        FitDeviceMapper.modelFor(manufacturer: 255, productName: '  '),
        isNull,
      );
    });

    test('a file without a manufacturer keeps the Garmin fallback', () {
      expect(FitDeviceMapper.modelFor(manufacturer: null), 'Garmin');
      expect(
        FitDeviceMapper.modelFor(manufacturer: null, product: 4518),
        'Descent X50i',
      );
    });

    test('a product_name that is only the manufacturer is ignored', () {
      expect(
        FitDeviceMapper.modelFor(
          manufacturer: 23,
          manufacturerName: 'Suunto',
          product: 9999,
          productName: 'SUUNTO',
        ),
        'Suunto',
      );
    });

    test('the prefix is only stripped at a word boundary', () {
      expect(
        FitDeviceMapper.modelFor(
          manufacturer: 23,
          manufacturerName: 'Suunto',
          productName: 'SuuntoX 1',
        ),
        'SuuntoX 1',
      );
    });
  });
}
