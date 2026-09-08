import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/domain/cloud_import_paging.dart';

void main() {
  group('CloudImportPaging', () {
    test('defaults to 15 latest dives per page', () {
      expect(CloudImportPaging.defaultPageSize, 15);
    });

    test('clamp pins values below 1 up to the minimum', () {
      expect(CloudImportPaging.clamp(0), CloudImportPaging.minPageSize);
      expect(CloudImportPaging.clamp(-4), CloudImportPaging.minPageSize);
    });

    test('clamp pins values above the maximum down', () {
      expect(
        CloudImportPaging.clamp(CloudImportPaging.maxPageSize + 1),
        CloudImportPaging.maxPageSize,
      );
    });

    test('clamp leaves in-range values alone', () {
      expect(CloudImportPaging.clamp(15), 15);
      expect(CloudImportPaging.clamp(1), 1);
      expect(CloudImportPaging.clamp(100), 100);
    });
  });
}
