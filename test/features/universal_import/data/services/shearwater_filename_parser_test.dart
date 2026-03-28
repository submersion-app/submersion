import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/universal_import/data/services/shearwater_filename_parser.dart';

void main() {
  group('ShearwaterFilenameParser', () {
    group('parseFilename', () {
      test('extracts Teric model and serial', () {
        final result = ShearwaterFilenameParser.parse(
          'Teric[8629AC48]#1 2025-9-20 7-42-35.swlogzp',
        );
        expect(result.model, 'Teric');
        expect(result.serial, '8629AC48');
        expect(result.diveNumber, 1);
      });

      test('extracts Perdix model and serial', () {
        final result = ShearwaterFilenameParser.parse(
          'Perdix[ABCD1234]#15 2025-12-01 10-30-00.swlogzp',
        );
        expect(result.model, 'Perdix');
        expect(result.serial, 'ABCD1234');
        expect(result.diveNumber, 15);
      });

      test('extracts Petrel 3 with space in name', () {
        final result = ShearwaterFilenameParser.parse(
          'Petrel 3[11223344]#7 2025-6-15 14-00-00.swlogzp',
        );
        expect(result.model, 'Petrel 3');
        expect(result.serial, '11223344');
        expect(result.diveNumber, 7);
      });

      test('extracts Peregrine', () {
        final result = ShearwaterFilenameParser.parse(
          'Peregrine[DEADBEEF]#100 2025-1-1 0-0-0.swlogzp',
        );
        expect(result.model, 'Peregrine');
        expect(result.serial, 'DEADBEEF');
        expect(result.diveNumber, 100);
      });

      test('returns unknown for unrecognized format', () {
        final result = ShearwaterFilenameParser.parse('random_file.db');
        expect(result.model, isNull);
        expect(result.serial, isNull);
        expect(result.diveNumber, isNull);
      });

      test('returns unknown for empty string', () {
        final result = ShearwaterFilenameParser.parse('');
        expect(result.model, isNull);
        expect(result.serial, isNull);
      });
    });

    group('vendorProduct', () {
      test('maps known models to vendor/product', () {
        expect(ShearwaterFilenameParser.vendorProduct('Teric'), (
          'Shearwater',
          'Teric',
        ));
        expect(ShearwaterFilenameParser.vendorProduct('Perdix'), (
          'Shearwater',
          'Perdix',
        ));
        expect(ShearwaterFilenameParser.vendorProduct('Petrel 3'), (
          'Shearwater',
          'Petrel 3',
        ));
      });

      test('returns null for unknown model', () {
        expect(ShearwaterFilenameParser.vendorProduct('Unknown'), isNull);
      });
    });
  });
}
