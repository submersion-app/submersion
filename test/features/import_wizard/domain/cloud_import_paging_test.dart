import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/domain/cloud_import_paging.dart';

void main() {
  group('CloudImportPaging', () {
    test('fetches 15 latest dives per page', () {
      expect(CloudImportPaging.pageSize, 15);
    });
  });
}
